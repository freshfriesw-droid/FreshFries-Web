CREATE OR REPLACE FUNCTION public.ff_reward_issue(p_kind text, p_name text, p_phone text, p_items jsonb, p_expiry_date date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text;v_name text:=btrim(coalesce(p_name,''));v_phone text:=btrim(coalesce(p_phone,''));
 v_item jsonb;v_id uuid;v_qty integer;v_title text;v_line jsonb:='[]'::jsonb;
 v_code text;v_random text;v_total integer:=0;v_result uuid;v_attempts integer:=0;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role IS DISTINCT FROM 'manager' THEN RAISE EXCEPTION 'إصدار الأكواد للمدير العام فقط' USING ERRCODE='42501';END IF;
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
END $function$
;
