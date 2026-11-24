-- A05: approval, cashier desk and decision reason committed atomically.
-- The Edge Function verifies the caller and phone ownership before service-role invocation.
CREATE OR REPLACE FUNCTION public.ff_a05_approve_application(p_application uuid,p_actor uuid,p_auth_user uuid,p_role text,p_branch uuid,p_desk text DEFAULT NULL,p_reason text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $body$
DECLARE result jsonb; desk_name text; reason text:=coalesce(nullif(btrim(p_reason),''),'تم قبول الطلب، تُستلم بيانات الدخول من الإدارة.');
BEGIN
 IF NOT public.ff61_can_act(p_actor,'approve') THEN RAISE EXCEPTION 'لا تملك صلاحية القبول' USING ERRCODE='42501';END IF;
 IF p_role IS NULL OR length(reason) NOT BETWEEN 5 AND 1200 THEN RAISE EXCEPTION 'سبب القرار أو الدور غير صالح' USING ERRCODE='22023';END IF;
 IF p_desk IS NOT NULL THEN
  IF p_role<>'cashier' THEN RAISE EXCEPTION 'وجهة الكاشير لا تخص هذا الدور' USING ERRCODE='22023';END IF;
  SELECT label INTO desk_name FROM public.ff_luxe_cashier_desks WHERE code=p_desk AND branch_id=p_branch AND active;
  IF NOT FOUND THEN RAISE EXCEPTION 'الوجهة لا تخص الفرع المختار' USING ERRCODE='42501';END IF;
 END IF;
 result:=public.ff61_approve_application(p_application,p_actor,p_auth_user,p_role,p_branch);
 UPDATE public.ff61_employee_applications SET decision_reason=reason WHERE id=p_application;
 IF p_desk IS NOT NULL THEN
  INSERT INTO public.ff_luxe_cashier_staff_desks(user_id,desk_code,assigned_by) VALUES(p_auth_user,p_desk,p_actor)
  ON CONFLICT(user_id) DO UPDATE SET desk_code=EXCLUDED.desk_code,assigned_by=EXCLUDED.assigned_by,assigned_at=now();
 END IF;
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 VALUES(p_actor,'a05_application_decision','employee_application',p_application::text,p_branch,jsonb_build_object('role',p_role,'desk',p_desk,'reason',reason));
 RETURN result||jsonb_build_object('desk',p_desk,'desk_name',desk_name);
END $body$;
REVOKE EXECUTE ON FUNCTION public.ff_a05_approve_application(uuid,uuid,uuid,text,uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ff_a05_approve_application(uuid,uuid,uuid,text,uuid,text,text) TO service_role;
-- Retain the previous browser's immediate post-approval desk linking only for its own
-- recently approved cashier, not arbitrary accounts. New clients use the atomic RPC.
DO $migration$
DECLARE src text:=pg_get_functiondef('public.ff_luxe_set_cashier_desk(uuid,text)'::regprocedure);
 marker text:='select 1 from public.ff61_application_delegations d';
BEGIN
 IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected desk grant source';END IF;
 src:=replace(src,'where d.user_id=auth.uid() and d.may_approve',
 $body$where d.user_id=auth.uid() and d.may_approve AND EXISTS(
 SELECT 1 FROM public.ff61_employee_applications a WHERE a.approved_user_id=p_user AND a.status='approved' AND a.approved_role='cashier' AND a.decided_by=auth.uid() AND a.decided_at>now()-interval '10 minutes'
 )$body$);
 EXECUTE src;
END $migration$;
-- Only the approved employee's verified phone is copied into a new courier contact record.
DO $migration$
DECLARE src text:=pg_get_functiondef('public.ff61_approve_application(uuid,uuid,uuid,text,uuid)'::regprocedure);
BEGIN
 IF strpos(src,'INSERT INTO public.ff_drivers(name,branch_id,status,active,sort_order)')=0 THEN RAISE EXCEPTION 'Unexpected approval driver insert';END IF;
 src:=replace(src,'INSERT INTO public.ff_drivers(name,branch_id,status,active,sort_order)','INSERT INTO public.ff_drivers(name,branch_id,status,active,sort_order,phone)');
 src:=replace(src,$body$VALUES(a.full_name,p_branch,'ready',true,100)$body$,$body$VALUES(a.full_name,p_branch,'ready',true,100,a.phone)$body$);
 EXECUTE src;
END $migration$;
