-- A02: exact live RPCs, real role contexts and a temporary presence change.
-- Everything is inside an exception subtransaction, including push jobs.
DO $qa$
DECLARE
 v_actor uuid;v_cashier uuid;v_driver uuid;v_driver_user uuid;v_branch uuid;
 v_order uuid;v_offer uuid;v_request uuid:=gen_random_uuid();v_desk text;
 v_price numeric;v_items jsonb;v_add_items jsonb;v_input jsonb;v_result jsonb;
 v_add uuid;v_cancel uuid;v_late uuid;v_case jsonb;v_error text;v_prior text;
 v_old_presence jsonb;v_new_presence jsonb;v_fixture_driver uuid;
BEGIN
 SELECT id INTO STRICT v_branch FROM public.ff_branches WHERE active AND code='cairo';
 SELECT user_id INTO v_actor FROM public.ff_profiles WHERE active AND role='customer_service' LIMIT 1;
 SELECT p.user_id INTO v_cashier FROM public.ff_profiles p JOIN public.ff_user_branches u ON u.user_id=p.user_id
 WHERE p.active AND p.role='cashier' AND u.branch_id=v_branch LIMIT 1;
 SELECT d.id,l.user_id INTO v_driver,v_driver_user FROM public.ff_drivers d JOIN public.ff38_driver_links l ON l.driver_id=d.id
 JOIN public.ff_profiles f ON f.user_id=l.user_id JOIN public.ff38_driver_presence pr ON pr.driver_id=d.id
 WHERE d.branch_id=v_branch AND d.active AND f.active AND f.role='driver'
 AND NOT EXISTS(SELECT 1 FROM public.ff38_delivery_tasks t WHERE t.driver_id=d.id AND t.delivered_at IS NULL)
 AND NOT EXISTS(SELECT 1 FROM ff_private.automatic_dispatch_exclusions e WHERE e.branch_id=v_branch AND e.driver_id=d.id)
 ORDER BY d.id LIMIT 1;
 IF v_actor IS NULL OR v_cashier IS NULL OR v_driver IS NULL THEN RAISE EXCEPTION 'QA role context missing'; END IF;
 v_fixture_driver:=v_driver;
 SELECT to_jsonb(p) INTO v_old_presence FROM public.ff38_driver_presence p WHERE driver_id=v_fixture_driver;
 SELECT price INTO STRICT v_price FROM public.ff_menu_items WHERE active AND name='تشكن فرايز';
 v_items:=jsonb_build_array(jsonb_build_object('name','تشكن فرايز','qty',1,'price',v_price,'item_notes','QA initial'));
 v_add_items:=jsonb_build_array(jsonb_build_object('item_name','تشكن فرايز','quantity',2,'unit_price',v_price,
  'item_notes','بدون شطة','addition_notes','QA addition note'));
 SELECT code INTO v_desk FROM public.ff_luxe_cashier_desks WHERE branch_id=v_branch AND active ORDER BY code LIMIT 1;
 v_prior:=current_setting('request.jwt.claim.sub',true);
 PERFORM set_config('request.jwt.claim.sub',v_actor::text,true);
 PERFORM set_config('lock_timeout','3s',true);
 BEGIN
  UPDATE public.ff38_driver_presence SET state='ready',checked_in_at=coalesce(checked_in_at,now()),
   checked_out_at=NULL,last_seen_at=now() WHERE driver_id=v_fixture_driver;
  v_input:=jsonb_build_object('p_branch',v_branch,'p_desk',v_desk,'p_phone','700000000','p_area','QA area',
   'p_items',v_items,'p_delivery_fee',0,'p_customer_name','QA customer','p_channel','phone',
   'p_full_address','QA address','p_notes','A02_ADDITION_ROLLBACK_20261124');
  v_result:=public.ff27_submit(v_request,'delivery',v_input);v_order:=(v_result->>'order_id')::uuid;
  IF NOT EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE order_id=v_order) THEN
   SELECT id,driver_id INTO v_offer,v_driver FROM public.ff38_dispatch_offers WHERE order_id=v_order AND status='offered' LIMIT 1;
   IF v_offer IS NULL THEN RAISE EXCEPTION 'No active fixture offer'; END IF;
   SELECT l.user_id INTO STRICT v_driver_user FROM public.ff38_driver_links l JOIN public.ff_profiles f ON f.user_id=l.user_id
    WHERE l.driver_id=v_driver AND f.active AND f.role='driver';
   PERFORM set_config('request.jwt.claim.sub',v_driver_user::text,true);
   v_result:=public.ff38_driver_reply(v_offer,true,NULL);
   IF v_result->>'state' IS DISTINCT FROM 'accepted' THEN RAISE EXCEPTION 'Offer not accepted'; END IF;
  ELSE
   SELECT driver_id INTO STRICT v_driver FROM public.ff38_delivery_tasks WHERE order_id=v_order;
   SELECT l.user_id INTO STRICT v_driver_user FROM public.ff38_driver_links l JOIN public.ff_profiles f ON f.user_id=l.user_id
    WHERE l.driver_id=v_driver AND f.active AND f.role='driver';
  END IF;
  PERFORM set_config('request.jwt.claim.sub',v_actor::text,true);
  FOR v_case IN SELECT value FROM jsonb_array_elements('[null,{},[],[{"item_name":"QA","quantity":"NaN","unit_price":100}],[{"item_name":"QA","quantity":1,"unit_price":"Infinity"}]]'::jsonb) LOOP
   v_error:=NULL;
   BEGIN
    PERFORM public.ff52_regular_addition_create(v_order,v_case);
    RAISE EXCEPTION 'Unexpected invalid addition';
   EXCEPTION WHEN SQLSTATE '22023' THEN v_error:=SQLSTATE; END;
   IF v_error IS DISTINCT FROM '22023' THEN RAISE EXCEPTION 'Invalid addition was not rejected'; END IF;
  END LOOP;
  v_add:=(public.ff52_regular_addition_create(v_order,v_add_items)->>'addition_id')::uuid;
  v_cancel:=(public.ff52_regular_addition_create(v_order,v_add_items)->>'addition_id')::uuid;
  IF NOT EXISTS(SELECT 1 FROM public.ff38_order_additions WHERE id=v_add AND status='pending'
    AND amount=2*v_price AND addition_notes='QA addition note')
   OR NOT EXISTS(SELECT 1 FROM public.ff38_order_addition_items WHERE addition_id=v_add
    AND quantity=2 AND unit_price=v_price AND item_notes='بدون شطة') THEN RAISE EXCEPTION 'Addition item mismatch';END IF;
  PERFORM set_config('request.jwt.claim.sub',v_cashier::text,true);
  PERFORM public.ff49_cashier_receive(v_order);
  PERFORM public.ff49_cashier_invoice(v_order,NULL);
  PERFORM public.ff38_cashier_set_stage(v_order,'preparing');
  PERFORM public.ff38_cashier_set_stage(v_order,'ready');
  v_error:=NULL;
  BEGIN PERFORM public.ff38_cashier_set_stage(v_order,'handed_over');
  EXCEPTION WHEN SQLSTATE '23514' THEN v_error:=SQLERRM;END;
  IF v_error IS DISTINCT FROM 'لا يمكن تسليم الطلب للموصل: توجد إضافات بدون اعتماد فاتورة' THEN RAISE EXCEPTION 'Pending addition handover not blocked: %',v_error;END IF;
  PERFORM public.ff52_regular_addition_invoice(v_add,NULL);
  IF NOT EXISTS(SELECT 1 FROM public.ff52_addition_pos WHERE addition_id=v_add AND invoice_ref IS NULL AND recorded_by=v_cashier)
   OR NOT EXISTS(SELECT 1 FROM public.ff38_order_additions WHERE id=v_add AND status='invoiced') THEN RAISE EXCEPTION 'Addition invoice mismatch';END IF;
  PERFORM set_config('request.jwt.claim.sub',v_actor::text,true);
  PERFORM public.ff52_regular_addition_cancel(v_cancel,'QA cancellation reason');
  IF NOT EXISTS(SELECT 1 FROM public.ff38_order_additions WHERE id=v_cancel AND status='cancelled')
   OR NOT EXISTS(SELECT 1 FROM public.ff_audit_log WHERE entity_type='order_addition' AND entity_id=v_cancel::text
    AND action='order_addition_cancelled' AND details->>'reason'='QA cancellation reason') THEN RAISE EXCEPTION 'Cancellation audit mismatch';END IF;
  PERFORM set_config('request.jwt.claim.sub',v_cashier::text,true);
  PERFORM public.ff38_cashier_set_stage(v_order,'handed_over');
  PERFORM set_config('request.jwt.claim.sub',v_driver_user::text,true);
  PERFORM public.ff38_driver_progress(v_order,'on_way');
  PERFORM set_config('request.jwt.claim.sub',v_actor::text,true);
  FOR v_case IN SELECT value FROM jsonb_array_elements('[null,{},[],[{"item_name":"QA","quantity":"NaN","unit_price":100}],[{"item_name":"QA","quantity":1,"unit_price":"Infinity"}]]'::jsonb) LOOP
   v_error:=NULL;
   BEGIN
    PERFORM public.ff52_late_addition_create(v_order,v_case);
    RAISE EXCEPTION 'Unexpected invalid late addition';
   EXCEPTION WHEN SQLSTATE '22023' THEN v_error:=SQLSTATE;END;
   IF v_error IS DISTINCT FROM '22023' THEN RAISE EXCEPTION 'Invalid late addition was not rejected';END IF;
  END LOOP;
  v_late:=(public.ff52_late_addition_create(v_order,v_add_items)->>'addition_id')::uuid;
  IF NOT EXISTS(SELECT 1 FROM public.ff52_late_addition_consent WHERE addition_id=v_late AND state='awaiting_driver' AND driver_id=v_driver)
  THEN RAISE EXCEPTION 'Late addition consent missing';END IF;
  PERFORM set_config('request.jwt.claim.sub',v_driver_user::text,true);
  v_error:=NULL;
  BEGIN PERFORM public.ff38_driver_progress(v_order,'delivered');
  EXCEPTION WHEN OTHERS THEN v_error:=SQLERRM;END;
  IF v_error IS NULL OR v_error NOT LIKE '%إضافة%' AND v_error NOT LIKE '%إضافات%' THEN RAISE EXCEPTION 'Pending late addition did not block completion: %',v_error;END IF;
  PERFORM public.ff52_late_driver_decide(v_late,true,NULL);
  PERFORM set_config('request.jwt.claim.sub',v_cashier::text,true);
  PERFORM public.ff52_late_invoice(v_late,NULL);
  PERFORM set_config('request.jwt.claim.sub',v_driver_user::text,true);
  PERFORM public.ff52_late_driver_pickup(v_late);
  IF NOT EXISTS(SELECT 1 FROM public.ff52_late_addition_consent WHERE addition_id=v_late AND state='picked_up')
   OR NOT EXISTS(SELECT 1 FROM public.ff38_order_additions WHERE id=v_late AND status='invoiced') THEN RAISE EXCEPTION 'Late pickup mismatch';END IF;
  PERFORM public.ff38_driver_progress(v_order,'arrived');
  PERFORM public.ff38_driver_progress(v_order,'delivered');
  IF NOT EXISTS(SELECT 1 FROM public.ff_orders WHERE id=v_order AND status='delivered') THEN RAISE EXCEPTION 'Final delivery mismatch';END IF;
  RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;
 END;
 SELECT to_jsonb(p) INTO v_new_presence FROM public.ff38_driver_presence p WHERE driver_id=v_fixture_driver;
 IF v_new_presence IS DISTINCT FROM v_old_presence OR v_order IS NULL OR v_late IS NULL
  OR EXISTS(SELECT 1 FROM public.ff_orders WHERE id=v_order)
  OR EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE order_id=v_order)
  OR EXISTS(SELECT 1 FROM public.ff38_order_additions WHERE order_id=v_order)
  OR EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE order_id=v_order)
  OR EXISTS(SELECT 1 FROM public.ff70_atomic_requests WHERE request_id=v_request)
 THEN RAISE EXCEPTION 'Addition rollback failed';END IF;
 PERFORM set_config('request.jwt.claim.sub',coalesce(v_prior,''),true);
END $qa$;
SELECT 'PASS: actual offer/assignment, regular additions, handover blocked, invoice, cancellation audit, late addition consent/pickup, final delivery, complete rollback' AS result;
