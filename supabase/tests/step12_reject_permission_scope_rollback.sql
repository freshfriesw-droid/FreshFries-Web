BEGIN;
DO $qa$
DECLARE b1 uuid:=gen_random_uuid();b2 uuid:=gen_random_uuid();m uuid:=gen_random_uuid();cs uuid:=gen_random_uuid();s uuid:=gen_random_uuid();s0 uuid:=gen_random_uuid();d uuid:=gen_random_uuid();c uuid:=gen_random_uuid();a uuid:=gen_random_uuid();k uuid:=gen_random_uuid();u uuid:=gen_random_uuid();x uuid:=gen_random_uuid();d1 uuid:=gen_random_uuid();d2 uuid:=gen_random_uuid();o1 uuid:=gen_random_uuid();o2 uuid:=gen_random_uuid();o3 uuid:=gen_random_uuid();r jsonb;n bigint:=-1000000000000-floor(random()*1e12)::bigint;actor uuid;checks int:=0;old_value boolean;
BEGIN
 INSERT INTO auth.users(id) VALUES(m),(cs),(s),(s0),(d),(c),(a),(k),(u),(x);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 reject manager','manager',true),(cs,'QA STEP12 reject CS','customer_service',true),(s,'QA STEP12 reject supervisor','supervisor',true),(s0,'QA STEP12 central supervisor','supervisor',true),(d,'QA STEP12 reject driver','driver',true),(c,'QA STEP12 reject cashier','cashier',true),(a,'QA STEP12 reject assembly','assembly',true),(k,'QA STEP12 reject kitchen','burger_kitchen',true),(x,'QA STEP12 reject disabled','supervisor',false);
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-step12-reject-'||b1,'QA STEP12 reject one'),(b2,'qa-step12-reject-'||b2,'QA STEP12 reject two');
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(s,b1),(d,b1),(c,b1),(a,b1),(k,b1),(x,b1);
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d1,'QA reject driver A',b1),(d2,'QA reject driver B',b2);
 INSERT INTO public.ff38_driver_links(user_id,driver_id) VALUES(d,d1);
 INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d1,'ready',now(),now()),(d2,'ready',now(),now()) ON CONFLICT(driver_id) DO UPDATE SET state='ready',checked_in_at=now(),last_seen_at=now();
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,area_snapshot,status,created_by,items_total,delivery_fee,total) VALUES(o1,n,b1,'000000000','QA area','new',cs,100,0,100),(o2,n-1,b2,'000000000','QA area','new',cs,100,0,100),(o3,n-2,b1,'000000000','QA area','cancelled',cs,100,0,100);
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 INSERT INTO public.ff38_dispatch_offers(order_id,driver_id,expires_at) VALUES(o1,d1,now()+interval '5 minutes'),(o2,d2,now()+interval '5 minutes');
 SELECT allow_driver_reject INTO old_value FROM public.ff_orders WHERE id=o1;
 SET LOCAL ROLE authenticated;
 PERFORM set_config('request.jwt.claim.sub',s::text,true);
 r:=public.ff38_get_reject_permissions();
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'order_id'=o1::text) OR EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'order_id' IN(o2::text,o3::text)) THEN RAISE EXCEPTION 'Scoped supervisor branch/terminal mismatch';END IF;checks:=checks+1;
 FOREACH actor IN ARRAY ARRAY[m,cs,s0] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  r:=public.ff38_get_reject_permissions();
  IF NOT EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'order_id'=o1::text) OR NOT EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'order_id'=o2::text) OR EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'order_id'=o3::text) THEN RAISE EXCEPTION 'Central role scope regression';END IF;checks:=checks+1;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',d::text,true);r:=public.ff38_get_reject_permissions();
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'order_id'=o1::text) OR EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'order_id' IN(o2::text,o3::text)) THEN RAISE EXCEPTION 'Driver offer ownership mismatch';END IF;checks:=checks+1;
 FOREACH actor IN ARRAY ARRAY[c,a,k] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  r:=public.ff38_get_reject_permissions();IF jsonb_array_length(r)<>0 THEN RAISE EXCEPTION 'Non-dispatch role got data';END IF;checks:=checks+1;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY[u,x] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff38_get_reject_permissions();RAISE EXCEPTION 'Inactive reject permissions accessible' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY[s,s0,d,c,a,k,u,x] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff38_set_driver_reject_permission(o1,NOT old_value);RAISE EXCEPTION 'Unauthorized reject permission changed' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff38_list_reject_permission_audit();RAISE EXCEPTION 'Unauthorized reject audit read' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',cs::text,true);
 r:=public.ff38_set_driver_reject_permission(o1,NOT old_value);
 IF (r->>'allow_driver_reject')::boolean IS DISTINCT FROM NOT old_value THEN RAISE EXCEPTION 'CS update lost';END IF;checks:=checks+1;
 r:=public.ff38_list_reject_permission_audit();IF jsonb_typeof(r) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'CS audit unavailable';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 r:=public.ff38_set_driver_reject_permission(o1,old_value);IF (r->>'allow_driver_reject')::boolean IS DISTINCT FROM old_value THEN RAISE EXCEPTION 'Manager update lost';END IF;checks:=checks+1;
 r:=public.ff38_list_reject_permission_audit();IF jsonb_typeof(r) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Manager audit unavailable';END IF;checks:=checks+1;
 RESET ROLE;
 IF (SELECT allow_driver_reject FROM public.ff_orders WHERE id=o1) IS DISTINCT FROM old_value THEN RAISE EXCEPTION 'Fixture state mismatch';END IF;checks:=checks+1;
 IF checks<>31 THEN RAISE EXCEPTION 'Expected 31 assertions, got %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 reject permission scope: 31 assertions; scoped and central supervisors, driver own offers, manager/CS writes and audit, inactive denials' result;
ROLLBACK;
