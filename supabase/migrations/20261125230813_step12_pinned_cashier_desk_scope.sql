-- STEP12: preserve Cairo pinned courier rules while enforcing cashier desk scope.
CREATE OR REPLACE FUNCTION public.ff62_assign_pinned(p_order uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE o public.ff_orders%ROWTYPE; d uuid; role_name text;
BEGIN
 SELECT role INTO role_name FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-o-'||p_order::text));
 SELECT * INTO o FROM public.ff_orders WHERE id=p_order FOR UPDATE;
 IF o.id IS NULL OR o.order_type<>'delivery' OR o.status IN ('cancelled','delivered','reservation_completed') THEN RAISE EXCEPTION 'الطلب غير قابل للإسناد'; END IF;
 IF role_name IS NULL OR NOT public.ff49_can_work_branch(o.branch_id,ARRAY[role_name]) OR NOT public.ff38_permission_allowed(auth.uid(),'assign_driver') THEN RAISE EXCEPTION 'ليس لديك صلاحية الإسناد' USING ERRCODE='42501'; END IF;
 IF role_name='cashier' AND NOT ff_private.a10_cashier_order_visible(p_order) THEN RAISE EXCEPTION 'الطلب غير متاح لهذه الوجهة' USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ff_branches WHERE id=o.branch_id AND code='cairo') THEN RAISE EXCEPTION 'خاص بفرع القاهرة فقط'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-branch-rr-'||o.branch_id::text));
 SELECT driver_id INTO d FROM public.ff62_pinned_drivers WHERE branch_id=o.branch_id;
 IF d IS NULL THEN RAISE EXCEPTION 'يجب تثبيت موصل أولًا'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ff_drivers WHERE id=d AND branch_id=o.branch_id AND active) THEN RAISE EXCEPTION 'الموصل المثبت غير نشط'; END IF;
 PERFORM 1 FROM public.ff38_driver_presence p WHERE p.driver_id=d AND p.state IN ('ready','busy') AND p.checked_in_at IS NOT NULL AND p.checked_out_at IS NULL AND p.last_seen_at>clock_timestamp()-interval '90 seconds' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'الموصل المثبت غير حاضر أو غير متصل';END IF;
 IF o.driver_id IS NOT NULL OR EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE order_id=p_order) THEN RAISE EXCEPTION 'الطلب مسند بالفعل'; END IF;
 UPDATE public.ff38_dispatch_offers SET status='cancelled',responded_at=now() WHERE order_id=p_order AND status='offered';
 INSERT INTO public.ff38_delivery_tasks(order_id,driver_id,phase,cashier_stage,assigned_at,updated_at) VALUES(p_order,d,'assigned','waiting',now(),now());
 UPDATE public.ff_orders SET driver_id=d,delivery_fee=0,total=items_total,status='sent',sent_at=coalesce(sent_at,now()),updated_at=now() WHERE id=p_order;
 UPDATE public.ff38_driver_presence SET state='busy',updated_at=clock_timestamp() WHERE driver_id=d;
 RETURN jsonb_build_object('state','assigned_pinned','driver_id',d,'order_id',p_order,'delivery_fee',0);
END $function$;
