BEGIN;
DO $qa$
DECLARE b uuid:=gen_random_uuid();b2 uuid:=gen_random_uuid();a uuid:=gen_random_uuid();m uuid:=gen_random_uuid();req_r uuid:=gen_random_uuid();req_d uuid:=gen_random_uuid();payload_r jsonb;payload_d jsonb;r jsonb;d jsonb;checks int:=0;phase text;oid uuid;rid uuid;
BEGIN
 INSERT INTO auth.users(id) VALUES(a),(m);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(a,'QA STEP12 atomic scope','customer_service',true),(m,'QA STEP12 atomic manager','manager',true);
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-step12-replay-'||b,'QA STEP12 replay branch'),(b2,'qa-step12-replay-'||b2,'QA STEP12 other branch');
 payload_r:=jsonb_build_object('p_branch',b,'p_customer_name','QA synthetic','p_phone','000000000','p_pickup',now()+interval '1 hour','p_items',jsonb_build_array(jsonb_build_object('name','QA item','qty',1,'price',100)));
 payload_d:=jsonb_build_object('p_branch',b,'p_customer_name','QA synthetic','p_phone','000000000','p_area','QA area','p_channel','phone','p_full_address','QA address','p_delivery_fee',0,'p_items',jsonb_build_array(jsonb_build_object('name','QA item','qty',1,'price',100,'item_notes','QA note')));
 SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',a::text,true);
 r:=public.ff27_submit(req_r,'reservation',payload_r);rid:=(r->>'reservation_id')::uuid;IF rid IS NULL THEN RAISE EXCEPTION 'Reservation fixture missing';END IF;checks:=checks+1;
 d:=public.ff70_submit_atomic(req_d,'delivery',payload_d);oid:=(d->>'order_id')::uuid;IF oid IS NULL THEN RAISE EXCEPTION 'Delivery fixture missing';END IF;checks:=checks+1;
 IF public.ff27_submit(req_r,'reservation',payload_r) IS DISTINCT FROM r THEN RAISE EXCEPTION 'Reservation retry not idempotent';END IF;checks:=checks+1;
 IF public.ff70_submit_atomic(req_d,'delivery',payload_d) IS DISTINCT FROM d THEN RAISE EXCEPTION 'Delivery retry not idempotent';END IF;checks:=checks+1;
 BEGIN PERFORM public.ff27_submit(req_r,'reservation',payload_r||jsonb_build_object('p_notes','different'));RAISE EXCEPTION 'Changed payload reused' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE 'P0001' THEN NULL;END;checks:=checks+1;
 RESET ROLE;
 FOREACH phase IN ARRAY ARRAY['disabled','revoked','branch_inactive','role_changed','branch_moved'] LOOP
  PERFORM set_config('request.jwt.claim.sub',m::text,true);
  UPDATE public.ff_profiles SET active=(phase<>'disabled'),role=CASE WHEN phase IN('role_changed','branch_moved') THEN 'cashier' ELSE 'customer_service' END WHERE user_id=a;
  DELETE FROM public.ff38_staff_permission_overrides WHERE user_id=a AND permission_key='create_order';
  DELETE FROM public.ff_user_branches WHERE user_id=a;
  IF phase='revoked' THEN INSERT INTO public.ff38_staff_permission_overrides(user_id,permission_key,allowed,updated_by) VALUES(a,'create_order',false,m);END IF;
  IF phase IN ('role_changed','branch_moved') THEN
   INSERT INTO public.ff38_staff_permission_overrides(user_id,permission_key,allowed,updated_by) VALUES(a,'create_order',true,m);
   INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(a,CASE WHEN phase='role_changed' THEN b ELSE b2 END);
  END IF;
  UPDATE public.ff_branches SET active=(phase<>'branch_inactive') WHERE id=b;
  SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',a::text,true);
  BEGIN PERFORM public.ff27_submit(req_r,'reservation',payload_r);RAISE EXCEPTION 'Unauthorized reservation retry %',phase USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  IF phase='role_changed' THEN
   IF public.ff70_submit_atomic(req_d,'delivery',payload_d) IS DISTINCT FROM d THEN RAISE EXCEPTION 'Legitimate explicitly granted delivery retry lost';END IF;
  ELSE
   BEGIN PERFORM public.ff70_submit_atomic(req_d,'delivery',payload_d);RAISE EXCEPTION 'Unauthorized delivery retry %',phase USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;
  END IF;checks:=checks+1;
  RESET ROLE;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 UPDATE public.ff_profiles SET active=true,role='customer_service' WHERE user_id=a;
 DELETE FROM public.ff38_staff_permission_overrides WHERE user_id=a AND permission_key='create_order';
 UPDATE public.ff_branches SET active=true WHERE id=b;
 SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',a::text,true);
 IF public.ff27_submit(req_r,'reservation',payload_r) IS DISTINCT FROM r OR public.ff70_submit_atomic(req_d,'delivery',payload_d) IS DISTINCT FROM d THEN RAISE EXCEPTION 'Restored permissions retry lost';END IF;checks:=checks+2;
 RESET ROLE;
 IF (SELECT count(*) FROM public.ff70_atomic_requests WHERE actor_id=a)<>2 OR (SELECT count(*) FROM public.ff_orders WHERE branch_id=b)<>1 OR (SELECT count(*) FROM public.ff49_reservations WHERE branch_id=b)<>1 THEN RAISE EXCEPTION 'Retry duplicated records';END IF;checks:=checks+1;
 IF checks<>18 THEN RAISE EXCEPTION 'Expected 18 assertions, got %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 atomic replay scope: 18 assertions; current account, permission and branch checks, valid retry, no duplicate records; rollback' result;
ROLLBACK;
