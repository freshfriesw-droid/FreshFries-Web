begin;
do $setup$
declare
  recipient uuid := gen_random_uuid();
  manager_id uuid := gen_random_uuid();
  branch uuid := gen_random_uuid();
begin
  insert into auth.users(id) values(recipient),(manager_id);
  insert into public.ff_profiles(user_id,display_name,role,active)
  values(recipient,'QA-FF87 worker','cashier',true),(manager_id,'QA-FF87 manager','manager',true)
  on conflict(user_id) do update set role=excluded.role,active=true;
  insert into public.ff_branches(id,code,name) values(branch,'qa-ff87-'||branch,'QA-FF87');
  insert into public.ff_user_branches(user_id,branch_id) values(recipient,branch);
  perform set_config('request.jwt.claim.sub',manager_id::text,true);
  perform public.ff82_set_grant(recipient,branch,'orders',array['view','edit'],now()-interval '1 minute',now()+interval '1 hour');
  perform set_config('request.jwt.claim.sub',recipient::text,true);
  perform set_config('qa.branch',branch::text,true);
end $setup$;
set local role authenticated;
do $$begin
  if not exists(select from public.ff82_my_grant()) then raise exception 'Active grant missing';end if;
end$$;
reset role;
update public.ff_branches set active=false where id=current_setting('qa.branch')::uuid;
set local role authenticated;
do $$begin
  if exists(select from public.ff82_delegate_catalog()) then raise exception 'Inactive branch visible';end if;
end$$;
reset role;
update public.ff_branches set active=true where id=current_setting('qa.branch')::uuid;
update public.ff82_content_grants set ends_at=clock_timestamp()+interval '100 milliseconds' where recipient=auth.uid();
select pg_sleep(0.15);
set local role authenticated;
do $$begin
  if exists(select from public.ff82_my_grant()) then raise exception 'Expired grant visible';end if;
  if (public.ff82_delegate_draft('qa-ff87','QA-FF87')->>'ok')::boolean is distinct from false then raise exception 'Expected denial';end if;
end$$;
reset role;
do $$begin
  if not exists(select from public.ff82_content_audit where actor_id=auth.uid() and action='draft' and outcome='denied' and reason='outside_edit_scope') then raise exception 'Missing denial audit';end if;
end$$;
rollback;
