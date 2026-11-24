-- A new branch with no live couriers. All records, requests and queued notifications roll back.
begin;
do $fixture$
declare
  branch uuid := gen_random_uuid();
  actor uuid := gen_random_uuid();
  desk text := 'qa-'||branch;
begin
  insert into public.ff_branches(id,code,name) values(branch,'qa-'||branch,'فرع اختبار مستقل');
  insert into public.ff_luxe_cashier_desks(code,label,branch_id,sort_order) values(desk,'وجهة اختبار',branch,100);
  insert into auth.users(id) values(actor);
  insert into public.ff_profiles(user_id,display_name,role,active) values(actor,'موظف اختبار','customer_service',true)
    on conflict(user_id) do update set role='customer_service',active=true;
  insert into public.ff_user_branches(user_id,branch_id) values(actor,branch);
  perform set_config('request.jwt.claim.sub',actor::text,true);
  perform set_config('ff_qa.branch',branch::text,true);
end $fixture$;
set local role authenticated;
do $submit$
declare
  branch text := current_setting('ff_qa.branch');
  request_id uuid := gen_random_uuid();
  result jsonb;
  payload jsonb := jsonb_build_object('p_branch',branch,'p_desk','qa-'||branch,
    'p_phone','000000000','p_area','حي الاختبار','p_delivery_fee',0,'p_notes','طلب اختبار',
    'p_customer_name','عميل اختبار','p_channel','whatsapp','p_full_address','عنوان اختبار تفصيلي',
    'p_items','[{"name":"صنف اختبار","qty":1,"price":100,"item_notes":"بدون شطّة"},{"name":"صنف اختبار","qty":1,"price":100,"item_notes":"شطة إضافية"}]'::jsonb);
begin
  result := public.ff27_submit(request_id,'delivery',payload);
  if result->>'order_id' is null or (result->>'total')::numeric is distinct from 200 then
    raise exception 'Missing created order or wrong total'; end if;
  if public.ff27_submit(request_id,'delivery',payload) is distinct from result then
    raise exception 'Retry did not return the original order'; end if;
  perform set_config('ff_qa.order',result->>'order_id',true);
end $submit$;
reset role;
do $check$
declare
  target uuid := current_setting('ff_qa.order')::uuid;
  branch uuid := current_setting('ff_qa.branch')::uuid;
begin
  if (select count(*) from public.ff_orders where branch_id=branch)<>1 then raise exception 'Duplicate delivery'; end if;
  if not exists(select 1 from public.ff49_order_details where order_id=target and customer_name='عميل اختبار'
      and channel='whatsapp' and full_address='عنوان اختبار تفصيلي') then raise exception 'Missing contact details'; end if;
  if not exists(select 1 from public.ff_luxe_cashier_order_desks where order_id=target and desk_code='qa-'||branch)
    then raise exception 'Incorrect cashier destination'; end if;
  if (select array_agg(item_notes order by item_notes collate "C") from public.ff_order_items where order_id=target)
      is distinct from array['بدون شطّة','شطة إضافية'] then raise exception 'Incorrect per-line notes'; end if;
end $check$;
set local role authenticated;
do $compat$
declare
  payload jsonb := jsonb_build_object('p_branch',current_setting('ff_qa.branch'),'p_phone','000000002',
    'p_area','منطقة اختبار','p_items','[{"name":"اختبار","qty":1,"price":75}]'::jsonb);
  request_id uuid := gen_random_uuid();
  result jsonb;
begin
  result := public.ff27_submit(request_id,'delivery',payload);
  if result->>'order_id' is null or public.ff27_submit(request_id,'delivery',payload) is distinct from result then
    raise exception 'Legacy delivery retry failed'; end if;
  payload := payload||jsonb_build_object('p_customer_name','عميل اختبار');
  result := public.ff27_submit(gen_random_uuid(),'delivery',payload);
  perform set_config('ff_qa.partial_order',result->>'order_id',true);
  request_id := gen_random_uuid();
  result := public.ff27_submit(request_id,'reservation',payload);
  if result->>'reservation_id' is null or public.ff27_submit(request_id,'reservation',payload) is distinct from result then
    raise exception 'Reservation retry failed'; end if;
end $compat$;
reset role;
do $partial$
begin
  if not exists(select 1 from public.ff49_order_details where order_id=current_setting('ff_qa.partial_order')::uuid
      and customer_name='عميل اختبار' and channel is null and full_address is null) then
    raise exception 'Partial contact details were lost or invented'; end if;
end $partial$;
rollback;
