BEGIN;
CREATE TEMP TABLE step12_direct_read_result(tab text,context text,visible_rows bigint,error_code text) ON COMMIT DROP;
DO $qa$
DECLARE u uuid:=gen_random_uuid();d uuid:=gen_random_uuid();actor uuid; t record; c bigint;ctx text;err text;
BEGIN
 INSERT INTO auth.users(id) VALUES(u),(d);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(d,'QA STEP12 disabled direct reads','cashier',false);
 FOR t IN SELECT n.nspname schema,c.relname tab FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind IN ('r','p') AND has_table_privilege('authenticated',c.oid,'SELECT') ORDER BY c.relname LOOP
  FOREACH actor IN ARRAY ARRAY[u,d] LOOP
   ctx:=CASE WHEN actor=u THEN 'nonstaff' ELSE 'disabled' END;
   c:=NULL;err:=NULL;
   BEGIN
    SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',actor::text,true);
    EXECUTE format('SELECT count(*) FROM %I.%I',t.schema,t.tab) INTO c;
    RESET ROLE;
   EXCEPTION WHEN OTHERS THEN err:=SQLSTATE;RESET ROLE;END;
   INSERT INTO pg_temp.step12_direct_read_result VALUES(t.tab,ctx,c,err);
  END LOOP;
 END LOOP;
END $qa$;
SELECT context,count(*) tested,count(*) FILTER(WHERE visible_rows=0) empty,count(*) FILTER(WHERE error_code IS NOT NULL) errors,coalesce(jsonb_agg(jsonb_build_object('table',tab,'rows',visible_rows,'error',error_code) ORDER BY tab) FILTER(WHERE visible_rows>0 OR error_code IS NOT NULL),'[]') nonempty_or_errors FROM pg_temp.step12_direct_read_result GROUP BY context;
ROLLBACK;
