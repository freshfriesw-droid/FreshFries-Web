BEGIN;
DO $qa$
DECLARE b uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); actor uuid; role_name text; roles text[]:=ARRAY['cashier','driver','assembly','supervisor','customer_service','burger_kitchen','nonstaff','disabled_manager']; callers uuid[]:=ARRAY[]::uuid[]; call_sql text; checks int:=0; r jsonb; calls text[]; item uuid; offer uuid; v_run uuid; v_key text; target uuid:=gen_random_uuid(); email text:=target||'@example.invalid'; unknown_user uuid:=gen_random_uuid(); unknown_email text:=unknown_user||'@example.invalid'; label text:='QA STEP12 '||b; policy_before jsonb; policy_after jsonb;
BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-step12-admin-'||b,label);
 INSERT INTO auth.users(id,email) VALUES(m,m||'@example.invalid'),(target,email),(unknown_user,unknown_email);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,label,'manager',true),(target,label,'cashier',true);
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(target,b);
 SELECT to_jsonb(p) INTO policy_before FROM public.ff60_offer_policy p WHERE singleton=1;
 FOREACH role_name IN ARRAY roles LOOP
  actor:=gen_random_uuid(); callers:=array_append(callers,actor); INSERT INTO auth.users(id) VALUES(actor);
  IF role_name<>'nonstaff' THEN INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(actor,label,CASE WHEN role_name='disabled_manager' THEN 'manager' ELSE role_name END,role_name<>'disabled_manager'); END IF;
  IF role_name IN ('cashier','driver','assembly','supervisor','burger_kitchen') THEN INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(actor,b); END IF;
 END LOOP;
 SET LOCAL ROLE authenticated;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 r:=public.ff51_catalog_save_item(NULL,label,label,100);
 item:=(r->>'id')::uuid;
 r:=public.ff51_offer_save(NULL,label,100,true);
 offer:=(r->>'id')::uuid;
 r:=public.ff47_test_run_create('qa-step12','QA STEP12 synthetic');
 v_run:=coalesce(r->>'id',r->>'run_id')::uuid;
 RESET ROLE;
 SELECT c.test_key INTO v_key FROM public.ff47_test_run_cases c WHERE c.run_id=v_run LIMIT 1;
 IF item IS NULL OR offer IS NULL OR v_run IS NULL OR v_key IS NULL THEN RAISE EXCEPTION 'Missing test fixture identifiers'; END IF;
 calls:=ARRAY[
 format('SELECT public.ff38_admin_link_user(%L,%L,%L,%L::uuid)',email,label,'cashier',b),
 'SELECT public.ff38_admin_staff_audit()',
 'SELECT public.ff38_admin_staff_list()',
 format('SELECT public.ff47_test_case_save(%L::uuid,%L,%L,%L)',v_run,v_key,'passed','QA'),
 'SELECT public.ff47_test_run_create(''qa-step12'',''QA denied'')',
 format('SELECT public.ff47_test_run_detail(%L::uuid)',v_run),
 format('SELECT public.ff47_test_run_set_state(%L::uuid,%L)',v_run,'in_progress'),
 format('SELECT public.ff51_catalog_save_item(%L::uuid,%L,%L,200)',item,label,label),
 format('SELECT public.ff51_catalog_toggle(%L::uuid,false)',item),
 format('SELECT public.ff51_offer_save(%L::uuid,%L,200,false)',offer,label),
 'SELECT public.ff60_set_policy(180,600)',
 format('SELECT public.ff71_admin_link_assembly(%L,%L,%L::uuid)',email,label,b),
 format('SELECT public.ff_v12_assembly_account_update(%L,%L::uuid,true)',email,b),
 'SELECT public.ff_v12_assembly_accounts()'];
 SET LOCAL ROLE authenticated;
 FOREACH actor IN ARRAY callers LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  FOREACH call_sql IN ARRAY calls LOOP
   BEGIN EXECUTE call_sql; RAISE EXCEPTION 'Unauthorized administrative call returned: %',call_sql USING ERRCODE='ZQA12';
   EXCEPTION WHEN SQLSTATE '42501' THEN checks:=checks+1; END;
  END LOOP;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 BEGIN PERFORM public.ff71_admin_link_assembly(unknown_email,label,b); RAISE EXCEPTION 'Unapproved user linked' USING ERRCODE='ZQA12'; EXCEPTION WHEN SQLSTATE '42501' THEN checks:=checks+1; END;
 r:=public.ff47_test_case_save(v_run,v_key,'passed','QA');
 IF r->>'saved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Manager test-case save failed'; END IF; checks:=checks+1;
 r:=public.ff47_test_run_detail(v_run); IF jsonb_typeof(r)<>'object' THEN RAISE EXCEPTION 'Manager test detail failed'; END IF; checks:=checks+1;
 r:=public.ff51_catalog_toggle(item,false); IF r->>'saved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Manager toggle failed'; END IF; checks:=checks+1;
 r:=public.ff51_offer_save(offer,label,200,false); IF r->>'saved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Manager offer save failed'; END IF; checks:=checks+1;
 r:=public.ff71_admin_link_assembly(email,label,b); IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Manager existing-staff linking failed'; END IF; checks:=checks+1;
 RESET ROLE;
 IF NOT EXISTS(SELECT FROM public.ff_profiles WHERE user_id=target AND role='assembly' AND active) OR EXISTS(SELECT FROM public.ff_profiles WHERE user_id=unknown_user) THEN RAISE EXCEPTION 'Unexpected staff profile state'; END IF; checks:=checks+1;
 SELECT to_jsonb(p) INTO policy_after FROM public.ff60_offer_policy p WHERE singleton=1;
 IF policy_after IS DISTINCT FROM policy_before THEN RAISE EXCEPTION 'Offer policy changed'; END IF; checks:=checks+1;
 IF checks<>120 THEN RAISE EXCEPTION 'Expected 120 assertions, got %',checks; END IF;
END $qa$;
SELECT 'PASS STEP12 112 denial assertions across eight contexts; 8 additional authorized/fixture safety assertions; rollback' result;
ROLLBACK;
