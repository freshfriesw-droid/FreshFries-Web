-- DEC-09: server-side exact history filters, before the result limit.
create function public.ff86_content_history_scoped(p_key text,p_role text default null,p_branch uuid default null,p_global_branch boolean default false)
returns setof public.ff_content_versions
language sql stable security definer set search_path='' as $$
 select v.* from public.ff_content_versions v
 where v.content_key=p_key and auth.uid() is not null
 and exists(select 1 from public.ff_profiles p where p.user_id=auth.uid() and p.active and p.role='manager')
 and (p_role is null or v.role_scope=p_role)
 and ((not coalesce(p_global_branch,false) and (p_branch is null or v.branch_id=p_branch))
      or (coalesce(p_global_branch,false) and p_branch is null and v.branch_id is null))
 order by v.id desc limit 200
$$;
revoke all on function public.ff86_content_history_scoped(text,text,uuid,boolean) from public,anon;
grant execute on function public.ff86_content_history_scoped(text,text,uuid,boolean) to authenticated;
