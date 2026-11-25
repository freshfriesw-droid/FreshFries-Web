-- STEP05: independent, optimistic update of a central alert event.
-- Keep the earlier two-event RPC for legacy clients; the current UI uses this guarded RPC.
CREATE OR REPLACE FUNCTION public.ff_step05_set_global_tone(p_event text,p_tone jsonb,p_expected jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $function$
DECLARE current_value jsonb; initial_value jsonb:='{"new_order":{"type":"built_in","key":"soft"},"delay":{"type":"built_in","key":"soft"}}'::jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.ff_is_manager() THEN RAISE EXCEPTION 'MANAGER_ONLY' USING ERRCODE='42501';END IF;
 IF p_event IS NULL OR p_event NOT IN ('new_order','delay') THEN RAISE EXCEPTION 'INVALID_EVENT' USING ERRCODE='22023';END IF;
 -- Insert only if absent; conflict waits for any concurrent first writer.
 INSERT INTO public.ff_app_settings(setting_key,setting_value,updated_by,updated_at)
 VALUES('ff_global_tones',initial_value,auth.uid(),now()) ON CONFLICT(setting_key) DO NOTHING;
 SELECT setting_value INTO STRICT current_value FROM public.ff_app_settings WHERE setting_key='ff_global_tones' FOR UPDATE;
 IF current_value->p_event IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'STALE_GLOBAL_TONE' USING ERRCODE='40001';END IF;
 IF p_event='new_order' THEN
  RETURN public.ff74_set_global_tones(p_tone,current_value->'delay');
 END IF;
 RETURN public.ff74_set_global_tones(current_value->'new_order',p_tone);
END $function$;
REVOKE ALL ON FUNCTION public.ff_step05_set_global_tone(text,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ff_step05_set_global_tone(text,jsonb,jsonb) TO authenticated;
