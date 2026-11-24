-- QA-03: edit/cancel lifecycle with real role contexts and transactional rollback.
DO $qa$
DECLARE
 v_cs uuid;v_manager uuid;v_cashier uuid;v_other_cashier uuid;v_driver uuid;v_driver_user uuid;
 v_cairo uuid;v_khamseen uuid;v_order uuid;v_cancel_order uuid;v_change uuid;v_offer uuid;
 v_price numeric;v_items jsonb;v_new_items jsonb;v_input jsonb;v_result jsonb;
 v_req uuid:=gen_random_uuid();v_cancel_req uuid:=gen_random_uuid();v_msg text;v_prev text;
 v_presence_before jsonb;v_presence_after jsonb;v_fixture_driver uuid;
 v_permissions_before jsonb;v_permissions_after jsonb;
BEGIN
 SELECT id INTO STRICT v_cairo FROM public.ff_branches WHERE code='cairo' AND active;
 SELECT id INTO STRICT v_khamseen FROM public.ff_branches WHERE code='khamseen' AND active;
 SELECT user_id INTO v_cs FROM public.ff_profiles WHERE role='customer_service' AND active LIMIT 1;
 SELECT user_id INTO v_manager FROM public.ff_profiles WHERE role='manager' AND active LIMIT 1;
 SELECT f.user_id INTO v_cashier FROM public.ff_profiles f JOIN public.ff_user_branches u ON u.user_id=f.user_id
 WHERE f.role='cashier' AND f.active AND u.branch_id=v_cairo LIMIT 1;
 SELECT f.user_id INTO v_other_cashier FROM public.ff_profiles f WHERE f.role='cashier' AND f.active
 AND NOT EXISTS(SELECT 1 FROM public.ff_user_branches u WHERE u.user_id=f.user_id AND u.branch_id=v_cairo)
 AND NOT EXISTS(SELECT 1 FROM public.ff_user_branches u WHERE u.user_id=f.user_id AND u.branch_id=v_khamseen) LIMIT 1;
 SELECT d.id,l.user_id INTO v_driver,v_driver_user FROM public.ff_drivers d JOIN public.ff38_driver_links l ON l.driver_id=d.id
 JOIN public.ff_profiles f ON f.user_id=l.user_id JOIN public.ff38_driver_presence pr ON pr.driver_id=d.id
 WHERE d.branch_id=v_cairo AND d.active AND f.active AND f.role='driver'
 AND NOT EXISTS(SELECT 1 FROM public.ff38_delivery_tasks t WHERE t.driver_id=d.id AND t.delivered_at IS NULL)
 AND NOT EXISTS(SELECT 1 FROM ff_private.automatic_dispatch_exclusions e WHERE e.branch_id=v_cairo AND e.driver_id=d.id)
 ORDER BY d.id LIMIT 1;
 IF v_cs IS NULL OR v_manager IS NULL OR v_cashier IS NULL OR v_other_cashier IS NULL OR v_driver IS NULL
 THEN RAISE EXCEPTION 'QA role contexts unavailable';END IF;
 v_fixture_driver:=v_driver;
 SELECT to_jsonb(p) INTO v_presence_before FROM public.ff38_driver_presence p WHERE driver_id=v_fixture_driver;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY permission_key),'[]'::jsonb) INTO v_permissions_before
 FROM public.ff38_staff_permission_overrides x WHERE user_id=v_other_cashier;
 SELECT price INTO STRICT v_price FROM public.ff_menu_items WHERE active AND name='تشكن فرايز';
 v_items:=jsonb_build_array(jsonb_build_object('name','تشكن فرايز','qty',1,'price',v_price,'item_notes','بدون شطة'));
 v_new_items:=jsonb_build_array(jsonb_build_object('name','تشكن فرايز','qty',2,'price',v_price,'item_notes','بدون شطة'));
 v_input:=jsonb_build_object('p_branch',v_cairo,'p_phone','700000000','p_area','QA area','p_items',v_items,
 'p_delivery_fee',500,'p_customer_name','QA customer','p_channel','phone','p_full_address','QA address','p_notes','A02_EDIT_CANCEL_ROLLBACK');
 v_prev:=current_setting('request.jwt.claim.sub',true);
 PERFORM set_config('lock_timeout','3s',true);
 BEGIN
  PERFORM set_config('request.jwt.claim.sub',v_manager::text,true);
  INSERT INTO public.ff38_staff_permission_overrides(user_id,permission_key,allowed,updated_by)
   VALUES(v_other_cashier,'edit_order',true,v_manager),(v_other_cashier,'cancel_order',true,v_manager)
   ON CONFLICT(user_id,permission_key) DO UPDATE SET allowed=true,updated_by=EXCLUDED.updated_by,updated_at=now();
  UPDATE public.ff38_driver_presence SET state='ready',checked_in_at=coalesce(checked_in_at,now()),checked_out_at=NULL,last_seen_at=now()
  WHERE driver_id=v_fixture_driver;
  PERFORM set_config('request.jwt.claim.sub',v_cs::text,true);
  v_result:=public.ff27_submit(v_req,'delivery',v_input);v_order:=(v_result->>'order_id')::uuid;
  IF NOT EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE order_id=v_order) THEN
   SELECT id,driver_id INTO v_offer,v_driver FROM public.ff38_dispatch_offers WHERE order_id=v_order AND status='offered' LIMIT 1;
   IF v_offer IS NULL THEN RAISE EXCEPTION 'Offer fixture missing';END IF;
   SELECT l.user_id INTO STRICT v_driver_user FROM public.ff38_driver_links l JOIN public.ff_profiles f ON f.user_id=l.user_id
   WHERE l.driver_id=v_driver AND f.active AND f.role='driver';
   PERFORM set_config('request.jwt.claim.sub',v_driver_user::text,true);
   PERFORM public.ff38_driver_reply(v_offer,true,NULL);
  END IF;
  PERFORM set_config('request.jwt.claim.sub',v_other_cashier::text,true);
  v_msg:=NULL;
  BEGIN PERFORM public.ff50_change_request(v_order,v_new_items,'QA edit reason');
  EXCEPTION WHEN SQLSTATE '42501' THEN v_msg:=SQLERRM;END;
  IF v_msg IS DISTINCT FROM 'الفرع غير مصرح' THEN RAISE EXCEPTION 'Cross-branch edit bypass: %',v_msg;END IF;
  PERFORM set_config('request.jwt.claim.sub',v_cs::text,true);
  v_msg:=NULL;
  BEGIN PERFORM public.ff50_change_request(v_order,jsonb_set(v_new_items,'{0,price}','1.001'),'QA edit reason');
  EXCEPTION WHEN SQLSTATE '22023' THEN v_msg:=SQLSTATE;END;
  IF v_msg IS DISTINCT FROM '22023' THEN RAISE EXCEPTION 'Precision guard missing';END IF;
  v_change:=(public.ff50_change_request(v_order,v_new_items,'QA edit reason')->>'change_id')::uuid;
  IF NOT EXISTS(SELECT 1 FROM public.ff50_order_changes WHERE id=v_change
    AND old_items @> '[{"item_notes":"بدون شطة","qty":1}]'::jsonb AND new_items @> '[{"item_notes":"بدون شطة","qty":2}]'::jsonb)
  THEN RAISE EXCEPTION 'Before/after note snapshot mismatch';END IF;
  PERFORM set_config('request.jwt.claim.sub',v_cashier::text,true);
  PERFORM public.ff49_cashier_receive(v_order);PERFORM public.ff49_cashier_invoice(v_order,NULL);
  PERFORM public.ff50_change_cashier_decide(v_change,true,'QA approved');
  PERFORM set_config('request.jwt.claim.sub',v_other_cashier::text,true);
  v_msg:=NULL;
  BEGIN PERFORM public.ff50_change_service_confirm(v_change);EXCEPTION WHEN SQLSTATE '42501' THEN v_msg:=SQLERRM;END;
  IF v_msg IS DISTINCT FROM 'الفرع غير مصرح' THEN RAISE EXCEPTION 'Cross-branch confirm bypass: %',v_msg;END IF;
  PERFORM set_config('request.jwt.claim.sub',v_cs::text,true);
  PERFORM public.ff50_change_service_confirm(v_change);
  PERFORM set_config('request.jwt.claim.sub',v_cashier::text,true);
  PERFORM public.ff50_change_cashier_confirm_pos(v_change,NULL);
  IF NOT EXISTS(SELECT 1 FROM public.ff_order_items WHERE order_id=v_order AND quantity=2 AND unit_price=v_price AND item_notes='بدون شطة')
   OR NOT EXISTS(SELECT 1 FROM public.ff_orders WHERE id=v_order AND items_total=2*v_price AND total=2*v_price+500)
   OR NOT EXISTS(SELECT 1 FROM public.ff50_order_changes WHERE id=v_change AND status='completed')
   OR (SELECT count(*) FROM public.ff50_order_change_events WHERE change_id=v_change)<>4
  THEN RAISE EXCEPTION 'Committed edit mismatch';END IF;
  PERFORM set_config('request.jwt.claim.sub',v_cs::text,true);
  PERFORM public.ff_luxe_cancel_assigned(v_order,'QA assigned cancellation');
  v_msg:=NULL;
  BEGIN PERFORM public.ff50_change_request(v_order,v_new_items,'QA closed edit');EXCEPTION WHEN OTHERS THEN v_msg:=SQLERRM;END;
  IF v_msg IS DISTINCT FROM 'لا يمكن تعديل طلب غادر مع الموصل أو لم يتم إسناده' THEN RAISE EXCEPTION 'Closed edit not blocked: %',v_msg;END IF;
  v_cancel_order:=(public.ff27_submit(v_cancel_req,'delivery',v_input||jsonb_build_object('p_branch',v_khamseen))->>'order_id')::uuid;
  IF EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE order_id=v_cancel_order) THEN RAISE EXCEPTION 'Unassigned fixture unexpectedly assigned';END IF;
  PERFORM set_config('request.jwt.claim.sub',v_other_cashier::text,true);
  v_msg:=NULL;
  BEGIN PERFORM public.ff38_cancel_unassigned_order(v_cancel_order,'QA wrong branch');EXCEPTION WHEN SQLSTATE '42501' THEN v_msg:=SQLERRM;END;
  IF v_msg IS DISTINCT FROM 'الفرع غير مصرح' THEN RAISE EXCEPTION 'Cross-branch cancellation bypass: %',v_msg;END IF;
  PERFORM set_config('request.jwt.claim.sub',v_cs::text,true);
  PERFORM public.ff38_cancel_unassigned_order(v_cancel_order,'QA unassigned cancellation');
  IF (SELECT count(*) FROM public.ff_orders WHERE id IN(v_order,v_cancel_order) AND status='cancelled')<>2
   OR (SELECT count(*) FROM public.ff38_order_cancellation_audit WHERE order_id IN(v_order,v_cancel_order))<>2
   THEN RAISE EXCEPTION 'Cancellation audit mismatch';END IF;
  RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 SELECT to_jsonb(p) INTO v_presence_after FROM public.ff38_driver_presence p WHERE driver_id=v_fixture_driver;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY permission_key),'[]'::jsonb) INTO v_permissions_after
 FROM public.ff38_staff_permission_overrides x WHERE user_id=v_other_cashier;
 IF v_order IS NULL OR v_cancel_order IS NULL OR v_change IS NULL OR v_presence_after IS DISTINCT FROM v_presence_before
 OR v_permissions_after IS DISTINCT FROM v_permissions_before
 OR EXISTS(SELECT 1 FROM public.ff_orders WHERE id IN(v_order,v_cancel_order))
 OR EXISTS(SELECT 1 FROM public.ff50_order_changes WHERE id=v_change)
 OR EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE order_id IN(v_order,v_cancel_order))
 OR EXISTS(SELECT 1 FROM public.ff70_atomic_requests WHERE request_id IN(v_req,v_cancel_req))
 THEN RAISE EXCEPTION 'Rollback failed';END IF;
 PERFORM set_config('request.jwt.claim.sub',coalesce(v_prev,''),true);
END $qa$;
SELECT 'PASS: item edit note snapshots and persistence, price precision, cross-branch edit/confirm/cancel denied, assigned/unassigned cancel, terminal order blocked, rollback' AS result;
