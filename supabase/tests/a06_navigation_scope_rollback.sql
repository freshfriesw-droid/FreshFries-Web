DO $qa$
DECLARE m uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); d uuid:=gen_random_uuid();b1 uuid:=gen_random_uuid();b2 uuid:=gen_random_uuid();r jsonb;denied boolean;passes int:=0;
BEGIN
 BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-'||b1,'QA one'),(b2,'qa-'||b2,'QA two');
 INSERT INTO auth.users(id) VALUES(m),(c),(d);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA manager','manager',true),(c,'QA cashier','cashier',true),(d,'QA disabled','cashier',false) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=excluded.active;
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c,b1),(d,b1);
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 PERFORM public.ff_a06_nav_save('cashier',b1,'all','accordion',280,'labels','QA scope');
 PERFORM public.ff_a06_nav_save('cashier',b1,'mobile','flat',300,'floating','QA mobile');
 PERFORM public.ff_a06_nav_save('cashier',b2,'mobile','accordion',260,'compact','QA foreign');
 PERFORM public.ff_a06_nav_save('cashier',b1,'mobile','flat',290,'wide','QA latest');
 RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff_a06_nav_scope(null,'mobile');IF r->>'mode'<>'flat' OR (r->>'drawer_width')::int<>290 OR r->>'bar'<>'wide' OR r->>'branch'<>b1::text THEN RAISE EXCEPTION 'Incorrect scope precedence';END IF;passes:=passes+1;
 r:=public.ff_a06_nav_scope(b1,'desktop');IF r->>'bar'<>'labels' OR (r->>'drawer_width')::int<>280 THEN RAISE EXCEPTION 'Wrong device inheritance';END IF;passes:=passes+1;
 denied:=false;BEGIN PERFORM public.ff_a06_nav_scope(b2,'mobile');EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Foreign branch';END IF;passes:=passes+1;
 denied:=false;BEGIN PERFORM public.ff_a06_nav_save('all',null,'all','flat',280,null,'QA forbidden');EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Nonmanager write';END IF;passes:=passes+1;
 RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub',d::text,true);SET LOCAL ROLE authenticated;
 denied:=false;BEGIN PERFORM public.ff_a06_nav_scope(b1,'mobile');EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Disabled account';END IF;passes:=passes+1;
 RESET ROLE;
 IF has_table_privilege('authenticated','ff_private.a06_nav_versions','SELECT,INSERT,UPDATE,DELETE') OR has_function_privilege('anon','public.ff_a06_nav_scope(uuid,text)','EXECUTE') THEN RAISE EXCEPTION 'Direct grant';END IF;passes:=passes+1;
 IF (SELECT count(*) FROM public.ff_audit_log WHERE action='a06_nav_defaults' AND actor_id=m)<>4 THEN RAISE EXCEPTION 'Audit missing';END IF;passes:=passes+1;
 RAISE EXCEPTION 'QA rollback' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF passes<>7 OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id IN(b1,b2)) OR EXISTS(SELECT 1 FROM ff_private.a06_nav_versions WHERE actor_id=m) THEN RAISE EXCEPTION 'QA incomplete';END IF;
END $qa$;
SELECT 'PASS A06: 7 navigation scope assertions; rollback' result;