BEGIN;
DO $$
DECLARE v jsonb:='{"reports_actions":[{"key":"ff76Run","shape":"pack","size":"normal","icon":"file","hover":"outline","press":"inset"},{"key":"ff76Preview","shape":"pack","size":"normal"},{"key":"ff76Download","shape":"pack","size":"normal"},{"key":"ff76Share","shape":"pack","size":"normal"}]}';
BEGIN
 IF NOT ff_private.a07_valid_elements(v,'reports') OR ff_private.a07_valid_elements(jsonb_set(v,'{reports_actions,0,icon}','"<script>"'),'reports') THEN RAISE EXCEPTION 'icon validation';END IF;
 IF NOT ff_private.a07_valid_elements('{"driver_status":[{"key":"driver_offer_countdown","shape":"inherit","size":"large","weight":"strong"},{"key":"driver_status_tag","shape":"round","size":"normal"}]}','driver') THEN RAISE EXCEPTION 'dynamic registry';END IF;
 IF ff_private.a07_valid_elements('{"driver_status":[{"key":"driver_offer_countdown","shape":"inherit","size":"large","tone":"light"},{"key":"driver_status_tag","shape":"round","size":"normal"}]}','driver') THEN RAISE EXCEPTION 'critical tone override';END IF;
 IF NOT ff_private.a07_valid_style('{"logoAsset":"mark","logoDarkAsset":"brand","logoWidth":"48","logoPosition":"cover"}') OR ff_private.a07_valid_style('{"logoAsset":"https://example.invalid/logo.png"}') OR ff_private.a07_valid_style('{"logoWidth":"100000"}') THEN RAISE EXCEPTION 'logo allowlist';END IF;
 IF ff_private.a09_merge_elements('reports',v,null,jsonb_set(v,'{reports_actions,0,icon}','"star"'),ARRAY['buttons']) IS NOT NULL THEN RAISE EXCEPTION 'delegated advanced icon changed';END IF;
END $$;
SELECT 'PASS STEP03 logo, state styling and safety validation' AS result;
ROLLBACK;