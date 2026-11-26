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
