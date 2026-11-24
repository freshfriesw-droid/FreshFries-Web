-- A03: exercise actual reply/cancel/redispatch paths, with rollback of every fixture.
DO $qa$
DECLARE b uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); u1 uuid:=gen_random_uuid(); u2 uuid:=gen_random_uuid();
 d1 uuid:=gen_random_uuid(); d2 uuid:=gen_random_uuid(); o1 uuid:=gen_random_uuid(); o2 uuid:=gen_random_uuid();
 o3 uuid:=gen_random_uuid(); o4 uuid:=gen_random_uuid(); o5 uuid:=gen_random_uuid(); f uuid; f2 uuid; oid uuid;
 r jsonb; passes int:=0; blocked boolean;
BEGIN
 BEGIN
  INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-'||b,'QA A03 isolated branch');
  INSERT INTO auth.users(id) VALUES(a),(u1),(u2);
  INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(a,'QA manager','manager',true),(u1,'QA driver 1','driver',true),(u2,'QA driver 2','driver',true)
   ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
  INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d1,'QA driver 1',b),(d2,'QA driver 2',b);
  INSERT INTO public.ff38_driver_links(user_id,driver_id) VALUES(u1,d1),(u2,d2);
  INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d1,'ready',now(),now()),(d2,'ready',now(),now())
   ON CONFLICT(driver_id) DO UPDATE SET state='ready',checked_in_at=now(),last_seen_at=now();
  FOREACH oid IN ARRAY ARRAY[o1,o2,o3,o4,o5] LOOP
   INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot,allow_driver_reject)
   VALUES(oid,-(1+floor(random()*1e12)::bigint),b,'000000000',public.ff_business_date(now()),'QA',true);
  END LOOP;
  PERFORM set_config('request.jwt.claim.sub',a::text,true);
  r:=public.ff38_dispatch(o1,d1); f:=(r->>'offer_id')::uuid;
  IF f IS NULL THEN RAISE EXCEPTION 'No offer created'; END IF;
  PERFORM set_config('request.jwt.claim.sub',u2::text,true);
  SET LOCAL ROLE authenticated;
  blocked:=false;
  BEGIN PERFORM public.ff38_driver_reply(f,true,null);
  EXCEPTION WHEN raise_exception THEN blocked:=true; END;
  IF NOT blocked THEN RAISE EXCEPTION 'Foreign driver replied'; END IF; passes:=passes+1;
  PERFORM set_config('request.jwt.claim.sub',u1::text,true);
  blocked:=false;
  BEGIN PERFORM public.ff38_driver_reply(f,null,null);
  EXCEPTION WHEN raise_exception THEN blocked:=true; END;
  IF NOT blocked THEN RAISE EXCEPTION 'Null decision accepted'; END IF; passes:=passes+1;
  r:=public.ff38_driver_reply(f,true,null);
  IF r->>'state' IS DISTINCT FROM 'accepted' THEN RAISE EXCEPTION 'Accept failed: %',r; END IF; passes:=passes+1;
  blocked:=false;
  BEGIN PERFORM public.ff38_driver_reply(f,true,null);
  EXCEPTION WHEN raise_exception THEN blocked:=true; END;
  IF NOT blocked THEN RAISE EXCEPTION 'Duplicate reply accepted'; END IF; passes:=passes+1;
  RESET ROLE;
  IF (SELECT count(*) FROM public.ff38_delivery_tasks WHERE order_id=o1 AND driver_id=d1)<>1
   OR (SELECT status FROM public.ff38_dispatch_offers WHERE id=f)<>'accepted' THEN RAISE EXCEPTION 'Accepted assignment mismatch';END IF;
  PERFORM set_config('request.jwt.claim.sub',a::text,true);
  r:=public.ff38_dispatch(o2,d2); f:=(r->>'offer_id')::uuid;
  IF f IS NULL THEN RAISE EXCEPTION 'No cancellable offer';END IF;
  PERFORM public.ff38_cancel_unassigned_order(o2,'QA cancel before acceptance');
  PERFORM set_config('request.jwt.claim.sub',u2::text,true);
  SET LOCAL ROLE authenticated;
  blocked:=false;
  BEGIN PERFORM public.ff38_driver_reply(f,true,null);
  EXCEPTION WHEN raise_exception THEN blocked:=true; END;
  IF NOT blocked THEN RAISE EXCEPTION 'Cancelled offer accepted';END IF;passes:=passes+1;
  RESET ROLE;
  IF EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE order_id=o2)
   OR (SELECT status FROM public.ff_orders WHERE id=o2)<>'cancelled' THEN RAISE EXCEPTION 'Cancel state changed';END IF;
  PERFORM set_config('request.jwt.claim.sub',a::text,true);
  r:=public.ff38_dispatch(o3,d2);f:=(r->>'offer_id')::uuid;
  IF f IS NULL THEN RAISE EXCEPTION 'No rejection fixture';END IF;
  PERFORM set_config('request.jwt.claim.sub',u2::text,true);
  SET LOCAL ROLE authenticated;
  r:=public.ff38_driver_reply(f,false,'QA permitted reject');
  IF r->>'state' IS DISTINCT FROM 'rejected' THEN RAISE EXCEPTION 'Reject failed: %',r;END IF;passes:=passes+1;
  RESET ROLE;
  IF (SELECT status FROM public.ff38_dispatch_offers WHERE id=f)<>'rejected'
   OR EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE order_id=o3 AND driver_id=d2) THEN RAISE EXCEPTION 'Rejected driver assigned';END IF;
  -- Direct fixture expires in the past even after the deadline trigger.
  INSERT INTO public.ff38_dispatch_offers(order_id,driver_id,offered_at,expires_at)
   VALUES(o4,d2,now()-interval '20 minutes',now()-interval '10 minutes') RETURNING id INTO f;
  SET LOCAL ROLE authenticated;
  r:=public.ff38_driver_reply(f,true,null);
  IF r->>'state' IS DISTINCT FROM 'expired' THEN RAISE EXCEPTION 'Late response not expired: %',r;END IF;passes:=passes+1;
  RESET ROLE;
  IF (SELECT status FROM public.ff38_dispatch_offers WHERE id=f)<>'expired'
   OR EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE order_id=o4 AND driver_id=d2) THEN RAISE EXCEPTION 'Expired driver assigned';END IF;
  IF EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE order_id=o1 GROUP BY order_id HAVING count(*)>1) THEN RAISE EXCEPTION 'Duplicate task';END IF;
  RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF passes<>7 OR EXISTS(SELECT 1 FROM auth.users WHERE id IN(a,u1,u2)) OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id=b)
 OR EXISTS(SELECT 1 FROM public.ff_orders WHERE id IN(o1,o2,o3,o4,o5)) THEN RAISE EXCEPTION 'Incomplete coverage or rollback';END IF;
END $qa$;
SELECT 'PASS A03: seven checks, foreign/null/duplicate replies denied, valid accept, cancel-before-accept, permitted rejection, late expiry; rollback' AS result;
