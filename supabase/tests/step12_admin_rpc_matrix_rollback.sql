BEGIN;
DO $qa$
DECLARE b uuid:=gen_random_uuid(); target uuid:=gen_random_uuid(); a_target uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); actor uuid; desk text:='qa-'||gen_random_uuid(); role_name text; roles text[]:=ARRAY['cashier','driver','assembly','supervisor','customer_service','burger_kitchen','nonstaff','disabled']; callers uuid[]:=ARRAY[]::uuid[]; q text; checks int:=0; r jsonb; deny_calls text[];
BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-admin-matrix-'||b,'QA admin matrix');
 INSERT INTO auth.users(id) VALUES(target),(a_target),(m);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(target,'QA STEP12 target','cashier',true),(a_target,'QA STEP12 assembly target','assembly',true),(m,'QA STEP12 manager','manager',true);
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(target,b),(a_target,b);
 INSERT INTO public.ff_luxe_cashier_desks(code,label,branch_id,sort_order) VALUES(desk,'QA desk',b,1);
 FOREACH role_name IN ARRAY roles LOOP
  actor:=gen_random_uuid();callers:=array_append(callers,actor);INSERT INTO auth.users(id) VALUES(actor);
  IF role_name<>'nonstaff' THEN INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(actor,'QA STEP12 '||role_name,CASE WHEN role_name='disabled' THEN 'cashier' ELSE role_name END,role_name<>'disabled'); END IF;
  IF role_name IN ('cashier','driver','assembly','supervisor','burger_kitchen','disabled') THEN INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(actor,b);END IF;
 END LOOP;
 deny_calls:=ARRAY[
  format('SELECT public.ff38_admin_permission_audit(%L::uuid)',target),
  format('SELECT public.ff38_admin_permission_matrix(%L::uuid)',target),
  format('SELECT public.ff38_admin_set_permission(%L::uuid,%L,true)',target,'view_reports'),
  format('SELECT public.ff38_admin_staff_set_access(%L::uuid,%L,ARRAY[%L::uuid])',target,'cashier',b),
  format('SELECT public.ff38_admin_staff_set_active(%L::uuid,false)',target),
  format('SELECT public.ff61_set_delegation(%L::uuid,true,true,true,true)',target),
  format('SELECT public.ff62_assembly_set_branch(%L::uuid,%L::uuid,true)',a_target,b),
  format('SELECT public.ff68_admin_staff_set_role(%L::uuid,%L,ARRAY[%L::uuid])',target,'cashier',b),
  format('SELECT public.ff_a10_report_grant(%L::uuid,%L,true)',target,'finance'),
  format('SELECT public.ff_luxe_set_cashier_desk(%L::uuid,%L)',target,desk),
  format('SELECT public.ff38_permission_allowed(%L::uuid,%L)',target,'view_reports')];
 SET LOCAL ROLE authenticated;
 FOREACH actor IN ARRAY callers LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  FOREACH q IN ARRAY deny_calls LOOP
   BEGIN EXECUTE q;RAISE EXCEPTION 'Unauthorized administrative call returned' USING ERRCODE='ZQA12';
   EXCEPTION WHEN SQLSTATE '42501' THEN checks:=checks+1; END;
  END LOOP;
  r:=public.ff_a11_message_grant(target,'cashier',b,'information',now()+interval '1 hour');
  IF r->>'ok' IS DISTINCT FROM 'false' OR r->>'error' IS DISTINCT FROM 'المدير فقط' THEN RAISE EXCEPTION 'Unauthorized message delegation accepted';END IF;checks:=checks+1;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 r:=public.ff38_admin_permission_matrix(target);IF jsonb_typeof(r)<>'array' OR jsonb_array_length(r)=0 THEN RAISE EXCEPTION 'Manager matrix lost';END IF;checks:=checks+1;
 r:=public.ff38_admin_set_permission(target,'view_reports',true);IF r->>'saved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Manager permission update lost';END IF;checks:=checks+1;
 r:=public.ff38_admin_permission_audit(target);IF jsonb_array_length(r)=0 THEN RAISE EXCEPTION 'Manager audit lost';END IF;checks:=checks+1;
 r:=public.ff_a11_message_grant(target,'cashier',b,'information',now()+interval '1 hour');IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Manager valid message grant failed';END IF;checks:=checks+1;
 RESET ROLE;
 IF checks<>100 THEN RAISE EXCEPTION 'Expected 100 checks, got %',checks;END IF;
 IF NOT (SELECT active FROM public.ff_profiles WHERE user_id=target) THEN RAISE EXCEPTION 'Target unexpectedly disabled';END IF;
END $qa$;
SELECT 'PASS STEP12 administrative RPC: 96 valid-input denial assertions in 8 contexts and 4 authorized manager assertions; rollback' result;
ROLLBACK;
