-- A03 branch-scoped before-invoice reassignment: isolated actual RPC, complete rollback.
DO $qa$
DECLARE
 a uuid:=gen_random_uuid(); cs uuid:=gen_random_uuid(); b1 uuid:=gen_random_uuid(); b2 uuid:=gen_random_uuid();
 d1 uuid:=gen_random_uuid(); d2 uuid:=gen_random_uuid(); d3 uuid:=gen_random_uuid(); d4 uuid:=gen_random_uuid();
 o1 uuid:=gen_random_uuid(); o2 uuid:=gen_random_uuid(); o3 uuid:=gen_random_uuid();
 r jsonb; blocked boolean; passes int:=0;
BEGIN
 BEGIN
  INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-'||b1,'QA first'),(b2,'qa-'||b2,'QA second');
  INSERT INTO auth.users(id) VALUES(a),(cs);
  INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(a,'QA cashier','cashier',true),(cs,'QA CS','customer_service',true)
   ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
  INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(a,b1);
  INSERT INTO public.ff38_staff_permission_overrides(user_id,permission_key,allowed,updated_by) VALUES(a,'assign_driver',true,a);
  INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d1,'QA original',b2),(d2,'QA alternate',b2),(d3,'QA own original',b1),(d4,'QA own alternate',b1);
  INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at)
   VALUES(d1,'busy',now(),now()),(d2,'ready',now(),now()),(d3,'busy',now(),now()),(d4,'ready',now(),now())
   ON CONFLICT(driver_id) DO UPDATE SET state=excluded.state,checked_in_at=excluded.checked_in_at,last_seen_at=excluded.last_seen_at;
  INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot,driver_id,status)
   VALUES(o1,-(1+floor(random()*1e12)::bigint),b2,'000000000',public.ff_business_date(now()),'QA',d1,'sent'),
   (o2,-(1+floor(random()*1e12)::bigint),b1,'000000000',public.ff_business_date(now()),'QA',d3,'sent'),
   (o3,-(1+floor(random()*1e12)::bigint),b2,'000000000',public.ff_business_date(now()),'QA',d1,'sent');
  INSERT INTO public.ff38_delivery_tasks(order_id,driver_id) VALUES(o1,d1),(o2,d3),(o3,d1);
  UPDATE public.ff_orders SET status='cancelled' WHERE id=o3;
  UPDATE public.ff38_delivery_tasks SET delivered_at=now() WHERE order_id=o3;
  PERFORM set_config('request.jwt.claim.sub',a::text,true);
  SET LOCAL ROLE authenticated;
  blocked:=false;
  BEGIN PERFORM public.ff52_reassign_before_pos(o1,d2,'QA foreign branch');EXCEPTION WHEN SQLSTATE '42501' THEN blocked:=true;END;
  IF NOT blocked THEN RAISE EXCEPTION 'Foreign branch transfer accepted';END IF;passes:=passes+1;
  blocked:=false;
  BEGIN PERFORM public.ff52_reassign_before_pos(o2,d2,'QA foreign driver');EXCEPTION WHEN raise_exception THEN blocked:=true;END;
  IF NOT blocked THEN RAISE EXCEPTION 'Foreign driver accepted';END IF;passes:=passes+1;
  r:=public.ff52_reassign_before_pos(o2,d4,'QA own branch transfer');
  IF r->>'driver_id' IS DISTINCT FROM d4::text THEN RAISE EXCEPTION 'Own branch transfer failed';END IF;passes:=passes+1;
  PERFORM set_config('request.jwt.claim.sub',cs::text,true);
  r:=public.ff52_reassign_before_pos(o1,d2,'QA central transfer');
  IF r->>'driver_id' IS DISTINCT FROM d2::text THEN RAISE EXCEPTION 'Central CS transfer failed';END IF;passes:=passes+1;
  blocked:=false;
  BEGIN PERFORM public.ff52_reassign_before_pos(o3,d2,'QA terminal transfer');EXCEPTION WHEN raise_exception THEN blocked:=true;END;
  IF NOT blocked THEN RAISE EXCEPTION 'Cancelled transfer accepted';END IF;passes:=passes+1;
  RESET ROLE;
  IF (SELECT driver_id FROM public.ff_orders WHERE id=o1) IS DISTINCT FROM d2
   OR (SELECT driver_id FROM public.ff38_delivery_tasks WHERE order_id=o1) IS DISTINCT FROM d2
   OR (SELECT driver_id FROM public.ff_orders WHERE id=o2) IS DISTINCT FROM d4
   OR (SELECT driver_id FROM public.ff38_delivery_tasks WHERE order_id=o2) IS DISTINCT FROM d4
   OR (SELECT driver_id FROM public.ff_orders WHERE id=o3) IS DISTINCT FROM d1
   OR (SELECT count(*) FROM public.ff52_driver_reassignment_audit WHERE order_id IN(o1,o2,o3))<>2 THEN RAISE EXCEPTION 'Order/task/audit mismatch';END IF;passes:=passes+1;
  UPDATE public.ff38_staff_permission_overrides SET allowed=false WHERE user_id=a AND permission_key='assign_driver';
  PERFORM set_config('request.jwt.claim.sub',a::text,true);
  SET LOCAL ROLE authenticated;
  blocked:=false;
  BEGIN PERFORM public.ff52_reassign_before_pos(o2,d3,'QA revoked assignment');EXCEPTION WHEN SQLSTATE '42501' THEN blocked:=true;END;
  IF NOT blocked THEN RAISE EXCEPTION 'Revoked permission accepted';END IF;passes:=passes+1;
  RESET ROLE;
  RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF passes<>7 OR EXISTS(SELECT 1 FROM auth.users WHERE id IN(a,cs)) OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id IN(b1,b2))
 OR EXISTS(SELECT 1 FROM public.ff_orders WHERE id IN(o1,o2,o3)) THEN RAISE EXCEPTION 'Incomplete QA or rollback';END IF;
END $qa$;
SELECT 'PASS A03: seven reassignment checks, branch/driver isolation, own branch and central CS, cancelled denied, atomic audit, revoked denied; rollback' AS result;
