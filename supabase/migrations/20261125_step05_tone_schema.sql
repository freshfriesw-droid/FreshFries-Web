-- STEP05: fail closed for malformed central alert tone settings, preserving current valid data.
ALTER TABLE public.ff_app_settings ADD CONSTRAINT ff_step05_global_tone_shape
CHECK (setting_key <> 'ff_global_tones' OR coalesce(
 jsonb_typeof(setting_value)='object' AND (setting_value-ARRAY['new_order','delay'])='{}'::jsonb
 AND (jsonb_typeof((setting_value->'new_order'))='object' AND CASE ((setting_value->'new_order'))->>'type'
 WHEN 'built_in' THEN ((setting_value->'new_order')-ARRAY['type','key'])='{}'::jsonb AND jsonb_typeof(((setting_value->'new_order'))->'key')='string' AND ((setting_value->'new_order'))->>'key' IN ('soft','digital','classic','double','urgent')
 WHEN 'uploaded' THEN ((setting_value->'new_order')-ARRAY['type','tone_id'])='{}'::jsonb AND jsonb_typeof(((setting_value->'new_order'))->'tone_id')='string' AND ((setting_value->'new_order'))->>'tone_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 ELSE false END)
 AND (jsonb_typeof((setting_value->'delay'))='object' AND CASE ((setting_value->'delay'))->>'type'
 WHEN 'built_in' THEN ((setting_value->'delay')-ARRAY['type','key'])='{}'::jsonb AND jsonb_typeof(((setting_value->'delay'))->'key')='string' AND ((setting_value->'delay'))->>'key' IN ('soft','digital','classic','double','urgent')
 WHEN 'uploaded' THEN ((setting_value->'delay')-ARRAY['type','tone_id'])='{}'::jsonb AND jsonb_typeof(((setting_value->'delay'))->'tone_id')='string' AND ((setting_value->'delay'))->>'tone_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 ELSE false END),false));

CREATE OR REPLACE FUNCTION public.ff74_set_global_tones(p_new_order jsonb,p_delay jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $function$
DECLARE v_value jsonb;v_item jsonb;v_id uuid;
BEGIN
 IF auth.uid() IS NULL OR NOT public.ff_is_manager() THEN RAISE EXCEPTION 'MANAGER_ONLY' USING ERRCODE='42501';END IF;
 FOREACH v_item IN ARRAY ARRAY[p_new_order,p_delay] LOOP
  IF NOT coalesce((jsonb_typeof(v_item)='object' AND CASE (v_item)->>'type'
 WHEN 'built_in' THEN (v_item-ARRAY['type','key'])='{}'::jsonb AND jsonb_typeof((v_item)->'key')='string' AND (v_item)->>'key' IN ('soft','digital','classic','double','urgent')
 WHEN 'uploaded' THEN (v_item-ARRAY['type','tone_id'])='{}'::jsonb AND jsonb_typeof((v_item)->'tone_id')='string' AND (v_item)->>'tone_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 ELSE false END),false) THEN RAISE EXCEPTION 'INVALID_TONE' USING ERRCODE='22023';END IF;
  IF v_item->>'type'='uploaded' THEN
   v_id:=(v_item->>'tone_id')::uuid;
   IF NOT EXISTS(SELECT 1 FROM public.ff66_tones t JOIN storage.objects o ON o.bucket_id='ff-luxe-tones' AND o.name=t.storage_path WHERE t.id=v_id AND t.is_active)
   THEN RAISE EXCEPTION 'TONE_NOT_ACTIVE_OR_FILE_MISSING' USING ERRCODE='22023';END IF;
  END IF;
 END LOOP;
 v_value:=jsonb_build_object('new_order',p_new_order,'delay',p_delay);
 INSERT INTO public.ff_app_settings(setting_key,setting_value,updated_by,updated_at) VALUES('ff_global_tones',v_value,auth.uid(),now())
 ON CONFLICT(setting_key) DO UPDATE SET setting_value=excluded.setting_value,updated_by=excluded.updated_by,updated_at=now();
 RETURN v_value;
END $function$;
