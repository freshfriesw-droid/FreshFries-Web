CREATE OR REPLACE FUNCTION public.ff38_get_reject_permissions()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text; v_driver uuid; v_result jsonb;
BEGIN
 SELECT p.role INTO v_role FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active=true;
  IF v_role IS NULL THEN RAISE EXCEPTION 'غير مصرح' USING ERRCODE='42501'; END IF;
   IF v_role IN ('manager','customer_service','supervisor') THEN
     SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('order_id',o.id,'allow_driver_reject',o.allow_driver_reject)),'[]'::jsonb)
       INTO v_result FROM public.ff_orders o
         WHERE o.order_type='delivery' AND o.status NOT IN ('delivered','cancelled','reservation_completed')
       AND (v_role<>'supervisor' OR ff_private.a10_branch_visible(v_role,o.branch_id));
          ELSIF v_role='driver' THEN
            SELECT l.driver_id INTO v_driver FROM public.ff38_driver_links l WHERE l.user_id=auth.uid();
              SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('order_id',o.id,'allow_driver_reject',o.allow_driver_reject)),'[]'::jsonb)
                INTO v_result FROM public.ff_orders o
                  WHERE EXISTS(SELECT 1 FROM public.ff38_dispatch_offers f
                      WHERE f.order_id=o.id AND f.driver_id=v_driver AND f.status='offered');
                       ELSE v_result='[]'::jsonb;
                        END IF;
                         RETURN v_result;
                         END $function$
;
