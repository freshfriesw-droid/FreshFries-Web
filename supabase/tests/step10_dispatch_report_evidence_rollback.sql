-- Real dispatch evidence, automatic, manual special cumulative, and denied client forgery.
DO $qa$
DECLARE b uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); special uuid:=gen_random_uuid(); actor uuid:=gen_random_uuid(); driver_actor uuid:=gen_random_uuid(); o1 uuid:=gen_random_uuid(); o2 uuid:=gen_random_uuid(); o3 uuid:=gen_random_uuid(); o4 uuid:=gen_random_uuid(); o5 uuid:=gen_random_uuid(); oid uuid; r jsonb; denied boolean:=false; checks int:=0; dy date:=public.ff_business_date(now())-1; ts timestamptz; n bigint:=-1000000000000-floor(random()*1e12)::bigint;
BEGIN
 BEGIN
  ts:=(dy+time '10:00') AT TIME ZONE 'Asia/Aden';
  INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-step10-'||b,'STEP10 dispatch QA');
  INSERT INTO auth.users(id) VALUES(actor),(driver_actor);
  INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(actor,'STEP10 QA manager','manager',true),(driver_actor,'STEP10 QA courier','driver',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
  INSERT INTO public.ff_drivers(id,name,branch_id,sort_order) VALUES(d,'STEP10 QA ordinary',b,1),(special,'STEP10 QA special',b,2);
  INSERT INTO public.ff38_driver_links(user_id,driver_id) VALUES(driver_actor,d);
  INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d,'ready',now(),now()),(special,'ready',now(),now()) ON CONFLICT(driver_id) DO UPDATE SET state=excluded.state,checked_in_at=excluded.checked_in_at,last_seen_at=excluded.last_seen_at;
  INSERT INTO ff_private.special_courier_capacity(driver_id) VALUES(special);
  FOREACH oid IN ARRAY ARRAY[o1,o2,o3,o4,o5] LOOP
   INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,area_snapshot,created_at,created_by) VALUES(oid,n,b,'700000000','QA area',ts,actor);n:=n-1;
  END LOOP;
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  r:=public.ff38_dispatch(o1,NULL);
  IF r->>'state'<>'offered' OR r->>'driver_id'<>d::text THEN RAISE EXCEPTION 'Automatic offer %',r; END IF;checks:=checks+1;
  PERFORM set_config('request.jwt.claim.sub',driver_actor::text,true);
  r:=public.ff38_driver_reply((r->>'offer_id')::uuid,true,NULL);
  IF r->>'state'<>'accepted' THEN RAISE EXCEPTION 'Automatic offer acceptance %',r;END IF;checks:=checks+1;
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  r:=public.ff38_dispatch(o2,NULL);
  IF r->>'state'<>'assigned_cumulative' THEN RAISE EXCEPTION 'Automatic cumulative %',r; END IF;checks:=checks+1;
  INSERT INTO public.ff38_delivery_tasks(order_id,driver_id) VALUES(o3,special);
  UPDATE public.ff_orders SET status='sent',driver_id=special WHERE id=o3;
  UPDATE public.ff38_driver_presence SET state='busy' WHERE driver_id=special;
  r:=public.ff49_manual_dispatch(o4,special,'STEP10 QA special target');
  IF r->>'state'<>'assigned_cumulative' THEN RAISE EXCEPTION 'Manual special cumulative %',r;END IF;checks:=checks+1;
  r:=public.ff38_dispatch(o4,special);
  IF r->>'state'<>'already_assigned' OR (SELECT count(*) FROM public.ff_audit_log WHERE action='step10_dispatch_evidence' AND entity_id=o4::text)<>1 THEN RAISE EXCEPTION 'Duplicate evidence';END IF;checks:=checks+1;
  SET LOCAL ROLE authenticated;
  BEGIN
   INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details) VALUES(actor,'step10_dispatch_evidence','dispatch_report_evidence',o5::text,b,'{"kind":"cumulative","mode":"manual","special":true}');
  EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;
  IF NOT denied THEN RAISE EXCEPTION 'Forged dispatch evidence';END IF;checks:=checks+1;
  r:=public.ff_a10_reporting_center(dy,dy,b,NULL,NULL,NULL,NULL,NULL);
  IF (r#>>'{assignment_review,automatic_confirmed}')::int<>2 OR (r#>>'{assignment_review,manual_confirmed}')::int<>1 OR (r#>>'{assignment_review,special_direct_confirmed}')::int<>1 OR (r#>>'{assignment_review,evidence_events}')::int<>3 THEN RAISE EXCEPTION 'Evidence totals %',r->'assignment_review';END IF;checks:=checks+1;
  r:=public.ff_a10_reporting_center(dy,dy,b,special,NULL,NULL,NULL,NULL);
  IF (r#>>'{assignment_review,automatic_confirmed}')::int<>0 OR (r#>>'{assignment_review,manual_confirmed}')::int<>1 OR (r#>>'{assignment_review,special_direct_confirmed}')::int<>1 THEN RAISE EXCEPTION 'Driver evidence filter %',r->'assignment_review';END IF;checks:=checks+1;
  RESET ROLE;
  RAISE EXCEPTION 'QA rollback' USING ERRCODE='ZQA10';
 EXCEPTION WHEN SQLSTATE 'ZQA10' THEN NULL;END;
 IF checks<>8 OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id=b) OR EXISTS(SELECT 1 FROM public.ff_audit_log WHERE entity_type='dispatch_report_evidence' AND entity_id IN(o1::text,o2::text,o4::text,o5::text)) THEN RAISE EXCEPTION 'Incomplete evidence rollback %',checks;END IF;
END $qa$;
SELECT 'PASS STEP10: 8 dispatch origin assertions, special direct evidence, role forgery denial, no duplicates and full rollback' AS result;
