-- A02: active frontend and its 22 local scripts use server RPCs for these
-- four core tables; both deployed Edge Functions also have no direct use.
-- Keep existing SELECT grants (including Realtime) and service-role grants.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE
 public.ff_orders, public.ff_order_items, public.ff_customers, public.ff_customer_notes
 FROM authenticated, anon, PUBLIC;

-- Old atomic clients retain compatibility through the current guarded path.
CREATE OR REPLACE FUNCTION public.ff70_submit_atomic(p_request uuid,p_kind text,p_input jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 IF p_kind IS DISTINCT FROM 'delivery' THEN RAISE EXCEPTION 'Invalid request' USING ERRCODE='22023'; END IF;
 IF p_request IS NULL OR jsonb_typeof(p_input) IS DISTINCT FROM 'object'
    OR jsonb_typeof(p_input->'p_items') IS DISTINCT FROM 'array' THEN
  RAISE EXCEPTION 'Invalid request or items' USING ERRCODE='22023';
 END IF;
 IF jsonb_array_length(p_input->'p_items') NOT BETWEEN 1 AND 50 OR EXISTS (
  SELECT 1 FROM jsonb_array_elements(p_input->'p_items') e
  WHERE btrim(coalesce(e->>'name',''))=''
   OR length(coalesce(e->>'item_notes',''))>500
   OR (e->>'qty') IS NULL OR (e->>'price') IS NULL
   OR (e->>'qty') !~ '^[0-9]+([.][0-9]+)?$'
   OR (e->>'price') !~ '^[0-9]+([.][0-9]+)?$'
 ) THEN RAISE EXCEPTION 'Invalid item data or notes' USING ERRCODE='22023'; END IF;
 RETURN public.ff27_submit(p_request,p_kind,p_input);
END;
$function$;

-- Keep internal functions and their service-role privileges. The active
-- browser calls ff27_submit and ff52_regular_addition_* instead.
REVOKE EXECUTE ON FUNCTION
 public.ff_create_order_with_items(jsonb,jsonb),
 public.ff38_create_delivery_order(uuid,text,text,jsonb,numeric,text),
 public.ff49_create_delivery_order(uuid,text,text,jsonb,numeric,text,text,text,text),
 public.ff38_create_order_addition(uuid,jsonb),
 public.ff38_cancel_order_addition(uuid)
 FROM authenticated, anon, PUBLIC;

-- The obsolete desk-create callback is still present in old cached HTML
-- and overwritten by the current preview handler. Its retirement requires
-- live publishing/client verification, so retain its existing access here.

-- Current atomic path must verify persisted quantities, prices and notes.
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
    if prior.payload_hash<>payload_hash then raise exception 'المعرّف مستخدم لطلب بمحتوى مختلف'; end if;
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
end $function$;
