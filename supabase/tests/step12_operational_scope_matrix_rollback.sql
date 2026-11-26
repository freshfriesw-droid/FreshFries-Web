BEGIN;
DO $qa$
DECLARE b1 uuid:=gen_random_uuid();b2 uuid:=gen_random_uuid();m uuid:=gen_random_uuid();cs uuid:=gen_random_uuid();c uuid:=gen_random_uuid();s uuid:=gen_random_uuid();d uuid:=gen_random_uuid();a uuid:=gen_random_uuid();k uuid:=gen_random_uuid();k2 uuid:=gen_random_uuid();u uuid:=gen_random_uuid();x uuid:=gen_random_uuid();r jsonb;actor uuid;rid1 uuid;rid2 uuid;checks int:=0;items jsonb:='[{"name":"QA synthetic item","qty":1,"price":100}]';today date:=public.ff_business_date(now());
BEGIN
 INSERT INTO auth.users(id) VALUES(m),(cs),(c),(s),(d),(a),(k),(k2),(u),(x);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 scope manager','manager',true),(cs,'QA STEP12 scope CS','customer_service',true),(c,'QA STEP12 scope cashier','cashier',true),(s,'QA STEP12 scope supervisor','supervisor',true),(d,'QA STEP12 scope driver','driver',true),(a,'QA STEP12 scope assembly','assembly',true),(k,'QA STEP12 scope kitchen','burger_kitchen',true),(k2,'QA STEP12 other kitchen','burger_kitchen',true),(x,'QA STEP12 scope disabled','manager',false);
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-step12-op-'||b1,'QA STEP12 scope one'),(b2,'qa-step12-op-'||b2,'QA STEP12 scope two');
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c,b1),(s,b1),(d,b1),(a,b1),(k,b1),(k2,b2),(x,b1);
 SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',m::text,true);
 PERFORM public.ff62_assembly_set_branch(a,b1,true);
 r:=public.ff49_create_reservation(b1,'QA synthetic one','000000000',now()+interval '10 minutes',items,'');rid1:=(r->>'reservation_id')::uuid;
 PERFORM set_config('request.jwt.claim.sub',cs::text,true);
 r:=public.ff49_create_reservation(b2,'QA synthetic two','000000000',now()+interval '15 minutes',items,'');rid2:=(r->>'reservation_id')::uuid;
 IF rid1 IS NULL OR rid2 IS NULL THEN RAISE EXCEPTION 'Missing reservations';END IF;checks:=checks+2;
 FOREACH actor IN ARRAY ARRAY[m,cs,c,s,d,a,k] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  r:=public.ff49_catalog();IF jsonb_typeof(r) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Active catalog denied';END IF;checks:=checks+1;
  IF public.ff_is_manager() IS DISTINCT FROM (actor=m) THEN RAISE EXCEPTION 'Manager helper incorrect';END IF;checks:=checks+1;
  IF public.ff_has_branch(b1) IS DISTINCT FROM (actor IN(m,c,s,d,a,k)) OR public.ff_has_branch(b2) IS DISTINCT FROM (actor=m) THEN RAISE EXCEPTION 'Branch helper incorrect';END IF;checks:=checks+1;
  IF actor IN(m,cs,c,s) THEN
   r:=public.ff49_reservations_list(200);
   IF NOT EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'id'=rid1::text) OR EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'id'=rid2::text) IS DISTINCT FROM (actor IN(m,cs)) THEN RAISE EXCEPTION 'Reservation read scope incorrect';END IF;
  ELSE
   BEGIN PERFORM public.ff49_reservations_list(200);RAISE EXCEPTION 'Unauthorized reservation read' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
  END IF;checks:=checks+1;
  IF actor IN(m,cs) THEN r:=public.ff_luxe_dispatch_preview(b2,'QA area');IF r->>'state' IS DISTINCT FROM 'waiting' THEN RAISE EXCEPTION 'Central preview denied';END IF;
  ELSE BEGIN PERFORM public.ff_luxe_dispatch_preview(b2,'QA area');RAISE EXCEPTION 'Unauthorized dispatch preview' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
  END IF;checks:=checks+1;
  IF actor=m THEN r:=public.ff27_quality(today,today,b1);IF jsonb_typeof(r) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Manager report denied';END IF;
  ELSE BEGIN PERFORM public.ff27_quality(today,today,b1);RAISE EXCEPTION 'Unauthorized manager report' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
  END IF;checks:=checks+1;
  IF actor IN(m,cs,s) THEN r:=public.ff_f01_daily_summary(today,today-1,b1);IF jsonb_typeof(r->'days') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Daily report denied';END IF;
  ELSE BEGIN PERFORM public.ff_f01_daily_summary(today,today-1,b1);RAISE EXCEPTION 'Unauthorized daily report' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
  END IF;checks:=checks+1;
  IF actor NOT IN(m,cs) THEN
   BEGIN PERFORM public.ff49_create_reservation(b1,'QA synthetic','000000000',now()+interval '1 hour',items,'');RAISE EXCEPTION 'Unauthorized reservation creation' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  END IF;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY[u,x] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  IF public.ff_is_manager() OR public.ff_has_branch(b1) THEN RAISE EXCEPTION 'Inactive branch/manager helper';END IF;checks:=checks+1;
  BEGIN PERFORM public.ff49_catalog();RAISE EXCEPTION 'Inactive catalog access' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff49_reservations_list(200);RAISE EXCEPTION 'Inactive reservation read' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff49_create_reservation(b1,'QA synthetic','000000000',now()+interval '1 hour',items,'');RAISE EXCEPTION 'Inactive reservation creation' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff27_quality(today,today,b1);RAISE EXCEPTION 'Inactive quality report' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff_f01_daily_summary(today,today-1,b1);RAISE EXCEPTION 'Inactive daily report' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff_luxe_dispatch_preview(b2,'QA area');RAISE EXCEPTION 'Inactive dispatch preview' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',s::text,true);
 BEGIN PERFORM public.ff_f01_daily_summary(today,today-1,b2);RAISE EXCEPTION 'Foreign report accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 BEGIN PERFORM public.ff49_reservation_transition(rid1,'reviewed','QA supervisor');RAISE EXCEPTION 'Supervisor transition accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);
 BEGIN PERFORM public.ff49_reservation_transition(rid2,'cancelled','QA other branch');RAISE EXCEPTION 'Foreign reservation transition accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 BEGIN PERFORM public.ff49_reservation_transition(rid1,'reviewed','QA wrong role');RAISE EXCEPTION 'Cashier reviewed reservation' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',cs::text,true);PERFORM public.ff49_reservation_transition(rid1,'reviewed','QA reviewed');PERFORM public.ff49_reservation_transition(rid1,'confirmed','QA confirmed');checks:=checks+2;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);PERFORM public.ff49_reservation_transition(rid1,'preparing','QA preparation');checks:=checks+1;
 -- Kitchen/assembly role and branch resolution, presence visible only in assigned branch.
 PERFORM set_config('request.jwt.claim.sub',k::text,true);IF public.ff_burger_presence_ping(true) IS DISTINCT FROM true THEN RAISE EXCEPTION 'Kitchen presence denied';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',k2::text,true);PERFORM public.ff_burger_presence_ping(true);
 FOREACH actor IN ARRAY ARRAY[c,a,k] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  r:=public.ff_burger_my_branch();IF jsonb_array_length(r->'branches')<>1 OR r#>>'{branches,0,id}' IS DISTINCT FROM b1::text THEN RAISE EXCEPTION 'Kitchen branch leak';END IF;checks:=checks+1;
  r:=public.ff_burger_online_status();IF jsonb_array_length(r)<>1 OR r#>>'{0,branch_id}' IS DISTINCT FROM b1::text OR r#>>'{0,online_count}' IS DISTINCT FROM '1' THEN RAISE EXCEPTION 'Kitchen presence scope';END IF;checks:=checks+1;
  IF (public.ff_v12_assembly_me()->>'is_assembly')::boolean IS DISTINCT FROM (actor=a) THEN RAISE EXCEPTION 'Assembly identity incorrect';END IF;checks:=checks+1;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY[m,cs,s,d,u,x] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff_burger_my_branch();RAISE EXCEPTION 'Unauthorized kitchen branch accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff_burger_online_status();RAISE EXCEPTION 'Unauthorized kitchen presence accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  IF public.ff_v12_assembly_me()->>'is_assembly' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Unauthorized assembly role';END IF;checks:=checks+1;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY[c,a] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff_burger_presence_ping(true);RAISE EXCEPTION 'Non-kitchen presence accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 END LOOP;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',m::text,true);
 UPDATE public.ff_v9_assembly_access SET enabled=false WHERE user_id=a AND branch_id=b1;
 SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',a::text,true);
 IF public.ff_v12_assembly_me()->>'is_assembly' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Revoked assembly still enabled';END IF;checks:=checks+1;
 BEGIN PERFORM public.ff_burger_my_branch();RAISE EXCEPTION 'Revoked assembly kitchen access' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 RESET ROLE;
 IF (SELECT status FROM public.ff49_reservations WHERE id=rid1) IS DISTINCT FROM 'preparing' OR (SELECT status FROM public.ff49_reservations WHERE id=rid2) IS DISTINCT FROM 'new' THEN RAISE EXCEPTION 'Unauthorized reservation changed';END IF;checks:=checks+1;
 IF checks<>110 THEN RAISE EXCEPTION 'Expected 110 assertions, got %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 operational scope matrix: 110 assertions; reservation, branch helpers, reports, kitchen presence, assembly and dispatch preview; rollback' result;
ROLLBACK;
