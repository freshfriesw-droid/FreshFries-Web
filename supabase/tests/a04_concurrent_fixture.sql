-- A04 test only: loads after A03 core and lifecycle fixtures; real RPC bodies, synthetic rows.
create table public.ff_branches(id uuid primary key,name text not null,code text not null,active boolean not null default true);
create table public.ff_v9_assembly_access(user_id uuid,branch_id uuid,enabled boolean not null default true,primary key(user_id,branch_id));
alter table public.ff_profiles add column display_name text not null default 'QA';
create table public.ff_menu_categories(id uuid primary key,name text,active boolean default true);
create table public.ff_menu_items(id uuid primary key,category_id uuid,name text,active boolean default true);
create table public.ff_luxe_cashier_staff_desks(user_id uuid,desk_code text);
create table public.ff_luxe_cashier_order_desks(order_id uuid,desk_code text);
create table public.ff_burger_tickets(id uuid primary key default gen_random_uuid(),client_token uuid not null unique,branch_id uuid not null,order_kind text not null,
 delivery_order_id uuid,invoice_ref text not null default '',cashier_id uuid not null,cashier_name text not null,items jsonb not null,notes text not null default '',
 kitchen_id uuid,kitchen_name text,status text not null default 'sent',sent_at timestamptz not null default now(),accepted_at timestamptz,ready_at timestamptz,
 acknowledged_at timestamptz,acknowledged_by uuid,notes_confirmed_at timestamptz,notes_confirmed_by uuid);
CREATE OR REPLACE FUNCTION public.ff_v12_assembly_me()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 DECLARE v_role text;v_branch uuid;v_name text;v_count integer;
 BEGIN
 SELECT p.role INTO v_role FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active;
 IF v_role IS DISTINCT FROM 'assembly' THEN RETURN pg_catalog.jsonb_build_object('is_assembly',false); END IF;
 SELECT count(*), (array_agg(a.branch_id))[1] INTO v_count,v_branch
 FROM public.ff_v9_assembly_access a
 JOIN public.ff_user_branches ub ON ub.user_id=a.user_id AND ub.branch_id=a.branch_id
 JOIN public.ff_branches b ON b.id=a.branch_id AND b.active
 WHERE a.user_id=auth.uid() AND a.enabled;
 IF v_count<>1 THEN RETURN pg_catalog.jsonb_build_object('is_assembly',false,'reason','assembly_branch_count'); END IF;
 SELECT name INTO v_name FROM public.ff_branches WHERE id=v_branch;
 RETURN pg_catalog.jsonb_build_object('is_assembly',true,'branch',pg_catalog.jsonb_build_object('id',v_branch,'name',v_name));
 END $function$;

CREATE OR REPLACE FUNCTION public.ff_v9_assembly_set_stage(p_order uuid, p_stage text, p_expected_stage text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 DECLARE
 v_actor uuid := auth.uid(); v_role text; v_branch uuid; v_old text;
 v_task_driver uuid; v_order_driver uuid; v_phase text; v_status text;
 BEGIN
 IF v_actor IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول' USING ERRCODE='42501'; END IF;
 IF p_order IS NULL OR p_stage IS NULL OR p_expected_stage IS NULL OR
 p_stage NOT IN ('preparing','ready','handed_over') THEN
 RAISE EXCEPTION 'مدخلات غير صالحة' USING ERRCODE='22023'; END IF;
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=v_actor AND active=true;
 IF v_role IS NULL THEN RAISE EXCEPTION 'حساب غير مفعل' USING ERRCODE='42501'; END IF;
 
 IF v_role <> 'manager' AND (v_role <> 'assembly' OR public.ff_v12_assembly_me()->>'is_assembly' IS DISTINCT FROM 'true') THEN
 RAISE EXCEPTION 'صلاحية التجميع غير متاحة' USING ERRCODE='42501';END IF;
 PERFORM 1 FROM public.ff_orders WHERE id=p_order FOR UPDATE;
 SELECT o.branch_id,t.cashier_stage,t.driver_id,o.driver_id,t.phase,o.status
 INTO v_branch,v_old,v_task_driver,v_order_driver,v_phase,v_status
 FROM public.ff38_delivery_tasks t JOIN public.ff_orders o ON o.id=t.order_id
 WHERE t.order_id=p_order FOR UPDATE OF t;
 IF NOT FOUND THEN RAISE EXCEPTION 'الطلب غير متاح' USING ERRCODE='P0002'; END IF;
 IF v_role <> 'manager' AND NOT EXISTS (
 SELECT 1 FROM public.ff_v9_assembly_access a JOIN public.ff_user_branches ub
 ON ub.user_id=a.user_id AND ub.branch_id=a.branch_id
 WHERE a.user_id=v_actor AND a.branch_id=v_branch AND a.enabled
 ) THEN RAISE EXCEPTION 'لا توجد صلاحية لهذا الفرع' USING ERRCODE='42501'; END IF;
 IF v_old IS DISTINCT FROM p_expected_stage THEN
 RAISE EXCEPTION 'تغيرت حالة الطلب؛ حدّث البيانات' USING ERRCODE='40001'; END IF;
 IF v_status IN ('cancelled','canceled','closed','delivered','reservation_completed') OR v_phase='delivered' THEN
 RAISE EXCEPTION 'الطلب مغلق' USING ERRCODE='22023'; END IF;
 IF v_phase IS DISTINCT FROM 'assigned' THEN
 RAISE EXCEPTION 'بدأت رحلة التوصيل؛ لا يمكن تعديل التجميع' USING ERRCODE='22023'; END IF;
 IF EXISTS (
 SELECT 1 FROM public.ff49_driver_transfers x
 WHERE x.order_id=p_order AND x.status='pending_cashier'
 ) THEN RAISE EXCEPTION 'تغيير الموصل بانتظار موافقة الكاشير' USING ERRCODE='22023'; END IF;
 IF v_task_driver IS NULL OR v_order_driver IS NULL OR v_task_driver <> v_order_driver THEN
 RAISE EXCEPTION 'يجب التحقق من إسناد الموصل' USING ERRCODE='22023'; END IF;
 IF NOT ((v_old='printed' AND p_stage='preparing') OR
 (v_old='preparing' AND p_stage='ready') OR
 (v_old='ready' AND p_stage='handed_over')) THEN
 RAISE EXCEPTION 'انتقال غير مسموح' USING ERRCODE='22023'; END IF;
 IF NOT EXISTS (
 SELECT 1 FROM public.ff49_cashier_receipts r WHERE r.order_id=p_order
 AND r.received_by IS NOT NULL AND r.invoiced_at IS NOT NULL
 ) THEN RAISE EXCEPTION 'اعتماد الكاشير للقطع غير مكتمل' USING ERRCODE='22023'; END IF;
 IF EXISTS (
 SELECT 1 FROM public.ff38_order_additions a WHERE a.order_id=p_order AND a.status='pending'
 ) THEN RAISE EXCEPTION 'توجد إضافات معلقة تنتظر اعتماد الكاشير' USING ERRCODE='22023'; END IF;
 UPDATE public.ff38_delivery_tasks SET cashier_stage=p_stage,updated_at=now() WHERE order_id=p_order;
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 VALUES(v_actor,'assembly_stage_changed','order',p_order::text,v_branch,
 jsonb_build_object('from',v_old,'to',p_stage,'source','ff_v10_assembly'));
 RETURN jsonb_build_object('ok',true,'order_id',p_order,'stage',p_stage);
 END; $function$;

CREATE OR REPLACE FUNCTION public.ff_v12_assembly_set_stage(p_order uuid, p_stage text, p_expected_stage text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 DECLARE v_access jsonb;v_branch uuid;
 BEGIN
 v_access:=public.ff_v12_assembly_me();
 IF v_access->>'is_assembly' IS DISTINCT FROM 'true' THEN
 RAISE EXCEPTION 'صلاحية التجميع غير متاحة لهذا الحساب' USING ERRCODE='42501'; END IF;
 v_branch:=(v_access->'branch'->>'id')::uuid;
 IF p_order IS NULL OR NOT EXISTS (SELECT 1 FROM public.ff_orders WHERE id=p_order AND branch_id=v_branch) THEN
 RAISE EXCEPTION 'الطلب لا يخص الفرع المصرح' USING ERRCODE='42501'; END IF;
 RETURN public.ff_v9_assembly_set_stage(p_order,p_stage,p_expected_stage);
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
 
 IF v_role='assembly' AND public.ff_v12_assembly_me()->>'is_assembly' IS DISTINCT FROM 'true' THEN
 RAISE EXCEPTION 'صلاحية نقطة التجميع غير متاحة' USING ERRCODE='42501';END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',b.id,'name',b.name,'code',b.code) ORDER BY b.name),'[]'::jsonb)
 INTO v_branches
 FROM public.ff_user_branches ub JOIN public.ff_branches b ON b.id=ub.branch_id
 WHERE ub.user_id=auth.uid() AND b.active;
 IF jsonb_array_length(v_branches)=0 THEN RAISE EXCEPTION 'الحساب غير مرتبط بفرع نشط' USING ERRCODE='42501'; END IF;
 IF v_role IN ('assembly','burger_kitchen') AND jsonb_array_length(v_branches)<>1 THEN
 RAISE EXCEPTION 'يلزم تحديد فرع واحد فقط لحساب قسم البرجر' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('role',v_role,'branches',v_branches);
END $function$;

CREATE OR REPLACE FUNCTION ff_private.a04_burger_has_notes(p_notes text, p_items jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 SELECT length(btrim(coalesce(p_notes,'')))>0 OR EXISTS(
 SELECT 1 FROM jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) i
 WHERE length(btrim(coalesce(i->>'item_notes','')))>0);
$function$;

CREATE OR REPLACE FUNCTION ff_private.ff_burger_ready_notes_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
 IF NEW.status='ready' AND OLD.status='preparing'
 AND ff_private.a04_burger_has_notes(NEW.notes,NEW.items) AND NEW.notes_confirmed_at IS NULL THEN
 RAISE EXCEPTION 'لا يمكن إنهاء البرجر قبل تأكيد تنفيذ الملاحظات' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $function$;

CREATE OR REPLACE FUNCTION public.ff_burger_send(p_branch uuid, p_order_kind text, p_delivery_order uuid, p_invoice text, p_items jsonb, p_notes text, p_token uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_id uuid;v_name text;v_item jsonb;v_item_id uuid;v_qty integer;
 v_checked jsonb:='[]'::jsonb;v_sum integer:=0;v_seen uuid[]:=ARRAY[]::uuid[];
BEGIN
 PERFORM public.ff_burger_my_branch();
 SELECT display_name INTO v_name FROM public.ff_profiles
 WHERE user_id=auth.uid() AND active=true AND role IN ('cashier','assembly');
 IF v_name IS NULL THEN RAISE EXCEPTION 'إرسال أوامر البرجر للكاشير أو نقطة التجميع فقط' USING ERRCODE='42501';END IF;
 IF p_branch IS NULL OR NOT EXISTS(
 SELECT 1 FROM public.ff_user_branches ub JOIN public.ff_branches b ON b.id=ub.branch_id
 WHERE ub.user_id=auth.uid() AND ub.branch_id=p_branch AND b.active)
 THEN RAISE EXCEPTION 'الفرع غير مصرح به' USING ERRCODE='42501';END IF;
 IF p_token IS NULL THEN RAISE EXCEPTION 'معرّف الإرسال مطلوب';END IF;
 SELECT id INTO v_id FROM public.ff_burger_tickets WHERE client_token=p_token AND cashier_id=auth.uid();
 IF v_id IS NOT NULL THEN RETURN jsonb_build_object('saved',true,'id',v_id,'duplicate',true);END IF;
 IF p_order_kind IS NULL OR p_order_kind NOT IN ('local','delivery') THEN RAISE EXCEPTION 'نوع الطلب غير صالح';END IF;
 IF length(btrim(coalesce(p_invoice,'')))>80 THEN RAISE EXCEPTION 'رقم الفاتورة طويل جدًا';END IF;
 IF length(coalesce(p_notes,''))>1000 THEN RAISE EXCEPTION 'الملاحظات طويلة جدًا';END IF;
 IF p_order_kind='local' AND p_delivery_order IS NOT NULL THEN RAISE EXCEPTION 'الطلب المحلي لا يحتاج رقم طلب توصيل';END IF;
 IF p_order_kind='delivery' AND NOT EXISTS(
 SELECT 1 FROM public.ff_orders o WHERE o.id=p_delivery_order AND o.branch_id=p_branch
 AND o.order_type='delivery' AND o.status NOT IN ('cancelled','canceled','closed','delivered','reservation_completed')
 AND (NOT EXISTS(SELECT 1 FROM public.ff_luxe_cashier_staff_desks sd WHERE sd.user_id=auth.uid())
 OR NOT EXISTS(SELECT 1 FROM public.ff_luxe_cashier_order_desks od WHERE od.order_id=o.id)
 OR EXISTS(SELECT 1 FROM public.ff_luxe_cashier_staff_desks sd JOIN public.ff_luxe_cashier_order_desks od
 ON sd.desk_code=od.desk_code WHERE sd.user_id=auth.uid() AND od.order_id=o.id))
 ) THEN RAISE EXCEPTION 'اختر طلب توصيل تابع لفرعك ووجهة الكاشير المسموحة';END IF;
 IF p_items IS NULL OR jsonb_typeof(p_items)<>'array' OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 20
 THEN RAISE EXCEPTION 'حدد صنف برجر واحدًا على الأقل';END IF;
 FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
 IF jsonb_typeof(v_item)<>'object' OR (v_item->>'id') IS NULL OR coalesce(v_item->>'qty','') !~ '^[1-9][0-9]?$'
 THEN RAISE EXCEPTION 'كمية أو صنف البرجر غير صالح';END IF;
 v_item_id:=(v_item->>'id')::uuid;v_qty:=(v_item->>'qty')::integer;
 IF v_item_id=ANY(v_seen) THEN RAISE EXCEPTION 'الصنف مكرر، عدل الكمية في سطر واحد';END IF;
 v_seen:=array_append(v_seen,v_item_id);v_sum:=v_sum+v_qty;
 IF v_sum>100 THEN RAISE EXCEPTION 'الكمية الإجمالية أكبر من المسموح';END IF;
 SELECT i.name INTO v_name FROM public.ff_menu_items i JOIN public.ff_menu_categories c ON c.id=i.category_id
 WHERE i.id=v_item_id AND i.active AND c.active AND
 (c.name ILIKE '%برجر%' OR (c.name='الإضافات' AND i.name IN ('إكسترا سماش','شريحة جبن شيدر')));
 IF v_name IS NULL THEN RAISE EXCEPTION 'يوجد صنف غير فعال أو ليس من قسم البرجر';END IF;
 
 IF (v_item ? 'item_notes' AND jsonb_typeof(v_item->'item_notes') NOT IN ('string','null'))
 OR length(btrim(coalesce(v_item->>'item_notes','')))>300 THEN RAISE EXCEPTION 'ملاحظة الصنف غير صالحة أو تتجاوز 300 حرف';END IF;
 v_checked:=v_checked||jsonb_build_array(jsonb_build_object('id',v_item_id,'name',v_name,'qty',v_qty,'item_notes',nullif(btrim(coalesce(v_item->>'item_notes','')),'')));
 
 END LOOP;
 SELECT display_name INTO v_name FROM public.ff_profiles WHERE user_id=auth.uid();
 INSERT INTO public.ff_burger_tickets
 (client_token,branch_id,order_kind,delivery_order_id,invoice_ref,cashier_id,cashier_name,items,notes)
 VALUES(p_token,p_branch,p_order_kind,p_delivery_order,btrim(coalesce(p_invoice,'')),auth.uid(),v_name,v_checked,btrim(coalesce(p_notes,'')))
 ON CONFLICT(client_token) DO NOTHING RETURNING id INTO v_id;
 IF v_id IS NULL THEN
 SELECT id INTO v_id FROM public.ff_burger_tickets WHERE client_token=p_token AND cashier_id=auth.uid();
 IF v_id IS NULL THEN RAISE EXCEPTION 'معرّف إرسال مستخدم لحساب آخر';END IF;
 END IF;
 RETURN jsonb_build_object('saved',true,'id',v_id);
END $function$;

CREATE OR REPLACE FUNCTION public.ff_burger_transition(p_ticket uuid, p_action text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text;v_person text;v_row public.ff_burger_tickets%ROWTYPE;
BEGIN
 PERFORM public.ff_burger_my_branch();
 SELECT role,display_name INTO v_role,v_person FROM public.ff_profiles
 WHERE user_id=auth.uid() AND active;
 IF v_role IS NULL OR v_role NOT IN ('cashier','assembly','burger_kitchen') THEN
 RAISE EXCEPTION 'الدور غير مخول' USING ERRCODE='42501';END IF;
 SELECT * INTO v_row FROM public.ff_burger_tickets WHERE id=p_ticket FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'الطلب غير موجود';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ff_user_branches ub JOIN public.ff_branches b ON b.id=ub.branch_id AND b.active WHERE ub.user_id=auth.uid() AND ub.branch_id=v_row.branch_id)
 THEN RAISE EXCEPTION 'طلب يخص فرعًا آخر' USING ERRCODE='42501';END IF;
 IF p_action='receive' AND v_role='burger_kitchen' AND v_row.status='sent' THEN
 UPDATE public.ff_burger_tickets SET status='preparing',kitchen_id=auth.uid(),kitchen_name=v_person,
 accepted_at=clock_timestamp() WHERE id=p_ticket;
 ELSIF p_action='ready' AND v_role='burger_kitchen' AND v_row.status='preparing'
 AND v_row.kitchen_id=auth.uid() THEN
 IF ff_private.a04_burger_has_notes(v_row.notes,v_row.items) AND v_row.notes_confirmed_at IS NULL THEN
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

CREATE OR REPLACE FUNCTION public.ff_burger_confirm_notes(p_ticket uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_ticket public.ff_burger_tickets%ROWTYPE;
BEGIN
 PERFORM public.ff_burger_my_branch();
 IF NOT EXISTS (SELECT 1 FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active AND p.role='burger_kitchen') THEN
 RAISE EXCEPTION 'يؤكد التنفيذ موظف البرجر المستلم فقط' USING ERRCODE='42501'; END IF;
 SELECT * INTO v_ticket FROM public.ff_burger_tickets WHERE id=p_ticket FOR UPDATE;
 IF NOT FOUND OR v_ticket.status<>'preparing' OR v_ticket.kitchen_id IS DISTINCT FROM auth.uid() THEN
 RAISE EXCEPTION 'لا يمكن اعتماد الملاحظات لهذا الطلب' USING ERRCODE='42501'; END IF;
 
 IF NOT EXISTS(SELECT 1 FROM public.ff_user_branches ub JOIN public.ff_branches b ON b.id=ub.branch_id AND b.active
 WHERE ub.user_id=auth.uid() AND ub.branch_id=v_ticket.branch_id) THEN
 RAISE EXCEPTION 'طلب يخص فرعًا آخر' USING ERRCODE='42501';END IF;
 IF NOT ff_private.a04_burger_has_notes(v_ticket.notes,v_ticket.items) THEN RETURN true;END IF;
 IF v_ticket.notes_confirmed_at IS NULL THEN
 UPDATE public.ff_burger_tickets SET notes_confirmed_at=clock_timestamp(),notes_confirmed_by=auth.uid()
 WHERE id=p_ticket;
 END IF;
 RETURN true;
END $function$;
CREATE TRIGGER ff_burger_ready_notes_guard BEFORE UPDATE OF status ON public.ff_burger_tickets FOR EACH ROW EXECUTE FUNCTION ff_private.ff_burger_ready_notes_guard();
