DO $qa$
DECLARE m uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); rev bigint; nextrev bigint; restored bigint; denied boolean; cfg jsonb:='{"elements":{"driver_actions":[{"key":"clockInBtn","shape":"pill","size":"large"},{"key":"clockOutBtn","shape":"outline","size":"normal"},{"key":"ff51BreakBtn","shape":"pack","size":"normal"}]}}'; passed int:=0;
BEGIN
 BEGIN
  INSERT INTO auth.users(id) VALUES(m),(d);
  INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA manager','manager',true),(d,'QA driver','driver',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
  INSERT INTO ff_private.a07_design_packs VALUES('D99999','Future isolated QA',99999);
  PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
  IF (SELECT count(*) FROM public.ff_a07_design_catalog() WHERE code='D99999')<>1 THEN RAISE EXCEPTION 'Catalog ceiling';END IF;passed:=passed+1;
  rev:=public.ff_a07_named_design('driver','driver',null,'mobile','D99999','','labels','QA registry','',NULL,cfg);
  PERFORM public.ff_ui_publish(rev);passed:=passed+1;
  denied:=false;BEGIN PERFORM public.ff_a07_named_design('driver','driver',null,'mobile','D99998','','labels','QA missing','',NULL,cfg);EXCEPTION WHEN foreign_key_violation THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Unregistered pack';END IF;passed:=passed+1;
  denied:=false;BEGIN PERFORM public.ff_a07_named_design('cashier','cashier',null,'mobile','D01','','labels','QA scope','',NULL,cfg);EXCEPTION WHEN check_violation THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Cross scope element';END IF;passed:=passed+1;
  denied:=false;BEGIN PERFORM public.ff_a07_named_design('driver','driver',null,'mobile','D01','','labels','QA hidden','',NULL,jsonb_set(cfg,'{elements,driver_actions,0,hidden}','true'));EXCEPTION WHEN OTHERS THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Hidden action';END IF;passed:=passed+1;
  denied:=false;BEGIN PERFORM public.ff_a07_named_design('driver','driver',null,'mobile','D01','','labels','QA removed','',NULL,cfg #- '{elements,driver_actions,0}');EXCEPTION WHEN OTHERS THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Removed required action';END IF;passed:=passed+1;
  denied:=false;BEGIN PERFORM public.ff_a07_named_design('driver','driver',null,'mobile','D01','','labels','QA duplicate','',NULL,jsonb_set(cfg,'{elements,driver_actions,2,key}','"clockInBtn"'));EXCEPTION WHEN OTHERS THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Duplicate action';END IF;passed:=passed+1;
  nextrev:=public.ff_a07_named_design('driver','driver',null,'mobile','D09','','labels','QA next','',NULL,'{}');PERFORM public.ff_ui_publish(nextrev);
  restored:=public.ff_ui_rollback(nextrev);
  RESET ROLE;PERFORM set_config('request.jwt.claim.sub',d::text,true);SET LOCAL ROLE authenticated;
  IF (SELECT count(*) FROM public.ff_a07_design_catalog())<>0 THEN RAISE EXCEPTION 'Unauthorized catalog';END IF;passed:=passed+1;
  IF public.ff_a07_effective_designs(null,'mobile')->'driver'->'style_config'<>cfg OR public.ff_a07_effective_designs(null,'mobile')->'driver'->>'pack'<>'D99999' THEN RAISE EXCEPTION 'Restore lost element design';END IF;passed:=passed+1;
  IF public.ff_a07_effective_designs(null,'desktop')->'driver'->>'id'=restored::text THEN RAISE EXCEPTION 'Wrong device';END IF;passed:=passed+1;
  RESET ROLE;RAISE EXCEPTION 'QA rollback' USING ERRCODE='ZQ002';
 EXCEPTION WHEN SQLSTATE 'ZQ002' THEN NULL;END;
 IF passed<>10 OR EXISTS(SELECT 1 FROM ff_private.a07_design_packs WHERE code='D99999') OR EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id IN(m,d)) THEN RAISE EXCEPTION 'QA rollback incomplete: %',passed;END IF;
END $qa$;
SELECT 'PASS A07: 10 registry, mandatory-element, scope and restore assertions; rollback' result;
