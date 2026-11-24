-- Test actual authenticated grants plus canonical creation and rollback.
DO $qa$
DECLARE
 v_actor uuid;v_branch uuid;v_req uuid:=gen_random_uuid();v_order uuid;
 v_items jsonb;v_input jsonb;v_result jsonb;v_retry jsonb;
 v_price numeric;v_stmt text;v_state text;v_previous text;v_checks int:=0;
 v_bad jsonb;v_before int;v_after int;
BEGIN
 SELECT user_id INTO v_actor FROM public.ff_profiles WHERE active AND role='customer_service' LIMIT 1;
 SELECT id INTO STRICT v_branch FROM public.ff_branches WHERE active AND code='cairo';
 SELECT price INTO STRICT v_price FROM public.ff_menu_items WHERE active AND name='تشكن فرايز';
 IF v_actor IS NULL THEN RAISE EXCEPTION 'CS fixture unavailable';END IF;
 v_items:=jsonb_build_array(jsonb_build_object('name','تشكن فرايز','qty',1,'price',v_price,'item_notes','بدون شطة'));
 v_input:=jsonb_build_object('p_branch',v_branch,'p_phone','700000000','p_area','QA area',
   'p_items',v_items,'p_delivery_fee',0,'p_customer_name','QA customer','p_channel','phone',
   'p_full_address','QA address','p_notes','A02_WRITE_BOUNDARY_ROLLBACK');
 v_previous:=current_setting('request.jwt.claim.sub',true);
 PERFORM set_config('lock_timeout','3s',true);
 BEGIN
  PERFORM set_config('request.jwt.claim.sub',v_actor::text,true);
  SET LOCAL ROLE authenticated;
  -- These no-row statements still require UPDATE privilege.
  FOREACH v_stmt IN ARRAY ARRAY[
   'UPDATE public.ff_orders SET total=0 WHERE false',
   'UPDATE public.ff_order_items SET unit_price=0 WHERE false',
   'UPDATE public.ff_customers SET name=NULL WHERE false',
   'UPDATE public.ff_customer_notes SET note=NULL WHERE false',
   'SELECT public.ff_create_order_with_items(''{}''::jsonb,''[]''::jsonb)',
   'SELECT public.ff38_create_delivery_order(NULL,NULL,NULL,NULL,0,'''')',
   'SELECT public.ff49_create_delivery_order(NULL,NULL,NULL,NULL,0,'''',NULL,NULL,NULL)',
   'SELECT public.ff38_create_order_addition(NULL,NULL)',
   'SELECT public.ff38_cancel_order_addition(NULL)'
  ] LOOP
   v_state:=NULL;
   BEGIN EXECUTE v_stmt;
   EXCEPTION WHEN SQLSTATE '42501' THEN v_state:=SQLSTATE;END;
   IF v_state IS DISTINCT FROM '42501' THEN RAISE EXCEPTION 'Legacy/direct write not denied: %',v_stmt;END IF;
   v_checks:=v_checks+1;
  END LOOP;
  v_result:=public.ff27_submit(v_req,'delivery',v_input);
  v_order:=(v_result->>'order_id')::uuid;
  v_retry:=public.ff70_submit_atomic(v_req,'delivery',v_input);
  IF v_retry IS DISTINCT FROM v_result THEN RAISE EXCEPTION 'Legacy atomic replay mismatch';END IF;
  v_state:=NULL;
  BEGIN
   PERFORM public.ff70_submit_atomic(gen_random_uuid(),'delivery',v_input-'p_delivery_fee');
  EXCEPTION WHEN SQLSTATE '22023' THEN v_state:=SQLSTATE;END;
  IF v_state IS DISTINCT FROM '22023' THEN RAISE EXCEPTION 'Legacy fee bypass';END IF;
  v_checks:=v_checks+1;
  v_bad:=jsonb_set(v_input,'{p_items,0,price}','1.001'::jsonb);
  v_state:=NULL;
  BEGIN
   PERFORM public.ff27_submit(gen_random_uuid(),'delivery',v_bad);
  EXCEPTION WHEN SQLSTATE '22023' THEN v_state:=SQLSTATE;END;
  IF v_state IS DISTINCT FROM '22023' THEN RAISE EXCEPTION 'Rounded price accepted';END IF;
  v_checks:=v_checks+1;
  RESET ROLE;
  IF NOT EXISTS(SELECT 1 FROM public.ff_orders WHERE id=v_order AND total=v_price)
   OR NOT EXISTS(SELECT 1 FROM public.ff_order_items WHERE order_id=v_order AND quantity=1
   AND unit_price=v_price AND item_notes='بدون شطة') THEN RAISE EXCEPTION 'Current RPC save mismatch';END IF;
  IF (SELECT count(*) FROM public.ff_orders WHERE notes='A02_WRITE_BOUNDARY_ROLLBACK')<>1 THEN
   RAISE EXCEPTION 'Duplicate or partial order saved';END IF;
  RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF v_checks<>11 OR v_order IS NULL OR EXISTS(SELECT 1 FROM public.ff_orders WHERE id=v_order)
  OR EXISTS(SELECT 1 FROM public.ff70_atomic_requests WHERE request_id=v_req)
  OR EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE order_id=v_order) THEN RAISE EXCEPTION 'QA rollback failure';END IF;
 IF NOT has_table_privilege('authenticated','public.ff_orders','SELECT')
  OR NOT has_table_privilege('service_role','public.ff_orders','UPDATE') THEN RAISE EXCEPTION 'Realtime/service grants changed';END IF;
 PERFORM set_config('request.jwt.claim.sub',coalesce(v_previous,''),true);
END $qa$;
SELECT 'PASS: direct table mutations and legacy RPCs denied; canonical order saved exactly; legacy idempotent replay; missing fee and rounding blocked; complete rollback' AS result;
