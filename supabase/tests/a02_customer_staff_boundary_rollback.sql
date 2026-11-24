-- Fail-closed employee RPC boundary for a verified customer without staff profile.
-- Synthetic auth fixture is rolled back; no SMS or employee/account changes.
DO $qa$
DECLARE u uuid:=gen_random_uuid(); branch uuid; missing uuid:=gen_random_uuid();
 cs uuid; v_phone text; stmt text; code text; count_pass int:=0; prev text;
BEGIN
 SELECT id INTO STRICT branch FROM public.ff_branches WHERE code='cairo' AND active;
 SELECT user_id INTO cs FROM public.ff_profiles WHERE active AND role='customer_service' LIMIT 1;
 IF cs IS NULL THEN RAISE EXCEPTION 'CS fixture unavailable';END IF;
 v_phone:='9677'||lpad((10000000+floor(random()*89999999)::int)::text,8,'0');
 IF EXISTS(SELECT 1 FROM auth.users WHERE auth.users.phone=v_phone) THEN RAISE EXCEPTION 'Fixture collision';END IF;
 prev:=current_setting('request.jwt.claim.sub',true);
 BEGIN
  INSERT INTO auth.users(id,aud,role,phone,phone_confirmed_at,created_at,updated_at)
   VALUES(u,'authenticated','authenticated',v_phone,now(),now(),now());
  PERFORM set_config('request.jwt.claim.sub',u::text,true);
  SET LOCAL ROLE authenticated;
  IF public.ff28_my_role() IS DISTINCT FROM 'customer' THEN RAISE EXCEPTION 'Customer fixture invalid'; END IF;
  FOREACH stmt IN ARRAY ARRAY[
   'select public.ff51_customer_directory('''',1)',
   'select public.ff49_reservations_list(1)',
   'select public.ff49_visible_transfers()',
   'select public.ff51_driver_rating_summary()',
   'select public.ff51_order_archive(current_date,current_date,NULL,NULL,1,0)',
   format('select public.ff51_rate_driver(%L::uuid,5,'''')',missing),
   'select public.ff_burger_list(1)',
   'select public.ff_burger_my_branch()',
   'select public.ff_burger_online_status()',
   format('select public.ff_burger_transition(%L::uuid,''receive'')',missing),
   format('select public.ff_case_alert_read(%L::uuid)',missing),
   'select public.ff_case_alerts(1)',
   format('select public.ff_luxe_dispatch_preview(%L::uuid,''QA area'')',branch),
   format('select public.ff_luxe_rate_driver_cashier(%L::uuid,5,'''')',missing),
   format('select public.ff_luxe_rate_driver_cs(%L::uuid,5,'''')',missing),
   'select public.ff_luxe_rating_summary_period(current_date,current_date,NULL)',
   'select public.ff_reward_check(''QA-NOT-A-CODE'')',
   format('select public.ff_reward_redeem(''QA-NOT-A-CODE'',%L::uuid,''cashier_pickup'','''',0,'''',%L::uuid,true)',branch,missing)
  ] LOOP
   code:=NULL;
   BEGIN EXECUTE stmt;
   EXCEPTION WHEN SQLSTATE '42501' THEN code:=SQLSTATE;
   END;
   IF code IS DISTINCT FROM '42501' THEN RAISE EXCEPTION 'Staff boundary bypass: %',stmt; END IF;
   count_pass:=count_pass+1;
  END LOOP;
  -- Preserve existing CS access, without returning private data.
  PERFORM set_config('request.jwt.claim.sub',cs::text,true);
  PERFORM public.ff51_customer_directory('',1);
  PERFORM public.ff49_reservations_list(1);
  PERFORM public.ff_luxe_dispatch_preview(branch,'QA area');
  RESET ROLE;
  RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL; END;
 IF count_pass<>18 OR EXISTS(SELECT 1 FROM auth.users WHERE id=u) THEN RAISE EXCEPTION 'Incomplete boundary QA or fixture persisted'; END IF;
 PERFORM set_config('request.jwt.claim.sub',coalesce(prev,''),true);
END $qa$;
SELECT 'PASS: 18 employee RPCs denied to verified nonstaff subject; CS directory/reservation/dispatch access preserved; fixture rolled back' AS result;
