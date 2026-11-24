-- Preserve the existing request ledger, locks, grants and reservation RPC.
do $preflight$
begin
  if (select md5(prosrc) from pg_proc where oid='public.ff27_submit(uuid,text,jsonb)'::regprocedure)
      is distinct from '61785136e8523f0816a227af49a6a99f' then
    raise exception 'ff27_submit has changed; reconcile its current implementation before applying';
  end if;
end $preflight$;

create or replace function public.ff27_submit(p_request uuid,p_kind text,p_input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $body$
declare
  actor uuid := auth.uid();
  payload_hash text;
  prior public.ff70_atomic_requests%rowtype;
  result jsonb;
  branch uuid;
  desk text;
  previous_desk text;
begin
  if actor is null then raise exception 'تسجيل الدخول مطلوب' using errcode='42501'; end if;
  if p_request is null or p_kind is null or p_kind not in ('delivery','reservation')
     or jsonb_typeof(p_input) is distinct from 'object' then
    raise exception 'نوع الطلب غير مسموح';
  end if;
  if jsonb_typeof(p_input->'p_items') is distinct from 'array'
     or jsonb_array_length(p_input->'p_items') not between 1 and 50 then
    raise exception 'أصناف الطلب غير صالحة';
  end if;
  payload_hash := md5(p_kind||':'||p_input::text);
  perform pg_advisory_xact_lock(hashtextextended(actor::text||':'||p_request::text,0));
  select * into prior from public.ff70_atomic_requests where actor_id=actor and request_id=p_request;
  if found then
    if prior.payload_hash<>payload_hash then raise exception 'المعرّف مستخدم لطلب بمحتوى مختلف'; end if;
    return prior.result;
  end if;

  branch := (p_input->>'p_branch')::uuid;
  if p_kind='delivery' then
    desk := nullif(p_input->>'p_desk','');
    if desk is not null and not exists (
      select 1 from public.ff_luxe_cashier_desks d where d.code=desk and d.branch_id=branch and d.active
    ) then raise exception 'وجهة الكاشير غير متوافقة مع الفرع'; end if;
    previous_desk := current_setting('ff_luxe.cashier_desk',true);
    perform set_config('ff_luxe.cashier_desk',coalesce(desk,''),true);
    -- ff49 validates contact details and calls ff38, which writes items and their notes before dispatch.
    result := public.ff49_create_delivery_order(branch,p_input->>'p_phone',p_input->>'p_area',p_input->'p_items',
      coalesce((p_input->>'p_delivery_fee')::numeric,0),coalesce(p_input->>'p_notes',''),
      p_input->>'p_customer_name',p_input->>'p_channel',p_input->>'p_full_address');
    perform set_config('ff_luxe.cashier_desk',coalesce(previous_desk,''),true);
  else
    result := public.ff49_create_reservation(branch,p_input->>'p_customer_name',p_input->>'p_phone',
      (p_input->>'p_pickup')::timestamptz,p_input->'p_items',coalesce(p_input->>'p_notes',''));
  end if;
  insert into public.ff70_atomic_requests(actor_id,request_id,payload_hash,result)
  values(actor,p_request,payload_hash,result);
  return result;
end $body$;
