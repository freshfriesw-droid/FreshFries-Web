-- STEP05 actual central metadata and fail-closed settings; synthetic identities only; rollback.
BEGIN;
DO $qa$
DECLARE m uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); inactive uuid:=gen_random_uuid(); cat_a jsonb; cat_b jsonb; settings_a jsonb; settings_b jsonb; tones_a jsonb; tones_b jsonb; count_packs int; denied boolean; checks int:=0; rejected int:=0; image_id uuid; image_path text; tone_id uuid; bad jsonb; cfg jsonb; original_cfg jsonb;
BEGIN
 INSERT INTO auth.users(id) VALUES(m),(a),(b),(inactive);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP05 manager','manager',true),(a,'QA STEP05 service','customer_service',true),(b,'QA STEP05 cashier','cashier',true),(inactive,'QA STEP05 inactive','cashier',false)
 ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=excluded.active;
 SELECT id,extra->>'image_path' INTO image_id,image_path FROM public.ff_menu_items WHERE active AND extra->>'image_path' IS NOT NULL LIMIT 1;
 SELECT id INTO tone_id FROM public.ff66_tones WHERE is_active LIMIT 1;
 IF image_id IS NULL OR tone_id IS NULL THEN RAISE EXCEPTION 'Real media fixtures unavailable';END IF;
 SELECT setting_value INTO original_cfg FROM public.ff_app_settings WHERE setting_key='ff_global_tones';
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 SELECT count(*) INTO count_packs FROM public.ff_a07_design_catalog();IF count_packs<16 THEN RAISE EXCEPTION 'design registry mismatch %',count_packs; END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='ff_menu_media' AND name=image_path) THEN RAISE EXCEPTION 'missing public image object'; END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM public.ff53_save_menu_image(image_id,'menu/invalid.svg','item');EXCEPTION WHEN OTHERS THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'unsafe image path accepted';END IF;checks:=checks+1;
 FOR bad IN SELECT value FROM jsonb_array_elements('[null,{},[],{"type":"built_in"},{"type":"built_in","key":null},{"type":"built_in","key":"unknown"},{"type":"built_in","key":"soft","handler":"evil"},{"type":"uploaded"},{"type":"uploaded","tone_id":"bad"},{"type":"uploaded","tone_id":"00000000-0000-0000-0000-000000000000"},{"type":"other","key":"soft"}]'::jsonb) LOOP
  denied:=false;BEGIN PERFORM public.ff74_set_global_tones(bad,'{"type":"built_in","key":"soft"}');EXCEPTION WHEN SQLSTATE '22023' THEN denied:=true;END;
  IF NOT denied THEN RAISE EXCEPTION 'malformed tone accepted %',bad;END IF;rejected:=rejected+1;
 END LOOP;
 denied:=false;BEGIN PERFORM public.ff74_set_global_tones(NULL,'{"type":"built_in","key":"soft"}');EXCEPTION WHEN SQLSTATE '22023' THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'SQL NULL accepted';END IF;rejected:=rejected+1;
 denied:=false;BEGIN UPDATE public.ff_app_settings SET setting_value='{"new_order":{"type":"built_in"},"delay":{"type":"built_in","key":"soft"}}' WHERE setting_key='ff_global_tones';EXCEPTION WHEN check_violation THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'direct invalid setting accepted';END IF;checks:=checks+1;
 cfg:=public.ff74_set_global_tones(jsonb_build_object('type','uploaded','tone_id',tone_id),'{"type":"built_in","key":"soft"}');
 IF cfg->'new_order'->>'tone_id'<>tone_id::text OR cfg->'delay'->>'key'<>'soft' THEN RAISE EXCEPTION 'valid setting failed';END IF;checks:=checks+1;
 IF original_cfg IS NOT NULL THEN PERFORM public.ff74_set_global_tones(original_cfg->'new_order',original_cfg->'delay');END IF;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',a::text,true);SET LOCAL ROLE authenticated;
 cat_a:=public.ff49_catalog();settings_a:=public.ff74_get_global_tones();
 SELECT jsonb_agg(jsonb_build_object('id',id,'path',storage_path) ORDER BY id) INTO tones_a FROM public.ff66_tones;
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(cat_a) x WHERE x->>'id'=image_id::text AND x->>'image_path'=image_path AND x->>'image_version' IS NOT NULL) THEN RAISE EXCEPTION 'image metadata unavailable';END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT FROM public.ff66_tones t JOIN storage.objects o ON o.name=t.storage_path AND o.bucket_id='ff-luxe-tones' WHERE t.id=tone_id) THEN RAISE EXCEPTION 'private active tone unavailable to staff';END IF;checks:=checks+1;
 IF EXISTS(SELECT FROM public.ff_a07_design_catalog()) THEN RAISE EXCEPTION 'nonmanager design catalog';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM public.ff53_save_menu_image(image_id,image_path,'item');EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'nonmanager photo write accepted';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM public.ff74_set_global_tones('{"type":"built_in","key":"soft"}','{"type":"built_in","key":"soft"}');EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'nonmanager global tone write accepted';END IF;checks:=checks+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',b::text,true);SET LOCAL ROLE authenticated;
 cat_b:=public.ff49_catalog();settings_b:=public.ff74_get_global_tones();SELECT jsonb_agg(jsonb_build_object('id',id,'path',storage_path) ORDER BY id) INTO tones_b FROM public.ff66_tones;
 IF cat_a IS DISTINCT FROM cat_b OR settings_a IS DISTINCT FROM settings_b OR tones_a IS DISTINCT FROM tones_b THEN RAISE EXCEPTION 'central media different across two accounts';END IF;checks:=checks+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',inactive::text,true);SET LOCAL ROLE authenticated;
 IF EXISTS(SELECT FROM public.ff66_tones) OR EXISTS(SELECT FROM storage.objects WHERE bucket_id='ff-luxe-tones') THEN RAISE EXCEPTION 'inactive account has private tone access';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM public.ff49_catalog();EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'inactive staff catalog access';END IF;checks:=checks+1;
 RESET ROLE;
 IF EXISTS(SELECT FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND 'anon'=ANY(roles) AND (coalesce(qual,'') LIKE '%ff-luxe-tones%' OR coalesce(with_check,'') LIKE '%ff-luxe-tones%')) THEN RAISE EXCEPTION 'anon tone policy';END IF;checks:=checks+1;
 PERFORM set_config('ff.qa.step05',jsonb_build_object('assertions',checks,'invalid_tones_rejected',rejected,'designs',count_packs,'identical_catalog_and_tones',true,'real_image_and_tone',true)::text,true);
END $qa$;
SELECT current_setting('ff.qa.step05')::jsonb AS result;
ROLLBACK;
