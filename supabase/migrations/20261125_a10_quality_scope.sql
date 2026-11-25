
-- A10 one scoped case visibility predicate, using actual linked account/desk.
CREATE OR REPLACE FUNCTION ff_private.a10_branch_visible(p_role text,p_branch uuid)
RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT p_role='manager' OR (p_branch IS NOT NULL AND (
 EXISTS(SELECT FROM public.ff_user_branches u WHERE u.user_id=auth.uid() AND u.branch_id=p_branch)
 OR ((p_role='customer_service' OR (p_role='supervisor' AND NOT EXISTS(SELECT FROM public.ff_user_branches u WHERE u.user_id=auth.uid()))) AND EXISTS(SELECT FROM public.ff_branches b WHERE b.id=p_branch AND b.active))
 OR (p_role='driver' AND EXISTS(SELECT FROM public.ff38_driver_links l JOIN public.ff_drivers d ON d.id=l.driver_id WHERE l.user_id=auth.uid() AND d.active AND d.branch_id=p_branch))
 ))
$$;
CREATE OR REPLACE FUNCTION ff_private.a10_cashier_order_visible(p_order uuid)
RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT EXISTS(SELECT FROM public.ff_orders o JOIN public.ff_profiles p ON p.user_id=auth.uid() AND p.active AND p.role='cashier' JOIN public.ff_user_branches u ON u.user_id=p.user_id AND u.branch_id=o.branch_id LEFT JOIN public.ff_luxe_cashier_order_desks od ON od.order_id=o.id LEFT JOIN public.ff_luxe_cashier_staff_desks sd ON sd.user_id=p.user_id WHERE o.id=p_order AND o.order_type='delivery' AND (sd.user_id IS NULL OR od.order_id IS NULL OR sd.desk_code=od.desk_code))
$$;
CREATE OR REPLACE FUNCTION ff_private.a10_case_visible(p_role text,p_kind text,p_creator uuid,p_branch uuid,p_order uuid)
RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT p_role='manager' OR (p_kind='staff_grievance' AND p_creator=auth.uid()) OR (p_kind='customer_complaint' AND p_role IN ('customer_service','supervisor','cashier') AND ff_private.a10_branch_visible(p_role,p_branch) AND (p_role<>'cashier' OR p_order IS NULL OR ff_private.a10_cashier_order_visible(p_order)))
$$;
REVOKE ALL ON FUNCTION ff_private.a10_branch_visible(text,uuid),ff_private.a10_cashier_order_visible(uuid),ff_private.a10_case_visible(text,text,uuid,uuid,uuid) FROM PUBLIC,anon,authenticated;
ALTER TABLE public.ff_luxe_driver_grievances ADD COLUMN case_id uuid UNIQUE REFERENCES public.ff41_cases(id) ON DELETE SET NULL;
-- Existing rows (if present on a restored environment) remain untouched in the old table.
-- A linked case is created on submission; legacy preexisting rows retain their original status and details.
CREATE OR REPLACE FUNCTION public.ff_luxe_driver_grievance(p_order uuid,p_category text,p_details text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_driver uuid; v_branch uuid; v_id bigint; v_case uuid; v_order_number bigint; v_subject text;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='driver') THEN RAISE EXCEPTION 'الموصل فقط' USING ERRCODE='42501';END IF;
 IF p_category IS NULL OR p_category NOT IN ('delivery_fee','cashier','customer_service','customer','other') OR length(btrim(coalesce(p_details,''))) NOT BETWEEN 10 AND 1500 THEN RAISE EXCEPTION 'حدد النوع واكتب تفاصيل لا تقل عن عشرة أحرف';END IF;
 SELECT d.id,d.branch_id INTO v_driver,v_branch FROM public.ff38_driver_links l JOIN public.ff_drivers d ON d.id=l.driver_id AND d.active WHERE l.user_id=auth.uid();
 IF v_driver IS NULL THEN RAISE EXCEPTION 'حساب الموصل غير مربوط' USING ERRCODE='42501';END IF;
 IF p_order IS NOT NULL THEN
  SELECT o.branch_id,o.order_number INTO v_branch,v_order_number FROM public.ff_orders o JOIN public.ff38_delivery_tasks t ON t.order_id=o.id WHERE o.id=p_order AND t.driver_id=v_driver;
  IF v_order_number IS NULL THEN RAISE EXCEPTION 'الطلب لا يخص الموصل' USING ERRCODE='42501';END IF;
 END IF;
 PERFORM pg_advisory_xact_lock(hashtext('ff41-create-'||auth.uid()::text));
 IF (SELECT count(*) FROM public.ff41_cases WHERE created_by=auth.uid() AND created_at>now()-interval '24 hours')>=20 THEN RAISE EXCEPTION 'تم بلوغ حد البلاغات اليومي';END IF;
 v_subject:='تظلم موصل — '||CASE p_category WHEN 'delivery_fee' THEN 'رسوم التوصيل' WHEN 'cashier' THEN 'الكاشير' WHEN 'customer_service' THEN 'خدمة العملاء' WHEN 'customer' THEN 'العميل' ELSE 'أخرى' END||CASE WHEN v_order_number IS NULL THEN '' ELSE ' · طلب #'||v_order_number::text END;
 INSERT INTO public.ff41_cases(kind,branch_id,subject,description,priority,created_by) VALUES('staff_grievance',v_branch,v_subject,btrim(p_details),'normal',auth.uid()) RETURNING id INTO v_case;
 INSERT INTO public.ff_luxe_driver_grievances(order_id,driver_user_id,category,details,case_id) VALUES(p_order,auth.uid(),p_category,btrim(p_details),v_case) RETURNING id INTO v_id;
 INSERT INTO public.ff41_case_events(case_id,actor_id,action,new_status,note) VALUES(v_case,auth.uid(),'created','open','تم تسجيل تظلم الموصل الخاص');
 RETURN jsonb_build_object('submitted',true,'id',v_id,'case_id',v_case);
END $$;
CREATE OR REPLACE FUNCTION ff_private.a10_sync_grievance_status() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF NEW.status IS DISTINCT FROM OLD.status THEN UPDATE public.ff_luxe_driver_grievances SET status=CASE NEW.status WHEN 'open' THEN 'pending' WHEN 'in_review' THEN 'in_review' ELSE 'resolved' END WHERE case_id=NEW.id;END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION ff_private.a10_sync_grievance_status() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER a10_grievance_status AFTER UPDATE OF status ON public.ff41_cases FOR EACH ROW EXECUTE FUNCTION ff_private.a10_sync_grievance_status();
CREATE OR REPLACE FUNCTION public.ff41_case_list(p_status text DEFAULT NULL::text, p_kind text DEFAULT NULL::text, p_limit integer DEFAULT 60)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 DECLARE v_uid uuid:=auth.uid();v_role text;v_items jsonb;v_open integer;v_review integer;
 BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=v_uid AND active=true;
 IF v_uid IS NULL OR v_role IS NULL THEN RAISE EXCEPTION 'الحساب غير مفعل' USING ERRCODE='42501'; END IF;
 IF p_limit IS NULL OR p_limit<1 OR p_limit>100 THEN RAISE EXCEPTION 'حد النتائج غير صالح'; END IF;
 IF p_status IS NOT NULL AND p_status<>'' AND p_status NOT IN ('open','in_review','resolved','closed') THEN
 RAISE EXCEPTION 'حالة غير صالحة'; END IF;
 IF p_kind IS NOT NULL AND p_kind<>'' AND p_kind NOT IN ('customer_complaint','staff_grievance') THEN
 RAISE EXCEPTION 'نوع بلاغ غير صالح'; END IF;
 SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
 'id',x.id,'kind',x.kind,'subject',x.subject,'status',x.status,'priority',x.priority,
 'branch_id',x.branch_id,'order_number',x.order_number,
 'created_by',x.created_by,'creator',x.creator,'created_at',x.created_at,'updated_at',x.updated_at
 ) ORDER BY x.updated_at DESC,x.id DESC),'[]'::jsonb)
 INTO v_items FROM (
 SELECT c.id,c.kind,c.subject,c.status,c.priority,c.branch_id,o.order_number,
 c.created_by,p.display_name AS creator,c.created_at,c.updated_at
 FROM public.ff41_cases c
 JOIN public.ff_profiles p ON p.user_id=c.created_by
 LEFT JOIN public.ff_orders o ON o.id=c.order_id
 WHERE (COALESCE(p_status,'')='' OR c.status=p_status)
 AND (COALESCE(p_kind,'')='' OR c.kind=p_kind)
 AND (
 ff_private.a10_case_visible(v_role,c.kind,c.created_by,c.branch_id,c.order_id)
 )
 ORDER BY c.updated_at DESC,c.id DESC LIMIT p_limit
 ) x;
 SELECT count(*) FILTER(WHERE c.status='open')::integer,
 count(*) FILTER(WHERE c.status='in_review')::integer
 INTO v_open,v_review
 FROM public.ff41_cases c
 WHERE (
 ff_private.a10_case_visible(v_role,c.kind,c.created_by,c.branch_id,c.order_id)
 );
 RETURN pg_catalog.jsonb_build_object('items',v_items,'open_count',v_open,'review_count',v_review);
 END $function$;
CREATE OR REPLACE FUNCTION public.ff41_case_detail(p_case uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 DECLARE v_uid uuid:=auth.uid();v_role text;v_item jsonb;v_events jsonb;
 BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=v_uid AND active=true;
 IF v_uid IS NULL OR v_role IS NULL THEN RAISE EXCEPTION 'الحساب غير مفعل' USING ERRCODE='42501'; END IF;
 SELECT pg_catalog.jsonb_build_object(
 'id',c.id,'kind',c.kind,'branch_id',c.branch_id,'order_id',c.order_id,
 'order_number',o.order_number,'subject',c.subject,'description',c.description,
 'priority',c.priority,'status',c.status,'resolution',c.resolution,
 'customer_name',c.customer_name,'customer_phone',
 CASE WHEN v_role='supervisor' THEN NULL ELSE c.customer_phone END,
 'contact_channel',c.contact_channel,
 'created_by',c.created_by,'creator',p.display_name,'created_at',c.created_at,
 'updated_at',c.updated_at,'resolved_at',c.resolved_at,'closed_at',c.closed_at
 ) INTO v_item
 FROM public.ff41_cases c
 JOIN public.ff_profiles p ON p.user_id=c.created_by
 LEFT JOIN public.ff_orders o ON o.id=c.order_id
 WHERE c.id=p_case
 AND (
 ff_private.a10_case_visible(v_role,c.kind,c.created_by,c.branch_id,c.order_id)
 );
 IF v_item IS NULL THEN RAISE EXCEPTION 'البلاغ غير متاح لحسابك' USING ERRCODE='42501'; END IF;
 SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
 'id',e.id,'action',e.action,'actor',e.actor,'created_at',e.created_at,
 'old_status',e.old_status,'new_status',e.new_status,'note',e.note
 ) ORDER BY e.id ASC),'[]'::jsonb)
 INTO v_events FROM (
 SELECT h.id,h.action,p.display_name AS actor,h.created_at,h.old_status,h.new_status,h.note
 FROM public.ff41_case_events h
 JOIN public.ff_profiles p ON p.user_id=h.actor_id
 WHERE h.case_id=p_case ORDER BY h.id DESC LIMIT 200
 ) e;
 RETURN pg_catalog.jsonb_build_object('item',v_item,'events',v_events);
 END $function$;
CREATE OR REPLACE FUNCTION public.ff41_case_comment(p_case uuid, p_body text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 DECLARE v_uid uuid:=auth.uid();v_role text;v_kind text;v_owner uuid;
 v_branch uuid;v_order uuid;v_status text;v_comment text:=pg_catalog.btrim(COALESCE(p_body,''));
 v_recent integer;
 BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=v_uid AND active=true;
 IF v_uid IS NULL OR v_role IS NULL THEN RAISE EXCEPTION 'الحساب غير مفعل' USING ERRCODE='42501'; END IF;
 IF pg_catalog.char_length(v_comment) NOT BETWEEN 2 AND 2000 THEN
 RAISE EXCEPTION 'التعليق يجب أن يكون بين حرفين و2000 حرف'; END IF;
 SELECT kind,created_by,branch_id,order_id,status INTO v_kind,v_owner,v_branch,v_order,v_status
 FROM public.ff41_cases WHERE id=p_case FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'البلاغ غير موجود'; END IF;
 IF NOT ff_private.a10_case_visible(v_role,v_kind,v_owner,v_branch,v_order) THEN RAISE EXCEPTION 'ليس لديك صلاحية التعليق على البلاغ' USING ERRCODE='42501'; END IF;
 IF v_status='closed' THEN RAISE EXCEPTION 'البلاغ مغلق؛ اطلب من المدير إعادة فتحه'; END IF;
 SELECT count(*)::integer INTO v_recent FROM public.ff41_case_events
 WHERE actor_id=v_uid AND action='comment' AND created_at>now()-interval '24 hours';
 IF v_recent>=100 THEN RAISE EXCEPTION 'تم بلوغ الحد اليومي للتعليقات'; END IF;
 INSERT INTO public.ff41_case_events(case_id,actor_id,action,old_status,new_status,note)
 VALUES(p_case,v_uid,'comment',v_status,v_status,v_comment);
 UPDATE public.ff41_cases SET updated_at=now() WHERE id=p_case;
 RETURN pg_catalog.jsonb_build_object('saved',true,'case_id',p_case);
 END $function$;
CREATE OR REPLACE FUNCTION public.ff41_case_create(p_kind text, p_subject text, p_description text, p_branch uuid DEFAULT NULL::uuid, p_order uuid DEFAULT NULL::uuid, p_priority text DEFAULT 'normal'::text, p_customer_name text DEFAULT NULL::text, p_customer_phone text DEFAULT NULL::text, p_channel text DEFAULT 'phone'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 DECLARE
 v_uid uuid:=auth.uid();v_role text;v_branch uuid:=p_branch;
 v_subject text:=pg_catalog.btrim(COALESCE(p_subject,''));
 v_description text:=pg_catalog.btrim(COALESCE(p_description,''));
 v_priority text:=COALESCE(p_priority,'normal');v_order_branch uuid;v_order_phone text;
 v_customer_name text:=NULLIF(pg_catalog.btrim(COALESCE(p_customer_name,'')),'');
 v_customer_phone text:=NULLIF(pg_catalog.btrim(COALESCE(p_customer_phone,'')),'');
 v_id uuid;v_recent integer;
 BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=v_uid AND active=true;
 IF v_uid IS NULL OR v_role IS NULL THEN
 RAISE EXCEPTION 'الحساب غير مفعل' USING ERRCODE='42501'; END IF;
 IF p_kind NOT IN ('customer_complaint','staff_grievance') OR p_kind IS NULL THEN
 RAISE EXCEPTION 'نوع البلاغ غير صالح'; END IF;
 IF pg_catalog.char_length(v_subject) NOT BETWEEN 4 AND 140 THEN
 RAISE EXCEPTION 'عنوان البلاغ يجب أن يكون بين 4 و140 حرفاً'; END IF;
 IF pg_catalog.char_length(v_description) NOT BETWEEN 10 AND 4000 THEN
 RAISE EXCEPTION 'تفاصيل البلاغ يجب أن تكون بين 10 و4000 حرف'; END IF;
 IF v_priority NOT IN ('low','normal','high') THEN RAISE EXCEPTION 'درجة الأولوية غير صالحة'; END IF;

 IF p_kind='customer_complaint' THEN
 IF v_role NOT IN ('manager','customer_service','cashier') THEN
 RAISE EXCEPTION 'تسجيل شكوى العميل غير متاح لدورك' USING ERRCODE='42501'; END IF;
 IF p_channel IS NULL OR p_channel NOT IN ('phone','whatsapp','walk_in','other') THEN
 RAISE EXCEPTION 'قناة التواصل غير صالحة'; END IF;
 IF v_customer_name IS NOT NULL AND pg_catalog.char_length(v_customer_name) NOT BETWEEN 2 AND 120 THEN
 RAISE EXCEPTION 'اسم العميل يجب أن يكون بين 2 و120 حرفاً'; END IF;
 IF v_customer_phone IS NOT NULL AND (pg_catalog.char_length(v_customer_phone) NOT BETWEEN 6 AND 30
 OR v_customer_phone !~ '^[+0-9 ()-]+$') THEN
 RAISE EXCEPTION 'رقم التواصل غير صالح'; END IF;
 IF p_order IS NOT NULL THEN
 SELECT o.branch_id,o.phone_snapshot INTO v_order_branch,v_order_phone FROM public.ff_orders o
 WHERE o.id=p_order AND o.order_type='delivery';
 IF v_order_branch IS NULL OR NOT ff_private.a10_branch_visible(v_role,v_order_branch) OR (v_role='cashier' AND NOT ff_private.a10_cashier_order_visible(p_order)) THEN RAISE EXCEPTION 'طلب التوصيل غير متاح لحسابك' USING ERRCODE='42501';END IF;
 IF v_branch IS NULL THEN v_branch:=v_order_branch; END IF;
 IF v_branch<>v_order_branch THEN RAISE EXCEPTION 'الطلب لا يتبع الفرع المحدد'; END IF;
 IF v_customer_phone IS NULL AND v_order_phone IS NOT NULL THEN
 v_customer_phone:=pg_catalog.btrim(v_order_phone);
 IF pg_catalog.char_length(v_customer_phone) NOT BETWEEN 6 AND 30 OR
 v_customer_phone !~ '^[+0-9 ()-]+$' THEN v_customer_phone:=NULL; END IF;
 END IF;
 END IF;
 IF v_branch IS NULL THEN RAISE EXCEPTION 'يرجى اختيار فرع الشكوى'; END IF;
 ELSE
 IF v_role='manager' THEN
 RAISE EXCEPTION 'تظلم الموظف يجب أن يُقدّم من حساب الموظف نفسه' USING ERRCODE='42501'; END IF;
 IF p_order IS NOT NULL THEN RAISE EXCEPTION 'التظلم الوظيفي لا يرتبط بطلب عميل'; END IF;
 -- Automatically associate a driver with their own branch; do not trust client branch input.
 IF v_role='driver' THEN
 SELECT d.branch_id INTO v_order_branch FROM public.ff38_driver_links l
 JOIN public.ff_drivers d ON d.id=l.driver_id AND d.active=true
 WHERE l.user_id=v_uid;
 IF v_order_branch IS NULL THEN RAISE EXCEPTION 'حساب الموصل غير مربوط بفرع' USING ERRCODE='42501'; END IF;
 IF v_branch IS NOT NULL AND v_branch<>v_order_branch THEN
 RAISE EXCEPTION 'لا يمكنك تحديد فرع آخر' USING ERRCODE='42501'; END IF;
 v_branch:=v_order_branch;
 END IF;
 IF v_role='cashier' AND v_branch IS NULL THEN
 SELECT b.branch_id INTO v_branch FROM public.ff_user_branches b
 WHERE b.user_id=v_uid ORDER BY b.branch_id LIMIT 1;
 END IF;
 END IF;
 IF v_branch IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM public.ff_branches WHERE id=v_branch AND active=true
 ) THEN RAISE EXCEPTION 'الفرع غير متاح'; END IF;
 IF v_branch IS NOT NULL AND NOT ff_private.a10_branch_visible(v_role,v_branch) THEN RAISE EXCEPTION 'الفرع غير مصرح' USING ERRCODE='42501';END IF;
 IF v_branch IS NOT NULL AND v_role='cashier' AND NOT EXISTS (
 SELECT 1 FROM public.ff_user_branches b
 WHERE b.user_id=v_uid AND b.branch_id=v_branch
 ) THEN RAISE EXCEPTION 'الفرع غير مصرح لك' USING ERRCODE='42501'; END IF;

 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff41-create-'||v_uid::text));
 SELECT count(*)::integer INTO v_recent FROM public.ff41_cases
 WHERE created_by=v_uid AND created_at>now()-interval '24 hours';
 IF v_recent>=20 THEN RAISE EXCEPTION 'تم بلوغ حد 20 بلاغاً خلال 24 ساعة'; END IF;
 INSERT INTO public.ff41_cases(kind,branch_id,order_id,subject,description,customer_name,customer_phone,contact_channel,priority,created_by)
 VALUES(p_kind,v_branch,p_order,v_subject,v_description,
 CASE WHEN p_kind='customer_complaint' THEN v_customer_name ELSE NULL END,
 CASE WHEN p_kind='customer_complaint' THEN v_customer_phone ELSE NULL END,
 CASE WHEN p_kind='customer_complaint' THEN p_channel ELSE NULL END,
 v_priority,v_uid)
 RETURNING id INTO v_id;
 INSERT INTO public.ff41_case_events(case_id,actor_id,action,old_status,new_status,note)
 VALUES(v_id,v_uid,'created',NULL,'open','تم تسجيل البلاغ');
 RETURN pg_catalog.jsonb_build_object('saved',true,'case_id',v_id,'status','open');
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
 AND ff_private.a10_case_visible(v_role,c.kind,c.created_by,c.branch_id,c.order_id)
 AND NOT EXISTS(SELECT 1 FROM public.ff_case_alert_receipts r WHERE r.case_id=c.id AND r.user_id=auth.uid());
 RETURN jsonb_build_object('unread_count',v_count,'items',coalesce((
 SELECT jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC) FROM
 (SELECT c.id,c.subject,c.priority,c.status,c.created_at,c.branch_id,c.order_id,o.order_number,
 b.name as branch_name, (r.seen_at IS NOT NULL) as seen
 FROM public.ff41_cases c LEFT JOIN public.ff_orders o ON o.id=c.order_id
 LEFT JOIN public.ff_branches b ON b.id=c.branch_id
 LEFT JOIN public.ff_case_alert_receipts r ON r.case_id=c.id AND r.user_id=auth.uid()
 WHERE c.kind='customer_complaint' AND c.order_id IS NOT NULL
 AND ff_private.a10_case_visible(v_role,c.kind,c.created_by,c.branch_id,c.order_id)
 ORDER BY c.created_at DESC LIMIT least(greatest(coalesce(p_limit,50),1),100)) t
 ),'[]'::jsonb));
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
 AND ff_private.a10_case_visible(v_role,c.kind,c.created_by,c.branch_id,c.order_id)
 ) THEN RAISE EXCEPTION 'البلاغ غير متاح لحسابك' USING ERRCODE='42501';END IF;
 INSERT INTO public.ff_case_alert_receipts(case_id,user_id)
 VALUES(p_case,auth.uid()) ON CONFLICT(case_id,user_id) DO NOTHING;
 RETURN true;
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
 IF v_role='cashier' AND NOT ff_private.a10_cashier_order_visible(p_order) THEN RAISE EXCEPTION 'الطلب خارج نقطة الكاشير المصرح بها' USING ERRCODE='42501';END IF;
 IF v_role='customer_service' AND NOT EXISTS(SELECT FROM public.ff_orders o WHERE o.id=p_order AND o.created_by=auth.uid()) THEN RAISE EXCEPTION 'الطلب لا يخص موظف الخدمة' USING ERRCODE='42501';END IF;
 IF p_stars IS NULL OR NOT EXISTS(SELECT FROM public.ff_orders o WHERE o.id=p_order AND o.status NOT IN ('cancelled','canceled','closed')) THEN RAISE EXCEPTION 'التقييم غير متاح لهذا الطلب';END IF;
 INSERT INTO public.ff51_driver_ratings(order_id,driver_id,stars,note,rater_id,rater_role)
 VALUES(p_order,v_driver,p_stars,left(coalesce(p_note,''),500),auth.uid(),
 CASE WHEN v_role='manager' THEN 'manager' ELSE 'cashier' END);
 RETURN jsonb_build_object('saved',true);
 END $function$;
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
 WHERE o.id=p_order AND o.status <> 'cancelled' AND t.cashier_stage='handed_over';
 IF v_driver IS NULL THEN RAISE EXCEPTION 'الطلب غير موجود أو لا يوجد موصل مسند'; END IF;
 IF v_role='cashier' AND NOT EXISTS (
 SELECT 1 FROM public.ff_user_branches b WHERE b.user_id=auth.uid() AND b.branch_id=v_branch
 ) THEN RAISE EXCEPTION 'ليس لديك صلاحية التقييم لهذا الفرع' USING ERRCODE='42501'; END IF;
 v_rating_role:=CASE WHEN v_role='manager' THEN 'manager' ELSE 'cashier' END;
 IF v_role='cashier' AND NOT ff_private.a10_cashier_order_visible(p_order) THEN RAISE EXCEPTION 'الطلب خارج نقطة الكاشير المصرح بها' USING ERRCODE='42501';END IF;
 IF v_role='customer_service' AND NOT EXISTS(SELECT FROM public.ff_orders o WHERE o.id=p_order AND o.created_by=auth.uid()) THEN RAISE EXCEPTION 'الطلب لا يخص موظف الخدمة' USING ERRCODE='42501';END IF;
 IF p_stars IS NULL OR NOT EXISTS(SELECT FROM public.ff_orders o WHERE o.id=p_order AND o.status NOT IN ('cancelled','canceled','closed')) THEN RAISE EXCEPTION 'التقييم غير متاح لهذا الطلب';END IF;
 INSERT INTO public.ff51_driver_ratings(order_id,driver_id,stars,note,rater_id,rater_role)
 VALUES(p_order,v_driver,p_stars,left(btrim(coalesce(p_note,'')),500),auth.uid(),v_rating_role)
 ON CONFLICT (order_id,rater_role) DO NOTHING;
 IF NOT FOUND THEN RAISE EXCEPTION 'تم تسجيل تقييم هذا الدور مسبقًا';END IF;
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
 IF v_role='cashier' AND NOT ff_private.a10_cashier_order_visible(p_order) THEN RAISE EXCEPTION 'الطلب خارج نقطة الكاشير المصرح بها' USING ERRCODE='42501';END IF;
 IF v_role='customer_service' AND NOT EXISTS(SELECT FROM public.ff_orders o WHERE o.id=p_order AND o.created_by=auth.uid()) THEN RAISE EXCEPTION 'الطلب لا يخص موظف الخدمة' USING ERRCODE='42501';END IF;
 IF p_stars IS NULL OR NOT EXISTS(SELECT FROM public.ff_orders o WHERE o.id=p_order AND o.status NOT IN ('cancelled','canceled','closed')) THEN RAISE EXCEPTION 'التقييم غير متاح لهذا الطلب';END IF;
 INSERT INTO public.ff51_driver_ratings(order_id,driver_id,stars,note,rater_id,rater_role)
 VALUES(p_order,v_driver,p_stars,left(btrim(coalesce(p_note,'')),500),auth.uid(),v_role)
 ON CONFLICT (order_id,rater_role) DO NOTHING;
 IF NOT FOUND THEN RAISE EXCEPTION 'تم تسجيل تقييم هذا الدور مسبقًا';END IF;
 RETURN jsonb_build_object('saved',true,'role',v_role);
END
$function$;
CREATE OR REPLACE FUNCTION public.ff_luxe_driver_rate_order(p_order uuid, p_cs integer, p_cashier integer, p_customer integer, p_overall integer, p_note text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_driver uuid;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='driver') THEN RAISE EXCEPTION 'الموصل فقط' USING ERRCODE='42501'; END IF;
 IF p_cs IS NULL OR p_cashier IS NULL OR p_customer IS NULL OR p_overall IS NULL OR p_cs NOT BETWEEN 1 AND 5 OR p_cashier NOT BETWEEN 1 AND 5 OR p_customer NOT BETWEEN 1 AND 5 OR p_overall NOT BETWEEN 1 AND 5 THEN RAISE EXCEPTION 'التقييم من 1 إلى 5'; END IF;
 SELECT l.driver_id INTO v_driver FROM public.ff38_driver_links l WHERE l.user_id=auth.uid() LIMIT 1;
 IF v_driver IS NULL OR NOT EXISTS(SELECT 1 FROM public.ff38_delivery_tasks t JOIN public.ff_orders o ON o.id=t.order_id WHERE t.order_id=p_order AND t.driver_id=v_driver AND o.status='delivered') THEN RAISE EXCEPTION 'الطلب لا يخص حساب الموصل' USING ERRCODE='42501'; END IF;
 INSERT INTO public.ff_luxe_driver_feedback(order_id,driver_user_id,customer_service_stars,cashier_stars,customer_stars,overall_stars,note)
 VALUES(p_order,auth.uid(),p_cs,p_cashier,p_customer,p_overall,left(coalesce(p_note,''),1000))
 ON CONFLICT(order_id,driver_user_id) DO NOTHING;
 IF NOT FOUND THEN RAISE EXCEPTION 'تم تسجيل تقييمك لهذا الطلب مسبقًا';END IF;
 RETURN jsonb_build_object('saved',true);
END;$function$;

CREATE OR REPLACE FUNCTION public.ff_luxe_rating_summary_period(p_from date DEFAULT NULL,p_to date DEFAULT NULL,p_branch uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_role text; d_from date:=coalesce(p_from,public.ff_business_date(now()));d_to date:=coalesce(p_to,public.ff_business_date(now()));v_driver uuid;answer jsonb;
BEGIN
 SELECT p.role INTO v_role FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active;
 IF v_role IS NULL OR v_role NOT IN ('manager','supervisor','driver') OR EXISTS(SELECT FROM public.ff38_staff_permission_overrides WHERE user_id=auth.uid() AND permission_key='view_reports' AND NOT allowed) OR EXISTS(SELECT FROM ff_private.a10_report_section_grants WHERE user_id=auth.uid() AND section='ratings' AND NOT allowed) THEN RAISE EXCEPTION 'غير مصرح بتقرير التقييمات' USING ERRCODE='42501';END IF;
 IF d_from>d_to OR d_from<date '2020-01-01' OR d_to>public.ff_business_date(now()) OR d_to-d_from>366 THEN RAISE EXCEPTION 'نطاق التقييمات غير صحيح';END IF;
 IF p_branch IS NOT NULL AND NOT ff_private.a10_branch_visible(v_role,p_branch) THEN RAISE EXCEPTION 'الفرع غير مصرح' USING ERRCODE='42501';END IF;
 IF v_role='driver' THEN SELECT l.driver_id INTO v_driver FROM public.ff38_driver_links l JOIN public.ff_drivers d ON d.id=l.driver_id AND d.active WHERE l.user_id=auth.uid();END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.average DESC,q.name),'[]') INTO answer FROM(SELECT d.id driver_id,d.name,count(*)::int count,round(avg(x.stars),2) average FROM public.ff51_driver_ratings x JOIN public.ff_orders o ON o.id=x.order_id JOIN public.ff_drivers d ON d.id=x.driver_id WHERE public.ff_business_date(x.rated_at) BETWEEN d_from AND d_to AND (p_branch IS NULL OR o.branch_id=p_branch) AND (v_role='driver' AND x.driver_id=v_driver OR v_role<>'driver' AND ff_private.a10_branch_visible(v_role,o.branch_id)) GROUP BY d.id,d.name)q;
 RETURN answer;
END $$;
CREATE OR REPLACE FUNCTION public.ff51_driver_rating_summary()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.ff_luxe_rating_summary_period(greatest(date '2020-01-01',public.ff_business_date(now())-366),public.ff_business_date(now()),NULL)
$$;
-- A controlled escalation path for internal low ratings, no automatic sanction.
CREATE OR REPLACE FUNCTION public.ff_a10_escalate_rating(p_rating uuid,p_note text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.ff51_driver_ratings; b uuid; n bigint; cid uuid; label text;
BEGIN
 IF NOT public.ff_is_manager() OR auth.uid() IS NULL THEN RAISE EXCEPTION 'التصعيد للمدير العام فقط' USING ERRCODE='42501';END IF;
 SELECT * INTO r FROM public.ff51_driver_ratings WHERE id=p_rating AND stars<=2 FOR UPDATE;
 IF r.id IS NULL OR length(btrim(coalesce(p_note,''))) NOT BETWEEN 10 AND 1000 THEN RAISE EXCEPTION 'اختر تقييمًا منخفضًا واكتب سبب المتابعة';END IF;
 SELECT branch_id,order_number INTO b,n FROM public.ff_orders WHERE id=r.order_id;
 label:='متابعة جودة — تقييم #'||r.id::text;
 SELECT id INTO cid FROM public.ff41_cases WHERE subject=label AND kind='customer_complaint' AND order_id=r.order_id;
 IF cid IS NOT NULL THEN RETURN jsonb_build_object('ok',true,'case_id',cid,'already_exists',true);END IF;
 -- No private rating note copied to the complaint. Manager supplies a safe operational reason explicitly.
 INSERT INTO public.ff41_cases(kind,branch_id,order_id,subject,description,priority,created_by,contact_channel) VALUES('customer_complaint',b,r.order_id,label,btrim(p_note),'high',auth.uid(),'other') RETURNING id INTO cid;
 INSERT INTO public.ff41_case_events(case_id,actor_id,action,new_status,note) VALUES(cid,auth.uid(),'created','open','متابعة جودة يدوية؛ لا عقوبة آلية');
 RETURN jsonb_build_object('ok',true,'case_id',cid,'already_exists',false);
END $$;
REVOKE ALL ON FUNCTION public.ff_a10_escalate_rating(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a10_escalate_rating(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.ff_a10_driver_rating_queue()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE d uuid;
BEGIN
 SELECT l.driver_id INTO d FROM public.ff38_driver_links l JOIN public.ff_profiles p ON p.user_id=l.user_id AND p.active AND p.role='driver' JOIN public.ff_drivers dr ON dr.id=l.driver_id AND dr.active WHERE l.user_id=auth.uid();
 IF d IS NULL THEN RAISE EXCEPTION 'الموصل فقط' USING ERRCODE='42501';END IF;
 RETURN coalesce((SELECT jsonb_agg(to_jsonb(q) ORDER BY q.delivered_at DESC) FROM (SELECT o.id,o.order_number,coalesce(t.delivered_at,o.delivered_at) delivered_at FROM public.ff_orders o JOIN public.ff38_delivery_tasks t ON t.order_id=o.id WHERE t.driver_id=d AND o.status='delivered' AND coalesce(t.delivered_at,o.delivered_at)>now()-interval '30 days' AND NOT EXISTS(SELECT FROM public.ff_luxe_driver_feedback f WHERE f.order_id=o.id AND f.driver_user_id=auth.uid()) ORDER BY coalesce(t.delivered_at,o.delivered_at) DESC LIMIT 50) q),'[]');
END $$;
CREATE OR REPLACE FUNCTION public.ff_a10_customer_rate(p_order uuid,p_stars integer,p_note text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_phone text; v_number text; v_order uuid;
BEGIN
 IF auth.uid() IS NULL OR EXISTS(SELECT FROM public.ff_profiles WHERE user_id=auth.uid()) THEN RAISE EXCEPTION 'العميل المخول فقط' USING ERRCODE='42501';END IF;
 SELECT phone INTO v_phone FROM auth.users WHERE id=auth.uid() AND phone_confirmed_at IS NOT NULL;
 v_number:=regexp_replace(coalesce(v_phone,''),'[^0-9]','','g');
 IF v_number !~ '^9677[0-9]{8}$' THEN RAISE EXCEPTION 'يرجى تأكيد ملكية رقم الهاتف' USING ERRCODE='42501';END IF;
 v_number:=right(v_number,9);
 IF p_order IS NULL OR p_stars IS NULL OR p_stars NOT BETWEEN 1 AND 5 OR length(coalesce(p_note,''))>500 THEN RAISE EXCEPTION 'اختر من نجمة إلى خمس نجوم وملاحظة اختيارية حتى 500 حرف';END IF;
 UPDATE public.ff_orders o SET rating=p_stars,rating_note=nullif(btrim(coalesce(p_note,'')),''),updated_at=now()
 WHERE o.id=p_order AND o.status='delivered' AND o.rating IS NULL AND regexp_replace(translate(coalesce(o.phone_snapshot,''),'٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','01234567890123456789'),'[^0-9]','','g') IN(v_number,'967'||v_number,'00967'||v_number)
 RETURNING o.id INTO v_order;
 IF v_order IS NULL THEN RAISE EXCEPTION 'الطلب غير متاح للتقييم أو تم تقييمه مسبقًا' USING ERRCODE='42501';END IF;
 RETURN jsonb_build_object('saved',true);
END $$;
REVOKE ALL ON FUNCTION public.ff_a10_driver_rating_queue(),public.ff_a10_customer_rate(uuid,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a10_driver_rating_queue(),public.ff_a10_customer_rate(uuid,integer,text) TO authenticated;
