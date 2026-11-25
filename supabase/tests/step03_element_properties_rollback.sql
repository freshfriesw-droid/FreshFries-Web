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
DO $qa$
DECLARE m uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); a bigint; s bigint; j jsonb; base jsonb:='{"elements":{"driver_actions":[{"key":"ff51BreakBtn","shape":"pack","size":"normal"},{"key":"clockInBtn","shape":"round","size":"large","weight":"strong"},{"key":"clockOutBtn","shape":"outline","size":"normal"}]}}'; specific jsonb;
BEGIN
 INSERT INTO auth.users(id) VALUES(m);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA manager','manager',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-'||b,'QA scope');
 PERFORM set_config('request.jwt.claim.sub',m::text,true); SET LOCAL ROLE authenticated;
 a:=public.ff_a07_named_design('all','all',b,'all','D01','','labels','QA element baseline','',NULL,base);PERFORM public.ff_ui_publish(a);
 specific:=jsonb_set(jsonb_set(jsonb_set(base,'{elements,driver_actions,1,shape}','"inherit"'),'{elements,driver_actions,1,size}','"inherit"'),'{elements,driver_actions,1,font}','"tahoma"') #- '{elements,driver_actions,1,weight}';
 s:=public.ff_a07_named_design('driver','driver',b,'mobile','D02','','labels','QA element specific','',NULL,specific);PERFORM public.ff_ui_publish(s);
 j:=public.ff_a07_manager_style_layers('driver','driver',b,'mobile');
 IF j#>>'{style,elements,driver_actions,1,shape}' IS DISTINCT FROM 'round' OR j#>>'{style,elements,driver_actions,1,size}' IS DISTINCT FROM 'large' OR j#>>'{style,elements,driver_actions,1,weight}' IS DISTINCT FROM 'strong' OR j#>>'{style,elements,driver_actions,1,font}' IS DISTINCT FROM 'tahoma' THEN RAISE EXCEPTION 'property inheritance %',j; END IF;
 IF j->'sources'->>'elements.driver_actions.clockInBtn.shape' IS DISTINCT FROM a::text OR j->'sources'->>'elements.driver_actions.clockInBtn.weight' IS DISTINCT FROM a::text OR j->'sources'->>'elements.driver_actions.clockInBtn.font' IS DISTINCT FROM s::text THEN RAISE EXCEPTION 'property source %',j; END IF;
 j:=public.ff_a07_manager_style_layers('driver','driver',b,'desktop');
 IF j#>'{style,elements,driver_actions,1,font}' IS NOT NULL THEN RAISE EXCEPTION 'device leak %',j; END IF;
 RESET ROLE;
END $qa$;
SELECT 'STEP03 bounded property and delegation checks passed' AS result;
ROLLBACK;