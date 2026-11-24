-- A03: actual automatic dispatch rotation, route priority and cumulative area rules.
-- Isolated synthetic branches; all changes are rolled back.
DO $qa$
DECLARE b uuid:=gen_random_uuid(); b2 uuid:=gen_random_uuid(); d1 uuid:=gen_random_uuid(); d2 uuid:=gen_random_uuid(); d3 uuid:=gen_random_uuid(); special uuid:=gen_random_uuid(); foreign_d uuid:=gen_random_uuid();
 o1 uuid:=gen_random_uuid();o2 uuid:=gen_random_uuid();o3 uuid:=gen_random_uuid();o4 uuid:=gen_random_uuid();o5 uuid:=gen_random_uuid();o6 uuid:=gen_random_uuid();o7 uuid:=gen_random_uuid();o8 uuid:=gen_random_uuid();oid uuid;
 r jsonb; n int:=0;
BEGIN
 BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-'||b,'QA rotation'),(b2,'qa-'||b2,'QA foreign');
 INSERT INTO public.ff_drivers(id,name,branch_id,sort_order) VALUES(d1,'QA first',b,1),(d2,'QA second',b,2),(d3,'QA disconnected',b,0),(special,'QA special',b,0),(foreign_d,'QA outside',b2,0);
 INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at)
 VALUES(d1,'ready',now(),now()),(d2,'ready',now(),now()),(d3,'ready',now(),now()-interval '91 seconds'),(special,'ready',now(),now()),(foreign_d,'ready',now(),now())
 ON CONFLICT(driver_id) DO UPDATE SET state=excluded.state,checked_in_at=excluded.checked_in_at,last_seen_at=excluded.last_seen_at;
 INSERT INTO ff_private.special_courier_capacity(driver_id) VALUES(special);
 FOREACH oid IN ARRAY ARRAY[o1,o2,o3,o4,o5,o6,o7,o8] LOOP
  INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot)
  VALUES(oid,-(1+floor(random()*1e12)::bigint),b,'000000000',public.ff_business_date(now()),'QA Area A');
 END LOOP;
 r:=public.ff38__offer_next(o1);
 IF r->>'driver_id' IS DISTINCT FROM d1::text THEN RAISE EXCEPTION 'Initial ordered candidate mismatch: %',r;END IF;n:=n+1;
 UPDATE public.ff38_dispatch_offers SET status='expired',offered_at=now()-interval '30 minutes',expires_at=now()-interval '20 minutes' WHERE order_id=o1;
 r:=public.ff38__offer_next(o2);
 IF r->>'driver_id' IS DISTINCT FROM d2::text THEN RAISE EXCEPTION 'Round robin did not rotate: %',r;END IF;n:=n+1;
 UPDATE public.ff38_dispatch_offers SET status='expired',offered_at=now()-interval '20 minutes',expires_at=now()-interval '10 minutes' WHERE order_id=o2;
 r:=public.ff38__offer_next(o3);
 IF r->>'driver_id' IS DISTINCT FROM d1::text THEN RAISE EXCEPTION 'Oldest offer not selected: %',r;END IF;n:=n+1;
 UPDATE public.ff38_dispatch_offers SET status='expired' WHERE order_id=o3;
 -- Geographic preference inside an explicitly configured all-day test window.
 INSERT INTO public.ff52_priority_routes(branch_id,driver_id,area_terms,start_local,end_local)
 VALUES(b,d2,array['QA Area A'],time '00:00:00',time '23:59:59.999999');
 IF NOT public.ff52_is_route_priority(d2,b,'QA Area A') OR public.ff52_is_route_priority(d2,b,'QA Area B') OR public.ff52_is_route_priority(d2,b2,'QA Area A') THEN RAISE EXCEPTION 'Route scope mismatch';END IF;n:=n+1;
 r:=public.ff38__offer_next(o4);
 IF r->>'driver_id' IS DISTINCT FROM d2::text THEN RAISE EXCEPTION 'Route priority lost: %',r;END IF;n:=n+1;
 UPDATE public.ff38_dispatch_offers SET status='expired' WHERE order_id=o4;
 UPDATE public.ff52_priority_routes SET active=false WHERE branch_id=b;
 IF public.ff52_is_route_priority(d2,b,'QA Area A') THEN RAISE EXCEPTION 'Inactive route still prioritized';END IF;n:=n+1;
 -- One active driver, two tasks in A: a third in another area cannot be assigned.
 UPDATE public.ff38_driver_presence SET state='offline',checked_in_at=null WHERE driver_id=d2;
 INSERT INTO public.ff38_delivery_tasks(order_id,driver_id) VALUES(o1,d1),(o2,d1);
 UPDATE public.ff_orders SET driver_id=d1,status='sent' WHERE id IN(o1,o2);
 UPDATE public.ff38_driver_presence SET state='busy' WHERE driver_id=d1;
 UPDATE public.ff_orders SET area_snapshot='QA Area B' WHERE id=o5;
 r:=public.ff38__offer_next(o5);
 IF r->>'state' IS DISTINCT FROM 'queued' THEN RAISE EXCEPTION 'Incompatible third area assigned: %',r;END IF;n:=n+1;
 r:=public.ff38__offer_next(o6);
 IF r->>'state' IS DISTINCT FROM 'assigned_cumulative' OR r->>'driver_id' IS DISTINCT FROM d1::text THEN RAISE EXCEPTION 'Compatible third order not assigned: %',r;END IF;n:=n+1;
 r:=public.ff38__offer_next(o7);
 IF r->>'state' IS DISTINCT FROM 'assigned_cumulative' THEN RAISE EXCEPTION 'Fourth assignment failed: %',r;END IF;n:=n+1;
 r:=public.ff38__offer_next(o8);
 IF r->>'state' IS DISTINCT FROM 'assigned_cumulative' OR (SELECT count(*) FROM public.ff38_delivery_tasks WHERE driver_id=d1 AND delivered_at IS NULL)<>5 THEN RAISE EXCEPTION 'Fifth assignment failed: %',r;END IF;n:=n+1;
 IF EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE driver_id IN(d2,d3,special,foreign_d)) THEN RAISE EXCEPTION 'Excluded driver assigned';END IF;
 RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF n<>10 OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id IN(b,b2)) OR EXISTS(SELECT 1 FROM public.ff_orders WHERE id IN(o1,o2,o3,o4,o5,o6,o7,o8)) THEN RAISE EXCEPTION 'Incomplete rotation coverage or rollback: %',n;END IF;
END $qa$;
SELECT 'PASS A03: 10 checks, fair rotation, geographic priority and branch isolation, disconnected/special exclusion, cumulative area and five tasks; rollback' AS result;