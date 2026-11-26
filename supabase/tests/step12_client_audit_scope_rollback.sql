BEGIN;
DO $qa$
DECLARE b1 uuid:=gen_random_uuid();b2 uuid:=gen_random_uuid();m uuid:=gen_random_uuid();cs uuid:=gen_random_uuid();c uuid:=gen_random_uuid();s uuid:=gen_random_uuid();d uuid:=gen_random_uuid();a uuid:=gen_random_uuid();k uuid:=gen_random_uuid();u uuid:=gen_random_uuid();x uuid:=gen_random_uuid();actor uuid;r jsonb;checks int:=0;i int;tag text:='qa_step12_'||replace(gen_random_uuid()::text,'-','');v_details jsonb;
BEGIN
 INSERT INTO auth.users(id) VALUES(m),(cs),(c),(s),(d),(a),(k),(u),(x);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 audit manager','manager',true),(cs,'QA STEP12 audit CS','customer_service',true),(c,'QA STEP12 audit cashier','cashier',true),(s,'QA STEP12 audit supervisor','supervisor',true),(d,'QA STEP12 audit driver','driver',true),(a,'QA STEP12 audit assembly','assembly',true),(k,'QA STEP12 audit kitchen','burger_kitchen',true),(x,'QA STEP12 audit disabled','manager',false);
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-step12-audit-'||b1,'QA STEP12 audit one'),(b2,'qa-step12-audit-'||b2,'QA STEP12 audit two');
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c,b1),(s,b1),(d,b1),(a,b1),(k,b1),(x,b1);
 v_details:=jsonb_build_object('qa',tag,'actor_id',m,'role','manager','source','forged client');
 SET LOCAL ROLE authenticated;
 FOREACH actor IN ARRAY ARRAY[u,x] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff_security_login_event('sign_out',v_details);RAISE EXCEPTION 'Inactive login-event write' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff_log_customer_view('archive_view','000000000',NULL,b1,v_details);RAISE EXCEPTION 'Inactive customer audit write' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff48_report_client_event('runtime_error',tag,'v1.0');RAISE EXCEPTION 'Inactive diagnostic accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY[c,s,d,a,k] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff_log_customer_view('directory_search','000000000',NULL,b1,v_details);RAISE EXCEPTION 'Non-CS private directory audit accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY[c,s,d,a] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff_log_customer_view('archive_view','000000000',NULL,b2,v_details);RAISE EXCEPTION 'Foreign branch audit accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  IF public.ff_log_customer_view('archive_view','000000000',NULL,b1,v_details) IS DISTINCT FROM true THEN RAISE EXCEPTION 'Own branch audit denied';END IF;checks:=checks+1;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY[m,cs] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  IF public.ff_log_customer_view('directory_search','000000000',NULL,b2,v_details) IS DISTINCT FROM true THEN RAISE EXCEPTION 'Central audit denied';END IF;checks:=checks+1;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY[m,cs,c,s,d,a,k] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  IF public.ff_security_login_event('sign_out',v_details) IS DISTINCT FROM true THEN RAISE EXCEPTION 'Active client event denied';END IF;checks:=checks+1;
  BEGIN PERFORM public.ff_security_login_event('not_an_event',v_details);RAISE EXCEPTION 'Invalid login event accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '22023' THEN NULL;END;checks:=checks+1;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY[a,k] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff48_report_client_event('runtime_error',tag,'v1.0');RAISE EXCEPTION 'Restricted diagnostic accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);
 FOR i IN 1..60 LOOP
  r:=public.ff48_report_client_event('runtime_error',tag,'v1.0');IF r->>'saved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Unexpected diagnostic cap before 60';END IF;checks:=checks+1;
 END LOOP;
 r:=public.ff48_report_client_event('runtime_error',tag,'v1.0');IF r->>'rate_limited' IS DISTINCT FROM 'true' OR r->>'saved' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Diagnostic rate cap failed';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',cs::text,true);
 r:=public.ff48_report_client_event('runtime_error',tag,'v1.0');IF r->>'saved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Separate account rate cap failed';END IF;checks:=checks+1;
 RESET ROLE;
 IF (SELECT count(*) FROM public.ff_customer_views v WHERE v.details#>>'{details,qa}'=tag)<>6 OR EXISTS(SELECT FROM public.ff_customer_views v JOIN public.ff_profiles p ON p.user_id=v.actor_id WHERE v.details#>>'{details,qa}'=tag AND (v.actor_role IS DISTINCT FROM p.role OR v.details->>'source'<>'web')) THEN RAISE EXCEPTION 'Audit identity columns inconsistent';END IF;checks:=checks+1;
 IF (SELECT count(*) FROM public.ff_login_events v WHERE v.details#>>'{details,qa}'=tag)<>7 OR EXISTS(SELECT FROM public.ff_login_events v JOIN public.ff_profiles p ON p.user_id=v.user_id WHERE v.details#>>'{details,qa}'=tag AND (v.role IS DISTINCT FROM p.role OR v.details->>'source'<>'web')) THEN RAISE EXCEPTION 'Client login event identity columns inconsistent';END IF;checks:=checks+1;
 IF (SELECT count(*) FROM public.ff48_client_diagnostics WHERE action_key=tag AND user_id=c AND role='cashier')<>60 OR (SELECT count(*) FROM public.ff48_client_diagnostics WHERE action_key=tag AND user_id=cs AND role='customer_service')<>1 THEN RAISE EXCEPTION 'Diagnostic count/actor mismatch';END IF;checks:=checks+1;
 IF checks<>102 THEN RAISE EXCEPTION 'Expected 102 assertions, got %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 audit client event scopes: 102 assertions including role identity, branch denial, 60-event rate cap and separate account isolation; rollback' result;
ROLLBACK;
