BEGIN;
DO $qa$
DECLARE b uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); actor uuid; kind text; kinds text[]:=ARRAY['manager','cashier','driver','assembly','supervisor','customer_service','burger_kitchen','nonstaff','disabled']; expected text; r jsonb; checks int:=0; enabled boolean;
BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-step12-role-'||b,'QA STEP12 role');
 FOREACH kind IN ARRAY kinds LOOP
  actor:=gen_random_uuid(); INSERT INTO auth.users(id) VALUES(actor);
  IF kind<>'nonstaff' THEN INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(actor,'QA STEP12 role '||kind,CASE WHEN kind='disabled' THEN 'cashier' ELSE kind END,kind<>'disabled');END IF;
  IF kind='manager' THEN m:=actor;END IF;
  IF kind='cashier' THEN u:=actor;END IF;
  IF kind='disabled' THEN d:=actor;END IF;
  IF kind IN ('cashier','driver','assembly','supervisor','burger_kitchen','disabled') THEN INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(actor,b);END IF;
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  expected:=CASE WHEN kind IN ('nonstaff','disabled') THEN NULL ELSE kind END;
  IF public.ff_security_my_role() IS DISTINCT FROM expected THEN RAISE EXCEPTION 'Role mismatch %',kind;END IF;checks:=checks+1;
  IF expected IS NULL THEN
   BEGIN PERFORM public.ff28_my_role();RAISE EXCEPTION 'Role lookup authorized' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
   BEGIN PERFORM public.ff38_my_permissions();RAISE EXCEPTION 'Permission matrix authorized' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
   BEGIN PERFORM public.ff48_release_info();RAISE EXCEPTION 'Release info authorized' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
   IF public.ff49_can_work_branch(b,ARRAY['cashier','manager','customer_service']) IS DISTINCT FROM false THEN RAISE EXCEPTION 'Inactive/nonstaff branch access';END IF;checks:=checks+1;
  ELSE
   IF public.ff28_my_role() IS DISTINCT FROM expected THEN RAISE EXCEPTION 'Active role mismatch';END IF;checks:=checks+1;
   r:=public.ff38_my_permissions();IF jsonb_typeof(r) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Missing permission object';END IF;checks:=checks+1;
   r:=public.ff48_release_info();IF r->>'production_certified' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Production readiness misrepresented';END IF;checks:=checks+1;
   enabled:=public.ff49_can_work_branch(b,ARRAY[expected]);IF enabled IS DISTINCT FROM true THEN RAISE EXCEPTION 'Own branch unexpectedly denied for %',kind;END IF;checks:=checks+1;
  END IF;
  RESET ROLE;
 END LOOP;
 SET LOCAL ROLE authenticated;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 IF public.ff38_permission_allowed(d,'view_reports') IS DISTINCT FROM false THEN RAISE EXCEPTION 'Disabled permission retained';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',u::text,true);
 BEGIN PERFORM public.ff38_permission_allowed(m,'view_reports');RAISE EXCEPTION 'Cross-account permission inquiry' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 IF public.ff49_can_work_branch(gen_random_uuid(),ARRAY['cashier']) IS DISTINCT FROM false THEN RAISE EXCEPTION 'Other branch accessible';END IF;checks:=checks+1;
 RESET ROLE;
 IF checks<>48 THEN RAISE EXCEPTION 'Expected 48 checks, got %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 role and permission discovery: 48 checks; active, inactive, nonstaff, cross-account and branch' result;
ROLLBACK;
