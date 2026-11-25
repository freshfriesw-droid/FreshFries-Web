-- Test-only snapshot of exact live clock-in RPC after STEP11 (whitespace normalized).
CREATE OR REPLACE FUNCTION public.ff38_clock_in()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 DECLARE v_driver uuid;v_active int;v_order uuid;
 BEGIN
 SELECT l.driver_id INTO v_driver FROM public.ff38_driver_links l
 JOIN public.ff_profiles p ON p.user_id=l.user_id AND p.active AND p.role='driver'
 JOIN public.ff_drivers d ON d.id=l.driver_id AND d.active
 WHERE l.user_id=auth.uid();
 IF v_driver IS NULL THEN RAISE EXCEPTION 'الحساب غير مرتبط بموصل نشط' USING ERRCODE='42501'; END IF;
 SELECT count(*) INTO v_active FROM public.ff38_delivery_tasks WHERE driver_id=v_driver AND delivered_at IS NULL;
 INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at,updated_at)
 VALUES(v_driver,CASE WHEN v_active>0 THEN 'busy' ELSE 'ready' END,now(),now(),now())
 ON CONFLICT(driver_id) DO UPDATE SET state=CASE WHEN public.ff38_driver_presence.state='paused' THEN 'paused' ELSE excluded.state END,
 checked_in_at=CASE WHEN public.ff38_driver_presence.state='offline' THEN now() ELSE public.ff38_driver_presence.checked_in_at END,
 checked_out_at=NULL,last_seen_at=now(),updated_at=now();
 -- Preserve paused status across a browser reload/login; no offers while paused.
 IF (SELECT state FROM public.ff38_driver_presence WHERE driver_id=v_driver) <> 'paused' THEN
 -- Immediately distribute older waiting orders to a newly present driver (same branch only).
 FOR v_order IN
 SELECT o.id FROM public.ff_orders o JOIN public.ff_drivers d ON d.branch_id=o.branch_id
 WHERE d.id=v_driver AND o.order_type='delivery' AND o.status='new'
 AND o.created_at>now()-interval '14 days'
 AND NOT EXISTS(SELECT 1 FROM public.ff38_delivery_tasks t WHERE t.order_id=o.id)
 AND NOT EXISTS(SELECT 1 FROM public.ff38_dispatch_offers f WHERE f.order_id=o.id AND f.status='offered' AND f.expires_at>now())
 ORDER BY o.created_at LIMIT 5
 LOOP
 -- We already own a presence row lock; never wait on an order/branch lock
 -- held by a dispatcher that may be waiting for this same presence row.
 IF pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtext('ff38-o-'||v_order::text))
 AND pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtext('ff38-branch-rr-'||(SELECT branch_id FROM public.ff_drivers WHERE id=v_driver)::text)) THEN
 PERFORM 1 FROM public.ff_orders WHERE id=v_order FOR UPDATE SKIP LOCKED;
 IF FOUND THEN PERFORM public.ff38__offer_next(v_order);END IF;
 END IF;
 END LOOP;
 END IF;
 RETURN jsonb_build_object('state',(SELECT state FROM public.ff38_driver_presence WHERE driver_id=v_driver),'driver_id',v_driver);
 END $function$
