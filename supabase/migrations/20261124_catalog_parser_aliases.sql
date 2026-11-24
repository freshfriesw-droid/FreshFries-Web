alter table public.ff_menu_items add column parser_aliases text[];
alter table public.ff_offers add column parser_aliases text[];

-- Extend the existing catalog responses, keeping their role checks and media fields.
do $upgrade$
declare s text;
begin
 s:=pg_get_functiondef('public.ff49_catalog()'::regprocedure);
 if position('''image_path'',m.extra' in s)=0 or position('''image_path'',o.details' in s)=0 then raise exception 'Unexpected catalog shape'; end if;
 execute replace(replace(s,'''image_path'',m.extra','''parser_aliases'',m.parser_aliases,''image_path'',m.extra'),
   '''image_path'',o.details','''parser_aliases'',o.parser_aliases,''image_path'',o.details');
 s:=pg_get_functiondef('public.ff51_manager_catalog()'::regprocedure);
 if position('sort_order FROM public.ff_menu_items' in s)=0 or position('details FROM public.ff_offers' in s)=0 then raise exception 'Unexpected manager catalog shape'; end if;
 execute replace(replace(s,'sort_order FROM public.ff_menu_items','sort_order,parser_aliases FROM public.ff_menu_items'),
   'details FROM public.ff_offers','details,parser_aliases FROM public.ff_offers');
end $upgrade$;

create function public.ff_save_catalog_parser_aliases(p_kind text,p_id uuid,p_expected text[],p_aliases text[]) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.ff_profiles where user_id=auth.uid() and active and role='manager') then
  raise exception 'إدارة مرادفات المنيو للمدير العام' using errcode='42501'; end if;
 if p_aliases is not null and (cardinality(p_aliases)>100 or exists(
  select 1 from unnest(p_aliases) a where a is null or a<>trim(a) or length(a) not between 1 and 120 or a ~ '[[:cntrl:]|]'
 )) then raise exception 'راجع المرادفات: كل مرادف في سطر مستقل وبحد أقصى 120 حرفًا'; end if;
 if p_kind='item' then
  update public.ff_menu_items set parser_aliases=p_aliases where id=p_id and parser_aliases is not distinct from p_expected;
 elsif p_kind='offer' then
  update public.ff_offers set parser_aliases=p_aliases where id=p_id and parser_aliases is not distinct from p_expected;
 else raise exception 'نوع غير صحيح'; end if;
 if not found then raise exception 'تغيّرت المرادفات أو حُذف الصنف؛ حدّث المنيو وراجع التعديل'; end if;
 insert into public.ff_audit_log(actor_id,action,entity_type,entity_id,details)
 values(auth.uid(),'catalog_parser_aliases_changed',p_kind,p_id::text,jsonb_build_object('before',p_expected,'after',p_aliases));
end $$;
revoke all on function public.ff_save_catalog_parser_aliases(text,uuid,text[],text[]) from public,anon;
grant execute on function public.ff_save_catalog_parser_aliases(text,uuid,text[],text[]) to authenticated;
