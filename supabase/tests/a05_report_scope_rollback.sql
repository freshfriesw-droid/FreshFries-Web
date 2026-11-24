DO $qa$
DECLARE b1 uuid:=gen_random_uuid();b2 uuid:=gen_random_uuid();m uuid:=gen_random_uuid();cs uuid:=gen_random_uuid();c uuid:=gen_random_uuid();s uuid:=gen_random_uuid();a uuid:=gen_random_uuid();d1 uuid:=gen_random_uuid();d2 uuid:=gen_random_uuid();o1 uuid:=gen_random_uuid();o2 uuid:=gen_random_uuid();desk1 text:='qa-'||gen_random_uuid();desk2 text:='qa-'||gen_random_uuid();r jsonb;blocked boolean;passes int:=0;
BEGIN
 BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-'||b1,'QA one'),(b2,'qa-'||b2,'QA two');
 INSERT INTO auth.users(id) VALUES(m),(cs),(c),(s),(a);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA manager','manager',true),(cs,'QA CS','customer_service',true),(c,'QA cashier','cashier',true),(s,'QA supervisor','supervisor',true),(a,'QA assembly','assembly',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c,b1),(a,b1);
 INSERT INTO public.ff_v9_assembly_access(user_id,branch_id,enabled,granted_by) VALUES(a,b1,false,m);
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d1,'QA one',b1),(d2,'QA two',b1);
 INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d1,'busy',now(),now()),(d2,'busy',now(),now()) ON CONFLICT(driver_id) DO UPDATE SET state='busy',checked_in_at=now(),last_seen_at=now();
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,driver_id,status,created_by) VALUES
 (o1,-(1+floor(random()*1e12)::bigint),b1,'000000000',public.ff_business_date(now()),d1,'sent',cs),
 (o2,-(1+floor(random()*1e12)::bigint),b1,'000000000',public.ff_business_date(now()),d2,'sent',cs);
 INSERT INTO public.ff38_delivery_tasks(order_id,driver_id) VALUES(o1,d1),(o2,d2);
 INSERT INTO public.ff_luxe_cashier_desks(code,label,branch_id,sort_order) VALUES(desk1,'QA desk1',b1,1),(desk2,'QA desk2',b1,2);
 INSERT INTO public.ff_luxe_cashier_staff_desks(user_id,desk_code,assigned_by) VALUES(c,desk1,m);
 INSERT INTO public.ff_luxe_cashier_order_desks(order_id,desk_code) VALUES(o1,desk1),(o2,desk2);
 PERFORM set_config('request.jwt.claim.sub',c::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff38_snapshot();
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r->'orders') x WHERE x->>'id'=o1::text) OR EXISTS(SELECT 1 FROM jsonb_array_elements(r->'orders') x WHERE x->>'id'=o2::text) THEN RAISE EXCEPTION 'Legacy snapshot bypass';END IF;passes:=passes+1;
 r:=public.ff51_order_archive(public.ff_business_date(now()),public.ff_business_date(now()),b1,null,60,0);
 IF (r->>'total')::int<>1 OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r->'rows') x WHERE x->>'id'=o1::text) THEN RAISE EXCEPTION 'Archive cashier desk scope';END IF;passes:=passes+1;
 IF EXISTS(SELECT 1 FROM public.ff_orders WHERE id=o2) THEN RAISE EXCEPTION 'Raw other desk read';END IF;passes:=passes+1;
 RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub',cs::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff80_dashboard_metrics(b2);
 IF r->>'role'<>'customer_service' THEN RAISE EXCEPTION 'Central CS dashboard unavailable';END IF;passes:=passes+1;
 r:=public.ff76_reporting_center(public.ff_business_date(now()),public.ff_business_date(now()),b2,null);
 IF r->>'role'<>'customer_service' THEN RAISE EXCEPTION 'Central CS report unavailable';END IF;passes:=passes+1;
 RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub',s::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff80_dashboard_metrics(b2);IF r->>'role'<>'supervisor' THEN RAISE EXCEPTION 'Central supervisor dashboard unavailable';END IF;passes:=passes+1;
 RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 PERFORM public.ff38_admin_set_permission(c,'view_reports',false);
 PERFORM public.ff38_admin_set_permission(cs,'view_reports',false);RESET ROLE;
 FOREACH m IN ARRAY ARRAY[c,cs] LOOP
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 blocked:=false;BEGIN PERFORM public.ff76_reporting_center(public.ff_business_date(now()),public.ff_business_date(now()),b1,null);EXCEPTION WHEN SQLSTATE '42501' THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Revoked report not blocked';END IF;passes:=passes+1;
 blocked:=false;BEGIN PERFORM public.ff80_dashboard_metrics(b1);EXCEPTION WHEN SQLSTATE '42501' THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Revoked dashboard not blocked';END IF;passes:=passes+1;
 blocked:=false;BEGIN PERFORM public.ff51_order_archive(public.ff_business_date(now()),public.ff_business_date(now()),b1,null,60,0);EXCEPTION WHEN SQLSTATE '42501' THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Revoked archive not blocked';END IF;passes:=passes+1;
 RESET ROLE;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',a::text,true);SET LOCAL ROLE authenticated;
 blocked:=false;BEGIN PERFORM public.ff76_reporting_center(public.ff_business_date(now()),public.ff_business_date(now()),b1,null);EXCEPTION WHEN SQLSTATE '42501' THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Revoked assembly report still available';END IF;passes:=passes+1;
 RESET ROLE;
 RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF passes<>13 OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id IN(b1,b2)) THEN RAISE EXCEPTION 'Incomplete QA/rollback: %',passes;END IF;
END $qa$;
SELECT 'PASS A05: 13 report and desk scope assertions; central roles, revoked reports, assembly revocation; rollback' AS result;