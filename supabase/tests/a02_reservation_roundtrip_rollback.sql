-- Real role/branch/transition test, rollback all fixture data before commit.
DO $qa$
DECLARE
 v_actor uuid;v_manager uuid;v_driver uuid;v_cashier uuid;v_other uuid;
 v_branch record;v_id uuid;v_req uuid;v_input jsonb;v_items jsonb;v_result jsonb;
 v_case jsonb;v_msg text;v_count int:=0;v_cashier_count int:=0;v_prior text;
 v_ids uuid[]:=ARRAY[]::uuid[];v_requests uuid[]:=ARRAY[]::uuid[];
BEGIN
 SELECT user_id INTO v_actor FROM public.ff_profiles WHERE active AND role='customer_service' LIMIT 1;
 SELECT user_id INTO v_manager FROM public.ff_profiles WHERE active AND role='manager' LIMIT 1;
 SELECT user_id INTO v_driver FROM public.ff_profiles WHERE active AND role='driver' LIMIT 1;
 IF v_actor IS NULL OR v_manager IS NULL OR v_driver IS NULL THEN RAISE EXCEPTION 'QA roles missing'; END IF;
 SELECT jsonb_build_array(jsonb_build_object('name',name,'qty',2,'price',price,'item_notes','بدون شطة'))
 INTO STRICT v_items FROM public.ff_menu_items WHERE active AND name='تشكن فرايز';
 v_prior:=current_setting('request.jwt.claim.sub',true);
 PERFORM set_config('request.jwt.claim.sub',v_actor::text,true);
 PERFORM set_config('lock_timeout','3s',true);
 BEGIN
  FOR v_branch IN SELECT id,code FROM public.ff_branches WHERE active AND code IN ('cairo','sam_mall','khamseen') ORDER BY code LOOP
   FOR v_case IN SELECT value FROM jsonb_array_elements('[null,{},[],[{"name":"QA","qty":"NaN","price":100}],[{"name":"QA","qty":1,"price":"Infinity"}]]'::jsonb) LOOP
    v_msg:=NULL;
    BEGIN
     PERFORM public.ff49_create_reservation(v_branch.id,'QA customer','700000000',NULL,v_case,'A02 negative');
     RAISE EXCEPTION 'Unexpected invalid reservation';
    EXCEPTION WHEN SQLSTATE '22023' THEN v_msg:=SQLSTATE;END;
    IF v_msg IS DISTINCT FROM '22023' THEN RAISE EXCEPTION 'Invalid payload was not rejected';END IF;
   END LOOP;
   v_req:=gen_random_uuid();v_requests:=array_append(v_requests,v_req);
   v_input:=jsonb_build_object('p_branch',v_branch.id,'p_customer_name','QA customer','p_phone','700000000',
    'p_pickup',NULL,'p_items',v_items,'p_notes','A02_RES_ROLLBACK_20261124');
   v_result:=public.ff27_submit(v_req,'reservation',v_input);v_id:=(v_result->>'reservation_id')::uuid;
   v_ids:=array_append(v_ids,v_id);
   IF public.ff27_submit(v_req,'reservation',v_input) IS DISTINCT FROM v_result THEN RAISE EXCEPTION 'Reservation idempotency mismatch';END IF;
   IF NOT EXISTS(SELECT 1 FROM public.ff49_reservations WHERE id=v_id AND branch_id=v_branch.id
    AND status='new' AND pickup_unspecified AND items=v_items AND created_by=v_actor) THEN RAISE EXCEPTION 'Reservation save mismatch';END IF;
   v_msg:=NULL;
   BEGIN
    PERFORM public.ff49_reservation_transition(v_id,'ready','QA skip');
   EXCEPTION WHEN OTHERS THEN v_msg:=SQLERRM;END;
   IF v_msg IS DISTINCT FROM 'الانتقال بين حالات الحجز غير مسموح' THEN RAISE EXCEPTION 'Invalid transition not blocked';END IF;
   PERFORM public.ff49_reservation_transition(v_id,'reviewed','QA review');
   PERFORM public.ff49_reservation_transition(v_id,'confirmed','QA confirmation');
   v_msg:=NULL;
   BEGIN
    PERFORM public.ff49_reservation_transition(v_id,'preparing','QA wrong role');
   EXCEPTION WHEN SQLSTATE '42501' THEN v_msg:=SQLSTATE;END;
   IF v_msg IS DISTINCT FROM '42501' THEN RAISE EXCEPTION 'Customer service may not prepare reservation';END IF;
   SELECT f.user_id INTO v_other FROM public.ff_profiles f WHERE f.active AND f.role='cashier'
     AND NOT EXISTS(SELECT 1 FROM public.ff_user_branches u WHERE u.user_id=f.user_id AND u.branch_id=v_branch.id) LIMIT 1;
   IF v_other IS NOT NULL THEN
    PERFORM set_config('request.jwt.claim.sub',v_other::text,true);
    v_msg:=NULL;
    BEGIN
     PERFORM public.ff49_reservation_transition(v_id,'preparing','QA wrong branch');
    EXCEPTION WHEN SQLSTATE '42501' THEN v_msg:=SQLSTATE;END;
    IF v_msg IS DISTINCT FROM '42501' THEN RAISE EXCEPTION 'Cross-branch cashier access';END IF;
   END IF;
   SELECT f.user_id INTO v_cashier FROM public.ff_profiles f JOIN public.ff_user_branches u ON u.user_id=f.user_id
    WHERE f.active AND f.role='cashier' AND u.branch_id=v_branch.id LIMIT 1;
   IF v_cashier IS NOT NULL THEN v_cashier_count:=v_cashier_count+1;END IF;
   PERFORM set_config('request.jwt.claim.sub',coalesce(v_cashier,v_manager)::text,true);
   PERFORM public.ff49_reservation_transition(v_id,'preparing','QA preparation');
   PERFORM public.ff49_reservation_transition(v_id,'ready','QA ready');
   PERFORM public.ff49_reservation_transition(v_id,'collected','QA collected');
   IF NOT EXISTS(SELECT 1 FROM public.ff49_reservations WHERE id=v_id AND status='collected')
    OR (SELECT count(*) FROM public.ff49_reservation_events WHERE reservation_id=v_id)<>6
    OR EXISTS(SELECT 1 FROM public.ff_orders WHERE notes='A02_RES_ROLLBACK_20261124')
    THEN RAISE EXCEPTION 'Reservation state or delivery isolation mismatch';END IF;
   PERFORM set_config('request.jwt.claim.sub',v_driver::text,true);
   v_msg:=NULL;
   BEGIN
    PERFORM public.ff49_reservations_list(200);
   EXCEPTION WHEN SQLSTATE '42501' THEN v_msg:=SQLSTATE;END;
   IF v_msg IS DISTINCT FROM '42501' THEN RAISE EXCEPTION 'Driver can read reservation list';END IF;
   PERFORM set_config('request.jwt.claim.sub',v_actor::text,true);
   v_count:=v_count+1;
  END LOOP;
  IF v_count<>3 THEN RAISE EXCEPTION 'Incomplete branch coverage';END IF;
  RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;
 END;
 IF v_count<>3 OR EXISTS(SELECT 1 FROM public.ff49_reservations WHERE id=ANY(v_ids))
  OR EXISTS(SELECT 1 FROM public.ff49_reservation_events WHERE reservation_id=ANY(v_ids))
  OR EXISTS(SELECT 1 FROM public.ff70_atomic_requests WHERE request_id=ANY(v_requests))
 THEN RAISE EXCEPTION 'Reservation rollback failed';END IF;
 PERFORM set_config('request.jwt.claim.sub',coalesce(v_prior,''),true);
 RAISE NOTICE 'Passed % branches with % branch-cashier contexts, remaining manager fallback',v_count,v_cashier_count;
END $qa$;
SELECT 'PASS: reservation validation, states, role/branch guard, idempotency, no delivery, rollback' AS result;
