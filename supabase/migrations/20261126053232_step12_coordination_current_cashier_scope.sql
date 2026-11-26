CREATE OR REPLACE FUNCTION public.ff_a10_cashier_coordination(p_order uuid, p_stars integer, p_note text DEFAULT ''::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF NOT EXISTS(SELECT FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active AND p.role='cashier')
 OR NOT EXISTS(SELECT FROM public.ff_orders o JOIN public.ff38_delivery_tasks t ON t.order_id=o.id JOIN public.ff49_cashier_receipts cr ON cr.order_id=o.id WHERE o.id=p_order AND cr.received_by=auth.uid() AND t.cashier_stage='handed_over' AND o.status NOT IN ('cancelled','canceled','closed'))
 OR NOT ff_private.a10_cashier_order_visible(p_order) THEN
 RAISE EXCEPTION 'التقييم متاح لكاشير الطلب بعد تسليمه للموصل' USING ERRCODE='42501';END IF;
 IF p_stars IS NULL OR p_stars NOT BETWEEN 1 AND 5 OR length(coalesce(p_note,''))>500 THEN RAISE EXCEPTION 'التقييم من 1 إلى 5 والملاحظة حتى 500 حرف';END IF;
 INSERT INTO ff_private.a10_cashier_coordination(order_id,cashier_user_id,stars,note) VALUES(p_order,auth.uid(),p_stars,coalesce(p_note,'')) ON CONFLICT DO NOTHING;
 IF NOT FOUND THEN RAISE EXCEPTION 'سبق تسجيل تقييم التنسيق لهذا الطلب';END IF;
 RETURN true;
END $function$
;
