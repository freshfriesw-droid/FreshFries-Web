-- FIX-09 / QA-12: previously expired/rejected offers cannot be bypassed by cumulative dispatch.
-- The same history exclusion already exists in the normal offer selector.
DO $migration$
DECLARE
 src text:=pg_get_functiondef('public.ff38__offer_next(uuid,uuid)'::regprocedure);
 marker text:='AND (a.active_count<2 OR a.same_area>0)';
 patched text:=$body$AND (a.active_count<2 OR a.same_area>0)
 AND NOT EXISTS(SELECT 1 FROM public.ff38_dispatch_offers old
 WHERE old.order_id=p_order AND old.driver_id=d.id AND old.status IN ('rejected','expired'))$body$;
BEGIN
 IF strpos(src,marker)=0 OR strpos(substr(src,strpos(src,marker)+length(marker)),marker)>0 THEN
 RAISE EXCEPTION 'Unexpected cumulative eligibility definition';END IF;
 EXECUTE replace(src,marker,patched);
END $migration$;
