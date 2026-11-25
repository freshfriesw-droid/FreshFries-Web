-- STEP12: legacy dispatch cursor remains server-owned; push registration is staff-only.
revoke insert, update, delete, truncate on public.ff_rr_cursors from public, anon, authenticated;
create policy ff_step12_push_active_insert on public.ff_push_devices as restrictive for insert to authenticated with check (exists (select 1 from public.ff_profiles p where p.user_id=(select auth.uid()) and p.active));
create policy ff_step12_push_active_update on public.ff_push_devices as restrictive for update to authenticated using (exists (select 1 from public.ff_profiles p where p.user_id=(select auth.uid()) and p.active)) with check (exists (select 1 from public.ff_profiles p where p.user_id=(select auth.uid()) and p.active));
