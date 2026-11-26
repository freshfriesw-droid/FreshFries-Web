BEGIN;
DO $qa$
DECLARE m uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); i uuid; items jsonb; r jsonb; issued uuid; code_value text; actor uuid; kind text; denied int:=0; checks int:=0;
BEGIN
 INSERT INTO public.ff_menu_categories(id,name,active) VALUES(c,'QA STEP12 reward '||c,true);
 INSERT INTO public.ff_menu_items(category_id,name,price,active) VALUES(c,'QA STEP12 reward item',100,true) RETURNING id INTO i;
 items:=jsonb_build_array(jsonb_build_object('id',i,'qty',1));
 INSERT INTO auth.users(id) VALUES(m);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 reward manager','manager',true);
 FOREACH kind IN ARRAY ARRAY['cashier','driver','assembly','supervisor','customer_service','burger_kitchen','disabled_cashier','disabled_manager','nonstaff'] LOOP
  actor:=gen_random_uuid();
  INSERT INTO auth.users(id) VALUES(actor);
  IF kind<>'nonstaff' THEN
   INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(actor,'QA STEP12 reward '||kind,CASE WHEN kind='disabled_cashier' THEN 'cashier' WHEN kind='disabled_manager' THEN 'manager' ELSE kind END,kind NOT LIKE 'disabled_%');
  END IF;
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN
   PERFORM public.ff_reward_issue('hospitality','QA synthetic recipient','0000000000',items,NULL);
   RAISE EXCEPTION 'Unauthorized issue for %',kind USING ERRCODE='ZQA12';
  EXCEPTION WHEN SQLSTATE '42501' THEN denied:=denied+1; END;
  RESET ROLE;
 END LOOP;
 IF denied<>9 THEN RAISE EXCEPTION 'Expected 9 denials, got %',denied; END IF;
 SET LOCAL ROLE authenticated;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 r:=public.ff_reward_issue('hospitality','QA synthetic recipient','0000000000',items,NULL);
 IF r->>'saved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Valid manager issue failed'; END IF; checks:=checks+1;
 issued:=(r->>'id')::uuid; code_value:=r->>'code';
 r:=public.ff_reward_check(code_value);
 IF (r->>'id')::uuid IS DISTINCT FROM issued THEN RAISE EXCEPTION 'Reward lookup failed'; END IF; checks:=checks+1;
 IF public.ff_reward_void(code_value) IS DISTINCT FROM true THEN RAISE EXCEPTION 'Manager void failed'; END IF; checks:=checks+1;
 RESET ROLE;
 IF (SELECT status FROM public.ff_reward_codes WHERE id=issued) IS DISTINCT FROM 'void' THEN RAISE EXCEPTION 'Unexpected reward state'; END IF; checks:=checks+1;
 IF (SELECT count(*) FROM public.ff_reward_codes WHERE recipient_name='QA synthetic recipient' AND issued_by<>m)<>0 THEN RAISE EXCEPTION 'Unauthorized reward persisted'; END IF; checks:=checks+1;
 IF checks<>5 THEN RAISE EXCEPTION 'Expected five valid and safety checks'; END IF;
END $qa$;
SELECT 'PASS STEP12 reward issue: 9 denied roles and 5 authorized/state assertions' result;
ROLLBACK;
