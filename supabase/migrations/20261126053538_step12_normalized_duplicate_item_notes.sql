CREATE OR REPLACE FUNCTION public.ff70_set_item_notes(p_order uuid, p_items jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_actor uuid := auth.uid(); v_order public.ff_orders%ROWTYPE; v_count integer; v_updated integer;
BEGIN
 IF v_actor IS NULL OR NOT public.ff38_permission_allowed(v_actor,'create_order') THEN RAISE EXCEPTION 'غير مصرح' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_order FROM public.ff_orders WHERE id=p_order FOR UPDATE;
   IF NOT FOUND OR v_order.created_by IS DISTINCT FROM v_actor OR v_order.status <> 'new' THEN RAISE EXCEPTION 'الطلب غير متاح للتعديل' USING ERRCODE='42501'; END IF;
    IF NOT public.ff49_can_work_branch(v_order.branch_id,ARRAY['manager','customer_service']::text[]) THEN RAISE EXCEPTION 'الفرع غير مصرح' USING ERRCODE='42501'; END IF;
     IF pg_catalog.jsonb_typeof(p_items) IS DISTINCT FROM 'array' OR pg_catalog.jsonb_array_length(p_items)>50 THEN RAISE EXCEPTION 'أصناف غير صالحة'; END IF;
      SELECT count(*) INTO v_count FROM public.ff_order_items WHERE order_id=p_order;
       IF v_count <> pg_catalog.jsonb_array_length(p_items) THEN RAISE EXCEPTION 'عدد الأصناف لا يطابق الطلب'; END IF;
        -- Compare all line attributes in order to prevent mapping notes to the wrong duplicate item.
         IF EXISTS (
           SELECT 1 FROM (
              SELECT item_name,quantity,unit_price,count(*) AS n FROM public.ff_order_items WHERE order_id=p_order GROUP BY 1,2,3
                ) actual FULL JOIN (
                   SELECT pg_catalog.btrim(e->>'name') AS item_name,(e->>'qty')::numeric AS quantity,(e->>'price')::numeric AS unit_price,count(*) AS n
                      FROM pg_catalog.jsonb_array_elements(p_items) e GROUP BY 1,2,3
                        ) requested USING(item_name,quantity,unit_price,n)
                          WHERE actual.n IS NULL OR requested.n IS NULL
                           ) THEN RAISE EXCEPTION 'بيانات الأصناف غير مطابقة'; END IF;
                            WITH incoming AS (
                              SELECT pg_catalog.btrim(e->>'name') AS name,(e->>'qty')::numeric AS qty,(e->>'price')::numeric AS price,
                                pg_catalog.left(pg_catalog.btrim(coalesce(e->>'item_notes','')),500) AS note,
                                  row_number() OVER(PARTITION BY pg_catalog.btrim(e->>'name'),(e->>'qty')::numeric,(e->>'price')::numeric ORDER BY ord) AS seq
                                    FROM pg_catalog.jsonb_array_elements(p_items) WITH ORDINALITY AS t(e,ord)
                                     ), existing AS (
                                       SELECT id,item_name,quantity,unit_price,row_number() OVER(PARTITION BY item_name,quantity,unit_price ORDER BY id) AS seq
                                         FROM public.ff_order_items WHERE order_id=p_order
                                          )
                                           UPDATE public.ff_order_items oi SET item_notes=incoming.note FROM incoming JOIN existing ON existing.item_name=incoming.name AND existing.quantity=incoming.qty AND existing.unit_price=incoming.price AND existing.seq=incoming.seq WHERE oi.id=existing.id;
                                            GET DIAGNOSTICS v_updated=ROW_COUNT;
                                             IF v_updated IS DISTINCT FROM v_count THEN RAISE EXCEPTION 'تعذر مطابقة جميع ملاحظات الأصناف'; END IF;
 RETURN pg_catalog.jsonb_build_object('updated',v_updated,'order_id',p_order);
                                             END;
                                             $function$;
