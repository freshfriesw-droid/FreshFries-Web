
-- The confirmed fee allocation is explicit evidence attached to a closed settlement;
-- it never changes the original settlement or creates an accounting movement.
CREATE TABLE ff_private.a10_fee_evidence(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,settlement_id uuid NOT NULL REFERENCES public.ff42_driver_settlements(id),amount numeric NOT NULL CHECK(amount>=0),evidence_note text NOT NULL CHECK(length(btrim(evidence_note)) BETWEEN 5 AND 500),confirmed_by uuid NOT NULL,confirmed_at timestamptz NOT NULL DEFAULT clock_timestamp());
ALTER TABLE ff_private.a10_fee_evidence ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ff_private.a10_fee_evidence FROM PUBLIC,anon,authenticated;
CREATE INDEX a10_fee_evidence_latest ON ff_private.a10_fee_evidence(settlement_id,id DESC);
CREATE OR REPLACE FUNCTION public.ff_a10_confirm_fee(p_settlement uuid,p_amount numeric,p_note text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.ff42_driver_settlements; v_id bigint;
BEGIN
 IF auth.uid() IS NULL OR NOT public.ff_is_manager() THEN RAISE EXCEPTION 'تأكيد رسوم التوصيل للمدير العام فقط' USING ERRCODE='42501';END IF;
 SELECT * INTO r FROM public.ff42_driver_settlements WHERE id=p_settlement FOR UPDATE;
 IF r.id IS NULL OR r.status<>'closed' THEN RAISE EXCEPTION 'التأكيد يتطلب تسوية مقفلة';END IF;
 IF p_amount IS NULL OR p_amount::text IN ('NaN','Infinity','-Infinity') OR p_amount<0 OR p_amount>least(r.cash_received,r.delivered_delivery_fees) OR length(btrim(coalesce(p_note,''))) NOT BETWEEN 5 AND 500 THEN RAISE EXCEPTION 'أدخل مبلغاً موثقاً لا يتجاوز الرسم المستحق والمستلم، مع مرجع الإثبات';END IF;
 INSERT INTO ff_private.a10_fee_evidence(settlement_id,amount,evidence_note,confirmed_by) VALUES(p_settlement,p_amount,btrim(p_note),auth.uid()) RETURNING id INTO v_id;
 RETURN jsonb_build_object('ok',true,'id',v_id,'amount',p_amount);
END $$;
CREATE OR REPLACE FUNCTION public.ff_a10_fee_history(p_settlement uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT public.ff_is_manager() THEN RAISE EXCEPTION 'سجل إثبات الرسوم للمدير العام فقط' USING ERRCODE='42501';END IF;
 RETURN coalesce((SELECT jsonb_agg(to_jsonb(q) ORDER BY q.id DESC) FROM (SELECT e.id,e.amount,e.evidence_note,e.confirmed_at,p.display_name confirmed_by FROM ff_private.a10_fee_evidence e LEFT JOIN public.ff_profiles p ON p.user_id=e.confirmed_by WHERE e.settlement_id=p_settlement ORDER BY e.id DESC LIMIT 100) q),'[]');
END $$;
REVOKE ALL ON FUNCTION public.ff_a10_confirm_fee(uuid,numeric,text),public.ff_a10_fee_history(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a10_confirm_fee(uuid,numeric,text),public.ff_a10_fee_history(uuid) TO authenticated;
CREATE OR REPLACE FUNCTION ff_private.a10_order_filter(p_order uuid,p_creator uuid,p_order_area text,p_order_status text,p_staff uuid,p_area text,p_item text,p_status text)
RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT (p_staff IS NULL OR p_creator=p_staff) AND (p_area IS NULL OR lower(btrim(p_order_area))=lower(btrim(p_area))) AND (p_status IS NULL OR (p_status='pending' AND p_order_status NOT IN ('delivered','cancelled')) OR p_status=p_order_status)
 AND (p_item IS NULL OR EXISTS(SELECT FROM public.ff_order_items i WHERE i.order_id=p_order AND lower(btrim(i.item_name))=lower(btrim(p_item))) OR EXISTS(SELECT FROM public.ff38_order_additions a JOIN public.ff38_order_addition_items i ON i.addition_id=a.id WHERE a.order_id=p_order AND a.status='invoiced' AND lower(btrim(i.item_name))=lower(btrim(p_item))))
$$;
REVOKE ALL ON FUNCTION ff_private.a10_order_filter(uuid,uuid,text,text,uuid,text,text,text) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION ff_private.a10_report_core(p_from date,p_to date,p_branch uuid,p_driver uuid,p_staff uuid,p_area text,p_item text,p_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_uid uuid:=auth.uid();
 v_role text;
 v_driver uuid;
 v_branches uuid[];
 v_start date:=coalesce(p_from,public.ff_business_date(now()));
 v_end date:=coalesce(p_to,public.ff_business_date(now()));
 v_core jsonb;
 v_attendance jsonb;
 v_complaints jsonb;
 v_grievances jsonb;
 v_comparison jsonb;
 v_approval jsonb;
 v_internal_ratings jsonb;
 v_settlements jsonb;
 v_extra jsonb;
 v_reservations jsonb;
 v_quality jsonb;
 v_partial boolean:=p_staff IS NOT NULL OR p_area IS NOT NULL OR p_item IS NOT NULL OR p_status IS NOT NULL;
BEGIN
 SELECT p.role INTO v_role FROM public.ff_profiles AS p WHERE p.user_id=v_uid AND p.active;
 IF v_role IS NULL OR v_role NOT IN('manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen')
 THEN RAISE EXCEPTION 'حساب موظف فعّال مطلوب' USING ERRCODE='42501'; END IF;
 IF v_role IN('supervisor','customer_service') AND NOT public.ff38_permission_allowed(v_uid,'view_reports')
 THEN RAISE EXCEPTION 'ليست لديك صلاحية التقارير' USING ERRCODE='42501'; END IF;
 
 IF EXISTS(SELECT 1 FROM public.ff38_staff_permission_overrides WHERE user_id=v_uid AND permission_key='view_reports' AND allowed=false) THEN
 RAISE EXCEPTION 'صلاحية التقارير مسحوبة' USING ERRCODE='42501';END IF;
 IF v_role='assembly' AND public.ff_v12_assembly_me()->>'is_assembly' IS DISTINCT FROM 'true' THEN
 RAISE EXCEPTION 'صلاحية التجميع مسحوبة' USING ERRCODE='42501';END IF;
 IF v_role='burger_kitchen' THEN PERFORM public.ff_burger_my_branch();END IF;
 IF v_start>v_end OR v_end-v_start>89 OR v_end>public.ff_business_date(now()) OR v_start<date '2020-01-01'
 THEN RAISE EXCEPTION 'الفترة يجب أن تكون بين 1 و90 يوماً ودون تواريخ مستقبلية'; END IF;
 IF v_role='driver' THEN
   SELECT l.driver_id INTO v_driver FROM public.ff38_driver_links AS l
   JOIN public.ff_drivers AS d ON d.id=l.driver_id AND d.active WHERE l.user_id=v_uid;
   IF v_driver IS NULL THEN RAISE EXCEPTION 'حساب الموصل غير مربوط' USING ERRCODE='42501'; END IF;
 END IF;
 IF v_role<>'manager' THEN
   SELECT array_agg(DISTINCT b.branch_id) INTO v_branches FROM public.ff_user_branches AS b WHERE b.user_id=v_uid;
   IF v_role='driver' THEN SELECT array_agg(d.branch_id) INTO v_branches FROM public.ff_drivers AS d WHERE d.id=v_driver; END IF;
   IF v_role='customer_service' OR (v_role='supervisor' AND coalesce(cardinality(v_branches),0)=0) THEN
 SELECT array_agg(b.id) INTO v_branches FROM public.ff_branches b WHERE b.active;
 END IF;
   IF coalesce(cardinality(v_branches),0)=0 THEN RAISE EXCEPTION 'لم يحدد فرع للحساب' USING ERRCODE='42501'; END IF;
 END IF;
 IF p_branch IS NOT NULL AND NOT EXISTS(
   SELECT 1 FROM public.ff_branches AS b WHERE b.id=p_branch
   AND (v_role='manager' OR b.id=ANY(v_branches))
 ) THEN RAISE EXCEPTION 'الفرع غير مصرح به' USING ERRCODE='42501'; END IF;
 IF p_driver IS NOT NULL AND (
   v_role NOT IN('manager','supervisor') OR NOT EXISTS (
     SELECT 1 FROM public.ff_drivers AS d WHERE d.id=p_driver
     AND (v_role='manager' OR d.branch_id=ANY(v_branches))
     AND (p_branch IS NULL OR d.branch_id=p_branch)
   )
 ) THEN RAISE EXCEPTION 'الموصل غير مصرح به' USING ERRCODE='42501'; END IF;
 IF p_status IS NOT NULL AND p_status NOT IN ('delivered','cancelled','pending') OR p_area IS NOT NULL AND length(btrim(p_area)) NOT BETWEEN 1 AND 160 OR p_item IS NOT NULL AND length(btrim(p_item)) NOT BETWEEN 1 AND 160 THEN RAISE EXCEPTION 'فلتر غير صالح' USING ERRCODE='22023';END IF;
 IF p_staff IS NOT NULL AND v_role NOT IN ('manager','supervisor','customer_service') THEN RAISE EXCEPTION 'فلتر الموظف غير متاح' USING ERRCODE='42501';END IF;
 IF v_role='customer_service' AND p_staff IS NOT NULL AND p_staff<>v_uid THEN RAISE EXCEPTION 'موظف غير مصرح' USING ERRCODE='42501';END IF;
 WITH accessible AS MATERIALIZED (
  SELECT o.id,o.order_number,o.branch_id,b.name AS branch_name,o.business_date AS work_day,
   o.created_at,o.created_by,o.customer_id,o.phone_snapshot,o.sent_at,o.closed_hours_flag,t.assigned_at,t.picked_up_at,t.arrived_at,
   coalesce(nullif(btrim(o.area_snapshot),''),'غير محددة') AS area_name,
   o.status,o.cancel_reason,o.rating,o.rating_note,
   coalesce(o.items_total,0) AS item_amount,coalesce(o.delivery_fee,0) AS fee_amount,
   coalesce(o.total,0) AS invoice_amount,
   coalesce(t.driver_id,o.driver_id) AS delivery_driver_id,
   coalesce(t.delivered_at,o.delivered_at) AS delivery_at,
   coalesce((SELECT sum(a.amount) FROM public.ff38_order_additions AS a
       WHERE a.order_id=o.id AND a.status='invoiced'),0) AS invoiced_addons,
   (nullif(btrim(o.phone_snapshot),'') IS NOT NULL AND NOT EXISTS
    (SELECT 1 FROM public.ff_orders AS older WHERE older.phone_snapshot=o.phone_snapshot
     AND (older.created_at,older.id)<(o.created_at,o.id))) AS first_customer,
   (nullif(btrim(o.area_snapshot),'') IS NOT NULL AND NOT EXISTS
    (SELECT 1 FROM public.ff_orders AS older WHERE lower(btrim(older.area_snapshot))=lower(btrim(o.area_snapshot))
     AND (older.created_at,older.id)<(o.created_at,o.id))) AS first_area
  FROM public.ff_orders AS o
  JOIN public.ff_branches AS b ON b.id=o.branch_id
  LEFT JOIN public.ff38_delivery_tasks AS t ON t.order_id=o.id
  WHERE o.order_type='delivery' AND o.business_date BETWEEN v_start AND v_end
   AND ((o.created_at AT TIME ZONE 'Asia/Aden')::time>=time '08:00'
      OR (o.created_at AT TIME ZONE 'Asia/Aden')::time<time '02:00')
   AND (p_branch IS NULL OR o.branch_id=p_branch)
   AND (v_role='manager' OR o.branch_id=ANY(v_branches))
   AND (v_role<>'customer_service' OR o.created_by=v_uid)
   AND (v_role<>'driver' OR coalesce(t.driver_id,o.driver_id)=v_driver)
   AND (v_role<>'cashier' OR EXISTS(SELECT 1 FROM public.ff49_cashier_receipts AS cr
        WHERE cr.order_id=o.id AND cr.received_by=v_uid))
   AND (v_role NOT IN('assembly','burger_kitchen') OR v_role='assembly'
        OR EXISTS(SELECT 1 FROM public.ff_burger_tickets AS k
            WHERE k.delivery_order_id=o.id AND k.kitchen_id=v_uid))
   AND (p_driver IS NULL OR coalesce(t.driver_id,o.driver_id)=p_driver)
 ), scoped AS MATERIALIZED (SELECT * FROM accessible a WHERE ff_private.a10_order_filter(a.id,a.created_by,a.area_name,a.status,p_staff,p_area,p_item,p_status)), product_rows AS (
  SELECT i.item_name AS item_name,i.quantity AS units,i.line_total AS revenue
   FROM scoped AS s JOIN public.ff_order_items AS i ON i.order_id=s.id
   WHERE s.status='delivered'
  UNION ALL
  SELECT i.item_name,i.quantity,i.line_total FROM scoped AS s
   JOIN public.ff38_order_additions AS a ON a.order_id=s.id AND a.status='invoiced'
   JOIN public.ff38_order_addition_items AS i ON i.addition_id=a.id
   WHERE s.status='delivered'
 )
 SELECT jsonb_build_object(
 'from',v_start,'to',v_end,'role',v_role,
 'scope',CASE WHEN v_role='manager' THEN 'كل الفروع أو الفرع المختار'
              WHEN v_role='driver' THEN 'طلبات الموصل نفسه'
              WHEN v_role='cashier' THEN 'الطلبات التي استلمها الكاشير'
              WHEN v_role='customer_service' THEN 'الطلبات التي أنشأها موظف خدمة العملاء'
              ELSE 'الفروع المرتبطة بحسابك' END,
 'available_sections',CASE
  WHEN v_role='manager' THEN '["summary","finance","orders","branches","drivers","staff","areas","items","ratings","cases","attendance","analytics","comparisons","approval"]'::jsonb
  WHEN v_role='supervisor' THEN '["summary","finance","orders","branches","drivers","staff","areas","items","ratings","cases","attendance","analytics","comparisons"]'::jsonb
  WHEN v_role='customer_service' THEN '["summary","orders","staff","areas","ratings","analytics"]'::jsonb
  WHEN v_role='driver' THEN '["summary","orders","drivers","ratings","attendance"]'::jsonb
  WHEN v_role='cashier' THEN '["summary","orders","items"]'::jsonb
  ELSE '["summary","orders"]'::jsonb END,
 'branches',coalesce((SELECT jsonb_agg(jsonb_build_object('id',b.id,'name',b.name) ORDER BY b.name)
    FROM public.ff_branches AS b WHERE b.active AND (v_role='manager' OR b.id=ANY(v_branches))),'[]'::jsonb),
 'driver_options',CASE WHEN v_role IN('manager','supervisor') THEN coalesce(
   (SELECT jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,'branch_id',d.branch_id) ORDER BY d.name)
    FROM public.ff_drivers AS d WHERE d.active AND (v_role='manager' OR d.branch_id=ANY(v_branches))),
   '[]'::jsonb) ELSE '[]'::jsonb END,
 'filter_options',jsonb_build_object(
 'staff',CASE WHEN v_role IN ('manager','supervisor','customer_service') THEN coalesce((SELECT jsonb_agg(to_jsonb(z) ORDER BY z.name,z.id) FROM (SELECT DISTINCT p.user_id id,p.display_name name FROM accessible a JOIN public.ff_profiles p ON p.user_id=a.created_by) z),'[]'::jsonb) ELSE '[]'::jsonb END,
 'areas',coalesce((SELECT jsonb_agg(a.area_name ORDER BY a.area_name) FROM (SELECT DISTINCT area_name FROM accessible ORDER BY area_name LIMIT 1000) a),'[]'::jsonb),
 'items',coalesce((SELECT jsonb_agg(q.name ORDER BY q.name) FROM (SELECT i.item_name name FROM accessible a JOIN public.ff_order_items i ON i.order_id=a.id UNION SELECT i.item_name FROM accessible a JOIN public.ff38_order_additions d ON d.order_id=a.id AND d.status='invoiced' JOIN public.ff38_order_addition_items i ON i.addition_id=d.id ORDER BY 1 LIMIT 1000) q),'[]'::jsonb)),
 'totals',(SELECT jsonb_build_object(
   'orders',count(*),'delivered',count(*) FILTER(WHERE status='delivered'),
   'cancelled',count(*) FILTER(WHERE status='cancelled'),
   'pending',count(*) FILTER(WHERE status NOT IN('delivered','cancelled')),
   'late',count(*) FILTER(WHERE status<>'cancelled' AND coalesce(delivery_at,now())-created_at>interval '60 minutes'),
   'late_completed',count(*) FILTER(WHERE status='delivered' AND delivery_at-created_at>interval '60 minutes'),
   'late_pending',count(*) FILTER(WHERE status NOT IN ('delivered','cancelled') AND now()-created_at>interval '60 minutes'),
   'p90_delivery_minutes',round((percentile_cont(.9) WITHIN GROUP(ORDER BY extract(epoch from(delivery_at-created_at))/60) FILTER(WHERE status='delivered' AND delivery_at>=created_at))::numeric,1),
   'free_delivery',count(*) FILTER(WHERE fee_amount=0),
   'new_customers',count(DISTINCT phone_snapshot) FILTER(WHERE first_customer),
   'repeat_customers',count(DISTINCT phone_snapshot) FILTER(WHERE NOT first_customer AND nullif(btrim(phone_snapshot),'') IS NOT NULL),
   'new_areas',count(DISTINCT lower(area_name)) FILTER(WHERE first_area AND area_name<>'غير محددة'),
   'item_sales',coalesce(sum(item_amount+invoiced_addons) FILTER(WHERE status='delivered'),0),
   'delivery_fees',coalesce(sum(fee_amount) FILTER(WHERE status='delivered'),0),
   'discounts_estimate',coalesce(sum(greatest(0,item_amount+fee_amount-invoice_amount))
      FILTER(WHERE status='delivered'),0),
   'net',coalesce(sum(invoice_amount+invoiced_addons) FILTER(WHERE status='delivered'),0),
   'average_order',round(avg(invoice_amount+invoiced_addons)
      FILTER(WHERE status='delivered'),1),
   'avg_delivery_minutes',round(avg(extract(epoch from(delivery_at-created_at))/60)
      FILTER(WHERE status='delivered' AND delivery_at>=created_at),1),
   'fastest_minutes',round(min(extract(epoch from(delivery_at-created_at))/60)
      FILTER(WHERE status='delivered' AND delivery_at>=created_at),1),
   'rating_avg',round(avg(rating),2),'rating_max',max(rating),'rating_min',min(rating),
   'low_ratings',count(*) FILTER(WHERE rating<=2),
   'cancellation_rate',round(100.0*(count(*) FILTER(WHERE status='cancelled'))/nullif(count(*),0),1)
 ) FROM scoped),
 'days',coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.work_day)
    FROM (SELECT work_day,count(*) AS orders,count(*) FILTER(WHERE status='delivered') AS delivered,
          count(*) FILTER(WHERE status='cancelled') AS cancelled,
          coalesce(sum(invoice_amount+invoiced_addons) FILTER(WHERE status='delivered'),0) AS net
          FROM scoped GROUP BY work_day) AS x),'[]'::jsonb),
 'branch_rows',coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.branch_name)
    FROM (SELECT branch_name,branch_id,count(*) AS orders,
          count(*) FILTER(WHERE status='delivered') AS delivered,
          count(*) FILTER(WHERE status='cancelled') AS cancelled,
          coalesce(sum(invoice_amount+invoiced_addons) FILTER(WHERE status='delivered'),0) AS net,
          round(avg(invoice_amount+invoiced_addons) FILTER(WHERE status='delivered'),1) AS average_order
          FROM scoped GROUP BY branch_name,branch_id) AS x),'[]'::jsonb),
 'hourly',coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.hour_of_day)
    FROM (SELECT extract(hour from created_at AT TIME ZONE 'Asia/Aden')::integer AS hour_of_day,
                 count(*) AS orders FROM scoped GROUP BY 1) AS x),'[]'::jsonb),
 'areas',coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.orders DESC)
    FROM (SELECT area_name,count(*) AS orders,count(*) FILTER(WHERE status='delivered') AS delivered,
                 count(*) FILTER(WHERE first_customer) AS new_customers
          FROM scoped GROUP BY area_name ORDER BY orders DESC LIMIT 40) AS x),'[]'::jsonb),
 'items',coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.quantity DESC)
    FROM (SELECT item_name,sum(units) AS quantity,sum(revenue) AS revenue
          FROM product_rows GROUP BY item_name ORDER BY quantity DESC LIMIT 40) AS x),'[]'::jsonb),
 'drivers',CASE WHEN v_role IN('manager','supervisor','driver') THEN coalesce(
    (SELECT jsonb_agg(to_jsonb(x) ORDER BY x.delivered DESC)
     FROM (SELECT s.delivery_driver_id AS driver_id,d.name AS driver_name,s.branch_id,
        count(*) AS assigned,count(*) FILTER(WHERE s.status='delivered') AS delivered,
        coalesce(sum(s.fee_amount) FILTER(WHERE s.status='delivered'),0) AS delivery_fees_due,
        coalesce(sum(s.invoice_amount+s.invoiced_addons) FILTER(WHERE s.status='delivered'),0) AS invoice_value,
        round(avg(s.invoice_amount+s.invoiced_addons) FILTER(WHERE s.status='delivered'),1) AS average_order,
        round(avg(extract(epoch from(s.delivery_at-s.created_at))/60)
          FILTER(WHERE s.status='delivered' AND s.delivery_at>=s.created_at),1) AS average_minutes,
        round(avg(s.rating),2) AS average_rating
        FROM scoped AS s JOIN public.ff_drivers AS d ON d.id=s.delivery_driver_id
        GROUP BY s.delivery_driver_id,d.name,s.branch_id ORDER BY delivered DESC LIMIT 100) AS x),'[]'::jsonb)
        ELSE '[]'::jsonb END,
 'service_staff',CASE WHEN v_role IN('manager','supervisor','customer_service') THEN coalesce(
    (SELECT jsonb_agg(to_jsonb(x) ORDER BY x.orders DESC)
      FROM (SELECT s.created_by AS staff_id,coalesce(p.display_name,'غير محدد') AS staff_name,count(*) AS orders,count(*) FILTER(WHERE s.status='cancelled') AS cancelled,count(*) FILTER(WHERE s.status<>'cancelled' AND coalesce(s.delivery_at,now())-s.created_at>interval '60 minutes') AS late,round(avg(extract(epoch from(s.sent_at-s.created_at))/60) FILTER(WHERE s.sent_at>=s.created_at),1) AS average_process_minutes,(SELECT count(*) FROM public.ff50_order_changes ch JOIN scoped z ON z.id=ch.order_id WHERE z.created_by IS NOT DISTINCT FROM s.created_by) AS changes
          FROM scoped AS s LEFT JOIN public.ff_profiles AS p ON p.user_id=s.created_by
          GROUP BY s.created_by,p.display_name ORDER BY orders DESC LIMIT 70) AS x),'[]'::jsonb)
    ELSE '[]'::jsonb END,
 'cancellations',CASE WHEN v_role IN('manager','supervisor','customer_service','cashier') THEN coalesce(
    (SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
     FROM (SELECT order_number,branch_name,created_at,
        coalesce(cancel_reason,'غير موثّق') AS reason
        FROM scoped WHERE status='cancelled' ORDER BY created_at DESC LIMIT 70) AS x),'[]'::jsonb)
    ELSE '[]'::jsonb END,
 'low_ratings',CASE WHEN v_role IN('manager','supervisor','customer_service') THEN coalesce(
    (SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
     FROM (SELECT order_number,rating,rating_note,created_at FROM scoped
      WHERE rating<=2 ORDER BY created_at DESC LIMIT 60) AS x),'[]'::jsonb)
    ELSE '[]'::jsonb END,
 'customers',CASE WHEN v_role IN('manager','supervisor') THEN coalesce(
    (SELECT jsonb_agg(to_jsonb(x) ORDER BY x.orders DESC)
     FROM (SELECT coalesce(c.name,'عميل') AS customer_name,
        '••••'||right(coalesce(max(s.phone_snapshot),''),4) AS phone_masked,
        count(*) AS orders
       FROM scoped AS s LEFT JOIN public.ff_customers AS c ON c.id=s.customer_id
       WHERE s.customer_id IS NOT NULL GROUP BY s.customer_id,c.name
       ORDER BY orders DESC LIMIT 40) AS x),'[]'::jsonb)
    ELSE '[]'::jsonb END,
 'late_orders',CASE WHEN v_role IN('manager','supervisor','customer_service','cashier','driver') THEN coalesce(
   (SELECT jsonb_agg(to_jsonb(x) ORDER BY x.delivery_minutes DESC)
    FROM (SELECT order_number,branch_name,
      round((extract(epoch from(coalesce(delivery_at,now())-created_at))/60)::numeric,1) AS delivery_minutes,status,
      created_at FROM scoped WHERE status<>'cancelled' AND coalesce(delivery_at,now())>created_at+interval '60 minutes'
      ORDER BY coalesce(delivery_at,now())-created_at DESC LIMIT 100) AS x),'[]'::jsonb)
    ELSE '[]'::jsonb END,
 'free_delivery_orders',coalesce(
   (SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
    FROM (SELECT order_number,branch_name,created_at,
        invoice_amount+invoiced_addons AS total_amount FROM scoped
       WHERE fee_amount=0 ORDER BY created_at DESC LIMIT 100) AS x),'[]'::jsonb),
 'phase_times',(SELECT jsonb_build_object('assignment_minutes',round(avg(extract(epoch from(assigned_at-created_at))/60) FILTER(WHERE assigned_at>=created_at),1),'pickup_minutes',round(avg(extract(epoch from(picked_up_at-assigned_at))/60) FILTER(WHERE picked_up_at>=assigned_at),1),'travel_minutes',round(avg(extract(epoch from(arrived_at-picked_up_at))/60) FILTER(WHERE arrived_at>=picked_up_at),1),'handover_minutes',round(avg(extract(epoch from(delivery_at-arrived_at))/60) FILTER(WHERE delivery_at>=arrived_at),1)) FROM scoped),
 'dispatch',(SELECT jsonb_build_object('offered',count(*),'accepted',count(*) FILTER(WHERE f.status='accepted'),'rejected',count(*) FILTER(WHERE f.status='rejected'),'expired',count(*) FILTER(WHERE f.status='expired'),'three_minute',count(*) FILTER(WHERE extract(epoch from(f.expires_at-f.offered_at)) BETWEEN 179 AND 181),'ten_minute',count(*) FILTER(WHERE extract(epoch from(f.expires_at-f.offered_at)) BETWEEN 599 AND 601)) FROM scoped z JOIN public.ff38_dispatch_offers f ON f.order_id=z.id WHERE (v_role<>'driver' OR f.driver_id=v_driver) AND (p_driver IS NULL OR f.driver_id=p_driver)),
 'additions',(SELECT jsonb_build_object('count',count(*),'invoiced_count',count(*) FILTER(WHERE a.status='invoiced'),'invoiced_value',coalesce(sum(a.amount) FILTER(WHERE a.status='invoiced'),0),'avg_minutes',round(avg(extract(epoch from(a.invoiced_at-a.created_at))/60) FILTER(WHERE a.invoiced_at>=a.created_at),1)) FROM scoped z JOIN public.ff38_order_additions a ON a.order_id=z.id),
 'invoice_review',(SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.order_number),'[]'::jsonb) FROM (SELECT z.order_number,z.branch_name,z.status FROM scoped z LEFT JOIN public.ff49_cashier_receipts cr ON cr.order_id=z.id WHERE z.status='delivered' AND nullif(btrim(cr.invoice_ref),'') IS NULL LIMIT 100) q),
 'fastest',coalesce(
   (SELECT jsonb_agg(to_jsonb(x) ORDER BY x.minutes)
    FROM (SELECT s.order_number,s.branch_name,d.name AS driver_name,
       round((extract(epoch from(s.delivery_at-s.created_at))/60)::numeric,1) AS minutes
     FROM scoped AS s LEFT JOIN public.ff_drivers AS d ON d.id=s.delivery_driver_id
     WHERE s.status='delivered' AND s.delivery_at>=s.created_at
     ORDER BY s.delivery_at-s.created_at LIMIT 5) AS x),'[]'::jsonb)
 ) INTO v_core;
 WITH shifts AS(
   SELECT g.d::date AS report_day,(g.d+interval '8 hours') AT TIME ZONE 'Asia/Aden' AS start_time,
      (g.d+interval '1 day 2 hours') AT TIME ZONE 'Asia/Aden' AS end_time
   FROM generate_series(v_start::timestamp,v_end::timestamp,interval '1 day') AS g(d)
 ), pieces AS(
   SELECT w.driver_id,sh.report_day,greatest(w.checked_in_at,sh.start_time) AS begin_at,
      least(coalesce(w.checked_out_at,now()),sh.end_time,now()) AS end_at
   FROM public.ff76_driver_work_sessions AS w
   JOIN public.ff_drivers AS d ON d.id=w.driver_id CROSS JOIN shifts AS sh
   WHERE w.checked_in_at<sh.end_time AND coalesce(w.checked_out_at,now())>sh.start_time
    AND (p_branch IS NULL OR d.branch_id=p_branch)
    AND (v_role='manager' OR d.branch_id=ANY(v_branches))
    AND (v_role IN('manager','supervisor') OR (v_role='driver' AND w.driver_id=v_driver))
    AND (p_driver IS NULL OR w.driver_id=p_driver) AND NOT v_partial
 ), net_parts AS(
   SELECT p.driver_id,p.report_day,p.begin_at,p.end_at,
    greatest(0,extract(epoch from(p.end_at-p.begin_at))-
       coalesce((SELECT sum(greatest(0,extract(epoch from
         least(coalesce(br.ended_at,now()),p.end_at)-greatest(br.started_at,p.begin_at))))
        FROM public.ff51_driver_breaks AS br
        WHERE br.driver_id=p.driver_id AND br.started_at<p.end_at
           AND coalesce(br.ended_at,now())>p.begin_at),0)) AS work_seconds
   FROM pieces AS p WHERE p.end_at>p.begin_at
 )
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.report_day,x.driver_name),'[]'::jsonb)
 INTO v_attendance FROM (
   SELECT n.report_day,n.driver_id,d.name AS driver_name,count(*) AS sessions,
    min(n.begin_at) AS first_checkin,max(n.end_at) AS last_checkout,
    round(sum(n.work_seconds)/3600,2) AS work_hours
   FROM net_parts AS n JOIN public.ff_drivers AS d ON d.id=n.driver_id
   GROUP BY n.report_day,n.driver_id,d.name
 ) AS x;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC),'[]'::jsonb)
 INTO v_complaints FROM(
   SELECT c.subject,c.status,c.created_at,b.name AS branch_name,o.order_number
   FROM public.ff41_cases AS c
   JOIN public.ff_branches AS b ON b.id=c.branch_id
   LEFT JOIN public.ff_orders AS o ON o.id=c.order_id
   WHERE v_role IN('manager','supervisor','customer_service')
    AND c.kind='customer_complaint'
    AND public.ff_business_date(c.created_at) BETWEEN v_start AND v_end
    AND (p_branch IS NULL OR c.branch_id=p_branch)
    AND (v_role='manager' OR c.branch_id=ANY(v_branches))
    AND (v_role<>'customer_service' OR c.created_by=v_uid)
    AND (p_driver IS NULL OR EXISTS(SELECT FROM public.ff38_delivery_tasks t WHERE t.order_id=c.order_id AND t.driver_id=p_driver))
    AND (NOT v_partial OR EXISTS(SELECT FROM public.ff_orders o2 WHERE o2.id=c.order_id AND ff_private.a10_order_filter(o2.id,o2.created_by,coalesce(nullif(btrim(o2.area_snapshot),''),'غير محددة'),o2.status,p_staff,p_area,p_item,p_status)))
   ORDER BY c.created_at DESC LIMIT 80
 ) AS x;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC),'[]'::jsonb)
 INTO v_grievances FROM(
   SELECT gr.category,gr.details,gr.status,gr.created_at
   FROM public.ff_luxe_driver_grievances AS gr
   LEFT JOIN public.ff_orders AS o ON o.id=gr.order_id
   WHERE v_role IN('manager','driver')
    AND (v_role='manager' OR gr.driver_user_id=v_uid)
    AND public.ff_business_date(gr.created_at) BETWEEN v_start AND v_end
    AND (p_branch IS NULL OR o.branch_id=p_branch)
    AND (p_driver IS NULL OR EXISTS(SELECT FROM public.ff38_driver_links l WHERE l.user_id=gr.driver_user_id AND l.driver_id=p_driver))
    AND (NOT v_partial OR ff_private.a10_order_filter(o.id,o.created_by,coalesce(nullif(btrim(o.area_snapshot),''),'غير محددة'),o.status,p_staff,p_area,p_item,p_status))
   ORDER BY gr.created_at DESC LIMIT 80
 ) AS x;
 SELECT coalesce(to_jsonb(a)-'id'-'report_day'-'scope_key'-'branch_id'-'approved_by','{}'::jsonb)
 INTO v_approval FROM public.ff76_report_approvals AS a
 WHERE v_role='manager' AND NOT v_partial AND p_driver IS NULL AND v_start=v_end AND a.report_day=v_end AND a.scope_key=coalesce(p_branch::text,'all');
 WITH comparison AS(
 SELECT o.business_date AS work_day,count(*) AS orders,
   count(*) FILTER(WHERE o.status='delivered') AS delivered,
   coalesce(sum(o.total+coalesce((SELECT sum(a.amount) FROM public.ff38_order_additions a WHERE a.order_id=o.id AND a.status='invoiced'),0)) FILTER(WHERE o.status='delivered'),0) AS net
 FROM public.ff_orders AS o
 LEFT JOIN public.ff38_delivery_tasks AS t ON t.order_id=o.id
 WHERE o.order_type='delivery' AND o.business_date BETWEEN v_end-7 AND v_end
   AND ((o.created_at AT TIME ZONE 'Asia/Aden')::time>=time '08:00'
     OR (o.created_at AT TIME ZONE 'Asia/Aden')::time<time '02:00')
   AND (p_branch IS NULL OR o.branch_id=p_branch)
   AND (v_role='manager' OR o.branch_id=ANY(v_branches))
   AND (v_role<>'customer_service' OR o.created_by=v_uid)
   AND (v_role<>'driver' OR coalesce(t.driver_id,o.driver_id)=v_driver)
   AND (v_role<>'cashier' OR EXISTS(SELECT 1 FROM public.ff49_cashier_receipts AS r
       WHERE r.order_id=o.id AND r.received_by=v_uid))
   AND (v_role NOT IN('assembly','burger_kitchen') OR v_role='assembly'
    OR EXISTS(SELECT 1 FROM public.ff_burger_tickets AS k WHERE k.delivery_order_id=o.id AND k.kitchen_id=v_uid))
   AND (p_driver IS NULL OR coalesce(t.driver_id,o.driver_id)=p_driver)
 AND ff_private.a10_order_filter(o.id,o.created_by,coalesce(nullif(btrim(o.area_snapshot),''),'غير محددة'),o.status,p_staff,p_area,p_item,p_status)
 GROUP BY o.business_date
 )
 SELECT jsonb_build_object(
   'today',coalesce((SELECT to_jsonb(x) FROM comparison AS x WHERE x.work_day=v_end),'{}'::jsonb),
   'yesterday',coalesce((SELECT to_jsonb(x) FROM comparison AS x WHERE x.work_day=v_end-1),'{}'::jsonb),
   'last_week',coalesce((SELECT to_jsonb(x) FROM comparison AS x WHERE x.work_day=v_end-7),'{}'::jsonb),
   'previous_week_average',jsonb_build_object('orders',coalesce((SELECT round(sum(x.orders)/7.0,1) FROM comparison AS x WHERE x.work_day BETWEEN v_end-7 AND v_end-1),0),'net',coalesce((SELECT round(sum(x.net)/7.0,1) FROM comparison AS x WHERE x.work_day BETWEEN v_end-7 AND v_end-1),0))
 ) INTO v_comparison;
 
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.driver_name),'[]'::jsonb)
 INTO v_internal_ratings FROM (
   SELECT d.id AS driver_id,d.name AS driver_name,count(*) AS ratings,
    round(avg(r.stars),2) AS average_stars,
    count(*) FILTER(WHERE r.stars<=2) AS low_ratings
   FROM public.ff51_driver_ratings AS r
   JOIN public.ff_drivers AS d ON d.id=r.driver_id JOIN public.ff_orders o ON o.id=r.order_id
   WHERE v_role IN('manager','supervisor','driver')
     AND public.ff_business_date(r.rated_at) BETWEEN v_start AND v_end
     AND (p_branch IS NULL OR o.branch_id=p_branch)
     AND (v_role='manager' OR o.branch_id=ANY(v_branches))
     AND (v_role<>'driver' OR r.driver_id=v_driver)
     AND (p_driver IS NULL OR r.driver_id=p_driver)
     AND ff_private.a10_order_filter(o.id,o.created_by,coalesce(nullif(btrim(o.area_snapshot),''),'غير محددة'),o.status,p_staff,p_area,p_item,p_status)
   GROUP BY d.id,d.name
 ) AS x;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.driver_name),'[]'::jsonb)
 INTO v_settlements FROM (
   SELECT d.id AS driver_id,d.name AS driver_name,count(*) AS statements,
      coalesce(sum(s.cash_due),0) AS cash_due,
      coalesce(sum(s.cash_received),0) AS cash_received,
      sum(s.cash_received) FILTER(WHERE s.status='closed') AS confirmed_received,
      sum(fe.amount) FILTER(WHERE s.status='closed') AS confirmed_delivery_fees,
      count(*) FILTER(WHERE s.status='closed' AND fe.id IS NULL) AS fees_need_review,
      sum(s.cash_due-s.cash_received) FILTER(WHERE s.status='closed') AS confirmed_difference,
      sum(s.cash_received) FILTER(WHERE s.status='draft') AS draft_received,
      count(*) FILTER(WHERE s.status='draft') AS draft_statements,
      count(*) FILTER(WHERE s.status='closed') AS closed_statements
   FROM public.ff42_driver_settlements AS s
   JOIN public.ff_drivers AS d ON d.id=s.driver_id
   LEFT JOIN LATERAL (SELECT e.id,e.amount FROM ff_private.a10_fee_evidence e WHERE e.settlement_id=s.id ORDER BY e.id DESC LIMIT 1) fe ON true
   WHERE v_role IN('manager','supervisor','driver')
     AND s.settlement_date BETWEEN v_start AND v_end
     AND (p_branch IS NULL OR s.branch_id=p_branch)
     AND (v_role='manager' OR s.branch_id=ANY(v_branches))
     AND (v_role<>'driver' OR s.driver_id=v_driver)
     AND (p_driver IS NULL OR s.driver_id=p_driver) AND NOT v_partial
   GROUP BY d.id,d.name
 ) AS x;
 SELECT jsonb_build_object('total',count(*),'collected',count(*) FILTER(WHERE r.status='collected'),'cancelled',count(*) FILTER(WHERE r.status='cancelled'),'pending',count(*) FILTER(WHERE r.status NOT IN ('collected','cancelled'))) INTO v_reservations FROM public.ff49_reservations r WHERE public.ff_business_date(r.created_at) BETWEEN v_start AND v_end AND (p_branch IS NULL OR r.branch_id=p_branch) AND (v_role='manager' OR r.branch_id=ANY(v_branches)) AND v_role IN ('manager','supervisor','customer_service') AND (v_role<>'customer_service' OR r.created_by=v_uid) AND p_driver IS NULL AND NOT v_partial;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.rated_at DESC),'[]'::jsonb) INTO v_quality FROM (SELECT o.order_number,b.name branch_name,r.rater_role,r.stars,CASE WHEN v_role='manager' THEN r.note ELSE NULL END AS note,r.rated_at FROM public.ff51_driver_ratings r JOIN public.ff_orders o ON o.id=r.order_id JOIN public.ff_branches b ON b.id=o.branch_id WHERE v_role IN ('manager','supervisor') AND r.stars<=2 AND public.ff_business_date(r.rated_at) BETWEEN v_start AND v_end AND (p_branch IS NULL OR o.branch_id=p_branch) AND (v_role='manager' OR o.branch_id=ANY(v_branches)) AND (p_driver IS NULL OR r.driver_id=p_driver) AND ff_private.a10_order_filter(o.id,o.created_by,coalesce(nullif(btrim(o.area_snapshot),''),'غير محددة'),o.status,p_staff,p_area,p_item,p_status) ORDER BY r.rated_at DESC LIMIT 100) q;
 RETURN v_core||jsonb_build_object(
   'generated_at',now(),'filters',jsonb_build_object('branch',p_branch,'driver',p_driver,'staff',p_staff,'area',p_area,'item',p_item,'status',p_status),'partial_order_filter',v_partial,
   'reservation_summary',v_reservations,'internal_low_ratings',v_quality,
   'finance_evidence',jsonb_build_object('confirmed_received',(SELECT sum((x->>'confirmed_received')::numeric) FROM jsonb_array_elements(v_settlements) x),'confirmed_difference',(SELECT sum((x->>'confirmed_difference')::numeric) FROM jsonb_array_elements(v_settlements) x),'draft_received',(SELECT sum((x->>'draft_received')::numeric) FROM jsonb_array_elements(v_settlements) x),'closed_statements',coalesce((SELECT sum((x->>'closed_statements')::int) FROM jsonb_array_elements(v_settlements) x),0),'fee_collection_confirmed',(SELECT sum((x->>'confirmed_delivery_fees')::numeric) FROM jsonb_array_elements(v_settlements) x),'fees_need_review',coalesce((SELECT sum((x->>'fees_need_review')::int) FROM jsonb_array_elements(v_settlements) x),0),'basis','settlement_calendar_date'),
   'attendance',v_attendance,'complaints',v_complaints,'grievances',v_grievances,
   'internal_driver_ratings',v_internal_ratings,'settlements',v_settlements,
   'comparison',v_comparison,'approval',coalesce(v_approval,'{}'::jsonb),
   'data_warnings',jsonb_build_array(
     'الخصومات تقديرية من فرق مبالغ الأصناف والتوصيل والفاتورة، وليست قيوداً محاسبية.',
     'الدوام محسوب من جلسات الحضور الجديدة، ولا يمكن استعادة الساعات القديمة التي لم توثق.',
     'التأخير هنا يُقاس بتجاوز 60 دقيقة من الإنشاء إلى التسليم.',
     'الرسوم المذكورة مستحقة وليست دليلاً على تحصيل نقدي فعلي. التحصيل المؤكد من التسويات المقفلة فقط ويستند إلى تاريخ التسوية المحلي؛ رسوم التوصيل المؤكدة تستند إلى إثبات مستقل داخل التسوية المقفلة.',
     'التسويات والدوام والحجوزات لا تنسب إلى فلتر صنف أو منطقة أو موظف أو حالة طلب؛ تظهر غير متاحة عند استخدام هذه الفلاتر.',
     'طلبات 02:00 إلى 07:59 مستبعدة من التقرير الرئيسي ولا تُحذف من قاعدة البيانات.'
   )
 );
END $function$;

REVOKE ALL ON FUNCTION ff_private.a10_report_core(date,date,uuid,uuid,uuid,text,text,text) FROM PUBLIC,anon,authenticated;
CREATE TABLE ff_private.a10_report_section_grants(user_id uuid REFERENCES public.ff_profiles(user_id) ON DELETE CASCADE,section text CHECK(section IN ('summary','finance','orders','branches','drivers','staff','areas','items','ratings','cases','attendance','analytics','comparisons','approval')),allowed boolean NOT NULL,changed_by uuid NOT NULL,changed_at timestamptz NOT NULL DEFAULT clock_timestamp(),PRIMARY KEY(user_id,section));
ALTER TABLE ff_private.a10_report_section_grants ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ff_private.a10_report_section_grants FROM PUBLIC,anon,authenticated;
CREATE TABLE ff_private.a10_report_grant_audit(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,user_id uuid NOT NULL,section text NOT NULL,allowed boolean,actor_id uuid NOT NULL,created_at timestamptz NOT NULL DEFAULT clock_timestamp());
ALTER TABLE ff_private.a10_report_grant_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ff_private.a10_report_grant_audit FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.ff_a10_report_grant(p_user uuid,p_section text,p_allowed boolean)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT public.ff_is_manager() THEN RAISE EXCEPTION 'تفويض التقارير للمدير العام فقط' USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT FROM public.ff_profiles p WHERE p.user_id=p_user AND p.active AND p.role<>'manager') OR p_section NOT IN ('summary','finance','orders','branches','drivers','staff','areas','items','ratings','cases','attendance','analytics','comparisons','approval') THEN RAISE EXCEPTION 'حساب أو قسم غير صالح';END IF;
 IF p_allowed IS NULL THEN DELETE FROM ff_private.a10_report_section_grants WHERE user_id=p_user AND section=p_section;
 ELSE INSERT INTO ff_private.a10_report_section_grants(user_id,section,allowed,changed_by) VALUES(p_user,p_section,p_allowed,auth.uid()) ON CONFLICT(user_id,section) DO UPDATE SET allowed=excluded.allowed,changed_by=excluded.changed_by,changed_at=clock_timestamp();END IF;
 INSERT INTO ff_private.a10_report_grant_audit(user_id,section,allowed,actor_id) VALUES(p_user,p_section,p_allowed,auth.uid());RETURN true;
END $$;
CREATE OR REPLACE FUNCTION public.ff_a10_report_grants()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT public.ff_is_manager() THEN RAISE EXCEPTION 'تفويض التقارير للمدير العام فقط' USING ERRCODE='42501';END IF;
 RETURN jsonb_build_object('accounts',coalesce((SELECT jsonb_agg(jsonb_build_object('id',p.user_id,'name',p.display_name,'role',p.role) ORDER BY p.display_name) FROM public.ff_profiles p WHERE p.active AND p.role<>'manager'),'[]'::jsonb),'grants',coalesce((SELECT jsonb_agg(to_jsonb(g)-'changed_by') FROM ff_private.a10_report_section_grants g),'[]'::jsonb));
END $$;
CREATE OR REPLACE FUNCTION public.ff_a10_reporting_center(p_from date DEFAULT NULL,p_to date DEFAULT NULL,p_branch uuid DEFAULT NULL,p_driver uuid DEFAULT NULL,p_staff uuid DEFAULT NULL,p_area text DEFAULT NULL,p_item text DEFAULT NULL,p_status text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE r jsonb; a text[]; t jsonb; role_name text; k text; money boolean; allowed_keys text[];
BEGIN
 r:=ff_private.a10_report_core(p_from,p_to,p_branch,p_driver,p_staff,nullif(btrim(p_area),''),nullif(btrim(p_item),''),nullif(btrim(p_status),''));
 role_name:=r->>'role';
 SELECT coalesce(array_agg(x),'{}') INTO a FROM jsonb_array_elements_text(r->'available_sections') x WHERE NOT EXISTS(SELECT FROM ff_private.a10_report_section_grants g WHERE g.user_id=auth.uid() AND g.section=x AND NOT g.allowed);
 IF cardinality(a)=0 THEN RAISE EXCEPTION 'لا توجد أقسام تقارير مخولة' USING ERRCODE='42501';END IF;
 r:=jsonb_set(r,'{available_sections}',to_jsonb(a));t:=r->'totals';
 money:=('finance'=ANY(a) OR (role_name='driver' AND 'drivers'=ANY(a)));
 IF NOT money THEN
  t:=t-ARRAY['item_sales','delivery_fees','discounts_estimate','net','average_order'];
  r:=r-ARRAY['finance_evidence','settlements','invoice_review'];
  IF r ? 'additions' THEN r:=jsonb_set(r,'{additions}',(r->'additions')-'invoiced_value');END IF;
  IF r ? 'branch_rows' THEN r:=jsonb_set(r,'{branch_rows}',coalesce((SELECT jsonb_agg(z-ARRAY['net','average_order']) FROM jsonb_array_elements(r->'branch_rows') z),'[]'));END IF;
  IF r ? 'days' THEN r:=jsonb_set(r,'{days}',coalesce((SELECT jsonb_agg(z-'net') FROM jsonb_array_elements(r->'days') z),'[]'));END IF;
  IF r ? 'free_delivery_orders' THEN r:=jsonb_set(r,'{free_delivery_orders}',coalesce((SELECT jsonb_agg(z-'total_amount') FROM jsonb_array_elements(r->'free_delivery_orders') z),'[]'));END IF;
  IF r ? 'drivers' THEN r:=jsonb_set(r,'{drivers}',coalesce((SELECT jsonb_agg(z-ARRAY['delivery_fees_due','invoice_value','average_order']) FROM jsonb_array_elements(r->'drivers') z),'[]'));END IF;
  IF r ? 'items' THEN r:=jsonb_set(r,'{items}',coalesce((SELECT jsonb_agg(z-'revenue') FROM jsonb_array_elements(r->'items') z),'[]'));END IF;
  IF r ? 'comparison' THEN r:=jsonb_set(r,'{comparison}',coalesce((SELECT jsonb_object_agg(key,value-'net') FROM jsonb_each(r->'comparison')),'{}'));END IF;
 END IF;
 IF NOT 'ratings'=ANY(a) THEN t:=t-ARRAY['rating_avg','rating_min','rating_max','low_ratings'];r:=r-ARRAY['low_ratings','internal_low_ratings','internal_driver_ratings'];IF r ? 'drivers' THEN r:=jsonb_set(r,'{drivers}',coalesce((SELECT jsonb_agg(z-'average_rating') FROM jsonb_array_elements(r->'drivers') z),'[]'));END IF;END IF;
 IF NOT 'areas'=ANY(a) THEN t:=t-ARRAY['new_customers','repeat_customers','new_areas'];r:=r-ARRAY['areas','customers'];END IF;
 IF NOT 'orders'=ANY(a) THEN r:=r-ARRAY['cancellations','late_orders','free_delivery_orders','fastest','phase_times','dispatch','additions','invoice_review'];END IF;
 IF NOT ('orders'=ANY(a) OR 'summary'=ANY(a)) THEN r:=r-'reservation_summary';END IF;
 IF NOT 'branches'=ANY(a) THEN r:=r-'branch_rows';END IF;
 IF NOT 'drivers'=ANY(a) THEN r:=r-'drivers';END IF;
 IF NOT 'staff'=ANY(a) THEN r:=r-'service_staff';END IF;
 IF NOT 'items'=ANY(a) THEN r:=r-'items';END IF;
 IF NOT 'cases'=ANY(a) THEN r:=r-ARRAY['complaints','grievances'];END IF;
 IF NOT 'attendance'=ANY(a) THEN r:=r-'attendance';END IF;
 IF NOT 'analytics'=ANY(a) THEN r:=r-ARRAY['days','hourly'];END IF;
 IF NOT 'comparisons'=ANY(a) THEN r:=r-'comparison';END IF;
 IF NOT 'approval'=ANY(a) THEN r:=r-'approval';END IF;
 IF role_name<>'manager' THEN
  IF r ? 'low_ratings' THEN r:=jsonb_set(r,'{low_ratings}',coalesce((SELECT jsonb_agg(z-'rating_note') FROM jsonb_array_elements(r->'low_ratings') z),'[]'));END IF;
  IF r ? 'customers' THEN r:=jsonb_set(r,'{customers}',coalesce((SELECT jsonb_agg(z-'customer_name') FROM jsonb_array_elements(r->'customers') z),'[]'));END IF;
 END IF;
 RETURN jsonb_set(r,'{totals}',t);
END $$;
CREATE OR REPLACE FUNCTION public.ff76_reporting_center(p_from date DEFAULT NULL,p_to date DEFAULT NULL,p_branch uuid DEFAULT NULL,p_driver uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.ff_a10_reporting_center(p_from,p_to,p_branch,p_driver,NULL,NULL,NULL,NULL)
$$;
REVOKE ALL ON FUNCTION public.ff_a10_reporting_center(date,date,uuid,uuid,uuid,text,text,text),public.ff_a10_report_grants(),public.ff_a10_report_grant(uuid,text,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a10_reporting_center(date,date,uuid,uuid,uuid,text,text,text),public.ff_a10_report_grants(),public.ff_a10_report_grant(uuid,text,boolean) TO authenticated;
