create table public.ff_report_presets (
 owner_id uuid not null references public.ff_profiles(user_id),
 title text not null check(length(title) between 1 and 80),
 sections text[] not null check(cardinality(sections) between 1 and 64),
 trend text not null check(trend in ('daily','weekly','monthly')),
 primary key(owner_id,title)
);
alter table public.ff_report_presets enable row level security;
revoke all on public.ff_report_presets from public,anon,authenticated;
create function public.ff_report_preset_save(p_title text,p_sections text[],p_trend text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select from public.ff_profiles where user_id=auth.uid() and active) then raise exception 'غير مخول';end if;
 if exists(select from unnest(p_sections) s where s is null or s !~ '^[a-z_]{1,40}$') then raise exception 'قسم غير صالح';end if;
 insert into public.ff_report_presets values(auth.uid(),trim(p_title),p_sections,p_trend)
 on conflict(owner_id,title) do update set sections=excluded.sections,trend=excluded.trend;
end $$;
create function public.ff_report_preset_list() returns table(title text,sections text[],trend text)
language sql stable security definer set search_path='' as $$
 select t.title,t.sections,t.trend from public.ff_report_presets t join public.ff_profiles p on p.user_id=t.owner_id and p.active
 where p.user_id=auth.uid() order by t.title
$$;
revoke all on function public.ff_report_preset_save(text,text[],text),public.ff_report_preset_list() from public,anon;
grant execute on function public.ff_report_preset_save(text,text[],text),public.ff_report_preset_list() to authenticated;
