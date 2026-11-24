-- A02 privacy boundary: fail closed for missing/inactive staff role.
-- Preserve authorized role lists and existing branch/permission checks.
CREATE OR REPLACE FUNCTION public.ff49_reservations_list(p_limit integer DEFAULT 80)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                                                                                        DECLARE v_role text;
                                                                                                        BEGIN
                                                                                                         SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
                                                                                                          IF v_role IS NULL OR v_role NOT IN ('manager','customer_service','cashier','supervisor') THEN
                                                                                                            RAISE EXCEPTION 'غير مصرح بمتابعة الحجوزات' USING ERRCODE='42501'; END IF;
                                                                                                             RETURN coalesce((SELECT jsonb_agg(jsonb_build_object(
                                                                                                              'id',r.id,'branch_id',r.branch_id,'customer_name',r.customer_name,
                                                                                                               'customer_phone',r.customer_phone,'pickup_at',r.pickup_at,'pickup_unspecified',r.pickup_unspecified,'items',r.items,
                                                                                                                'notes',r.notes,'status',r.status,'updated_at',r.updated_at,'revision',r.revision)
                                                                                                                 ORDER BY r.pickup_at)
                                                                                                                  FROM (SELECT * FROM public.ff49_reservations x WHERE
                                                                                                                    (v_role IN ('manager','customer_service') OR EXISTS(
                                                                                                                       SELECT 1 FROM public.ff_user_branches WHERE user_id=auth.uid() AND branch_id=x.branch_id))
                                                                                                                          AND x.pickup_at>now()-interval '3 days'
                                                                                                                             ORDER BY pickup_at ASC LIMIT greatest(1,least(coalesce(p_limit,80),200))) r),'[]'::jsonb);
                                                                                                                             END $function$;

CREATE OR REPLACE FUNCTION public.ff49_visible_transfers()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                                                  DECLARE v_role text;
                                                                  BEGIN
                                                                   SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
                                                                    IF v_role IS NULL OR v_role NOT IN ('manager','cashier','customer_service','supervisor') THEN
                                                                      RAISE EXCEPTION 'غير مصرح' USING ERRCODE='42501'; END IF;
                                                                       RETURN coalesce((SELECT jsonb_agg(jsonb_build_object(
                                                                         'id',r.id,'order_id',r.order_id,'original_driver_id',r.original_driver_id,
                                                                           'new_driver_id',r.new_driver_id,'reason',r.reason,'status',r.status,'requested_at',r.requested_at)
                                                                            ORDER BY r.requested_at DESC)
                                                                             FROM (SELECT r.* FROM public.ff49_driver_transfers r JOIN public.ff_orders o ON o.id=r.order_id
                                                                               WHERE r.status='pending_cashier' AND (v_role IN ('manager','customer_service')
                                                                                  OR EXISTS(SELECT 1 FROM public.ff_user_branches WHERE user_id=auth.uid() AND branch_id=o.branch_id))
                                                                                    ORDER BY r.requested_at DESC LIMIT 50) r),'[]'::jsonb);
                                                                                    END $function$;

CREATE OR REPLACE FUNCTION public.ff51_customer_directory(p_query text DEFAULT ''::text, p_limit integer DEFAULT 60)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
  IF v_role IS NULL OR v_role NOT IN ('manager','customer_service') THEN RAISE EXCEPTION 'غير مصرح' USING ERRCODE='42501'; END IF;
   RETURN coalesce((SELECT jsonb_agg(jsonb_build_object(
     'phone',x.phone_snapshot,'name',coalesce(x.customer_name,''),
       'address',coalesce(x.full_address,x.area_snapshot),'last_order_at',x.created_at,
         'notes_count',(SELECT count(*)::int FROM public.ff51_customer_notes n WHERE n.phone=x.phone_snapshot)
          ) ORDER BY x.created_at DESC)
           FROM (
            SELECT * FROM (
              SELECT DISTINCT ON (o.phone_snapshot) o.phone_snapshot,o.area_snapshot,o.created_at,
                 d.customer_name,d.full_address
                   FROM public.ff_orders o LEFT JOIN public.ff49_order_details d ON d.order_id=o.id
                     WHERE o.order_type='delivery' AND length(btrim(coalesce(o.phone_snapshot,'')))>=5
                        AND (btrim(coalesce(p_query,''))='' OR
                            o.phone_snapshot ILIKE '%'||btrim(p_query)||'%' OR
                                coalesce(d.customer_name,'') ILIKE '%'||btrim(p_query)||'%')
                                  ORDER BY o.phone_snapshot,o.created_at DESC
                                   ) latest ORDER BY latest.created_at DESC LIMIT greatest(1,least(coalesce(p_limit,60),150))
                                    ) x
                                     ),'[]'::jsonb);
                                     END $function$;

CREATE OR REPLACE FUNCTION public.ff51_driver_rating_summary()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                                                                                                                                                                 DECLARE v_role text;v_driver uuid;
                                                                                                                                                                                 BEGIN
                                                                                                                                                                                  SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
                                                                                                                                                                                   IF v_role IS NULL OR v_role NOT IN ('manager','supervisor','driver') THEN RAISE EXCEPTION 'غير مصرح' USING ERRCODE='42501'; END IF;
                                                                                                                                                                                    IF v_role='driver' THEN SELECT driver_id INTO v_driver FROM public.ff38_driver_links WHERE user_id=auth.uid(); END IF;
                                                                                                                                                                                     RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('driver_id',x.driver_id,'name',d.name,
                                                                                                                                                                                       'count',x.count,'average',x.average) ORDER BY x.average DESC) FROM
                                                                                                                                                                                        (SELECT driver_id,count(*)::int AS count,round(avg(stars)::numeric,2) AS average
                                                                                                                                                                                          FROM public.ff51_driver_ratings
                                                                                                                                                                                            WHERE v_role='manager' OR (v_role='driver' AND driver_id=v_driver)
                                                                                                                                                                                               OR (v_role='supervisor' AND EXISTS (SELECT 1 FROM public.ff_drivers d2
                                                                                                                                                                                                   JOIN public.ff_user_branches ub ON ub.branch_id=d2.branch_id AND ub.user_id=auth.uid()
                                                                                                                                                                                                       WHERE d2.id=driver_id)) GROUP BY driver_id) x
                                                                                                                                                                                                        JOIN public.ff_drivers d ON d.id=x.driver_id),'[]'::jsonb);
                                                                                                                                                                                                        END $function$;

CREATE OR REPLACE FUNCTION public.ff51_order_archive(p_from date, p_to date, p_branch uuid DEFAULT NULL::uuid, p_status text DEFAULT NULL::text, p_limit integer DEFAULT 60, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                                           DECLARE v_role text;v_rows jsonb;v_total bigint;
                                                           BEGIN
                                                            SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active=true;
                                                             IF v_role IS NULL OR v_role NOT IN ('manager','customer_service','cashier','supervisor') THEN
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

CREATE OR REPLACE FUNCTION public.ff51_rate_driver(p_order uuid, p_stars integer, p_note text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                                                                                                                                                DECLARE v_role text;v_branch uuid;v_driver uuid;v_stage text;
                                                                                                                                                                BEGIN
                                                                                                                                                                 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
                                                                                                                                                                  SELECT o.branch_id,t.driver_id,t.cashier_stage INTO v_branch,v_driver,v_stage
                                                                                                                                                                   FROM public.ff_orders o JOIN public.ff38_delivery_tasks t ON t.order_id=o.id WHERE o.id=p_order;
                                                                                                                                                                    IF v_role IS NULL OR v_role NOT IN ('manager','cashier')
                                                                                                                                                                     OR (v_role='cashier' AND NOT EXISTS(SELECT 1 FROM public.ff_user_branches
                                                                                                                                                                       WHERE user_id=auth.uid() AND branch_id=v_branch)) THEN
                                                                                                                                                                         RAISE EXCEPTION 'التقييم للكاشير المخول فقط' USING ERRCODE='42501'; END IF;
                                                                                                                                                                          IF v_driver IS NULL OR v_stage<>'handed_over' OR p_stars NOT BETWEEN 1 AND 5 THEN
                                                                                                                                                                            RAISE EXCEPTION 'يجب تسليم الطلب للموصل قبل تقييمه (1-5)'; END IF;
                                                                                                                                                                             INSERT INTO public.ff51_driver_ratings(order_id,driver_id,stars,note,rater_id,rater_role)
                                                                                                                                                                              VALUES(p_order,v_driver,p_stars,left(coalesce(p_note,''),500),auth.uid(),
                                                                                                                                                                                CASE WHEN v_role='manager' THEN 'manager' ELSE 'cashier' END);
                                                                                                                                                                                 RETURN jsonb_build_object('saved',true);
                                                                                                                                                                                 END $function$;

CREATE OR REPLACE FUNCTION public.ff_burger_list(p_limit integer DEFAULT 75)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text;v_branches jsonb;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role IS NULL OR v_role NOT IN ('cashier','assembly','burger_kitchen') THEN RAISE EXCEPTION 'غير مصرح' USING ERRCODE='42501'; END IF;
 RETURN coalesce((
 SELECT jsonb_agg(to_jsonb(s) ORDER BY s.sent_at DESC)
 FROM (SELECT t.id,t.branch_id,t.order_kind,t.delivery_order_id,t.invoice_ref,
   t.cashier_name,t.kitchen_id,t.kitchen_name,t.items,t.notes,t.notes_confirmed_at,t.status,t.sent_at,t.accepted_at,t.ready_at,
   t.acknowledged_at,b.name AS branch_name,
   CASE WHEN t.accepted_at IS NOT NULL AND t.ready_at IS NOT NULL THEN
    greatest(0,extract(epoch from(t.ready_at-t.accepted_at))::integer) ELSE NULL END AS prep_seconds
 FROM public.ff_burger_tickets t JOIN public.ff_branches b ON b.id=t.branch_id
 WHERE EXISTS(SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid() AND ub.branch_id=t.branch_id)
 ORDER BY CASE WHEN t.status IN ('sent','preparing','ready') THEN 0 ELSE 1 END,
   t.sent_at DESC LIMIT LEAST(GREATEST(coalesce(p_limit,75),1),150)
 ) s),'[]'::jsonb);
END $function$;

CREATE OR REPLACE FUNCTION public.ff_burger_my_branch()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text; v_branches jsonb;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role IS NULL OR v_role NOT IN ('cashier','assembly','burger_kitchen') THEN
   RAISE EXCEPTION 'غير مصرح بواجهة البرجر' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',b.id,'name',b.name,'code',b.code) ORDER BY b.name),'[]'::jsonb)
 INTO v_branches
 FROM public.ff_user_branches ub JOIN public.ff_branches b ON b.id=ub.branch_id
 WHERE ub.user_id=auth.uid() AND b.active;
 IF jsonb_array_length(v_branches)=0 THEN RAISE EXCEPTION 'الحساب غير مرتبط بفرع نشط' USING ERRCODE='42501'; END IF;
 IF v_role IN ('assembly','burger_kitchen') AND jsonb_array_length(v_branches)<>1 THEN
   RAISE EXCEPTION 'يلزم تحديد فرع واحد فقط لحساب قسم البرجر' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('role',v_role,'branches',v_branches);
END $function$;

CREATE OR REPLACE FUNCTION public.ff_burger_online_status()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role IS NULL OR v_role NOT IN ('cashier','assembly','burger_kitchen') THEN RAISE EXCEPTION 'غير مصرح' USING ERRCODE='42501'; END IF;
 RETURN coalesce((
  SELECT jsonb_agg(jsonb_build_object(
   'branch_id',b.id,'branch_name',b.name,'online_count',
   (SELECT count(*) FROM public.ff_burger_presence t JOIN public.ff_profiles p ON p.user_id=t.user_id AND p.active AND p.role='burger_kitchen'
    WHERE t.branch_id=b.id AND t.online AND t.last_seen_at>now()-interval '75 seconds'),
   'last_seen_at',(SELECT max(t.last_seen_at) FROM public.ff_burger_presence t
    JOIN public.ff_profiles p ON p.user_id=t.user_id AND p.active AND p.role='burger_kitchen' WHERE t.branch_id=b.id)
   ) ORDER BY b.name)
  FROM public.ff_user_branches ub JOIN public.ff_branches b ON b.id=ub.branch_id AND b.active
  WHERE ub.user_id=auth.uid()
 ),'[]'::jsonb);
END $function$;

CREATE OR REPLACE FUNCTION public.ff_burger_transition(p_ticket uuid, p_action text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text;v_person text;v_row public.ff_burger_tickets%ROWTYPE;
BEGIN
 SELECT role,display_name INTO v_role,v_person FROM public.ff_profiles
 WHERE user_id=auth.uid() AND active;
 IF v_role IS NULL OR v_role NOT IN ('cashier','assembly','burger_kitchen') THEN
   RAISE EXCEPTION 'الدور غير مخول' USING ERRCODE='42501';END IF;
 SELECT * INTO v_row FROM public.ff_burger_tickets WHERE id=p_ticket FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'الطلب غير موجود';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ff_user_branches WHERE user_id=auth.uid() AND branch_id=v_row.branch_id)
 THEN RAISE EXCEPTION 'طلب يخص فرعًا آخر' USING ERRCODE='42501';END IF;
 IF p_action='receive' AND v_role='burger_kitchen' AND v_row.status='sent' THEN
  UPDATE public.ff_burger_tickets SET status='preparing',kitchen_id=auth.uid(),kitchen_name=v_person,
     accepted_at=clock_timestamp() WHERE id=p_ticket;
 ELSIF p_action='ready' AND v_role='burger_kitchen' AND v_row.status='preparing'
     AND v_row.kitchen_id=auth.uid() THEN
   IF length(btrim(v_row.notes))>0 AND v_row.notes_confirmed_at IS NULL THEN
     RAISE EXCEPTION 'أكد تنفيذ الملاحظات المرفقة قبل جاهزية الطلب' USING ERRCODE='42501';
   END IF;
  UPDATE public.ff_burger_tickets SET status='ready',ready_at=clock_timestamp() WHERE id=p_ticket;
 ELSIF p_action='skip' AND v_role IN ('cashier','assembly') AND v_row.status='ready' THEN
  UPDATE public.ff_burger_tickets SET status='acknowledged',acknowledged_at=clock_timestamp(),
     acknowledged_by=auth.uid() WHERE id=p_ticket;
 ELSE RAISE EXCEPTION 'المرحلة تغيرت أو العملية غير مصرح بها؛ حدث القائمة' USING ERRCODE='42501';
 END IF;
 RETURN jsonb_build_object('saved',true,'id',p_ticket,'action',p_action);
END $function$;

CREATE OR REPLACE FUNCTION public.ff_case_alert_read(p_case uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role IS NULL OR v_role NOT IN ('manager','supervisor','customer_service') OR NOT EXISTS (
  SELECT 1 FROM public.ff41_cases c WHERE c.id=p_case AND c.kind='customer_complaint'
   AND c.order_id IS NOT NULL
   AND (v_role IN ('manager','customer_service') OR EXISTS
    (SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid() AND ub.branch_id=c.branch_id))
 ) THEN RAISE EXCEPTION 'البلاغ غير متاح لحسابك' USING ERRCODE='42501';END IF;
 INSERT INTO public.ff_case_alert_receipts(case_id,user_id)
 VALUES(p_case,auth.uid()) ON CONFLICT(case_id,user_id) DO NOTHING;
 RETURN true;
END $function$;

CREATE OR REPLACE FUNCTION public.ff_case_alerts(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text; v_count integer;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role IS NULL OR v_role NOT IN ('manager','supervisor','customer_service') THEN
  RAISE EXCEPTION 'لا توجد صلاحية الاطلاع على إشعارات الشكاوى' USING ERRCODE='42501';
 END IF;
 SELECT count(*) INTO v_count FROM public.ff41_cases c
 WHERE c.kind='customer_complaint' AND c.order_id IS NOT NULL
  AND c.status IN ('open','in_review')
  AND (v_role IN ('manager','customer_service') OR EXISTS
   (SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid() AND ub.branch_id=c.branch_id))
  AND NOT EXISTS(SELECT 1 FROM public.ff_case_alert_receipts r WHERE r.case_id=c.id AND r.user_id=auth.uid());
 RETURN jsonb_build_object('unread_count',v_count,'items',coalesce((
  SELECT jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC) FROM
  (SELECT c.id,c.subject,c.priority,c.status,c.created_at,c.branch_id,c.order_id,o.order_number,
  b.name as branch_name, (r.seen_at IS NOT NULL) as seen
  FROM public.ff41_cases c LEFT JOIN public.ff_orders o ON o.id=c.order_id
   LEFT JOIN public.ff_branches b ON b.id=c.branch_id
   LEFT JOIN public.ff_case_alert_receipts r ON r.case_id=c.id AND r.user_id=auth.uid()
  WHERE c.kind='customer_complaint' AND c.order_id IS NOT NULL
    AND (v_role IN ('manager','customer_service') OR EXISTS(
     SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid() AND ub.branch_id=c.branch_id))
  ORDER BY c.created_at DESC LIMIT least(greatest(coalesce(p_limit,50),1),100)) t
 ),'[]'::jsonb));
END $function$;

CREATE OR REPLACE FUNCTION public.ff_luxe_dispatch_preview(p_branch uuid, p_area text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text;v_candidate record;v_eligible integer;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active=true;
 IF v_role IS NULL OR v_role NOT IN ('manager','customer_service') THEN RAISE EXCEPTION 'غير مصرح' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ff_branches WHERE id=p_branch AND active=true) THEN RETURN jsonb_build_object('state','invalid_branch'); END IF;
 SELECT count(*) INTO v_eligible FROM public.ff_drivers d JOIN public.ff38_driver_presence p ON p.driver_id=d.id WHERE d.branch_id=p_branch AND d.active AND p.state IN ('ready','busy') AND p.checked_in_at IS NOT NULL AND p.last_seen_at>now()-interval '90 seconds' AND NOT EXISTS(SELECT 1 FROM ff_private.automatic_dispatch_exclusions pin WHERE pin.branch_id=p_branch AND pin.driver_id=d.id);
 SELECT d.id,d.name,a.active_count+w.waiting_count AS active_count,a.same_area
 INTO v_candidate FROM public.ff_drivers d
 JOIN public.ff38_driver_presence p ON p.driver_id=d.id
 CROSS JOIN LATERAL (SELECT count(*)::int active_count,count(*) FILTER (WHERE lower(btrim(o.area_snapshot))=lower(btrim(coalesce(p_area,''))))::int same_area FROM public.ff38_delivery_tasks t JOIN public.ff_orders o ON o.id=t.order_id WHERE t.driver_id=d.id AND t.delivered_at IS NULL AND o.status<>'cancelled') a
 CROSS JOIN LATERAL (SELECT count(*)::int waiting_count FROM public.ff38_dispatch_offers f WHERE f.driver_id=d.id AND f.status='offered' AND f.expires_at>now()) w
 WHERE d.branch_id=p_branch AND d.active AND p.state IN ('ready','busy') AND p.checked_in_at IS NOT NULL AND p.last_seen_at>now()-interval '90 seconds'
 AND NOT EXISTS(SELECT 1 FROM ff_private.automatic_dispatch_exclusions pin WHERE pin.branch_id=p_branch AND pin.driver_id=d.id)
 AND a.active_count+w.waiting_count<5
 AND (a.active_count+w.waiting_count<2 OR a.same_area>0)
 AND w.waiting_count=0
 ORDER BY CASE WHEN a.active_count+w.waiting_count=0 THEN 0 ELSE 1 END,
 CASE WHEN public.ff52_is_route_priority(d.id,p_branch,coalesce(p_area,'')) THEN 0 ELSE 1 END,
 CASE WHEN a.same_area>0 THEN 0 ELSE 1 END,a.active_count+w.waiting_count,
 (SELECT max(offered_at) FROM public.ff38_dispatch_offers h WHERE h.driver_id=d.id) ASC NULLS FIRST,d.sort_order,d.id
 LIMIT 1;
 IF v_candidate.id IS NULL THEN RETURN jsonb_build_object('state','waiting','eligible',v_eligible); END IF;
 RETURN jsonb_build_object('state','candidate','driver_id',v_candidate.id,'driver_name',v_candidate.name,'active_count',v_candidate.active_count,'notice','توقع لحظي غير نهائي؛ يتغير عند اعتماد الطلب أو قبوله');
END;$function$;

CREATE OR REPLACE FUNCTION public.ff_luxe_rate_driver_cashier(p_order uuid, p_stars integer, p_note text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text; v_branch uuid; v_driver uuid; v_rating_role text;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role IS NULL OR v_role NOT IN ('cashier','manager') THEN
  RAISE EXCEPTION 'تقييم الموصل للكاشير أو المدير فقط' USING ERRCODE='42501';
 END IF;
 IF p_stars IS NULL OR p_stars NOT BETWEEN 1 AND 5 THEN
  RAISE EXCEPTION 'التقييم من نجمة إلى خمس نجوم';
 END IF;
 SELECT o.branch_id,t.driver_id INTO v_branch,v_driver
 FROM public.ff_orders o
 JOIN public.ff38_delivery_tasks t ON t.order_id=o.id
 WHERE o.id=p_order AND o.status <> 'cancelled';
 IF v_driver IS NULL THEN RAISE EXCEPTION 'الطلب غير موجود أو لا يوجد موصل مسند'; END IF;
 IF v_role='cashier' AND NOT EXISTS (
  SELECT 1 FROM public.ff_user_branches b WHERE b.user_id=auth.uid() AND b.branch_id=v_branch
 ) THEN RAISE EXCEPTION 'ليس لديك صلاحية التقييم لهذا الفرع' USING ERRCODE='42501'; END IF;
 v_rating_role:=CASE WHEN v_role='manager' THEN 'manager' ELSE 'cashier' END;
 INSERT INTO public.ff51_driver_ratings(order_id,driver_id,stars,note,rater_id,rater_role)
 VALUES(p_order,v_driver,p_stars,left(btrim(coalesce(p_note,'')),500),auth.uid(),v_rating_role)
 ON CONFLICT (order_id,rater_role) DO UPDATE
 SET driver_id=EXCLUDED.driver_id,stars=EXCLUDED.stars,note=EXCLUDED.note,
     rater_id=EXCLUDED.rater_id,rated_at=now();
 RETURN jsonb_build_object('saved',true,'role',v_rating_role);
END
$function$;

CREATE OR REPLACE FUNCTION public.ff_luxe_rate_driver_cs(p_order uuid, p_stars integer, p_note text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text; v_driver uuid; v_branch uuid;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role IS NULL OR v_role NOT IN ('manager','customer_service') THEN
  RAISE EXCEPTION 'غير مصرح بالتقييم' USING ERRCODE='42501';
 END IF;
 IF p_stars IS NULL OR p_stars NOT BETWEEN 1 AND 5 THEN
  RAISE EXCEPTION 'التقييم من 1 إلى 5';
 END IF;
 SELECT o.branch_id,t.driver_id INTO v_branch,v_driver
 FROM public.ff_orders o JOIN public.ff38_delivery_tasks t ON t.order_id=o.id
 WHERE o.id=p_order AND o.status<>'cancelled';
 IF v_driver IS NULL THEN RAISE EXCEPTION 'لا يوجد موصل مسند'; END IF;
 INSERT INTO public.ff51_driver_ratings(order_id,driver_id,stars,note,rater_id,rater_role)
 VALUES(p_order,v_driver,p_stars,left(btrim(coalesce(p_note,'')),500),auth.uid(),v_role)
 ON CONFLICT (order_id,rater_role) DO UPDATE
 SET driver_id=EXCLUDED.driver_id,stars=EXCLUDED.stars,note=EXCLUDED.note,
     rater_id=EXCLUDED.rater_id,rated_at=now();
 RETURN jsonb_build_object('saved',true,'role',v_role);
END
$function$;

CREATE OR REPLACE FUNCTION public.ff_luxe_rating_summary_period(p_from date DEFAULT NULL::date, p_to date DEFAULT NULL::date, p_branch uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d_from date:=coalesce(p_from,(now() at time zone 'Asia/Aden')::date);
 d_to date:=coalesce(p_to,(now() at time zone 'Asia/Aden')::date);
 v_role text;v_driver uuid;v_data jsonb;
begin
 select role into v_role from public.ff_profiles where user_id=auth.uid() and active;
 IF v_role IS NULL OR v_role NOT IN ('manager','supervisor','driver')
 then raise exception 'غير مصرح بتقرير التقييمات' using errcode='42501';end if;
 if d_from>d_to or d_from<'2020-01-01'::date or d_to>(now() at time zone 'Asia/Aden')::date
   or d_to-d_from>366 then raise exception 'نطاق التقييمات غير صحيح';end if;
 if v_role='driver' then
  select driver_id into v_driver from public.ff38_driver_links where user_id=auth.uid() limit 1;end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'driver_id',r.driver_id,'name',r.driver_name,'count',r.cnt,'average',r.avgstars)
  order by r.avgstars desc,r.driver_name),'[]'::jsonb)
 into v_data from (
  select x.driver_id,d.name as driver_name,count(*)::integer cnt,
    round(avg(x.stars)::numeric,2) avgstars
  from public.ff51_driver_ratings x
  join public.ff_drivers d on d.id=x.driver_id
  where (x.rated_at at time zone 'Asia/Aden')::date between d_from and d_to
   and (p_branch is null or d.branch_id=p_branch)
   and (v_role in ('manager','supervisor') or (v_role='driver' and d.id=v_driver))
  group by x.driver_id,d.name
 ) r;
 return v_data;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ff_reward_check(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text;v_row public.ff_reward_codes%ROWTYPE;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role IS NULL OR v_role NOT IN ('manager','customer_service','cashier') THEN RAISE EXCEPTION 'غير مخوّل' USING ERRCODE='42501';END IF;
 SELECT * INTO v_row FROM public.ff_reward_codes
 WHERE code=upper(btrim(coalesce(p_code,''))) AND status='issued';
 IF NOT FOUND OR (v_row.expires_at IS NOT NULL AND v_row.expires_at<=now()) THEN
  RAISE EXCEPTION 'الكود غير موجود أو منتهي أو مستخدم مسبقًا';END IF;
 RETURN jsonb_build_object('id',v_row.id,'kind',v_row.kind,'customer_name',v_row.recipient_name,
   'customer_phone',v_row.recipient_phone,'items',v_row.items,'expires_at',v_row.expires_at);
END $function$;

CREATE OR REPLACE FUNCTION public.ff_reward_redeem(p_code text, p_branch uuid, p_channel text, p_area text DEFAULT ''::text, p_fee numeric DEFAULT 0, p_notes text DEFAULT ''::text, p_token uuid DEFAULT NULL::uuid, p_identity_confirmed boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text;v_voucher public.ff_reward_codes%ROWTYPE;v_result jsonb;
 v_order uuid;v_reservation uuid;v_notes text;v_addr text:=btrim(coalesce(p_area,''));
 v_branch_ok boolean;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role IS NULL OR v_role NOT IN ('manager','customer_service','cashier') THEN RAISE EXCEPTION 'لا تملك صلاحية استهلاك الأكواد' USING ERRCODE='42501';END IF;
 IF p_code IS NULL OR p_token IS NULL OR p_identity_confirmed IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'أدخل الكود وأكد مطابقة اسم ورقم العميل قبل الاستخدام';END IF;
 IF p_channel IS NULL OR p_channel NOT IN ('delivery','reservation','cashier_pickup') OR p_branch IS NULL THEN
  RAISE EXCEPTION 'اختر طريقة الاستلام والفرع';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ff_branches WHERE id=p_branch AND active) THEN
  RAISE EXCEPTION 'الفرع غير نشط';END IF;
 IF v_role='cashier' AND (p_channel<>'cashier_pickup' OR NOT EXISTS(
   SELECT 1 FROM public.ff_user_branches WHERE user_id=auth.uid() AND branch_id=p_branch)) THEN
  RAISE EXCEPTION 'الكاشير يستطيع إصدار بطاقة تحضير لفرعه فقط' USING ERRCODE='42501';END IF;
 IF v_role IN ('manager','customer_service') AND (
   p_channel='cashier_pickup' OR NOT public.ff49_can_work_branch(p_branch,ARRAY['manager','customer_service'])
   OR NOT public.ff38_permission_allowed(auth.uid(),'create_order')) THEN
  RAISE EXCEPTION 'غير مصرح بإنشاء هذا النوع من الطلبات' USING ERRCODE='42501';END IF;
 IF length(coalesce(p_notes,''))>1000 THEN RAISE EXCEPTION 'ملاحظات طويلة';END IF;
 IF p_fee IS NULL OR p_fee<0 OR p_fee>50000 OR p_fee::text IN ('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'أجرة التوصيل غير صالحة';END IF;
 IF p_channel='delivery' AND length(v_addr) NOT BETWEEN 2 AND 300 THEN
  RAISE EXCEPTION 'أدخل عنوان التوصيل أو المنطقة';END IF;
 SELECT * INTO v_voucher FROM public.ff_reward_codes
 WHERE code=upper(btrim(p_code)) FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'كود غير صحيح' USING ERRCODE='42501';END IF;
 IF v_voucher.status='redeemed' AND v_voucher.redeem_token=p_token THEN
  RETURN jsonb_build_object('saved',true,'duplicate',true,'order_id',v_voucher.redeemed_order_id,
    'reservation_id',v_voucher.redeemed_reservation_id,'channel',v_voucher.redeemed_channel);
 END IF;
 IF v_voucher.status<>'issued' OR (v_voucher.expires_at IS NOT NULL AND v_voucher.expires_at<=now()) THEN
  RAISE EXCEPTION 'الكود مستهلك أو منتهي الصلاحية' USING ERRCODE='42501';END IF;
 v_notes:='كود أصناف مجانية ('||CASE v_voucher.kind WHEN 'compensation' THEN 'تعويض' WHEN 'prize' THEN 'جائزة' ELSE 'ضيافة' END||') · '||left(coalesce(p_notes,''),950);
 IF p_channel='delivery' THEN
  v_result:=public.ff38_create_delivery_order(p_branch,v_voucher.recipient_phone,v_addr,
   v_voucher.items,p_fee,v_notes);
  v_order:=(v_result->>'order_id')::uuid;
  INSERT INTO public.ff49_order_details(order_id,customer_name,channel,full_address)
  VALUES(v_order,v_voucher.recipient_name,'phone',v_addr)
  ON CONFLICT(order_id) DO UPDATE SET customer_name=EXCLUDED.customer_name,full_address=EXCLUDED.full_address;
 ELSIF p_channel='reservation' THEN
  v_result:=public.ff49_create_reservation(p_branch,v_voucher.recipient_name,
    v_voucher.recipient_phone,NULL,v_voucher.items,v_notes);
  v_reservation:=(v_result->>'reservation_id')::uuid;
 ELSE
  INSERT INTO public.ff49_reservations(branch_id,customer_name,customer_phone,pickup_at,
   pickup_unspecified,items,notes,status,created_by)
  VALUES(p_branch,v_voucher.recipient_name,v_voucher.recipient_phone,now(),true,
   v_voucher.items,v_notes,'confirmed',auth.uid()) RETURNING id INTO v_reservation;
  INSERT INTO public.ff49_reservation_events(reservation_id,new_status,actor_id,note)
  VALUES(v_reservation,'confirmed',auth.uid(),'بطاقة تحضير كود ضيافة/تعويض: أكد الكاشير الاستلام');
 END IF;
 UPDATE public.ff_reward_codes
 SET status='redeemed',redeemed_at=clock_timestamp(),redeemed_by=auth.uid(),
  redeemed_branch_id=p_branch,redeemed_channel=p_channel,
  redeemed_order_id=v_order,redeemed_reservation_id=v_reservation,redeem_token=p_token
 WHERE id=v_voucher.id AND status='issued';
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 VALUES(auth.uid(),'reward_code_redeemed','reward_code',v_voucher.id::text,p_branch,
  jsonb_build_object('channel',p_channel,'order',v_order,'reservation',v_reservation,
  'kind',v_voucher.kind));
 RETURN jsonb_build_object('saved',true,'order_id',v_order,'reservation_id',v_reservation,'channel',p_channel);
END $function$;
