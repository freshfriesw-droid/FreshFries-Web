BEGIN;
DO $qa$
DECLARE b1 uuid:=gen_random_uuid();b2 uuid:=gen_random_uuid();m uuid:=gen_random_uuid();s uuid:=gen_random_uuid();c uuid:=gen_random_uuid();u uuid:=gen_random_uuid();disabled uuid:=gen_random_uuid();o uuid:=gen_random_uuid();actor uuid;calls text[];stmt text;r jsonb;checks int:=0;denied int:=0;
BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-delegated-'||b1,'QA delegated one'),(b2,'qa-delegated-'||b2,'QA delegated two');
 INSERT INTO auth.users(id) VALUES(m),(s),(c),(u),(disabled);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 manager','manager',true),(s,'QA STEP12 supervisor','supervisor',true),(c,'QA STEP12 cashier','cashier',true),(disabled,'QA STEP12 disabled','cashier',false);
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(s,b1),(c,b1),(disabled,b1);
 INSERT INTO public.ff38_staff_permission_overrides(user_id,permission_key,allowed,updated_by) VALUES(s,'view_reports',true,m);
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot,status) VALUES(o,-1000000000000-floor(random()*1e12)::bigint,b2,'000000000',public.ff_business_date(now()),'QA','cancelled');
 calls:=ARRAY[
 format('SELECT public.ff39_admin_send(%L,%L,%L,%L::uuid,false)','QA title','QA body','cashier',b1),
 'SELECT public.ff50_visible_order_changes(10)',
 'SELECT public.ff52_list_additions()',
 'SELECT public.ff62_manager_data_overview()',
 format('SELECT public.ff69_admin_send_assembly(%L,%L,%L::uuid,false)','QA title','QA body',b1),
 format('SELECT public.ff80_dashboard_metrics(%L::uuid)',b1),
 format('SELECT public.ff_a05_area_fee_hint(%L::uuid,%L)',b1,'QA area'),
 format('SELECT public.ff_a05_branch_policy(%L::uuid)',b1),
 'SELECT public.ff_a05_catalog_price_history(10)',
 format('SELECT public.ff_a07_manager_style_layers(%L,%L,%L::uuid,%L)','dashboard','cashier',b1,'mobile'),
 format('SELECT public.ff_a07_preview_scope(%L,%L,%L::uuid,%L,%L,%L::jsonb,%L,%L,%L::uuid,%L)','dashboard','cashier',b1,'mobile','D01','{}','dashboard','cashier',b1,'mobile'),
 format('SELECT * FROM public.ff_a08_manager_card_source(%L,%L::uuid,%L)','cashier',b1,'mobile'),
 format('SELECT public.ff_a08_metric_detail(%L::uuid,%L,0,10)',b1,'orders_today'),
 'SELECT public.ff_a11_message_audit(10)',
 'SELECT public.ff_a11_message_grants()',
 'SELECT public.ff_a12_legacy_batches()',
 'SELECT public.ff_a12_reset_batches()',
 'SELECT public.ff_customer_views_manager(10)',
 format('SELECT public.ff_luxe_cashier_completed_rating(%L::uuid,5,%L)',o,'QA rating'),
 format('SELECT public.ff_luxe_cashier_completed_report(%L::uuid,%L,%L,%L,%L)',o,'operational','QA subject','QA synthetic description','normal'),
 'SELECT public.ff_v12_assembly_snapshot()'];
 SET LOCAL ROLE authenticated;
 FOREACH actor IN ARRAY ARRAY[u,disabled] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  FOREACH stmt IN ARRAY calls LOOP
   BEGIN EXECUTE stmt;RAISE EXCEPTION 'Unauthorized call accepted: %',stmt USING ERRCODE='ZQA12';
   EXCEPTION WHEN SQLSTATE '42501' THEN denied:=denied+1;
   WHEN SQLSTATE 'P0001' THEN IF stmt<>'SELECT public.ff52_list_additions()' OR SQLERRM<>'المستخدم غير مخول' THEN RAISE;END IF;denied:=denied+1;END;
  END LOOP;
  IF EXISTS(SELECT FROM public.ff82_delegate_catalog()) THEN RAISE EXCEPTION 'Ungrant catalog visible';END IF;checks:=checks+1;
  IF public.ff_a09_design_context('mobile') IS NOT NULL THEN RAISE EXCEPTION 'Ungrant design visible';END IF;checks:=checks+1;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',s::text,true);
 BEGIN PERFORM public.ff_a05_branch_policy(b2);RAISE EXCEPTION 'Foreign policy allowed' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN checks:=checks+1;END;
 BEGIN PERFORM public.ff_a05_area_fee_hint(b2,'QA area');RAISE EXCEPTION 'Foreign fee hint allowed' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN checks:=checks+1;END;
 BEGIN PERFORM public.ff80_dashboard_metrics(b2);RAISE EXCEPTION 'Foreign dashboard allowed' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN checks:=checks+1;END;
 BEGIN PERFORM public.ff_a08_metric_detail(b2,'orders_today',0,10);RAISE EXCEPTION 'Foreign metric allowed' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN checks:=checks+1;END;
 IF jsonb_typeof(public.ff80_dashboard_metrics(b1)) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Own dashboard denied';END IF;checks:=checks+1;
 IF jsonb_typeof(public.ff_a08_metric_detail(b1,'orders_today',0,10)) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Own metric denied';END IF;checks:=checks+1;
 IF jsonb_typeof(public.ff_a05_branch_policy(b1)) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Own policy denied';END IF;checks:=checks+1;
 IF jsonb_typeof(public.ff_a05_area_fee_hint(b1,'QA area')) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Own fee hint denied';END IF;checks:=checks+1;
 RESET ROLE;
 UPDATE public.ff38_staff_permission_overrides SET allowed=false WHERE user_id=s AND permission_key='view_reports';
 SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',s::text,true);
 BEGIN PERFORM public.ff80_dashboard_metrics(b1);RAISE EXCEPTION 'Revoked dashboard allowed' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN checks:=checks+1;END;
 BEGIN PERFORM public.ff_a08_metric_detail(b1,'orders_today',0,10);RAISE EXCEPTION 'Revoked metric allowed' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN checks:=checks+1;END;
 RESET ROLE;SET LOCAL ROLE anon;
 PERFORM set_config('request.jwt.claim.sub','',true);
 r:=public.ff_a07_public_appearance('login','mobile');IF jsonb_typeof(r) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Public appearance broken';END IF;checks:=checks+1;
 BEGIN PERFORM public.ff_a07_public_appearance('staff','mobile');RAISE EXCEPTION 'Private appearance exposed' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '22023' THEN checks:=checks+1;END;
 PERFORM * FROM public.ff_step06_public_content('login');checks:=checks+1;
 IF EXISTS(SELECT FROM public.ff_step06_public_content('staff')) THEN RAISE EXCEPTION 'Private content exposed';END IF;checks:=checks+1;
 RESET ROLE;
 IF denied<>42 OR checks<>18 THEN RAISE EXCEPTION 'Expected 42+18, got % + %',denied,checks;END IF;
END $qa$;
SELECT 'PASS STEP12 delegated boundaries: 60 assertions (42 denials, 18 empty/scope/revocation/public checks)' result;
ROLLBACK;
