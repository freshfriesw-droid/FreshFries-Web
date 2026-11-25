-- STEP12: enforce authorized cashier desk in legacy financial and transfer RPCs; retain existing branch and assignment guards.
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

                                                                                                                                                                                                      IF v_role='cashier' AND NOT ff_private.a05_can_read_order(p_order) THEN
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

CREATE OR REPLACE FUNCTION public.ff49_cashier_confirm_transfer(p_transfer uuid, p_invoice_ref_after text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                         DECLARE v_transfer public.ff49_driver_transfers%ROWTYPE;v_branch uuid;v_task public.ff38_delivery_tasks%ROWTYPE;
                                                                              BEGIN
                                                                                                                    SELECT * INTO v_transfer FROM public.ff49_driver_transfers WHERE id=p_transfer FOR UPDATE;
                                                                                                                                                           IF NOT FOUND OR v_transfer.status<>'pending_cashier' THEN RAISE EXCEPTION 'طلب النقل غير متاح'; END IF;
                                                                                                                                                                                                   SELECT * INTO v_task FROM public.ff38_delivery_tasks WHERE order_id=v_transfer.order_id FOR UPDATE;
                                                                                                                                                                                                                                            SELECT branch_id INTO v_branch FROM public.ff_orders WHERE id=v_transfer.order_id;
                                                                                                                                                                                                                                                                                      IF NOT public.ff49_can_work_branch(v_branch,ARRAY['manager','cashier']) THEN
                                                                                                                                                                                                                                                                                                                                  RAISE EXCEPTION 'الموافقة للكاشير المصرح بالفرع فقط' USING ERRCODE='42501'; END IF;
                                                                                                                                                                                                                                                                                                                                                                               IF NOT public.ff_is_manager() AND NOT ff_private.a05_can_read_order(v_transfer.order_id) THEN
 RAISE EXCEPTION 'الطلب غير متاح لهذه الوجهة' USING ERRCODE='42501'; END IF;
 IF v_task.driver_id<>v_transfer.original_driver_id OR v_task.phase<>'assigned'
                                                                                                                                                                                                                                                                                                                                                                                                                             OR v_task.cashier_stage='waiting' OR length(btrim(coalesce(p_invoice_ref_after,''))) > 80 THEN
                                                                                                                                                                                                                                                                                                                                                                                                                                                                             RAISE EXCEPTION 'يجب اعتماد القطع قبل تأكيد نقل الموصل؛ رقم الفاتورة اختياري وبحد 80 حرفًا'; END IF;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              -- Lock driver row + apply capacity guard during transfer; any failure rolls back confirmation.
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                UPDATE public.ff49_driver_transfers SET status='confirmed',confirmed_by=auth.uid(),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    confirmed_at=now(),invoice_ref_after=nullif(btrim(p_invoice_ref_after),'') WHERE id=p_transfer;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         UPDATE public.ff38_delivery_tasks SET driver_id=v_transfer.new_driver_id,updated_at=now()
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               WHERE order_id=v_transfer.order_id;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      UPDATE public.ff_orders SET driver_id=v_transfer.new_driver_id,updated_at=now()
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              WHERE id=v_transfer.order_id;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       UPDATE public.ff49_cashier_receipts SET invoice_ref=coalesce(nullif(btrim(p_invoice_ref_after),''),invoice_ref),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  invoiced_by=auth.uid(),invoiced_at=now() WHERE order_id=v_transfer.order_id;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              UPDATE public.ff38_driver_presence SET state='busy',updated_at=now() WHERE driver_id=v_transfer.new_driver_id;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           UPDATE public.ff38_driver_presence SET state='ready',updated_at=now() WHERE driver_id=v_transfer.original_driver_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          AND state='busy' AND NOT EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE driver_id=v_transfer.original_driver_id AND delivered_at IS NULL)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           AND NOT EXISTS(SELECT 1 FROM public.ff38_dispatch_offers WHERE driver_id=v_transfer.original_driver_id AND status='offered' AND expires_at>now());
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             RETURN jsonb_build_object('confirmed',true,'order_id',v_transfer.order_id,'new_driver_id',v_transfer.new_driver_id);
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               END; $function$;

CREATE OR REPLACE FUNCTION public.ff49_request_driver_transfer(p_order uuid, p_new_driver uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_task public.ff38_delivery_tasks%ROWTYPE;v_branch uuid;v_id uuid;
BEGIN
 IF length(btrim(coalesce(p_reason,''))) NOT BETWEEN 5 AND 500
  OR NOT public.ff38_permission_allowed(auth.uid(),'assign_driver') THEN
    RAISE EXCEPTION 'سبب النقل وصلاحية تعيين الموصل مطلوبان' USING ERRCODE='42501'; END IF;
     SELECT * INTO v_task FROM public.ff38_delivery_tasks WHERE order_id=p_order FOR UPDATE;
      SELECT branch_id INTO v_branch FROM public.ff_orders WHERE id=p_order;
       IF NOT public.ff49_can_work_branch(v_branch,ARRAY['manager','customer_service','cashier']) OR
 (NOT public.ff_is_manager() AND EXISTS(SELECT FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.role='cashier') AND NOT ff_private.a05_can_read_order(p_order)) THEN
 RAISE EXCEPTION 'الطلب غير متاح لصلاحيات حسابك' USING ERRCODE='42501'; END IF;
 IF NOT FOUND OR v_task.order_id IS NULL OR v_task.phase<>'assigned'
        OR v_task.cashier_stage='waiting' THEN
          RAISE EXCEPTION 'النقل بعد القطع يتطلب طلبًا مسندًا لم يغادر الفرع'; END IF;
           IF p_new_driver IS NULL OR p_new_driver=v_task.driver_id OR NOT EXISTS (
            SELECT 1 FROM public.ff_drivers d JOIN public.ff38_driver_presence p ON p.driver_id=d.id
             WHERE d.id=p_new_driver AND d.branch_id=v_branch AND d.active
              AND p.checked_in_at IS NOT NULL AND p.state IN ('ready','busy')
               AND p.last_seen_at>now()-interval '90 seconds') THEN
                 RAISE EXCEPTION 'الموصل البديل غير متاح في نفس الفرع'; END IF;
                  INSERT INTO public.ff49_driver_transfers(order_id,original_driver_id,new_driver_id,reason,requested_by)
                   VALUES(p_order,v_task.driver_id,p_new_driver,btrim(p_reason),auth.uid())
                    RETURNING id INTO v_id;
                     RETURN jsonb_build_object('transfer_id',v_id,'status','pending_cashier');
                     END $function$;

CREATE OR REPLACE FUNCTION public.ff49_visible_transfers()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                                                  DECLARE v_role text;
                                                                  BEGIN
                                                                   SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
                                                                    IF v_role IS NULL OR v_role NOT IN ('manager','cashier','customer_service','supervisor') THEN
                                                                      RAISE EXCEPTION 'غير مصرح' USING ERRCODE='42501'; END IF;
                                                                       RETURN coalesce((SELECT jsonb_agg(jsonb_build_object(
                                                                         'id',r.id,'order_id',r.order_id,'original_driver_id',r.original_driver_id,
                                                                           'new_driver_id',r.new_driver_id,'reason',r.reason,'status',r.status,'requested_at',r.requested_at)
                                                                            ORDER BY r.requested_at DESC)
                                                                             FROM (SELECT r.* FROM public.ff49_driver_transfers r JOIN public.ff_orders o ON o.id=r.order_id
                                                                               WHERE r.status='pending_cashier' AND (v_role IN ('manager','customer_service')
                                                                                  OR EXISTS(SELECT 1 FROM public.ff_user_branches WHERE user_id=auth.uid() AND branch_id=o.branch_id))
                                                                                    AND (v_role<>'cashier' OR ff_private.a05_can_read_order(o.id))
 ORDER BY r.requested_at DESC LIMIT 50) r),'[]'::jsonb);
                                                                                    END $function$;

CREATE OR REPLACE FUNCTION public.ff52_reassign_before_pos(p_order uuid, p_driver uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_task public.ff38_delivery_tasks%rowtype;
 v_order public.ff_orders%rowtype;
 v_role text;
begin
 select role into v_role from public.ff_profiles where user_id=auth.uid() and active;
 if v_role is null or not public.ff38_permission_allowed(auth.uid(),'assign_driver')
 or length(btrim(coalesce(p_reason,''))) not between 5 and 500 then
  raise exception 'السبب وصلاحية الإسناد مطلوبان' using errcode='42501';
 end if;
 if p_order is null then raise exception 'الطلب غير متاح لصلاحيات حسابك' using errcode='42501'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-o-'||p_order::text));
 select * into v_order from public.ff_orders where id=p_order for update;
 if v_order.id is null or not public.ff49_can_work_branch(v_order.branch_id,array[v_role]) then
  raise exception 'الطلب غير متاح لصلاحيات حسابك' using errcode='42501';
 end if;
 if v_role='cashier' and not ff_private.a05_can_read_order(p_order) then
 raise exception 'الطلب غير متاح لهذه الوجهة' using errcode='42501';end if;
 if v_order.order_type<>'delivery' or v_order.status in ('cancelled','delivered','reservation_completed') then
  raise exception 'حالة الطلب لا تسمح بنقل الموصل';
 end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-branch-rr-'||v_order.branch_id::text));
 select * into v_task from public.ff38_delivery_tasks where order_id=p_order for update;
 if p_driver is null or v_task.order_id is null or v_task.delivered_at is not null
 or v_task.cashier_stage<>'waiting' or v_task.phase<>'assigned' or v_task.driver_id=p_driver then
  raise exception 'النقل المباشر متاح قبل الفاتورة فقط';
 end if;
 perform 1 from public.ff_drivers d join public.ff38_driver_presence p on p.driver_id=d.id
 where d.id=p_driver and d.branch_id=v_order.branch_id and d.active=true and p.state in ('ready','busy')
 and p.checked_in_at is not null and p.checked_out_at is null and p.last_seen_at>clock_timestamp()-interval '90 seconds' for update of p;
 if not found then
  raise exception 'موصل بديل غير متصل أو من فرع مختلف';
 end if;
 update public.ff38_delivery_tasks set driver_id=p_driver,updated_at=now() where order_id=p_order;
 update public.ff_orders set driver_id=p_driver,updated_at=now() where id=p_order;
 update public.ff38_driver_presence set state='busy',updated_at=now() where driver_id=p_driver;
 update public.ff38_driver_presence set state='ready',updated_at=now() where driver_id=v_task.driver_id
 and state='busy' and not exists(select 1 from public.ff38_delivery_tasks where driver_id=v_task.driver_id and delivered_at is null)
 and not exists(select 1 from public.ff38_dispatch_offers where driver_id=v_task.driver_id and status='offered' and expires_at>now());
 insert into public.ff52_driver_reassignment_audit(order_id,old_driver_id,new_driver_id,actor_id,reason)
 values(p_order,v_task.driver_id,p_driver,auth.uid(),btrim(p_reason));
 return jsonb_build_object('reassigned',true,'driver_id',p_driver);
end $function$;
