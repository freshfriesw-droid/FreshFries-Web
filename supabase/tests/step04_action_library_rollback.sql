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
ROLLBACK;
