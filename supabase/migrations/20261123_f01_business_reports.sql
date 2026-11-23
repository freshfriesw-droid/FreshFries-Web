-- F-01: report & archive business-date refactor on the same staging branch.
-- Read only reporting functions; preserves all existing role restrictions and outputs.
BEGIN;

-- ff27_quality (preserved signature and authorization)
CREATE OR REPLACE FUNCTION public.ff27_quality(p_from date, p_to date, p_branch uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_documents bigint;v_undocumented bigint;v_cash numeric;v_rated bigint;v_average numeric;v_low bigint;v_items jsonb;
BEGIN
 IF NOT public.ff_is_manager() OR NOT public.ff38_permission_allowed(auth.uid(),'view_reports') THEN RAISE EXCEPTION 'هذا التقرير لمدير النظام المخول فقط' USING ERRCODE='42501'; END IF;
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_to-p_from>366 THEN RAISE EXCEPTION 'الفترة غير صالحة أو تتجاوز سنة'; END IF;
 IF p_branch IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.ff_branches WHERE id=p_branch) THEN RAISE EXCEPTION 'الفرع غير موجود'; END IF;
 SELECT count(*) FILTER (WHERE NULLIF(pg_catalog.btrim(COALESCE(r.invoice_ref,'')),'') IS NOT NULL),
 count(*) FILTER (WHERE NULLIF(pg_catalog.btrim(COALESCE(r.invoice_ref,'')),'') IS NULL)
 INTO v_documents,v_undocumented FROM public.ff49_cashier_receipts r JOIN public.ff_orders o ON o.id=r.order_id
 WHERE r.invoiced_at IS NOT NULL AND o.business_date BETWEEN p_from AND p_to
 AND (p_branch IS NULL OR o.branch_id=p_branch);
 SELECT COALESCE(SUM(s.cash_received),0) INTO v_cash FROM public.ff42_driver_settlements s
 WHERE s.status='closed' AND s.settlement_date BETWEEN p_from AND p_to AND (p_branch IS NULL OR s.branch_id=p_branch);
 SELECT count(*) FILTER (WHERE o.rating IS NOT NULL),pg_catalog.round(avg(o.rating::numeric),2),
 count(*) FILTER (WHERE o.rating IS NOT NULL AND o.rating<=2)
 INTO v_rated,v_average,v_low FROM public.ff_orders o
 WHERE o.business_date BETWEEN p_from AND p_to
 AND (p_branch IS NULL OR o.branch_id=p_branch) AND o.status='delivered';
 SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('name',d.item_name,'qty',d.qty) ORDER BY d.qty DESC),'[]'::jsonb)
 INTO v_items FROM (
 SELECT i.item_name,SUM(i.quantity) qty FROM public.ff_order_items i JOIN public.ff_orders o ON o.id=i.order_id
 WHERE o.business_date BETWEEN p_from AND p_to
 AND (p_branch IS NULL OR o.branch_id=p_branch) AND o.status='delivered'
 GROUP BY i.item_name ORDER BY qty DESC LIMIT 50
 ) d;
 RETURN pg_catalog.jsonb_build_object('documented',v_documents,'undocumented',v_undocumented,
 'confirmed_cash',v_cash,'rated',v_rated,'average',v_average,'low',v_low,'items',v_items);
END;
$function$;

-- ff40_operations_report (preserved signature and authorization)
CREATE OR REPLACE FUNCTION public.ff40_operations_report(p_from date DEFAULT NULL::date, p_to date DEFAULT NULL::date, p_branch uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 DECLARE
  v_uid uuid:=auth.uid();
   v_role text;
    v_driver uuid;
     v_start date:=COALESCE(p_from, (public.ff_business_date(now())-6));
      v_end date:=COALESCE(p_to, public.ff_business_date(now()));
       v_output jsonb;
       BEGIN
        SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=v_uid AND active=true;
         IF v_role IS NULL OR NOT public.ff38_permission_allowed(v_uid,'view_reports') THEN
            RAISE EXCEPTION 'ليس لديك صلاحية عرض التقارير' USING ERRCODE='42501';
             END IF;
              IF v_start IS NULL OR v_end IS NULL OR v_start>v_end OR v_end-v_start>89
                  OR v_end>public.ff_business_date(now()) THEN
                     RAISE EXCEPTION 'اختر فترة صحيحة لا تتجاوز 90 يوماً ولا تنتهي في المستقبل';
                      END IF;
                       IF p_branch IS NOT NULL AND NOT EXISTS (
                          SELECT 1 FROM public.ff_branches WHERE id=p_branch
                           ) THEN RAISE EXCEPTION 'الفرع غير معروف'; END IF;
                            IF v_role='driver' THEN
                               SELECT l.driver_id INTO v_driver FROM public.ff38_driver_links l
                                  JOIN public.ff_drivers d ON d.id=l.driver_id AND d.active=true
                                     WHERE l.user_id=v_uid;
                                        IF v_driver IS NULL THEN RAISE EXCEPTION 'حساب الموصل غير مربوط' USING ERRCODE='42501'; END IF;
                                         END IF;

                                          WITH scoped AS MATERIALIZED (
                                            SELECT o.id,o.branch_id, b.name AS branch_name,
                                                     o.business_date AS day,
                                                              o.total,o.delivery_fee,o.status,o.created_at,
                                                                       t.order_id AS task_order_id,t.driver_id,t.assigned_at,t.delivered_at,
                                                                                COALESCE((SELECT sum(a.amount) FROM public.ff38_order_additions a
                                                                                           WHERE a.order_id=o.id AND a.status='invoiced'),0)::numeric AS invoiced_additions
                                                                                             FROM public.ff_orders o
                                                                                               JOIN public.ff_branches b ON b.id=o.branch_id
                                                                                                 LEFT JOIN public.ff38_delivery_tasks t ON t.order_id=o.id
                                                                                                   WHERE o.order_type='delivery'
                                                                                                      AND o.business_date BETWEEN v_start AND v_end
                                                                                                         
                                                                                                            AND (p_branch IS NULL OR o.branch_id=p_branch)
                                                                                                               AND (v_role IN ('manager','customer_service','supervisor')
                                                                                                                    OR (v_role='cashier' AND EXISTS (
                                                                                                                           SELECT 1 FROM public.ff_user_branches ub
                                                                                                                                  WHERE ub.user_id=v_uid AND ub.branch_id=o.branch_id))
                                                                                                                                       OR (v_role='driver' AND t.driver_id=v_driver))
                                                                                                                                        ),
                                                                                                                                         totals AS (
                                                                                                                                           SELECT count(*)::integer AS orders,
                                                                                                                                              count(*) FILTER(WHERE status='delivered')::integer AS delivered,
                                                                                                                                                 count(*) FILTER(WHERE status='cancelled')::integer AS cancelled,
                                                                                                                                                    count(*) FILTER(WHERE status NOT IN ('delivered','cancelled') AND task_order_id IS NULL)::integer AS awaiting_assignment,
                                                                                                                                                       count(*) FILTER(WHERE status NOT IN ('delivered','cancelled') AND task_order_id IS NOT NULL)::integer AS in_progress,
                                                                                                                                                          COALESCE(sum(total),0)::numeric AS total_order_value,
                                                                                                                                                             COALESCE(sum(total+invoiced_additions) FILTER(WHERE status='delivered'),0)::numeric AS delivered_order_value,
                                                                                                                                                                COALESCE(sum(invoiced_additions),0)::numeric AS invoiced_additions,
                                                                                                                                                                   COALESCE(sum(delivery_fee) FILTER(WHERE status='delivered'),0)::numeric AS delivered_delivery_fees,
                                                                                                                                                                      round(avg(EXTRACT(EPOCH FROM (delivered_at-assigned_at))/60)
                                                                                                                                                                           FILTER(WHERE status='delivered' AND delivered_at IS NOT NULL AND assigned_at IS NOT NULL),1) AS avg_delivery_minutes
                                                                                                                                                                             FROM scoped
                                                                                                                                                                              ),
                                                                                                                                                                               branch_rows AS (
                                                                                                                                                                                 SELECT branch_id,branch_name,count(*)::integer AS orders,
                                                                                                                                                                                    count(*) FILTER(WHERE status='delivered')::integer AS delivered,
                                                                                                                                                                                       count(*) FILTER(WHERE status='cancelled')::integer AS cancelled,
                                                                                                                                                                                          COALESCE(sum(total+invoiced_additions) FILTER(WHERE status='delivered'),0)::numeric AS delivered_order_value
                                                                                                                                                                                            FROM scoped GROUP BY branch_id,branch_name
                                                                                                                                                                                             ),
                                                                                                                                                                                              day_rows AS (
                                                                                                                                                                                                SELECT day,count(*)::integer AS orders,
                                                                                                                                                                                                   count(*) FILTER(WHERE status='delivered')::integer AS delivered,
                                                                                                                                                                                                      count(*) FILTER(WHERE status='cancelled')::integer AS cancelled,
                                                                                                                                                                                                         COALESCE(sum(total+invoiced_additions) FILTER(WHERE status='delivered'),0)::numeric AS delivered_order_value
                                                                                                                                                                                                           FROM scoped GROUP BY day
                                                                                                                                                                                                            ),
                                                                                                                                                                                                             driver_rows AS (
                                                                                                                                                                                                               SELECT s.driver_id,d.name AS driver_name,s.branch_id,
                                                                                                                                                                                                                  count(*)::integer AS assigned,
                                                                                                                                                                                                                     count(*) FILTER(WHERE s.status='delivered')::integer AS delivered,
                                                                                                                                                                                                                        round(avg(EXTRACT(EPOCH FROM (s.delivered_at-s.assigned_at))/60)
                                                                                                                                                                                                                               FILTER(WHERE s.status='delivered' AND s.delivered_at IS NOT NULL),1) AS avg_delivery_minutes
                                                                                                                                                                                                                                 FROM scoped s JOIN public.ff_drivers d ON d.id=s.driver_id
                                                                                                                                                                                                                                   WHERE s.driver_id IS NOT NULL
                                                                                                                                                                                                                                     GROUP BY s.driver_id,d.name,s.branch_id
                                                                                                                                                                                                                                      )
                                                                                                                                                                                                                                       SELECT pg_catalog.jsonb_build_object(
                                                                                                                                                                                                                                         'from',v_start,'to',v_end,'branch_id',p_branch,
                                                                                                                                                                                                                                           'currency','YER',
                                                                                                                                                                                                                                             'totals',(SELECT to_jsonb(t) FROM totals t),
                                                                                                                                                                                                                                               'branches',COALESCE((SELECT pg_catalog.jsonb_agg(to_jsonb(x) ORDER BY x.branch_name) FROM branch_rows x),'[]'::jsonb),
                                                                                                                                                                                                                                                 'days',COALESCE((SELECT pg_catalog.jsonb_agg(to_jsonb(x) ORDER BY x.day) FROM day_rows x),'[]'::jsonb),
                                                                                                                                                                                                                                                   'drivers',COALESCE((SELECT pg_catalog.jsonb_agg(to_jsonb(x) ORDER BY x.delivered DESC,x.driver_name) FROM driver_rows x),'[]'::jsonb)
                                                                                                                                                                                                                                                    ) INTO v_output;
                                                                                                                                                                                                                                                     RETURN v_output;
                                                                                                                                                                                                                                                     END $function$;

-- ff51_order_archive (preserved signature and authorization)
CREATE OR REPLACE FUNCTION public.ff51_order_archive(p_from date, p_to date, p_branch uuid DEFAULT NULL::uuid, p_status text DEFAULT NULL::text, p_limit integer DEFAULT 60, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                                           DECLARE v_role text;v_rows jsonb;v_total bigint;
                                                           BEGIN
                                                            SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active=true;
                                                             IF v_role NOT IN ('manager','customer_service','cashier','supervisor') THEN
                                                               RAISE EXCEPTION 'غير مصرح بالأرشيف' USING ERRCODE='42501'; END IF;
                                                                IF p_from IS NULL OR p_to IS NULL OR p_to<p_from OR p_to-p_from>366 THEN
                                                                  RAISE EXCEPTION 'الفترة مطلوبة وبحد أقصى سنة'; END IF;
                                                                   IF p_status IS NOT NULL AND p_status NOT IN ('delivered','cancelled','sent','new') THEN
                                                                     RAISE EXCEPTION 'فلتر الحالة غير مدعوم'; END IF;
                                                                      SELECT count(*) INTO v_total FROM public.ff_orders o
                                                                       WHERE o.order_type='delivery'
                                                                        AND o.business_date BETWEEN p_from AND p_to
                                                                         
                                                                          AND (p_branch IS NULL OR o.branch_id=p_branch)
                                                                           AND (p_status IS NULL OR o.status=p_status)
                                                                            AND (v_role IN ('manager','customer_service') OR EXISTS(
                                                                              SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid() AND ub.branch_id=o.branch_id));
                                                                               SELECT coalesce(jsonb_agg(jsonb_build_object(
                                                                                 'id',o.id,'number',o.order_number,'branch_id',o.branch_id,'phone',o.phone_snapshot,
                                                                                   'customer_name',coalesce(d.customer_name,''),'channel',coalesce(d.channel,'phone'),
                                                                                     'address',coalesce(d.full_address,o.area_snapshot),'status',o.status,
                                                                                       'created_at',o.created_at,'notes',o.notes,'items_total',o.items_total,
                                                                                         'delivery_fee',o.delivery_fee,'total',o.total,'driver_name',dr.name,
                                                                                           'cashier_stage',t.cashier_stage,'driver_phase',t.phase,
                                                                                             'items',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',it.item_name,'qty',it.quantity,'price',it.unit_price)),'[]'::jsonb)
                                                                                                        FROM public.ff_order_items it WHERE it.order_id=o.id),
                                                                                                          'events',(SELECT coalesce(jsonb_agg(to_jsonb(ev)),'[]'::jsonb)
                                                                                                                     FROM (SELECT * FROM public.ff_order_events e WHERE e.order_id=o.id LIMIT 100) ev),
                                                                                                                       'changes',(SELECT coalesce(jsonb_agg(jsonb_build_object('status',c.status,'old_items',c.old_items,
                                                                                                                             'new_items',c.new_items,'reason',c.reason,'requested_at',c.requested_at,'external_invoice_ref',c.external_invoice_ref)
                                                                                                                                   ORDER BY c.requested_at),'[]'::jsonb)
                                                                                                                                         FROM public.ff50_order_changes c WHERE c.order_id=o.id),
                                                                                                                                           'additions',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',a.id,'status',a.status,'amount',a.amount,'created_at',a.created_at)),'[]'::jsonb)
                                                                                                                                                 FROM public.ff38_order_additions a WHERE a.order_id=o.id)
                                                                                                                                                  ) ORDER BY o.created_at DESC),'[]'::jsonb) INTO v_rows
                                                                                                                                                   FROM (SELECT * FROM public.ff_orders o
                                                                                                                                                    WHERE o.order_type='delivery'
                                                                                                                                                     AND o.business_date BETWEEN p_from AND p_to
                                                                                                                                                      
                                                                                                                                                       AND (p_branch IS NULL OR o.branch_id=p_branch)
                                                                                                                                                        AND (p_status IS NULL OR o.status=p_status)
                                                                                                                                                         AND (v_role IN ('manager','customer_service') OR EXISTS(
                                                                                                                                                           SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid() AND ub.branch_id=o.branch_id))
                                                                                                                                                            ORDER BY created_at DESC LIMIT greatest(1,least(coalesce(p_limit,60),150)) OFFSET greatest(0,least(coalesce(p_offset,0),100000))) o
                                                                                                                                                             LEFT JOIN public.ff49_order_details d ON d.order_id=o.id
                                                                                                                                                              LEFT JOIN public.ff38_delivery_tasks t ON t.order_id=o.id
                                                                                                                                                               LEFT JOIN public.ff_drivers dr ON dr.id=t.driver_id;
                                                                                                                                                                RETURN jsonb_build_object('total',v_total,'rows',v_rows,'offset',greatest(0,p_offset));
                                                                                                                                                                END $function$;

-- ff_luxe_completed_universal (preserved signature and authorization)
CREATE OR REPLACE FUNCTION public.ff_luxe_completed_universal(p_from date DEFAULT NULL::date, p_to date DEFAULT NULL::date, p_branch uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 30, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_start date:=coalesce(p_from,public.ff_business_date(now()));
 v_end date:=coalesce(p_to,public.ff_business_date(now()));
 v_limit integer:=least(greatest(coalesce(p_limit,30),1),60);
 v_offset integer:=least(greatest(coalesce(p_offset,0),0),10000);
 v_role text;v_rows jsonb;v_found int;v_branches jsonb;v_desk text;
begin
 select role into v_role from public.ff_profiles
 where user_id=auth.uid() and active;
 if v_role not in ('manager','supervisor','customer_service','cashier','driver','assembly') or v_role is null
 then raise exception 'حساب غير مخوّل' using errcode='42501';end if;
 if v_start>v_end or v_start<'2020-01-01'::date or v_end>'2100-01-01'::date
    or v_end-v_start>366 then raise exception 'اختر نطاق تاريخ صحيحًا لا يتجاوز 366 يومًا';end if;
 if p_branch is not null and not exists(
  select 1 from public.ff_branches where id=p_branch and active
 ) then raise exception 'فرع غير صحيح';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',b.id,'code',b.code,'name',b.name)
                  order by b.code),'[]'::jsonb)
 into v_branches from public.ff_branches b where b.active and (
  v_role in ('manager','supervisor')
  or (v_role='customer_service' and (
     not exists(select 1 from public.ff_user_branches ub where ub.user_id=auth.uid())
     or exists(select 1 from public.ff_user_branches ub where ub.user_id=auth.uid() and ub.branch_id=b.id)))
  or (v_role='cashier' and exists(select 1 from public.ff_user_branches ub where ub.user_id=auth.uid() and ub.branch_id=b.id))
  or (v_role='assembly' and exists(select 1 from public.ff_v9_assembly_access a where a.user_id=auth.uid() and a.branch_id=b.id and a.enabled))
  or (v_role='driver' and exists(select 1 from public.ff38_driver_links l join public.ff_drivers d on d.id=l.driver_id where l.user_id=auth.uid() and d.branch_id=b.id))
 );
 select sd.desk_code into v_desk from public.ff_luxe_cashier_staff_desks sd where sd.user_id=auth.uid();
 with scoped as (
   select o.id,o.order_number,o.branch_id,o.status,o.created_at,o.delivered_at,
      o.phone_snapshot,o.area_snapshot,o.notes,o.cancel_reason,
      o.items_total,o.delivery_fee,o.total,o.driver_id as fallback_driver,
      t.driver_id,t.phase,t.cashier_stage,t.assigned_at,t.delivered_at as task_delivered_at,
      coalesce(nullif(dt.customer_name,''),nullif(c.name,''),'عميل') as customer_name,
      coalesce(nullif(dt.full_address,''),nullif(o.area_snapshot,''),'') as address,
      coalesce(nullif(d.name,''),'لم يحدد') as driver_name,
      coalesce(nullif(created_staff.display_name,''),'غير محدد') as customer_service_name,
      coalesce(nullif(receiving_cashier.display_name,''),'بانتظار استلام الكاشير') as cashier_employee_name,
      coalesce(nullif(btrim(r.invoice_ref),''),late.invoice_ref) as invoice_ref,
      rt.stars as role_rating,rt.note as role_rating_note,
      fb.overall_stars as driver_feedback,
      (select count(*) from public.ff41_cases fc where fc.order_id=o.id and fc.kind='customer_complaint') as cases
   from public.ff_orders o
   left join public.ff38_delivery_tasks t on t.order_id=o.id
   left join public.ff49_order_details dt on dt.order_id=o.id
   left join public.ff_customers c on c.id=o.customer_id
   left join public.ff_drivers d on d.id=coalesce(t.driver_id,o.driver_id)
   left join public.ff49_cashier_receipts r on r.order_id=o.id
   left join public.ff_profiles created_staff on created_staff.user_id=o.created_by
   left join public.ff_profiles receiving_cashier on receiving_cashier.user_id=coalesce(r.received_by,r.invoiced_by)
   left join public.ff_luxe_late_invoice_refs late on late.order_id=o.id
   left join public.ff51_driver_ratings rt on rt.order_id=o.id and rt.rater_role=v_role
   left join public.ff_luxe_driver_feedback fb on fb.order_id=o.id and fb.driver_user_id=auth.uid()
   where o.order_type='delivery'
    and (o.status in ('delivered','cancelled','canceled','closed')
       or (t.cashier_stage='handed_over' and o.status not in ('cancelled','canceled','closed')))
    and o.business_date between v_start and v_end
    and (p_branch is null or o.branch_id=p_branch)
    and ff_private.ff_luxe_completed_can_view(o.id)
   order by o.created_at desc,o.id desc
   limit v_limit+1 offset v_offset
 ), paged as (
   select s.*,row_number() over(order by s.created_at desc,s.id desc) seq from scoped s
 )
 select count(*),coalesce(jsonb_agg(jsonb_build_object(
   'id',p.id,'number',p.order_number,'branch_id',p.branch_id,'status',p.status,
   'phase',p.phase,'cashier_stage',p.cashier_stage,'created_at',p.created_at,
   'assigned_at',p.assigned_at,'delivered_at',coalesce(p.delivered_at,p.task_delivered_at),
   'customer_name',p.customer_name,'phone',p.phone_snapshot,'area',p.area_snapshot,
   'full_address',p.address,'notes',p.notes,'cancel_reason',p.cancel_reason,
   'driver_id',coalesce(p.driver_id,p.fallback_driver),'driver_name',p.driver_name,
   'customer_service_name',p.customer_service_name,'cashier_employee_name',p.cashier_employee_name,
   'items_total',p.items_total,'delivery_fee',p.delivery_fee,'total',p.total,
   'invoice_ref',p.invoice_ref,'role_rating',p.role_rating,
   'role_rating_note',p.role_rating_note,'driver_feedback',p.driver_feedback,
   'case_count',p.cases,
   'items',coalesce((select jsonb_agg(jsonb_build_object(
       'name',i.item_name,'qty',i.quantity,'price',i.unit_price,
       'line_total',i.line_total,'notes',i.item_notes) order by i.id)
     from public.ff_order_items i where i.order_id=p.id),'[]'::jsonb)
 ) order by p.seq) filter(where p.seq<=v_limit),'[]'::jsonb)
 into v_found,v_rows from paged p;
 return jsonb_build_object(
  'items',coalesce(v_rows,'[]'::jsonb),'has_more',v_found>v_limit,
  'offset',v_offset,'limit',v_limit,'from',v_start,'to',v_end,'branches',v_branches,
  'role',v_role,'cashier_desk',v_desk
 );
end;
$function$;

-- ff_luxe_settlement_period (preserved signature and authorization)
CREATE OR REPLACE FUNCTION public.ff_luxe_settlement_period(p_from date, p_to date, p_branch uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare answer jsonb;
begin
 if auth.uid() is null or not exists(select 1 from public.ff_profiles p
   where p.user_id=auth.uid() and p.role='manager' and p.active)
 then raise exception 'التقرير للمدير العام فقط' using errcode='42501'; end if;
 if p_from is null or p_to is null or p_from>p_to
   or p_from<date '2020-01-01' or p_to>public.ff_business_date(now())
   or p_to-p_from>366 then raise exception 'الفترة غير صالحة أو أطول من سنة';end if;
 if p_branch is not null and not exists(select 1 from public.ff_branches b where b.id=p_branch)
 then raise exception 'الفرع غير موجود';end if;
 with delivered as (
  select o.business_date as report_date,o.branch_id,
    count(*)::integer as n,
    coalesce(sum(o.total+coalesce(a.additions,0)),0)::numeric as gross
  from public.ff_orders o
  join public.ff38_delivery_tasks t on t.order_id=o.id
  left join lateral(select coalesce(sum(x.amount),0) as additions from public.ff38_order_additions x
   where x.order_id=o.id and x.status='invoiced') a on true
  where o.order_type='delivery' and o.status='delivered'
   and o.business_date between p_from and p_to
   
   and (p_branch is null or p_branch=o.branch_id)
  group by 1,2
 ), cash as (
  select s.settlement_date as report_date,s.branch_id,
     count(*)::integer as n,
     count(*) filter(where s.status='closed')::integer as closed_n,
     coalesce(sum(s.cash_due),0)::numeric as due,
     coalesce(sum(s.cash_received),0)::numeric as received
  from public.ff42_driver_settlements s
  where s.settlement_date between p_from and p_to
    and (p_branch is null or s.branch_id=p_branch)
  group by 1,2
 ), merged as (
  select coalesce(d.report_date,c.report_date) as report_date,
    coalesce(d.branch_id,c.branch_id) as branch_id,
    coalesce(d.n,0) as delivered_orders,
    coalesce(d.gross,0) as delivered_value,
    coalesce(c.n,0) as settlements,
    coalesce(c.closed_n,0) as closed_settlements,
    coalesce(c.due,0) as cash_due,
    coalesce(c.received,0) as cash_received
  from delivered d full join cash c
  on d.report_date=c.report_date and d.branch_id=c.branch_id
 )
 select jsonb_build_object('from',p_from,'to',p_to,'read_only',true,
    'rows',coalesce(jsonb_agg(jsonb_build_object(
      'day',m.report_date,'branch',b.name,'branch_id',m.branch_id,
      'delivered_orders',m.delivered_orders,'delivered_value',m.delivered_value,
      'settlements',m.settlements,'closed_settlements',m.closed_settlements,
      'cash_due',m.cash_due,'cash_received',m.cash_received,
      'difference',m.cash_due-m.cash_received
    ) order by m.report_date desc,b.name),'[]'::jsonb),
    'totals',jsonb_build_object(
      'delivered_orders',coalesce(sum(m.delivered_orders),0),
      'delivered_value',coalesce(sum(m.delivered_value),0),
      'settlements',coalesce(sum(m.settlements),0),
      'cash_due',coalesce(sum(m.cash_due),0),
      'cash_received',coalesce(sum(m.cash_received),0)
    ))
 into answer
 from merged m join public.ff_branches b on b.id=m.branch_id;
 return answer;
end;$function$;

COMMIT;
