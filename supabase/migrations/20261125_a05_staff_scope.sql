-- FIX-14/15, QA-25/43: require controlled staff administration and onboarding.
-- Keep existing accounts and service-role writes; all browser mutations use audited RPCs.
REVOKE INSERT,UPDATE,DELETE,TRUNCATE ON public.ff_profiles,public.ff_user_branches,public.ff_v9_assembly_access FROM PUBLIC,anon,authenticated;
-- Existing-account relinking remains available, but never creates or activates a new profile.
CREATE OR REPLACE FUNCTION public.ff38_admin_link_user(p_email text,p_name text,p_role text,p_branch uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $body$
DECLARE v_user uuid;v_role text;v_result jsonb;v_branches uuid[];
BEGIN
 IF NOT public.ff_is_manager() THEN RAISE EXCEPTION 'صلاحية المدير العام مطلوبة' USING ERRCODE='42501';END IF;
 SELECT u.id INTO v_user FROM auth.users u WHERE lower(u.email)=lower(btrim(coalesce(p_email,'')));
 IF v_user IS NULL OR v_user=auth.uid() THEN RAISE EXCEPTION 'استخدم تقديم طلب انضمام لاعتماد الموظف الجديد' USING ERRCODE='42501';END IF;
 PERFORM pg_advisory_xact_lock(hashtext('ff38-user-'||v_user::text));
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=v_user AND active FOR UPDATE;
 IF v_role IS NULL OR v_role='manager' THEN RAISE EXCEPTION 'يجب اعتماد الموظف أولًا عبر طلب الانضمام أو إدارة الحسابات القائمة' USING ERRCODE='42501';END IF;
 IF p_role IS NULL OR p_role NOT IN ('driver','customer_service','cashier','supervisor','burger_kitchen') OR length(btrim(coalesce(p_name,''))) NOT BETWEEN 2 AND 150 THEN
 RAISE EXCEPTION 'الاسم أو الدور غير صالح' USING ERRCODE='22023';END IF;
 v_branches:=CASE WHEN p_role IN ('driver','cashier','burger_kitchen') THEN ARRAY[p_branch] ELSE ARRAY[]::uuid[] END;
 IF p_role IN ('customer_service','supervisor') AND p_branch IS NOT NULL THEN RAISE EXCEPTION 'الدور مركزي' USING ERRCODE='22023';END IF;
 v_result:=public.ff68_admin_staff_set_role(v_user,p_role,v_branches);
 UPDATE public.ff_profiles SET display_name=btrim(p_name) WHERE user_id=v_user;
 UPDATE public.ff_drivers SET name=btrim(p_name) WHERE id=(SELECT driver_id FROM public.ff38_driver_links WHERE user_id=v_user);
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 VALUES(auth.uid(),'a05_existing_staff_relinked','employee',v_user::text,p_branch,jsonb_build_object('old_role',v_role,'role',p_role));
 RETURN v_result||jsonb_build_object('linked',true,'user_id',v_user);
END $body$;
REVOKE EXECUTE ON FUNCTION public.ff38_admin_link_user(text,text,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff38_admin_link_user(text,text,text,uuid) TO authenticated;
-- Remove stale application delegation when the employee changes duty; manager may explicitly regrant.
CREATE OR REPLACE FUNCTION ff_private.a05_clear_role_delegation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $body$
DECLARE n int;
BEGIN
 DELETE FROM public.ff61_application_delegations WHERE user_id=NEW.user_id;
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n>0 THEN
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,details)
 VALUES(auth.uid(),'a05_delegation_reset_on_role_change','employee',NEW.user_id::text,jsonb_build_object('old_role',OLD.role,'new_role',NEW.role));
 END IF;
 RETURN NEW;
END $body$;
REVOKE EXECUTE ON FUNCTION ff_private.a05_clear_role_delegation() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER a05_clear_role_delegation AFTER UPDATE OF role ON public.ff_profiles
 FOR EACH ROW WHEN (OLD.role IS DISTINCT FROM NEW.role) EXECUTE FUNCTION ff_private.a05_clear_role_delegation();
-- Role/branch changes use one lock order in both wrapper and underlying manager RPC.
DO $migration$
DECLARE src text:=pg_get_functiondef('public.ff68_admin_staff_set_role(uuid,text,uuid[])'::regprocedure);
 marker text:='SELECT role INTO v_old_role';
BEGIN
 IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected role wrapper';END IF;
 EXECUTE replace(src,marker,$body$PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-user-'||p_user::text));
 $body$||marker);
END $migration$;
-- Restrict direct raw rows to the same operational scope as the staff workspace.
CREATE OR REPLACE FUNCTION ff_private.a05_can_read_order(p_order uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $body$
 SELECT EXISTS(SELECT 1 FROM public.ff_profiles p JOIN public.ff_orders o ON o.id=p_order
 WHERE p.user_id=auth.uid() AND p.active AND (
 p.role IN ('manager','customer_service')
 OR (p.role='cashier' AND EXISTS(SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=p.user_id AND ub.branch_id=o.branch_id)
 AND EXISTS(SELECT 1 FROM public.ff38_delivery_tasks t WHERE t.order_id=o.id)
 AND (NOT EXISTS(SELECT 1 FROM public.ff_luxe_cashier_staff_desks sd WHERE sd.user_id=p.user_id)
 OR NOT EXISTS(SELECT 1 FROM public.ff_luxe_cashier_order_desks od WHERE od.order_id=o.id)
 OR EXISTS(SELECT 1 FROM public.ff_luxe_cashier_staff_desks sd JOIN public.ff_luxe_cashier_order_desks od ON od.desk_code=sd.desk_code WHERE sd.user_id=p.user_id AND od.order_id=o.id)))
 OR (p.role='driver' AND EXISTS(SELECT 1 FROM public.ff38_driver_links l JOIN public.ff38_delivery_tasks t ON t.driver_id=l.driver_id JOIN public.ff_drivers d ON d.id=l.driver_id AND d.active WHERE l.user_id=p.user_id AND t.order_id=o.id AND d.branch_id=o.branch_id))
 ));
$body$;
REVOKE EXECUTE ON FUNCTION ff_private.a05_can_read_order(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION ff_private.a05_can_read_order(uuid) TO authenticated;
-- No new raw PII route for assembly, kitchen, supervisor or applicant; use existing scoped RPCs.
DROP POLICY ff_orders_branch_access ON public.ff_orders;
CREATE POLICY ff_orders_scoped_read ON public.ff_orders FOR SELECT TO authenticated USING (ff_private.a05_can_read_order(id));
DROP POLICY ff_items_branch_access ON public.ff_order_items;
CREATE POLICY ff_items_scoped_read ON public.ff_order_items FOR SELECT TO authenticated USING (ff_private.a05_can_read_order(order_id));
DROP POLICY ff_events_branch_access ON public.ff_order_events;
CREATE POLICY ff_events_scoped_read ON public.ff_order_events FOR SELECT TO authenticated USING (ff_private.a05_can_read_order(order_id));
ALTER POLICY ff_customers_branch_read ON public.ff_customers TO authenticated USING (
 EXISTS(SELECT 1 FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active AND p.role IN ('manager','customer_service'))
);
ALTER POLICY ff_customer_notes_read ON public.ff_customer_notes TO authenticated USING (
 EXISTS(SELECT 1 FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active AND p.role IN ('manager','customer_service'))
);
-- The client-driven sweep is a privileged assignment action, not a bypass for a revoked assign_driver.
DO $migration$
DECLARE src text:=pg_get_functiondef('public.ff38_sweep_offers()'::regprocedure);
 marker text:='FOR v_order IN SELECT DISTINCT';
BEGIN
 IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected sweep';END IF;
 EXECUTE replace(src,marker,$body$IF NOT public.ff38_permission_allowed(auth.uid(),'assign_driver') THEN RAISE EXCEPTION 'صلاحية الإسناد مسحوبة' USING ERRCODE='42501';END IF;
 $body$||marker);
END $migration$;
