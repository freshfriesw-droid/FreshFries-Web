DO $qa$
DECLARE m uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); a bigint; r bigint; s bigint; n bigint; j jsonb; p int:=0;
BEGIN
 BEGIN
 INSERT INTO auth.users(id) VALUES(m),(d);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA manager','manager',true),(d,'QA driver','driver',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-'||b,'QA scope');
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(d,b);
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 a:=public.ff_a07_named_design('all','all',b,'all','D01','','labels','QA global','',NULL,'{"density":"compact","font":"tahoma"}');PERFORM public.ff_ui_publish(a);
 r:=public.ff_a07_named_design('all','driver',b,'all','D02','','labels','QA role','',NULL,'{"radius":"round"}');PERFORM public.ff_ui_publish(r);
 s:=public.ff_a07_named_design('driver','all',b,'all','D03','','labels','QA screen','',NULL,'{"radius":"square","font":"serif"}');PERFORM public.ff_ui_publish(s);
 j:=public.ff_a07_manager_style_layers('driver','driver',b,'mobile');
 IF j->'style'->>'density'<>'compact' OR j->'style'->>'radius'<>'square' OR j->'style'->>'font'<>'serif' THEN RAISE EXCEPTION 'Property precedence %',j;END IF;p:=p+1;
 IF j->'sources'->>'density'<>a::text OR j->'sources'->>'radius'<>s::text THEN RAISE EXCEPTION 'Sources %',j;END IF;p:=p+1;
 n:=public.ff_a07_named_design('driver','all',b,'all','D04','','labels','QA next','',NULL,'{}');PERFORM public.ff_ui_publish(n);
 j:=public.ff_a07_manager_style_layers('driver','driver',b,'mobile');
 IF j->'style'->>'radius'<>'round' OR j->'style'->>'font'<>'tahoma' OR j->'sources'->>'radius'<>r::text THEN RAISE EXCEPTION 'Superseded property leak %',j;END IF;p:=p+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',d::text,true);SET LOCAL ROLE authenticated;
 j:=public.ff_a07_effective_designs(b,'mobile');
 IF j->'driver'->>'id'<>n::text OR j->'driver'->'style_config'->>'font'<>'tahoma' OR j->'driver'->'style_config'->>'radius'<>'round' THEN RAISE EXCEPTION 'Live effective inheritance %',j;END IF;p:=p+1;
 RESET ROLE;RAISE EXCEPTION 'QA rollback' USING ERRCODE='ZQ003';
 EXCEPTION WHEN SQLSTATE 'ZQ003' THEN NULL;END;
 IF p<>4 OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id=b) THEN RAISE EXCEPTION 'QA incomplete %',p;END IF;
END $qa$;
SELECT 'PASS A07: 4 property precedence, source, replacement and inheritance assertions; rollback' result;
