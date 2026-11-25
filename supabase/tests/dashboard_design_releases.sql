begin;
do $qa$
declare m uuid:=gen_random_uuid();d uuid:=gen_random_uuid();a bigint;b bigint;c bigint;restored bigint;
begin
 insert into auth.users(id) values(m),(d);
 insert into public.ff_profiles(user_id,display_name,role,active) values(m,'مدير اختبار','manager',true),(d,'موصل اختبار','driver',true)
 on conflict(user_id) do update set role=excluded.role,active=true;
 perform set_config('request.jwt.claim.sub',m::text,true);
 a:=public.ff_ui_save_draft('driver',null,'mobile','D02','اختبار','floating');
 b:=public.ff_ui_save_draft('driver',null,'mobile','D03','','wide');
 if exists(select from public.ff_ui_effective(null,'mobile') where id=a) then raise exception 'Draft visible';end if;
 perform public.ff_ui_publish(a);
 begin perform public.ff_ui_publish(b);raise exception 'Stale draft allowed';exception when raise_exception then if sqlerrm='Stale draft allowed' then raise;end if;end;
 perform set_config('request.jwt.claim.sub',d::text,true);
 if not exists(select from public.ff_ui_effective(null,'mobile') where id=a) or exists(select from public.ff_ui_effective(null,'desktop') where id=a) then raise exception 'Wrong device';end if;
 if exists(select from public.ff_ui_manager_history()) then raise exception 'Unauthorized history';end if;
 begin perform public.ff_ui_publish(b);raise exception 'Unauthorized publish';exception when SQLSTATE '42501' then null;end;
 perform set_config('request.jwt.claim.sub',m::text,true);
 c:=public.ff_ui_save_draft('driver',null,'mobile','D07','اختبار ٢','icons');perform public.ff_ui_publish(c);
 restored:=public.ff_ui_save_draft(null,null,null,null,null,null,a);perform public.ff_ui_publish(restored);
 perform set_config('request.jwt.claim.sub',d::text,true);
 if not exists(select from public.ff_ui_effective(null,'mobile') where id=restored and pack='D02' and bar='floating') then raise exception 'Restore failed';end if;
end $qa$;
rollback;
