-- Read-only reconciliation of actual source rows, three active branches and consolidated.
-- Explicit time bounds and raw source computations; no test writes.
DO $qa$
DECLARE actor uuid; b record; r jsonb; expected record; dy date:=public.ff_business_date(now()); start_date date:=dy-89; count_checked int:=0; v_prior text; expected_f record;
BEGIN
SELECT user_id INTO STRICT actor FROM public.ff_profiles WHERE role='manager' AND active LIMIT 1;
v_prior:=current_setting('request.jwt.claim.sub',true);
PERFORM set_config('request.jwt.claim.sub',actor::text,true);
FOR b IN SELECT id,code FROM public.ff_branches WHERE active UNION ALL SELECT null::uuid,'all' LOOP
 r:=public.ff_a10_reporting_center(start_date,dy,b.id,NULL,NULL,NULL,NULL,NULL);
 SELECT count(*) orders,count(*) FILTER(WHERE o.status='delivered') delivered,count(*) FILTER(WHERE o.status='cancelled') cancelled,
 coalesce(sum(o.items_total+coalesce(a.addons,0)) FILTER(WHERE o.status='delivered'),0) items,
 coalesce(sum(o.delivery_fee) FILTER(WHERE o.status='delivered'),0) fees,
 coalesce(sum(o.total+coalesce(a.addons,0)) FILTER(WHERE o.status='delivered'),0) net
 INTO expected FROM public.ff_orders o LEFT JOIN LATERAL(SELECT sum(amount) addons FROM public.ff38_order_additions WHERE order_id=o.id AND status='invoiced') a ON true
 WHERE o.order_type='delivery' AND o.created_at >= ((start_date+time '08:00') AT TIME ZONE 'Asia/Aden') AND o.created_at < ((dy+1+time '02:00') AT TIME ZONE 'Asia/Aden') AND NOT o.closed_hours_flag AND (b.id IS NULL OR o.branch_id=b.id);
 IF (r#>>'{totals,orders}')::bigint IS DISTINCT FROM expected.orders OR (r#>>'{totals,delivered}')::bigint IS DISTINCT FROM expected.delivered OR (r#>>'{totals,cancelled}')::bigint IS DISTINCT FROM expected.cancelled OR (r#>>'{totals,item_sales}')::numeric IS DISTINCT FROM expected.items OR (r#>>'{totals,delivery_fees}')::numeric IS DISTINCT FROM expected.fees OR (r#>>'{totals,net}')::numeric IS DISTINCT FROM expected.net THEN RAISE EXCEPTION 'Source amount/status mismatch for %',b.code; END IF;
 SELECT sum(s.cash_received) FILTER(WHERE s.status='closed') received,sum(s.cash_due-s.cash_received) FILTER(WHERE s.status='closed') difference,sum(s.cash_received) FILTER(WHERE s.status='draft') draft_received,count(*) FILTER(WHERE s.status='closed') closed_statements,sum(e.amount) FILTER(WHERE s.status='closed') fees_confirmed,count(*) FILTER(WHERE s.status='closed' AND e.id IS NULL) fees_need_review INTO expected_f
 FROM public.ff42_driver_settlements s LEFT JOIN LATERAL(SELECT id,amount FROM ff_private.a10_fee_evidence WHERE settlement_id=s.id ORDER BY id DESC LIMIT 1)e ON true
 WHERE s.settlement_date BETWEEN start_date AND dy AND (b.id IS NULL OR s.branch_id=b.id);
 IF (r#>>'{finance_evidence,confirmed_received}')::numeric IS DISTINCT FROM expected_f.received OR (r#>>'{finance_evidence,confirmed_difference}')::numeric IS DISTINCT FROM expected_f.difference OR (r#>>'{finance_evidence,draft_received}')::numeric IS DISTINCT FROM expected_f.draft_received OR (r#>>'{finance_evidence,closed_statements}')::bigint IS DISTINCT FROM expected_f.closed_statements OR (r#>>'{finance_evidence,fee_collection_confirmed}')::numeric IS DISTINCT FROM expected_f.fees_confirmed OR (r#>>'{finance_evidence,fees_need_review}')::bigint IS DISTINCT FROM expected_f.fees_need_review THEN RAISE EXCEPTION 'Settlement source mismatch for %',b.code; END IF;
 count_checked:=count_checked+1;
END LOOP;
IF count_checked<>4 THEN RAISE EXCEPTION 'Expected 3 active branches and consolidated';END IF;
PERFORM set_config('request.jwt.claim.sub',coalesce(v_prior,''),true);
END $qa$;
SELECT 'PASS STEP10: 90-day source reconciliation across 3 branches and consolidated; actual order counts, fees, invoice amounts, latest fee evidence and draft/closed settlements' AS result;
