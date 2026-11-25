DO $qa$
DECLARE m uuid:=gen_random_uuid(); cs uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); s uuid:=gen_random_uuid(); b1 uuid:=gen_random_uuid(); b2 uuid:=gen_random_uuid(); a bigint; b bigint; e bigint; t bigint; r jsonb; denied boolean; passes int:=0;
 cfg jsonb:='[{"metric":"orders_today","label":"اختبار وراثة","size":"wide","tone":"red","roles":["cashier","customer_service"],"icon":"orders"}]';
BEGIN
 BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-'||b1,'QA one'),(b2,'qa-'||b2,'QA two');
 INSERT INTO auth.users(id) VALUES(m),(cs),(c),(s);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA manager','manager',true),(cs,'QA CS','customer_service',true),(c,'QA cashier','cashier',true),(s,'QA supervisor','supervisor',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=excluded.active;
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c,b1),(s,b1);
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 a:=public.ff_a07_named_design('all','all',b1,'all','D01','','labels','QA base cards','',cfg,'{"dashboardPanels":{"branches":true}}');PERFORM public.ff_ui_publish(a);
 b:=public.ff_a07_named_design('dashboard','cashier',b1,'mobile','D05','','labels','QA visual only','',NULL,'{}');PERFORM public.ff_ui_publish(b);
 IF (SELECT revision FROM public.ff_a08_manager_card_source('cashier',b1,'mobile'))<>a THEN RAISE EXCEPTION 'Incorrect inherited card source';END IF;passes:=passes+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',c::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff_a07_effective_designs(b1,'mobile');
 IF (r->'dashboard'->>'id')::bigint<>b OR r->'dashboard'->'card_layout'<>cfg OR (r->'dashboard'->>'card_layout_source')::bigint<>a THEN RAISE EXCEPTION 'Inherited cards lost %',r;END IF;passes:=passes+1;
 denied:=false;BEGIN PERFORM public.ff_a08_manager_card_source('cashier',b1,'mobile');EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Card source manager-only boundary';END IF;passes:=passes+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 e:=public.ff_a07_named_design('dashboard','cashier',b1,'mobile','D06','','labels','QA explicit empty','', '[]','{}');PERFORM public.ff_ui_publish(e);
 t:=public.ff_a07_named_design('dashboard','customer_service',b2,'mobile','D09','','labels','QA central branch','',cfg,'{}');PERFORM public.ff_ui_publish(t);
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',c::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff_a07_effective_designs(b1,'mobile');IF r->'dashboard'->'card_layout'<>'[]'::jsonb OR r->'dashboard'->>'card_layout_source'<>e::text THEN RAISE EXCEPTION 'Explicit empty layout overridden';END IF;passes:=passes+1;
 r:=public.ff_a07_effective_designs(b1,'desktop');IF r->'dashboard'->'card_layout'<>cfg THEN RAISE EXCEPTION 'Device scope';END IF;passes:=passes+1;
 denied:=false;BEGIN PERFORM public.ff_a07_effective_designs(b2,'mobile');EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Foreign cashier branch';END IF;passes:=passes+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',cs::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff_a07_effective_designs(b2,'mobile');IF r->'dashboard'->>'card_layout_source'<>t::text THEN RAISE EXCEPTION 'Central customer-service design inaccessible';END IF;passes:=passes+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',s::text,true);SET LOCAL ROLE authenticated;
 denied:=false;BEGIN PERFORM public.ff_a07_effective_designs(b2,'mobile');EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Foreign supervisor branch';END IF;passes:=passes+1;
 RESET ROLE;
 RAISE EXCEPTION 'QA rollback' USING ERRCODE='ZQ009';
 EXCEPTION WHEN SQLSTATE 'ZQ009' THEN NULL;END;
 IF passes<>8 OR EXISTS(SELECT FROM public.ff_branches WHERE id IN(b1,b2)) THEN RAISE EXCEPTION 'Incomplete rollback %',passes;END IF;
END $qa$;
SELECT 'PASS A08: 8 inherited-card, explicit-empty, device and central branch authorization assertions; rollback' AS result;
