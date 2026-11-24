-- QA-12: real managed re-offer of expired offers; isolated rollback.
DO $qa$
DECLARE b uuid:=gen_random_uuid(); b2 uuid:=gen_random_uuid(); cs uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); d2 uuid:=gen_random_uuid(); outside uuid:=gen_random_uuid(); o uuid:=gen_random_uuid(); old_id uuid; new_id uuid; r jsonb; denied boolean; passes int:=0;
BEGIN
 BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-'||b,'QA reoffer'),(b2,'qa-'||b2,'QA foreign');
 INSERT INTO auth.users(id) VALUES(cs);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(cs,'QA CS','customer_service',true) ON CONFLICT(user_id) DO UPDATE SET role='customer_service',active=true;
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d,'QA original',b),(d2,'QA backup',b),(outside,'QA outside',b2);
 INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d,'ready',now(),now()),(d2,'ready',now(),now()),(outside,'ready',now(),now()) ON CONFLICT(driver_id) DO UPDATE SET state='ready',checked_in_at=now(),last_seen_at=now();
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot) VALUES(o,-(1+floor(random()*1e12)::bigint),b,'000000000',public.ff_business_date(now()),'QA');
 INSERT INTO public.ff38_dispatch_offers(order_id,driver_id,offered_at,expires_at) VALUES(o,d,now()-interval '20 minutes',now()-interval '10 minutes') RETURNING id INTO old_id;
 PERFORM set_config('request.jwt.claim.sub',cs::text,true);
 SET LOCAL ROLE authenticated;
 denied:=false;
 BEGIN PERFORM public.ff60_manual_reoffer(o,d,'');EXCEPTION WHEN raise_exception THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Missing reason accepted';END IF;passes:=passes+1;
 denied:=false;
 BEGIN PERFORM public.ff60_manual_reoffer(o,outside,'QA foreign courier');EXCEPTION WHEN raise_exception THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Foreign courier accepted';END IF;passes:=passes+1;
 r:=public.ff60_manual_reoffer(o,d,'QA repeat after expiry');
 new_id:=(r->>'offer_id')::uuid;
 IF r->>'state'<>'offered' OR new_id IS NULL OR new_id=old_id THEN RAISE EXCEPTION 'Replacement not created';END IF;passes:=passes+1;
 denied:=false;
 BEGIN PERFORM public.ff60_manual_reoffer(o,d,'QA repeat while pending');EXCEPTION WHEN raise_exception THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Duplicate active reoffer';END IF;passes:=passes+1;
 RESET ROLE;
 IF (SELECT status FROM public.ff38_dispatch_offers WHERE id=old_id)<>'expired'
 OR (SELECT count(*) FROM public.ff38_dispatch_offers WHERE order_id=o AND status='offered')<>1
 OR NOT EXISTS(SELECT 1 FROM public.ff38_dispatch_offers WHERE id=new_id AND driver_id=d AND expires_at-offered_at=interval '3 minutes')
 OR NOT EXISTS(SELECT 1 FROM public.ff60_workflow_events WHERE order_id=o AND event_type='manual_reoffer' AND actor_id=cs AND details->>'reason'='QA repeat after expiry' AND details->>'offer_id'=new_id::text)
 OR EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE order_id=o) THEN RAISE EXCEPTION 'Expiry/new timer/audit mismatch';END IF;passes:=passes+1;
 RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF passes<>5 OR EXISTS(SELECT 1 FROM public.ff_orders WHERE id=o) OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id IN(b,b2)) OR EXISTS(SELECT 1 FROM auth.users WHERE id=cs) THEN RAISE EXCEPTION 'Incomplete QA or rollback';END IF;
END $qa$;
SELECT 'PASS A03: managed reoffer, new deadline/id, missing reason/foreign/duplicate denied, original expiry and audit retained; rollback' AS result;