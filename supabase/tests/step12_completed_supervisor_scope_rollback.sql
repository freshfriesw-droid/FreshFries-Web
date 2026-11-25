BEGIN;
DO $qa$
DECLARE b1 uuid:=gen_random_uuid();b2 uuid:=gen_random_uuid();s uuid:=gen_random_uuid();central uuid:=gen_random_uuid();m uuid:=gen_random_uuid();c uuid:=gen_random_uuid();o1 uuid:=gen_random_uuid();o2 uuid:=gen_random_uuid();v jsonb;u uuid;d date:=public.ff_business_date(now());checks int:=0;
BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-completed-'||b1,'QA completed one'),(b2,'qa-completed-'||b2,'QA completed two');
 INSERT INTO auth.users(id) VALUES(s),(central),(m),(c);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(s,'QA STEP12 scoped supervisor','supervisor',true),(central,'QA STEP12 central supervisor','supervisor',true),(m,'QA STEP12 manager','manager',true),(c,'QA STEP12 central CS','customer_service',true);
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(s,b1);
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot,order_type,status) VALUES(o1,-(1+floor(random()*1e12)::bigint),b1,'000000000',d,'QA','delivery','cancelled'),(o2,-(1+floor(random()*1e12)::bigint),b2,'000000000',d,'QA','delivery','cancelled');
 SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',s::text,true);
 v:=public.ff_luxe_completed_universal(d,d,b1,60,0);
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(v->'items') x WHERE x->>'id'=o1::text) THEN RAISE EXCEPTION 'Own completed order missing';END IF;checks:=checks+1;
 v:=public.ff_luxe_completed_universal(d,d,b2,60,0);
 IF jsonb_array_length(v->'items')<>0 OR EXISTS(SELECT FROM jsonb_array_elements(v->'branches') x WHERE x->>'id'=b2::text) THEN RAISE EXCEPTION 'Foreign completed branch exposed';END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(v->'branches') x WHERE x->>'id'=b1::text) THEN RAISE EXCEPTION 'Own branch selector missing';END IF;checks:=checks+1;
 v:=public.ff_luxe_completed_universal(d,d,NULL,60,0);
 IF EXISTS(SELECT FROM jsonb_array_elements(v->'items') x WHERE x->>'id'=o2::text) THEN RAISE EXCEPTION 'Implicit foreign branch exposure';END IF;checks:=checks+1;
 BEGIN PERFORM public.ff_luxe_completed_universal_action(o2,'report','{}');RAISE EXCEPTION 'Foreign action not rejected by authorization' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 FOREACH u IN ARRAY ARRAY[central,m,c] LOOP
  PERFORM set_config('request.jwt.claim.sub',u::text,true);
  v:=public.ff_luxe_completed_universal(d,d,b2,60,0);
  IF NOT EXISTS(SELECT FROM jsonb_array_elements(v->'items') x WHERE x->>'id'=o2::text) THEN RAISE EXCEPTION 'Central access lost';END IF;checks:=checks+1;
 END LOOP;
 RESET ROLE;
 UPDATE public.ff_user_branches SET branch_id=b2 WHERE user_id=s;
 SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',s::text,true);
 v:=public.ff_luxe_completed_universal(d,d,b2,60,0);
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(v->'items') x WHERE x->>'id'=o2::text) OR EXISTS(SELECT FROM jsonb_array_elements(v->'branches') x WHERE x->>'id'=b1::text) THEN RAISE EXCEPTION 'Branch reassignment not immediate';END IF;checks:=checks+1;
 RESET ROLE;
 IF checks<>9 THEN RAISE EXCEPTION 'Incomplete completed-order scope checks';END IF;
END $qa$;
SELECT 'PASS STEP12 completed-order scope: 9 checks; scoped supervisor read/action/branch selector, central roles, immediate reassignment' result;
ROLLBACK;
