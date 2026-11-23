
CREATE OR REPLACE FUNCTION public.ff76_reporting_center(
 p_from date DEFAULT NULL,p_to date DEFAULT NULL,p_branch uuid DEFAULT NULL,p_driver uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $ff76$
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
BEGIN
 SELECT p.role INTO v_role FROM public.ff_profiles AS p WHERE p.user_id=v_uid AND p.active;
 IF v_role IS NULL OR v_role NOT IN('manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen')
 THEN RAISE EXCEPTION 'حساب موظف فعّال مطلوب' USING ERRCODE='42501'; END IF;
 IF v_role IN('supervisor','customer_service') AND NOT public.ff38_permission_allowed(v_uid,'view_reports')
 THEN RAISE EXCEPTION 'ليست لديك صلاحية التقارير' USING ERRCODE='42501'; END IF;
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
   IF v_role='customer_service' AND coalesce(cardinality(v_branches),0)=0 THEN
     SELECT array_agg(DISTINCT o.branch_id) INTO v_branches FROM public.ff_orders AS o WHERE o.created_by=v_uid;
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
 WITH scoped AS MATERIALIZED (
  SELECT o.id,o.order_number,o.branch_id,b.name AS branch_name,o.business_date AS work_day,
   o.created_at,o.created_by,o.customer_id,o.phone_snapshot,
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
     AND older.created_at<o.created_at)) AS first_customer,
   (nullif(btrim(o.area_snapshot),'') IS NOT NULL AND NOT EXISTS
    (SELECT 1 FROM public.ff_orders AS older WHERE lower(btrim(older.area_snapshot))=lower(btrim(o.area_snapshot))
     AND older.created_at<o.created_at)) AS first_area
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
 ), product_rows AS (
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
 'totals',(SELECT jsonb_build_object(
   'orders',count(*),'delivered',count(*) FILTER(WHERE status='delivered'),
   'cancelled',count(*) FILTER(WHERE status='cancelled'),
   'pending',count(*) FILTER(WHERE status NOT IN('delivered','cancelled')),
   'late',count(*) FILTER(WHERE status='delivered' AND delivery_at-created_at>interval '60 minutes'),
   'free_delivery',count(*) FILTER(WHERE fee_amount=0),
   'new_customers',count(*) FILTER(WHERE first_customer),
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
        round(avg(s.invoice_amount+s.invoiced_addons) FILTER(WHERE s.status='delivered'),1) AS average_order,
        round(avg(extract(epoch from(s.delivery_at-s.created_at))/60)
          FILTER(WHERE s.status='delivered' AND s.delivery_at>=s.created_at),1) AS average_minutes,
        round(avg(s.rating),2) AS average_rating
        FROM scoped AS s JOIN public.ff_drivers AS d ON d.id=s.delivery_driver_id
        GROUP BY s.delivery_driver_id,d.name,s.branch_id ORDER BY delivered DESC LIMIT 100) AS x),'[]'::jsonb)
        ELSE '[]'::jsonb END,
 'service_staff',CASE WHEN v_role IN('manager','supervisor','customer_service') THEN coalesce(
    (SELECT jsonb_agg(to_jsonb(x) ORDER BY x.orders DESC)
      FROM (SELECT coalesce(p.display_name,'غير محدد') AS staff_name,count(*) AS orders
          FROM scoped AS s LEFT JOIN public.ff_profiles AS p ON p.user_id=s.created_by
          GROUP BY p.display_name ORDER BY orders DESC LIMIT 70) AS x),'[]'::jsonb)
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
    AND (p_driver IS NULL OR w.driver_id=p_driver)
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
   ORDER BY gr.created_at DESC LIMIT 80
 ) AS x;
 SELECT coalesce(to_jsonb(a)-'id'-'report_day'-'scope_key'-'branch_id'-'approved_by','{}'::jsonb)
 INTO v_approval FROM public.ff76_report_approvals AS a
 WHERE v_role='manager' AND a.report_day=v_end AND a.scope_key=coalesce(p_branch::text,'all');
 WITH comparison AS(
 SELECT o.business_date AS work_day,count(*) AS orders,
   count(*) FILTER(WHERE o.status='delivered') AS delivered,
   coalesce(sum(o.total) FILTER(WHERE o.status='delivered'),0) AS net
 FROM public.ff_orders AS o
 LEFT JOIN public.ff38_delivery_tasks AS t ON t.order_id=o.id
 WHERE o.order_type='delivery' AND o.business_date IN(v_end,v_end-1,v_end-7)
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
 GROUP BY o.business_date
 )
 SELECT jsonb_build_object(
   'today',coalesce((SELECT to_jsonb(x) FROM comparison AS x WHERE x.work_day=v_end),'{}'::jsonb),
   'yesterday',coalesce((SELECT to_jsonb(x) FROM comparison AS x WHERE x.work_day=v_end-1),'{}'::jsonb),
   'last_week',coalesce((SELECT to_jsonb(x) FROM comparison AS x WHERE x.work_day=v_end-7),'{}'::jsonb)
 ) INTO v_comparison;
 
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.driver_name),'[]'::jsonb)
 INTO v_internal_ratings FROM (
   SELECT d.name AS driver_name,count(*) AS ratings,
    round(avg(r.stars),2) AS average_stars,
    count(*) FILTER(WHERE r.stars<=2) AS low_ratings
   FROM public.ff51_driver_ratings AS r
   JOIN public.ff_drivers AS d ON d.id=r.driver_id
   WHERE v_role IN('manager','supervisor','driver')
     AND public.ff_business_date(r.rated_at) BETWEEN v_start AND v_end
     AND (p_branch IS NULL OR d.branch_id=p_branch)
     AND (v_role='manager' OR d.branch_id=ANY(v_branches))
     AND (v_role<>'driver' OR r.driver_id=v_driver)
     AND (p_driver IS NULL OR r.driver_id=p_driver)
   GROUP BY d.name
 ) AS x;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.driver_name),'[]'::jsonb)
 INTO v_settlements FROM (
   SELECT d.name AS driver_name,count(*) AS statements,
      coalesce(sum(s.cash_due),0) AS cash_due,
      coalesce(sum(s.cash_received),0) AS cash_received,
      count(*) FILTER(WHERE s.status='closed') AS closed_statements
   FROM public.ff42_driver_settlements AS s
   JOIN public.ff_drivers AS d ON d.id=s.driver_id
   WHERE v_role IN('manager','supervisor','driver')
     AND s.settlement_date BETWEEN v_start AND v_end
     AND (p_branch IS NULL OR s.branch_id=p_branch)
     AND (v_role='manager' OR s.branch_id=ANY(v_branches))
     AND (v_role<>'driver' OR s.driver_id=v_driver)
     AND (p_driver IS NULL OR s.driver_id=p_driver)
   GROUP BY d.name
 ) AS x;
 RETURN v_core||jsonb_build_object(
   'attendance',v_attendance,'complaints',v_complaints,'grievances',v_grievances,
   'internal_driver_ratings',v_internal_ratings,'settlements',v_settlements,
   'comparison',v_comparison,'approval',coalesce(v_approval,'{}'::jsonb),
   'data_warnings',jsonb_build_array(
     'الخصومات تقديرية من فرق مبالغ الأصناف والتوصيل والفاتورة، وليست قيوداً محاسبية.',
     'الدوام محسوب من جلسات الحضور الجديدة، ولا يمكن استعادة الساعات القديمة التي لم توثق.',
     'التأخير هنا يُقاس بتجاوز 60 دقيقة من الإنشاء إلى التسليم.',
     'الرسوم المذكورة مستحقة وليست دليلاً على تحصيل نقدي فعلي.',
     'طلبات 02:00 إلى 07:59 مستبعدة من التقرير الرئيسي ولا تُحذف من قاعدة البيانات.'
   )
 );
END $ff76$;
REVOKE ALL ON FUNCTION public.ff76_reporting_center(date,date,uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff76_reporting_center(date,date,uuid,uuid) TO authenticated;
