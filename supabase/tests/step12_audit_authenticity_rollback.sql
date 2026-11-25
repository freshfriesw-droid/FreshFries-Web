begin;
DO $qa$
DECLARE u uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); n int;
BEGIN
 insert into auth.users(id) values(u),(m);
 insert into public.ff_profiles(user_id,display_name,role,active) values(m,'STEP12 QA manager','manager',true) on conflict(user_id) do update set role=excluded.role,active=excluded.active;
 perform set_config('request.jwt.claim.sub',u::text,true);
 set local role authenticated;
 begin
 insert into public.ff_audit_log(actor_id,action,entity_type,entity_id,details) values(u,'step12_qa_probe','step12_qa_probe',u::text,'{}'::jsonb);
 raise exception 'untrusted insert permitted' using errcode='ZQA12';
 exception when insufficient_privilege then null; end;
 reset role;
 perform set_config('request.jwt.claim.sub',m::text,true);
 set local role authenticated;
 begin
 insert into public.ff_audit_log(actor_id,action,entity_type,entity_id,details) values(m,'step12_qa_probe','step12_qa_probe',m::text,'{}'::jsonb);
 raise exception 'manager direct insert permitted' using errcode='ZQA12';
 exception when insufficient_privilege then null; end;
 reset role;
 insert into public.ff_audit_log(actor_id,action,entity_type,entity_id,details) values(m,'step12_qa_server','step12_qa_probe',m::text,'{}'::jsonb);
 set local role authenticated;
 select count(*) into n from public.ff_audit_log where actor_id=m and action='step12_qa_server';
 if n<>1 then raise exception 'manager audit read broken';end if;
 reset role;
 if not has_table_privilege('service_role','public.ff_audit_log','INSERT') then raise exception 'service-role writer broken';end if;
END $qa$;
select 'PASS STEP12: direct audit writes denied to nonstaff and manager; server write and manager read preserved' result;
rollback;
