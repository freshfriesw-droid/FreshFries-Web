-- Catalog-only regression: no operational rows are read or modified.
DO $qa$
DECLARE n int;
BEGIN
 SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace
 WHERE s.nspname IN ('public','ff_private') AND c.relkind IN ('r','p') AND NOT c.relrowsecurity;
 IF n<>0 THEN RAISE EXCEPTION 'Missing RLS: %',n; END IF;
 IF has_schema_privilege('anon','ff_private','USAGE') OR has_schema_privilege('authenticated','ff_private','USAGE') THEN RAISE EXCEPTION 'Private schema exposed'; END IF;
 SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace
 WHERE s.nspname='ff_private' AND p.proname IN ('ff_burger_event_and_notify','ff_case_order_push','ff_f01_anomaly_notice','ff_f01_stamp_order')
 AND NOT has_function_privilege('anon',p.oid,'EXECUTE') AND NOT has_function_privilege('authenticated',p.oid,'EXECUTE');
 IF n<>4 THEN RAISE EXCEPTION 'Trigger grants not hardened: %',n; END IF;
 SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace
 WHERE s.nspname IN ('public','ff_private') AND p.prosecdef AND NOT EXISTS(SELECT 1 FROM unnest(p.proconfig) v WHERE v LIKE 'search_path=%');
 IF n<>0 THEN RAISE EXCEPTION 'Definer without fixed search_path'; END IF;
 SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace
 WHERE s.nspname IN ('public','ff_private') AND c.relkind IN ('r','p') AND has_table_privilege('anon',c.oid,'SELECT,INSERT,UPDATE,DELETE');
 IF n<>0 THEN RAISE EXCEPTION 'Unexpected anonymous direct table grant'; END IF;
END $qa$;
SELECT 'PASS STEP12: RLS, private schema, trigger grants, definer search_path and anon table grants' AS result;
