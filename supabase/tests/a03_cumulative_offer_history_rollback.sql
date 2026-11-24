-- Actual production RPC coverage, isolated fixtures rolled back.
DO $qa$
DECLARE b uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); d1 uuid:=gen_random_uuid(); d2 uuid:=gen_random_uuid();
 o1 uuid:=gen_random_uuid(); o2 uuid:=gen_random_uuid(); exp_o uuid:=gen_random_uuid(); rej_o uuid:=gen_random_uuid();
 eligible_o uuid:=gen_random_uuid(); oid uuid; f uuid; r jsonb; passes int:=0;
BEGIN
 BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-'||b,'QA expired cumulative');
 INSERT INTO auth.users(id) VALUES(a);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(a,'QA CS','customer_service',true) ON CONFLICT(user_id) DO UPDATE SET role='customer_service',active=true;
 INSERT INTO public.ff_drivers(id,name,branch_id,sort_order) VALUES(d1,'QA busy first',b,1),(d2,'QA busy second',b,2);
 INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d1,'busy',now(),now()),(d2,'offline',null,now()) ON CONFLICT(driver_id) DO UPDATE SET state=excluded.state,checked_in_at=excluded.checked_in_at,last_seen_at=excluded.last_seen_at;
 FOREACH oid IN ARRAY ARRAY[o1,o2,exp_o,rej_o,eligible_o] LOOP
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot,allow_driver_reject)
 VALUES(oid,-(1+floor(random()*1e12)::bigint),b,'000000000',public.ff_business_date(now()),'QA same',true);
 END LOOP;
 INSERT INTO public.ff38_delivery_tasks(order_id,driver_id) VALUES(o1,d1);
 UPDATE public.ff_orders SET driver_id=d1,status='sent' WHERE id=o1;
 INSERT INTO public.ff38_dispatch_offers(order_id,driver_id,offered_at,expires_at)
 VALUES(exp_o,d1,now()-interval '20 minutes',now()-interval '10 minutes') RETURNING id INTO f;
 r:=public.ff38__offer_next(exp_o);
 IF r->>'state' IS DISTINCT FROM 'queued' OR EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE order_id=exp_o)
 OR (SELECT status FROM public.ff38_dispatch_offers WHERE id=f)<>'expired' THEN RAISE EXCEPTION 'Expired busy courier was reassigned: %',r;END IF;passes:=passes+1;
 INSERT INTO public.ff38_dispatch_offers(order_id,driver_id,expires_at) VALUES(rej_o,d1,now()+interval '10 minutes') RETURNING id INTO f;
 UPDATE public.ff38_dispatch_offers SET status='rejected',responded_at=now() WHERE id=f;
 r:=public.ff38__offer_next(rej_o);
 IF r->>'state' IS DISTINCT FROM 'queued' OR EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE order_id=rej_o) THEN RAISE EXCEPTION 'Rejected busy courier was assigned: %',r;END IF;passes:=passes+1;
 PERFORM set_config('request.jwt.claim.sub',a::text,true);
 SET LOCAL ROLE authenticated;
 r:=public.ff60_manual_reoffer(exp_o,d1,'QA authorized repeat');
 RESET ROLE;
 IF r->>'state' IS DISTINCT FROM 'offered' OR r->>'driver_id' IS DISTINCT FROM d1::text
 OR NOT EXISTS(SELECT 1 FROM public.ff60_workflow_events WHERE order_id=exp_o AND event_type='manual_reoffer' AND actor_id=a AND details->>'reason'='QA authorized repeat') THEN RAISE EXCEPTION 'Authorized reoffer broken';END IF;passes:=passes+1;
 UPDATE public.ff38_dispatch_offers SET status='expired' WHERE order_id=exp_o AND status='offered';
 UPDATE public.ff38_driver_presence SET state='busy',checked_in_at=now(),last_seen_at=now() WHERE driver_id=d2;
 INSERT INTO public.ff38_delivery_tasks(order_id,driver_id) VALUES(o2,d2);
 UPDATE public.ff_orders SET driver_id=d2,status='sent' WHERE id=o2;
 r:=public.ff38__offer_next(rej_o);
 IF r->>'state' IS DISTINCT FROM 'assigned_cumulative' OR r->>'driver_id' IS DISTINCT FROM d2::text THEN RAISE EXCEPTION 'Eligible busy alternative not selected: %',r;END IF;passes:=passes+1;
 r:=public.ff38__offer_next(eligible_o);
 IF r->>'state' IS DISTINCT FROM 'assigned_cumulative' OR r->>'driver_id' IS DISTINCT FROM d1::text THEN RAISE EXCEPTION 'Ordinary cumulative assignment broken: %',r;END IF;passes:=passes+1;
 RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF passes<>5 OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id=b) OR EXISTS(SELECT 1 FROM auth.users WHERE id=a)
 OR EXISTS(SELECT 1 FROM public.ff_orders WHERE id IN(o1,o2,exp_o,rej_o,eligible_o)) THEN RAISE EXCEPTION 'Incomplete QA or rollback';END IF;
END $qa$;
SELECT 'PASS A03: five cumulative history checks; expired/rejected excluded, authorized reoffer and eligible alternate preserved; rollback' AS result;