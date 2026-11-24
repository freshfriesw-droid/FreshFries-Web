-- A03 branch isolation: actual authenticated contexts, no persistent fixtures.
DO $qa$
DECLARE a uuid:=gen_random_uuid(); s uuid:=gen_random_uuid(); cs uuid:=gen_random_uuid();
 b1 uuid:=gen_random_uuid(); b2 uuid:=gen_random_uuid(); o1 uuid:=gen_random_uuid(); o2 uuid:=gen_random_uuid();
 d uuid:=gen_random_uuid(); who uuid; o uuid; r jsonb; blocked boolean; passes int:=0;
BEGIN
 BEGIN
  INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-'||b1,'QA A03 branch1'),(b2,'qa-'||b2,'QA A03 branch2');
  INSERT INTO auth.users(id) VALUES(a),(s),(cs);
  INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(a,'QA cashier','cashier',true),(s,'QA supervisor','supervisor',true),(cs,'QA central CS','customer_service',true)
   ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
  INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(a,b1),(s,b1);
  INSERT INTO public.ff38_staff_permission_overrides(user_id,permission_key,allowed,updated_by)
   VALUES(a,'assign_driver',true,a),(s,'assign_driver',true,s);
  INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d,'QA branch2 driver',b2);
  INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d,'ready',now(),now())
   ON CONFLICT(driver_id) DO UPDATE SET state='ready',checked_in_at=now(),last_seen_at=now();
  INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot)
   VALUES(o1,-(1+floor(random()*1e12)::bigint),b1,'000000000',public.ff_business_date(now()),'QA'),
         (o2,-(1+floor(random()*1e12)::bigint),b2,'000000000',public.ff_business_date(now()),'QA');
  SET LOCAL ROLE authenticated;
  FOREACH who IN ARRAY ARRAY[a,s] LOOP
   PERFORM set_config('request.jwt.claim.sub',who::text,true);
   blocked:=false;
   BEGIN PERFORM public.ff38_dispatch(o2,d);
   EXCEPTION WHEN SQLSTATE '42501' THEN blocked:=true;END;
   IF NOT blocked THEN RAISE EXCEPTION 'Foreign branch direct dispatch allowed';END IF; passes:=passes+1;
   blocked:=false;
   BEGIN PERFORM public.ff49_manual_dispatch(o2,d,'QA cross-branch check');
   EXCEPTION WHEN SQLSTATE '42501' THEN blocked:=true;END;
   IF NOT blocked THEN RAISE EXCEPTION 'Foreign branch manual dispatch allowed';END IF;passes:=passes+1;
   r:=public.ff38_dispatch(o1);
   IF r->>'state' IS DISTINCT FROM 'queued' THEN RAISE EXCEPTION 'Authorized own branch failed';END IF;passes:=passes+1;
  END LOOP;
  PERFORM set_config('request.jwt.claim.sub',cs::text,true);
  r:=public.ff38_dispatch(o2,d);
  IF r->>'state' IS DISTINCT FROM 'offered' OR r->>'driver_id' IS DISTINCT FROM d::text THEN RAISE EXCEPTION 'Central CS branch access broken';END IF;passes:=passes+1;
  RESET ROLE;
  UPDATE public.ff38_staff_permission_overrides SET allowed=false WHERE user_id=a AND permission_key='assign_driver';
  PERFORM set_config('request.jwt.claim.sub',a::text,true);
  SET LOCAL ROLE authenticated;
  blocked:=false;
  BEGIN PERFORM public.ff38_dispatch(o1);
  EXCEPTION WHEN SQLSTATE '42501' THEN blocked:=true;END;
  IF NOT blocked THEN RAISE EXCEPTION 'Revoked assignment allowed';END IF;passes:=passes+1;
  RESET ROLE;
  IF (SELECT count(*) FROM public.ff38_dispatch_offers WHERE order_id=o2 AND driver_id=d AND status='offered')<>1 THEN RAISE EXCEPTION 'Expected exactly one offer';END IF;
  RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF passes<>8 OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id IN(b1,b2))
 OR EXISTS(SELECT 1 FROM auth.users WHERE id IN(a,s,cs))
 OR EXISTS(SELECT 1 FROM public.ff_orders WHERE id IN(o1,o2)) THEN RAISE EXCEPTION 'Incomplete scope test or rollback';END IF;
END $qa$;
SELECT 'PASS A03: 8 checks, cashier/supervisor branch scope, manual dispatch denial, central CS preserved, revoked assignment denied; rollback' AS result;
