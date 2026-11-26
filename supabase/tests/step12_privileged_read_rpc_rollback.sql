BEGIN;
DO $qa$
DECLARE b uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); actor uuid; role_name text; roles text[]:=ARRAY['cashier','driver','assembly','supervisor','customer_service','burger_kitchen','nonstaff','disabled_manager']; callers uuid[]:=ARRAY[]::uuid[]; q text; checks int:=0; r jsonb; calls text[];
BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-step12-read-'||b,'QA STEP12 read');
 INSERT INTO auth.users(id) VALUES(m);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 manager','manager',true);
 FOREACH role_name IN ARRAY roles LOOP
  actor:=gen_random_uuid(); callers:=array_append(callers,actor); INSERT INTO auth.users(id) VALUES(actor);
  IF role_name<>'nonstaff' THEN INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(actor,'QA STEP12 '||role_name,CASE WHEN role_name='disabled_manager' THEN 'manager' ELSE role_name END,role_name<>'disabled_manager'); END IF;
  IF role_name IN ('cashier','driver','assembly','supervisor','burger_kitchen') THEN INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(actor,b); END IF;
 END LOOP;
 calls:=ARRAY[
 format('SELECT public.ff42_settlement_overview((now() AT TIME ZONE ''Asia/Aden'')::date,%L::uuid)',b),
 'SELECT public.ff43_security_report()',
 'SELECT public.ff44_integrity_review((now() AT TIME ZONE ''Asia/Aden'')::date-1,(now() AT TIME ZONE ''Asia/Aden'')::date)',
 'SELECT public.ff45_branch_access_review()',
 'SELECT public.ff46_release_readiness()',
 'SELECT public.ff47_test_runs_list()',
 'SELECT public.ff48_diagnostics_summary()',
 'SELECT public.ff51_manager_catalog()',
 'SELECT public.ff52_admin_route_list()',
 'SELECT public.ff_a10_report_grants()'];
 SET LOCAL ROLE authenticated;
 FOREACH actor IN ARRAY callers LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  FOREACH q IN ARRAY calls LOOP
   BEGIN EXECUTE q INTO r; RAISE EXCEPTION 'Unauthorized read returned: %',q USING ERRCODE='ZQA12';
   EXCEPTION WHEN SQLSTATE '42501' THEN checks:=checks+1; END;
  END LOOP;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 FOREACH q IN ARRAY calls LOOP
  EXECUTE q INTO r;
  IF r IS NULL OR jsonb_typeof(r) NOT IN ('object','array') THEN RAISE EXCEPTION 'Manager valid read failed: %',q; END IF;
  checks:=checks+1;
 END LOOP;
 RESET ROLE;
 IF checks<>90 THEN RAISE EXCEPTION 'Expected 90 assertions, got %',checks; END IF;
END $qa$;
SELECT 'PASS STEP12 privileged read RPC: 80 denials across 8 contexts; 10 manager valid-read assertions; no payload returned; rollback' result;
ROLLBACK;
