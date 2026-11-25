DO $qa$
DECLARE m uuid:=gen_random_uuid(); cs uuid:=gen_random_uuid(); cs2 uuid:=gen_random_uuid(); s uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); inactive uuid:=gen_random_uuid(); b1 uuid:=gen_random_uuid(); b2 uuid:=gen_random_uuid(); d1 uuid:=gen_random_uuid(); d2 uuid:=gen_random_uuid(); o1 uuid:=gen_random_uuid(); o2 uuid:=gen_random_uuid(); o3 uuid:=gen_random_uuid(); o4 uuid:=gen_random_uuid(); n1 bigint:=-(1+floor(random()*1e12)::bigint); n2 bigint:=n1-1;n3 bigint:=n1-2;n4 bigint:=n1-3;
 day date:=public.ff_business_date(now()); created timestamptz; p integer:=0; r jsonb; z jsonb; denied boolean;
 cfg jsonb:='[{"metric":"orders_today","label":"طلبات","size":"wide","tone":"red","roles":["manager","supervisor"],"permission":"view_reports","icon":"orders"}]'; rev bigint; nextrev bigint; restored bigint;
BEGIN
 BEGIN
 created:=(day+time '09:00') AT TIME ZONE 'Asia/Aden';
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-'||b1,'QA one'),(b2,'qa-'||b2,'QA two');
 INSERT INTO auth.users(id) VALUES(m),(cs),(cs2),(s),(c),(d),(inactive);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA manager','manager',true),(cs,'QA CS','customer_service',true),(cs2,'QA CS 2','customer_service',true),(s,'QA supervisor','supervisor',true),(c,'QA cashier','cashier',true),(d,'QA driver','driver',true),(inactive,'QA inactive','manager',false)
 ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=excluded.active;
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(s,b1),(c,b1),(d,b1);
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d1,'QA driver one',b1),(d2,'QA driver two',b2);
 INSERT INTO public.ff38_driver_links(user_id,driver_id) VALUES(d,d1);
 INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d1,'ready',now(),now()),(d2,'ready',now(),now()) ON CONFLICT(driver_id) DO UPDATE SET state='ready',checked_in_at=now(),last_seen_at=now();
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,driver_id,status,created_by,created_at,updated_at) VALUES
 (o1,n1,b1,'000000000',day,d1,'sent',cs,created,created),
 (o2,n2,b1,'000000000',day,NULL,'delivered',cs,created,created+interval '1 minute'),
 (o3,n3,b1,'000000000',day,NULL,'new',cs2,created,created+interval '2 minutes'),
 (o4,n4,b2,'000000000',day,d2,'sent',cs2,created,created+interval '3 minutes');
 INSERT INTO public.ff38_delivery_tasks(order_id,driver_id) VALUES(o1,d1),(o4,d2);
 INSERT INTO public.ff49_cashier_receipts(order_id,received_by) VALUES(o1,c);
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff80_dashboard_metrics(b1);
 IF (r->>'orders_today')::int<>3 OR (r->>'completed_today')::int<>1 OR (r->>'available_drivers')::int<>1 OR jsonb_array_length(r->'branch_status')<>1 THEN RAISE EXCEPTION 'Manager metrics %',r;END IF;p:=p+1;
 IF (r->'branch_status'->0->>'orders_today')::int<>3 OR jsonb_array_length(r->'recent_activity')<>3 OR (r->'recent_activity'->0->>'order_number')::bigint<>n3 THEN RAISE EXCEPTION 'Branch/activity counts %',r;END IF;p:=p+1;
 z:=public.ff_a08_metric_detail(b1,'orders_today',0,1);IF (z->>'total')::int<>3 OR jsonb_array_length(z->'rows')<>1 OR (z->'rows'->0->>'order_number')::bigint<>n3 THEN RAISE EXCEPTION 'Detail pagination %',z;END IF;p:=p+1;
 z:=public.ff_a08_metric_detail(b1,'orders_today',1,1);IF (z->'rows'->0->>'order_number')::bigint<>n2 OR z->'rows'->0 ? 'phone_snapshot' THEN RAISE EXCEPTION 'Detail second page/PII %',z;END IF;p:=p+1;
 z:=public.ff_a08_metric_detail(b1,'completed_today');IF (z->>'total')::int<>1 OR (z->'rows'->0->>'order_number')::bigint<>n2 THEN RAISE EXCEPTION 'Completed details %',z;END IF;p:=p+1;
 z:=public.ff_a08_metric_detail(b1,'late_today');IF (z->>'total')::int<>(r->>'late_today')::int THEN RAISE EXCEPTION 'Late consistency %',z;END IF;p:=p+1;
 z:=public.ff_a08_metric_detail(b2,'available_drivers');IF (z->>'total')::int<>1 OR z->'rows'->0->>'driver_name'<>'QA driver two' OR z->'rows'->0 ? 'phone' THEN RAISE EXCEPTION 'Driver scope %',z;END IF;p:=p+1;
 rev:=public.ff_a07_named_design('dashboard','all',b1,'mobile','D01','','labels','QA cards','',cfg,'{"dashboardPanels":{"branches":true,"activity":false},"quickActions":["orders","reports"]}');PERFORM public.ff_ui_publish(rev);
 nextrev:=public.ff_a07_named_design('dashboard','all',b1,'mobile','D01','','labels','QA empty','','[]','{}');PERFORM public.ff_ui_publish(nextrev);
 restored:=public.ff_ui_rollback(nextrev);
 IF (SELECT card_layout FROM public.ff_a07_manager_source('dashboard','manager',b1,'mobile'))<>cfg THEN RAISE EXCEPTION 'Card restoration';END IF;p:=p+1;
 denied:=false;BEGIN PERFORM public.ff_a07_named_design('driver','driver',b1,'mobile','D01','','labels','QA wrong screen','',cfg,'{}');EXCEPTION WHEN check_violation THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Wrong screen card accepted';END IF;p:=p+1;
 RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub',cs::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff80_dashboard_metrics(b1);z:=public.ff_a08_metric_detail(b1,'orders_today');
 IF (r->>'orders_today')::int<>2 OR (z->>'total')::int<>2 OR EXISTS(SELECT FROM jsonb_array_elements(z->'rows') e WHERE (e->>'order_number')::bigint=n3) THEN RAISE EXCEPTION 'CS data leak % %',r,z;END IF;p:=p+1;
 r:=public.ff80_dashboard_metrics(b2);IF (r->>'orders_today')::int<>0 OR jsonb_array_length(r->'recent_activity')<>0 THEN RAISE EXCEPTION 'CS foreign actor leak %',r;END IF;p:=p+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',s::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff80_dashboard_metrics(NULL);IF (r->>'orders_today')::int<>3 OR jsonb_array_length(r->'branch_status')<>1 THEN RAISE EXCEPTION 'Supervisor branch leak %',r;END IF;p:=p+1;
 denied:=false;BEGIN PERFORM public.ff_a08_metric_detail(b2,'orders_today');EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Foreign branch drill down';END IF;p:=p+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',d::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff80_dashboard_metrics(b1);z:=public.ff_a08_metric_detail(b1,'orders_today');IF (r->>'orders_today')::int<>1 OR r->>'available_drivers' IS NOT NULL OR (z->>'total')::int<>1 OR (z->'rows'->0->>'order_number')::bigint<>n1 THEN RAISE EXCEPTION 'Driver personal scope % %',r,z;END IF;p:=p+1;
 denied:=false;BEGIN PERFORM public.ff_a08_metric_detail(b1,'available_drivers');EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Driver roster exposed';END IF;p:=p+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',c::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff80_dashboard_metrics(b1);z:=public.ff_a08_metric_detail(b1,'orders_today');IF (r->>'orders_today')::int<>1 OR (z->>'total')::int<>1 OR r->>'available_drivers' IS NOT NULL THEN RAISE EXCEPTION 'Cashier scope % %',r,z;END IF;p:=p+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 PERFORM public.ff38_admin_set_permission(cs,'view_reports',false);
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',cs::text,true);SET LOCAL ROLE authenticated;
 denied:=false;BEGIN PERFORM public.ff_a08_metric_detail(b1,'orders_today');EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Revoked reports detail';END IF;p:=p+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',inactive::text,true);SET LOCAL ROLE authenticated;
 denied:=false;BEGIN PERFORM public.ff80_dashboard_metrics(b1);EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Inactive account';END IF;p:=p+1;
 RESET ROLE;
 IF has_function_privilege('anon','public.ff_a08_metric_detail(uuid,text,integer,integer)','EXECUTE') OR has_function_privilege('authenticated','ff_private.a08_order_rows(uuid,text,uuid[],uuid,date)','EXECUTE') THEN RAISE EXCEPTION 'Unsafe grants';END IF;p:=p+1;
 IF NOT public.ff81_validate_cards(cfg) OR public.ff81_validate_cards(jsonb_set(cfg,'{0,roles}','["manager","manager"]')) OR public.ff81_validate_cards(jsonb_set(cfg,'{0,permission}','"admin_secret"')) OR public.ff81_validate_cards(jsonb_set(cfg,'{0,metric}','"fabricated"')) OR NOT public.ff81_validate_cards('[]') OR NOT public.ff81_validate_cards((SELECT jsonb_agg(cfg->0) FROM generate_series(1,100))) THEN RAISE EXCEPTION 'Card validation/cap';END IF;p:=p+1;
 IF ff_private.a08_valid_panels('{"alerts":false}') OR ff_private.a08_valid_actions('["orders","orders"]') OR ff_private.a08_valid_actions('["javascript:evil"]') OR NOT ff_private.a08_valid_actions('["orders","reports"]') THEN RAISE EXCEPTION 'Unsafe dashboard config';END IF;p:=p+1;
 RAISE EXCEPTION 'QA rollback' USING ERRCODE='ZQ008';
 EXCEPTION WHEN SQLSTATE 'ZQ008' THEN NULL;END;
 IF p<>21 OR EXISTS(SELECT FROM public.ff_orders WHERE id IN(o1,o2,o3,o4)) OR EXISTS(SELECT FROM public.ff_branches WHERE id IN(b1,b2)) THEN RAISE EXCEPTION 'Incomplete rollback %',p;END IF;
END $qa$;
SELECT 'PASS A08: 21 scope, metric-detail, visibility config, restore, pagination and rollback assertions' AS result;
