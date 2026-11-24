-- DEC-06 phase 2: cards are part of the same immutable design revision.
-- Null means the built-in four cards; an empty array intentionally hides the KPI area.
alter table public.ff_ui_versions add column card_layout jsonb;
create function public.ff81_validate_cards(p_cards jsonb) returns boolean
language plpgsql immutable set search_path='' as $$
declare card jsonb;
begin
 if p_cards is null then return true;end if;
 if jsonb_typeof(p_cards)<>'array' or octet_length(p_cards::text)>65536 then return false;end if;
 for card in select value from jsonb_array_elements(p_cards) loop
  if jsonb_typeof(card)<>'object' then return false;end if;
  if not (card ?& array['metric','label','size','tone']) or (card-array['metric','label','size','tone'])<>'{}'::jsonb then return false;end if;
  if jsonb_typeof(card->'metric')<>'string' or jsonb_typeof(card->'label')<>'string' or jsonb_typeof(card->'size')<>'string' or jsonb_typeof(card->'tone')<>'string' then return false;end if;
  if card->>'metric' not in ('orders_today','late_today','completed_today','available_drivers')
   or card->>'size' not in ('normal','wide','full') or card->>'tone' not in ('default','red','black','neutral')
   or length(btrim(card->>'label')) not between 1 and 100 or card->>'label' ~ '[<>{}[:cntrl:]]'
   or card->>'label' ~* '(https?://|www\.|javascript:|data:|vbscript:|//)'
   or translate(card->>'label',U&'\061C\200E\200F\202A\202B\202C\202D\202E\2066\2067\2068\2069','')<>card->>'label' then return false;end if;
 end loop;
 return true;
end $$;
alter table public.ff_ui_versions add constraint ff81_card_layout_valid check(public.ff81_validate_cards(card_layout));
create function public.ff81_copy_restored_cards() returns trigger
language plpgsql set search_path='' as $$
begin
 if new.restored_from is not null then
  select v.card_layout into new.card_layout from public.ff_ui_versions v where v.id=new.restored_from;
 end if;
 return new;
end $$;
create trigger ff81_copy_restored_cards before insert on public.ff_ui_versions for each row execute function public.ff81_copy_restored_cards();
create function public.ff81_named_card_draft(p_role text,p_branch uuid,p_device text,p_pack text,p_text text,p_bar text,p_name text,p_description text,p_cards jsonb)
returns bigint language plpgsql security definer set search_path='' as $$
declare revision bigint;
begin
 if auth.uid() is null or not exists(select 1 from public.ff_profiles where user_id=auth.uid() and active and role='manager') then raise exception 'غير مخول';end if;
 if not public.ff81_validate_cards(p_cards) then raise exception 'محتوى البطاقات غير صالح';end if;
 revision:=public.ff_ui_named_draft(p_role,p_branch,p_device,p_pack,p_text,p_bar,p_name,p_description);
 update public.ff_ui_versions set card_layout=p_cards where id=revision and published_at is null;
 return revision;
end $$;
create function public.ff81_effective_cards(p_branch uuid,p_device text,p_revision bigint)
returns jsonb language sql stable security definer set search_path='' as $$
 select v.card_layout from public.ff_ui_versions v join public.ff_ui_effective(p_branch,p_device) e on e.id=v.id
 where auth.uid() is not null and v.id=p_revision
$$;
revoke all on function public.ff81_validate_cards(jsonb),public.ff81_copy_restored_cards(),public.ff81_named_card_draft(text,uuid,text,text,text,text,text,text,jsonb),public.ff81_effective_cards(uuid,text,bigint) from public,anon;
grant execute on function public.ff81_named_card_draft(text,uuid,text,text,text,text,text,text,jsonb),public.ff81_effective_cards(uuid,text,bigint) to authenticated;
