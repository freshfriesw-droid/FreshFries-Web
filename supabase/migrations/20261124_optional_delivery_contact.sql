-- Keep independently supplied details without manufacturing missing customer information.
do $guard$
begin
  if (select md5(prosrc) from pg_proc where oid='public.ff49_create_delivery_order(uuid,text,text,jsonb,numeric,text,text,text,text)'::regprocedure)
      is distinct from '71cd0a351b7c6cc3d587d981e68a9564' then
    raise exception 'Reconcile the changed delivery details function before applying';
  end if;
end $guard$;

alter table public.ff49_order_details alter column customer_name drop not null,
  alter column channel drop not null, alter column full_address drop not null;

create or replace function public.ff49_create_delivery_order(
  p_branch uuid,p_phone text,p_area text,p_items jsonb,p_delivery_fee numeric,p_notes text,
  p_customer_name text,p_channel text,p_full_address text
) returns jsonb language plpgsql security definer set search_path='' as $body$
declare
  result jsonb;
  name_value text := nullif(btrim(p_customer_name),'');
  channel_value text := nullif(btrim(p_channel),'');
  address_value text := nullif(btrim(p_full_address),'');
begin
  if length(name_value) not between 2 and 100 then raise exception 'اسم العميل يجب أن يكون بين 2 و100 حرف'; end if;
  if channel_value not in ('phone','whatsapp') then raise exception 'مصدر الطلب غير صالح'; end if;
  if length(address_value) not between 2 and 500 then raise exception 'العنوان التفصيلي يجب أن يكون بين 2 و500 حرف'; end if;

  result := public.ff38_create_delivery_order(p_branch,p_phone,p_area,p_items,p_delivery_fee,p_notes);
  if name_value is not null or channel_value is not null or address_value is not null then
    insert into public.ff49_order_details(order_id,customer_name,channel,full_address)
    values((result->>'order_id')::uuid,name_value,channel_value,address_value);
  end if;
  return result;
end $body$;
