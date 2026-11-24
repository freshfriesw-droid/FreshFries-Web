-- A02: validation before dispatch, no actual order or customer changes.
DO $qa$
DECLARE v_manager uuid; v_missing uuid:=gen_random_uuid(); v_input jsonb; v_case jsonb; v_msg text; v_previous text;
BEGIN
 SELECT user_id INTO v_manager FROM public.ff_profiles WHERE role='manager' AND active LIMIT 1;
 IF v_manager IS NULL THEN RAISE EXCEPTION 'No active manager test context'; END IF;
 v_previous:=current_setting('request.jwt.claim.sub',true);
 PERFORM set_config('request.jwt.claim.sub',v_manager::text,true);
 v_input:=jsonb_build_object('p_branch',v_missing,'p_items',jsonb_build_array(jsonb_build_object('name','QA fixture','qty',1,'price',100)),
  'p_phone','700000000','p_area','QA area','p_customer_name','QA customer','p_channel','phone','p_full_address','QA address');
 FOR v_case IN SELECT value FROM jsonb_array_elements('[{}, {"p_delivery_fee":null}, {"p_delivery_fee":""}, {"p_delivery_fee":-1}, {"p_delivery_fee":"NaN"}]'::jsonb) LOOP
  v_msg:=NULL;
  BEGIN
   PERFORM public.ff27_submit(gen_random_uuid(),'delivery',v_input||v_case);
  EXCEPTION WHEN SQLSTATE '22023' THEN v_msg:=SQLERRM; END;
  IF v_msg IS DISTINCT FROM 'أدخل أجرة التوصيل صراحةً، حتى لو كانت صفرًا' THEN
   RAISE EXCEPTION 'A02 fee validation failed: %',v_case;
  END IF;
 END LOOP;
 v_msg:=NULL;
 BEGIN
  PERFORM public.ff27_submit(gen_random_uuid(),'delivery',v_input||'{"p_delivery_fee":0}'::jsonb);
 EXCEPTION WHEN OTHERS THEN v_msg:=SQLERRM; END;
 IF v_msg IS DISTINCT FROM 'الفرع غير صحيح' THEN RAISE EXCEPTION 'Explicit zero fee failed: %',v_msg; END IF;
 PERFORM set_config('request.jwt.claim.sub',coalesce(v_previous,''),true);
END $qa$;
