BEGIN;
DO $qa$
DECLARE m uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); b2 uuid:=gen_random_uuid(); general_id bigint; exact_id bigint; before_count bigint; j jsonb; target record; denied boolean;
general_style jsonb:='{"elements":{"driver_actions":[{"key":"ff51BreakBtn","shape":"inherit","size":"inherit","orderMode":"inherit"},{"key":"clockInBtn","shape":"round","size":"normal","font":"tahoma","align":"center","orderMode":"inherit"},{"key":"clockOutBtn","shape":"inherit","size":"inherit","orderMode":"inherit"}]}}';
exact_style jsonb:='{"elements":{"driver_actions":[{"key":"ff51BreakBtn","shape":"inherit","size":"inherit","orderMode":"inherit"},{"key":"clockInBtn","shape":"inherit","size":"inherit","font":"serif","orderMode":"inherit"},{"key":"clockOutBtn","shape":"inherit","size":"inherit","orderMode":"inherit"}]}}';
draft_style jsonb:='{"elements":{"driver_actions":[{"key":"ff51BreakBtn","shape":"inherit","size":"inherit","orderMode":"inherit"},{"key":"clockInBtn","shape":"inherit","size":"large","orderMode":"inherit"},{"key":"clockOutBtn","shape":"inherit","size":"inherit","orderMode":"inherit"}]}}';
BEGIN
 INSERT INTO auth.users(id) VALUES(m),(d);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP03 provenance manager','manager',true),(d,'QA STEP03 provenance driver','driver',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-'||b,'QA provenance'),(b2,'qa-'||b2,'QA other');
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 general_id:=public.ff_a07_named_design('all','all',b,'all','D01','','labels','QA provenance general','',NULL,general_style);
 PERFORM public.ff_ui_publish(general_id);
 exact_id:=public.ff_a07_named_design('driver','driver',b,'mobile','D02','','labels','QA provenance exact','',NULL,exact_style);
 PERFORM public.ff_ui_publish(exact_id);
 RESET ROLE;SELECT count(*) INTO before_count FROM public.ff_ui_versions;SET LOCAL ROLE authenticated;
 j:=public.ff_a07_manager_style_layers('driver','driver',b,'mobile');
 IF j#>>'{sources,elements.driver_actions.clockInBtn.font}' IS DISTINCT FROM exact_id::text OR j#>>'{sources,elements.driver_actions.clockInBtn.shape}' IS DISTINCT FROM general_id::text OR j#>>'{sources,elements.driver_actions.clockInBtn.align}' IS DISTINCT FROM general_id::text THEN RAISE EXCEPTION 'published per-property provenance mismatch';END IF;
 j:=public.ff_a07_preview_scope('driver','driver',b,'mobile','D03',draft_style,'driver','driver',b,'mobile');
 IF j->>'applies' IS DISTINCT FROM 'true' OR j#>>'{before_sources,elements.driver_actions.clockInBtn.font}' IS DISTINCT FROM exact_id::text OR j#>>'{after_sources,elements.driver_actions.clockInBtn.font}' IS DISTINCT FROM general_id::text OR j#>>'{after_sources,elements.driver_actions.clockInBtn.size}' IS DISTINCT FROM '-1' OR j#>>'{after_sources,elements.driver_actions.clockInBtn.shape}' IS DISTINCT FROM general_id::text THEN RAISE EXCEPTION 'draft per-property provenance mismatch';END IF;
 FOR target IN SELECT * FROM (VALUES ('driver','driver',b,'desktop'),('driver','driver',b2,'mobile'),('driver','cashier',b,'mobile'),('orders','driver',b,'mobile')) AS t(screen,role,branch,device) LOOP
  j:=public.ff_a07_preview_scope('driver','driver',b,'mobile','D03',draft_style,target.screen,target.role,target.branch,target.device);
  IF j->>'applies' IS DISTINCT FROM 'false' OR j->'before_sources' IS DISTINCT FROM j->'after_sources' OR j->'before' IS DISTINCT FROM j->'after' OR EXISTS(SELECT 1 FROM jsonb_each_text(coalesce(j->'after_sources','{}')) s WHERE s.value IN ('-1',exact_id::text)) THEN RAISE EXCEPTION 'foreign scope leaked';END IF;
 END LOOP;
 RESET ROLE;IF (SELECT count(*) FROM public.ff_ui_versions)<>before_count THEN RAISE EXCEPTION 'preview persisted';END IF;
 PERFORM set_config('request.jwt.claim.sub',d::text,true);SET LOCAL ROLE authenticated;
 denied:=false;BEGIN PERFORM public.ff_a07_manager_style_layers('driver','driver',b,'mobile');EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'non-manager source disclosure';END IF;
 denied:=false;BEGIN PERFORM public.ff_a07_preview_scope('driver','driver',b,'mobile','D03',draft_style,'driver','driver',b,'mobile');EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'non-manager preview disclosure';END IF;
 RESET ROLE;
END $qa$;
SELECT 'PASS STEP03 per-element provenance: published + draft, 4 foreign scopes, no persisted preview, 2 permission denials' AS result;
ROLLBACK;
