BEGIN;
DO $qa$
DECLARE a jsonb:='{"driver_actions":[{"key":"ff51BreakBtn","shape":"inherit","size":"inherit"},{"key":"clockInBtn","shape":"inherit","size":"inherit","font":"cairo","align":"center"},{"key":"clockOutBtn","shape":"inherit","size":"inherit"}]}'::jsonb;
        b jsonb:='{"driver_actions":[{"key":"ff51BreakBtn","shape":"inherit","size":"inherit"},{"key":"clockInBtn","shape":"inherit","size":"inherit","textScale":"large"},{"key":"clockOutBtn","shape":"inherit","size":"inherit"}]}'::jsonb;
        resolved jsonb; merged jsonb; invalid jsonb;
BEGIN
 IF NOT ff_private.a07_valid_elements(a,'driver') OR NOT ff_private.a07_valid_elements(b,'driver') OR NOT ff_private.a07_valid_style(jsonb_build_object('elements',a)) THEN RAISE EXCEPTION 'valid element alignment or typography rejected'; END IF;
 IF NOT ff_private.a07_valid_elements(jsonb_set(a,'{driver_actions,1,font}','"noto"'),'driver') THEN RAISE EXCEPTION 'supported fallback font rejected'; END IF;
 IF ff_private.a07_valid_elements(a,'cashier') THEN RAISE EXCEPTION 'cross-screen alignment accepted'; END IF;
 FOREACH invalid IN ARRAY ARRAY[
   jsonb_set(a,'{driver_actions,1,align}','"position:absolute"'),
   jsonb_set(a,'{driver_actions,1,textScale}','"0px"'),
   jsonb_set(a,'{driver_actions,1,font}','"url(https://example.com)"'),
   jsonb_set(a,'{driver_actions,1,align}','null')
 ] LOOP
  IF ff_private.a07_valid_elements(invalid,'driver') THEN RAISE EXCEPTION 'unsafe property accepted';END IF;
 END LOOP;
 resolved:=ff_private.a07_merge_style_candidates('driver',jsonb_build_array(
 jsonb_build_object('revision',102,'style',jsonb_build_object('elements',b),'rank_order',1),
 jsonb_build_object('revision',101,'style',jsonb_build_object('elements',a),'rank_order',2)));
 IF resolved#>>'{style,elements,driver_actions,1,align}' IS DISTINCT FROM 'center'
 OR resolved#>>'{style,elements,driver_actions,1,font}' IS DISTINCT FROM 'cairo'
 OR resolved#>>'{style,elements,driver_actions,1,textScale}' IS DISTINCT FROM 'large'
 OR resolved#>>'{sources,elements.driver_actions.clockInBtn.align}' IS DISTINCT FROM '101'
 OR resolved#>>'{sources,elements.driver_actions.clockInBtn.textScale}' IS DISTINCT FROM '102' THEN RAISE EXCEPTION 'per-property inheritance/source mismatch: %',resolved; END IF;
 IF ff_private.a09_merge_elements('driver',a,a,jsonb_set(a,'{driver_actions,1,align}','"end"'),ARRAY['layout','buttons','colors']) IS NOT NULL THEN RAISE EXCEPTION 'advanced alignment unauthorized by existing delegated capabilities'; END IF;
 merged:=ff_private.a09_merge_elements('driver',a,a,jsonb_set(a,'{driver_actions,1,shape}','"round"'),ARRAY['buttons','layout']);
 IF merged#>>'{driver_actions,1,align}' IS DISTINCT FROM 'center' OR merged#>>'{driver_actions,1,shape}' IS DISTINCT FROM 'round' THEN RAISE EXCEPTION 'delegated allowed change lost manager alignment'; END IF;
END $qa$;
SELECT 'PASS STEP03 individual alignment, independent text size, inheritance, fonts and delegation guard' AS result;
ROLLBACK;
