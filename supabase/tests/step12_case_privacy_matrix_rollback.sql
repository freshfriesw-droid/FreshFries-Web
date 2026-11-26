BEGIN;
DO $qa$
DECLARE b1 uuid:=gen_random_uuid();b2 uuid:=gen_random_uuid();m uuid:=gen_random_uuid();cs uuid:=gen_random_uuid();c uuid:=gen_random_uuid();s uuid:=gen_random_uuid();d uuid:=gen_random_uuid();a uuid:=gen_random_uuid();k uuid:=gen_random_uuid();u uuid:=gen_random_uuid();x uuid:=gen_random_uuid();o1 uuid:=gen_random_uuid();o2 uuid:=gen_random_uuid();o3 uuid:=gen_random_uuid();v1 uuid;v2 uuid;v3 uuid;g uuid;actor uuid;desk1 text:='qa-'||gen_random_uuid();desk2 text:='qa-'||gen_random_uuid();n bigint:=-1000000000000-floor(random()*1e12)::bigint;checks int:=0;r jsonb;phone_value text:='000000000';target uuid;
BEGIN
 INSERT INTO auth.users(id) VALUES(m),(cs),(c),(s),(d),(a),(k),(u),(x);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 case manager','manager',true),(cs,'QA STEP12 case CS','customer_service',true),(c,'QA STEP12 case cashier','cashier',true),(s,'QA STEP12 case supervisor','supervisor',true),(d,'QA STEP12 case driver','driver',true),(a,'QA STEP12 case assembly','assembly',true),(k,'QA STEP12 case kitchen','burger_kitchen',true),(x,'QA STEP12 case disabled','manager',false);
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-step12-case-'||b1,'QA STEP12 case branch 1'),(b2,'qa-step12-case-'||b2,'QA STEP12 case branch 2');
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c,b1),(s,b1),(d,b1),(a,b1),(k,b1);
 INSERT INTO public.ff_luxe_cashier_desks(code,label,branch_id,sort_order) VALUES(desk1,'QA desk 1',b1,9997),(desk2,'QA desk 2',b1,9998);
 INSERT INTO public.ff_luxe_cashier_staff_desks(user_id,desk_code,assigned_by) VALUES(c,desk1,m);
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,area_snapshot,status,created_by,items_total,delivery_fee,total) VALUES(o1,n,b1,phone_value,'QA area','new',cs,100,0,100),(o2,n-1,b1,phone_value,'QA area','new',cs,100,0,100),(o3,n-2,b2,phone_value,'QA area','new',cs,100,0,100);
 INSERT INTO public.ff_luxe_cashier_order_desks(order_id,desk_code) VALUES(o1,desk1),(o2,desk2);
 SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',cs::text,true);
 r:=public.ff41_case_create('customer_complaint','QA complaint one','QA synthetic description',b1,o1,'normal','QA synthetic',phone_value,'phone');v1:=(r->>'case_id')::uuid;
 r:=public.ff41_case_create('customer_complaint','QA complaint two','QA synthetic description',b1,o2,'normal','QA synthetic',phone_value,'phone');v2:=(r->>'case_id')::uuid;
 r:=public.ff41_case_create('customer_complaint','QA complaint three','QA synthetic description',b2,o3,'normal','QA synthetic',phone_value,'phone');v3:=(r->>'case_id')::uuid;
 IF v1 IS NULL OR v2 IS NULL OR v3 IS NULL THEN RAISE EXCEPTION 'Missing synthetic complaints';END IF;checks:=checks+3;
 PERFORM set_config('request.jwt.claim.sub',a::text,true);
 r:=public.ff41_case_create('staff_grievance','QA staff grievance','QA synthetic description',b1,NULL,'normal',NULL,NULL,NULL);g:=(r->>'case_id')::uuid;
 IF g IS NULL THEN RAISE EXCEPTION 'Missing synthetic grievance';END IF;checks:=checks+1;
 r:=public.ff41_case_detail(g);IF r#>>'{item,id}' IS DISTINCT FROM g::text THEN RAISE EXCEPTION 'Own grievance unavailable';END IF;checks:=checks+1;
 r:=public.ff41_case_comment(g,'QA own comment');IF r->>'saved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Own grievance comment unavailable';END IF;checks:=checks+1;
 FOREACH actor IN ARRAY ARRAY[cs,c,s,d,k,u,x] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff41_case_detail(g);RAISE EXCEPTION 'Foreign grievance read accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff41_case_comment(g,'QA denied comment');RAISE EXCEPTION 'Foreign grievance comment accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff41_case_transition(g,'in_review',NULL);RAISE EXCEPTION 'Unauthorized transition accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);
 r:=public.ff41_case_detail(v1);IF r#>>'{item,customer_phone}' IS DISTINCT FROM phone_value THEN RAISE EXCEPTION 'Own desk complaint missing';END IF;checks:=checks+1;
 FOREACH target IN ARRAY ARRAY[v2,v3] LOOP
  BEGIN PERFORM public.ff41_case_detail(target);RAISE EXCEPTION 'Foreign complaint read accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff41_case_comment(target,'QA denied comment');RAISE EXCEPTION 'Foreign complaint comment accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 END LOOP;
 BEGIN PERFORM public.ff41_case_create('customer_complaint','QA forbidden desk','QA synthetic description',b1,o2,'normal',NULL,NULL,'phone');RAISE EXCEPTION 'Foreign desk creation accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 r:=public.ff41_case_list(NULL,NULL,100);IF NOT EXISTS(SELECT FROM jsonb_array_elements(r->'items') j WHERE j->>'id'=v1::text) OR EXISTS(SELECT FROM jsonb_array_elements(r->'items') j WHERE j->>'id' IN(v2::text,v3::text,g::text)) THEN RAISE EXCEPTION 'Cashier case list scope';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',s::text,true);
 r:=public.ff41_case_detail(v1);IF r#>>'{item,id}' IS DISTINCT FROM v1::text OR r#>>'{item,customer_phone}' IS NOT NULL THEN RAISE EXCEPTION 'Supervisor phone masking failed';END IF;checks:=checks+1;
 BEGIN PERFORM public.ff41_case_detail(v3);RAISE EXCEPTION 'Supervisor foreign branch accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 r:=public.ff_case_alerts(100);IF NOT EXISTS(SELECT FROM jsonb_array_elements(r->'items') j WHERE j->>'id'=v1::text) OR EXISTS(SELECT FROM jsonb_array_elements(r->'items') j WHERE j->>'id' IN(v3::text,g::text)) THEN RAISE EXCEPTION 'Alert branch scope';END IF;checks:=checks+1;
 BEGIN PERFORM public.ff_case_alert_read(v3);RAISE EXCEPTION 'Foreign alert read accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 IF public.ff_case_alert_read(v1) IS DISTINCT FROM true THEN RAISE EXCEPTION 'Own alert read denied';END IF;checks:=checks+1;
 r:=public.ff_case_alerts(100);IF NOT EXISTS(SELECT FROM jsonb_array_elements(r->'items') j WHERE j->>'id'=v1::text AND j->>'seen'='true') THEN RAISE EXCEPTION 'Alert receipt missing';END IF;checks:=checks+1;
 FOREACH actor IN ARRAY ARRAY[c,d,a,k,u,x] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff_case_alerts(100);RAISE EXCEPTION 'Unauthorized alerts returned' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff_case_alert_read(v1);RAISE EXCEPTION 'Unauthorized receipt accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 r:=public.ff41_case_detail(g);IF r#>>'{item,id}' IS DISTINCT FROM g::text THEN RAISE EXCEPTION 'Manager grievance read failed';END IF;checks:=checks+1;
 r:=public.ff41_case_transition(g,'in_review',NULL);IF r->>'status' IS DISTINCT FROM 'in_review' THEN RAISE EXCEPTION 'Manager review failed';END IF;checks:=checks+1;
 r:=public.ff41_case_transition(g,'resolved','QA synthetic resolution');IF r->>'status' IS DISTINCT FROM 'resolved' THEN RAISE EXCEPTION 'Manager resolution failed';END IF;checks:=checks+1;
 r:=public.ff41_case_transition(g,'closed',NULL);IF r->>'status' IS DISTINCT FROM 'closed' THEN RAISE EXCEPTION 'Manager close failed';END IF;checks:=checks+1;
 RESET ROLE;
 IF (SELECT count(*) FROM public.ff41_case_events WHERE case_id=g)<>5 OR (SELECT count(*) FROM public.ff_case_alert_receipts WHERE case_id IN(v1,v2,v3))<>1 THEN RAISE EXCEPTION 'Unauthorized event or receipt persisted';END IF;checks:=checks+1;
 IF checks<>57 THEN RAISE EXCEPTION 'Expected 57 checks, got %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 case privacy: 57 assertions, grievance ownership, cashier desk, supervisor branch and phone masking, alerts and manager lifecycle' result;
ROLLBACK;
