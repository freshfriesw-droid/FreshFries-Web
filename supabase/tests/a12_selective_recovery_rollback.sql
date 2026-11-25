DO $qa$
declare m uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); b2 uuid:=gen_random_uuid();
 d date:=(now() at time zone 'Asia/Aden')::date; o uuid; o2 uuid; o3 uuid; o4 uuid; live uuid:=gen_random_uuid();
 r jsonb; token text; batch uuid; snap jsonb; n int:=0; baseline bigint; audit_base bigint;
begin
 select count(*) into baseline from public.ff_orders; select count(*) into audit_base from public.ff_audit_log;
 begin
 insert into public.ff_branches(id,code,name) values(b,'qa-a12-'||b,'A12 QA'),(b2,'qa-a12-'||b2,'A12 QA2');
 insert into auth.users(id) values(m),(u);
 insert into public.ff_profiles(user_id,display_name,role,active) values(m,'QA manager','manager',true),(u,'QA cashier','cashier',true) on conflict(user_id) do update set role=excluded.role,active=true;
 insert into public.ff_orders(id,branch_id,order_number,order_type,status,phone_snapshot,created_at,business_date)
 values(live,b,999999999,'delivery','cancelled','000000000',(d+time '12:00') at time zone 'Asia/Aden',d);
 perform set_config('request.jwt.claim.sub',m::text,true);set local role authenticated;
 r:=public.ff_a12_create_fixture(b,'delivery',d,'إنشاء طلب اختبار'); o:=(r->>'id')::uuid;
 o2:=(public.ff_a12_create_fixture(b,'reservation',d,'إنشاء طلب اختبار')->>'id')::uuid;
 o3:=(public.ff_a12_create_fixture(b2,'delivery',d,'إنشاء طلب اختبار')->>'id')::uuid;
 o4:=(public.ff_a12_create_fixture(b,'delivery',d-1,'إنشاء طلب اختبار')->>'id')::uuid;
 r:=public.ff_a12_reset_preview(b,'delivery',d,d);token:=r->>'token';
 if r#>>'{counts,orders}'<>'1' or r#>>'{orders,0,id}'<>o::text or r->'blockers'<>'{}'::jsonb then raise exception 'scope %',r;end if;n:=n+1;
 if public.ff_a12_reset_preview(b,'all',d,d)#>>'{counts,orders}'<>'2' then raise exception 'type all';end if;n:=n+1;
 begin perform public.ff_a12_reset_execute(b,'delivery',d,d,token,'wrong');raise exception 'wrong confirmation accepted' using errcode='ZQA01';exception when others then if sqlstate='ZQA01' then raise;end if;end;n:=n+1;
 reset role; select ff_private.a12_snapshot(array[o]) into snap;
 insert into public.ff_order_events(order_id,new_status,note,actor_id) values(o,'cancelled','changed after preview',m);
 set local role authenticated;
 begin perform public.ff_a12_reset_execute(b,'delivery',d,d,token,'تصفير طلبات الاختبار فقط');raise exception 'stale preview accepted' using errcode='ZQA01';exception when others then if sqlstate='ZQA01' then raise;end if;end;n:=n+1;
 reset role;select ff_private.a12_snapshot(array[o]) into snap;
 set local role authenticated;
 r:=public.ff_a12_reset_preview(b,'delivery',d,d);token:=r->>'token';
 r:=public.ff_a12_reset_execute(b,'delivery',d,d,token,'تصفير طلبات الاختبار فقط');batch:=(r->>'batch_id')::uuid;
 if r->>'backup_saved'<>'true' or r#>>'{removed,orders}'<>'1' or r#>>'{removed,events}'<>'2' or r#>>'{remaining_selected,orders}'<>'0' then raise exception 'reset %',r;end if;n:=n+1;
 reset role;
 if exists(select from public.ff_orders where id=o) or (select count(*) from public.ff_orders where id in(live,o2,o3,o4))<>4 then raise exception 'wrong records affected';end if;n:=n+1;
 if not exists(select from ff_private.a12_reset_batches where id=batch and snapshot=snap) then raise exception 'backup mismatch';end if;n:=n+1;
 if not exists(select from public.ff_audit_log where action='a12_test_reset' and entity_id=batch::text) then raise exception 'missing reset audit';end if;n:=n+1;
 perform set_config('request.jwt.claim.sub',u::text,true);set local role authenticated;
 begin perform public.ff_a12_reset_preview(b,'all',d,d);raise exception 'cashier preview accepted' using errcode='ZQA01';exception when insufficient_privilege then null;end;n:=n+1;
 begin perform public.ff_a12_restore(batch,'استرجاع نسخة الاختبار');raise exception 'cashier restore accepted' using errcode='ZQA01';exception when insufficient_privilege then null;end;n:=n+1;
 begin perform public.ff_a12_create_fixture(b,'delivery',d,'إنشاء طلب اختبار');raise exception 'cashier fixture accepted' using errcode='ZQA01';exception when insufficient_privilege then null;end;n:=n+1;
 reset role;perform set_config('request.jwt.claim.sub',m::text,true);set local role authenticated;
 begin perform public.ff_a12_restore(batch,'wrong');raise exception 'wrong restore accepted' using errcode='ZQA01';exception when others then if sqlstate='ZQA01' then raise;end if;end;n:=n+1;
 r:=public.ff_a12_restore(batch,'استرجاع نسخة الاختبار');if r->>'exact_match'<>'true' then raise exception 'restore %',r;end if;n:=n+1;
 begin perform public.ff_a12_restore(batch,'استرجاع نسخة الاختبار');raise exception 'duplicate restore accepted' using errcode='ZQA01';exception when others then if sqlstate='ZQA01' then raise;end if;end;n:=n+1;
 reset role;
 if ff_private.a12_snapshot(array[o]) is distinct from snap or not exists(select from public.ff_audit_log where action='a12_test_restore' and entity_id=batch::text) then raise exception 'restore mismatch';end if;n:=n+1;
 if has_function_privilege('authenticated','public.ff_luxe_reset_safe(text[],text)','execute') or has_function_privilege('authenticated','public.ff_luxe_reset_scoped(text[],text)','execute') or has_function_privilege('authenticated','public.ff_manager_reset_data(text)','execute') or has_function_privilege('anon','public.ff_a12_restore(uuid,text)','execute') or has_table_privilege('authenticated','ff_private.a12_reset_batches','select') then raise exception 'unsafe privileges';end if;n:=n+1;
 raise exception 'QA rollback' using errcode='ZQA12';
 exception when sqlstate 'ZQA12' then null;end;
 if n<>16 or (select count(*) from public.ff_orders)<>baseline or (select count(*) from public.ff_audit_log)<>audit_base or exists(select from public.ff_branches where id in(b,b2)) then raise exception 'incomplete or fixture leak %',n;end if;
end $qa$;

-- Real branch configurations, only ephemeral rows, including a protected SET NULL dependency.
DO $qa$
declare m uuid:=gen_random_uuid(); b uuid; d date:=(now() at time zone 'Asia/Aden')::date; o uuid; r jsonb; snap jsonb; batch uuid; n int:=0;
begin
 begin
 select id into b from public.ff_branches where code='cairo' and active;
 if b is null then raise exception 'QA requires Cairo branch configuration';end if;
 insert into auth.users(id) values(m);
 insert into public.ff_profiles(user_id,display_name,role,active) values(m,'A12 QA manager','manager',true) on conflict(user_id) do update set role=excluded.role,active=true;
 perform set_config('request.jwt.claim.sub',m::text,true);set local role authenticated;
 o:=(public.ff_a12_create_fixture(b,'delivery',d,'إنشاء طلب اختبار')->>'id')::uuid;
 r:=public.ff_a12_reset_preview(b,'delivery',d,d);
 -- Abort rather than touch any previously generated fixture in a real branch.
 if r#>>'{counts,orders}'<>'1' or r#>>'{orders,0,id}'<>o::text or r#>>'{counts,desks}'<>'1' then raise exception 'fixture scope or desk mismatch %',r;end if;n:=n+1;
 reset role;
 insert into public.ff_push_jobs(user_id,order_id,event_key,kind,title,body,status)
 values(m,o,'a12-test:'||o,'employee_notice','QA','QA','sent');
 set local role authenticated;
 r:=public.ff_a12_reset_preview(b,'delivery',d,d);
 if r->'blockers'='{}'::jsonb then raise exception 'SET NULL dependent row not protected';end if;n:=n+1;
 begin perform public.ff_a12_reset_execute(b,'delivery',d,d,r->>'token','تصفير طلبات الاختبار فقط');raise exception 'blocked reset allowed' using errcode='ZQA01';exception when others then if sqlstate='ZQA01' then raise;end if;end;n:=n+1;
 reset role;
 if not exists(select from public.ff_push_jobs where order_id=o and event_key='a12-test:'||o) or not exists(select from public.ff_orders where id=o) then raise exception 'protected data changed';end if;n:=n+1;
 delete from public.ff_push_jobs where order_id=o and event_key='a12-test:'||o;
 select ff_private.a12_snapshot(array[o]) into snap;
 set local role authenticated;
 r:=public.ff_a12_reset_preview(b,'delivery',d,d);
 batch:=(public.ff_a12_reset_execute(b,'delivery',d,d,r->>'token','تصفير طلبات الاختبار فقط')->>'batch_id')::uuid;
 r:=public.ff_a12_restore(batch,'استرجاع نسخة الاختبار');
 if r->>'exact_match'<>'true' then raise exception 'real branch restore failure';end if;n:=n+1;
 reset role;
 if ff_private.a12_snapshot(array[o]) is distinct from snap then raise exception 'desk restore not exact';end if;n:=n+1;
 raise exception 'QA rollback' using errcode='ZQA12';
 exception when sqlstate 'ZQA12' then null;end;
 if n<>6 or exists(select from public.ff_orders where id=o) or exists(select from auth.users where id=m) then raise exception 'QA incomplete %',n;end if;
end $qa$;