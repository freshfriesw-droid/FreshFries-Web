BEGIN;
DO $qa$
DECLARE m uuid:=gen_random_uuid();a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();d uuid:=gen_random_uuid();u uuid:=gen_random_uuid();x uuid:=gen_random_uuid();msg1 uuid:=gen_random_uuid();msg2 uuid:=gen_random_uuid();msg3 uuid:=gen_random_uuid();actor uuid;target uuid;r jsonb;checks int:=0;title_value text:='QA STEP12 '||gen_random_uuid();
BEGIN
 INSERT INTO auth.users(id) VALUES(m),(a),(b),(d),(u),(x);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 inbox manager','manager',true),(a,'QA STEP12 inbox cashier','cashier',true),(b,'QA STEP12 inbox CS','customer_service',true),(d,'QA STEP12 inbox driver','driver',true),(x,'QA STEP12 inbox disabled','cashier',false);
 INSERT INTO public.ff39_messages(id,sender_id,title,body,target_role,requires_ack,cancelled_at) VALUES(msg1,m,title_value,'QA synthetic message one','cashier',true,NULL),(msg2,b,title_value,'QA synthetic message two','driver',true,NULL),(msg3,m,title_value,'QA synthetic cancelled message','cashier',true,now());
 INSERT INTO public.ff39_message_recipients(message_id,user_id) VALUES(msg1,a),(msg2,d),(msg3,a),(msg1,x);
 SET LOCAL ROLE authenticated;
 PERFORM set_config('request.jwt.claim.sub',a::text,true);
 r:=public.ff39_inbox(100,false);
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(r->'items') j WHERE j->>'id'=msg1::text) OR EXISTS(SELECT FROM jsonb_array_elements(r->'items') j WHERE j->>'id' IN(msg2::text,msg3::text)) THEN RAISE EXCEPTION 'Inbox ownership/cancellation mismatch';END IF;checks:=checks+1;
 FOREACH target IN ARRAY ARRAY[msg2,msg3] LOOP
  BEGIN PERFORM public.ff39_mark_read(target,true);RAISE EXCEPTION 'Foreign/cancelled receipt accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 END LOOP;
 r:=public.ff39_mark_read(msg1,true);IF r->>'saved' IS DISTINCT FROM 'true' OR r->>'acknowledged_at' IS NULL THEN RAISE EXCEPTION 'Own receipt failed';END IF;checks:=checks+1;
 r:=public.ff39_inbox(100,true);IF EXISTS(SELECT FROM jsonb_array_elements(r->'items') j WHERE j->>'id'=msg1::text) THEN RAISE EXCEPTION 'Read message remained unread';END IF;checks:=checks+1;
 r:=public.ff_a11_message_history(100);IF EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'id' IN(msg1::text,msg2::text,msg3::text)) THEN RAISE EXCEPTION 'Recipient obtained sender history';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',b::text,true);
 r:=public.ff_a11_message_history(100);IF NOT EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'id'=msg2::text) OR EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'id' IN(msg1::text,msg3::text)) THEN RAISE EXCEPTION 'Sender history scope';END IF;checks:=checks+1;
 FOREACH actor IN ARRAY ARRAY[a,b,d,u,x] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff39_admin_sent(100);RAISE EXCEPTION 'Nonmanager legacy sent history accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY[u,x] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff39_inbox(100,false);RAISE EXCEPTION 'Inactive inbox accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff39_mark_read(msg1,true);RAISE EXCEPTION 'Inactive receipt accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff_a11_message_history(100);RAISE EXCEPTION 'Inactive history accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff60_health();RAISE EXCEPTION 'Inactive health accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff60_read_policy();RAISE EXCEPTION 'Inactive policy accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  r:=public.ff_a11_message_access();IF r->>'can_send' IS DISTINCT FROM 'false' OR jsonb_array_length(r->'branches')<>0 THEN RAISE EXCEPTION 'Inactive message access accepted';END IF;checks:=checks+1;
  SELECT coalesce(jsonb_agg(to_jsonb(p)),'[]') INTO r FROM public.ff_report_preset_list() p;
  IF jsonb_array_length(r)<>0 THEN RAISE EXCEPTION 'Inactive preset visibility';END IF;checks:=checks+1;
  BEGIN PERFORM public.ff_report_preset_save(title_value,ARRAY['orders'],'daily');RAISE EXCEPTION 'Inactive preset write accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'غير مخول' THEN RAISE;END IF;END;checks:=checks+1;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',a::text,true);
 PERFORM public.ff_report_preset_save(title_value,ARRAY['orders'],'daily');checks:=checks+1;
 SELECT coalesce(jsonb_agg(to_jsonb(p)),'[]') INTO r FROM public.ff_report_preset_list() p;
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'title'=title_value AND j->>'trend'='daily') THEN RAISE EXCEPTION 'Own preset missing';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',b::text,true);
 SELECT coalesce(jsonb_agg(to_jsonb(p)),'[]') INTO r FROM public.ff_report_preset_list() p;
 IF EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'title'=title_value) THEN RAISE EXCEPTION 'Foreign preset visible';END IF;checks:=checks+1;
 PERFORM public.ff_report_preset_save(title_value,ARRAY['ratings'],'weekly');checks:=checks+1;
 SELECT coalesce(jsonb_agg(to_jsonb(p)),'[]') INTO r FROM public.ff_report_preset_list() p;
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'title'=title_value AND j->>'trend'='weekly') THEN RAISE EXCEPTION 'Second owner preset missing';END IF;checks:=checks+1;
 r:=public.ff60_health();IF r->>'queue' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Active health denied';END IF;checks:=checks+1;
 r:=public.ff60_read_policy();IF (r->>'fast_seconds')::integer IS NULL OR (r->>'slow_seconds')::integer IS NULL THEN RAISE EXCEPTION 'Active policy denied';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 r:=public.ff39_admin_sent(100);IF NOT EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'id'=msg1::text) THEN RAISE EXCEPTION 'Manager legacy history unavailable';END IF;checks:=checks+1;
 r:=public.ff_a11_message_history(100);IF NOT EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'id'=msg2::text) THEN RAISE EXCEPTION 'Manager history unavailable';END IF;checks:=checks+1;
 RESET ROLE;
 IF NOT EXISTS(SELECT FROM public.ff_report_presets WHERE owner_id=a AND title=title_value AND trend='daily') OR NOT EXISTS(SELECT FROM public.ff_report_presets WHERE owner_id=b AND title=title_value AND trend='weekly') OR (SELECT count(*) FROM public.ff_report_presets WHERE title=title_value)<>2 THEN RAISE EXCEPTION 'Preset ownership changed';END IF;checks:=checks+1;
 IF (SELECT count(*) FROM public.ff39_message_recipients WHERE message_id IN(msg1,msg2,msg3) AND acknowledged_at IS NOT NULL)<>1 OR NOT EXISTS(SELECT FROM public.ff39_message_recipients WHERE message_id=msg1 AND user_id=a AND acknowledged_at IS NOT NULL) THEN RAISE EXCEPTION 'Unexpected receipt state';END IF;checks:=checks+1;
 IF checks<>39 THEN RAISE EXCEPTION 'Expected 39 assertions got %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 communications and report presets: 39 assertions, own inbox, cancellation, receipts, sender history, inactive identities, preset ownership, read-only dispatch policy' result;
ROLLBACK;
