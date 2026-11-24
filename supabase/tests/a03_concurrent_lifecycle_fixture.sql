-- TEST ONLY, loaded after a03_concurrent_core_fixture.sql.
-- Live cashier/courier functions, with minimal dependency tables and no production records.
alter table public.ff_orders add column created_at timestamptz default now(),add column delivered_at timestamptz;
alter table public.ff38_delivery_tasks add column cashier_stage text not null default 'waiting',
 add column picked_up_at timestamptz,add column arrived_at timestamptz,add column updated_at timestamptz default now();
create table public.ff_user_branches(user_id uuid,branch_id uuid,primary key(user_id,branch_id));
create table public.ff49_cashier_receipts(order_id uuid primary key,received_by uuid not null,invoiced_by uuid,invoice_ref text,invoiced_at timestamptz);
create table public.ff38_order_additions(id uuid primary key,order_id uuid,status text);
create table public.ff49_driver_transfers(order_id uuid,status text);
create table public.ff52_late_addition_consent(addition_id uuid,state text);
create table public.ff60_workflow_events(order_id uuid,branch_id uuid,event_type text,from_value text,to_value text,driver_id uuid,actor_id uuid,created_at timestamptz default now());
CREATE OR REPLACE FUNCTION public.ff49_can_work_branch(p_branch uuid, p_roles text[])
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 DECLARE v_role text;
 BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active=true;
 IF v_role IS NULL OR NOT v_role=ANY(p_roles) THEN RETURN false; END IF;
 IF v_role IN ('manager','customer_service') THEN RETURN true; END IF;
 RETURN EXISTS(SELECT 1 FROM public.ff_user_branches
 WHERE user_id=auth.uid() AND branch_id=p_branch);
 END $function$;

CREATE OR REPLACE FUNCTION public.ff49_guard_cashier_invoice()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF NEW.cashier_stage IS NOT DISTINCT FROM OLD.cashier_stage THEN
 RETURN NEW;
 END IF;

 IF NOT (
 (OLD.cashier_stage = 'waiting'
 AND NEW.cashier_stage = 'printed')
 OR
 (OLD.cashier_stage = 'printed'
 AND NEW.cashier_stage = 'preparing')
 OR
 (OLD.cashier_stage = 'preparing'
 AND NEW.cashier_stage = 'ready')
 OR
 (OLD.cashier_stage = 'ready'
 AND NEW.cashier_stage = 'handed_over')
 ) THEN
 RAISE EXCEPTION
 'انتقال غير مسموح بين مراحل الكاشير'
 USING ERRCODE = '23514';
 END IF;

 IF NOT EXISTS (
 SELECT 1
 FROM public.ff49_cashier_receipts r
 WHERE r.order_id = NEW.order_id
 AND r.received_by IS NOT NULL
 AND r.invoiced_at IS NOT NULL
 ) THEN
 RAISE EXCEPTION
 'يجب اعتماد الكاشير قبل تغيير المرحلة'
 USING ERRCODE = '23514';
 END IF;

 RETURN NEW;
 END;
 $function$;

CREATE OR REPLACE FUNCTION public.ff38_guard_driver_departure()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 BEGIN
 IF OLD.phase = 'assigned'
 AND NEW.phase <> 'assigned'
 AND EXISTS (
 SELECT 1
 FROM public.ff38_order_additions
 WHERE order_id = NEW.order_id
 AND status = 'pending'
 )
 THEN
 RAISE EXCEPTION
 'لا يمكن خروج الموصل: توجد إضافة تنتظر فاتورة الكاشير';
 END IF;

 RETURN NEW;
 END;
 $function$;

CREATE OR REPLACE FUNCTION public.ff60_task_safety()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF TG_OP='UPDATE' THEN
 IF NEW.cashier_stage='handed_over' AND OLD.cashier_stage IS DISTINCT FROM 'handed_over' THEN
 IF EXISTS(SELECT 1 FROM public.ff38_order_additions a
 WHERE a.order_id=NEW.order_id AND a.status='pending') THEN
 RAISE EXCEPTION 'لا يمكن تسليم الطلب للموصل: توجد إضافات بدون اعتماد فاتورة' USING ERRCODE='23514';
 END IF;
 IF EXISTS(SELECT 1 FROM public.ff49_driver_transfers x
 WHERE x.order_id=NEW.order_id AND x.status='pending_cashier') THEN
 RAISE EXCEPTION 'لا يمكن التسليم: نقل الموصل ينتظر اعتماد الكاشير' USING ERRCODE='23514';
 END IF;
 END IF;
 IF NEW.phase='on_way' AND OLD.phase IS DISTINCT FROM 'on_way' THEN
 IF OLD.phase <> 'assigned' OR NEW.cashier_stage <> 'handed_over' THEN
 RAISE EXCEPTION 'لا يمكن المغادرة قبل تسليم الكاشير' USING ERRCODE='23514';
 END IF;
 IF EXISTS(SELECT 1 FROM public.ff38_order_additions a
 WHERE a.order_id=NEW.order_id AND a.status='pending') THEN
 RAISE EXCEPTION 'لا يمكن المغادرة: إضافات معلقة' USING ERRCODE='23514';
 END IF;
 IF EXISTS(SELECT 1 FROM public.ff49_driver_transfers x
 WHERE x.order_id=NEW.order_id AND x.status='pending_cashier') THEN
 RAISE EXCEPTION 'لا يمكن المغادرة: نقل الموصل غير مؤكد' USING ERRCODE='23514';
 END IF;
 END IF;
 IF NEW.phase='delivered' AND OLD.phase IS DISTINCT FROM 'delivered' THEN
 IF OLD.phase NOT IN ('on_way','arrived') THEN
 RAISE EXCEPTION 'لا يمكن التسليم من هذه المرحلة' USING ERRCODE='23514';
 END IF;
 IF EXISTS(SELECT 1 FROM public.ff38_order_additions a
 WHERE a.order_id=NEW.order_id AND a.status='pending') THEN
 RAISE EXCEPTION 'لا يمكن إنهاء الطلب: توجد إضافة معلقة' USING ERRCODE='23514';
 END IF;
 IF EXISTS(
 SELECT 1 FROM public.ff52_late_addition_consent c
 JOIN public.ff38_order_additions a ON a.id=c.addition_id
 WHERE a.order_id=NEW.order_id AND c.state IN ('awaiting_driver','driver_accepted','invoiced')
 ) THEN
 RAISE EXCEPTION 'لا يمكن إنهاء الطلب: يجب إكمال استلام الإضافة المتأخرة أو إلغاؤها' USING ERRCODE='23514';
 END IF;
 END IF;
 END IF;
 RETURN NEW;
 END $function$;

CREATE OR REPLACE FUNCTION public.ff60_task_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 DECLARE v_branch uuid;
 BEGIN
 SELECT branch_id INTO v_branch FROM public.ff_orders WHERE id=NEW.order_id;
 IF v_branch IS NULL THEN RETURN NEW; END IF;
 IF TG_OP='INSERT' THEN
 INSERT INTO public.ff60_workflow_events(order_id,branch_id,event_type,to_value,driver_id,actor_id)
 VALUES(NEW.order_id,v_branch,'assignment','assigned',NEW.driver_id,auth.uid());
 ELSE
 IF NEW.driver_id IS DISTINCT FROM OLD.driver_id THEN
 INSERT INTO public.ff60_workflow_events(order_id,branch_id,event_type,from_value,to_value,driver_id,actor_id)
 VALUES(NEW.order_id,v_branch,'driver_change',OLD.driver_id::text,NEW.driver_id::text,NEW.driver_id,auth.uid());
 END IF;
 IF NEW.cashier_stage IS DISTINCT FROM OLD.cashier_stage THEN
 INSERT INTO public.ff60_workflow_events(order_id,branch_id,event_type,from_value,to_value,driver_id,actor_id)
 VALUES(NEW.order_id,v_branch,'cashier',OLD.cashier_stage,NEW.cashier_stage,NEW.driver_id,auth.uid());
 END IF;
 IF NEW.phase IS DISTINCT FROM OLD.phase THEN
 INSERT INTO public.ff60_workflow_events(order_id,branch_id,event_type,from_value,to_value,driver_id,actor_id)
 VALUES(NEW.order_id,v_branch,'courier',OLD.phase,NEW.phase,NEW.driver_id,auth.uid());
 END IF;
 END IF;
 RETURN NEW;
 END $function$;

CREATE OR REPLACE FUNCTION public.ff38_cashier_set_stage(p_order uuid, p_stage text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_role text;v_branch uuid;v_existing text;v_old_index int;v_new_index int;v_status text;v_delivered_at timestamptz;
begin
 select role into v_role from public.ff_profiles where user_id=auth.uid() and active;
 if v_role not in ('manager','cashier') or v_role is null then raise exception 'للكاشير فقط' using errcode='42501';end if;
 
 PERFORM 1 FROM public.ff_orders WHERE id=p_order FOR UPDATE;
 select o.branch_id,t.cashier_stage,o.status,t.delivered_at into v_branch,v_existing,v_status,v_delivered_at
 from public.ff38_delivery_tasks t join public.ff_orders o on o.id=t.order_id
 where t.order_id=p_order for update of t;
 if not found then raise exception 'الطلب غير مسند لموصل بعد';end if;
 if v_status in ('cancelled','delivered') or v_delivered_at is not null then
 raise exception 'الطلب ملغي أو منتهٍ؛ لا يمكن تغيير حالة الكاشير';
 end if;
 if v_role='cashier' and not exists(select 1 from public.ff_user_branches where user_id=auth.uid() and branch_id=v_branch)
 then raise exception 'فرع غير مصرح' using errcode='42501';end if;
 v_old_index=array_position(array['waiting','printed','preparing','ready','handed_over'],v_existing);
 v_new_index=array_position(array['waiting','printed','preparing','ready','handed_over'],p_stage);
 if v_new_index is null or v_new_index<>v_old_index+1 then raise exception 'يجب تحديث مراحل الكاشير بالترتيب';end if;
 update public.ff38_delivery_tasks set cashier_stage=p_stage,updated_at=now() where order_id=p_order;
 return jsonb_build_object('stage',p_stage,'order_id',p_order);
end;$function$;

CREATE OR REPLACE FUNCTION public.ff49_cashier_invoice(p_order uuid, p_invoice_ref text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 DECLARE v_branch uuid;v_stage text;v_result jsonb;
 BEGIN
 
 PERFORM 1 FROM public.ff_orders WHERE id=p_order FOR UPDATE;
 SELECT o.branch_id,t.cashier_stage INTO v_branch,v_stage
 FROM public.ff_orders o JOIN public.ff38_delivery_tasks t ON t.order_id=o.id
 WHERE o.id=p_order FOR UPDATE OF t;
 IF NOT FOUND OR NOT public.ff49_can_work_branch(v_branch,ARRAY['manager','cashier']) THEN
 RAISE EXCEPTION 'غير مصرح' USING ERRCODE='42501'; END IF;
 
 IF EXISTS(SELECT 1 FROM public.ff_orders o JOIN public.ff38_delivery_tasks t ON t.order_id=o.id
 WHERE o.id=p_order AND (o.order_type<>'delivery' OR o.status IN ('cancelled','delivered','reservation_completed') OR t.delivered_at IS NOT NULL))
 THEN RAISE EXCEPTION 'الطلب ملغي أو منتهٍ؛ لا يمكن استلامه أو اعتماد فاتورته'; END IF;
 IF v_stage<>'waiting' OR length(btrim(coalesce(p_invoice_ref,''))) > 80 THEN
 RAISE EXCEPTION 'لا يمكن اعتماد القطع في هذه المرحلة أو أن رقم الفاتورة أطول من 80 حرفًا'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.ff49_cashier_receipts WHERE order_id=p_order) THEN
 RAISE EXCEPTION 'أكد استلام الطلب أولًا'; END IF;
 -- Validated prior to stage transition, then stored in same transaction.
 UPDATE public.ff49_cashier_receipts SET invoice_ref=nullif(btrim(p_invoice_ref),''),invoiced_by=auth.uid(),invoiced_at=now()
 WHERE order_id=p_order AND invoiced_at IS NULL;
 IF NOT FOUND THEN RAISE EXCEPTION 'سبق ربط الفاتورة بهذا الطلب'; END IF;
 v_result:=public.ff38_cashier_set_stage(p_order,'printed');
 RETURN v_result||jsonb_build_object('external_invoice_ref',nullif(btrim(p_invoice_ref),''));
 END; $function$;

CREATE OR REPLACE FUNCTION public.ff49_cashier_receive(p_order uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 DECLARE v_branch uuid; v_stage text;
 BEGIN
 
 PERFORM 1 FROM public.ff_orders WHERE id=p_order FOR UPDATE;
 SELECT o.branch_id,t.cashier_stage INTO v_branch,v_stage
 FROM public.ff_orders o JOIN public.ff38_delivery_tasks t ON t.order_id=o.id
 WHERE o.id=p_order FOR UPDATE OF t;
 IF NOT FOUND OR NOT public.ff49_can_work_branch(v_branch,ARRAY['manager','cashier']) THEN
 RAISE EXCEPTION 'للكاشير المصرح بهذا الفرع فقط' USING ERRCODE='42501'; END IF;
 
 IF EXISTS(SELECT 1 FROM public.ff_orders o JOIN public.ff38_delivery_tasks t ON t.order_id=o.id
 WHERE o.id=p_order AND (o.order_type<>'delivery' OR o.status IN ('cancelled','delivered','reservation_completed') OR t.delivered_at IS NOT NULL))
 THEN RAISE EXCEPTION 'الطلب ملغي أو منتهٍ؛ لا يمكن استلامه أو اعتماد فاتورته'; END IF;
 IF v_stage<>'waiting' THEN RAISE EXCEPTION 'لا يمكن استلام الطلب بهذه الحالة'; END IF;
 INSERT INTO public.ff49_cashier_receipts(order_id,received_by)
 VALUES(p_order,auth.uid()) ON CONFLICT(order_id) DO NOTHING;
 RETURN jsonb_build_object('received',true,'order_id',p_order);
 END $function$;

CREATE OR REPLACE FUNCTION public.ff38_driver_progress(p_order uuid, p_phase text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_driver uuid;v_task public.ff38_delivery_tasks%rowtype;v_rem int;v_order uuid;v_status text;
begin
 select l.driver_id into v_driver from public.ff38_driver_links l
 join public.ff_profiles p on p.user_id=l.user_id and p.role='driver' and p.active
 where l.user_id=auth.uid();
 if v_driver is null then raise exception 'غير مصرح' using errcode='42501';end if;
 -- Use the same lock order as cancellation: ff_orders before ff38_delivery_tasks.
 select status into v_status from public.ff_orders where id=p_order for update;
 if not found or v_status in ('cancelled','delivered') then
 raise exception 'الطلب ملغي أو منتهٍ، لا يمكن تحديثه';end if;
 select * into v_task from public.ff38_delivery_tasks where order_id=p_order for update;
 if v_task.order_id is null or v_task.driver_id<>v_driver or v_task.delivered_at is not null
 then raise exception 'الطلب ليس نشطاً أو ليس مسنداً لحسابك';end if;
 if p_phase='on_way' and v_task.phase='assigned' and v_task.cashier_stage='handed_over' then
 update public.ff38_delivery_tasks set phase='on_way',picked_up_at=now(),updated_at=now() where order_id=p_order;
 elsif p_phase='arrived' and v_task.phase='on_way' then
 update public.ff38_delivery_tasks set phase='arrived',arrived_at=now(),updated_at=now() where order_id=p_order;
 elsif p_phase='delivered' and v_task.phase in ('on_way','arrived') then
 update public.ff38_delivery_tasks set phase='delivered',delivered_at=now(),updated_at=now() where order_id=p_order;
 update public.ff_orders set status='delivered',delivered_at=now(),updated_at=now() where id=p_order;
 else raise exception 'خطوة غير متاحة. تحقق من حالة الكاشير والطلب';end if;
 select count(*) into v_rem from public.ff38_delivery_tasks where driver_id=v_driver and delivered_at is null;
 update public.ff38_driver_presence set
 state=case when v_rem=0 then 'ready' else 'busy' end,last_seen_at=now(),updated_at=now()
 where driver_id=v_driver and state<>'offline';
 if p_phase='delivered' then
 for v_order in select o.id from public.ff_orders o join public.ff_drivers d on d.branch_id=o.branch_id
 where d.id=v_driver and o.order_type='delivery' and o.status='new' and o.created_at>now()-interval '14 days'
 and not exists(select 1 from public.ff38_delivery_tasks t where t.order_id=o.id)
 and not exists(select 1 from public.ff38_dispatch_offers f where f.order_id=o.id and f.status='offered' and f.expires_at>now())
 order by o.created_at limit 5
 loop perform public.ff38__offer_next(v_order);end loop;
 end if;
 return jsonb_build_object('phase',p_phase,'remaining',v_rem);
end;$function$;
create trigger ff49_guard_cashier_invoice before update of cashier_stage on public.ff38_delivery_tasks for each row execute function public.ff49_guard_cashier_invoice();
create trigger ff38_guard_driver_departure before update of phase on public.ff38_delivery_tasks for each row execute function public.ff38_guard_driver_departure();
create trigger ff60_task_safety before update on public.ff38_delivery_tasks for each row execute function public.ff60_task_safety();
create trigger ff60_task_audit after insert or update on public.ff38_delivery_tasks for each row execute function public.ff60_task_audit();
