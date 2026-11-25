-- STEP11: serialize attendance termination with assignment, preserve historical sessions.
CREATE OR REPLACE FUNCTION public.ff38_clock_out() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_driver uuid; v_presence public.ff38_driver_presence%ROWTYPE; v_end timestamptz;
BEGIN
 SELECT l.driver_id INTO v_driver FROM public.ff38_driver_links l
 JOIN public.ff_profiles p ON p.user_id=l.user_id AND p.active AND p.role='driver'
 JOIN public.ff_drivers d ON d.id=l.driver_id AND d.active WHERE l.user_id=auth.uid();
 IF v_driver IS NULL THEN RAISE EXCEPTION 'غير مسموح' USING ERRCODE='42501'; END IF;
 SELECT * INTO v_presence FROM public.ff38_driver_presence WHERE driver_id=v_driver FOR UPDATE;
 IF EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE driver_id=v_driver AND delivered_at IS NULL) THEN
  RAISE EXCEPTION 'لا يمكن إنهاء الدوام قبل تسليم الطلبات المفتوحة';
 END IF;
 IF EXISTS(SELECT 1 FROM public.ff38_dispatch_offers WHERE driver_id=v_driver AND status='offered' AND expires_at>clock_timestamp()) THEN
  RAISE EXCEPTION 'لديك طلب ينتظر قبولك أو رفضك، يرجى الرد عليه قبل إنهاء الدوام';
 END IF;
 -- Repeat requests must not move the recorded checkout timestamp.
 IF v_presence.driver_id IS NULL OR v_presence.state='offline' OR v_presence.checked_in_at IS NULL OR v_presence.checked_out_at IS NOT NULL THEN
  RETURN jsonb_build_object('state','offline');
 END IF;
 v_end:=clock_timestamp();
 -- Close only a break that belongs to the current recorded work session.
 UPDATE public.ff51_driver_breaks SET ended_at=v_end
 WHERE driver_id=v_driver AND ended_at IS NULL AND started_at>=v_presence.checked_in_at AND started_at<=v_end;
 UPDATE public.ff38_driver_presence SET state='offline',checked_out_at=v_end,updated_at=v_end WHERE driver_id=v_driver;
 RETURN jsonb_build_object('state','offline');
END $$;
CREATE OR REPLACE FUNCTION public.ff51_driver_set_break(p_on_break boolean) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_driver uuid; v_presence public.ff38_driver_presence%ROWTYPE; v_now timestamptz;
BEGIN
 SELECT l.driver_id INTO v_driver FROM public.ff38_driver_links l
 JOIN public.ff_profiles p ON p.user_id=l.user_id AND p.active AND p.role='driver'
 JOIN public.ff_drivers d ON d.id=l.driver_id AND d.active WHERE l.user_id=auth.uid();
 IF v_driver IS NULL THEN RAISE EXCEPTION 'للموصل فقط' USING ERRCODE='42501'; END IF;
 IF p_on_break IS NULL THEN RAISE EXCEPTION 'حدد بدء الاستراحة أو إنهاءها';END IF;
 SELECT * INTO v_presence FROM public.ff38_driver_presence WHERE driver_id=v_driver FOR UPDATE;
 IF v_presence.driver_id IS NULL OR v_presence.checked_in_at IS NULL OR v_presence.checked_out_at IS NOT NULL OR v_presence.state='offline' THEN
  RAISE EXCEPTION 'يلزم بدء الدوام قبل الاستراحة';
 END IF;
 v_now:=clock_timestamp();
 IF p_on_break THEN
  IF v_presence.state IS DISTINCT FROM 'ready' OR EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE driver_id=v_driver AND delivered_at IS NULL)
   OR EXISTS(SELECT 1 FROM public.ff38_dispatch_offers WHERE driver_id=v_driver AND status='offered' AND expires_at>v_now)
   OR EXISTS(SELECT 1 FROM public.ff51_driver_breaks WHERE driver_id=v_driver AND ended_at IS NULL AND started_at>=v_presence.checked_in_at) THEN
   RAISE EXCEPTION 'الاستراحة متاحة عند عدم وجود أي مهام أو عروض فقط';
  END IF;
  INSERT INTO public.ff51_driver_breaks(driver_id,started_at) VALUES(v_driver,v_now);
  UPDATE public.ff38_driver_presence SET state='paused',updated_at=v_now WHERE driver_id=v_driver;
 ELSE
  IF v_presence.state IS DISTINCT FROM 'paused' THEN RAISE EXCEPTION 'الموصل ليس في استراحة';END IF;
  UPDATE public.ff51_driver_breaks SET ended_at=v_now WHERE driver_id=v_driver AND ended_at IS NULL AND started_at>=v_presence.checked_in_at AND started_at<=v_now;
  UPDATE public.ff38_driver_presence SET state='ready',last_seen_at=v_now,updated_at=v_now WHERE driver_id=v_driver;
 END IF;
 RETURN jsonb_build_object('state',CASE WHEN p_on_break THEN 'paused' ELSE 'ready' END);
END $$;
-- Both automatic offer paths must re-check the candidate after acquiring the same presence lock.
-- A direct transfer uses the same lock. Preserve the previous routing and capacity policies.
DO $migration$
DECLARE d text; a text; z text;
BEGIN
 d:=pg_get_functiondef('public.ff38__offer_next(uuid,uuid)'::regprocedure);
 a:='PERFORM 1 FROM public.ff38_driver_presence WHERE driver_id=v_driver FOR UPDATE;';
 z:=$s$PERFORM 1 FROM public.ff38_driver_presence WHERE driver_id=v_driver AND state IN ('ready','busy') AND checked_in_at IS NOT NULL AND checked_out_at IS NULL AND last_seen_at>clock_timestamp()-interval '90 seconds' FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('state','queued','reason','driver_no_longer_available'); END IF;$s$;
 IF (length(d)-length(replace(d,a,'')))/length(a)<>2 THEN RAISE EXCEPTION 'Unexpected dispatch presence anchors';END IF;
 EXECUTE replace(d,a,z);
 d:=pg_get_functiondef('public.ff52_reassign_before_pos(uuid,uuid,text)'::regprocedure);
 a:=$s$if not exists(select 1 from public.ff_drivers d join public.ff38_driver_presence p on p.driver_id=d.id$s$;
 z:=$s$perform 1 from public.ff_drivers d join public.ff38_driver_presence p on p.driver_id=d.id$s$;
 IF (length(d)-length(replace(d,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'Unexpected transfer anchor';END IF;
 d:=replace(d,a,z);
 a:=$s$and p.checked_in_at is not null and p.last_seen_at>now()-interval '90 seconds') then$s$;
 z:=$s$and p.checked_in_at is not null and p.checked_out_at is null and p.last_seen_at>clock_timestamp()-interval '90 seconds' for update of p;
 if not found then$s$;
 IF (length(d)-length(replace(d,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'Unexpected transfer eligibility anchor';END IF;
 EXECUTE replace(d,a,z);
END $migration$;
REVOKE ALL ON FUNCTION public.ff38_clock_out(),public.ff51_driver_set_break(boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff38_clock_out(),public.ff51_driver_set_break(boolean) TO authenticated;
