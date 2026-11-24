CREATE OR REPLACE FUNCTION public.ff28_customer(p_order uuid DEFAULT NULL::uuid, p_stars integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_phone text; v_number text; v_order uuid; v_result jsonb;
BEGIN
 IF auth.uid() IS NULL OR EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid()) THEN
  RAISE EXCEPTION 'بوابة العميل متاحة للعملاء المخولين فقط' USING ERRCODE='42501';
 END IF;
 SELECT phone INTO v_phone FROM auth.users
 WHERE id=auth.uid() AND phone_confirmed_at IS NOT NULL;
 v_number:=pg_catalog.regexp_replace(coalesce(v_phone,''),'[^0-9]','','g');
 IF v_number !~ '^9677[0-9]{8}$' THEN RAISE EXCEPTION 'يرجى تأكيد ملكية رقم هاتف يمني صالح' USING ERRCODE='42501'; END IF;
 v_number:=pg_catalog.right(v_number,9);
 IF p_order IS NOT NULL OR p_stars IS NOT NULL THEN
   IF p_order IS NULL OR p_stars IS NULL OR p_stars NOT BETWEEN 1 AND 5 THEN
    RAISE EXCEPTION 'معرف الطلب والتقييم 1–5 مطلوبان' USING ERRCODE='22023';
   END IF;
   UPDATE public.ff_orders o SET rating=p_stars,updated_at=now()
     WHERE o.id=p_order AND o.status='delivered' AND o.rating IS NULL
       AND pg_catalog.regexp_replace(pg_catalog.translate(coalesce(o.phone_snapshot,''),'٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','01234567890123456789'),'[^0-9]','','g') IN
           (v_number,'967'||v_number,'00967'||v_number)
   RETURNING o.id INTO v_order;
   IF v_order IS NULL THEN RAISE EXCEPTION 'الطلب غير متاح للتقييم أو تم تقييمه مسبقًا' USING ERRCODE='42501'; END IF;
 END IF;
 SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
  'id',r.id,'order_number',r.order_number,'status',r.status,'total',r.total,
  'phase',r.phase,'cashier_stage',r.cashier_stage,'rating',r.rating
 ) ORDER BY r.created_at DESC),'[]'::jsonb)
 INTO v_result FROM (
   SELECT o.id,o.order_number,o.status,o.total,o.rating,o.created_at,
    t.phase,t.cashier_stage
   FROM public.ff_orders o
   LEFT JOIN LATERAL (
      SELECT dt.phase,dt.cashier_stage FROM public.ff38_delivery_tasks dt
      WHERE dt.order_id=o.id ORDER BY dt.updated_at DESC LIMIT 1
   ) t ON true
   WHERE pg_catalog.regexp_replace(pg_catalog.translate(coalesce(o.phone_snapshot,''),'٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','01234567890123456789'),'[^0-9]','','g') IN
       (v_number,'967'||v_number,'00967'||v_number)
   ORDER BY o.created_at DESC LIMIT 100
 ) r;
 RETURN v_result;
END;
$function$;
