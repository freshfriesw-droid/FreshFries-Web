-- STEP12: retain branch and cashier checks; restrict driver financial summary to own assigned order.
CREATE OR REPLACE FUNCTION public.ff38_order_financial_summary(p_order uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
    DECLARE
        v_user uuid;
            v_role text;
                v_branch uuid;
                    v_base numeric;
                        v_additions numeric;
                            v_pending numeric;
                            BEGIN
                                v_user := auth.uid();

                                    IF v_user IS NULL THEN
                                            RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
                                                END IF;

                                                    SELECT role INTO v_role
                                                        FROM public.ff_profiles
                                                            WHERE user_id = v_user
                                                                  AND active = true;

                                                                      IF v_role IS NULL THEN
                                                                              RAISE EXCEPTION 'ليس لديك صلاحية';
                                                                                  END IF;

                                                                                      SELECT branch_id, total
                                                                                          INTO v_branch, v_base
                                                                                              FROM public.ff_orders
                                                                                                  WHERE id = p_order;

                                                                                                      IF NOT FOUND THEN
                                                                                                              RAISE EXCEPTION 'الطلب غير موجود';
                                                                                                                  END IF;

                                                                                                                      IF v_role <> 'manager'
                                                                                                                             AND NOT EXISTS (
                                                                                                                                        SELECT 1
                                                                                                                                                   FROM public.ff_user_branches
                                                                                                                                                              WHERE user_id = v_user
                                                                                                                                                                           AND branch_id = v_branch
                                                                                                                                                                                  )
                                                                                                                                                                                      THEN
                                                                                                                                                                                              RAISE EXCEPTION 'ليس لديك صلاحية لهذا الفرع';
                                                                                                                                                                                                  END IF;

                                                                                                                                                                                                      IF v_role IN ('cashier','driver') AND NOT ff_private.a05_can_read_order(p_order) THEN
 RAISE EXCEPTION 'الطلب غير متاح لهذه الوجهة' USING ERRCODE='42501'; END IF;
 SELECT COALESCE(SUM(amount) FILTER (
                                                                                                                                                                                                                          WHERE status = 'invoiced'
                                                                                                                                                                                                                                  ), 0),
                                                                                                                                                                                                                                          COALESCE(SUM(amount) FILTER (
                                                                                                                                                                                                                                                      WHERE status = 'pending'
                                                                                                                                                                                                                                                              ), 0)
                                                                                                                                                                                                                                                                  INTO v_additions, v_pending
                                                                                                                                                                                                                                                                      FROM public.ff38_order_additions
                                                                                                                                                                                                                                                                          WHERE order_id = p_order;

                                                                                                                                                                                                                                                                              RETURN jsonb_build_object(
                                                                                                                                                                                                                                                                                      'order_id', p_order,
                                                                                                                                                                                                                                                                                              'base_total', COALESCE(v_base, 0),
                                                                                                                                                                                                                                                                                                      'invoiced_additions', v_additions,
                                                                                                                                                                                                                                                                                                              'pending_additions', v_pending,
                                                                                                                                                                                                                                                                                                                      'customer_total',
                                                                                                                                                                                                                                                                                                                                  COALESCE(v_base, 0) + v_additions
                                                                                                                                                                                                                                                                                                                                      );
                                                                                                                                                                                                                                                                                                                                      END;
                                                                                                                                                                                                                                                                                                                                      $function$;
