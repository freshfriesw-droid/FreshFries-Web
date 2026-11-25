BEGIN;
DO $qa$
DECLARE s uuid:=gen_random_uuid(); cs uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); b1 uuid:=gen_random_uuid(); b2 uuid:=gen_random_uuid(); o1 uuid:=gen_random_uuid(); o2 uuid:=gen_random_uuid(); d1 uuid:=gen_random_uuid(); d2 uuid:=gen_random_uuid(); v jsonb; who uuid; checks int:=0;
BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-snapshot-'||b1,'QA scope one'),(b2,'qa-snapshot-'||b2,'QA scope two');
 INSERT INTO auth.users(id) VALUES(s),(cs),(m);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(s,'QA STEP12 supervisor','supervisor',true),(cs,'QA STEP12 central','customer_service',true),(m,'QA STEP12 manager','manager',true);
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(s,b1);
 INSERT INTO public.ff_drivers(id,name,branch_id,active) VALUES(d1,'QA one',b1,true),(d2,'QA two',b2,true);
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot,order_type) VALUES(o1,-(1+floor(random()*1e12)::bigint),b1,'000000000',public.ff_business_date(now()),'QA','delivery'),(o2,-(1+floor(random()*1e12)::bigint),b2,'000000000',public.ff_business_date(now()),'QA','delivery');
 SET LOCAL ROLE authenticated;
 PERFORM set_config('request.jwt.claim.sub',s::text,true);
 v:=public.ff38_snapshot();
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(v->'orders') x WHERE x->>'id'=o1::text) OR EXISTS(SELECT FROM jsonb_array_elements(v->'orders') x WHERE x->>'id'=o2::text) THEN RAISE EXCEPTION 'Order scope failed'; END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(v->'drivers') x WHERE x->>'id'=d1::text) OR EXISTS(SELECT FROM jsonb_array_elements(v->'drivers') x WHERE x->>'id'=d2::text) THEN RAISE EXCEPTION 'Driver scope failed';END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(v->'branches') x WHERE x->>'id'=b1::text) OR EXISTS(SELECT FROM jsonb_array_elements(v->'branches') x WHERE x->>'id'=b2::text) THEN RAISE EXCEPTION 'Branch scope failed';END IF;checks:=checks+1;
 FOREACH who IN ARRAY ARRAY[cs,m] LOOP
  PERFORM set_config('request.jwt.claim.sub',who::text,true);
  v:=public.ff38_snapshot();
  IF NOT EXISTS(SELECT FROM jsonb_array_elements(v->'orders') x WHERE x->>'id'=o1::text) OR NOT EXISTS(SELECT FROM jsonb_array_elements(v->'orders') x WHERE x->>'id'=o2::text) THEN RAISE EXCEPTION 'Central order access broken';END IF;checks:=checks+1;
  IF NOT EXISTS(SELECT FROM jsonb_array_elements(v->'drivers') x WHERE x->>'id'=d1::text) OR NOT EXISTS(SELECT FROM jsonb_array_elements(v->'drivers') x WHERE x->>'id'=d2::text) THEN RAISE EXCEPTION 'Central driver access broken';END IF;checks:=checks+1;
 END LOOP;
 RESET ROLE;
 UPDATE public.ff_user_branches SET branch_id=b2 WHERE user_id=s AND branch_id=b1;
 PERFORM set_config('request.jwt.claim.sub',s::text,true);SET LOCAL ROLE authenticated;
 v:=public.ff38_snapshot();
 IF EXISTS(SELECT FROM jsonb_array_elements(v->'orders') x WHERE x->>'id'=o1::text) OR NOT EXISTS(SELECT FROM jsonb_array_elements(v->'orders') x WHERE x->>'id'=o2::text) THEN RAISE EXCEPTION 'Branch change not immediate';END IF;checks:=checks+1;
 RESET ROLE;
 UPDATE public.ff_profiles SET active=false WHERE user_id=s;
 SET LOCAL ROLE authenticated;
 BEGIN PERFORM public.ff38_snapshot();RAISE EXCEPTION 'Inactive account accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 RESET ROLE;
 IF checks<>9 THEN RAISE EXCEPTION 'Incomplete tests: %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12: 9 snapshot scope assertions including immediate branch change and inactive account; central roles preserved' result;
ROLLBACK;
