CREATE OR REPLACE FUNCTION public.ff_reward_redeem(p_code text, p_branch uuid, p_channel text, p_area text DEFAULT ''::text, p_fee numeric DEFAULT 0, p_notes text DEFAULT ''::text, p_token uuid DEFAULT NULL::uuid, p_identity_confirmed boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text;v_voucher public.ff_reward_codes%ROWTYPE;v_result jsonb;
 v_order uuid;v_reservation uuid;v_notes text;v_addr text:=btrim(coalesce(p_area,''));
 v_branch_ok boolean;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role IS NULL OR v_role NOT IN ('manager','customer_service','cashier') THEN RAISE EXCEPTION 'لا تملك صلاحية استهلاك الأكواد' USING ERRCODE='42501';END IF;
 IF p_code IS NULL OR p_token IS NULL OR p_identity_confirmed IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'أدخل الكود وأكد مطابقة اسم ورقم العميل قبل الاستخدام';END IF;
 IF p_channel IS NULL OR p_channel NOT IN ('delivery','reservation','cashier_pickup') OR p_branch IS NULL THEN
  RAISE EXCEPTION 'اختر طريقة الاستلام والفرع';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ff_branches WHERE id=p_branch AND active) THEN
  RAISE EXCEPTION 'الفرع غير نشط';END IF;
 IF v_role='cashier' AND (p_channel<>'cashier_pickup' OR NOT EXISTS(
   SELECT 1 FROM public.ff_user_branches WHERE user_id=auth.uid() AND branch_id=p_branch)) THEN
  RAISE EXCEPTION 'الكاشير يستطيع إصدار بطاقة تحضير لفرعه فقط' USING ERRCODE='42501';END IF;
 IF v_role IN ('manager','customer_service') AND (
   p_channel='cashier_pickup' OR NOT public.ff49_can_work_branch(p_branch,ARRAY['manager','customer_service'])
   OR NOT public.ff38_permission_allowed(auth.uid(),'create_order')) THEN
  RAISE EXCEPTION 'غير مصرح بإنشاء هذا النوع من الطلبات' USING ERRCODE='42501';END IF;
 IF length(coalesce(p_notes,''))>1000 THEN RAISE EXCEPTION 'ملاحظات طويلة';END IF;
 IF p_fee IS NULL OR p_fee<0 OR p_fee>50000 OR p_fee::text IN ('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'أجرة التوصيل غير صالحة';END IF;
 IF p_channel='delivery' AND length(v_addr) NOT BETWEEN 2 AND 300 THEN
  RAISE EXCEPTION 'أدخل عنوان التوصيل أو المنطقة';END IF;
 SELECT * INTO v_voucher FROM public.ff_reward_codes
 WHERE code=upper(btrim(p_code)) FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'كود غير صحيح' USING ERRCODE='42501';END IF;
 IF v_voucher.status='redeemed' AND v_voucher.redeem_token=p_token THEN
  IF v_voucher.redeemed_by IS DISTINCT FROM auth.uid()
   OR v_voucher.redeemed_branch_id IS DISTINCT FROM p_branch
   OR v_voucher.redeemed_channel IS DISTINCT FROM p_channel THEN
   RAISE EXCEPTION 'الكود مستهلك أو غير متاح لهذه المحاولة' USING ERRCODE='42501';
  END IF;
  RETURN jsonb_build_object('saved',true,'duplicate',true,'order_id',v_voucher.redeemed_order_id,
    'reservation_id',v_voucher.redeemed_reservation_id,'channel',v_voucher.redeemed_channel);
 END IF;
 IF v_voucher.status<>'issued' OR (v_voucher.expires_at IS NOT NULL AND v_voucher.expires_at<=now()) THEN
  RAISE EXCEPTION 'الكود مستهلك أو منتهي الصلاحية' USING ERRCODE='42501';END IF;
 v_notes:='كود أصناف مجانية ('||CASE v_voucher.kind WHEN 'compensation' THEN 'تعويض' WHEN 'prize' THEN 'جائزة' ELSE 'ضيافة' END||') · '||left(coalesce(p_notes,''),950);
 IF p_channel='delivery' THEN
  v_result:=public.ff38_create_delivery_order(p_branch,v_voucher.recipient_phone,v_addr,
   v_voucher.items,p_fee,v_notes);
  v_order:=(v_result->>'order_id')::uuid;
  INSERT INTO public.ff49_order_details(order_id,customer_name,channel,full_address)
  VALUES(v_order,v_voucher.recipient_name,'phone',v_addr)
  ON CONFLICT(order_id) DO UPDATE SET customer_name=EXCLUDED.customer_name,full_address=EXCLUDED.full_address;
 ELSIF p_channel='reservation' THEN
  v_result:=public.ff49_create_reservation(p_branch,v_voucher.recipient_name,
    v_voucher.recipient_phone,NULL,v_voucher.items,v_notes);
  v_reservation:=(v_result->>'reservation_id')::uuid;
 ELSE
  INSERT INTO public.ff49_reservations(branch_id,customer_name,customer_phone,pickup_at,
   pickup_unspecified,items,notes,status,created_by)
  VALUES(p_branch,v_voucher.recipient_name,v_voucher.recipient_phone,now(),true,
   v_voucher.items,v_notes,'confirmed',auth.uid()) RETURNING id INTO v_reservation;
  INSERT INTO public.ff49_reservation_events(reservation_id,new_status,actor_id,note)
  VALUES(v_reservation,'confirmed',auth.uid(),'بطاقة تحضير كود ضيافة/تعويض: أكد الكاشير الاستلام');
 END IF;
 UPDATE public.ff_reward_codes
 SET status='redeemed',redeemed_at=clock_timestamp(),redeemed_by=auth.uid(),
  redeemed_branch_id=p_branch,redeemed_channel=p_channel,
  redeemed_order_id=v_order,redeemed_reservation_id=v_reservation,redeem_token=p_token
 WHERE id=v_voucher.id AND status='issued';
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 VALUES(auth.uid(),'reward_code_redeemed','reward_code',v_voucher.id::text,p_branch,
  jsonb_build_object('channel',p_channel,'order',v_order,'reservation',v_reservation,
  'kind',v_voucher.kind));
 RETURN jsonb_build_object('saved',true,'order_id',v_order,'reservation_id',v_reservation,'channel',p_channel);
END $function$
;
