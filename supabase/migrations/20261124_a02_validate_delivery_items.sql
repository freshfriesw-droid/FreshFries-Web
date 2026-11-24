CREATE OR REPLACE FUNCTION public.ff38_create_delivery_order(p_branch uuid, p_phone text, p_area text, p_items jsonb, p_delivery_fee numeric DEFAULT 0, p_notes text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text;v_id uuid;v_number bigint;v_total numeric;v_count int;
BEGIN
SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
IF v_role IS NULL OR NOT public.ff38_permission_allowed(auth.uid(),'create_order') THEN RAISE EXCEPTION 'لا تملك صلاحية إنشاء الطلبات' USING ERRCODE='42501'; END IF;
IF NOT EXISTS(SELECT 1 FROM public.ff_branches WHERE id=p_branch AND active) THEN RAISE EXCEPTION 'الفرع غير صحيح'; END IF;
IF NOT public.ff49_can_work_branch(p_branch, ARRAY[v_role]) THEN RAISE EXCEPTION 'ليس لديك صلاحية العمل على هذا الفرع' USING ERRCODE='42501'; END IF;
IF pg_catalog.btrim(coalesce(p_phone,''))='' OR pg_catalog.btrim(coalesce(p_area,''))='' THEN RAISE EXCEPTION 'الهاتف والعنوان مطلوبان'; END IF;
-- Reject missing or non-finite values before any writes or dispatch.
IF p_delivery_fee IS NULL OR p_delivery_fee<0 OR p_delivery_fee::text IN ('NaN','Infinity','-Infinity')
 OR pg_catalog.jsonb_typeof(p_items) IS DISTINCT FROM 'array' THEN
 RAISE EXCEPTION 'راجع الأصناف وأجرة التوصيل' USING ERRCODE='22023';
END IF;
IF pg_catalog.jsonb_array_length(p_items) NOT BETWEEN 1 AND 50 THEN
 RAISE EXCEPTION 'راجع الأصناف وأجرة التوصيل' USING ERRCODE='22023';
END IF;
SELECT count(*),coalesce(sum(i.qty*i.price),0) INTO v_count,v_total
FROM pg_catalog.jsonb_to_recordset(p_items) AS i(name text,qty numeric,price numeric)
WHERE pg_catalog.btrim(coalesce(i.name,''))<>'' AND i.qty>0 AND i.price>=0
 AND i.qty::text NOT IN ('NaN','Infinity','-Infinity')
 AND i.price::text NOT IN ('NaN','Infinity','-Infinity');
IF v_count<>pg_catalog.jsonb_array_length(p_items) OR v_count>50 THEN
 RAISE EXCEPTION 'الأصناف أو الأسعار غير صالحة' USING ERRCODE='22023';
END IF;
PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-order-num-'||p_branch::text));
SELECT coalesce(max(order_number),0)+1 INTO v_number FROM public.ff_orders WHERE branch_id=p_branch;
INSERT INTO public.ff_orders(order_number,branch_id,phone_snapshot,area_snapshot,delivery_fee,items_total,total,
payment_status,status,order_type,notes,created_by,operational_date)
VALUES(v_number,p_branch,pg_catalog.left(p_phone,30),pg_catalog.left(p_area,300),p_delivery_fee,v_total,v_total+p_delivery_fee,
'unpaid','new','delivery',pg_catalog.left(coalesce(p_notes,''),2000),auth.uid(),
CASE WHEN EXTRACT(hour from pg_catalog.timezone('Asia/Aden',now()))>=8
THEN pg_catalog.timezone('Asia/Aden',now())::date
WHEN EXTRACT(hour from pg_catalog.timezone('Asia/Aden',now()))=0
THEN pg_catalog.timezone('Asia/Aden',now())::date-1 ELSE NULL END) RETURNING id INTO v_id;
INSERT INTO public.ff_order_items(order_id,item_name,quantity,unit_price,line_total,item_notes)
SELECT v_id,pg_catalog.btrim(i.name),i.qty,i.price,i.qty*i.price,coalesce(i.item_notes,'')
FROM pg_catalog.jsonb_to_recordset(p_items) AS i(name text,qty numeric,price numeric,item_notes text);
RETURN jsonb_build_object('order_id',v_id,'order_number',v_number,'total',v_total+p_delivery_fee,'dispatch',public.ff38__offer_next(v_id));
END $function$;
