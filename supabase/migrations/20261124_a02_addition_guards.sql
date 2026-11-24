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

CREATE OR REPLACE FUNCTION public.ff52_regular_addition_cancel(p_addition uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                 DECLARE v_role text;v_phase text;v_status text;v_order uuid;
                                 BEGIN
                                  SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
                                   IF v_role NOT IN ('manager','customer_service') OR NOT public.ff38_permission_allowed(auth.uid(),'cancel_order')
                                    OR length(btrim(coalesce(p_reason,''))) NOT BETWEEN 5 AND 500 THEN
                                      RAISE EXCEPTION 'صلاحية الإلغاء مع السبب مطلوبة' USING ERRCODE='42501'; END IF;
                                       SELECT a.order_id,a.status,t.phase INTO v_order,v_status,v_phase
                                        FROM public.ff38_order_additions a JOIN public.ff38_delivery_tasks t ON t.order_id=a.order_id
                                         WHERE a.id=p_addition FOR UPDATE OF a,t;
                                          IF NOT FOUND OR v_status<>'pending' OR v_phase<>'assigned' THEN
                                            RAISE EXCEPTION 'الإضافة ليست معلقة أو غادر الموصل'; END IF;
                                             UPDATE public.ff38_order_additions SET status='cancelled' WHERE id=p_addition;
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 SELECT auth.uid(),'order_addition_cancelled','order_addition',p_addition::text,o.branch_id,
 jsonb_build_object('order_id',v_order,'reason',btrim(p_reason),'old_status','pending','new_status','cancelled')
 FROM public.ff_orders o WHERE o.id=v_order;
                                              RETURN jsonb_build_object('cancelled',true,'order_id',v_order,'reason',btrim(p_reason));
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
            IF v_role NOT IN ('manager','customer_service') OR NOT public.ff38_permission_allowed(auth.uid(),'edit_order') THEN
              RAISE EXCEPTION 'غير مصرح بإنشاء إضافات' USING ERRCODE='42501'; END IF;
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
