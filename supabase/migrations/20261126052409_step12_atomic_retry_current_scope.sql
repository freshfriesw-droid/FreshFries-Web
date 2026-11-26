CREATE OR REPLACE FUNCTION public.ff27_submit(p_request uuid, p_kind text, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  actor uuid := auth.uid();
  payload_hash text;
  prior public.ff70_atomic_requests%rowtype;
  result jsonb;
  branch uuid;
  replay_role text;
  desk text;
  previous_desk text;
  saved_order uuid;
  expected_items_total numeric;
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
    -- Recheck current authorization after acquiring the request lock.
    select p.role into replay_role from public.ff_profiles p
      where p.user_id=actor and p.active;
    branch := (p_input->>'p_branch')::uuid;
    if replay_role is null
       or not public.ff38_permission_allowed(actor,'create_order')
       or not exists(select 1 from public.ff_branches b where b.id=branch and b.active)
       or not public.ff49_can_work_branch(branch,ARRAY[replay_role])
       or (p_kind='reservation' and replay_role not in ('manager','customer_service')) then
      raise exception 'لا تملك صلاحية إعادة المحاولة لهذا الطلب' using errcode='42501';
    end if;
    if prior.payload_hash<>payload_hash then raise exception 'المعرّف مستخدم لطلب بمحتوى مختلف'; end if;
    if exists(select 1 from ff_private.a12_legacy_registry t where t.id::text=prior.result->>'order_id' and not exists(select 1 from public.ff_orders o where o.id=t.id)) then raise exception 'تم تصفير الطلب التجريبي؛ استخدم معرف طلب جديد';end if;
    return prior.result;
  end if;

  branch := (p_input->>'p_branch')::uuid;
  if p_kind='delivery' then
    -- Zero is valid only when the caller explicitly supplies it.
    if nullif(btrim(p_input->>'p_delivery_fee'),'') is null
       or btrim(p_input->>'p_delivery_fee') !~ '^[0-9]+([.][0-9]+)?$' then
      raise exception 'أدخل أجرة التوصيل صراحةً، حتى لو كانت صفرًا' using errcode='22023';
    end if;
    desk := nullif(p_input->>'p_desk','');
    if desk is not null and not exists (
      select 1 from public.ff_luxe_cashier_desks d where d.code=desk and d.branch_id=branch and d.active
    ) then raise exception 'وجهة الكاشير غير متوافقة مع الفرع'; end if;
    previous_desk := current_setting('ff_luxe.cashier_desk',true);
    perform set_config('ff_luxe.cashier_desk',coalesce(desk,''),true);
    -- ff49 validates contact details and calls ff38, which writes items and their notes before dispatch.
    result := public.ff49_create_delivery_order(branch,p_input->>'p_phone',p_input->>'p_area',p_input->'p_items',
      (p_input->>'p_delivery_fee')::numeric,coalesce(p_input->>'p_notes',''),
      p_input->>'p_customer_name',p_input->>'p_channel',p_input->>'p_full_address');
    perform set_config('ff_luxe.cashier_desk',coalesce(previous_desk,''),true);
    -- Verify the exact persisted item multiset and total before committing.
    -- A mismatch rolls back order, dispatch, notifications and request token.
    saved_order := (result->>'order_id')::uuid;
    SELECT sum((e->>'qty')::numeric*(e->>'price')::numeric)
      INTO expected_items_total FROM jsonb_array_elements(p_input->'p_items') e;
    IF saved_order IS NULL OR NOT EXISTS(
      SELECT 1 FROM public.ff_orders o WHERE o.id=saved_order AND o.created_by=actor
      AND o.branch_id=branch AND o.items_total=expected_items_total
      AND o.delivery_fee=(p_input->>'p_delivery_fee')::numeric
      AND o.total=expected_items_total+(p_input->>'p_delivery_fee')::numeric
    ) THEN RAISE EXCEPTION 'عدم تطابق إجمالي الطلب المحفوظ' USING ERRCODE='22023'; END IF;
    IF EXISTS(
      (SELECT i.item_name,i.quantity,i.unit_price,i.line_total,i.item_notes
       FROM public.ff_order_items i WHERE i.order_id=saved_order
       EXCEPT ALL
       SELECT btrim(e->>'name'),(e->>'qty')::numeric,(e->>'price')::numeric,
         (e->>'qty')::numeric*(e->>'price')::numeric,coalesce(e->>'item_notes','')
       FROM jsonb_array_elements(p_input->'p_items') e)
      UNION ALL
      (SELECT btrim(e->>'name'),(e->>'qty')::numeric,(e->>'price')::numeric,
         (e->>'qty')::numeric*(e->>'price')::numeric,coalesce(e->>'item_notes','')
       FROM jsonb_array_elements(p_input->'p_items') e
       EXCEPT ALL
       SELECT i.item_name,i.quantity,i.unit_price,i.line_total,i.item_notes
       FROM public.ff_order_items i WHERE i.order_id=saved_order)
    ) THEN RAISE EXCEPTION 'عدم تطابق الأصناف أو الكميات أو الأسعار أو الملاحظات المحفوظة' USING ERRCODE='22023'; END IF;
  else
    result := public.ff49_create_reservation(branch,p_input->>'p_customer_name',p_input->>'p_phone',
      (p_input->>'p_pickup')::timestamptz,p_input->'p_items',coalesce(p_input->>'p_notes',''));
  end if;
  insert into public.ff70_atomic_requests(actor_id,request_id,payload_hash,result)
  values(actor,p_request,payload_hash,result);
  return result;
end $function$
;
