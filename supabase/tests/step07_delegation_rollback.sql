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
ROLLBACK;
SELECT 'STEP07 scoped delegation rollback test passed' AS result;
