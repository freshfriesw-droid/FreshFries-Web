-- A02 FIX-06 / FIX-07 / QA-26: real database creation for all three
-- branches, with an authenticated customer-service context, exact item price
-- and notes, idempotency, customer-contact audit, and mandatory rollback.
-- All writes (orders, dispatch, audit, push queue and atomic requests) happen
-- inside one exception subtransaction; the sentinel rolls them back before
-- commit. pg_net starts HTTP requests only after commit.
DO $qa$
DECLARE
 v_actor uuid; v_driver uuid; v_branch record; v_desk text;
 v_burger numeric; v_chicken numeric; v_fee numeric; v_expected numeric;
 v_input jsonb; v_request uuid; v_result jsonb; v_retry jsonb; v_order uuid;
 v_read jsonb; v_edit jsonb; v_count integer:=0; v_prior text; v_error text;
 v_ids uuid[]:=ARRAY[]::uuid[]; v_requests uuid[]:=ARRAY[]::uuid[];
BEGIN
 SELECT user_id INTO v_actor FROM public.ff_profiles WHERE active AND role='customer_service' LIMIT 1;
 SELECT user_id INTO v_driver FROM public.ff_profiles WHERE active AND role='driver' LIMIT 1;
 IF v_actor IS NULL OR v_driver IS NULL THEN RAISE EXCEPTION 'Required QA roles missing'; END IF;
 SELECT price INTO STRICT v_burger FROM public.ff_menu_items WHERE active AND name='سماش برجر دبل أسمر';
 SELECT price INTO STRICT v_chicken FROM public.ff_menu_items WHERE active AND name='تشكن فرايز';
 v_prior:=current_setting('request.jwt.claim.sub',true);
 PERFORM set_config('request.jwt.claim.sub',v_actor::text,true);
 PERFORM set_config('lock_timeout','3s',true);
 IF NOT public.ff38_permission_allowed(v_actor,'create_order') OR NOT public.ff38_permission_allowed(v_actor,'edit_order') THEN
  RAISE EXCEPTION 'Customer-service context lacks approved permissions';
 END IF;
 BEGIN
  FOR v_branch IN SELECT id,code FROM public.ff_branches WHERE active AND code IN ('cairo','sam_mall','khamseen') ORDER BY code LOOP
   SELECT code INTO v_desk FROM public.ff_luxe_cashier_desks WHERE active AND branch_id=v_branch.id ORDER BY code LIMIT 1;
   v_request:=gen_random_uuid();
   v_requests:=array_append(v_requests,v_request);
   v_fee:=CASE WHEN v_branch.code='cairo' THEN 0 ELSE 500 END;
   v_expected:=3*v_burger+v_chicken+v_fee;
   v_input:=jsonb_build_object('p_branch',v_branch.id,'p_desk',v_desk,
    'p_phone','700000000','p_area','QA area','p_customer_name','QA customer','p_channel','phone',
    'p_full_address','QA address','p_delivery_fee',v_fee,'p_notes','A02_ROLLBACK_20261124',
    'p_items',jsonb_build_array(
      jsonb_build_object('name','سماش برجر دبل أسمر','qty',3,'price',v_burger,'item_notes','بدون شطة'),
      jsonb_build_object('name','تشكن فرايز','qty',1,'price',v_chicken,'item_notes','QA note')));
   v_result:=public.ff27_submit(v_request,'delivery',v_input);
   v_order:=(v_result->>'order_id')::uuid;
   v_ids:=array_append(v_ids,v_order);
   IF NOT EXISTS(SELECT 1 FROM public.ff_orders WHERE id=v_order AND branch_id=v_branch.id AND created_by=v_actor
    AND delivery_fee=v_fee AND items_total=v_expected-v_fee AND total=v_expected AND phone_snapshot='700000000') THEN
    RAISE EXCEPTION 'Order header mismatch: %',v_branch.code; END IF;
   IF (SELECT count(*) FROM public.ff_order_items WHERE order_id=v_order)<>2
    OR NOT EXISTS(SELECT 1 FROM public.ff_order_items WHERE order_id=v_order AND item_name='سماش برجر دبل أسمر'
     AND quantity=3 AND unit_price=v_burger AND line_total=3*v_burger AND item_notes='بدون شطة')
    OR NOT EXISTS(SELECT 1 FROM public.ff_order_items WHERE order_id=v_order AND item_name='تشكن فرايز'
     AND quantity=1 AND unit_price=v_chicken AND line_total=v_chicken AND item_notes='QA note') THEN
    RAISE EXCEPTION 'Item persistence mismatch: %',v_branch.code; END IF;
   IF NOT EXISTS(SELECT 1 FROM public.ff49_order_details WHERE order_id=v_order AND customer_name='QA customer'
     AND full_address='QA address' AND channel='phone') THEN RAISE EXCEPTION 'Customer details mismatch'; END IF;
   IF v_desk IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.ff_luxe_cashier_order_desks WHERE order_id=v_order AND desk_code=v_desk) THEN
    RAISE EXCEPTION 'Desk mismatch: %',v_branch.code; END IF;
   v_retry:=public.ff27_submit(v_request,'delivery',v_input);
   IF v_retry IS DISTINCT FROM v_result THEN RAISE EXCEPTION 'Idempotency mismatch'; END IF;
   v_error:=NULL;
   BEGIN
    PERFORM public.ff27_submit(v_request,'delivery',v_input||'{"p_delivery_fee":900}'::jsonb);
   EXCEPTION WHEN OTHERS THEN v_error:=SQLERRM; END;
   IF v_error IS DISTINCT FROM 'المعرّف مستخدم لطلب بمحتوى مختلف' THEN RAISE EXCEPTION 'Different payload was not rejected'; END IF;
   v_read:=public.ff_order_customer_read(v_order);
   IF v_read->>'phone' IS DISTINCT FROM '700000000' THEN RAISE EXCEPTION 'Customer read mismatch'; END IF;
   v_edit:=public.ff_order_customer_edit(v_order,'700000001','QA new area','QA edited','QA new address','QA correction');
   IF NOT EXISTS(SELECT 1 FROM public.ff_order_customer_edits WHERE id=(v_edit->>'edit_id')::uuid AND order_id=v_order
     AND old_values->>'phone'='700000000' AND new_values->>'phone'='700000001' AND reason='QA correction') THEN
    RAISE EXCEPTION 'Before/after audit mismatch'; END IF;
   v_read:=public.ff_order_customer_read(v_order);
   IF v_read->>'phone' IS DISTINCT FROM '700000001' OR v_read->>'address' IS DISTINCT FROM 'QA new address' THEN
    RAISE EXCEPTION 'Customer update mismatch'; END IF;
   PERFORM set_config('request.jwt.claim.sub',v_driver::text,true);
   v_error:=NULL;
   BEGIN
    PERFORM public.ff_order_customer_read(v_order);
   EXCEPTION WHEN SQLSTATE '42501' THEN v_error:=SQLSTATE; END;
   IF v_error IS DISTINCT FROM '42501' THEN RAISE EXCEPTION 'Driver could access edit-only customer details'; END IF;
   PERFORM set_config('request.jwt.claim.sub',v_actor::text,true);
   v_count:=v_count+1;
  END LOOP;
  IF v_count<>3 THEN RAISE EXCEPTION 'Expected three active branches, got %',v_count; END IF;
  RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN
  NULL;
 END;
 IF v_count<>3 OR cardinality(v_ids)<>3 THEN RAISE EXCEPTION 'Incomplete QA'; END IF;
 IF EXISTS(SELECT 1 FROM public.ff_orders WHERE id=ANY(v_ids))
  OR EXISTS(SELECT 1 FROM public.ff_order_items WHERE order_id=ANY(v_ids))
  OR EXISTS(SELECT 1 FROM public.ff49_order_details WHERE order_id=ANY(v_ids))
  OR EXISTS(SELECT 1 FROM public.ff_order_customer_edits WHERE order_id=ANY(v_ids))
  OR EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE order_id=ANY(v_ids))
  OR EXISTS(SELECT 1 FROM public.ff70_atomic_requests WHERE request_id=ANY(v_requests))
 THEN RAISE EXCEPTION 'QA rollback failed'; END IF;
 PERFORM set_config('request.jwt.claim.sub',coalesce(v_prior,''),true);
END $qa$;
SELECT 'PASS: 3 branches, order/items/notes/prices, desk, idempotency, customer edit audit, unauthorized driver blocked, complete rollback' AS result;
