DO $qa$
DECLARE b1 uuid:=gen_random_uuid();b2 uuid:=gen_random_uuid();m uuid:=gen_random_uuid();d uuid:=gen_random_uuid();old uuid:=gen_random_uuid();u uuid:=gen_random_uuid();app uuid:=gen_random_uuid();desk1 text:='qa-'||gen_random_uuid();desk2 text:='qa-'||gen_random_uuid();ph text:='+999'||lpad(floor(random()*1e9)::bigint::text,9,'0');r jsonb;blocked boolean;passes int:=0;
BEGIN
 BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-'||b1,'QA one'),(b2,'qa-'||b2,'QA two');
 INSERT INTO auth.users(id) VALUES(m),(d),(old);
 INSERT INTO auth.users(id,phone) VALUES(u,ph);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA manager','manager',true),(d,'QA delegate','customer_service',true),(old,'QA existing cashier','cashier',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(old,b1);
 INSERT INTO public.ff_luxe_cashier_desks(code,label,branch_id,sort_order) VALUES(desk1,'QA first desk',b1,1),(desk2,'QA foreign desk',b2,1);
 INSERT INTO public.ff61_employee_applications(id,full_name,phone,qualification,address,age_years,marital_status,requested_role,privacy_accepted_at) VALUES(app,'QA Applicant',ph,'QA','QA address',25,'single','cashier',now());
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 PERFORM public.ff61_set_delegation(d,true,true,false,false);RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub',d::text,true);SET LOCAL ROLE authenticated;
 blocked:=false;BEGIN PERFORM public.ff_luxe_set_cashier_desk(old,desk1);EXCEPTION WHEN SQLSTATE '42501' THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Delegate altered unrelated cashier';END IF;passes:=passes+1;
 blocked:=false;BEGIN PERFORM public.ff_a05_approve_application(app,d,u,'cashier',b1,desk1,'QA valid reason');EXCEPTION WHEN SQLSTATE '42501' THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Browser called service-only approval';END IF;passes:=passes+1;
 RESET ROLE;
 blocked:=false;BEGIN PERFORM public.ff_a05_approve_application(app,d,u,'cashier',b1,desk2,'QA valid reason');EXCEPTION WHEN SQLSTATE '42501' THEN blocked:=true;END;
 IF NOT blocked OR EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=u) THEN RAISE EXCEPTION 'Foreign desk approval not atomic';END IF;passes:=passes+1;
 r:=public.ff_a05_approve_application(app,d,u,'cashier',b1,desk1,'QA valid reason');
 IF r->>'desk' IS DISTINCT FROM desk1 OR NOT EXISTS(SELECT 1 FROM public.ff_luxe_cashier_staff_desks WHERE user_id=u AND desk_code=desk1 AND assigned_by=d) OR NOT EXISTS(SELECT 1 FROM public.ff61_employee_applications WHERE id=app AND status='approved' AND decision_reason='QA valid reason') THEN RAISE EXCEPTION 'Atomic approval failed';END IF;passes:=passes+1;
 IF NOT EXISTS(SELECT 1 FROM public.ff_audit_log WHERE action='a05_application_decision' AND entity_id=app::text AND actor_id=d AND details->>'desk'=desk1) THEN RAISE EXCEPTION 'Decision audit missing';END IF;passes:=passes+1;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 PERFORM public.ff61_set_delegation(d,false,false,false,false);PERFORM public.ff_luxe_set_cashier_desk(old,desk1);RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub',d::text,true);SET LOCAL ROLE authenticated;
 blocked:=false;BEGIN PERFORM public.ff_luxe_set_cashier_desk(u,desk1);EXCEPTION WHEN SQLSTATE '42501' THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Revoked delegate still modified own approval';END IF;passes:=passes+1;
 RESET ROLE;
 IF NOT EXISTS(SELECT 1 FROM public.ff_luxe_cashier_staff_desks WHERE user_id=old AND assigned_by=m) THEN RAISE EXCEPTION 'Manager desk assignment failed';END IF;passes:=passes+1;
 RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF passes<>7 OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id IN(b1,b2)) OR EXISTS(SELECT 1 FROM auth.users WHERE id IN(m,d,old,u)) THEN RAISE EXCEPTION 'Incomplete QA/rollback';END IF;
END $qa$;
SELECT 'PASS A05: seven approval/desk atomicity and delegation assertions, rollback' AS result;