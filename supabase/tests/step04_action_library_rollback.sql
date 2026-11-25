-- STEP04: server whitelist, backward compatibility and safe copied instances; no persistent data.
BEGIN;
DO $qa$
DECLARE k text; cfg jsonb; bad jsonb; accepted int:=0; rejected int:=0;
BEGIN
 FOREACH k IN ARRAY ARRAY['home','new','orders','late','drivers','driver','cashier','reservations','transfer','routes','messages','cases','offers','attendance','burger','cashier_finished','reports','archive','ratings','settlements','rewards','catalog','customers','changes','team','assembly_admin','applications','application_alerts','branch_policy','staff_link','studio','data_center','security','integrity','access','readiness','qa','diagnostics','settings','refresh'] LOOP
  cfg:=jsonb_build_object('key',k,'label','اختصار آمن','icon','orders','size','wide','tone','red');
  IF NOT ff_private.a08_valid_actions(jsonb_build_array(k,cfg,cfg)) OR NOT ff_private.a07_valid_style(jsonb_build_object('quickActions',jsonb_build_array(cfg))) THEN RAISE EXCEPTION 'registered action rejected %',k; END IF;
  accepted:=accepted+1;
 END LOOP;
 FOR bad IN SELECT value FROM jsonb_array_elements('[null,{},["orders","orders"],["unknown"],["javascript:evil"],[{"key":"orders","label":"<script>","icon":"orders","size":"normal","tone":"default"}],[{"key":"orders","label":"https://example.com","icon":"orders","size":"normal","tone":"default"}],[{"key":"orders","label":"x","icon":"unknown","size":"normal","tone":"default"}],[{"key":"orders","label":"x","icon":"orders","size":"100vw","tone":"default"}],[{"key":"orders","label":"x","icon":"orders","size":"normal","tone":"url(evil)"}],[{"key":"orders","label":"x","icon":"orders","size":"normal","tone":"default","permission":"manager"}],[{"key":"orders","label":"x","icon":"orders","size":"normal","tone":"default","handler":"evil"}],[{"key":"orders","label":null,"icon":"orders","size":"normal","tone":"default"}]]'::jsonb) LOOP
  IF ff_private.a08_valid_actions(bad) THEN RAISE EXCEPTION 'unsafe layout accepted %',bad; END IF; rejected:=rejected+1;
 END LOOP;
 IF ff_private.a08_valid_actions(NULL) OR NOT ff_private.a08_valid_actions('[]') OR NOT ff_private.a08_valid_actions('["orders","reports"]') THEN RAISE EXCEPTION 'legacy/empty contract'; END IF;
 PERFORM set_config('ff.qa.step04',jsonb_build_object('registered_actions',accepted,'unsafe_rejected',rejected,'legacy_and_empty',true)::text,true);
END $qa$;
SELECT current_setting('ff.qa.step04')::jsonb AS result;
-- Exercise the real save/publish/resolution/authorization path using synthetic scoped identities.
DO $qa$
DECLARE m uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); b1 uuid:=gen_random_uuid(); b2 uuid:=gen_random_uuid(); v1 bigint; v2 bigint; stale bigint; resolved jsonb; before_perm jsonb; after_perm jsonb; denied boolean; original_count int; checks int:=0;
 cfg jsonb:='["orders",{"key":"archive","label":"أرشيف مخصص","icon":"star","size":"full","tone":"red"},{"key":"archive","label":"نسخة","icon":"clock","size":"normal","tone":"neutral"}]';
 cards jsonb:='[{"metric":"orders_today","label":"طلبات اليوم","size":"normal","tone":"default"}]';
BEGIN
 SELECT count(*) INTO original_count FROM public.ff_ui_versions;
 INSERT INTO auth.users(id) VALUES(m),(u);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP04 manager','manager',true),(u,'QA STEP04 cashier','cashier',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=excluded.active;
 INSERT INTO public.ff_branches(id,code,name,active) VALUES(b1,'qa-'||b1,'QA STEP04 own',true),(b2,'qa-'||b2,'QA STEP04 other',true);
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(u,b1);
 PERFORM set_config('request.jwt.claim.sub',u::text,true);SET LOCAL ROLE authenticated;
 before_perm:=public.ff38_my_permissions();
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 v1:=public.ff_a07_named_design('dashboard','cashier',b1,'mobile','D01','','labels','QA STEP04 first','',cards,jsonb_build_object('quickActions',cfg));
 stale:=public.ff_a07_named_design('dashboard','cashier',b1,'mobile','D01','','labels','QA STEP04 stale','',cards,jsonb_build_object('quickActions',cfg));
 PERFORM public.ff_ui_publish(v1);checks:=checks+1;
 denied:=false;BEGIN PERFORM public.ff_ui_publish(stale);EXCEPTION WHEN SQLSTATE 'P0001' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'stale draft published';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM public.ff_a07_named_design('dashboard','cashier',b1,'mobile','D01','','labels','QA STEP04 unsafe','',cards,'{"quickActions":[{"key":"orders","label":"x","icon":"orders","size":"normal","tone":"default","handler":"evil"}]}');EXCEPTION WHEN OTHERS THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'unsafe direct RPC accepted';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM public.ff_a07_named_design('cashier','cashier',b1,'mobile','D01','','labels','QA STEP04 wrong screen','',NULL,jsonb_build_object('quickActions',cfg));EXCEPTION WHEN OTHERS THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'wrong screen accepted';END IF;checks:=checks+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',u::text,true);SET LOCAL ROLE authenticated;
 resolved:=public.ff_a07_effective_designs(b1,'mobile');
 IF resolved->'dashboard'->'style_config'->'quickActions' IS DISTINCT FROM cfg THEN RAISE EXCEPTION 'published layout not resolved %',resolved;END IF;checks:=checks+1;
 IF public.ff_a07_effective_designs(b1,'desktop')->'dashboard'->'style_config'->'quickActions'=cfg THEN RAISE EXCEPTION 'mobile scope leaked';END IF;checks:=checks+1;
 after_perm:=public.ff38_my_permissions();IF after_perm IS DISTINCT FROM before_perm THEN RAISE EXCEPTION 'permissions changed';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM public.ff_a07_effective_designs(b2,'mobile');EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'foreign branch accepted';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM public.ff_a07_named_design('dashboard','cashier',b1,'mobile','D01','','labels','QA STEP04 employee','',cards,jsonb_build_object('quickActions',cfg));EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'nonmanager saved';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM public.ff_ui_publish(stale);EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'nonmanager published';END IF;checks:=checks+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 v2:=public.ff_a07_named_design('dashboard','cashier',b1,'mobile','D01','','labels','QA STEP04 empty','',cards,'{"quickActions":[]}');
 PERFORM public.ff_ui_publish(v2);
 IF public.ff_a07_effective_designs(b1,'mobile')->'dashboard'->'style_config'->'quickActions'=cfg THEN RAISE EXCEPTION 'empty layout not applied';END IF;
 PERFORM public.ff_ui_rollback(v2);checks:=checks+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',u::text,true);SET LOCAL ROLE authenticated;
 IF public.ff_a07_effective_designs(b1,'mobile')->'dashboard'->'style_config'->'quickActions' IS DISTINCT FROM cfg THEN RAISE EXCEPTION 'rollback did not restore shortcut configuration';END IF;checks:=checks+1;
 RESET ROLE;
 IF has_function_privilege('anon','ff_private.a08_valid_actions(jsonb)','EXECUTE') OR has_function_privilege('authenticated','ff_private.a08_valid_actions(jsonb)','EXECUTE') THEN RAISE EXCEPTION 'private validator exposed';END IF;checks:=checks+1;
 PERFORM set_config('ff.qa.step04.integration',jsonb_build_object('integration_assertions',checks,'stale_publish_rejected',true,'scope_and_permissions_preserved',true,'rollback_restored',true,'versions_before',original_count)::text,true);
END $qa$;
SELECT current_setting('ff.qa.step04.integration')::jsonb AS integration_result;
ROLLBACK;
