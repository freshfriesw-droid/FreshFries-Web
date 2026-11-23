-- Manager-issued one-use item vouchers (compensation / prize / hospitality).
-- Global unique code; redemption and fulfillment creation occur in ONE transaction.
CREATE TABLE IF NOT EXISTS public.ff_reward_codes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 code text NOT NULL UNIQUE,
 kind text NOT NULL CHECK (kind IN ('compensation','prize','hospitality')),
 recipient_name text NOT NULL,
 recipient_phone text NOT NULL,
 items jsonb NOT NULL CHECK (jsonb_typeof(items)='array' AND jsonb_array_length(items) BETWEEN 1 AND 25),
 issued_by uuid NOT NULL REFERENCES public.ff_profiles(user_id),
 issued_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz,
 status text NOT NULL DEFAULT 'issued' CHECK(status IN ('issued','redeemed','void')),
 redeemed_at timestamptz,
 redeemed_by uuid REFERENCES public.ff_profiles(user_id),
 redeemed_branch_id uuid REFERENCES public.ff_branches(id),
 redeemed_channel text CHECK(redeemed_channel IS NULL OR redeemed_channel IN ('delivery','reservation','cashier_pickup')),
 redeemed_order_id uuid REFERENCES public.ff_orders(id) ON DELETE SET NULL,
 redeemed_reservation_id uuid REFERENCES public.ff49_reservations(id) ON DELETE SET NULL,
 redeem_token uuid UNIQUE
);
CREATE INDEX IF NOT EXISTS ff_reward_codes_customer_idx ON public.ff_reward_codes(recipient_phone,issued_at DESC);
ALTER TABLE public.ff_reward_codes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ff_reward_codes FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.ff_reward_issue(
 p_kind text,p_name text,p_phone text,p_items jsonb,p_expiry_date date DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=''
AS $body$
DECLARE v_role text;v_name text:=btrim(coalesce(p_name,''));v_phone text:=btrim(coalesce(p_phone,''));
 v_item jsonb;v_id uuid;v_qty integer;v_title text;v_line jsonb:='[]'::jsonb;
 v_code text;v_random text;v_total integer:=0;v_result uuid;v_attempts integer:=0;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role<>'manager' THEN RAISE EXCEPTION 'إصدار الأكواد للمدير العام فقط' USING ERRCODE='42501';END IF;
 IF p_kind NOT IN ('compensation','prize','hospitality') OR length(v_name) NOT BETWEEN 2 AND 100
  OR length(v_phone) NOT BETWEEN 7 AND 30 OR v_phone !~ '^[+0-9٠-٩ ()-]+$' THEN
  RAISE EXCEPTION 'تحقق من نوع الكود واسم العميل ورقم الهاتف';END IF;
 IF p_expiry_date IS NOT NULL AND p_expiry_date< (now() AT TIME ZONE 'Asia/Aden')::date THEN
  RAISE EXCEPTION 'تاريخ انتهاء الكود في الماضي';END IF;
 IF p_items IS NULL OR jsonb_typeof(p_items)<>'array' OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 25 THEN
  RAISE EXCEPTION 'أضف أصناف التعويض من المنيو';END IF;
 FOR v_item IN SELECT value FROM jsonb_array_elements(p_items)
 LOOP
  IF jsonb_typeof(v_item)<>'object' OR (v_item->>'qty') !~ '^[1-9][0-9]?$' THEN
    RAISE EXCEPTION 'كمية الصنف غير صحيحة';END IF;
  v_id:=(v_item->>'id')::uuid;v_qty:=(v_item->>'qty')::integer;
  v_total:=v_total+v_qty;
  IF v_total>100 THEN RAISE EXCEPTION 'الكمية الإجمالية فوق الحد المسموح';END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_line) x WHERE x->>'id'=v_id::text) THEN
   RAISE EXCEPTION 'الصنف مكرر؛ ضع الكمية في سطر واحد';END IF;
  SELECT i.name INTO v_title FROM public.ff_menu_items i JOIN public.ff_menu_categories c ON c.id=i.category_id
  WHERE i.id=v_id AND i.active AND c.active;
  IF v_title IS NULL THEN RAISE EXCEPTION 'صنف غير نشط أو غير موجود في المنيو';END IF;
  v_line:=v_line||jsonb_build_array(jsonb_build_object('id',v_id,'name',v_title,'qty',v_qty,'price',0,'item_notes',''));
 END LOOP;
 LOOP
  v_random:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,16));
  v_code:='FF-'||substr(v_random,1,4)||'-'||substr(v_random,5,4)||'-'||substr(v_random,9,4)||'-'||substr(v_random,13,4);
  INSERT INTO public.ff_reward_codes(code,kind,recipient_name,recipient_phone,items,issued_by,expires_at)
  VALUES(v_code,p_kind,v_name,v_phone,v_line,auth.uid(),
   CASE WHEN p_expiry_date IS NULL THEN NULL ELSE ((p_expiry_date+1)::timestamp AT TIME ZONE 'Asia/Aden') END)
  ON CONFLICT(code) DO NOTHING RETURNING id INTO v_result;
  EXIT WHEN v_result IS NOT NULL;
  v_attempts:=v_attempts+1;
  IF v_attempts>=3 THEN RAISE EXCEPTION 'تعذر إصدار رمز فريد؛ أعد المحاولة';END IF;
 END LOOP;
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,details)
 VALUES(auth.uid(),'reward_code_issued','reward_code',v_result::text,
  jsonb_build_object('kind',p_kind,'item_count',jsonb_array_length(v_line)));
 RETURN jsonb_build_object('saved',true,'id',v_result,'code',v_code,'kind',p_kind,
  'customer_name',v_name,'customer_phone',v_phone,'items',v_line,'expires_at',p_expiry_date);
END $body$;

CREATE OR REPLACE FUNCTION public.ff_reward_list(p_limit integer DEFAULT 60)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $body$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN
  RAISE EXCEPTION 'الأكواد للمدير فقط' USING ERRCODE='42501';END IF;
 RETURN coalesce((
  SELECT jsonb_agg(to_jsonb(x) ORDER BY x.issued_at DESC)
  FROM(SELECT id,code,kind,recipient_name,recipient_phone,items,status,issued_at,expires_at,redeemed_at,
   redeemed_channel,redeemed_order_id,redeemed_reservation_id
   FROM public.ff_reward_codes ORDER BY issued_at DESC LIMIT least(greatest(coalesce(p_limit,60),1),150)) x
 ),'[]'::jsonb);
END $body$;

CREATE OR REPLACE FUNCTION public.ff_reward_check(p_code text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $body$
DECLARE v_role text;v_row public.ff_reward_codes%ROWTYPE;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role NOT IN ('manager','customer_service','cashier') THEN RAISE EXCEPTION 'غير مخوّل' USING ERRCODE='42501';END IF;
 SELECT * INTO v_row FROM public.ff_reward_codes
 WHERE code=upper(btrim(coalesce(p_code,''))) AND status='issued';
 IF NOT FOUND OR (v_row.expires_at IS NOT NULL AND v_row.expires_at<=now()) THEN
  RAISE EXCEPTION 'الكود غير موجود أو منتهي أو مستخدم مسبقًا';END IF;
 RETURN jsonb_build_object('id',v_row.id,'kind',v_row.kind,'customer_name',v_row.recipient_name,
   'customer_phone',v_row.recipient_phone,'items',v_row.items,'expires_at',v_row.expires_at);
END $body$;

CREATE OR REPLACE FUNCTION public.ff_reward_redeem(
 p_code text,p_branch uuid,p_channel text,p_area text DEFAULT '',
 p_fee numeric DEFAULT 0,p_notes text DEFAULT '',p_token uuid DEFAULT NULL,
 p_identity_confirmed boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=''
AS $body$
DECLARE v_role text;v_voucher public.ff_reward_codes%ROWTYPE;v_result jsonb;
 v_order uuid;v_reservation uuid;v_notes text;v_addr text:=btrim(coalesce(p_area,''));
 v_branch_ok boolean;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role NOT IN ('manager','customer_service','cashier') THEN RAISE EXCEPTION 'لا تملك صلاحية استهلاك الأكواد' USING ERRCODE='42501';END IF;
 IF p_code IS NULL OR p_token IS NULL OR p_identity_confirmed IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'أدخل الكود وأكد مطابقة اسم ورقم العميل قبل الاستخدام';END IF;
 IF p_channel NOT IN ('delivery','reservation','cashier_pickup') OR p_branch IS NULL THEN
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
 IF p_fee IS NULL OR p_fee<0 OR p_fee>50000 THEN RAISE EXCEPTION 'أجرة التوصيل غير صالحة';END IF;
 IF p_channel='delivery' AND length(v_addr) NOT BETWEEN 2 AND 300 THEN
  RAISE EXCEPTION 'أدخل عنوان التوصيل أو المنطقة';END IF;
 SELECT * INTO v_voucher FROM public.ff_reward_codes
 WHERE code=upper(btrim(p_code)) FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'كود غير صحيح' USING ERRCODE='42501';END IF;
 IF v_voucher.status='redeemed' AND v_voucher.redeem_token=p_token THEN
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
END $body$;

CREATE OR REPLACE FUNCTION public.ff_reward_void(p_code text)
RETURNS boolean LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=''
AS $body$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN
  RAISE EXCEPTION 'الإلغاء للمدير فقط' USING ERRCODE='42501';END IF;
 UPDATE public.ff_reward_codes SET status='void'
 WHERE code=upper(btrim(coalesce(p_code,''))) AND status='issued';
 IF NOT FOUND THEN RAISE EXCEPTION 'لا يمكن إلغاء كود مستخدم أو غير معروف';END IF;
 RETURN true;
END $body$;
REVOKE ALL ON FUNCTION public.ff_reward_issue(text,text,text,jsonb,date) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.ff_reward_list(integer) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.ff_reward_check(text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.ff_reward_redeem(text,uuid,text,text,numeric,text,uuid,boolean) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.ff_reward_void(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_reward_issue(text,text,text,jsonb,date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ff_reward_list(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ff_reward_check(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ff_reward_redeem(text,uuid,text,text,numeric,text,uuid,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ff_reward_void(text) TO authenticated;
