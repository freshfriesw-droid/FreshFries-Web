-- Fresh Fries LUXE: consolidated role-scoped reporting API.
-- Read-only; no changes to orders, dispatch, cashier workflows, or login.
CREATE OR REPLACE FUNCTION public.ff_reports_center(
 p_from date DEFAULT NULL,p_to date DEFAULT NULL,p_branch uuid DEFAULT NULL,p_driver uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $body$
DECLARE
 v_uid uuid:=auth.uid();v_role text;v_driver uuid;
 v_from date:=coalesce(p_from,public.ff_business_date(now()));
 v_to date:=coalesce(p_to,public.ff_business_date(now()));
 v_start timestamptz;v_end timestamptz;v_result jsonb;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=v_uid AND active=true;
 IF v_uid IS NULL OR v_role NOT IN
  ('manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen')
 THEN RAISE EXCEPTION 'هذا التقرير غير متاح لدورك' USING ERRCODE='42501';END IF;
 IF v_role IN ('manager','supervisor','customer_service') AND
  NOT public.ff38_permission_allowed(v_uid,'view_reports') THEN
  RAISE EXCEPTION 'تم سحب صلاحية عرض التقارير من حسابك' USING ERRCODE='42501';END IF;
 IF v_from<'2020-01-01'::date OR v_to>public.ff_business_date(now())
  OR v_to<v_from OR v_to-v_from>366 THEN
  RAISE EXCEPTION 'اختر فترة صحيحة بحد أقصى 367 يومًا تنتهي في اليوم التشغيلي الحالي'
  USING ERRCODE='22023';END IF;
 IF p_branch IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM public.ff_branches b WHERE b.id=p_branch AND
    (v_role IN ('manager','customer_service') OR EXISTS (
     SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=v_uid AND ub.branch_id=b.id))
 ) THEN RAISE EXCEPTION 'الفرع غير مخول لهذا الحساب' USING ERRCODE='42501';END IF;
 IF v_role='driver' THEN
  SELECT l.driver_id INTO v_driver
  FROM public.ff38_driver_links l JOIN public.ff_drivers d ON d.id=l.driver_id
  WHERE l.user_id=v_uid AND d.active LIMIT 1;
  IF v_driver IS NULL THEN RAISE EXCEPTION 'حساب الموصل غير مربوط' USING ERRCODE='42501';END IF;
 END IF;
 IF p_driver IS NOT NULL AND v_role NOT IN ('manager','supervisor','driver') THEN
  RAISE EXCEPTION 'فلتر الموصل غير متاح لهذا الدور' USING ERRCODE='42501';END IF;
 IF v_role='driver' AND p_driver IS NOT NULL AND p_driver<>v_driver THEN
  RAISE EXCEPTION 'لا يمكنك استعراض تقارير موصل آخر' USING ERRCODE='42501';END IF;
 IF p_driver IS NOT NULL AND v_role='supervisor' AND NOT EXISTS(
   SELECT 1 FROM public.ff_drivers d JOIN public.ff_user_branches ub ON ub.branch_id=d.branch_id
   WHERE d.id=p_driver AND ub.user_id=v_uid) THEN
   RAISE EXCEPTION 'الموصل ليس ضمن فروعك' USING ERRCODE='42501';END IF;
 IF p_driver IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.ff_drivers WHERE id=p_driver) THEN
   RAISE EXCEPTION 'الموصل غير معروف' USING ERRCODE='22023';END IF;

 v_start:=(v_from::timestamp+interval '8 hours') AT TIME ZONE 'Asia/Aden';
 v_end:=((v_to+1)::timestamp+interval '8 hours') AT TIME ZONE 'Asia/Aden';

 WITH all_scoped AS MATERIALIZED (
  SELECT o.id,o.order_number,o.branch_id,o.customer_id,o.created_by,o.created_at,
    o.business_date AS day,o.status,o.order_type,
    o.phone_snapshot,o.area_snapshot,o.items_total,o.delivery_fee,o.total,
    o.cancel_reason,o.rating,o.rating_note,o.closed_hours_flag,
    t.driver_id,t.assigned_at,t.picked_up_at,
    coalesce(t.delivered_at,o.delivered_at) AS delivered_at,
    t.cashier_stage,t.phase
   FROM public.ff_orders o
   LEFT JOIN public.ff38_delivery_tasks t ON t.order_id=o.id
   WHERE o.order_type='delivery' AND o.business_date BETWEEN least(v_from,v_to-7) AND v_to
    AND (p_branch IS NULL OR o.branch_id=p_branch)
    AND (p_driver IS NULL OR t.driver_id=p_driver)
    AND (
       v_role IN ('manager','customer_service')
       OR (v_role IN ('supervisor','assembly') AND EXISTS(
        SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=v_uid AND ub.branch_id=o.branch_id))
       OR (v_role='cashier' AND EXISTS(
        SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=v_uid AND ub.branch_id=o.branch_id)
        AND (o.created_by=v_uid OR EXISTS (
        SELECT 1 FROM public.ff49_cashier_receipts r WHERE r.order_id=o.id
          AND (r.received_by=v_uid OR r.invoiced_by=v_uid))))
       OR (v_role='driver' AND t.driver_id=v_driver)
     )
 ),
 scoped AS MATERIALIZED (SELECT * FROM all_scoped WHERE day BETWEEN v_from AND v_to),
 first_customer AS MATERIALIZED(
  SELECT NULLIF(btrim(phone_snapshot),'') AS phone,min(business_date) AS first_day
  FROM public.ff_orders WHERE order_type='delivery' AND NULLIF(btrim(phone_snapshot),'') IS NOT NULL
  GROUP BY NULLIF(btrim(phone_snapshot),'')
 ),
 first_area AS MATERIALIZED(
  SELECT lower(btrim(area_snapshot)) AS area,min(business_date) AS first_day
  FROM public.ff_orders WHERE order_type='delivery' AND NULLIF(btrim(area_snapshot),'') IS NOT NULL
  GROUP BY lower(btrim(area_snapshot))
 ),
 scoped_items AS MATERIALIZED(
  SELECT i.item_name AS name,i.quantity AS qty,
   COALESCE(i.line_total,i.quantity*i.unit_price,0) AS revenue
  FROM public.ff_order_items i JOIN scoped s ON s.id=i.order_id WHERE s.status='delivered'
  UNION ALL
  SELECT i.item_name,i.quantity,COALESCE(i.line_total,i.quantity*i.unit_price,0)
  FROM public.ff38_order_addition_items i
  JOIN public.ff38_order_additions a ON a.id=i.addition_id AND a.status='invoiced'
  JOIN scoped s ON s.id=a.order_id AND s.status='delivered'
 ),
 eligible_drivers AS MATERIALIZED (
  SELECT d.id,d.name,d.branch_id
  FROM public.ff_drivers d
  WHERE (v_role IN ('manager','customer_service')
   OR (v_role='supervisor' AND EXISTS(SELECT 1 FROM public.ff_user_branches ub
      WHERE ub.user_id=v_uid AND ub.branch_id=d.branch_id))
   OR (v_role='driver' AND d.id=v_driver))
   AND (p_branch IS NULL OR d.branch_id=p_branch)
   AND (p_driver IS NULL OR d.id=p_driver)
 ),
 attendance_spans AS MATERIALIZED (
  SELECT ed.id AS driver_id,ss.id AS session_id,ss.capture_source,
   GREATEST(ss.started_at,v_start) AS start_time,
   LEAST(COALESCE(ss.ended_at,
    LEAST(now(),COALESCE(pr.last_seen_at+interval '3 minutes',ss.started_at))),
    v_end) AS end_time
  FROM eligible_drivers ed JOIN public.ff_report_driver_sessions ss ON ss.driver_id=ed.id
  LEFT JOIN public.ff38_driver_presence pr ON pr.driver_id=ed.id
  WHERE ss.started_at<v_end AND COALESCE(ss.ended_at,now())>v_start
 ),
 attendance AS MATERIALIZED (
  SELECT sp.driver_id,
    round(COALESCE(sum(GREATEST(0,extract(epoch FROM(sp.end_time-sp.start_time)))),0)/3600.0,2) AS gross_hours,
    round(COALESCE(sum(COALESCE(breaks.seconds,0)),0)/3600.0,2) AS break_hours,
    round(COALESCE(sum(GREATEST(0,extract(epoch FROM(sp.end_time-sp.start_time))-
       COALESCE(breaks.seconds,0))),0)/3600.0,2) AS work_hours,
    count(*)::integer AS sessions,
    bool_or(sp.capture_source='partial_start') AS has_partial_session,
    min(sp.start_time) AS first_attendance,
    max(sp.end_time) AS last_attendance
  FROM attendance_spans sp
  LEFT JOIN LATERAL (
    SELECT COALESCE(sum(GREATEST(0,extract(epoch FROM(
      LEAST(coalesce(b.ended_at,now()),sp.end_time)-
      GREATEST(b.started_at,sp.start_time))))),0) seconds
    FROM public.ff51_driver_breaks b
    WHERE b.driver_id=sp.driver_id AND b.started_at<sp.end_time
     AND COALESCE(b.ended_at,now())>sp.start_time
  ) breaks ON true
  WHERE sp.end_time>sp.start_time
  GROUP BY sp.driver_id
 ),
 drv_stats AS MATERIALIZED(
  SELECT ed.id,ed.name,ed.branch_id,b.name branch_name,
    count(s.id)::integer AS assigned,
    count(s.id) FILTER(WHERE s.status='delivered')::integer AS delivered,
    count(s.id) FILTER(WHERE s.status='cancelled')::integer AS cancelled,
    coalesce(sum(s.total) FILTER(WHERE s.status='delivered'),0)::numeric AS invoice_value,
    coalesce(sum(s.delivery_fee) FILTER(WHERE s.status='delivered'),0)::numeric AS delivery_fees,
    round(avg(extract(epoch FROM(s.delivered_at-s.assigned_at))/60)
      FILTER(WHERE s.status='delivered' AND s.assigned_at IS NOT NULL AND s.delivered_at IS NOT NULL),1) AS avg_assignment_minutes,
    round(avg(extract(epoch FROM(s.delivered_at-s.picked_up_at))/60)
      FILTER(WHERE s.status='delivered' AND s.picked_up_at IS NOT NULL AND s.delivered_at IS NOT NULL),1) AS avg_trip_minutes,
    count(s.id) FILTER(WHERE s.status='delivered' AND s.picked_up_at IS NOT NULL
     AND s.delivered_at<=s.picked_up_at+interval '40 minutes')::integer AS on_time,
    count(s.id) FILTER(WHERE s.status='delivered' AND s.picked_up_at IS NOT NULL
     AND s.delivered_at IS NOT NULL)::integer AS trip_sample,
    a.work_hours,a.break_hours,a.gross_hours,a.sessions,
    coalesce(a.has_partial_session,false) AS partial_attendance,a.first_attendance,a.last_attendance,
    (SELECT round(avg(r.stars)::numeric,2) FROM public.ff51_driver_ratings r
      WHERE r.driver_id=ed.id AND (r.rated_at AT TIME ZONE 'Asia/Aden')::date BETWEEN v_from AND v_to) AS average_rating,
    (SELECT count(*)::integer FROM public.ff51_driver_ratings r WHERE r.driver_id=ed.id
       AND (r.rated_at AT TIME ZONE 'Asia/Aden')::date BETWEEN v_from AND v_to) AS rating_count
   FROM eligible_drivers ed JOIN public.ff_branches b ON b.id=ed.branch_id
   LEFT JOIN scoped s ON s.driver_id=ed.id
   LEFT JOIN attendance a ON a.driver_id=ed.id
   GROUP BY ed.id,ed.name,ed.branch_id,b.name,
    a.work_hours,a.break_hours,a.gross_hours,a.sessions,a.has_partial_session,a.first_attendance,a.last_attendance
 ),
 daily AS MATERIALIZED(
  SELECT days.day::date AS day,
   count(s.id)::integer orders,
   count(s.id) FILTER(WHERE s.status='delivered')::integer delivered,
   count(s.id) FILTER(WHERE s.status='cancelled')::integer cancelled,
   COALESCE(sum(s.total) FILTER(WHERE s.status='delivered'),0)::numeric delivered_value
  FROM generate_series(v_from,v_to,interval '1 day') days(day)
  LEFT JOIN scoped s ON s.day=days.day::date GROUP BY days.day
 ),
 result_stats AS(
  SELECT count(*)::integer orders,
   count(*) FILTER(WHERE status='delivered')::integer delivered,
   count(*) FILTER(WHERE status='cancelled')::integer cancelled,
   count(*) FILTER(WHERE status NOT IN('delivered','cancelled'))::integer in_progress,
   count(*) FILTER(WHERE status='delivered' AND delivery_fee=0)::integer free_delivery,
   count(*) FILTER(WHERE status='delivered' AND delivered_at IS NOT NULL AND picked_up_at IS NOT NULL
    AND delivered_at>picked_up_at+interval '40 minutes')::integer delayed_delivered,
   count(*) FILTER(WHERE status<>'delivered' AND status<>'cancelled'
    AND picked_up_at IS NOT NULL AND now()>picked_up_at+interval '40 minutes')::integer currently_late,
   count(*) FILTER(WHERE closed_hours_flag)::integer out_of_hours,
   COALESCE(sum(items_total) FILTER(WHERE status='delivered'),0)::numeric items_sales,
   COALESCE(sum(delivery_fee) FILTER(WHERE status='delivered'),0)::numeric delivery_fees,
   COALESCE(sum(total) FILTER(WHERE status='delivered'),0)::numeric invoice_value,
   round(avg(total) FILTER(WHERE status='delivered'),2) average_order_value,
   round(avg(extract(epoch FROM(delivered_at-created_at))/60)
    FILTER(WHERE status='delivered' AND delivered_at IS NOT NULL),1) avg_full_cycle_minutes,
   round(avg(extract(epoch FROM(delivered_at-picked_up_at))/60)
    FILTER(WHERE status='delivered' AND delivered_at IS NOT NULL AND picked_up_at IS NOT NULL),1) avg_trip_minutes
  FROM scoped
 )
 SELECT jsonb_build_object(
  'meta',jsonb_build_object('from',v_from,'to',v_to,'business_day_start','08:00',
   'business_day_close','02:00','timezone','Asia/Aden','currency','YER',
   'role',v_role,'branch_id',p_branch,'driver_id',coalesce(p_driver,v_driver),
   'scope_note',CASE WHEN v_role='driver' THEN 'طلباتي فقط'
    WHEN v_role='cashier' THEN 'طلباتي وفواتيري فقط'
    WHEN v_role='assembly' THEN 'نطاق فرعي فقط'
    WHEN v_role='burger_kitchen' THEN 'تذاكر مطبخ البرجر فقط'
    WHEN v_role='supervisor' THEN 'الفروع المخولة لي فقط' ELSE 'نطاق صلاحيات الحساب' END,
   'trip_sla_minutes',40,'discounts_available',false,'deferred_status_available',false,
   'profit_available',false,
   'attendance_history_start',(SELECT min(started_at) FROM public.ff_report_driver_sessions),
   'historical_attendance_incomplete',(
     SELECT count(*)=0 OR v_start<min(started_at)
     FROM public.ff_report_driver_sessions)),
  'totals',(SELECT to_jsonb(t)||jsonb_build_object(
   'invoiced_additions',COALESCE((SELECT sum(a.amount) FROM scoped s
    JOIN public.ff38_order_additions a ON a.order_id=s.id AND a.status='invoiced'
    WHERE s.status='delivered'),0),
   'recorded_discounts',NULL::numeric,'net_after_discounts',NULL::numeric,
   'net_profit',NULL::numeric,'deferred_orders',NULL::integer)
   FROM result_stats t),
  'previous_comparison',COALESCE((
   SELECT jsonb_agg(jsonb_build_object('day',ref.day,'orders',ref.orders,
     'delivered',ref.delivered,'cancelled',ref.cancelled,'value',ref.value)
     ORDER BY ref.day DESC)
   FROM (SELECT a.day,count(*)::integer orders,
    count(*) FILTER(WHERE status='delivered')::integer delivered,
    count(*) FILTER(WHERE status='cancelled')::integer cancelled,
    COALESCE(sum(total) FILTER(WHERE status='delivered'),0) value
    FROM all_scoped a WHERE a.day IN(v_to,v_to-1,v_to-7) GROUP BY a.day) ref
  ),'[]'::jsonb),
  'daily',COALESCE((SELECT jsonb_agg(to_jsonb(d) ORDER BY d.day) FROM daily d),'[]'::jsonb),
  'weekly',COALESCE((SELECT jsonb_agg(to_jsonb(w) ORDER BY w.week) FROM (
     SELECT date_trunc('week',day::timestamp)::date AS week,
      sum(orders)::integer orders,sum(delivered)::integer delivered,sum(delivered_value) value
      FROM daily GROUP BY 1) w),'[]'::jsonb),
  'monthly',COALESCE((SELECT jsonb_agg(to_jsonb(w) ORDER BY w.month) FROM (
     SELECT date_trunc('month',day::timestamp)::date AS month,
       sum(orders)::integer orders,sum(delivered)::integer delivered,sum(delivered_value) value
       FROM daily GROUP BY 1) w),'[]'::jsonb),
  'branches',COALESCE((SELECT jsonb_agg(to_jsonb(q) ORDER BY q.orders DESC) FROM (
   SELECT s.branch_id,b.name branch_name,count(*)::integer orders,
    count(*) FILTER(WHERE s.status='delivered')::integer delivered,
    count(*) FILTER(WHERE s.status='cancelled')::integer cancelled,
    round(avg(s.total) FILTER(WHERE s.status='delivered'),2) avg_order_value,
    COALESCE(sum(s.total) FILTER(WHERE s.status='delivered'),0) invoice_value,
    COALESCE(sum(s.delivery_fee) FILTER(WHERE s.status='delivered'),0) delivery_fees
   FROM scoped s JOIN public.ff_branches b ON b.id=s.branch_id GROUP BY s.branch_id,b.name
  ) q),'[]'::jsonb),
  'hours',COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.hour_of_day) FROM(
   SELECT extract(hour FROM created_at AT TIME ZONE 'Asia/Aden')::integer AS hour_of_day,
    count(*)::integer orders,count(*) FILTER(WHERE status='delivered')::integer delivered
   FROM scoped GROUP BY 1) x),'[]'::jsonb),
  'areas',CASE WHEN v_role IN('manager','supervisor','customer_service')
    THEN COALESCE((SELECT jsonb_agg(to_jsonb(a) ORDER BY a.orders DESC) FROM(
     SELECT nullif(btrim(s.area_snapshot),'') area,count(*)::integer orders,
      count(DISTINCT s.phone_snapshot)::integer customers,
      count(*) FILTER(WHERE fa.first_day BETWEEN v_from AND v_to)::integer new_area_orders,
      min(s.day) first_order_day,
      round(avg(s.total) FILTER(WHERE s.status='delivered'),2) avg_order
     FROM scoped s LEFT JOIN first_area fa ON fa.area=lower(btrim(s.area_snapshot))
     WHERE nullif(btrim(s.area_snapshot),'') IS NOT NULL
     GROUP BY 1 ORDER BY orders DESC LIMIT 60) a),'[]'::jsonb) ELSE '[]'::jsonb END,
  'customers',CASE WHEN v_role IN('manager','supervisor','customer_service')
    THEN COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.orders DESC) FROM(
     SELECT CASE WHEN v_role='supervisor'
       THEN '***'||right(s.phone_snapshot,4) ELSE s.phone_snapshot END AS phone,
      CASE WHEN v_role='supervisor' THEN 'عميل محفوظ'
       ELSE COALESCE(max(customer.name),'عميل') END customer_name,
      count(*)::integer orders,
      count(*) FILTER(WHERE fc.first_day BETWEEN v_from AND v_to)::integer new_customer_orders,
      coalesce(sum(s.total) FILTER(WHERE s.status='delivered'),0) delivered_value
     FROM scoped s LEFT JOIN first_customer fc ON fc.phone=btrim(s.phone_snapshot)
     LEFT JOIN public.ff_customers customer ON customer.id=s.customer_id
     WHERE nullif(btrim(s.phone_snapshot),'') IS NOT NULL
     GROUP BY s.phone_snapshot ORDER BY orders DESC LIMIT 60) c),'[]'::jsonb) ELSE '[]'::jsonb END,
  'new_counts',CASE WHEN v_role IN('manager','supervisor','customer_service')
    THEN jsonb_build_object(
      'new_customers',COALESCE((SELECT count(DISTINCT s.phone_snapshot)
       FROM scoped s JOIN first_customer fc ON fc.phone=btrim(s.phone_snapshot)
       WHERE fc.first_day BETWEEN v_from AND v_to),0),
      'new_areas',COALESCE((SELECT count(DISTINCT lower(btrim(s.area_snapshot)))
       FROM scoped s JOIN first_area fa ON fa.area=lower(btrim(s.area_snapshot))
       WHERE fa.first_day BETWEEN v_from AND v_to),0),
      'total_unique_customers',COALESCE((SELECT count(DISTINCT phone_snapshot) FROM scoped),0))
   ELSE NULL END,
  'items',CASE WHEN v_role IN('manager','supervisor','customer_service','cashier')
    THEN COALESCE((SELECT jsonb_agg(to_jsonb(i) ORDER BY i.qty DESC,i.revenue DESC) FROM(
      SELECT name,sum(qty) qty,sum(revenue) revenue
      FROM scoped_items GROUP BY name ORDER BY qty DESC LIMIT 75) i),'[]'::jsonb)
    ELSE '[]'::jsonb END,
  'drivers',CASE WHEN v_role IN('manager','supervisor','customer_service','driver')
    THEN COALESCE((SELECT jsonb_agg(to_jsonb(d) ORDER BY d.delivered DESC,d.name)
      FROM drv_stats d),'[]'::jsonb) ELSE '[]'::jsonb END,
  'customer_service',CASE WHEN v_role IN('manager','customer_service','supervisor')
    THEN COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.orders DESC) FROM(
     SELECT p.user_id,p.display_name AS employee,
      count(s.id)::integer orders,
      count(s.id) FILTER(WHERE s.status='delivered')::integer delivered,
      count(s.id) FILTER(WHERE s.status='cancelled')::integer cancelled
     FROM scoped s JOIN public.ff_profiles p ON p.user_id=s.created_by AND p.role='customer_service'
     WHERE v_role<>'customer_service' OR p.user_id=v_uid
     GROUP BY p.user_id,p.display_name) c),'[]'::jsonb) ELSE '[]'::jsonb END,
  'cashiers',CASE WHEN v_role IN('manager','supervisor','cashier')
    THEN COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.orders DESC) FROM(
     SELECT p.user_id,p.display_name employee,
      count(*)::integer orders,
      count(*) FILTER(WHERE r.invoiced_at IS NOT NULL)::integer invoiced,
      count(*) FILTER(WHERE NULLIF(btrim(r.invoice_ref),'') IS NULL)::integer missing_invoice
     FROM public.ff49_cashier_receipts r
     JOIN scoped s ON s.id=r.order_id
     JOIN public.ff_profiles p ON p.user_id=COALESCE(r.invoiced_by,r.received_by)
     WHERE v_role<>'cashier' OR p.user_id=v_uid
     GROUP BY p.user_id,p.display_name) c),'[]'::jsonb) ELSE '[]'::jsonb END,
  'fastest_order',CASE WHEN v_role IN('manager','supervisor','customer_service','driver')
    THEN (SELECT jsonb_build_object('order_number',s.order_number,'branch_id',s.branch_id,
      'minutes',round(extract(epoch FROM(s.delivered_at-s.created_at))/60,1),
      'driver_id',s.driver_id)
     FROM scoped s WHERE s.status='delivered' AND s.delivered_at>=s.created_at
     ORDER BY s.delivered_at-s.created_at LIMIT 1) ELSE NULL END,
  'cancellations',CASE WHEN v_role IN('manager','supervisor','customer_service','cashier')
    THEN COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.created_at DESC) FROM(
     SELECT s.order_number,s.branch_id,s.created_at,
      coalesce(nullif(btrim(s.cancel_reason),''),
       (SELECT a.reason FROM public.ff38_order_cancellation_audit a WHERE a.order_id=s.id
        ORDER BY a.cancelled_at DESC LIMIT 1),'سبب غير مسجل') AS reason
     FROM scoped s WHERE s.status='cancelled' ORDER BY s.created_at DESC LIMIT 100) c),'[]'::jsonb)
    ELSE '[]'::jsonb END,
  'ratings',CASE WHEN v_role IN('manager','supervisor','customer_service','driver')
    THEN COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.stars ASC,x.rated_at DESC) FROM(
     SELECT r.stars,r.note,r.rated_at,r.driver_id,d.name driver_name,
      (SELECT o.order_number FROM public.ff_orders o WHERE o.id=r.order_id) AS order_number
     FROM public.ff51_driver_ratings r JOIN eligible_drivers ed ON ed.id=r.driver_id
     JOIN public.ff_drivers d ON d.id=r.driver_id
     WHERE (r.rated_at AT TIME ZONE 'Asia/Aden')::date BETWEEN v_from AND v_to
     ORDER BY r.stars ASC,r.rated_at DESC LIMIT 100) x),'[]'::jsonb)
    ELSE '[]'::jsonb END,
  'order_ratings',CASE WHEN v_role IN('manager','supervisor','customer_service')
    THEN COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.rating ASC) FROM(
     SELECT s.order_number,s.branch_id,s.rating,s.rating_note
     FROM scoped s WHERE s.rating IS NOT NULL ORDER BY s.rating ASC,s.created_at DESC LIMIT 100) x),
     '[]'::jsonb) ELSE '[]'::jsonb END,
  'cases',CASE WHEN v_role IN('manager','supervisor','customer_service')
    THEN COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC) FROM(
     SELECT c.id,c.kind,c.subject,c.description,c.priority,c.status,c.resolution,
      c.created_at,c.branch_id,o.order_number,coalesce(p.display_name,'—') actor_name
     FROM public.ff41_cases c LEFT JOIN public.ff_orders o ON o.id=c.order_id
     LEFT JOIN public.ff_profiles p ON p.user_id=c.created_by
     WHERE (c.created_at AT TIME ZONE 'Asia/Aden')::date BETWEEN v_from AND v_to
       AND (p_branch IS NULL OR c.branch_id=p_branch)
       AND (v_role IN('manager','customer_service') OR EXISTS(
        SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=v_uid AND ub.branch_id=c.branch_id))
       AND (p_driver IS NULL OR EXISTS(
        SELECT 1 FROM public.ff38_delivery_tasks dt
         WHERE dt.order_id=c.order_id AND dt.driver_id=p_driver))
     ORDER BY c.created_at DESC LIMIT 150) x),'[]'::jsonb)
    ELSE '[]'::jsonb END,
  'rewards',CASE WHEN v_role='manager'
    THEN COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.issued_at DESC) FROM(
     SELECT code,kind,status,recipient_name,
      right(recipient_phone,4) phone_suffix,issued_at,redeemed_at,
      redeemed_branch_id,redeemed_channel,items
     FROM public.ff_reward_codes
     WHERE (issued_at AT TIME ZONE 'Asia/Aden')::date BETWEEN v_from AND v_to
      AND (p_branch IS NULL OR redeemed_branch_id=p_branch OR redeemed_branch_id IS NULL)
     ORDER BY issued_at DESC LIMIT 100) x),'[]'::jsonb)
    ELSE '[]'::jsonb END,
  'kitchen',CASE WHEN v_role IN('manager','supervisor','customer_service','burger_kitchen')
    THEN COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.sent DESC) FROM(
     SELECT b.id branch_id,b.name branch_name,
      count(*)::integer sent,
      count(*) FILTER(WHERE t.status IN('ready','acknowledged'))::integer finished,
      count(*) FILTER(WHERE t.notes IS NOT NULL AND btrim(t.notes)<>'' )::integer with_notes,
      count(*) FILTER(WHERE t.notes_confirmed_at IS NOT NULL)::integer confirmed_notes,
      round(avg(extract(epoch FROM(t.ready_at-t.accepted_at))/60)
        FILTER(WHERE t.ready_at IS NOT NULL AND t.accepted_at IS NOT NULL),1) avg_prep_minutes,
      round(min(extract(epoch FROM(t.ready_at-t.accepted_at))/60)
        FILTER(WHERE t.ready_at IS NOT NULL AND t.accepted_at IS NOT NULL),1) fastest_prep_minutes
     FROM public.ff_burger_tickets t JOIN public.ff_branches b ON b.id=t.branch_id
     WHERE public.ff_business_date(t.sent_at) BETWEEN v_from AND v_to
      AND (p_branch IS NULL OR b.id=p_branch)
      AND (v_role IN('manager','customer_service') OR EXISTS(
       SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=v_uid AND ub.branch_id=b.id))
      AND (v_role<>'burger_kitchen' OR t.kitchen_id=v_uid OR t.kitchen_id IS NULL)
     GROUP BY b.id,b.name) x),'[]'::jsonb) ELSE '[]'::jsonb END,
  'manager_notes',CASE WHEN v_role='manager'
    THEN COALESCE((SELECT jsonb_agg(to_jsonb(n) ORDER BY n.business_date DESC) FROM(
      SELECT business_date,branch_id,note_text,manual_expenses,approver_name,approved_at,updated_at
      FROM public.ff_report_manager_notes
      WHERE business_date BETWEEN v_from AND v_to
      AND (p_branch IS NULL OR branch_id=p_branch OR branch_id IS NULL)
      ORDER BY business_date DESC LIMIT 100) n),'[]'::jsonb)
    ELSE '[]'::jsonb END
 ) INTO v_result;
 RETURN v_result;
END $body$;
REVOKE ALL ON FUNCTION public.ff_reports_center(date,date,uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_reports_center(date,date,uuid,uuid) TO authenticated;
