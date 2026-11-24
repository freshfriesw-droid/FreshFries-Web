-- A02 customer privacy: use rollback-only synthetic auth identities, never send SMS.
-- Exercise the database API with authenticated role and simulated subject.
DO $qa$
DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid();
 oa uuid:=gen_random_uuid(); ob uuid:=gen_random_uuid(); oc uuid:=gen_random_uuid();
 branch_id_value uuid; manager_id uuid; phone_a text; phone_b text; phone_c text;
 next_number bigint; result jsonb; msg text; pass boolean:=false; previous_claim text;
BEGIN
 SELECT id INTO STRICT branch_id_value FROM public.ff_branches WHERE active AND code='cairo';
 SELECT user_id INTO manager_id FROM public.ff_profiles WHERE active AND role='manager' LIMIT 1;
 IF manager_id IS NULL THEN RAISE EXCEPTION 'Manager fixture unavailable'; END IF;
 -- Choose unused Yemeni-format test numbers; never transmit them to a provider.
 SELECT '7'||lpad((10000000+floor(random()*89999999)::int)::text,8,'0') INTO phone_a;
 SELECT '7'||lpad((10000000+floor(random()*89999999)::int)::text,8,'0') INTO phone_b;
 SELECT '7'||lpad((10000000+floor(random()*89999999)::int)::text,8,'0') INTO phone_c;
 IF phone_a=phone_b OR phone_a=phone_c OR phone_b=phone_c OR EXISTS(
 SELECT 1 FROM auth.users WHERE phone IN ('967'||phone_a,'967'||phone_b,'967'||phone_c)
 ) OR EXISTS(SELECT 1 FROM public.ff_orders o WHERE
 regexp_replace(translate(coalesce(o.phone_snapshot,''),'٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','01234567890123456789'),'[^0-9]','','g')
 IN(phone_a,phone_b,phone_c,'967'||phone_a,'967'||phone_b,'967'||phone_c,'00967'||phone_a,'00967'||phone_b,'00967'||phone_c))
 THEN RAISE EXCEPTION 'Fixture collision; rerun safely'; END IF;
 previous_claim:=current_setting('request.jwt.claim.sub',true);
 PERFORM set_config('lock_timeout','3s',true);
 BEGIN
  INSERT INTO auth.users(id,aud,role,phone,phone_confirmed_at,created_at,updated_at)
  VALUES(a,'authenticated','authenticated','967'||phone_a,now(),now(),now()),
        (b,'authenticated','authenticated','967'||phone_b,now(),now(),now()),
        (c,'authenticated','authenticated','967'||phone_c,NULL,now(),now());
  PERFORM set_config('request.jwt.claim.sub',manager_id::text,true);
  PERFORM pg_advisory_xact_lock(hashtext('ff38-order-num-'||branch_id_value::text));
  SELECT coalesce(max(order_number),0)+1 INTO next_number FROM public.ff_orders WHERE branch_id=branch_id_value;
  INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,area_snapshot,status,order_type,items_total,total,created_by,delivered_at)
  VALUES(oa,next_number,branch_id_value,translate('00967'||phone_a,'0123456789','٠١٢٣٤٥٦٧٨٩'),'QA A','delivered','delivery',100,100,manager_id,now()),
        (ob,next_number+1,branch_id_value,'+967'||phone_b,'QA B','delivered','delivery',200,200,manager_id,now()),
        (oc,next_number+2,branch_id_value,translate(phone_a,'0123456789','۰۱۲۳۴۵۶۷۸۹'),'QA A2','delivered','delivery',300,300,manager_id,now());
  PERFORM set_config('request.jwt.claim.sub',a::text,true);
  SET LOCAL ROLE authenticated;
  IF public.ff28_my_role() IS DISTINCT FROM 'customer' THEN RAISE EXCEPTION 'A role mismatch'; END IF;
  result:=public.ff28_customer();
  IF jsonb_array_length(result)<>2 OR NOT result @> jsonb_build_array(jsonb_build_object('id',oa))
    OR NOT result @> jsonb_build_array(jsonb_build_object('id',oc)) OR result @> jsonb_build_array(jsonb_build_object('id',ob))
    THEN RAISE EXCEPTION 'A ownership mismatch'; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(result) x WHERE x ?| ARRAY['phone','phone_snapshot','customer_name','driver_id','area_snapshot','notes','created_by'])
    THEN RAISE EXCEPTION 'Private columns disclosed'; END IF;
  IF EXISTS(SELECT 1 FROM public.ff_orders WHERE id IN(oa,ob,oc)) THEN RAISE EXCEPTION 'Direct order RLS leak'; END IF;
  BEGIN PERFORM public.ff28_customer(ob,5); RAISE EXCEPTION 'Cross-customer rating accepted';
   EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
  BEGIN PERFORM public.ff28_customer(oa,NULL); RAISE EXCEPTION 'Null rating accepted';
   EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
  BEGIN PERFORM public.ff28_customer(oa,6); RAISE EXCEPTION 'Invalid rating accepted';
   EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
  result:=public.ff28_customer(oa,4);
  IF NOT result @> jsonb_build_array(jsonb_build_object('id',oa,'rating',4)) THEN RAISE EXCEPTION 'Own rating not saved'; END IF;
  BEGIN PERFORM public.ff28_customer(oa,5); RAISE EXCEPTION 'Duplicate rating accepted';
   EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
  PERFORM set_config('request.jwt.claim.sub',b::text,true);
  result:=public.ff28_customer();
  IF jsonb_array_length(result)<>1 OR NOT result @> jsonb_build_array(jsonb_build_object('id',ob)) THEN RAISE EXCEPTION 'B ownership mismatch'; END IF;
  BEGIN PERFORM public.ff28_customer(oc,5); RAISE EXCEPTION 'B cross-rating accepted';
   EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
  PERFORM set_config('request.jwt.claim.sub',c::text,true);
  BEGIN PERFORM public.ff28_customer(); RAISE EXCEPTION 'Unverified identity accepted';
   EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
  BEGIN PERFORM public.ff28_my_role(); RAISE EXCEPTION 'Unverified role accepted';
   EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
  PERFORM set_config('request.jwt.claim.sub',manager_id::text,true);
  BEGIN PERFORM public.ff28_customer(); RAISE EXCEPTION 'Staff identity accepted';
   EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
  RESET ROLE;
  IF NOT EXISTS(SELECT 1 FROM public.ff_orders WHERE id=oa AND rating=4)
    OR EXISTS(SELECT 1 FROM public.ff_orders WHERE id IN(ob,oc) AND rating IS NOT NULL)
    THEN RAISE EXCEPTION 'Rating storage mismatch'; END IF;
  pass:=true;
  RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL; END;
 IF NOT pass OR EXISTS(SELECT 1 FROM auth.users WHERE id IN(a,b,c))
  OR EXISTS(SELECT 1 FROM public.ff_orders WHERE id IN(oa,ob,oc))
  OR EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE order_id IN(oa,ob,oc))
 THEN RAISE EXCEPTION 'Privacy QA failed or fixture persisted'; END IF;
 PERFORM set_config('request.jwt.claim.sub',coalesce(previous_claim,''),true);
END $qa$;
SELECT 'PASS: two verified synthetic subjects, Arabic/Persian phone ownership, RLS, privacy fields, rating once, invalid/unverified/staff denied, complete rollback' AS result;
