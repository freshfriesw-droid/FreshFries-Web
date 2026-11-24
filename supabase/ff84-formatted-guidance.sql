-- DEC-09 §6.5: optional guidance with trusted bold/list formatting, no raw HTML.
create or replace function public.ff83_valid_content(p_key text,p_body text) returns boolean
language plpgsql immutable set search_path='' as $$
declare clean text:=p_body; max_len integer:=180;
begin
 if p_body is null then return true;end if;
 if p_key in ('notices.delayed','notices.reminder') then
  clean:=replace(clean,'{order_number}','');
 elsif p_key in ('orders.guidance','reports.guidance') then
  max_len:=1000;
  clean:=replace(clean,chr(10),'');
 end if;
 return length(btrim(p_body)) between 1 and max_len and length(btrim(clean))>0
 and clean !~ '[<>{}[:cntrl:]]'
 and p_body !~* '(https?://|www\.|javascript:|data:|vbscript:|//)'
 and translate(p_body,U&'\061C\200E\200F\202A\202B\202C\202D\202E\2066\2067\2068\2069','')=p_body;
end $$;
insert into public.ff_content_catalog(key,screen,label,original) values
 ('orders.guidance','orders','إرشادات إضافية لمحلل الطلب','راجع الأصناف والكميات في المعاينة قبل الاعتماد.'),
 ('reports.guidance','reports','إرشادات إضافية للتقارير','اختر الفترة والأقسام المطلوبة، ثم اضغط إعداد التقرير.')
on conflict(key) do nothing;
