CREATE OR REPLACE FUNCTION public.ff52_late_cancel(p_addition uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                            DECLARE v_state text; v_branch uuid; v_role text;
                            BEGIN
                             IF NOT public.ff38_permission_allowed(auth.uid(),'edit_order')
                              OR length(btrim(coalesce(p_reason,''))) NOT BETWEEN 5 AND 500 THEN
                                RAISE EXCEPTION 'السبب وصلاحية التعديل مطلوبان' USING ERRCODE='42501'; END IF;
                                 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 SELECT x.state,o.branch_id INTO v_state,v_branch
 FROM public.ff52_late_addition_consent x
 JOIN public.ff38_order_additions a ON a.id=x.addition_id
 JOIN public.ff_orders o ON o.id=a.order_id
 WHERE x.addition_id=p_addition FOR UPDATE OF x;
 IF NOT FOUND OR v_role IS NULL OR NOT public.ff49_can_work_branch(v_branch,ARRAY[v_role]) THEN
   RAISE EXCEPTION 'الإضافة غير مصرح بها لهذا الفرع' USING ERRCODE='42501';
 END IF;
                                  IF v_state NOT IN ('awaiting_driver','driver_accepted') THEN
                                    RAISE EXCEPTION 'الإضافة المفوترة لا تلغى هنا؛ عالج فاتورتها خارجيًا أولًا'; END IF;
                                     UPDATE public.ff38_order_additions SET status='cancelled' WHERE id=p_addition;
                                      UPDATE public.ff52_late_addition_consent SET state='cancelled',cancellation_reason=btrim(p_reason)
                                       WHERE addition_id=p_addition;
                                        RETURN jsonb_build_object('cancelled',true);
                                        END $function$
;

CREATE OR REPLACE FUNCTION public.ff52_late_driver_decide(p_addition uuid, p_accept boolean, p_reason text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                                                    DECLARE v_driver uuid;v public.ff52_late_addition_consent%ROWTYPE;v_phase text;
                                                                    BEGIN
                                                                     SELECT driver_id INTO v_driver FROM public.ff38_driver_links l
                                                                      JOIN public.ff_profiles p ON p.user_id=l.user_id AND p.role='driver' AND p.active
                                                                       WHERE l.user_id=auth.uid();
                                                                        SELECT * INTO v FROM public.ff52_late_addition_consent WHERE addition_id=p_addition FOR UPDATE;
                                                                         IF NOT FOUND OR v.driver_id IS DISTINCT FROM v_driver OR v.state<>'awaiting_driver' THEN
                                                                           RAISE EXCEPTION 'هذه الإضافة غير متاحة لك' USING ERRCODE='42501'; END IF;
                                                                            IF p_accept IS NULL THEN RAISE EXCEPTION 'حدد قبول الإضافة أو رفضها' USING ERRCODE='22023'; END IF;
 SELECT phase INTO v_phase FROM public.ff38_delivery_tasks t JOIN public.ff38_order_additions a
                                                                             ON a.order_id=t.order_id WHERE a.id=p_addition FOR UPDATE OF t;
                                                                              IF v_phase NOT IN ('on_way','arrived') THEN RAISE EXCEPTION 'تغيرت حالة رحلة التوصيل'; END IF;
                                                                               UPDATE public.ff52_late_addition_consent SET
                                                                                state=CASE WHEN p_accept THEN 'driver_accepted' ELSE 'driver_rejected' END,
                                                                                 driver_decided_at=now(),rejection_reason=CASE WHEN p_accept THEN NULL ELSE left(coalesce(p_reason,''),500) END
                                                                                  WHERE addition_id=p_addition;
                                                                                   IF NOT p_accept THEN
                                                                                     UPDATE public.ff38_order_additions SET status='cancelled' WHERE id=p_addition;
                                                                                      END IF;
                                                                                       RETURN jsonb_build_object('accepted',p_accept);
                                                                                       END $function$
;
