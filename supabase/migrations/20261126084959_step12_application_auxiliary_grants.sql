SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';
DO $grant_guard$
DECLARE v record;
BEGIN
 FOR v IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind IN ('r','p') AND left(c.relname,2)='ff' LOOP
  EXECUTE format('REVOKE TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLE public.%I FROM anon, authenticated',v.relname);
 END LOOP;
 FOR v IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='S' AND left(c.relname,2)='ff' LOOP
  EXECUTE format('REVOKE SELECT, UPDATE ON SEQUENCE public.%I FROM anon, authenticated',v.relname);
  EXECUTE format('REVOKE USAGE ON SEQUENCE public.%I FROM anon',v.relname);
  IF v.relname<>'ff_push_devices_id_seq' THEN
   EXECUTE format('REVOKE USAGE ON SEQUENCE public.%I FROM authenticated',v.relname);
  END IF;
 END LOOP;
END $grant_guard$;
