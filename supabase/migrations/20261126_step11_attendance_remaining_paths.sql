-- STEP11: direct pinned dispatch must respect actual attendance; avoid clock-in/order lock inversion.
DO $migration$
DECLARE d text; a text; z text;
BEGIN
 d:=pg_get_functiondef('public.ff62_assign_pinned(uuid)'::regprocedure);
 a:=$s$ SELECT * INTO o FROM public.ff_orders WHERE id=p_order FOR UPDATE;$s$;
 z:=$s$ PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-o-'||p_order::text));
 SELECT * INTO o FROM public.ff_orders WHERE id=p_order FOR UPDATE;$s$;
 IF (length(d)-length(replace(d,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'Pinned order lock anchor';END IF;d:=replace(d,a,z);
 a:=$s$ SELECT driver_id INTO d FROM public.ff62_pinned_drivers WHERE branch_id=o.branch_id;$s$;
 z:=$s$ PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-branch-rr-'||o.branch_id::text));
 SELECT driver_id INTO d FROM public.ff62_pinned_drivers WHERE branch_id=o.branch_id;$s$;
 IF (length(d)-length(replace(d,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'Pinned branch lock anchor';END IF;d:=replace(d,a,z);
 a:=$s$ IF o.driver_id IS NOT NULL OR EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE order_id=p_order) THEN RAISE EXCEPTION 'الطلب مسند بالفعل'; END IF;$s$;
 z:=$s$ PERFORM 1 FROM public.ff38_driver_presence p WHERE p.driver_id=d AND p.state IN ('ready','busy') AND p.checked_in_at IS NOT NULL AND p.checked_out_at IS NULL AND p.last_seen_at>clock_timestamp()-interval '90 seconds' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'الموصل المثبت غير حاضر أو غير متصل';END IF;
 IF o.driver_id IS NOT NULL OR EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE order_id=p_order) THEN RAISE EXCEPTION 'الطلب مسند بالفعل'; END IF;$s$;
 IF (length(d)-length(replace(d,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'Pinned eligibility anchor';END IF;d:=replace(d,a,z);
 a:=$s$ RETURN jsonb_build_object('state','assigned_pinned','driver_id',d,'order_id',p_order,'delivery_fee',0);$s$;
 z:=$s$ UPDATE public.ff38_driver_presence SET state='busy',updated_at=clock_timestamp() WHERE driver_id=d;
 RETURN jsonb_build_object('state','assigned_pinned','driver_id',d,'order_id',p_order,'delivery_fee',0);$s$;
 IF (length(d)-length(replace(d,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'Pinned completion anchor';END IF;EXECUTE replace(d,a,z);
 d:=pg_get_functiondef('public.ff38_clock_in()'::regprocedure);
 a:=$s$LOOP PERFORM public.ff38__offer_next(v_order); END LOOP;$s$;
 z:=$s$LOOP
 -- We already own a presence row lock; never wait on an order/branch lock
 -- held by a dispatcher that may be waiting for this same presence row.
 IF pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtext('ff38-o-'||v_order::text))
 AND pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtext('ff38-branch-rr-'||(SELECT branch_id FROM public.ff_drivers WHERE id=v_driver)::text)) THEN
 PERFORM 1 FROM public.ff_orders WHERE id=v_order FOR UPDATE SKIP LOCKED;
 IF FOUND THEN PERFORM public.ff38__offer_next(v_order);END IF;
 END IF;
 END LOOP;$s$;
 IF (length(d)-length(replace(d,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'Clock-in sweep anchor';END IF;EXECUTE replace(d,a,z);
END $migration$;
