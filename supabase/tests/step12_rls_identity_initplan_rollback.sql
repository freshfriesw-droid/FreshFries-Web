-- STEP12: compare old and new policy results; rollback all fixture data and DDL.
-- Synthetic SQL contexts, not a live Auth sign-in. Do not run after unrelated policy changes.
BEGIN;
CREATE TEMP TABLE step12_rls_result(phase int, context text, tab text, n bigint, digest text, error_code text, PRIMARY KEY(phase,context,tab)) ON COMMIT DROP;
CREATE TEMP TABLE step12_rls_ctx(context text PRIMARY KEY, actor uuid, session_id uuid) ON COMMIT DROP;
CREATE TEMP TABLE step12_rls_policy_before AS SELECT * FROM pg_policies WHERE schemaname='public' AND policyname IN ('ff_profiles_read','ff_user_branches_read','ff_branches_read','ff_customers_authenticated_insert','ff_central_user_permissions_read','ff_central_settings_read','ff_central_roles_read','ff_audit_authenticated_insert','ff_customer_notes_insert','ff_customers_branch_read','ff_customer_notes_read','ff27_branch_updates_read');
CREATE TEMP TABLE step12_rls_plan(phase int, initplans int) ON COMMIT DROP;
DO $qa$
DECLARE a uuid; s uuid; ba uuid:=gen_random_uuid(); bb uuid:=gen_random_uuid(); oa uuid:=gen_random_uuid(); ob uuid:=gen_random_uuid(); m uuid; cid uuid:=gen_random_uuid(); p_name text; p_role text; c record; t text; n bigint; digest text; err text; plan json; plans int[]:=ARRAY[]::int[]; v_phase int; total int;
BEGIN
  IF (SELECT count(*) FROM pg_temp.step12_rls_policy_before)<>12 THEN RAISE EXCEPTION 'Policy count';END IF;
  -- Evaluate the stable session identity once per statement; preserve all other predicates, roles and grants.
ALTER POLICY ff27_branch_updates_read ON public.ff27_branch_updates USING ((EXISTS ( SELECT 1
   FROM ((ff_profiles p
     JOIN ff_user_branches ub ON ((ub.user_id = p.user_id)))
     JOIN ff_branches b ON (((b.id = ub.branch_id) AND b.active)))
  WHERE ((p.user_id = auth.uid()) AND p.active AND (ub.branch_id = ff27_branch_updates.branch_id) AND ((p.role = 'cashier'::text) OR ((p.role = 'assembly'::text) AND (((ff_v12_assembly_me() -> 'branch'::text) ->> 'id'::text) = (ff27_branch_updates.branch_id)::text)))))));
ALTER POLICY ff_audit_authenticated_insert ON public.ff_audit_log WITH CHECK (((actor_id = auth.uid()) AND ((branch_id IS NULL) OR ff_has_branch(branch_id))));
ALTER POLICY ff_branches_read ON public.ff_branches USING ((auth.uid() IS NOT NULL));
ALTER POLICY ff_central_roles_read ON public.ff_role_permissions USING ((EXISTS ( SELECT 1
   FROM ff_profiles p
  WHERE ((p.user_id = auth.uid()) AND p.active))));
ALTER POLICY ff_central_settings_read ON public.ff_app_settings USING ((EXISTS ( SELECT 1
   FROM ff_profiles p
  WHERE ((p.user_id = auth.uid()) AND p.active))));
ALTER POLICY ff_central_user_permissions_read ON public.ff_user_permissions USING ((user_id = auth.uid()));
ALTER POLICY ff_customer_notes_insert ON public.ff_customer_notes WITH CHECK (((created_by = auth.uid()) AND (ff_is_manager() OR (EXISTS ( SELECT 1
   FROM ff_orders o
  WHERE ((o.customer_id = ff_customer_notes.customer_id) AND ff_has_branch(o.branch_id)))))));
ALTER POLICY ff_customer_notes_read ON public.ff_customer_notes USING ((EXISTS ( SELECT 1
   FROM ff_profiles p
  WHERE ((p.user_id = auth.uid()) AND p.active AND (p.role = ANY (ARRAY['manager'::text, 'customer_service'::text]))))));
ALTER POLICY ff_customers_authenticated_insert ON public.ff_customers WITH CHECK ((created_by = auth.uid()));
ALTER POLICY ff_customers_branch_read ON public.ff_customers USING ((EXISTS ( SELECT 1
   FROM ff_profiles p
  WHERE ((p.user_id = auth.uid()) AND p.active AND (p.role = ANY (ARRAY['manager'::text, 'customer_service'::text]))))));
ALTER POLICY ff_profiles_read ON public.ff_profiles USING (((user_id = auth.uid()) OR ff_is_manager()));
ALTER POLICY ff_user_branches_read ON public.ff_user_branches USING (((user_id = auth.uid()) OR ff_is_manager()));

  INSERT INTO public.ff_branches(id,code,name) VALUES(ba,'qa-rls-'||ba,'QA STEP12 RLS A'),(bb,'qa-rls-'||bb,'QA STEP12 RLS B');
  FOREACH p_name IN ARRAY ARRAY['manager','customer_service','cashier_a','cashier_b','driver','assembly','supervisor','burger_kitchen','disabled_cashier','nonstaff','revoked_cashier','no_session'] LOOP
    a:=gen_random_uuid();s:=gen_random_uuid();
    INSERT INTO auth.users(id) VALUES(a);
    p_role:=CASE WHEN p_name IN ('cashier_a','cashier_b','disabled_cashier','revoked_cashier','no_session') THEN 'cashier' ELSE p_name END;
    IF p_name<>'nonstaff' THEN INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(a,'QA STEP12 initplan '||p_name,p_role,p_name<>'disabled_cashier');END IF;
    IF p_role NOT IN ('manager','customer_service','nonstaff') THEN INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(a,CASE WHEN p_name='cashier_b' THEN bb ELSE ba END);END IF;
    IF p_name NOT IN ('revoked_cashier','no_session') THEN INSERT INTO auth.sessions(id,user_id,created_at,updated_at) VALUES(s,a,now(),now());END IF;
    INSERT INTO pg_temp.step12_rls_ctx VALUES(p_name,a,CASE WHEN p_name='no_session' THEN NULL ELSE s END);
    IF p_name='manager' THEN m:=a;END IF;
  END LOOP;
  INSERT INTO public.ff_customers(id,phone,name,created_by) VALUES(cid,'000'||replace(cid::text,'-',''),'QA STEP12 synthetic',m);
  INSERT INTO public.ff_customer_notes(customer_id,note,created_by) VALUES(cid,'QA STEP12 synthetic',m);
  INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,status,customer_id) VALUES(oa,-1000000000000-floor(random()*1e12)::bigint,ba,'000000000',public.ff_business_date(now()),'new',cid),(ob,-1000000000000-floor(random()*1e12)::bigint,bb,'000000000',public.ff_business_date(now()),'new',cid);
  INSERT INTO public.ff27_branch_updates(order_id,branch_id) VALUES(oa,ba),(ob,bb) ON CONFLICT(order_id) DO UPDATE SET branch_id=excluded.branch_id;
  FOR v_phase IN 1..2 LOOP
    IF v_phase=2 THEN
      -- Evaluate the stable session identity once per statement; preserve all other predicates, roles and grants.
ALTER POLICY ff27_branch_updates_read ON public.ff27_branch_updates USING ((EXISTS ( SELECT 1
   FROM ((ff_profiles p
     JOIN ff_user_branches ub ON ((ub.user_id = p.user_id)))
     JOIN ff_branches b ON (((b.id = ub.branch_id) AND b.active)))
  WHERE ((p.user_id = (SELECT auth.uid())) AND p.active AND (ub.branch_id = ff27_branch_updates.branch_id) AND ((p.role = 'cashier'::text) OR ((p.role = 'assembly'::text) AND (((ff_v12_assembly_me() -> 'branch'::text) ->> 'id'::text) = (ff27_branch_updates.branch_id)::text)))))));
ALTER POLICY ff_audit_authenticated_insert ON public.ff_audit_log WITH CHECK (((actor_id = (SELECT auth.uid())) AND ((branch_id IS NULL) OR ff_has_branch(branch_id))));
ALTER POLICY ff_branches_read ON public.ff_branches USING (((SELECT auth.uid()) IS NOT NULL));
ALTER POLICY ff_central_roles_read ON public.ff_role_permissions USING ((EXISTS ( SELECT 1
   FROM ff_profiles p
  WHERE ((p.user_id = (SELECT auth.uid())) AND p.active))));
ALTER POLICY ff_central_settings_read ON public.ff_app_settings USING ((EXISTS ( SELECT 1
   FROM ff_profiles p
  WHERE ((p.user_id = (SELECT auth.uid())) AND p.active))));
ALTER POLICY ff_central_user_permissions_read ON public.ff_user_permissions USING ((user_id = (SELECT auth.uid())));
ALTER POLICY ff_customer_notes_insert ON public.ff_customer_notes WITH CHECK (((created_by = (SELECT auth.uid())) AND (ff_is_manager() OR (EXISTS ( SELECT 1
   FROM ff_orders o
  WHERE ((o.customer_id = ff_customer_notes.customer_id) AND ff_has_branch(o.branch_id)))))));
ALTER POLICY ff_customer_notes_read ON public.ff_customer_notes USING ((EXISTS ( SELECT 1
   FROM ff_profiles p
  WHERE ((p.user_id = (SELECT auth.uid())) AND p.active AND (p.role = ANY (ARRAY['manager'::text, 'customer_service'::text]))))));
ALTER POLICY ff_customers_authenticated_insert ON public.ff_customers WITH CHECK ((created_by = (SELECT auth.uid())));
ALTER POLICY ff_customers_branch_read ON public.ff_customers USING ((EXISTS ( SELECT 1
   FROM ff_profiles p
  WHERE ((p.user_id = (SELECT auth.uid())) AND p.active AND (p.role = ANY (ARRAY['manager'::text, 'customer_service'::text]))))));
ALTER POLICY ff_profiles_read ON public.ff_profiles USING (((user_id = (SELECT auth.uid())) OR ff_is_manager()));
ALTER POLICY ff_user_branches_read ON public.ff_user_branches USING (((user_id = (SELECT auth.uid())) OR ff_is_manager()));

    END IF;
    FOR c IN SELECT * FROM pg_temp.step12_rls_ctx ORDER BY context LOOP
      FOREACH t IN ARRAY ARRAY['ff_profiles','ff_user_branches','ff_branches','ff_user_permissions','ff_app_settings','ff_role_permissions','ff_customers','ff_customer_notes','ff27_branch_updates'] LOOP
        n:=NULL;digest:=NULL;err:=NULL;
        BEGIN
          SET LOCAL ROLE authenticated;
          PERFORM set_config('request.jwt.claim.sub',c.actor::text,true);
          PERFORM set_config('request.jwt.claims',jsonb_strip_nulls(jsonb_build_object('sub',c.actor,'role','authenticated','session_id',c.session_id))::text,true);
          EXECUTE format('SELECT count(*), md5(coalesce(string_agg(md5(to_jsonb(x)::text), '','' ORDER BY md5(to_jsonb(x)::text)),'''')) FROM public.%I x',t) INTO n,digest;
          IF c.context='cashier_a' AND t='ff_user_branches' THEN
            EXECUTE 'EXPLAIN (FORMAT JSON) SELECT * FROM public.ff_user_branches' INTO plan;
            plans:=array_append(plans,(SELECT count(*)::int FROM regexp_matches(plan::text,'"Subplan Name"\s*:\s*"InitPlan','g')));
          END IF;
          RESET ROLE;
        EXCEPTION WHEN OTHERS THEN err:=SQLSTATE;RESET ROLE;END;
        INSERT INTO pg_temp.step12_rls_result VALUES(v_phase,c.context,t,n,digest,err);
      END LOOP;
    END LOOP;
  END LOOP;
  IF EXISTS(SELECT 1 FROM pg_temp.step12_rls_result WHERE error_code IS NOT NULL) THEN RAISE EXCEPTION 'Read errors: %',(SELECT jsonb_agg(jsonb_build_array(phase,context,tab,error_code)) FROM pg_temp.step12_rls_result WHERE error_code IS NOT NULL);END IF;
  IF EXISTS(SELECT 1 FROM pg_temp.step12_rls_result a JOIN pg_temp.step12_rls_result b USING(context,tab) WHERE a.phase=1 AND b.phase=2 AND (a.n,a.digest) IS DISTINCT FROM (b.n,b.digest)) THEN RAISE EXCEPTION 'Visibility differs';END IF;
  SELECT count(*) INTO total FROM pg_temp.step12_rls_result r WHERE r.phase=2;
  IF total<>108 THEN RAISE EXCEPTION 'Unexpected checks %',total;END IF;
  IF EXISTS(SELECT 1 FROM pg_temp.step12_rls_policy_before a JOIN pg_policies b USING(schemaname,tablename,policyname) WHERE (a.permissive,a.roles,a.cmd) IS DISTINCT FROM (b.permissive,b.roles,b.cmd)) THEN RAISE EXCEPTION 'Policy scope changed';END IF;
  IF array_length(plans,1)<>2 OR plans[2]<=plans[1] THEN RAISE EXCEPTION 'No added initplan: %',plans;END IF;
  INSERT INTO pg_temp.step12_rls_plan VALUES(1,plans[1]),(2,plans[2]);
  IF has_table_privilege('authenticated','public.ff_customers','INSERT') OR has_table_privilege('authenticated','public.ff_customer_notes','INSERT') OR has_table_privilege('authenticated','public.ff_audit_log','INSERT') THEN RAISE EXCEPTION 'Unexpected direct insert grant';END IF;
END $qa$;
SELECT 'PASS' AS result, count(*) FILTER(WHERE phase=2) AS equivalent_context_table_pairs,(SELECT initplans FROM pg_temp.step12_rls_plan WHERE phase=1) AS before_initplans,(SELECT initplans FROM pg_temp.step12_rls_plan WHERE phase=2) AS after_initplans FROM pg_temp.step12_rls_result;
ROLLBACK;
