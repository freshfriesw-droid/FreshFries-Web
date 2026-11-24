-- FIX-07: actual server-side snapshot visibility and targeted push queue.
-- All fixture writes are rolled back; no external notification is dispatched.
DO $qa$
DECLARE
 v_cs uuid;v_manager uuid;v_driver uuid;v_driver_user uuid;v_other_driver_user uuid;
 v_cairo uuid;v_order uuid;v_offer uuid;v_fixture_driver uuid;
 v_price numeric;v_input jsonb;v_result jsonb;v_before jsonb;v_after jsonb;v_snapshot jsonb;
 v_edit uuid;v_req uuid:=gen_random_uuid();v_prev text;v_count int;
 v_presence_before jsonb;v_presence_after jsonb;v_key text;
BEGIN
 SELECT id INTO STRICT v_cairo FROM public.ff_branches WHERE code='cairo' AND active;
 SELECT user_id INTO STRICT v_cs FROM public.ff_profiles WHERE role='customer_service' AND active LIMIT 1;
 SELECT user_id INTO STRICT v_manager FROM public.ff_profiles WHERE role='manager' AND active LIMIT 1;
 SELECT d.id,l.user_id INTO v_driver,v_driver_user FROM public.ff_drivers d JOIN public.ff38_driver_links l ON l.driver_id=d.id
 JOIN public.ff_profiles f ON f.user_id=l.user_id JOIN public.ff38_driver_presence pr ON pr.driver_id=d.id
 WHERE d.branch_id=v_cairo AND d.active AND f.active AND f.role='driver'
 AND NOT EXISTS(SELECT 1 FROM public.ff38_delivery_tasks t WHERE t.driver_id=d.id AND t.delivered_at IS NULL)
 AND NOT EXISTS(SELECT 1 FROM ff_private.automatic_dispatch_exclusions e WHERE e.branch_id=v_cairo AND e.driver_id=d.id)
 ORDER BY d.id LIMIT 1;

 IF v_driver IS NULL THEN RAISE EXCEPTION 'Available Cairo QA driver role missing'; END IF;
 v_fixture_driver:=v_driver;
 SELECT to_jsonb(p) INTO v_presence_before FROM public.ff38_driver_presence p WHERE driver_id=v_fixture_driver;
 SELECT price INTO STRICT v_price FROM public.ff_menu_items WHERE active AND name='تشكن فرايز';
 v_input:=jsonb_build_object('p_branch',v_cairo,'p_phone','700000000','p_area','QA area',
 'p_items',jsonb_build_array(jsonb_build_object('name','تشكن فرايز','qty',1,'price',v_price,'item_notes','')),
 'p_delivery_fee',0,'p_customer_name','QA customer','p_channel','phone','p_full_address','QA address','p_notes','A02_CONTACT_SYNC_ROLLBACK');
 v_prev:=current_setting('request.jwt.claim.sub',true);
 PERFORM set_config('lock_timeout','3s',true);
 BEGIN
  PERFORM set_config('request.jwt.claim.sub',v_manager::text,true);
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

  SELECT t.driver_id,l.user_id INTO STRICT v_driver,v_driver_user FROM public.ff38_delivery_tasks t
  JOIN public.ff38_driver_links l ON l.driver_id=t.driver_id
  JOIN public.ff_profiles f ON f.user_id=l.user_id AND f.active AND f.role='driver'
  WHERE t.order_id=v_order;
  SELECT p.user_id INTO STRICT v_other_driver_user FROM public.ff_profiles p
  JOIN public.ff38_driver_links l ON l.user_id=p.user_id
  WHERE p.active AND p.role='driver' AND l.driver_id<>v_driver LIMIT 1;
  PERFORM set_config('request.jwt.claim.sub',v_driver_user::text,true);
  SET LOCAL ROLE authenticated;
  v_snapshot:=public.ff49_snapshot();
  SELECT x INTO STRICT v_before FROM jsonb_array_elements(v_snapshot->'orders') x WHERE x->>'id'=v_order::text;
  IF v_before->>'phone'<>'700000000' OR v_before->>'full_address'<>'QA address'
   OR v_before->>'customer_update' IS NOT NULL THEN RAISE EXCEPTION 'Initial driver snapshot mismatch'; END IF;
  PERFORM set_config('request.jwt.claim.sub',v_cs::text,true);
  v_result:=public.ff_order_customer_edit_with_note(v_order,'700000001','QA corrected area','QA corrected name','QA corrected address','QA contact correction','QA private contact note');
  v_edit:=(v_result->>'edit_id')::uuid;
  IF v_edit IS NULL OR NOT coalesce((v_result->>'note_saved')::boolean,false) THEN RAISE EXCEPTION 'Edit/note response invalid'; END IF;
  PERFORM set_config('request.jwt.claim.sub',v_driver_user::text,true);
  v_snapshot:=public.ff49_snapshot();
  SELECT x INTO STRICT v_after FROM jsonb_array_elements(v_snapshot->'orders') x WHERE x->>'id'=v_order::text;
  IF v_after->>'phone'<>'700000001' OR v_after->>'full_address'<>'QA corrected address'
   OR v_after->>'customer_name'<>'QA corrected name' OR v_after->'customer_update'->>'at' IS NULL
   OR NOT (v_after->'customer_update'->'fields' @> '["phone","area","name","address"]'::jsonb)
   OR (v_after->>'status',v_after->>'phase',v_after->>'total') IS DISTINCT FROM (v_before->>'status',v_before->>'phase',v_before->>'total')
   OR v_after::text LIKE '%QA private contact note%' THEN RAISE EXCEPTION 'Updated assigned-driver snapshot mismatch'; END IF;
  PERFORM set_config('request.jwt.claim.sub',v_other_driver_user::text,true);
  v_snapshot:=public.ff49_snapshot();
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_snapshot->'orders') x WHERE x->>'id'=v_order::text)
   THEN RAISE EXCEPTION 'Unassigned driver sees corrected order'; END IF;
  PERFORM set_config('request.jwt.claim.sub',v_cs::text,true);
  v_result:=public.ff_order_customer_edit(v_order,'700000001','QA corrected area','QA corrected name','QA corrected address','QA no-op');
  IF NOT coalesce((v_result->>'unchanged')::boolean,false) THEN RAISE EXCEPTION 'No-op did not remain unchanged'; END IF;
  RESET ROLE;
  v_key:='customer-edit:'||v_edit::text;
  IF (SELECT count(*) FROM public.ff_order_customer_edits WHERE order_id=v_order)<>1
   OR NOT EXISTS(SELECT 1 FROM public.ff_order_customer_edits WHERE id=v_edit AND actor_id=v_cs AND old_values->>'phone'='700000000' AND new_values->>'phone'='700000001')
   OR NOT EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE order_id=v_order AND event_key=v_key AND user_id=v_driver_user AND kind='employee_notice')
   OR EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE order_id=v_order AND event_key LIKE 'customer-edit:%' AND user_id<>v_driver_user)
   OR (SELECT count(*) FROM public.ff_push_jobs WHERE order_id=v_order AND event_key LIKE 'customer-edit:%')<>1
   OR EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE order_id=v_order AND event_key=v_key AND (body LIKE '%700000001%' OR body LIKE '%QA private contact note%'))
   THEN RAISE EXCEPTION 'Audit, targeted push, duplicate/no-op or private body check failed';END IF;
  RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 SELECT to_jsonb(p) INTO v_presence_after FROM public.ff38_driver_presence p WHERE driver_id=v_fixture_driver;
 IF v_order IS NULL OR v_edit IS NULL OR v_presence_after IS DISTINCT FROM v_presence_before
  OR EXISTS(SELECT 1 FROM public.ff_orders WHERE id=v_order)
  OR EXISTS(SELECT 1 FROM public.ff_order_customer_edits WHERE id=v_edit)
  OR EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE order_id=v_order)
  OR EXISTS(SELECT 1 FROM public.ff70_atomic_requests WHERE request_id=v_req)
  OR EXISTS(SELECT 1 FROM public.ff51_customer_notes WHERE note='QA private contact note')
 THEN RAISE EXCEPTION 'Rollback verification failed'; END IF;
 PERFORM set_config('request.jwt.claim.sub',coalesce(v_prev,''),true);
END $qa$;
SELECT 'PASS FIX-07: actual authenticated-role snapshots before/after; assigned-driver targeting, unrelated driver denial, audit, no-op deduplication, private-note isolation, rollback' AS result;
