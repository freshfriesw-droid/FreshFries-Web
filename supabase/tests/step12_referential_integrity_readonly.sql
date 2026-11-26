-- STEP12 read-only integrity audit; run against the current database as its administrator.
-- No data exported or changed. All application/storage FKs currently use MATCH SIMPLE.
BEGIN;
SET TRANSACTION READ ONLY;
DO $audit$
DECLARE
  f record;
  bad bigint;
  checked integer := 0;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint c JOIN pg_class cl ON cl.oid=c.conrelid JOIN pg_namespace n ON n.oid=cl.relnamespace WHERE n.nspname IN ('public','ff_private','storage') AND NOT c.convalidated) THEN
    RAISE EXCEPTION 'Unvalidated constraint';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_index i JOIN pg_class cl ON cl.oid=i.indrelid JOIN pg_namespace n ON n.oid=cl.relnamespace WHERE n.nspname IN ('public','ff_private','storage') AND (NOT i.indisvalid OR NOT i.indisready OR NOT i.indislive)) THEN
    RAISE EXCEPTION 'Invalid index';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger t JOIN pg_class cl ON cl.oid=t.tgrelid JOIN pg_namespace n ON n.oid=cl.relnamespace JOIN pg_constraint c ON c.oid=t.tgconstraint WHERE n.nspname IN ('public','ff_private','storage') AND c.contype='f' AND t.tgenabled='D') THEN
    RAISE EXCEPTION 'Disabled FK trigger';
  END IF;
  FOR f IN
    SELECT c.oid,c.confmatchtype,
      format('SELECT count(*) FROM %I.%I s WHERE (%s) AND NOT EXISTS (SELECT 1 FROM %I.%I t WHERE %s)',
      n.nspname,cl.relname,string_agg(format('s.%I IS NOT NULL',a.attname),' AND ' ORDER BY k.ord),
      rn.nspname,rc.relname,string_agg(format('t.%I = s.%I',b.attname,a.attname),' AND ' ORDER BY k.ord)) AS stmt
    FROM pg_constraint c JOIN pg_class cl ON cl.oid=c.conrelid JOIN pg_namespace n ON n.oid=cl.relnamespace
    JOIN pg_class rc ON rc.oid=c.confrelid JOIN pg_namespace rn ON rn.oid=rc.relnamespace
    CROSS JOIN LATERAL unnest(c.conkey,c.confkey) WITH ORDINALITY k(src,dst,ord)
    JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=k.src
    JOIN pg_attribute b ON b.attrelid=c.confrelid AND b.attnum=k.dst
    WHERE n.nspname IN ('public','ff_private','storage') AND c.contype='f'
    GROUP BY c.oid,c.confmatchtype,n.nspname,cl.relname,rn.nspname,rc.relname
  LOOP
    IF f.confmatchtype <> 's' THEN RAISE EXCEPTION 'Audit needs support for FK match type %',f.confmatchtype; END IF;
    EXECUTE f.stmt INTO bad;
    IF bad <> 0 THEN RAISE EXCEPTION 'Foreign key % has % orphan rows',f.oid,bad; END IF;
    checked := checked+1;
  END LOOP;
  IF checked=0 THEN RAISE EXCEPTION 'No foreign keys checked'; END IF;
  RAISE NOTICE 'PASS: % FK relationships checked; no orphan rows',checked;
END
$audit$;
SELECT 'PASS' AS integrity_audit;
ROLLBACK;
