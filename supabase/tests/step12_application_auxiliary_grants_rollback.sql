BEGIN;
DO $qa$
DECLARE v record; role_name text; n bigint; table_checks int:=0; seq_checks int:=0; denial_checks int:=0;
BEGIN
 FOR v IN SELECT c.oid,c.relname,c.relkind FROM pg_class c JOIN pg_namespace ns ON ns.oid=c.relnamespace WHERE ns.nspname='public' AND left(c.relname,2)='ff' AND c.relkind IN('r','p','S') LOOP
  IF v.relkind='S' THEN
   IF has_sequence_privilege('anon',v.oid,'USAGE,SELECT,UPDATE') THEN RAISE EXCEPTION 'anon sequence grant: %',v.relname;END IF;seq_checks:=seq_checks+1;
   IF has_sequence_privilege('authenticated',v.oid,'SELECT,UPDATE') OR (v.relname<>'ff_push_devices_id_seq' AND has_sequence_privilege('authenticated',v.oid,'USAGE')) THEN RAISE EXCEPTION 'authenticated sequence grant: %',v.relname;END IF;seq_checks:=seq_checks+1;
   IF NOT has_sequence_privilege('service_role',v.oid,'USAGE') THEN RAISE EXCEPTION 'service usage lost: %',v.relname;END IF;seq_checks:=seq_checks+1;
  ELSE
   FOREACH role_name IN ARRAY ARRAY['anon','authenticated'] LOOP
    IF has_table_privilege(role_name,v.oid,'TRUNCATE,REFERENCES,TRIGGER,MAINTAIN') THEN RAISE EXCEPTION 'auxiliary table grant: % %',role_name,v.relname;END IF;table_checks:=table_checks+1;
   END LOOP;
  END IF;
 END LOOP;
 IF NOT has_sequence_privilege('authenticated','public.ff_push_devices_id_seq','USAGE') THEN RAISE EXCEPTION 'push usage lost';END IF;
 FOREACH role_name IN ARRAY ARRAY['anon','authenticated'] LOOP
  EXECUTE format('SET LOCAL ROLE %I',role_name);
  BEGIN
   SELECT count(*) INTO n FROM public.ff_audit_log_id_seq;
   RAISE EXCEPTION 'direct audit sequence read permitted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RESET ROLE;
  denial_checks:=denial_checks+1;
 END LOOP;
 IF table_checks<204 OR seq_checks<90 OR denial_checks<>2 THEN RAISE EXCEPTION 'incomplete grant coverage';END IF;
 RAISE NOTICE 'table-role checks %, sequence-role checks %, denial checks %, retained push usage 1',table_checks,seq_checks,denial_checks;
END $qa$;
SELECT 'PASS STEP12 auxiliary grants; 204 table-role and 90 sequence-role checks at current schema, 2 direct read denials and 1 push grant' AS result;
ROLLBACK;
