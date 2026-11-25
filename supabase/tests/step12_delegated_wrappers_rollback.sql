BEGIN;
DO $qa$
DECLARE b1 uuid:=gen_random_uuid();b2 uuid:=gen_random_uuid();m uuid:=gen_random_uuid();s uuid:=gen_random_uuid();c uuid:=gen_random_uuid();u uuid:=gen_random_uuid();disabled uuid:=gen_random_uuid();o uuid:=gen_random_uuid();actor uuid;dy date:=public.ff_business_date(now())-1;calls text[];stmt text;r jsonb;checks int:=0;
BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-wrapper-'||b1,'QA wrapper one'),(b2,'qa-wrapper-'||b2,'QA wrapper two');
 INSERT INTO auth.users(id) VALUES(m),(s),(c),(u),(disabled);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 manager','manager',true),(s,'QA STEP12 supervisor','supervisor',true),(c,'QA STEP12 cashier','cashier',true),(disabled,'QA STEP12 disabled','cashier',false);
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(s,b1),(c,b1),(disabled,b1);
 INSERT INTO public.ff38_staff_permission_overrides(user_id,permission_key,allowed,updated_by) VALUES(s,'view_reports',true,m);
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot,status,created_at) VALUES(o,-1000000000000-floor(random()*1e12)::bigint,b2,'000000000',dy,'QA','new',(dy+time '12:00') AT TIME ZONE 'Asia/Aden');
 calls:=ARRAY[
 format('SELECT public.ff40_operations_report(%L::date,%L::date,%L::uuid)',dy,dy,b1),
 'SELECT public.ff51_driver_rating_summary()',
 format('SELECT public.ff76_reporting_center(%L::date,%L::date,%L::uuid,NULL)',dy,dy,b1),
 'SELECT public.ff_burger_menu()',
 format('SELECT * FROM public.ff_ui_effective(%L::uuid,%L)',b1,'mobile'),
 format('SELECT * FROM public.ff_ui_manager_source(%L,%L::uuid,%L)','cashier',b1,'desktop'),
 format('SELECT public.ff_v12_assembly_set_stage(%L::uuid,%L,%L)',o,'preparing','printed')];
 SET LOCAL ROLE authenticated;
 FOREACH actor IN ARRAY ARRAY[u,disabled] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  FOREACH stmt IN ARRAY calls LOOP
   BEGIN EXECUTE stmt;RAISE EXCEPTION 'Unauthorized wrapper accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN checks:=checks+1;END;
  END LOOP;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',s::text,true);
 BEGIN PERFORM public.ff40_operations_report(dy,dy,b2);RAISE EXCEPTION 'Foreign report allowed' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 BEGIN PERFORM public.ff76_reporting_center(dy,dy,b2,NULL);RAISE EXCEPTION 'Foreign report wrapper allowed' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 BEGIN PERFORM * FROM public.ff_ui_effective(b2,'mobile');RAISE EXCEPTION 'Foreign design allowed' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 BEGIN PERFORM * FROM public.ff_ui_manager_source('cashier',b1,'desktop');RAISE EXCEPTION 'Supervisor manager source allowed' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 r:=public.ff40_operations_report(dy,dy,b1);IF jsonb_typeof(r)<>'object' THEN RAISE EXCEPTION 'Own report inaccessible';END IF;checks:=checks+1;
 r:=public.ff51_driver_rating_summary();IF jsonb_typeof(r)<>'array' THEN RAISE EXCEPTION 'Own rating report inaccessible';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 r:=public.ff76_reporting_center(dy,dy,b2,NULL);IF (r#>>'{totals,orders}')::int IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'Manager report missing synthetic order';END IF;checks:=checks+1;
 PERFORM * FROM public.ff_ui_manager_source('cashier',b1,'desktop');checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);
 r:=public.ff_burger_menu();IF jsonb_typeof(r)<>'array' THEN RAISE EXCEPTION 'Cashier burger menu unavailable';END IF;checks:=checks+1;
 PERFORM * FROM public.ff_ui_effective(b1,'mobile');checks:=checks+1;
 RESET ROLE;
 IF checks<>24 THEN RAISE EXCEPTION 'Expected 24 checks, got %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 delegated wrappers: 24 assertions (14 nonstaff/disabled denials, 4 scope denials, 6 authorized paths)' result;
ROLLBACK;
