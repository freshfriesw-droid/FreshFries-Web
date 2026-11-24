-- Evaluate the grant at authorization time, including after a write lock wait.
create or replace function public.ff82_my_grant()
returns setof public.ff82_content_grants
language sql volatile security definer set search_path = '' as $$
  with instant as materialized (select clock_timestamp() as checked_at)
  select g.*
  from public.ff82_content_grants g
  join public.ff_profiles p on p.user_id = g.recipient and p.active and p.role = g.role_scope
  join public.ff_user_branches ub on ub.user_id = p.user_id and ub.branch_id = g.branch_id
  join public.ff_branches b on b.id = g.branch_id and b.active
  cross join instant
  where g.recipient = auth.uid() and g.revoked_at is null
    and instant.checked_at >= g.starts_at and instant.checked_at < g.ends_at
$$;
