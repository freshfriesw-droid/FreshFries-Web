begin;
do $qa$
declare u uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); n int; ep text:='https://example.invalid/step12-'||gen_random_uuid(); b uuid;
begin
insert into auth.users(id) values(u),(c),(d);
insert into public.ff_profiles(user_id,display_name,role,active) values(c,'STEP12 QA cashier','cashier',true),(d,'STEP12 QA disabled','cashier',false);
select id into b from public.ff_branches limit 1;
perform set_config('request.jwt.claim.sub',u::text,true);
set local role authenticated;
begin
insert into public.ff_push_devices(user_id,endpoint,subscription) values(u,ep,jsonb_build_object('endpoint',ep,'keys',jsonb_build_object('p256dh',repeat('A',87),'auth',repeat('B',22))));
raise exception 'nonstaff push accepted' using errcode='ZQA12';
exception when insufficient_privilege then null;end;
reset role;
perform set_config('request.jwt.claim.sub',d::text,true);
set local role authenticated;
begin
insert into public.ff_push_devices(user_id,endpoint,subscription) values(d,ep,jsonb_build_object('endpoint',ep,'keys',jsonb_build_object('p256dh',repeat('A',87),'auth',repeat('B',22))));
raise exception 'disabled push accepted' using errcode='ZQA12';
exception when insufficient_privilege then null;end;
reset role;
perform set_config('request.jwt.claim.sub',c::text,true);
set local role authenticated;
begin
insert into public.ff_rr_cursors(branch_id) values(b) on conflict(branch_id) do update set updated_at=now();
raise exception 'client cursor write accepted' using errcode='ZQA12';
exception when insufficient_privilege then null;end;
insert into public.ff_push_devices(user_id,endpoint,subscription) values(c,ep,jsonb_build_object('endpoint',ep,'keys',jsonb_build_object('p256dh',repeat('A',87),'auth',repeat('B',22))));
update public.ff_push_devices set enabled=false where user_id=c and endpoint=ep;
get diagnostics n=row_count;if n<>1 then raise exception 'active own update broken';end if;
reset role;
update public.ff_profiles set active=false where user_id=c;
set local role authenticated;
update public.ff_push_devices set enabled=true where user_id=c and endpoint=ep;
get diagnostics n=row_count;if n<>0 then raise exception 'disabled re-enable accepted';end if;
reset role;
if not has_table_privilege('service_role','public.ff_rr_cursors','INSERT') then raise exception 'server cursor grant missing';end if;
end $qa$;
select 'PASS STEP12 nonstaff and disabled push blocked; active own push works; disabled update blocked; client cursor write denied' result;
rollback;
