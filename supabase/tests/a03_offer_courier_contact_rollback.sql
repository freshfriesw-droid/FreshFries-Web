-- TR-42: actual role-scoped snapshots. Synthetic number; no production PII output.
DO $qa$
DECLARE b uuid:=gen_random_uuid(); cs uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); su uuid:=gen_random_uuid(); du uuid:=gen_random_uuid(); c uuid:=gen_random_uuid();
 d uuid:=gen_random_uuid(); o uuid:=gen_random_uuid(); f uuid; actor uuid; snap jsonb; offered jsonb; passes int:=0; role_name text;
BEGIN
 BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-'||b,'QA offer contact');
 INSERT INTO auth.users(id) VALUES(cs),(m),(su),(du),(c);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(cs,'QA CS','customer_service',true),(m,'QA manager','manager',true),(su,'QA supervisor','supervisor',true),(du,'QA driver','driver',true),(c,'QA cashier','cashier',true)
 ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(su,b),(c,b);
 INSERT INTO public.ff_drivers(id,name,branch_id,phone) VALUES(d,'QA courier',b,'000000001');
 INSERT INTO public.ff38_driver_links(user_id,driver_id) VALUES(du,d);
 INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d,'ready',now(),now()) ON CONFLICT(driver_id) DO UPDATE SET state='ready',checked_in_at=now(),last_seen_at=now();
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot) VALUES(o,-(1+floor(random()*1e12)::bigint),b,'000000000',public.ff_business_date(now()),'QA area');
 INSERT INTO public.ff38_dispatch_offers(order_id,driver_id,expires_at) VALUES(o,d,now()+interval '10 minutes') RETURNING id INTO f;
 SET LOCAL ROLE authenticated;
 FOREACH actor IN ARRAY ARRAY[cs,m,su,du,c] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  snap:=public.ff49_snapshot();
  role_name:=snap->>'role';
  select e into offered from jsonb_array_elements(snap->'offers') e where e->>'id'=f::text;
  IF actor IN(cs,m) THEN
   IF offered->>'driver_phone' IS DISTINCT FROM '000000001' OR offered->>'driver_id' IS DISTINCT FROM d::text THEN RAISE EXCEPTION 'Authorized contact missing: %',role_name;END IF;
  ELSIF offered ? 'driver_phone' THEN RAISE EXCEPTION 'Unauthorized contact exposed: %',role_name;
  END IF;passes:=passes+1;
 END LOOP;
 RESET ROLE;
 UPDATE public.ff_drivers SET phone=null WHERE id=d;
 PERFORM set_config('request.jwt.claim.sub',cs::text,true);SET LOCAL ROLE authenticated;
 snap:=public.ff49_snapshot();
 select e into offered from jsonb_array_elements(snap->'offers') e where e->>'id'=f::text;
 IF offered->>'driver_phone' IS NOT NULL THEN RAISE EXCEPTION 'Missing phone fabricated';END IF;passes:=passes+1;
 RESET ROLE;
 RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF passes<>6 OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id=b) OR EXISTS(SELECT 1 FROM public.ff_orders WHERE id=o)
 OR EXISTS(SELECT 1 FROM auth.users WHERE id IN(cs,m,su,du,c)) THEN RAISE EXCEPTION 'Incomplete QA/rollback';END IF;
END $qa$;
SELECT 'PASS A03 TR-42: six checks, current courier contact for CS/manager only, supervisor/driver/cashier denied, null stays null, rollback' AS result;