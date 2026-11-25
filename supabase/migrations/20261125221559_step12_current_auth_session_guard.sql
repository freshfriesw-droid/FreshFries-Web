-- STEP12: validate the signed session identifier against the authoritative Auth session.
CREATE OR REPLACE FUNCTION public.ff_step12_session_valid()
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid; v_session uuid; v_claim text;
BEGIN
 v_uid:=auth.uid(); v_claim:=auth.jwt()->>'session_id';
 IF v_uid IS NULL OR v_claim IS NULL OR v_claim !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN RETURN false; END IF;
 v_session:=v_claim::uuid;
 RETURN EXISTS(SELECT 1 FROM auth.sessions s JOIN auth.users u ON u.id=s.user_id
 WHERE s.id=v_session AND s.user_id=v_uid AND u.deleted_at IS NULL
 AND (u.banned_until IS NULL OR u.banned_until<=statement_timestamp())
 AND (s.not_after IS NULL OR s.not_after>statement_timestamp()));
EXCEPTION WHEN invalid_text_representation THEN RETURN false;
END $$;
REVOKE ALL ON FUNCTION public.ff_step12_session_valid() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.ff_step12_session_valid() TO authenticated;

-- Direct, trusted database-admin role simulations do not issue JWTs.
-- Real API/Storage/Realtime sessions must have an authoritative Auth session.
CREATE OR REPLACE FUNCTION public.ff_step12_session_context()
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$
 SELECT CASE WHEN session_user='postgres' AND nullif(current_setting('request.jwt.claims',true),'') IS NULL
 THEN true ELSE public.ff_step12_session_valid() END
$$;
REVOKE ALL ON FUNCTION public.ff_step12_session_context() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.ff_step12_session_context() TO authenticated;

CREATE OR REPLACE FUNCTION public.ff_step12_assert_session()
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
BEGIN
 IF current_setting('role',true)='authenticated' OR auth.jwt()->>'role'='authenticated' THEN
  IF NOT public.ff_step12_session_valid() THEN
   RAISE EXCEPTION USING ERRCODE='PT401', MESSAGE='انتهت جلسة الدخول، يرجى تسجيل الدخول من جديد';
  END IF;
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.ff_step12_assert_session() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ff_step12_assert_session() TO anon,authenticated,service_role;

DO $policy$
DECLARE r record;
BEGIN
 FOR r IN SELECT DISTINCT p.schemaname,p.tablename FROM pg_policies p
 JOIN pg_class c ON c.relname=p.tablename JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname=p.schemaname
 WHERE c.relrowsecurity AND ((p.schemaname='public' AND left(p.tablename,2)='ff') OR (p.schemaname='storage' AND p.tablename='objects'))
 LOOP
  EXECUTE format('CREATE POLICY ff_step12_current_session ON %I.%I AS RESTRICTIVE FOR ALL TO authenticated USING ((SELECT public.ff_step12_session_context())) WITH CHECK ((SELECT public.ff_step12_session_context()))',r.schemaname,r.tablename);
 END LOOP;
END $policy$;

-- Never replace another pre-request hook silently.
DO $config$
BEGIN
 IF EXISTS(SELECT 1 FROM pg_db_role_setting s,unnest(s.setconfig) x WHERE s.setrole='authenticator'::regrole AND x LIKE 'pgrst.db_pre_request=%' AND x<>'pgrst.db_pre_request=public.ff_step12_assert_session') THEN
  RAISE EXCEPTION 'Existing PostgREST pre-request hook needs explicit integration';
 END IF;
END $config$;
ALTER ROLE authenticator SET pgrst.db_pre_request='public.ff_step12_assert_session';
NOTIFY pgrst,'reload config';
