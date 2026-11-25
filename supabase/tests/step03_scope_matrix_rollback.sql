BEGIN;
DO $qa$
DECLARE m uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); b2 uuid:=gen_random_uuid(); ids bigint[]:=ARRAY[]::bigint[]; i int; t int; rev bigint; expected bigint[]; actual bigint[]; j jsonb; checked int:=0; cfg jsonb:='{"elements":{"driver_actions":[{"key":"ff51BreakBtn","shape":"inherit","size":"inherit"},{"key":"clockInBtn","shape":"round","size":"normal","align":"center"},{"key":"clockOutBtn","shape":"inherit","size":"inherit"}]}}';
BEGIN
 INSERT INTO auth.users(id) VALUES(m);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP03 scope ranking','manager',true) ON CONFLICT(user_id) DO UPDATE SET role='manager',active=true;
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-'||b,'QA first'),(b2,'qa-'||b2,'QA other');
 PERFORM set_config('request.jwt.claim.sub',m::text,true); SET LOCAL ROLE authenticated;
 FOR i IN 0..15 LOOP
  rev:=public.ff_a07_named_design(CASE WHEN (i&8)>0 THEN 'driver' ELSE 'all' END,CASE WHEN (i&4)>0 THEN 'driver' ELSE 'all' END,CASE WHEN (i&2)>0 THEN b ELSE NULL END,CASE WHEN (i&1)>0 THEN 'mobile' ELSE 'all' END,'D01','','labels','QA rank '||i,'',NULL,cfg);
  PERFORM public.ff_ui_publish(rev);
  ids:=array_append(ids,rev);
 END LOOP;
 j:=public.ff_a07_manager_style_layers('driver','driver',b,'mobile');
 IF j->'sources'->>'elements.driver_actions.clockInBtn.align' IS DISTINCT FROM ids[16]::text THEN RAISE EXCEPTION 'effective source %',j;END IF;
 RESET ROLE;
 FOR t IN 0..15 LOOP
  SELECT array_agg(ids[n+1] ORDER BY ((n&8)/8+(n&4)/4+(n&2)/2+(n&1)) DESC,n DESC) INTO expected FROM generate_series(0,15) n WHERE (n&t)=n;
  SELECT array_agg(revision ORDER BY rank_order) INTO actual FROM ff_private.a07_ranked_candidates(CASE WHEN (t&8)>0 THEN 'driver' ELSE 'orders' END,CASE WHEN (t&4)>0 THEN 'driver' ELSE 'cashier' END,CASE WHEN (t&2)>0 THEN b ELSE b2 END,CASE WHEN (t&1)>0 THEN 'mobile' ELSE 'desktop' END,m) WHERE revision=ANY(ids);
  IF actual IS DISTINCT FROM expected THEN RAISE EXCEPTION 'scope specificity or isolation % expected % actual %',t,expected,actual;END IF;
  checked:=checked+1;
 END LOOP;
 IF checked<>16 THEN RAISE EXCEPTION 'incomplete';END IF;
END $qa$;
SELECT 'PASS STEP03 16 real published scope combinations x 16 target combinations, exact ranked matches and per-element source' AS result;
ROLLBACK;