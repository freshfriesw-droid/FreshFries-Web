alter table public.ff_ui_versions
 add column draft_name text not null default '' check (length(draft_name)<=80),
 add column draft_description text not null default '' check (length(draft_description)<=400);

create function public.ff_ui_named_draft(p_role text,p_branch uuid,p_device text,p_pack text,
 p_text text,p_bar text,p_name text,p_description text)
returns bigint language plpgsql security definer set search_path='' as $$
declare revision bigint;
begin
 if nullif(trim(p_name),'') is null then raise exception 'أدخل اسم المسودة'; end if;
 revision:=public.ff_ui_save_draft(p_role,p_branch,p_device,p_pack,p_text,p_bar);
 update public.ff_ui_versions set draft_name=trim(p_name),draft_description=trim(p_description) where id=revision;
 return revision;
end $$;

create function public.ff_ui_rollback(p_current bigint)
returns bigint language plpgsql security definer set search_path='' as $$
declare active_release public.ff_ui_versions; previous_release public.ff_ui_versions; revision bigint;
begin
 if not exists(select from public.ff_profiles where user_id=auth.uid() and active and role='manager')
 then raise exception 'الاستعادة للمدير العام فقط'; end if;
 lock table public.ff_ui_versions in share row exclusive mode;
 select * into strict active_release from public.ff_ui_versions where id=p_current and published_at is not null;
 if active_release.previous_id is null then raise exception 'لا يوجد إصدار سابق لهذا النطاق'; end if;
 if exists(select from public.ff_ui_versions v where v.role_scope=active_release.role_scope and
    v.branch_id is not distinct from active_release.branch_id and v.device=active_release.device
    and (v.published_at,v.id)>(active_release.published_at,active_release.id))
 then raise exception 'تغير الإصدار النشط، حدّث السجل'; end if;
 select * into strict previous_release from public.ff_ui_versions where id=active_release.previous_id;
 revision:=public.ff_ui_save_draft(previous_release.role_scope,previous_release.branch_id,previous_release.device,
   previous_release.pack,previous_release.layout_text,previous_release.bar,previous_release.id);
 update public.ff_ui_versions set draft_name=previous_release.draft_name,
   draft_description=previous_release.draft_description where id=revision;
 perform public.ff_ui_publish(revision);
 return revision;
end $$;
revoke all on function public.ff_ui_named_draft(text,uuid,text,text,text,text,text,text), public.ff_ui_rollback(bigint) from public,anon;
grant execute on function public.ff_ui_named_draft(text,uuid,text,text,text,text,text,text), public.ff_ui_rollback(bigint) to authenticated;

create table public.ff_ui_trials (
 id bigint generated always as identity primary key,
 version_id bigint not null references public.ff_ui_versions,
 recipient uuid not null references public.ff_profiles(user_id),
 started_by uuid not null,
 started_at timestamptz not null default now(),
 ends_at timestamptz not null,
 stopped_at timestamptz,
 stopped_by uuid
);
alter table public.ff_ui_trials enable row level security;
revoke all on public.ff_ui_trials from public,anon,authenticated;
create index ff_ui_trials_active on public.ff_ui_trials(recipient,ends_at) where stopped_at is null;
create function public.ff_ui_trial_accounts(p_id bigint)
returns table(account_id uuid,account_name text)
language sql stable security definer set search_path='' as $$
 select p.user_id,p.display_name::text from public.ff_profiles p join public.ff_ui_versions v on v.id=p_id
 where exists(select from public.ff_profiles m where m.user_id=auth.uid() and m.active and m.role='manager')
 and v.published_at is null and p.active and (v.role_scope='all' or p.role::text=v.role_scope)
 and (v.branch_id is null or p.role='manager' or exists(select from public.ff_user_branches b
 where b.user_id=p.user_id and b.branch_id=v.branch_id)) order by p.display_name,p.user_id
$$;
create function public.ff_ui_control_trial(p_id bigint,p_accounts uuid[],p_hours integer)
returns integer language plpgsql security definer set search_path='' as $$
declare affected integer;
begin
 if not exists(select from public.ff_profiles where user_id=auth.uid() and active and role='manager')
 then raise exception 'الإجراء للمدير العام فقط'; end if;
 perform 1 from public.ff_ui_versions where id=p_id and published_at is null for update;
 if not found then raise exception 'اختر مسودة متاحة';end if;
 if p_hours=0 then
  update public.ff_ui_trials set stopped_at=now(),stopped_by=auth.uid()
  where version_id=p_id and stopped_at is null and ends_at>now();
  get diagnostics affected=row_count;
  return affected;
 end if;
 if p_hours is null or p_hours not in (1,8,24) or coalesce(cardinality(p_accounts),0)=0
 or exists(select account from unnest(p_accounts) account except select account_id from public.ff_ui_trial_accounts(p_id))
 then raise exception 'تحقق من مدة التجربة والحسابات المسموحة'; end if;
 update public.ff_ui_trials set stopped_at=now(),stopped_by=auth.uid()
 where version_id=p_id and stopped_at is null and ends_at>now();
 insert into public.ff_ui_trials(version_id,recipient,started_by,ends_at)
 select distinct p_id,account,auth.uid(),now()+make_interval(hours=>p_hours) from unnest(p_accounts) account;
 get diagnostics affected=row_count;
 return affected;
end $$;
create or replace function public.ff_ui_effective(p_branch uuid,p_device text) returns table(id bigint,pack text,layout_text text,bar text)
language sql stable security definer set search_path='' as $$
 select v.id,v.pack,v.layout_text,v.bar from public.ff_ui_versions v join public.ff_profiles p on p.user_id=auth.uid() and p.active
 left join lateral(select max(t.started_at) as started_at from public.ff_ui_trials t
 where t.version_id=v.id and t.recipient=p.user_id and t.stopped_at is null and t.ends_at>now()
 and v.published_at is null) trial on true
 where (v.published_at is not null or trial.started_at is not null) and (v.role_scope='all' or v.role_scope=p.role::text)
 and (v.branch_id is null or (v.branch_id=p_branch and public.ff_has_branch(v.branch_id)))
 and v.device in ('all',p_device)
 order by (trial.started_at is not null) desc,((v.role_scope<>'all')::int+(v.branch_id is not null)::int+(v.device<>'all')::int) desc,
 (v.role_scope<>'all') desc,(v.branch_id is not null) desc,(v.device<>'all') desc,
 coalesce(trial.started_at,v.published_at) desc,v.id desc limit 1
$$;
revoke all on function public.ff_ui_trial_accounts(bigint),public.ff_ui_control_trial(bigint,uuid[],integer) from public,anon;
grant execute on function public.ff_ui_trial_accounts(bigint),public.ff_ui_control_trial(bigint,uuid[],integer) to authenticated;
