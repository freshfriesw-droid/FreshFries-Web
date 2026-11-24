-- DEC-09 phase 1: plain-text, immutable, scoped content releases.
-- Only fixed, non-security-critical dashboard and report text targets are registered.
create table public.ff_content_catalog(
 key text primary key,
 screen text not null,
 label text not null,
 original text not null
);
alter table public.ff_content_catalog enable row level security;
revoke all on public.ff_content_catalog from public,anon,authenticated;
insert into public.ff_content_catalog(key,screen,label,original) values
 ('dashboard.title','dashboard','عنوان لوحة التحكم','العنوان الأصلي بحسب الدور'),
 ('dashboard.new','dashboard','زر طلب جديد','طلب جديد'),
 ('dashboard.reserve','dashboard','زر الحجز','📅 حجز للاستلام'),
 ('dashboard.late','dashboard','زر المتابعة','الطلبات المتأخرة'),
 ('reports.title','reports','عنوان مركز التقارير','📊 مركز التقارير الإدارية الموحد'),
 ('reports.subtitle','reports','وصف مركز التقارير','Fresh Fries LUXE — بيانات تشغيلية حسب الصلاحيات والفروع'),
 ('reports.run','reports','زر إعداد التقرير','إعداد التقرير'),
 ('reports.preview','reports','زر معاينة PDF','👁️ معاينة PDF'),
 ('reports.download','reports','زر تصدير PDF','⬇️ تصدير PDF'),
 ('reports.share','reports','زر مشاركة التقرير','📤 مشاركة التقرير'),
 ('reports.csv','reports','زر تصدير CSV','تصدير الأقسام CSV'),
 ('reports.close','reports','زر إغلاق التقرير','✕ إغلاق');

create table public.ff_content_versions(
 id bigint generated always as identity primary key,
 content_key text not null references public.ff_content_catalog(key),
 role_scope text not null check(role_scope in ('all','manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen')),
 branch_id uuid references public.ff_branches(id),
 body text,
 actor_id uuid not null,
 created_at timestamptz not null default now(),
 previous_id bigint references public.ff_content_versions(id),
 published_at timestamptz,
 published_by uuid,
 constraint ff_content_safe_text check(body is null or (
   length(btrim(body)) between 1 and 180 and body !~ '[<>{}]' and body !~ '[[:cntrl:]]'
   and body !~* '(https?://|www\.|javascript:|data:|vbscript:|//)'
   and translate(body,U&'\061C\200E\200F\202A\202B\202C\202D\202E\2066\2067\2068\2069','')=body))
);
alter table public.ff_content_versions enable row level security;
revoke all on public.ff_content_versions from public,anon,authenticated;
create index ff_content_versions_scope on public.ff_content_versions(content_key,role_scope,branch_id,id desc);

create function public.ff_content_catalog_list() returns setof public.ff_content_catalog
language sql stable security definer set search_path='' as $$
 select c.* from public.ff_content_catalog c where auth.uid() is not null and exists(
 select 1 from public.ff_profiles p where p.user_id=auth.uid() and p.active and p.role='manager') order by c.screen,c.key
$$;
create function public.ff_content_history(p_key text) returns setof public.ff_content_versions
language sql stable security definer set search_path='' as $$
 select v.* from public.ff_content_versions v where v.content_key=p_key and auth.uid() is not null and exists(
 select 1 from public.ff_profiles p where p.user_id=auth.uid() and p.active and p.role='manager') order by v.id desc limit 200
$$;
create function public.ff_content_create_draft(p_key text,p_role text,p_branch uuid,p_body text)
returns bigint language plpgsql security definer set search_path='' as $$
declare prior bigint; new_id bigint;
begin
 if auth.uid() is null or not exists(select 1 from public.ff_profiles where user_id=auth.uid() and active and role='manager') then
  raise exception 'تحرير المحتوى للمدير العام فقط'; end if;
 select id into prior from public.ff_content_versions where content_key=p_key and role_scope=p_role
  and branch_id is not distinct from p_branch and published_at is not null order by published_at desc,id desc limit 1;
 insert into public.ff_content_versions(content_key,role_scope,branch_id,body,actor_id,previous_id)
 values(p_key,p_role,p_branch,btrim(p_body),auth.uid(),prior) returning id into new_id;
 return new_id;
end $$;
create function public.ff_content_publish(p_id bigint)
returns void language plpgsql security definer set search_path='' as $$
declare draft public.ff_content_versions; prior bigint;
begin
 if auth.uid() is null or not exists(select 1 from public.ff_profiles where user_id=auth.uid() and active and role='manager') then
  raise exception 'النشر للمدير العام فقط'; end if;
 lock table public.ff_content_versions in share row exclusive mode;
 select * into strict draft from public.ff_content_versions where id=p_id;
 if draft.published_at is not null then return; end if;
 select id into prior from public.ff_content_versions where content_key=draft.content_key and role_scope=draft.role_scope
  and branch_id is not distinct from draft.branch_id and published_at is not null order by published_at desc,id desc limit 1;
 if prior is distinct from draft.previous_id then raise exception 'تغير النص المنشور؛ احفظ مسودة جديدة بعد المراجعة'; end if;
 update public.ff_content_versions set published_at=clock_timestamp(),published_by=auth.uid() where id=p_id;
end $$;
create function public.ff_content_effective(p_branch uuid)
returns table(content_key text,body text,revision bigint)
language sql stable security definer set search_path='' as $$
 select distinct on(v.content_key) v.content_key,v.body,v.id
 from public.ff_content_versions v join public.ff_profiles p on p.user_id=auth.uid() and p.active
 where auth.uid() is not null and v.published_at is not null
 and (v.role_scope='all' or v.role_scope=p.role::text)
 and (v.branch_id is null or (v.branch_id=p_branch and public.ff_has_branch(v.branch_id)))
 order by v.content_key,((v.role_scope<>'all')::int+(v.branch_id is not null)::int) desc,
 (v.role_scope<>'all') desc,(v.branch_id is not null) desc,v.published_at desc,v.id desc
$$;
revoke all on function public.ff_content_catalog_list(),public.ff_content_history(text),public.ff_content_create_draft(text,text,uuid,text),public.ff_content_publish(bigint),public.ff_content_effective(uuid) from public,anon;
grant execute on function public.ff_content_catalog_list(),public.ff_content_history(text),public.ff_content_create_draft(text,text,uuid,text),public.ff_content_publish(bigint),public.ff_content_effective(uuid) to authenticated;
