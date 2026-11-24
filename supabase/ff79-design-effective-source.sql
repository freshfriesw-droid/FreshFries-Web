-- DEC-03: read-only explanation of the published design matched to a concrete preview scope.
-- The selection mirrors ff_ui_effective's published-version precedence; per-account trials are excluded.
create function public.ff_ui_manager_source(p_role text,p_branch uuid,p_device text)
returns table(id bigint,role_scope text,branch_id uuid,device text,pack text,layout_text text,bar text,published_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.ff_profiles p where p.user_id=auth.uid() and p.active and p.role='manager') then
  raise exception 'عرض مصدر التصميم للمدير العام فقط';
 end if;
 if p_role is null or p_role not in ('manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen')
  or p_device is null or p_device not in ('mobile','desktop') then raise exception 'حدد دوراً وجهازاً للمعاينة';end if;
 if p_branch is not null and not exists(select 1 from public.ff_branches b where b.id=p_branch) then
  raise exception 'الفرع غير موجود';end if;
 return query select v.id,v.role_scope,v.branch_id,v.device,v.pack,v.layout_text,v.bar,v.published_at
 from public.ff_ui_versions v
 where v.published_at is not null and v.role_scope in ('all',p_role)
 and (v.branch_id is null or v.branch_id=p_branch)
 and v.device in ('all',p_device)
 order by ((v.role_scope<>'all')::int+(v.branch_id is not null)::int+(v.device<>'all')::int) desc,
 (v.role_scope<>'all') desc,(v.branch_id is not null) desc,(v.device<>'all') desc,v.published_at desc,v.id desc limit 1;
end $$;
revoke all on function public.ff_ui_manager_source(text,uuid,text) from public,anon;
grant execute on function public.ff_ui_manager_source(text,uuid,text) to authenticated;
