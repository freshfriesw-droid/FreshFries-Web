BEGIN;
DO $qa$
DECLARE b1 uuid:=gen_random_uuid();b2 uuid:=gen_random_uuid();m uuid:=gen_random_uuid();cs uuid:=gen_random_uuid();c uuid:=gen_random_uuid();s uuid:=gen_random_uuid();du uuid:=gen_random_uuid();a uuid:=gen_random_uuid();k uuid:=gen_random_uuid();u uuid:=gen_random_uuid();x uuid:=gen_random_uuid();cust uuid:=gen_random_uuid();unverified uuid:=gen_random_uuid();d1 uuid:=gen_random_uuid();d2 uuid:=gen_random_uuid();o uuid[]:=ARRAY[gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];phone_value text:='7'||lpad(floor(random()*1e8)::bigint::text,8,'0');desk1 text:='qa-'||gen_random_uuid();desk2 text:='qa-'||gen_random_uuid();actor uuid;rr uuid;cid uuid;r jsonb;checks int:=0;i int;n bigint:=-1000000000000-floor(random()*1e12)::bigint;today date:=public.ff_business_date(now());
BEGIN
 INSERT INTO auth.users(id) VALUES(m),(cs),(c),(s),(du),(a),(k),(u),(x);
 INSERT INTO auth.users(id,phone,phone_confirmed_at) VALUES(cust,'967'||phone_value,now()),(unverified,'9677'||lpad(floor(random()*1e8)::bigint::text,8,'0'),NULL);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 rating manager','manager',true),(cs,'QA STEP12 rating CS','customer_service',true),(c,'QA STEP12 rating cashier','cashier',true),(s,'QA STEP12 rating supervisor','supervisor',true),(du,'QA STEP12 rating driver','driver',true),(a,'QA STEP12 rating assembly','assembly',true),(k,'QA STEP12 rating kitchen','burger_kitchen',true),(x,'QA STEP12 rating disabled','cashier',false);
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-step12-rating-'||b1,'QA STEP12 rating one'),(b2,'qa-step12-rating-'||b2,'QA STEP12 rating two');
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c,b1),(s,b1),(du,b1),(a,b1),(k,b1),(x,b1);
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d1,'QA rating driver one',b1),(d2,'QA rating driver two',b2);
 INSERT INTO public.ff38_driver_links(user_id,driver_id) VALUES(du,d1);
 INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d1,'busy',now(),now()),(d2,'busy',now(),now()) ON CONFLICT(driver_id) DO UPDATE SET state='busy',checked_in_at=now(),last_seen_at=now();
 INSERT INTO public.ff_luxe_cashier_desks(code,label,branch_id,sort_order) VALUES(desk1,'QA desk 1',b1,1),(desk2,'QA desk 2',b1,2);
 INSERT INTO public.ff_luxe_cashier_staff_desks(user_id,desk_code,assigned_by) VALUES(c,desk1,m);
 FOR i IN 1..5 LOOP
  INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,area_snapshot,status,created_by,items_total,delivery_fee,total,driver_id,delivered_at) VALUES(o[i],n-i,CASE WHEN i=3 THEN b2 ELSE b1 END,CASE WHEN i=3 THEN '000000000' ELSE phone_value END,'QA area',CASE WHEN i<=3 THEN 'delivered' ELSE 'sent' END,CASE WHEN i=3 THEN m ELSE cs END,100,0,100,CASE WHEN i=3 THEN d2 ELSE d1 END,CASE WHEN i<=3 THEN now() ELSE NULL END);
  INSERT INTO public.ff38_delivery_tasks(order_id,driver_id,phase,cashier_stage,delivered_at) VALUES(o[i],CASE WHEN i=3 THEN d2 ELSE d1 END,CASE WHEN i<=3 THEN 'delivered' ELSE 'on_way' END,'handed_over',CASE WHEN i<=3 THEN now() ELSE NULL END);
  IF i<>3 THEN INSERT INTO public.ff_luxe_cashier_order_desks(order_id,desk_code) VALUES(o[i],CASE WHEN i=2 THEN desk2 ELSE desk1 END);END IF;
  IF i IN(2,4,5) THEN INSERT INTO public.ff49_cashier_receipts(order_id,received_by) VALUES(o[i],c);END IF;
 END LOOP;
 SET LOCAL ROLE authenticated;
 PERFORM set_config('request.jwt.claim.sub',cs::text,true);
 r:=public.ff_luxe_rate_driver_cs(o[1],2,'QA private service note');IF r->>'saved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'CS rating lost';END IF;checks:=checks+1;
 BEGIN PERFORM public.ff_luxe_rate_driver_cs(o[3],4,'QA other creator');RAISE EXCEPTION 'Foreign creator rating accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 RESET ROLE;SELECT id INTO rr FROM public.ff51_driver_ratings WHERE order_id=o[1] AND rater_role='customer_service';
 SET LOCAL ROLE authenticated;
 FOREACH actor IN ARRAY ARRAY[s,du,a,k,u,x] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff51_rate_driver(o[1],4,'QA denied');RAISE EXCEPTION 'Unauthorized legacy rating' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff_luxe_rate_driver_cashier(o[1],4,'QA denied');RAISE EXCEPTION 'Unauthorized cashier rating' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff_luxe_rate_driver_cs(o[1],4,'QA denied');RAISE EXCEPTION 'Unauthorized CS rating' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff_a10_escalate_rating(rr,'QA denied escalation');RAISE EXCEPTION 'Unauthorized rating escalation' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff_a10_cashier_coordination(o[4],4,'QA denied');RAISE EXCEPTION 'Unauthorized coordination' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);
 BEGIN PERFORM public.ff_a10_cashier_coordination(o[2],4,'QA prior receipt wrong desk');RAISE EXCEPTION 'Other desk coordination accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 BEGIN PERFORM public.ff51_rate_driver(o[2],4,'QA other desk');RAISE EXCEPTION 'Other desk legacy rating accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 BEGIN PERFORM public.ff_luxe_rate_driver_cashier(o[3],4,'QA other branch');RAISE EXCEPTION 'Other branch rating accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 PERFORM public.ff51_rate_driver(o[1],4,'QA legacy own desk');checks:=checks+1;
 PERFORM public.ff_luxe_rate_driver_cashier(o[4],3,'QA current own desk');checks:=checks+1;
 IF public.ff_a10_cashier_coordination(o[4],4,'QA coordination') IS DISTINCT FROM true THEN RAISE EXCEPTION 'Own coordination lost';END IF;checks:=checks+1;
 BEGIN PERFORM public.ff_a10_cashier_coordination(o[4],5,'QA duplicate');RAISE EXCEPTION 'Duplicate coordination accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE 'P0001' THEN NULL;END;checks:=checks+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',m::text,true);
 DELETE FROM public.ff_user_branches WHERE user_id=c;INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c,b2);
 SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',c::text,true);
 BEGIN PERFORM public.ff_a10_cashier_coordination(o[5],4,'QA former receipt');RAISE EXCEPTION 'Former branch coordination accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',cust::text,true);
 r:=public.ff_a10_customer_rate(o[1],2,'QA customer rating');IF r->>'saved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Verified customer rating lost';END IF;checks:=checks+1;
 BEGIN PERFORM public.ff_a10_customer_rate(o[3],4,'QA foreign order');RAISE EXCEPTION 'Foreign customer rating accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 BEGIN PERFORM public.ff_a10_customer_rate(o[1],5,'QA duplicate');RAISE EXCEPTION 'Duplicate customer rating accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 FOREACH actor IN ARRAY ARRAY[unverified,cs,c,x] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff_a10_customer_rate(o[2],4,'QA denied');RAISE EXCEPTION 'Unverified or staff customer rating accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);PERFORM public.ff_luxe_rate_driver_cashier(o[3],3,'QA other driver');
 r:=public.ff_a10_escalate_rating(rr,'QA follow-up reason');cid:=(r->>'case_id')::uuid;IF cid IS NULL OR r->>'ok' IS DISTINCT FROM 'true' OR public.ff_a10_escalate_rating(rr,'QA duplicate follow-up')->>'already_exists' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Manager escalation or idempotency lost';END IF;checks:=checks+1;
 FOREACH actor IN ARRAY ARRAY[s,du] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  r:=public.ff_luxe_rating_summary_period(today,today,NULL);
  IF NOT EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'driver_id'=d1::text) OR EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'driver_id'=d2::text) THEN RAISE EXCEPTION 'Ratings summary scope leak';END IF;checks:=checks+1;
  BEGIN PERFORM public.ff_luxe_rating_summary_period(today,today,b2);RAISE EXCEPTION 'Other branch rating summary accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 END LOOP;
 RESET ROLE;
 IF (SELECT count(*) FROM ff_private.a10_cashier_coordination WHERE order_id=ANY(o))<>1 OR NOT EXISTS(SELECT FROM ff_private.a10_cashier_coordination WHERE order_id=o[4] AND stars=4) OR (SELECT rating FROM public.ff_orders WHERE id=o[2]) IS NOT NULL THEN RAISE EXCEPTION 'Denied rating mutated data';END IF;checks:=checks+1;
 IF checks<>53 THEN RAISE EXCEPTION 'Expected 53 assertions, got %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 rating and coordination matrix: 53 assertions; current branch and desk, verified customer, role ownership, report scope and escalation; rollback' result;
ROLLBACK;
