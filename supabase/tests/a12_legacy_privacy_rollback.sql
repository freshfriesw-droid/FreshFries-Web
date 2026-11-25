DO $qa$
declare m uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); customer uuid:=gen_random_uuid();
 s bigint; a bigint; menus bigint; n int:=0;
begin
 select count(*) into s from public.ff_staff;select count(*) into a from public.ff_app_settings;select count(*) into menus from public.ff_menu_items;
 begin
 insert into auth.users(id) values(m),(c),(d),(customer);
 insert into public.ff_profiles(user_id,display_name,role,active) values(m,'QA mgr','manager',true),(c,'QA cashier','cashier',true),(d,'QA inactive','cashier',false)
 on conflict(user_id) do update set role=excluded.role,active=excluded.active;
 perform set_config('request.jwt.claim.sub',customer::text,true);set local role authenticated;
 if (select count(*) from public.ff_staff)<>0 or (select count(*) from public.ff_app_settings)<>0 or (select count(*) from public.ff_role_permissions)<>0 then raise exception 'nonstaff legacy leak';end if;n:=n+1;
 if (select count(*) from public.ff_menu_items)<>menus then raise exception 'catalog access changed';end if;n:=n+1;
 reset role;perform set_config('request.jwt.claim.sub',d::text,true);set local role authenticated;
 if (select count(*) from public.ff_staff)<>0 or (select count(*) from public.ff_app_settings)<>0 then raise exception 'inactive staff legacy leak';end if;n:=n+1;
 reset role;perform set_config('request.jwt.claim.sub',c::text,true);set local role authenticated;
 if (select count(*) from public.ff_staff)<>0 or (select count(*) from public.ff_app_settings)<>a then raise exception 'cashier visibility mismatch';end if;n:=n+1;
 reset role;perform set_config('request.jwt.claim.sub',m::text,true);set local role authenticated;
 if (select count(*) from public.ff_staff)<>s or (select count(*) from public.ff_app_settings)<>a then raise exception 'manager visibility lost';end if;n:=n+1;
 reset role;
 if exists(select 1 from pg_class cl where cl.relnamespace='public'::regnamespace and cl.relname in ('ff_app_settings','ff_menu_categories','ff_menu_items','ff_offers','ff_role_permissions','ff_staff','ff_user_permissions') and (has_table_privilege('anon',cl.oid,'select') or has_table_privilege('anon',cl.oid,'insert') or has_table_privilege('anon',cl.oid,'update') or has_table_privilege('anon',cl.oid,'delete'))) then raise exception 'anon grant remains';end if;n:=n+1;
 raise exception 'QA rollback' using errcode='ZQA12';
 exception when sqlstate 'ZQA12' then null;end;
 if n<>6 or exists(select from auth.users where id in(m,c,d,customer)) then raise exception 'QA incomplete %',n;end if;
end $qa$;
