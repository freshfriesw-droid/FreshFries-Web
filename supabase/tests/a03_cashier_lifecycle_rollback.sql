-- Isolated complete cashier/courier lifecycle, optional invoice and terminal protection.
DO $qa$
DECLARE b uuid:=gen_random_uuid(); foreign_b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); other uuid:=gen_random_uuid(); mgr uuid:=gen_random_uuid();
 d uuid:=gen_random_uuid(); d2 uuid:=gen_random_uuid(); o uuid:=gen_random_uuid(); cancelled uuid:=gen_random_uuid(); ref_order uuid:=gen_random_uuid(); oid uuid;
 f uuid; r jsonb; rejected boolean; stage text; phase text; passes int:=0; bad text;
BEGIN
 BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-'||b,'QA lifecycle'),(foreign_b,'qa-'||foreign_b,'QA foreign');
 INSERT INTO auth.users(id) VALUES(c),(u),(other),(mgr);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(c,'QA cashier','cashier',true),(u,'QA driver','driver',true),(other,'QA foreign driver','driver',true),(mgr,'QA manager','manager',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c,b);
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d,'QA driver',b),(d2,'QA other',foreign_b);
 INSERT INTO public.ff38_driver_links(user_id,driver_id) VALUES(u,d),(other,d2);
 INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d,'ready',now(),now()),(d2,'ready',now(),now()) ON CONFLICT(driver_id) DO UPDATE SET state='ready',checked_in_at=now(),last_seen_at=now();
 FOREACH oid IN ARRAY ARRAY[o,cancelled,ref_order] LOOP
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot) VALUES(oid,-(1+floor(random()*1e12)::bigint),b,'000000000',public.ff_business_date(now()),'QA');
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',mgr::text,true);
 r:=public.ff38_dispatch(o,d);f:=(r->>'offer_id')::uuid;
 IF f IS NULL THEN RAISE EXCEPTION 'Missing offer';END IF;
 PERFORM set_config('request.jwt.claim.sub',u::text,true);
 SET LOCAL ROLE authenticated;
 r:=public.ff38_driver_reply(f,true,null);
 IF r->>'state'<>'accepted' THEN RAISE EXCEPTION 'Accept failed';END IF;passes:=passes+1;
 rejected:=false;
 BEGIN PERFORM public.ff38_driver_progress(o,'on_way'); EXCEPTION WHEN raise_exception THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'Departure before handover accepted';END IF;passes:=passes+1;
 PERFORM set_config('request.jwt.claim.sub',other::text,true);
 rejected:=false;
 BEGIN PERFORM public.ff38_driver_progress(o,'on_way'); EXCEPTION WHEN raise_exception THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'Foreign driver progress accepted';END IF;passes:=passes+1;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);
 rejected:=false;
 BEGIN PERFORM public.ff49_cashier_invoice(o,NULL);EXCEPTION WHEN raise_exception THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'Invoice before receive accepted';END IF;passes:=passes+1;
 PERFORM public.ff49_cashier_receive(o);
 PERFORM public.ff49_cashier_receive(o);
 rejected:=false;
 BEGIN PERFORM public.ff38_cashier_set_stage(o,'printed');EXCEPTION WHEN SQLSTATE '23514' THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'Print without invoice confirmation accepted';END IF;passes:=passes+1;
 PERFORM public.ff49_cashier_invoice(o,NULL);passes:=passes+1;
 rejected:=false;
 BEGIN PERFORM public.ff38_cashier_set_stage(o,'ready');EXCEPTION WHEN raise_exception THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'Skipped preparing';END IF;passes:=passes+1;
 FOREACH stage IN ARRAY ARRAY['preparing','ready','handed_over'] LOOP
 PERFORM public.ff38_cashier_set_stage(o,stage);
 END LOOP;
 rejected:=false;
 BEGIN PERFORM public.ff38_cashier_set_stage(o,'handed_over');EXCEPTION WHEN raise_exception THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'Repeated handover accepted';END IF;passes:=passes+1;
 PERFORM set_config('request.jwt.claim.sub',u::text,true);
 FOREACH phase IN ARRAY ARRAY['on_way','arrived','delivered'] LOOP
 PERFORM public.ff38_driver_progress(o,phase);
 END LOOP;passes:=passes+1;
 rejected:=false;
 BEGIN PERFORM public.ff38_driver_progress(o,'delivered');EXCEPTION WHEN raise_exception THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'Repeated completion accepted';END IF;passes:=passes+1;
 RESET ROLE;
 IF NOT EXISTS(SELECT 1 FROM public.ff_orders WHERE id=o AND status='delivered' AND delivered_at IS NOT NULL)
 OR NOT EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE order_id=o AND phase='delivered' AND cashier_stage='handed_over' AND picked_up_at IS NOT NULL AND arrived_at IS NOT NULL AND delivered_at IS NOT NULL)
 OR (SELECT count(*) FROM public.ff49_cashier_receipts WHERE order_id=o AND invoice_ref IS NULL AND invoiced_at IS NOT NULL AND received_by=c AND invoiced_by=c)<>1
 OR (SELECT count(*) FROM public.ff60_workflow_events WHERE order_id=o AND event_type='cashier' AND actor_id=c)<>4
 OR (SELECT count(*) FROM public.ff60_workflow_events WHERE order_id=o AND event_type='courier' AND actor_id=u)<>3 THEN RAISE EXCEPTION 'Lifecycle/audit mismatch';END IF;passes:=passes+1;
 -- A completion sweep might already have offered a queued fixture. Clear only synthetic offers.
 UPDATE public.ff38_dispatch_offers SET status='expired' WHERE order_id IN(cancelled,ref_order) AND status='offered';
 UPDATE public.ff_orders SET driver_id=d,status='sent' WHERE id IN(cancelled,ref_order);
 INSERT INTO public.ff38_delivery_tasks(order_id,driver_id) VALUES(cancelled,d),(ref_order,d);
 UPDATE public.ff_orders SET status='cancelled' WHERE id=cancelled;
 UPDATE public.ff38_delivery_tasks SET delivered_at=now() WHERE order_id=cancelled;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);
 SET LOCAL ROLE authenticated;
 rejected:=false;
 BEGIN PERFORM public.ff49_cashier_receive(cancelled);EXCEPTION WHEN raise_exception THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'Cancelled order received';END IF;passes:=passes+1;
 PERFORM public.ff49_cashier_receive(ref_order);
 PERFORM public.ff49_cashier_invoice(ref_order,'QA-12345');
 RESET ROLE;
 IF EXISTS(SELECT 1 FROM public.ff49_cashier_receipts WHERE order_id=cancelled)
 OR NOT EXISTS(SELECT 1 FROM public.ff49_cashier_receipts WHERE order_id=ref_order AND invoice_ref='QA-12345' AND invoiced_by=c) THEN RAISE EXCEPTION 'Cancelled/reference receipt mismatch';END IF;passes:=passes+1;
 RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF passes<>13 OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id IN(b,foreign_b)) OR EXISTS(SELECT 1 FROM auth.users WHERE id IN(c,u,other,mgr)) OR EXISTS(SELECT 1 FROM public.ff_orders WHERE id IN(o,cancelled,ref_order)) THEN RAISE EXCEPTION 'Incomplete QA or rollback: %',passes;END IF;
END $qa$;
SELECT 'PASS A03: 13 cashier/courier lifecycle checks, optional invoice, reference, sequence, replay, cancellation, actor audit; rollback' AS result;
