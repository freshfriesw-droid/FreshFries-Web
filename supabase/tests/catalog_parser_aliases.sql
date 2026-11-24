begin;
do $test$
declare actor uuid:=gen_random_uuid(); manager_id uuid:=gen_random_uuid(); offer uuid:=gen_random_uuid(); denied boolean:=false; stale boolean:=false;
begin
 insert into auth.users(id) values(actor);
 insert into public.ff_profiles(user_id,display_name,role,active) values(actor,'موظف اختبار','customer_service',true)
 on conflict(user_id) do update set role='customer_service',active=true;
 insert into auth.users(id) values(manager_id);
 insert into public.ff_profiles(user_id,display_name,role,active) values(manager_id,'مدير اختبار','manager',true)
 on conflict(user_id) do update set role='manager',active=true;
 perform set_config('request.jwt.claim.sub',actor::text,true);
 insert into public.ff_offers(id,name,price,active) values(offer,'اختبار المرادفات',1,true);
 begin
  perform public.ff_save_catalog_parser_aliases('offer',offer,null,array['عرض خاص']);
 exception when insufficient_privilege then denied:=true;
 end;
 if not denied then raise exception 'unexpected permission';end if;
 perform set_config('request.jwt.claim.sub',manager_id::text,true);
 perform public.ff_save_catalog_parser_aliases('offer',offer,null,array['عرض خاص']);
 if not exists(select 1 from jsonb_array_elements(public.ff49_catalog()) item where item->>'id'=offer::text and item->'parser_aliases'='["عرض خاص"]'::jsonb) then
  raise exception 'parser catalog missing aliases'; end if;
 if not exists(select 1 from jsonb_array_elements(public.ff51_manager_catalog()->'offers') item where item->>'id'=offer::text and item->'parser_aliases'='["عرض خاص"]'::jsonb) then
  raise exception 'admin catalog missing aliases'; end if;
 begin
  perform public.ff_save_catalog_parser_aliases('offer',offer,null,array['تعديل متزامن']);
 exception when raise_exception then
  if sqlerrm not like 'تغيّرت المرادفات%' then raise; end if;
  stale:=true;
 end;
 if not stale then raise exception 'stale write accepted';end if;
 perform public.ff_save_catalog_parser_aliases('offer',offer,array['عرض خاص'],null);
 if exists(select 1 from public.ff_offers where id=offer and parser_aliases is not null) then raise exception 'reset failed';end if;
end $test$;
rollback;
