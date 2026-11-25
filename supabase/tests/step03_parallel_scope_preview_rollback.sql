BEGIN;
DO $qa$
DECLARE m uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); b2 uuid:=gen_random_uuid(); a bigint; s bigint; j jsonb; before_count bigint; denied boolean:=false;
BEGIN
 INSERT INTO auth.users(id) VALUES(m),(d);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA manager','manager',true),(d,'QA driver','driver',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-'||b,'QA scope'),(b2,'qa-'||b2,'QA alternate');
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 a:=public.ff_a07_named_design('all','all',b,'all','D01','','labels','QA general','',NULL,'{"font":"tahoma","density":"compact"}');PERFORM public.ff_ui_publish(a);
 s:=public.ff_a07_named_design('driver','driver',b,'mobile','D02','','labels','QA exact','',NULL,'{"font":"serif","radius":"round"}');PERFORM public.ff_ui_publish(s);
 RESET ROLE;SELECT count(*) INTO before_count FROM public.ff_ui_versions;SET LOCAL ROLE authenticated;
 j:=public.ff_a07_preview_scope('driver','driver',b,'mobile','D03','{"radius":"square"}','driver','driver',b,'mobile');
 IF j->>'applies' IS DISTINCT FROM 'true' OR j#>>'{before,style_config,font}' IS DISTINCT FROM 'serif' OR j#>>'{after,style_config,font}' IS DISTINCT FROM 'tahoma' OR j#>>'{after,style_config,radius}' IS DISTINCT FROM 'square' OR j#>>'{after,pack}' IS DISTINCT FROM 'D03' OR j#>>'{after_sources,radius}' IS DISTINCT FROM '-1' OR j#>>'{after_sources,font}' IS DISTINCT FROM a::text THEN RAISE EXCEPTION 'preview mismatch %',j;END IF;
 j:=public.ff_a07_preview_scope('driver','driver',b,'mobile','D03','{"radius":"square"}','driver','driver',b,'desktop');
 IF j->>'applies' IS DISTINCT FROM 'false' OR j->'before' IS DISTINCT FROM j->'after' THEN RAISE EXCEPTION 'device leak';END IF;
 j:=public.ff_a07_preview_scope('driver','driver',b,'mobile','D03','{"radius":"square"}','driver','driver',b2,'mobile');
 IF j->>'applies' IS DISTINCT FROM 'false' OR j->'before' IS DISTINCT FROM j->'after' THEN RAISE EXCEPTION 'branch leak';END IF;
 j:=public.ff_a07_preview_scope('all','all',b,'all','D03','{"radius":"square"}','driver','driver',b,'mobile');
 IF j#>>'{after,pack}' IS DISTINCT FROM 'D02' OR j#>>'{after,style_config,radius}' IS DISTINCT FROM 'round' THEN RAISE EXCEPTION 'specificity override';END IF;
 RESET ROLE;IF (SELECT count(*) FROM public.ff_ui_versions)<>before_count THEN RAISE EXCEPTION 'preview persisted a draft';END IF;
 PERFORM set_config('request.jwt.claim.sub',d::text,true);SET LOCAL ROLE authenticated;
 BEGIN PERFORM public.ff_a07_preview_scope('all','all',null,'all','D01','{}','driver','driver',null,'mobile');EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'non-manager preview';END IF;
 RESET ROLE;
END $qa$;
SELECT 'PASS STEP03 parallel scope simulation, precedence, no write and access denial' AS result;
ROLLBACK;