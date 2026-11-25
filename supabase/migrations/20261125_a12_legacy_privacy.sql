-- A12 review: legacy directory and settings were visible to any verified customer.
alter policy ff_central_staff_read on public.ff_staff to authenticated using (public.ff_is_manager());
alter policy ff_central_settings_read on public.ff_app_settings to authenticated using (
 exists(select 1 from public.ff_profiles p where p.user_id=auth.uid() and p.active)
);
alter policy ff_central_roles_read on public.ff_role_permissions to authenticated using (
 exists(select 1 from public.ff_profiles p where p.user_id=auth.uid() and p.active)
);
-- No anon policy exists on these seven tables; remove redundant grants.
revoke all privileges on public.ff_app_settings,public.ff_menu_categories,public.ff_menu_items,public.ff_offers,
 public.ff_role_permissions,public.ff_staff,public.ff_user_permissions from anon;
