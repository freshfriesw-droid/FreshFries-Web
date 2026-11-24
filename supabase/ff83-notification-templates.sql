-- DEC-09: allow only declared variables in the two operational notification templates.
-- Other labels retain the existing prohibition on braces. No arbitrary HTML or URLs.
create function public.ff83_valid_content(p_key text,p_body text) returns boolean
language plpgsql immutable set search_path='' as $$
declare clean text:=p_body;
begin
 if p_body is null then return true;end if;
 if p_key in ('notices.delayed','notices.reminder') then
  clean:=replace(clean,'{order_number}','');
 end if;
 return length(btrim(p_body)) between 1 and 180 and clean !~ '[<>{}[:cntrl:]]'
 and p_body !~* '(https?://|www\.|javascript:|data:|vbscript:|//)'
 and translate(p_body,U&'\061C\200E\200F\202A\202B\202C\202D\202E\2066\2067\2068\2069','')=p_body;
end $$;
alter table public.ff_content_versions drop constraint ff_content_safe_text;
alter table public.ff_content_versions add constraint ff_content_safe_text check(public.ff83_valid_content(content_key,body));
insert into public.ff_content_catalog(key,screen,label,original) values
 ('notices.delayed','notices','تنبيه الطلب المتأخر','تنبيه تشغيلي جديد — طلب #{order_number}'),
 ('notices.reminder','notices','تذكير الطلب المتأخر','تذكير: طلب #{order_number} ما زال متأخرًا')
on conflict(key) do nothing;
revoke all on function public.ff83_valid_content(text,text) from public,anon,authenticated;
