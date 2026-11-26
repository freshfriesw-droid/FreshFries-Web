BEGIN;
DO $qa$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid JOIN pg_attribute a ON a.attrelid=i.indrelid AND a.attname='order_id' WHERE i.indrelid='public.ff_order_items'::regclass AND c.relname='ff_order_items_order_id_idx' AND i.indisvalid AND i.indisready AND i.indkey[0]=a.attnum AND i.indpred IS NULL AND NOT i.indisunique) THEN RAISE EXCEPTION 'missing valid FK index'; END IF;
 IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.ff_order_items'::regclass) THEN RAISE EXCEPTION 'RLS disabled'; END IF;
END $qa$;
CREATE TEMP TABLE ff_step12_idx_probe ON COMMIT DROP AS SELECT i AS item_id, md5(((i-1)/4)::text)::uuid AS order_id FROM generate_series(1,40000) i;
ANALYZE ff_step12_idx_probe;
DO $probe$
DECLARE before_plan jsonb; after_plan jsonb; before_ids integer[]; after_ids integer[];
BEGIN
 EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) SELECT item_id FROM ff_step12_idx_probe WHERE order_id = md5(''1234'')::uuid' INTO before_plan;
 SELECT array_agg(item_id ORDER BY item_id) INTO before_ids FROM ff_step12_idx_probe WHERE order_id=md5('1234')::uuid;
 CREATE INDEX ff_step12_probe_order_id_idx ON ff_step12_idx_probe(order_id);
 ANALYZE ff_step12_idx_probe;
 EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) SELECT item_id FROM ff_step12_idx_probe WHERE order_id = md5(''1234'')::uuid' INTO after_plan;
 SELECT array_agg(item_id ORDER BY item_id) INTO after_ids FROM ff_step12_idx_probe WHERE order_id=md5('1234')::uuid;
 IF cardinality(before_ids)<>4 OR before_ids IS DISTINCT FROM after_ids THEN RAISE EXCEPTION 'result mismatch'; END IF;
 IF before_plan->0->'Plan'->>'Node Type'<>'Seq Scan' OR after_plan::text NOT LIKE '%Index%' THEN RAISE EXCEPTION 'expected index access path unavailable'; END IF;
END $probe$;
SELECT 'PASS STEP12 order items index: 4 assertions; synthetic access-path probe; rollback' AS result;
ROLLBACK;
