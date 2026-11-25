-- QA-08: compare actual server authorization before/after visual publication.
-- Isolated temporary identities and branches, entire transaction rolled back.
BEGIN;
DO $qa$
DECLARE admin uuid:=gen_random_uuid(); own_branch uuid:=gen_random_uuid(); foreign_branch uuid:=gen_random_uuid(); uid uuid; role_name text; screen_name text; rev bigint; before_perms jsonb; after_perms jsonb; before_all jsonb; after_all jsonb; branch_before boolean[]; branch_after boolean[]; permission_keys text[]; j jsonb; roles_checked int:=0; keys_checked int:=0; denied int:=0; foreign_before boolean; foreign_after boolean; rejected boolean;
BEGIN
 INSERT INTO auth.users(id) VALUES(admin);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(admin,'QA STEP03 auth invariant admin','manager',true) ON CONFLICT(user_id) DO UPDATE SET role='manager',active=true;
 INSERT INTO public.ff_branches(id,code,name,active) VALUES(own_branch,'qa-'||own_branch,'QA STEP03 auth own',true),(foreign_branch,'qa-'||foreign_branch,'QA STEP03 auth foreign',true);
 SELECT array_agg(DISTINCT permission_key ORDER BY permission_key) INTO permission_keys FROM public.ff38_role_permission_defaults;
 IF coalesce(cardinality(permission_keys),0)=0 THEN RAISE EXCEPTION 'No permissions to compare';END IF;
 FOREACH role_name IN ARRAY ARRAY['manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen'] LOOP
  uid:=gen_random_uuid();
  INSERT INTO auth.users(id) VALUES(uid);
  INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(uid,'QA STEP03 auth invariant '||role_name,role_name,true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
  INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(uid,own_branch);
  screen_name:=CASE WHEN role_name='customer_service' THEN 'orders' WHEN role_name IN ('manager','supervisor') THEN 'dashboard' ELSE role_name END;
  PERFORM set_config('request.jwt.claim.sub',uid::text,true);SET LOCAL ROLE authenticated;
  before_perms:=public.ff38_my_permissions();
  SELECT jsonb_object_agg(k,public.ff38_permission_allowed(uid,k)) INTO before_all FROM unnest(permission_keys) k;
  branch_before:=ARRAY[public.ff_has_branch(own_branch),public.ff_has_branch(foreign_branch),public.ff_is_manager()];
  foreign_before:=true;BEGIN PERFORM public.ff_a07_effective_designs(foreign_branch,'mobile');EXCEPTION WHEN SQLSTATE '42501' THEN foreign_before:=false;END;
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub',admin::text,true);SET LOCAL ROLE authenticated;
  rev:=public.ff_a07_named_design(screen_name,role_name,own_branch,'mobile','D05','QA appearance only','labels','QA STEP03 auth invariant '||role_name,'',NULL,'{"density":"compact","font":"serif","radius":"square","surface":"dark"}');
  PERFORM public.ff_ui_publish(rev);
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub',uid::text,true);SET LOCAL ROLE authenticated;
  j:=public.ff_a07_effective_designs(own_branch,'mobile');
  IF j->screen_name->>'id' IS DISTINCT FROM rev::text OR j->screen_name->'style_config'->>'density' IS DISTINCT FROM 'compact' THEN RAISE EXCEPTION 'test design not active for %',role_name;END IF;
  after_perms:=public.ff38_my_permissions();
  SELECT jsonb_object_agg(k,public.ff38_permission_allowed(uid,k)) INTO after_all FROM unnest(permission_keys) k;
  branch_after:=ARRAY[public.ff_has_branch(own_branch),public.ff_has_branch(foreign_branch),public.ff_is_manager()];
  foreign_after:=true;BEGIN j:=public.ff_a07_effective_designs(foreign_branch,'mobile');EXCEPTION WHEN SQLSTATE '42501' THEN foreign_after:=false;END;
  IF before_perms IS DISTINCT FROM after_perms OR before_all IS DISTINCT FROM after_all OR branch_before IS DISTINCT FROM branch_after OR foreign_before IS DISTINCT FROM foreign_after THEN RAISE EXCEPTION 'authorization changed for %',role_name;END IF;
  IF branch_after IS DISTINCT FROM ARRAY[true,role_name='manager',role_name='manager'] THEN RAISE EXCEPTION 'branch/manager check mismatch %',role_name;END IF;
  IF foreign_after IS DISTINCT FROM (role_name IN ('manager','customer_service')) THEN RAISE EXCEPTION 'appearance policy mismatch %',role_name;END IF;
  IF foreign_after AND j->screen_name->>'id'=rev::text THEN RAISE EXCEPTION 'branch scoped design leaked %',role_name;END IF;
  IF NOT foreign_after THEN denied:=denied+1;END IF;
  IF role_name<>'manager' THEN
   rejected:=false;BEGIN PERFORM public.ff38_permission_allowed(admin,permission_keys[1]);EXCEPTION WHEN SQLSTATE '42501' THEN rejected:=true;END;
   IF NOT rejected THEN RAISE EXCEPTION 'foreign permission inspection accessible for %',role_name;END IF;
   denied:=denied+1;
  END IF;
  RESET ROLE;
  keys_checked:=keys_checked+cardinality(permission_keys);roles_checked:=roles_checked+1;
 END LOOP;
 IF roles_checked<>7 OR denied<>11 THEN RAISE EXCEPTION 'coverage mismatch';END IF;
 PERFORM set_config('ff.qa.auth_invariant',jsonb_build_object('roles',roles_checked,'permission_values_compared',keys_checked,'branch_and_manager_checks',roles_checked*3,'foreign_denials',denied,'published_designs',roles_checked,'foreign_appearance_policy_comparisons',roles_checked)::text,true);
END $qa$;
SELECT current_setting('ff.qa.auth_invariant')::jsonb AS result;
ROLLBACK;
