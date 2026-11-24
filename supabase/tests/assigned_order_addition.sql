-- FIX-08 / QA-14. Staging-only service-to-cashier handoff; no external POS call.
begin;

do $fixtures$
declare
  branch uuid := gen_random_uuid();
  service uuid := gen_random_uuid();
  cashier uuid := gen_random_uuid();
  driver uuid := gen_random_uuid();
  target uuid := gen_random_uuid();
begin
  insert into public.ff_branches(id,code,name) values(branch,'qa-'||branch,'فرع اختبار الإضافة');
  insert into auth.users(id) values(service),(cashier);
  insert into public.ff_profiles(user_id,display_name,role,active)
  values(service,'خدمة عملاء اختبار','customer_service',true),(cashier,'كاشير اختبار','cashier',true)
  on conflict(user_id) do update set role=excluded.role,active=true;
  insert into public.ff_user_branches(user_id,branch_id) values(cashier,branch),(service,branch);
  insert into public.ff_drivers(id,name,branch_id) values(driver,'موصل اختبار',branch);
  insert into public.ff38_driver_presence(driver_id) values(driver) on conflict do nothing;
  insert into public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date)
  values(target,-(1+floor(random()*1e12)::bigint),branch,'000000000',public.ff_business_date(now()));
  insert into public.ff38_delivery_tasks(order_id,driver_id) values(target,driver);
  perform set_config('ff_qa.target_order',target::text,true);
  perform set_config('ff_qa.cashier',cashier::text,true);
  perform set_config('request.jwt.claim.sub',service::text,true);
end $fixtures$;

set local role authenticated;
do $handoff$
declare
  target uuid := current_setting('ff_qa.target_order')::uuid;
  addition uuid;
  result jsonb;
  visible jsonb;
begin
  result := public.ff52_regular_addition_create(target,
    '[{"item_name":"صنف تجريبي","quantity":2,"unit_price":150,"item_notes":"بَدون شطّة","addition_notes":"ملاحظة عامة"}]');
  addition := (result->>'addition_id')::uuid;
  if addition is null or not (result @> '{"status":"pending","amount":300}') then
    raise exception 'Service did not create the expected pending addition';
  end if;
  perform set_config('request.jwt.claim.sub',current_setting('ff_qa.cashier'),true);
  select entry into strict visible from jsonb_array_elements(public.ff52_list_additions()) entry
    where entry->>'id'=addition::text;
  if not (visible @> '{"status":"pending","amount":300,"addition_notes":"ملاحظة عامة","items":[{"quantity":2,"unit_price":150,"item_notes":"بَدون شطّة"}]}') then
    raise exception 'Cashier preview differs from the service submission';
  end if;
  result := public.ff52_regular_addition_invoice(addition,'QA-FIX08');
  if not (result @> '{"success":true,"status":"invoiced","amount":300,"items_count":1}') then
    raise exception 'Cashier invoice result mismatch';
  end if;
  select entry into strict visible from jsonb_array_elements(public.ff52_list_additions()) entry
    where entry->>'id'=addition::text;
  if not (visible @> '{"status":"invoiced","invoice_ref":"QA-FIX08","amount":300}') then
    raise exception 'Expected invoiced addition in the cashier list';
  end if;
end $handoff$;
reset role;
rollback;
