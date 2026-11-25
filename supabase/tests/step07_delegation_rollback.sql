BEGIN;
-- Isolated synthetic users and branch. No real operational records; rollback all fixtures.
DO $setup$
DECLARE recipient uuid:=gen_random_uuid(); manager_id uuid:=gen_random_uuid(); branch_id uuid:=gen_random_uuid();
BEGIN
 INSERT INTO auth.users(id) VALUES(recipient),(manager_id);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(recipient,'QA-STEP07 worker','cashier',true),(manager_id,'QA-STEP07 manager','manager',true)
 ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_branches(id,code,name) VALUES(branch_id,'qa-step07-'||branch_id,'QA-STEP07');
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(recipient,branch_id);
 PERFORM set_config('qa.step07.worker',recipient::text,true);
 PERFORM set_config('qa.step07.manager',manager_id::text,true);
 PERFORM set_config('qa.step07.branch',branch_id::text,true);
END $setup$;
SET LOCAL ROLE authenticated;
DO $qa$
DECLARE kind text; worker uuid:=current_setting('qa.step07.worker')::uuid; mgr uuid:=current_setting('qa.step07.manager')::uuid; branch uuid:=current_setting('qa.step07.branch')::uuid; grant_id bigint; patch jsonb; result jsonb; rev bigint;
BEGIN
 FOR kind,patch IN SELECT * FROM (VALUES
 ('design','{"designPack":"D02"}'::jsonb),
 ('fonts','{"font":"tahoma","scale":"large"}'::jsonb),
 ('identity','{"logoWidth":"40%","logoPosition":"cover"}'::jsonb),
 ('media','{"logoAsset":"mark","logoDarkAsset":"brand"}'::jsonb),
 ('layout','{"designBar":"icons","dialogRadius":"round"}'::jsonb),
 ('colors','{"accent":"red"}'::jsonb),
 ('buttons','{"button":"pill"}'::jsonb),
 ('cards','{"dashboardPanels":{"activity":true},"cardLayout":[{"metric":"orders_today","label":"QA STEP07","size":"normal","tone":"default"}]}'::jsonb)) x(k,p)
 LOOP
  PERFORM set_config('request.jwt.claim.sub',mgr::text,true);
  grant_id:=public.ff_a09_set_grant(worker,branch,CASE WHEN kind='cards' THEN 'dashboard' ELSE 'orders' END,ARRAY['view','edit','preview','review'],clock_timestamp()-interval '1 second',clock_timestamp()+interval '5 minutes',ARRAY[kind]);
  IF grant_id IS NULL THEN RAISE EXCEPTION 'grant failed %',kind;END IF;
  PERFORM set_config('request.jwt.claim.sub',worker::text,true);
  IF public.ff_a09_design_context('mobile') IS NULL THEN RAISE EXCEPTION 'context missing %',kind;END IF;
  result:=public.ff_a09_design_draft('mobile',patch,'QA STEP07',NULL);
  IF result->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'allowed patch rejected % %',kind,result;END IF;
  rev:=(result->>'revision')::bigint;
  IF NOT EXISTS(SELECT FROM public.ff_a09_design_history('mobile') WHERE id=rev AND published_at IS NULL AND screen_scope=CASE WHEN kind='cards' THEN 'dashboard' ELSE 'orders' END AND role_scope='cashier' AND branch_id=branch) THEN RAISE EXCEPTION 'scope failure %',kind;END IF;
  IF (public.ff_a09_design_review(rev,'QA STEP07 review')->>'ok') IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'review rejected %',kind;END IF;
  IF (public.ff_a09_design_draft('mobile','{"rawCss":"x"}','QA reject',NULL)->>'ok') IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'raw CSS accepted %',kind;END IF;
  IF kind<>'design' AND (public.ff_a09_design_draft('mobile','{"designPack":"D02"}','QA reject',NULL)->>'ok') IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'pack crossed scope %',kind;END IF;
  IF kind<>'media' AND (public.ff_a09_design_draft('mobile','{"logoAsset":"mark"}','QA reject',NULL)->>'ok') IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'media crossed scope %',kind;END IF;
  BEGIN
   PERFORM public.ff82_revoke_grant(grant_id);
   RAISE EXCEPTION 'worker revoke unexpectedly returned' USING ERRCODE='XX000';
  EXCEPTION WHEN SQLSTATE 'P0001' OR SQLSTATE '42501' THEN NULL;
  END;
  PERFORM set_config('request.jwt.claim.sub',mgr::text,true);
  IF NOT public.ff82_revoke_grant(grant_id) THEN RAISE EXCEPTION 'manager revoke failed';END IF;
  PERFORM set_config('request.jwt.claim.sub',worker::text,true);
  IF EXISTS(SELECT FROM public.ff82_my_grant()) OR public.ff_a09_design_context('mobile') IS NOT NULL OR (public.ff_a09_design_draft('mobile',patch,'QA revoked',NULL)->>'ok') IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'revoked grant still effective %',kind;END IF;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',mgr::text,true);
 grant_id:=public.ff_a09_set_grant(worker,branch,'orders',ARRAY['view'],clock_timestamp()-interval '1 second',clock_timestamp()+interval '5 minutes',ARRAY['design']);
 PERFORM set_config('request.jwt.claim.sub',worker::text,true);
 IF (public.ff_a09_design_draft('mobile','{"designPack":"D02"}','QA view only',NULL)->>'ok') IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'view-only edit accepted';END IF;
 IF (public.ff_a09_design_review(rev,'QA view only')->>'ok') IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'view-only review accepted';END IF;
 PERFORM set_config('request.jwt.claim.sub',mgr::text,true);
 grant_id:=public.ff_a09_set_grant(worker,branch,'orders',ARRAY['edit'],clock_timestamp()-interval '1 second',clock_timestamp()+interval '150 milliseconds',ARRAY['design']);
 PERFORM pg_sleep(0.2);
 PERFORM set_config('request.jwt.claim.sub',worker::text,true);
 IF EXISTS(SELECT FROM public.ff82_my_grant()) OR (public.ff_a09_design_draft('mobile','{"designPack":"D02"}','QA expired',NULL)->>'ok') IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'expired grant accepted';END IF;
END $qa$;
RESET ROLE;
DO $audit$
BEGIN
 IF NOT EXISTS(SELECT FROM public.ff82_content_audit WHERE actor_id=current_setting('qa.step07.worker')::uuid AND action='design_draft' AND outcome='denied' AND effect='no_change') THEN RAISE EXCEPTION 'denial audit missing';END IF;
 IF EXISTS(SELECT FROM public.ff_ui_versions WHERE actor_id=current_setting('qa.step07.worker')::uuid AND published_at IS NOT NULL) THEN RAISE EXCEPTION 'unexpected publication';END IF;
END $audit$;
-- Additional acceptance: independent capabilities, effective inheritance, role/branch changes and audit.
DO $more$
DECLARE worker uuid:=current_setting('qa.step07.worker')::uuid; mgr uuid:=current_setting('qa.step07.manager')::uuid; br uuid:=current_setting('qa.step07.branch')::uuid; other uuid:=gen_random_uuid(); gid bigint; rev bigint; base bigint; r jsonb; checks int:=0; e jsonb; cards jsonb:='[{"metric":"orders_today","label":"QA inherited card","size":"normal","tone":"default"}]';
BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(other,'qa-step07-other-'||other,'QA-STEP07 other branch');
 PERFORM set_config('request.jwt.claim.sub',mgr::text,true);
 SET LOCAL ROLE authenticated;
 base:=public.ff_a07_named_design('dashboard','cashier',br,'all','D02','','labels','QA inherited','',cards,'{}');
 PERFORM public.ff_ui_publish(base);
 base:=public.ff_a07_named_design('dashboard','cashier',br,'mobile','D01','','labels','QA exact','',NULL,'{"dashboardPanels":{"shortcuts":false,"branches":true}}');
 PERFORM public.ff_ui_publish(base);
 gid:=public.ff_a09_set_grant(worker,br,'dashboard',ARRAY['view','edit','preview','review'],clock_timestamp()-interval '1 minute',clock_timestamp()+interval '5 minutes',ARRAY['cards']);
 PERFORM set_config('request.jwt.claim.sub',worker::text,true);
 r:=public.ff_a09_design_context('mobile');
 IF r->'card_layout' IS DISTINCT FROM cards THEN RAISE EXCEPTION 'Inherited cards missing %',r; END IF;checks:=checks+1;
 r:=public.ff_a09_design_draft('mobile','{"dashboardPanels":{"activity":false}}','QA panel partial',NULL);
 IF r->>'ok'<>'true' THEN RAISE EXCEPTION 'Panel patch failed %',r;END IF; rev:=(r->>'revision')::bigint;
 IF NOT EXISTS(SELECT FROM public.ff_a09_design_history('mobile') WHERE id=rev AND style_config->'dashboardPanels'='{"activity":false,"shortcuts":false,"branches":true}'::jsonb AND published_at IS NULL) THEN RAISE EXCEPTION 'Panel patch erased other settings';END IF;checks:=checks+1;
 IF public.ff_a09_design_context('mobile')->'card_layout' IS DISTINCT FROM cards THEN RAISE EXCEPTION 'Draft leaked to effective context';END IF;checks:=checks+1;
 r:=public.ff_a09_design_draft('mobile','{"quickActions":["new"]}','QA scope violation',NULL);
 IF r->>'ok'<>'false' THEN RAISE EXCEPTION 'cards grant changed actions';END IF;checks:=checks+1;
 r:=public.ff_a09_design_draft('mobile','{"cardLayout":[{"metric":"secret","label":"QA","size":"normal","tone":"default"}]}','QA bad card',NULL);
 IF r->>'ok'<>'false' THEN RAISE EXCEPTION 'invalid metric accepted';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',mgr::text,true);
 gid:=public.ff_a09_set_grant(worker,br,'dashboard',ARRAY['edit','preview'],clock_timestamp()-interval '1 second',clock_timestamp()+interval '5 minutes',ARRAY['fonts']);
 PERFORM set_config('request.jwt.claim.sub',worker::text,true);
 r:=public.ff_a09_design_draft('mobile','{"elements":{"dashboard_status":[{"key":"dashboard_status_tag","shape":"pack","size":"normal","font":"tahoma"}]}}','QA font',NULL);
 IF r->>'ok'<>'true' THEN RAISE EXCEPTION 'Element font failed %',r;END IF;rev:=(r->>'revision')::bigint;checks:=checks+1;
 IF NOT EXISTS(SELECT FROM public.ff_a09_design_history('mobile') WHERE id=rev AND style_config->'elements'->'dashboard_status'->0->>'font'='tahoma') THEN RAISE EXCEPTION 'Element font missing';END IF;checks:=checks+1;
 r:=public.ff_a09_design_draft('mobile','{"elements":{"dashboard_status":[{"key":"dashboard_status_tag","shape":"pill","size":"normal","font":"tahoma"}]}}','QA shape denied',NULL);
 IF r->>'ok'<>'false' THEN RAISE EXCEPTION 'font grant modified shape';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',mgr::text,true);
 gid:=public.ff_a09_set_grant(worker,br,'cashier',ARRAY['view','edit','preview','review'],clock_timestamp()-interval '1 second',clock_timestamp()+interval '5 minutes',ARRAY['text']);
 PERFORM set_config('request.jwt.claim.sub',worker::text,true);
 r:=public.ff82_delegate_draft('cashier.title','QA text');
 IF r->>'ok'<>'true' THEN RAISE EXCEPTION 'Text regression %',r;END IF;rev:=(r->>'revision')::bigint;checks:=checks+1;
 IF (public.ff82_delegate_review(rev,'QA text review')->>'ok')<>'true' THEN RAISE EXCEPTION 'Text review regression';END IF;checks:=checks+1;
 IF (public.ff82_delegate_draft('cashier.title',NULL)->>'ok')<>'false' THEN RAISE EXCEPTION 'Text restore accepted';END IF;checks:=checks+1;
 IF (public.ff82_delegate_review(9223372036854775807,'QA wrong revision')->>'ok')<>'false' THEN RAISE EXCEPTION 'Unknown review accepted';END IF;checks:=checks+1;
 IF public.ff_a09_design_context('mobile') IS NOT NULL THEN RAISE EXCEPTION 'Text grant leaked design context';END IF;checks:=checks+1;
 RESET ROLE;
 IF NOT EXISTS(SELECT FROM public.ff82_content_audit WHERE actor_id=worker AND action='review' AND attempted_revision=9223372036854775807 AND effect='no_change' AND outcome='denied' AND revision_id IS NULL) THEN RAISE EXCEPTION 'Missing rejected text review audit';END IF;checks:=checks+1;
 DELETE FROM public.ff_user_branches WHERE user_id=worker AND branch_id=br;
 SET LOCAL ROLE authenticated;
 IF EXISTS(SELECT FROM public.ff82_my_grant()) OR EXISTS(SELECT FROM public.ff82_delegate_catalog()) THEN RAISE EXCEPTION 'Removed branch leaked access';END IF;checks:=checks+1;
 RESET ROLE;
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(worker,br);
 PERFORM set_config('request.jwt.claim.sub',mgr::text,true);
 SET LOCAL ROLE authenticated;
 BEGIN
  PERFORM public.ff_a09_set_grant(worker,other,'dashboard',ARRAY['edit'],clock_timestamp(),clock_timestamp()+interval '5 minutes',ARRAY['fonts']);
  RAISE EXCEPTION 'Cross-branch grant accepted' USING ERRCODE='XX000';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;checks:=checks+1;
 gid:=public.ff_a09_set_grant(worker,br,'dashboard',ARRAY['edit'],clock_timestamp()+interval '1 minute',clock_timestamp()+interval '5 minutes',ARRAY['fonts']);
 PERFORM set_config('request.jwt.claim.sub',worker::text,true);
 IF EXISTS(SELECT FROM public.ff82_my_grant()) OR (public.ff_a09_design_draft('mobile','{"font":"tahoma"}','QA scheduled',NULL)->>'ok')<>'false' THEN RAISE EXCEPTION 'Future grant activated early';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',mgr::text,true);
 gid:=public.ff_a09_set_grant(worker,br,'dashboard',ARRAY['edit'],clock_timestamp()-interval '1 second',clock_timestamp()+interval '5 minutes',ARRAY['fonts']);
 RESET ROLE;
 UPDATE public.ff_profiles SET active=false WHERE user_id=worker;
 PERFORM set_config('request.jwt.claim.sub',worker::text,true);SET LOCAL ROLE authenticated;
 IF EXISTS(SELECT FROM public.ff82_my_grant()) OR (public.ff_a09_design_draft('mobile','{"font":"tahoma"}','QA inactive',NULL)->>'ok')<>'false' THEN RAISE EXCEPTION 'Inactive account retained grant';END IF;checks:=checks+1;
 RESET ROLE;
 IF checks<>18 THEN RAISE EXCEPTION 'Incomplete additional checks %',checks;END IF;
END $more$;
ROLLBACK;
SELECT 'PASS STEP07 scoped grants, 18 additional inheritance, audit and branch/account checks; rollback' AS result;
