-- Immutable revisions. A branch-specific design is read only within that branch.
create table public.ff_ui_versions (
 id bigint generated always as identity primary key,
 role_scope text not null check(role_scope in ('all','manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen')),
 branch_id uuid references public.ff_branches(id),
 device text not null check(device in ('all','mobile','desktop')),
 pack text not null check(pack ~ '^D(0[1-9]|1[0-6])$'),
 layout_text text not null check(length(layout_text)<=180 and layout_text !~ '[<>]'),
 bar text not null check(bar in ('labels','icons','wide','floating','compact')),
 actor_id uuid not null,
 created_at timestamptz not null default now(),
 published_at timestamptz,
 published_by uuid,
 previous_id bigint references public.ff_ui_versions,
 restored_from bigint references public.ff_ui_versions
);
alter table public.ff_ui_versions enable row level security;
revoke all on public.ff_ui_versions from public,anon,authenticated;
create index ff_ui_versions_scope_idx on public.ff_ui_versions(role_scope,branch_id,device,id desc);
create function public.ff_ui_manager_history() returns setof public.ff_ui_versions
language sql stable security definer set search_path='' as $$
 select v.* from public.ff_ui_versions v where exists(select from public.ff_profiles p where p.user_id=auth.uid() and p.active and p.role='manager') order by v.id desc limit 200
$$;
create function public.ff_ui_save_draft(p_role text,p_branch uuid,p_device text,p_pack text,p_text text,p_bar text,p_restore bigint default null)
returns bigint language plpgsql security definer set search_path='' as $$
declare new_id bigint; prior bigint; old public.ff_ui_versions;
begin
 if not exists(select from public.ff_profiles where user_id=auth.uid() and active and role='manager') then raise exception 'غير مخول'; end if;
 if p_restore is not null then
  select * into strict old from public.ff_ui_versions where id=p_restore and published_at is not null;
  p_role:=old.role_scope;p_branch:=old.branch_id;p_device:=old.device;p_pack:=old.pack;p_text:=old.layout_text;p_bar:=old.bar;
 end if;
 select id into prior from public.ff_ui_versions where role_scope=p_role and branch_id is not distinct from p_branch and device=p_device and published_at is not null order by published_at desc,id desc limit 1;
 insert into public.ff_ui_versions(role_scope,branch_id,device,pack,layout_text,bar,actor_id,previous_id,restored_from)
 values(p_role,p_branch,p_device,p_pack,p_text,p_bar,auth.uid(),prior,p_restore) returning id into new_id;
 return new_id;
end $$;
create function public.ff_ui_publish(p_id bigint) returns void language plpgsql security definer set search_path='' as $$
declare draft public.ff_ui_versions; prior bigint;
begin
 if not exists(select from public.ff_profiles where user_id=auth.uid() and active and role='manager') then raise exception 'غير مخول';end if;
 lock table public.ff_ui_versions in share row exclusive mode;
 select * into strict draft from public.ff_ui_versions where id=p_id;
 if draft.published_at is not null then return;end if;
 select id into prior from public.ff_ui_versions where role_scope=draft.role_scope and branch_id is not distinct from draft.branch_id and device=draft.device and published_at is not null order by published_at desc,id desc limit 1;
 if prior is distinct from draft.previous_id then raise exception 'تغير الإصدار المنشور. راجع التعديلات واحفظ مسودة جديدة';end if;
 update public.ff_ui_versions set published_by=auth.uid(),published_at=clock_timestamp() where id=p_id;
end $$;
create function public.ff_ui_effective(p_branch uuid,p_device text) returns table(id bigint,pack text,layout_text text,bar text)
language sql stable security definer set search_path='' as $$
 select v.id,v.pack,v.layout_text,v.bar from public.ff_ui_versions v join public.ff_profiles p on p.user_id=auth.uid() and p.active
 where v.published_at is not null and (v.role_scope='all' or v.role_scope=p.role::text)
 and (v.branch_id is null or (v.branch_id=p_branch and public.ff_has_branch(v.branch_id)))
 and v.device in ('all',p_device)
 order by (v.branch_id is not null) desc,(v.role_scope<>'all') desc,(v.device<>'all') desc,v.published_at desc,v.id desc limit 1
$$;
revoke all on function public.ff_ui_manager_history(),public.ff_ui_save_draft(text,uuid,text,text,text,text,bigint),public.ff_ui_publish(bigint),public.ff_ui_effective(uuid,text) from public,anon;
grant execute on function public.ff_ui_manager_history(),public.ff_ui_save_draft(text,uuid,text,text,text,text,bigint),public.ff_ui_publish(bigint),public.ff_ui_effective(uuid,text) to authenticated;
