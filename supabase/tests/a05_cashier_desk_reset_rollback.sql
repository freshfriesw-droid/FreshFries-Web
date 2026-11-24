DO $qa$
DECLARE b1 uuid:=gen_random_uuid();b2 uuid:=gen_random_uuid();m uuid:=gen_random_uuid();u uuid:=gen_random_uuid();desk text:='qa-'||gen_random_uuid();passes int:=0;
BEGIN
 BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-'||b1,'QA one'),(b2,'qa-'||b2,'QA two');
 INSERT INTO auth.users(id) VALUES(m),(u);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA manager','manager',true),(u,'QA cashier','cashier',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(u,b1);
 INSERT INTO public.ff_luxe_cashier_desks(code,label,branch_id,sort_order) VALUES(desk,'QA desk',b1,1);
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 PERFORM public.ff_luxe_set_cashier_desk(u,desk);PERFORM public.ff38_admin_staff_set_access(u,'cashier',ARRAY[b1]);RESET ROLE;
 IF NOT EXISTS(SELECT 1 FROM public.ff_luxe_cashier_staff_desks WHERE user_id=u AND desk_code=desk) THEN RAISE EXCEPTION 'Valid desk was removed';END IF;passes:=passes+1;
 SET LOCAL ROLE authenticated;PERFORM public.ff38_admin_staff_set_access(u,'cashier',ARRAY[b2]);RESET ROLE;
 IF EXISTS(SELECT 1 FROM public.ff_luxe_cashier_staff_desks WHERE user_id=u) THEN RAISE EXCEPTION 'Foreign desk remains';END IF;passes:=passes+1;
 SET LOCAL ROLE authenticated;PERFORM public.ff38_admin_staff_set_access(u,'cashier',ARRAY[b1]);PERFORM public.ff_luxe_set_cashier_desk(u,desk);PERFORM public.ff68_admin_staff_set_role(u,'assembly',ARRAY[b1]);RESET ROLE;
 IF EXISTS(SELECT 1 FROM public.ff_luxe_cashier_staff_desks WHERE user_id=u) OR NOT EXISTS(SELECT 1 FROM public.ff_audit_log WHERE actor_id=m AND entity_id=u::text AND action='a05_cashier_desk_reset') THEN RAISE EXCEPTION 'Role desk reset missing';END IF;passes:=passes+1;
 RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF passes<>3 OR EXISTS(SELECT 1 FROM auth.users WHERE id IN(m,u)) THEN RAISE EXCEPTION 'Incomplete QA rollback';END IF;
END $qa$;
SELECT 'PASS 3 cashier desk preservation and reset assertions' AS result;