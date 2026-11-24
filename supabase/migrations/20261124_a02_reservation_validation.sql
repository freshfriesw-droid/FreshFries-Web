CREATE OR REPLACE FUNCTION public.ff49_create_reservation(p_branch uuid, p_customer_name text, p_phone text, p_pickup timestamp with time zone, p_items jsonb, p_notes text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                                                                     DECLARE v_id uuid; v_count int;
                                                                                     BEGIN
                                                                                      IF NOT public.ff49_can_work_branch(p_branch,ARRAY['manager','customer_service'])
                                                                                       OR NOT public.ff38_permission_allowed(auth.uid(),'create_order') THEN
                                                                                         RAISE EXCEPTION 'غير مصرح بإنشاء حجز' USING ERRCODE='42501'; END IF;
                                                                                          IF NOT EXISTS(SELECT 1 FROM public.ff_branches WHERE id=p_branch AND active) THEN
  RAISE EXCEPTION 'الفرع غير صحيح' USING ERRCODE='22023';
 END IF;
 IF jsonb_typeof(p_items) IS DISTINCT FROM 'array' THEN
  RAISE EXCEPTION 'راجع اسم العميل والهاتف والموعد والأصناف' USING ERRCODE='22023';
 END IF;
 IF (p_pickup IS NOT NULL AND p_pickup<=now()-interval '5 minutes')
                                                                                           OR length(btrim(coalesce(p_customer_name,''))) NOT BETWEEN 2 AND 100
                                                                                            OR length(btrim(coalesce(p_phone,''))) NOT BETWEEN 5 AND 40
                                                                                             OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 50 THEN
                                                                                               RAISE EXCEPTION 'راجع اسم العميل والهاتف والموعد والأصناف' USING ERRCODE='22023'; END IF;
                                                                                                SELECT count(*)::int INTO v_count FROM jsonb_to_recordset(p_items) AS x(name text,qty numeric,price numeric)
                                                                                                 WHERE length(btrim(coalesce(name,'')))>0 AND qty>0 AND price>=0
 AND qty::text NOT IN ('NaN','Infinity','-Infinity') AND price::text NOT IN ('NaN','Infinity','-Infinity');
                                                                                                  IF v_count<>jsonb_array_length(p_items) THEN RAISE EXCEPTION 'أصناف الحجز غير صحيحة' USING ERRCODE='22023'; END IF;
                                                                                                   INSERT INTO public.ff49_reservations(branch_id,customer_name,customer_phone,pickup_at,items,notes,created_by,pickup_unspecified)
                                                                                                    VALUES(p_branch,btrim(p_customer_name),btrim(p_phone),coalesce(p_pickup,now()),p_items,left(coalesce(p_notes,''),2000),auth.uid(),p_pickup IS NULL)
                                                                                                     RETURNING id INTO v_id;
                                                                                                      INSERT INTO public.ff49_reservation_events(reservation_id,new_status,actor_id,note)
                                                                                                       VALUES(v_id,'new',auth.uid(),'تم إنشاء الحجز');
                                                                                                        RETURN jsonb_build_object('reservation_id',v_id,'status','new');
                                                                                                        END $function$;
