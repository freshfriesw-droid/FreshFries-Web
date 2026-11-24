-- Safe integration check; uses a non-existent order and makes no data changes.
DO $qa$
DECLARE v_manager uuid; v_missing uuid:=gen_random_uuid(); v_msg text; v_reason text; v_previous text;
BEGIN
 SELECT user_id INTO v_manager FROM public.ff_profiles WHERE role='manager' AND active LIMIT 1;
 IF v_manager IS NULL THEN RAISE EXCEPTION 'No active manager test context'; END IF;
 v_previous:=current_setting('request.jwt.claim.sub',true);
 PERFORM set_config('request.jwt.claim.sub',v_manager::text,true);
 IF auth.uid() IS DISTINCT FROM v_manager THEN RAISE EXCEPTION 'JWT fixture failed'; END IF;
 FOREACH v_reason IN ARRAY ARRAY[NULL::text,'','   ',repeat('x',301)] LOOP
  v_msg:=NULL;
  BEGIN
   PERFORM public.ff_order_customer_edit(v_missing,'700000000','QA area','QA customer','QA address',v_reason);
  EXCEPTION WHEN SQLSTATE '22023' THEN v_msg:=SQLERRM; END;
  IF v_msg IS DISTINCT FROM 'سبب التعديل إلزامي وبحد أقصى 300 حرف' THEN
   RAISE EXCEPTION 'A02 mandatory reason check failed';
  END IF;
 END LOOP;
 v_msg:=NULL;
 BEGIN
  PERFORM public.ff_order_customer_edit(v_missing,'700000000','QA area','QA customer','QA address','A02 QA valid reason');
 EXCEPTION WHEN OTHERS THEN v_msg:=SQLERRM; END;
 IF v_msg IS DISTINCT FROM 'الطلب غير موجود' THEN RAISE EXCEPTION 'Valid reason check failed: %',v_msg; END IF;
 PERFORM set_config('request.jwt.claim.sub',coalesce(v_previous,''),true);
END $qa$;
