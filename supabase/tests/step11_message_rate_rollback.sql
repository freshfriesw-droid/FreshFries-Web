DO $qa$
DECLARE br uuid:=gen_random_uuid();m uuid:=gen_random_uuid();c uuid:=gen_random_uuid();v jsonb;i int;blocked boolean;
BEGIN
 BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(br,'qa-step11-rate-'||br,'QA rate');
 INSERT INTO auth.users(id) VALUES(m),(c);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA sender','manager',true),(c,'QA recipient','cashier',true) ON CONFLICT(user_id) DO UPDATE SET active=true,role=excluded.role;
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c,br);
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 FOR i IN 1..30 LOOP
  v:=public.ff_a11_message_send('QA message '||i,'QA rate only','cashier',br,'information',ARRAY[c],ARRAY[c],false,NULL);
  IF v->>'ok'<>'true' THEN RAISE EXCEPTION 'Premature rate limit %',i;END IF;
 END LOOP;
 v:=public.ff_a11_message_send('QA overflow','QA rate only','cashier',br,'information',ARRAY[c],ARRAY[c],false,NULL);
 IF v->>'ok'<>'false' OR v->>'error' NOT LIKE '%حد الإرسال%' THEN RAISE EXCEPTION 'Rate limit bypass';END IF;
 RESET ROLE;
 IF (SELECT count(*) FROM public.ff39_messages WHERE sender_id=m)<>30 OR (SELECT count(*) FROM public.ff39_message_recipients rr JOIN public.ff39_messages mm ON mm.id=rr.message_id WHERE mm.sender_id=m AND rr.user_id=c)<>30 THEN RAISE EXCEPTION 'Flood persisted extra recipients';END IF;
 RAISE EXCEPTION 'rollback QA' USING ERRCODE='PZ011';
 EXCEPTION WHEN SQLSTATE 'PZ011' THEN NULL;END;
 IF EXISTS(SELECT 1 FROM public.ff_branches WHERE id=br) OR EXISTS(SELECT 1 FROM public.ff39_messages WHERE sender_id=m) THEN RAISE EXCEPTION 'QA rollback incomplete';END IF;
END $qa$;
SELECT 'PASS STEP11 actual hourly rate limit: 30 allowed, 31st blocked, exact recipients, rollback' result;