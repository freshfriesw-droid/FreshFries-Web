-- FIX-07. Run on staging. All identities, orders, audit entries and queued events roll back.
begin;

do $fixtures$
declare
  branch uuid := gen_random_uuid();
  actor uuid := gen_random_uuid();
  customer_order uuid := gen_random_uuid();
begin
  insert into public.ff_branches(id,code,name)
  values(branch,'qa-'||branch,'فرع اختبار بيانات العميل');
  insert into auth.users(id) values(actor);
  insert into public.ff_profiles(user_id,display_name,role,active)
  values(actor,'مدير اختبار تصحيح العميل','manager',true)
  on conflict(user_id) do update set role='manager',active=true;
  insert into public.ff_orders(id,order_number,branch_id,phone_snapshot,area_snapshot,business_date)
  values(customer_order,-(1+floor(random()*1e12)::bigint),branch,'000000000','منطقة اختبار',current_date);
  perform set_config('request.jwt.claim.sub',actor::text,true);
  perform set_config('ff_qa.contact_order',customer_order::text,true);
end $fixtures$;

set local role authenticated;
do $edit$
declare
  target uuid := current_setting('ff_qa.contact_order')::uuid;
  previous jsonb := public.ff_order_customer_read(target);
  result jsonb;
  current_contact jsonb;
begin
  if previous->>'phone' is distinct from '000000000' then
    raise exception 'Fixture contact unavailable to manager';
  end if;
  result := public.ff_order_customer_edit(target,'000000001','منطقة مصححة','عميل تجريبي','عنوان مُصحّح','تصحيح تجريبي');
  if result->>'edit_id' is null then raise exception 'Missing change identifier'; end if;
  current_contact := public.ff_order_customer_read(target);
  if not (current_contact @> '{"phone":"000000001","area":"منطقة مصححة","name":"عميل تجريبي","address":"عنوان مُصحّح"}')
     or current_contact->>'status' is distinct from previous->>'status'
     or current_contact->>'last_edit' is null then
    raise exception 'Saved contact, timestamp or order state mismatch';
  end if;
  result := public.ff_order_customer_edit(target,'000000001','منطقة مصححة','عميل تجريبي','عنوان مُصحّح','تصحيح تجريبي');
  if result->>'unchanged' is distinct from 'true' then raise exception 'Repeat edit was not idempotent'; end if;
end $edit$;
reset role;

do $audit$
declare
  target uuid := current_setting('ff_qa.contact_order')::uuid;
  change public.ff_order_customer_edits%rowtype;
begin
  select * into strict change from public.ff_order_customer_edits where order_id=target;
  if change.actor_id is distinct from auth.uid() or change.reason is distinct from 'تصحيح تجريبي'
     or change.old_values->>'phone' is distinct from '000000000'
     or change.new_values->>'phone' is distinct from '000000001'
     or not (change.changed_fields @> array['phone','area','name','address']) then
    raise exception 'Actor, reason or field history mismatch';
  end if;
  if (select count(*) from public.ff_audit_log where actor_id=change.actor_id
      and action='customer_contact_corrected' and entity_id=target::text
      and details->>'change_id'=change.id::text) <> 1 then
    raise exception 'Expected one matching audit event';
  end if;
end $audit$;

rollback;
