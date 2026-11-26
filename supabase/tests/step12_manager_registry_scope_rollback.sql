BEGIN;
DO $qa$
DECLARE b uuid:=gen_random_uuid();m uuid:=gen_random_uuid();target uuid:=gen_random_uuid();actor uuid;roles text[]:=ARRAY['cashier','driver','assembly','supervisor','customer_service','burger_kitchen','nonstaff','disabled_manager'];kind text;callers uuid[]:=ARRAY[]::uuid[];sql_call text;calls text[];checks int:=0;num bigint;gid bigint;rid bigint;did bigint;r jsonb;
BEGIN
 INSERT INTO auth.users(id) VALUES(m),(target);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 registry manager','manager',true),(target,'QA STEP12 registry target','cashier',true);
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-step12-registry-'||b,'QA STEP12 registry');
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(target,b);
 FOREACH kind IN ARRAY roles LOOP
  actor:=gen_random_uuid();callers:=array_append(callers,actor);INSERT INTO auth.users(id) VALUES(actor);
  IF kind<>'nonstaff' THEN INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(actor,'QA STEP12 registry '||kind,CASE WHEN kind='disabled_manager' THEN 'manager' ELSE kind END,kind<>'disabled_manager');END IF;
  IF kind IN ('cashier','driver','assembly','supervisor','burger_kitchen') THEN INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(actor,b);END IF;
 END LOOP;
 SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',m::text,true);
 gid:=public.ff_a09_set_grant(target,b,'cashier',ARRAY['view','edit','preview','review'],now()-interval '1 minute',now()+interval '1 hour',ARRAY['text']);
 did:=public.ff_a07_named_design('cashier','cashier',b,'mobile','D01','','labels','QA registry design','',NULL,'{}');
 PERFORM public.ff_ui_publish(did);
 rid:=public.ff_content_create_draft('cashier.title','cashier',b,'QA registry manager draft');
 IF gid IS NULL OR did IS NULL OR rid IS NULL THEN RAISE EXCEPTION 'Missing manager fixture';END IF;
 PERFORM set_config('request.jwt.claim.sub',target::text,true);
 r:=public.ff82_delegate_draft('cashier.title','QA registry worker draft');
 RESET ROLE;
 -- Get the delegated content revision from the isolated fixture, not from real records.
 SELECT max(v.id) INTO rid FROM public.ff_content_versions v WHERE v.actor_id=target AND v.branch_id=b AND v.content_key='cashier.title';
 IF rid IS NULL THEN RAISE EXCEPTION 'Missing delegated revision';END IF;
 SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',target::text,true);
 r:=public.ff82_delegate_review(rid,'QA registry review');
 RESET ROLE;
 IF NOT EXISTS(SELECT FROM public.ff82_content_reviews z WHERE z.revision_id=rid AND z.reviewer=target) THEN RAISE EXCEPTION 'Missing delegated review';END IF;
 calls:=ARRAY[
 'SELECT count(*) FROM public.ff82_manager_accounts()',
 'SELECT count(*) FROM public.ff82_manager_audit()',
 'SELECT count(*) FROM public.ff82_manager_grants()',
 format('SELECT count(*) FROM public.ff82_manager_reviews(%L::bigint)',rid),
 format('SELECT count(*) FROM public.ff86_content_history_scoped(%L,%L,%L::uuid,false)','cashier.title','cashier',b),
 'SELECT count(*) FROM public.ff_a07_design_catalog()',
 'SELECT count(*) FROM public.ff_content_catalog_list()',
 'SELECT count(*) FROM public.ff_content_history(''cashier.title'')',
 'SELECT count(*) FROM public.ff_ui_manager_history()',
 'SELECT jsonb_array_length(public.ff_luxe_cashier_desks_roster())'];
 SET LOCAL ROLE authenticated;
 FOREACH actor IN ARRAY callers LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  FOREACH sql_call IN ARRAY calls LOOP
   EXECUTE sql_call INTO num;
   IF num IS DISTINCT FROM 0 THEN RAISE EXCEPTION 'Unauthorized registry read returned rows';END IF;checks:=checks+1;
  END LOOP;
  BEGIN PERFORM public.ff_a07_manager_source('cashier','cashier',b,'mobile');RAISE EXCEPTION 'Unauthorized manager design source' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 IF NOT EXISTS(SELECT FROM public.ff82_manager_accounts() z WHERE z.user_id=target AND z.branch_id=b) THEN RAISE EXCEPTION 'Manager account fixture inaccessible';END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT FROM public.ff82_manager_audit() z WHERE z.grant_id=gid) THEN RAISE EXCEPTION 'Manager audit fixture inaccessible';END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT FROM public.ff82_manager_grants() z WHERE z.id=gid) THEN RAISE EXCEPTION 'Manager grant fixture inaccessible';END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT FROM public.ff82_manager_reviews(rid) z WHERE z.reviewer=target) THEN RAISE EXCEPTION 'Manager review fixture inaccessible';END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT FROM public.ff86_content_history_scoped('cashier.title','cashier',b,false) z WHERE z.id=rid) THEN RAISE EXCEPTION 'Manager scoped history missing';END IF;checks:=checks+1;
 IF (SELECT count(*) FROM public.ff_a07_design_catalog())<>16 THEN RAISE EXCEPTION 'Manager design catalog count mismatch';END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT FROM public.ff_content_catalog_list() z WHERE z.key='cashier.title') THEN RAISE EXCEPTION 'Manager content catalog missing';END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT FROM public.ff_content_history('cashier.title') z WHERE z.id=rid) THEN RAISE EXCEPTION 'Manager content history missing';END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT FROM public.ff_ui_manager_history() z WHERE z.id=did) THEN RAISE EXCEPTION 'Manager design history missing';END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(public.ff_luxe_cashier_desks_roster()) z WHERE z->>'user_id'=target::text) THEN RAISE EXCEPTION 'Manager cashier roster missing';END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT FROM public.ff_a07_manager_source('cashier','cashier',b,'mobile') z WHERE z.id=did) THEN RAISE EXCEPTION 'Manager design source missing';END IF;checks:=checks+1;
 RESET ROLE;
 IF checks<>99 THEN RAISE EXCEPTION 'Expected 99 assertions, got %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 manager-only registries: 88 unauthorized empty/denied reads, 11 authorized checks; rollback' result;
ROLLBACK;
