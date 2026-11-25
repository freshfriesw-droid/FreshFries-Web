BEGIN;
DO $$
DECLARE v jsonb:='{"reports_actions":[{"key":"ff76Run","shape":"pack","size":"normal","tone":"navy","weight":"strong"},{"key":"ff76Preview","shape":"pack","size":"normal"},{"key":"ff76Download","shape":"pack","size":"normal"},{"key":"ff76Share","shape":"pack","size":"normal"}]}'; bad jsonb; x jsonb;
BEGIN
 IF NOT ff_private.a07_valid_elements(v,'reports') OR NOT ff_private.a07_valid_elements(v,'all') OR ff_private.a07_valid_elements(v,'orders') THEN RAISE EXCEPTION 'scope validation failed'; END IF;
 FOREACH bad IN ARRAY ARRAY[jsonb_set(v,'{reports_actions,0,tone}','"url(evil)"'),jsonb_set(v,'{reports_actions,0,weight}','null'),jsonb_set(v,'{reports_actions,0,display}','"none"'),jsonb_set(v,'{reports_actions,1,key}','"ff76Run"')] LOOP
 IF ff_private.a07_valid_elements(bad,'reports') THEN RAISE EXCEPTION 'unsafe value accepted %',bad; END IF;
 END LOOP;
 IF ff_private.a07_valid_elements('{"cashier_stage":[{"key":"cashier_stage","shape":"pack","size":"normal","tone":"red"}]}','cashier') THEN RAISE EXCEPTION 'critical state tone allowed'; END IF;
 x:=jsonb_set(v,'{reports_actions,0,shape}','"pill"');
 IF ff_private.a09_merge_elements('reports',v,null,x,ARRAY['buttons']) IS DISTINCT FROM x THEN RAISE EXCEPTION 'legacy delegated edit rejected'; END IF;
 IF ff_private.a09_merge_elements('reports',v,null,jsonb_set(v,'{reports_actions,0,tone}','"red"'),ARRAY['buttons','layout']) IS NOT NULL THEN RAISE EXCEPTION 'delegated unauthorized color change'; END IF;
 IF ff_private.a09_merge_elements('reports',v,null,v #- '{reports_actions,0,tone}',ARRAY['buttons','layout']) IS NOT NULL THEN RAISE EXCEPTION 'delegated removal allowed'; END IF;
END $$;
SELECT 'STEP03 bounded property and delegation checks passed' AS result;
ROLLBACK;