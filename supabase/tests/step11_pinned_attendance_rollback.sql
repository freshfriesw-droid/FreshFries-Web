DO $qa$
DECLARE b uuid;old_pinned uuid; m uuid:=gen_random_uuid();u uuid:=gen_random_uuid();d uuid:=gen_random_uuid();o uuid:=gen_random_uuid();r jsonb;blocked boolean;checks int:=0;
BEGIN
 SELECT id INTO STRICT b FROM public.ff_branches WHERE code='cairo';
 SELECT driver_id INTO STRICT old_pinned FROM public.ff62_pinned_drivers WHERE branch_id=b;
 BEGIN
 INSERT INTO auth.users(id) VALUES(m),(u);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA pinned manager','manager',true),(u,'QA pinned driver','driver',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d,'QA pinned isolated',b);
 INSERT INTO public.ff38_driver_links(user_id,driver_id) VALUES(u,d);
 UPDATE public.ff62_pinned_drivers SET driver_id=d WHERE branch_id=b;
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,area_snapshot,created_by,items_total,delivery_fee,total) VALUES(o,-1000000000000-floor(random()*1e12)::bigint,b,'000000000','QA',m,1000,500,1500);
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 blocked:=false;BEGIN PERFORM public.ff62_assign_pinned(o);EXCEPTION WHEN raise_exception THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Offline pinned assignment accepted';END IF;checks:=checks+1;
 INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d,'paused',now(),now()) ON CONFLICT(driver_id) DO UPDATE SET state='paused',checked_in_at=now(),last_seen_at=now(),checked_out_at=NULL;
 blocked:=false;BEGIN PERFORM public.ff62_assign_pinned(o);EXCEPTION WHEN raise_exception THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Paused pinned assignment accepted';END IF;checks:=checks+1;
 UPDATE public.ff38_driver_presence SET state='ready',last_seen_at=now()-interval '10 minutes' WHERE driver_id=d;
 blocked:=false;BEGIN PERFORM public.ff62_assign_pinned(o);EXCEPTION WHEN raise_exception THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Disconnected pinned assignment accepted';END IF;checks:=checks+1;
 UPDATE public.ff38_driver_presence SET last_seen_at=now() WHERE driver_id=d;
 r:=public.ff62_assign_pinned(o);
 IF r->>'state'<>'assigned_pinned' OR (r->>'delivery_fee')::numeric<>0 THEN RAISE EXCEPTION 'Valid pinned policy changed %',r;END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT 1 FROM public.ff38_driver_presence WHERE driver_id=d AND state='busy') THEN RAISE EXCEPTION 'Pinned readiness mismatch';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',u::text,true);
 blocked:=false;BEGIN PERFORM public.ff38_clock_out();EXCEPTION WHEN raise_exception THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Pinned task allowed checkout';END IF;checks:=checks+1;
 RAISE EXCEPTION 'rollback' USING ERRCODE='PZ011';
 EXCEPTION WHEN SQLSTATE 'PZ011' THEN NULL;END;
 IF checks<>6 OR EXISTS(SELECT 1 FROM public.ff_drivers WHERE id=d) OR (SELECT driver_id FROM public.ff62_pinned_drivers WHERE branch_id=b) IS DISTINCT FROM old_pinned THEN RAISE EXCEPTION 'QA rollback incomplete';END IF;
END $qa$;
SELECT 'PASS STEP11 6 pinned path assertions: offline, paused, disconnected denial; valid direct policy, busy, checkout blocked; rollback' result;
