-- DEC-10 phase 1: explicit account, current role, branch, screen and time bound text delegation.
-- A single current grant per account prevents overlapping grants from broadening authority.
create table public.ff82_content_grants(
 id bigint generated always as identity primary key,
 recipient uuid not null references public.ff_profiles(user_id),
 role_scope text not null,
 branch_id uuid not null references public.ff_branches(id),
 screen text not null,
 capabilities text[] not null check(cardinality(capabilities)>0 and capabilities <@ array['view','edit','preview','review']::text[]),
 starts_at timestamptz not null,
 ends_at timestamptz not null check(ends_at>starts_at),
 granted_by uuid not null,
 created_at timestamptz not null default now(),
 revoked_at timestamptz, revoked_by uuid
);
create unique index ff82_one_current_grant on public.ff82_content_grants(recipient) where revoked_at is null;
alter table public.ff82_content_grants enable row level security;
revoke all on public.ff82_content_grants from public,anon,authenticated;
create table public.ff82_content_audit(
 id bigint generated always as identity primary key, actor_id uuid not null,
 grant_id bigint references public.ff82_content_grants(id),
 action text not null, outcome text not null, reason text not null default '',
 content_key text, revision_id bigint references public.ff_content_versions(id),
 created_at timestamptz not null default now()
);
alter table public.ff82_content_audit enable row level security;
revoke all on public.ff82_content_audit from public,anon,authenticated;
create table public.ff82_content_reviews(
 id bigint generated always as identity primary key,
 revision_id bigint not null references public.ff_content_versions(id),
 grant_id bigint not null references public.ff82_content_grants(id),
 reviewer uuid not null, note text not null check(length(btrim(note)) between 1 and 500 and note !~ '[<>{}[:cntrl:]]' and note !~* '(https?://|www\.|javascript:|data:|vbscript:|//)' and translate(note,U&'\061C\200E\200F\202A\202B\202C\202D\202E\2066\2067\2068\2069','')=note),
 created_at timestamptz not null default now()
);
alter table public.ff82_content_reviews enable row level security;
revoke all on public.ff82_content_reviews from public,anon,authenticated;

create function public.ff82_manager_accounts()
returns table(user_id uuid,display_name text,role text,branch_id uuid,branch_name text)
language sql stable security definer set search_path='' as $$
 select p.user_id,p.display_name,p.role,b.id,b.name
 from public.ff_profiles p join public.ff_user_branches ub on ub.user_id=p.user_id join public.ff_branches b on b.id=ub.branch_id
 where auth.uid() is not null and public.ff_is_manager() and p.active and p.role<>'manager' and b.active
 order by p.display_name,b.name
$$;
create function public.ff82_manager_grants() returns setof public.ff82_content_grants
language sql stable security definer set search_path='' as $$
 select g.* from public.ff82_content_grants g where auth.uid() is not null and public.ff_is_manager() order by g.id desc limit 200
$$;
create function public.ff82_set_grant(p_recipient uuid,p_branch uuid,p_screen text,p_capabilities text[],p_start timestamptz,p_end timestamptz)
returns bigint language plpgsql security definer set search_path='' as $$
declare r text; new_id bigint; old_id bigint;
begin
 if auth.uid() is null or not public.ff_is_manager() then raise exception 'إدارة التفويض للمدير العام فقط';end if;
 select a.role into r from public.ff82_manager_accounts() a where a.user_id=p_recipient and a.branch_id=p_branch;
 if r is null or not exists(select 1 from public.ff_content_catalog c where c.screen=p_screen)
 or p_start is null or p_end is null or p_end<=greatest(p_start,now()) or p_capabilities is null or cardinality(p_capabilities)=0
 or array_position(p_capabilities,null) is not null or not(p_capabilities <@ array['view','edit','preview','review']::text[])
 then raise exception 'تحقق من الحساب والفرع والواجهة والصلاحيات والمدة';end if;
 lock table public.ff82_content_grants in share row exclusive mode;
 update public.ff82_content_grants set revoked_at=clock_timestamp(),revoked_by=auth.uid()
 where recipient=p_recipient and revoked_at is null returning id into old_id;
 if old_id is not null then insert into public.ff82_content_audit(actor_id,grant_id,action,outcome,reason) values(auth.uid(),old_id,'revoke','allowed','replaced');end if;
 insert into public.ff82_content_grants(recipient,role_scope,branch_id,screen,capabilities,starts_at,ends_at,granted_by)
 values(p_recipient,r,p_branch,p_screen,p_capabilities,p_start,p_end,auth.uid()) returning id into new_id;
 insert into public.ff82_content_audit(actor_id,grant_id,action,outcome) values(auth.uid(),new_id,'grant','allowed');
 return new_id;
end $$;
create function public.ff82_revoke_grant(p_id bigint) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.ff_is_manager() then raise exception 'إلغاء التفويض للمدير العام فقط';end if;
 update public.ff82_content_grants set revoked_at=clock_timestamp(),revoked_by=auth.uid() where id=p_id and revoked_at is null;
 if not found then return false;end if;
 insert into public.ff82_content_audit(actor_id,grant_id,action,outcome) values(auth.uid(),p_id,'revoke','allowed');
 return true;
end $$;
create function public.ff82_my_grant() returns setof public.ff82_content_grants
language sql stable security definer set search_path='' as $$
 select g.* from public.ff82_content_grants g join public.ff_profiles p on p.user_id=g.recipient and p.active and p.role=g.role_scope
 join public.ff_user_branches ub on ub.user_id=p.user_id and ub.branch_id=g.branch_id
 where g.recipient=auth.uid() and g.revoked_at is null and now()>=g.starts_at and now()<g.ends_at
$$;
create function public.ff82_delegate_catalog() returns setof public.ff_content_catalog
language sql stable security definer set search_path='' as $$
 select c.* from public.ff_content_catalog c join public.ff82_my_grant() g on g.screen=c.screen
 where g.capabilities && array['view','edit','preview','review']::text[] order by c.key
$$;
create function public.ff82_delegate_history(p_key text) returns setof public.ff_content_versions
language sql stable security definer set search_path='' as $$
 select v.* from public.ff_content_versions v join public.ff_content_catalog c on c.key=v.content_key
 join public.ff82_my_grant() g on g.screen=c.screen and g.role_scope=v.role_scope and g.branch_id=v.branch_id
 where v.content_key=p_key and g.capabilities && array['view','preview','review','edit']::text[]
 and (v.published_at is not null or v.actor_id=auth.uid() or 'review'=any(g.capabilities)) order by v.id desc limit 100
$$;
create function public.ff82_delegate_draft(p_key text,p_body text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.ff82_content_grants; prior bigint; revision bigint; why text;
begin
 if auth.uid() is null then return jsonb_build_object('ok',false,'reason','authentication');end if;
 -- Serialize write with revocation and replacement. Recheck using the current grant after locking.
 lock table public.ff82_content_grants in share mode;
 select * into g from public.ff82_my_grant();
 if g.id is null or not('edit'=any(g.capabilities)) or not exists(select 1 from public.ff_content_catalog c where c.key=p_key and c.screen=g.screen) then why:='outside_edit_scope';
 elsif p_body is null then why:='restore_manager_only';
 else
  select id into prior from public.ff_content_versions where content_key=p_key and role_scope=g.role_scope and branch_id=g.branch_id and published_at is not null order by published_at desc,id desc limit 1;
  begin
   insert into public.ff_content_versions(content_key,role_scope,branch_id,body,actor_id,previous_id)
   values(p_key,g.role_scope,g.branch_id,btrim(p_body),auth.uid(),prior) returning id into revision;
  exception when check_violation then why:='invalid_text';end;
 end if;
 insert into public.ff82_content_audit(actor_id,grant_id,action,outcome,reason,content_key,revision_id)
 values(auth.uid(),g.id,'draft',case when why is null then 'allowed' else 'denied' end,coalesce(why,''),left(p_key,150),revision);
 return jsonb_build_object('ok',why is null,'reason',why,'revision',revision);
end $$;
create function public.ff82_delegate_review(p_revision bigint,p_note text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.ff82_content_grants; v public.ff_content_versions; why text;
begin
 if auth.uid() is null then return jsonb_build_object('ok',false,'reason','authentication');end if;
 lock table public.ff82_content_grants in share mode;
 select * into g from public.ff82_my_grant();
 select * into v from public.ff_content_versions where id=p_revision;
 if g.id is null or not('review'=any(g.capabilities)) or v.id is null or v.published_at is not null or v.role_scope<>g.role_scope or v.branch_id is distinct from g.branch_id
 or not exists(select 1 from public.ff_content_catalog c where c.key=v.content_key and c.screen=g.screen) then why:='outside_review_scope';
 else
  begin insert into public.ff82_content_reviews(revision_id,grant_id,reviewer,note) values(v.id,g.id,auth.uid(),btrim(p_note));
  exception when check_violation or not_null_violation then why:='invalid_note';end;
 end if;
 insert into public.ff82_content_audit(actor_id,grant_id,action,outcome,reason,revision_id)
 values(auth.uid(),g.id,'review',case when why is null then 'allowed' else 'denied' end,coalesce(why,''),case when why is null then v.id end);
 return jsonb_build_object('ok',why is null,'reason',why);
end $$;
create function public.ff82_manager_audit() returns setof public.ff82_content_audit
language sql stable security definer set search_path='' as $$
 select a.* from public.ff82_content_audit a where auth.uid() is not null and public.ff_is_manager() order by a.id desc limit 200
$$;
create function public.ff82_manager_reviews(p_revision bigint) returns setof public.ff82_content_reviews
language sql stable security definer set search_path='' as $$
 select r.* from public.ff82_content_reviews r where auth.uid() is not null and public.ff_is_manager() and r.revision_id=p_revision order by r.id desc
$$;
revoke all on function public.ff82_manager_accounts(),public.ff82_manager_grants(),public.ff82_set_grant(uuid,uuid,text,text[],timestamptz,timestamptz),public.ff82_revoke_grant(bigint),public.ff82_my_grant(),public.ff82_delegate_catalog(),public.ff82_delegate_history(text),public.ff82_delegate_draft(text,text),public.ff82_delegate_review(bigint,text),public.ff82_manager_audit(),public.ff82_manager_reviews(bigint) from public,anon;
grant execute on function public.ff82_manager_accounts(),public.ff82_manager_grants(),public.ff82_set_grant(uuid,uuid,text,text[],timestamptz,timestamptz),public.ff82_revoke_grant(bigint),public.ff82_my_grant(),public.ff82_delegate_catalog(),public.ff82_delegate_history(text),public.ff82_delegate_draft(text,text),public.ff82_delegate_review(bigint,text),public.ff82_manager_audit(),public.ff82_manager_reviews(bigint) to authenticated;
