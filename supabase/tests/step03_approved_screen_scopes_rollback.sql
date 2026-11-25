BEGIN;
DO $qa$
DECLARE m uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); a bigint; l bigint; c bigint; f bigint; j jsonb; denied boolean; 
BEGIN
 INSERT INTO auth.users(id) VALUES(m),(d);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA manager','manager',true),(d,'QA driver','driver',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-'||b,'QA screen');
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 a:=public.ff_a07_named_design('all','all',NULL,'all','D03','INTERNAL ONLY','labels','QA general','',NULL,'{"font":"serif"}');PERFORM public.ff_ui_publish(a);
 l:=public.ff_a07_named_design('login','all',NULL,'mobile','D05','Public sample','labels','QA login','',NULL,'{"font":"tahoma","logoAsset":"mark"}');PERFORM public.ff_ui_publish(l);
 c:=public.ff_a07_named_design('customer_portal','all',NULL,'all','D06','','labels','QA unpublished portal','',NULL,'{"radius":"round"}');
 f:=public.ff_a07_named_design('finance','manager',b,'mobile','D07','','labels','QA finance','',NULL,'{"density":"compact"}');PERFORM public.ff_ui_publish(f);
 IF EXISTS(SELECT 1 FROM public.ff_ui_trial_accounts(c)) THEN RAISE EXCEPTION 'public account trial must be unavailable'; END IF;
 denied:=false;BEGIN PERFORM public.ff_a07_named_design('login','driver',b,'all','D01','','labels','QA invalid','',NULL,'{}');EXCEPTION WHEN check_violation THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'invalid public scope';END IF;
 j:=public.ff_a07_effective_designs(b,'mobile');IF j#>>'{finance,pack}' IS DISTINCT FROM 'D07' OR j ? 'login' OR j ? 'customer_portal' THEN RAISE EXCEPTION 'staff scope mismatch';END IF;
 j:=public.ff_a07_preview_scope('all','all',NULL,'all','D03','{}','login','all',NULL,'mobile');IF j->>'applies' IS DISTINCT FROM 'false' OR j->'before' IS DISTINCT FROM j->'after' THEN RAISE EXCEPTION 'staff general scope leaked';END IF;
 j:=public.ff_a07_preview_scope('login','all',NULL,'mobile','D04','{"radius":"square"}','login','all',NULL,'mobile');IF j->>'applies' IS DISTINCT FROM 'true' OR j#>>'{after,pack}' IS DISTINCT FROM 'D04' OR j#>>'{before,pack}' IS DISTINCT FROM 'D05' THEN RAISE EXCEPTION 'public preview mismatch';END IF;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub','',true);SET LOCAL ROLE anon;
 j:=public.ff_a07_public_appearance('login','mobile');IF j#>>'{pack}' IS DISTINCT FROM 'D05' OR j#>>'{style_config,font}' IS DISTINCT FROM 'tahoma' OR j->>'layout_text' IS DISTINCT FROM 'Public sample' OR j ? 'id' OR j ? 'actor_id' THEN RAISE EXCEPTION 'public exposure mismatch %',j;END IF;
 IF public.ff_a07_public_appearance('login','desktop') ? 'pack' OR public.ff_a07_public_appearance('customer_portal','mobile') ? 'pack' THEN RAISE EXCEPTION 'unpublished or device leak';END IF;
 denied:=false;BEGIN PERFORM public.ff_a07_public_appearance('finance','mobile');EXCEPTION WHEN invalid_parameter_value THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'internal scope exposed';END IF;
 RESET ROLE;
END $qa$;
SELECT 'PASS STEP03 approved screen scopes and anonymous published-only isolation' AS result;
ROLLBACK;