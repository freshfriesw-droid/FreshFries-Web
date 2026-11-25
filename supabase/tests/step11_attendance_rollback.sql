-- Test actual attendance state, no orphan breaks, pending offers and outstanding work.
DO $qa$
DECLARE b uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); o uuid:=gen_random_uuid(); f uuid; r jsonb; blocked boolean; n int:=0; start_at timestamptz; stop_at timestamptz;
BEGIN
 BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-step11-'||b,'QA attendance');
 INSERT INTO auth.users(id) VALUES(m),(u);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA manager','manager',true),(u,'QA driver','driver',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d,'QA driver',b);
 INSERT INTO public.ff38_driver_links(user_id,driver_id) VALUES(u,d);
 PERFORM set_config('request.jwt.claim.sub',u::text,true); SET LOCAL ROLE authenticated;
 blocked:=false; BEGIN PERFORM public.ff51_driver_set_break(true); EXCEPTION WHEN raise_exception THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'break before clock in';END IF;n:=n+1;
 IF public.ff38_clock_in()->>'state'<>'ready' THEN RAISE EXCEPTION 'clock in';END IF;n:=n+1;
 RESET ROLE; SELECT checked_in_at INTO start_at FROM public.ff38_driver_presence WHERE driver_id=d;
 SET LOCAL ROLE authenticated;
 blocked:=false; BEGIN PERFORM public.ff51_driver_set_break(NULL); EXCEPTION WHEN raise_exception THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'null break accepted';END IF;n:=n+1;
 IF public.ff51_driver_set_break(true)->>'state'<>'paused' THEN RAISE EXCEPTION 'break';END IF;n:=n+1;
 IF public.ff38_clock_in()->>'state'<>'paused' OR public.ff38_heartbeat()->>'state'<>'paused' THEN RAISE EXCEPTION 'reconnect changed break';END IF;n:=n+1;
 IF public.ff51_driver_set_break(false)->>'state'<>'ready' THEN RAISE EXCEPTION 'return';END IF;n:=n+1;
 RESET ROLE;
 IF (SELECT count(*) FROM public.ff51_driver_breaks WHERE driver_id=d AND ended_at IS NOT NULL)<>1 THEN RAISE EXCEPTION 'break not closed';END IF;n:=n+1;
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,area_snapshot,created_by) VALUES(o,-1000000000000-floor(random()*1e12)::bigint,b,'000000000','QA',m);
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 r:=public.ff38_dispatch(o,d); f:=(r->>'offer_id')::uuid;
 IF f IS NULL THEN RAISE EXCEPTION 'offer %',r;END IF;
 PERFORM set_config('request.jwt.claim.sub',u::text,true); SET LOCAL ROLE authenticated;
 blocked:=false; BEGIN PERFORM public.ff38_clock_out(); EXCEPTION WHEN raise_exception THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'clock out with pending offer';END IF;n:=n+1;
 blocked:=false; BEGIN PERFORM public.ff51_driver_set_break(true); EXCEPTION WHEN raise_exception THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'break with pending offer';END IF;n:=n+1;
 IF public.ff38_driver_reply(f,true,NULL)->>'state'<>'accepted' THEN RAISE EXCEPTION 'accept';END IF;n:=n+1;
 blocked:=false; BEGIN PERFORM public.ff38_clock_out(); EXCEPTION WHEN raise_exception THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'clock out with task';END IF;n:=n+1;
 RESET ROLE; UPDATE public.ff_orders SET status='cancelled' WHERE id=o; UPDATE public.ff38_delivery_tasks SET delivered_at=clock_timestamp() WHERE order_id=o;UPDATE public.ff38_driver_presence SET state='ready' WHERE driver_id=d;
 SET LOCAL ROLE authenticated; PERFORM public.ff51_driver_set_break(true);
 IF public.ff38_clock_out()->>'state'<>'offline' THEN RAISE EXCEPTION 'checkout';END IF;n:=n+1;
 RESET ROLE; SELECT checked_out_at INTO stop_at FROM public.ff38_driver_presence WHERE driver_id=d;
 IF EXISTS(SELECT 1 FROM public.ff51_driver_breaks WHERE driver_id=d AND ended_at IS NULL) OR stop_at IS NULL THEN RAISE EXCEPTION 'orphan break';END IF;n:=n+1;
 SET LOCAL ROLE authenticated; PERFORM public.ff38_clock_out(); IF public.ff38_heartbeat()->>'requires_clock_in'<>'true' THEN RAISE EXCEPTION 'heartbeat restarted shift';END IF;n:=n+1;
 RESET ROLE;
 IF (SELECT checked_out_at FROM public.ff38_driver_presence WHERE driver_id=d) IS DISTINCT FROM stop_at OR (SELECT count(*) FROM public.ff76_driver_work_sessions WHERE driver_id=d AND checked_in_at=start_at AND checked_out_at=stop_at)<>1 THEN RAISE EXCEPTION 'repeat changed checkout';END IF;n:=n+1;
 RAISE EXCEPTION 'rollback QA' USING ERRCODE='PZ011';
 EXCEPTION WHEN SQLSTATE 'PZ011' THEN NULL;END;
 IF n<>15 OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id=b) THEN RAISE EXCEPTION 'QA incomplete %',n;END IF;
END $qa$;
SELECT 'PASS STEP11 15 attendance assertions: clock-in, pause, resume, reconnect, pending offer/task denial, checkout closes break, idempotency and rollback' result;
