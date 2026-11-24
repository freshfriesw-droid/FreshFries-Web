-- FIX-08: align both addition API paths with the integer-quantity parser and exact monetary precision.
CREATE OR REPLACE FUNCTION ff_private.a02_validate_addition_items(p_items jsonb)
RETURNS void LANGUAGE plpgsql IMMUTABLE SET search_path TO '' AS $$
DECLARE x jsonb; q numeric; price numeric; total numeric:=0;
BEGIN
 IF jsonb_typeof(p_items) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'الأصناف غير صالحة' USING ERRCODE='22023'; END IF;
 IF jsonb_array_length(p_items) NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'عدد سطور الأصناف غير صالح' USING ERRCODE='22023'; END IF;
 FOR x IN SELECT value FROM jsonb_array_elements(p_items) LOOP
  IF jsonb_typeof(x) IS DISTINCT FROM 'object' OR jsonb_typeof(x->'item_name') IS DISTINCT FROM 'string'
   OR length(btrim(coalesce(x->>'item_name','')))=0 OR jsonb_typeof(x->'quantity') IS DISTINCT FROM 'number'
   OR jsonb_typeof(x->'unit_price') IS DISTINCT FROM 'number'
   OR (x ? 'item_notes' AND jsonb_typeof(x->'item_notes') NOT IN ('string','null'))
   OR (x ? 'addition_notes' AND jsonb_typeof(x->'addition_notes') NOT IN ('string','null')) THEN
   RAISE EXCEPTION 'بيانات صنف الإضافة غير صالحة' USING ERRCODE='22023';
  END IF;
  q:=(x->>'quantity')::numeric;price:=(x->>'unit_price')::numeric;
  IF q NOT BETWEEN 1 AND 100 OR q<>trunc(q) OR price<0 OR price>=1000000000000 OR price<>round(price,2) THEN
   RAISE EXCEPTION 'الكمية عدد صحيح بين 1 و100 والسعر بدقة منزلتين' USING ERRCODE='22023';END IF;
  total:=total+q*price;
  IF total>=1000000000000 THEN RAISE EXCEPTION 'قيمة الإضافة خارج النطاق المسموح' USING ERRCODE='22023'; END IF;
 END LOOP;
 IF total<=0 THEN RAISE EXCEPTION 'إجمالي الإضافة يجب أن يكون أكبر من صفر' USING ERRCODE='22023';END IF;
END $$;
REVOKE ALL ON FUNCTION ff_private.a02_validate_addition_items(jsonb) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.ff52_late_addition_create(p_order uuid, p_items jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                              DECLARE v_phase text;v_driver uuid;v_status text;v_add uuid;v_n int;v_sum numeric;
                                              BEGIN
                                               IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role IN ('manager','customer_service'))
 OR NOT public.ff38_permission_allowed(auth.uid(),'edit_order')
                                                THEN
                                                  RAISE EXCEPTION 'غير مصرح بإنشاء الإضافة' USING ERRCODE='42501'; END IF;
 PERFORM ff_private.a02_validate_addition_items(p_items);
 IF jsonb_typeof(p_items) IS DISTINCT FROM 'array' THEN
  RAISE EXCEPTION 'الأصناف غير صالحة' USING ERRCODE='22023';
 END IF;
 IF jsonb_array_length(p_items) NOT BETWEEN 1 AND 50 THEN
  RAISE EXCEPTION 'الأصناف غير صالحة' USING ERRCODE='22023';
 END IF;
                                                   SELECT t.phase,t.driver_id,o.status INTO v_phase,v_driver,v_status
                                                    FROM public.ff_orders o JOIN public.ff38_delivery_tasks t ON t.order_id=o.id
                                                     WHERE o.id=p_order FOR UPDATE OF o,t;
                                                      IF NOT FOUND OR v_phase NOT IN ('on_way','arrived') OR v_status IN ('delivered','cancelled') THEN
                                                        RAISE EXCEPTION 'الإضافة المتأخرة متاحة فقط بعد خروج الموصل وقبل التسليم'; END IF;
                                                         SELECT count(*)::int,coalesce(sum(quantity*unit_price),0) INTO v_n,v_sum
                                                          FROM jsonb_to_recordset(p_items) AS i(item_name text,quantity numeric,unit_price numeric)
                                                           WHERE length(btrim(coalesce(item_name,'')))>0 AND quantity>0 AND unit_price>=0
 AND quantity::text NOT IN ('NaN','Infinity','-Infinity') AND unit_price::text NOT IN ('NaN','Infinity','-Infinity');
                                                            IF v_n<>jsonb_array_length(p_items) OR v_sum<=0 THEN RAISE EXCEPTION 'مبالغ الأصناف غير صالحة' USING ERRCODE='22023'; END IF;
                                                             INSERT INTO public.ff38_order_additions(order_id,status,requested_by,amount,addition_notes)
                                                              VALUES(p_order,'pending',auth.uid(),0,coalesce(p_items->0->>'addition_notes','')) RETURNING id INTO v_add;
                                                               INSERT INTO public.ff52_late_addition_consent(addition_id,driver_id) VALUES(v_add,v_driver);
                                                                INSERT INTO public.ff38_order_addition_items(addition_id,item_name,quantity,unit_price,item_notes)
                                                                 SELECT v_add,btrim(i.item_name),i.quantity,i.unit_price,coalesce(i.item_notes,'')
                                                                  FROM jsonb_to_recordset(p_items) AS i(item_name text,quantity numeric,unit_price numeric,item_notes text);
                                                                   UPDATE public.ff38_order_additions SET amount=v_sum WHERE id=v_add;
                                                                    RETURN jsonb_build_object('addition_id',v_add,'state','awaiting_driver','amount',v_sum);
                                                                    END $function$;
CREATE OR REPLACE FUNCTION public.ff52_regular_addition_create(p_order uuid, p_items jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
          DECLARE v_role text;v_phase text;v_status text;v_add uuid;v_n integer;v_total numeric;
          BEGIN
           SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
            IF v_role IS NULL OR v_role NOT IN ('manager','customer_service') OR NOT public.ff38_permission_allowed(auth.uid(),'edit_order') THEN
              RAISE EXCEPTION 'غير مصرح بإنشاء إضافات' USING ERRCODE='42501'; END IF;
               PERFORM ff_private.a02_validate_addition_items(p_items);
 IF jsonb_typeof(p_items) IS DISTINCT FROM 'array' THEN
  RAISE EXCEPTION 'الأصناف غير صالحة' USING ERRCODE='22023';
 END IF;
 IF jsonb_array_length(p_items) NOT BETWEEN 1 AND 50 THEN
                 RAISE EXCEPTION 'الأصناف غير صالحة' USING ERRCODE='22023'; END IF;
                  SELECT o.status,t.phase INTO v_status,v_phase FROM public.ff_orders o
                   JOIN public.ff38_delivery_tasks t ON t.order_id=o.id WHERE o.id=p_order FOR UPDATE OF o,t;
                    IF NOT FOUND OR v_phase<>'assigned' OR v_status IN ('delivered','cancelled') THEN
                      RAISE EXCEPTION 'لا يمكن إضافة أصناف قبل الإسناد أو بعد مغادرة الموصل'; END IF;
                       SELECT count(*)::int,coalesce(sum(quantity*unit_price),0) INTO v_n,v_total
                        FROM jsonb_to_recordset(p_items) AS i(item_name text,quantity numeric,unit_price numeric)
                         WHERE length(btrim(coalesce(item_name,'')))>0 AND quantity>0 AND unit_price>=0
 AND quantity::text NOT IN ('NaN','Infinity','-Infinity') AND unit_price::text NOT IN ('NaN','Infinity','-Infinity');
                          IF v_n<>jsonb_array_length(p_items) OR v_total<=0 THEN RAISE EXCEPTION 'بيانات الإضافة غير صحيحة' USING ERRCODE='22023'; END IF;
                           INSERT INTO public.ff38_order_additions(order_id,status,requested_by,amount,addition_notes)
                            VALUES(p_order,'pending',auth.uid(),0,coalesce(p_items->0->>'addition_notes','')) RETURNING id INTO v_add;
                             INSERT INTO public.ff38_order_addition_items(addition_id,item_name,quantity,unit_price,item_notes)
                              SELECT v_add,btrim(i.item_name),i.quantity,i.unit_price,coalesce(i.item_notes,'')
                               FROM jsonb_to_recordset(p_items) AS i(item_name text,quantity numeric,unit_price numeric,item_notes text);
                                UPDATE public.ff38_order_additions SET amount=v_total WHERE id=v_add;
                                 RETURN jsonb_build_object('addition_id',v_add,'amount',v_total,'status','pending');
                                 END $function$;