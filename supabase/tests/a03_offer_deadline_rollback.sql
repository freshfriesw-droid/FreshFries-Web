-- Isolated rollback integration for FIX-09 / QA-12; no persistent fixtures.
DO $qa$
DECLARE
 b uuid:=gen_random_uuid(); other_b uuid:=gen_random_uuid(); d uuid:=gen_random_uuid();
 special uuid:=gen_random_uuid(); backup uuid:=gen_random_uuid(); outside uuid:=gen_random_uuid();
 o1 uuid:=gen_random_uuid(); o2 uuid:=gen_random_uuid(); o3 uuid:=gen_random_uuid();
 o4 uuid:=gen_random_uuid(); o5 uuid:=gen_random_uuid(); o6 uuid:=gen_random_uuid();
 oid uuid; seconds int; first_expiry timestamptz; outcome jsonb; fast int; slow int; passes int:=0;
BEGIN
 SELECT fast_seconds,slow_seconds INTO STRICT fast,slow FROM public.ff60_offer_policy WHERE singleton=1;
 IF fast<>180 OR slow<>600 THEN RAISE EXCEPTION 'Expected approved 180/600-second policy; do not overwrite configuration'; END IF;
 BEGIN
  INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-'||b,'A03 isolated branch'),(other_b,'qa-'||other_b,'A03 foreign branch');
  INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d,'QA candidate',b),(special,'QA special',b),(backup,'QA backup',b),(outside,'QA foreign',other_b);
  INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at)
   VALUES(d,'ready',now(),now()),(special,'ready',now(),now()),(backup,'offline',null,null),(outside,'ready',now(),now())
   ON CONFLICT(driver_id) DO UPDATE SET state=excluded.state,checked_in_at=excluded.checked_in_at,last_seen_at=excluded.last_seen_at;
  INSERT INTO ff_private.special_courier_capacity(driver_id) VALUES(special);
  FOREACH oid IN ARRAY ARRAY[o1,o2,o3,o4,o5,o6] LOOP
   INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot)
    VALUES(oid,-(1+floor(random()*1e12)::bigint),b,'000000000',public.ff_business_date(now()),'QA');
  END LOOP;
  outcome:=public.ff38__offer_next(o1);
  SELECT extract(epoch from expires_at-offered_at)::int,expires_at INTO STRICT seconds,first_expiry
   FROM public.ff38_dispatch_offers WHERE order_id=o1 AND driver_id=d AND status='offered';
  IF seconds<>slow THEN RAISE EXCEPTION 'Special/foreign driver incorrectly shortened deadline: %',seconds; END IF; passes:=passes+1;
  UPDATE public.ff38_driver_presence SET state='ready',checked_in_at=now(),last_seen_at=now() WHERE driver_id=backup;
  IF (SELECT expires_at FROM public.ff38_dispatch_offers WHERE order_id=o1 AND driver_id=d) IS DISTINCT FROM first_expiry THEN RAISE EXCEPTION 'Existing deadline changed';END IF; passes:=passes+1;
  UPDATE public.ff38_dispatch_offers SET status='expired' WHERE order_id=o1;
  outcome:=public.ff38__offer_next(o2,d);
  SELECT extract(epoch from expires_at-offered_at)::int INTO STRICT seconds
   FROM public.ff38_dispatch_offers WHERE order_id=o2 AND driver_id=d AND status='offered';
  IF seconds<>fast THEN RAISE EXCEPTION 'Ready backup did not yield 3 minutes: %',seconds;END IF; passes:=passes+1;
  UPDATE public.ff38_dispatch_offers SET status='expired' WHERE order_id=o2;
  INSERT INTO public.ff38_dispatch_offers(order_id,driver_id,status,offered_at,expires_at)
   VALUES(o3,backup,'expired',now()-interval '11 minutes',now()-interval '1 minute');
  outcome:=public.ff38__offer_next(o3);
  SELECT extract(epoch from expires_at-offered_at)::int INTO STRICT seconds
   FROM public.ff38_dispatch_offers WHERE order_id=o3 AND driver_id=d AND status='offered';
  IF seconds<>slow THEN RAISE EXCEPTION 'Expired prior candidate incorrectly shortened re-offer: %',seconds; END IF; passes:=passes+1;
  UPDATE public.ff38_dispatch_offers SET status='expired' WHERE order_id=o3 AND status='offered';
  UPDATE public.ff38_driver_presence SET last_seen_at=now()-interval '91 seconds' WHERE driver_id=backup;
  outcome:=public.ff38__offer_next(o4);
  SELECT extract(epoch from expires_at-offered_at)::int INTO STRICT seconds
   FROM public.ff38_dispatch_offers WHERE order_id=o4 AND driver_id=d AND status='offered';
  IF seconds<>slow THEN RAISE EXCEPTION 'Disconnected backup incorrectly shortened deadline: %',seconds; END IF; passes:=passes+1;
  IF public.ff38__offer_next(o4)->>'state' IS DISTINCT FROM 'pending' THEN RAISE EXCEPTION 'Existing active offer not preserved';END IF;
  IF (SELECT count(*) FROM public.ff38_dispatch_offers WHERE order_id=o4 AND status='offered')<>1 THEN RAISE EXCEPTION 'Duplicate offer';END IF; passes:=passes+1;
  UPDATE public.ff38_dispatch_offers SET status='expired' WHERE order_id=o4;
  UPDATE public.ff38_driver_presence SET last_seen_at=now() WHERE driver_id=backup;
  outcome:=public.ff38__offer_next(o5,backup);
  IF NOT EXISTS(SELECT 1 FROM public.ff38_dispatch_offers WHERE order_id=o5 AND driver_id=backup AND status='offered') THEN RAISE EXCEPTION 'Missing pending backup fixture';END IF;
  outcome:=public.ff38__offer_next(o6,d);
  SELECT extract(epoch from expires_at-offered_at)::int INTO STRICT seconds
   FROM public.ff38_dispatch_offers WHERE order_id=o6 AND driver_id=d AND status='offered';
  IF seconds<>slow THEN RAISE EXCEPTION 'Reserved backup incorrectly shortened deadline: %',seconds; END IF; passes:=passes+1;
  RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF passes<>7 OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id IN (b,other_b))
 OR EXISTS(SELECT 1 FROM public.ff_orders WHERE id IN (o1,o2,o3,o4,o5,o6)) THEN RAISE EXCEPTION 'QA rollback or coverage incomplete';END IF;
END $qa$;
SELECT 'PASS A03: 7 checks, 180/600 seconds, eligible/excluded/expired/offline/reserved backup, fixed deadline, duplicate offer blocked; rollback' AS result;
