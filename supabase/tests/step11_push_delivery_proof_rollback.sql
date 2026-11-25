DO $qa$
DECLARE b uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); c1 uuid:=gen_random_uuid(); c2 uuid:=gen_random_uuid(); c3 uuid:=gen_random_uuid(); msg uuid; j bigint; rr jsonb; checks int:=0; ok boolean;
BEGIN
 BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-step11-push-'||b,'QA Push');
 INSERT INTO auth.users(id) VALUES(m),(c1),(c2),(c3);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA manager','manager',true),(c1,'QA A','cashier',true),(c2,'QA B','cashier',true),(c3,'QA C','cashier',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c1,b),(c2,b),(c3,b);
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 rr:=public.ff_a11_message_send('QA proof','QA content','cashier',b,'information',ARRAY[c1,c2,c3],ARRAY[c1,c2,c3],false,NULL);
 msg:=(rr->>'message_id')::uuid;
 IF msg IS NULL THEN RAISE EXCEPTION 'QA send %',rr;END IF;
 INSERT INTO public.ff_push_jobs(user_id,event_key,kind,title,body,status) SELECT x,'message:'||msg,'message','QA generic','QA generic','sending' FROM unnest(ARRAY[c1,c2,c3]) x ON CONFLICT(user_id,event_key) DO UPDATE SET status='sending';
 SELECT id INTO STRICT j FROM public.ff_push_jobs WHERE event_key='message:'||msg AND user_id=c1;
 ok:=public.ff_push_finish_job(j,true,'PROVIDER_ACCEPTED');
 IF NOT ok OR NOT EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE id=j AND status='sent' AND provider_accepted_at IS NOT NULL) THEN RAISE EXCEPTION 'Provider acceptance missing';END IF;checks:=checks+1;
 SELECT id INTO STRICT j FROM public.ff_push_jobs WHERE event_key='message:'||msg AND user_id=c2;
 ok:=public.ff_push_finish_job(j,false,'NO_ENABLED_DEVICE');
 IF NOT ok OR NOT EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE id=j AND status='failed' AND provider_accepted_at IS NULL AND sent_at IS NULL) THEN RAISE EXCEPTION 'No-device false success';END IF;checks:=checks+1;
 SELECT id INTO STRICT j FROM public.ff_push_jobs WHERE event_key='message:'||msg AND user_id=c3;
 ok:=public.ff_push_finish_job(j,true,NULL);
 IF NOT ok OR NOT EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE id=j AND status='sent' AND provider_accepted_at IS NULL) THEN RAISE EXCEPTION 'Legacy success incorrectly verified';END IF;checks:=checks+1;
 IF public.ff_push_finish_job(j,true,'PROVIDER_ACCEPTED') THEN RAISE EXCEPTION 'Replayed finish accepted';END IF;checks:=checks+1;
 SELECT x INTO rr FROM jsonb_array_elements(public.ff_a11_message_history()) x WHERE x->>'id'=msg::text;
 IF rr IS NULL OR (rr->>'recipients')::int<>3 OR (rr->>'push_accepted_count')::int<>1 OR (rr->>'push_unverified_count')::int<>1 OR (rr->>'push_unavailable_count')::int<>1 OR (rr->>'read_count')::int<>0 THEN RAISE EXCEPTION 'History conflated proof %',rr;END IF;checks:=checks+1;
 IF has_function_privilege('authenticated','public.ff_push_finish_job(bigint,boolean,text)','EXECUTE') OR has_function_privilege('anon','public.ff_push_finish_job(bigint,boolean,text)','EXECUTE') THEN RAISE EXCEPTION 'Client finish permission';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',c2::text,true);
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.ff39_inbox()->'items') x WHERE x->>'id'=msg::text) THEN RAISE EXCEPTION 'No-device lost inbox';END IF;checks:=checks+1;
 RAISE EXCEPTION 'rollback QA' USING ERRCODE='PZ011';
 EXCEPTION WHEN SQLSTATE 'PZ011' THEN NULL;END;
 IF checks<>7 OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id=b) THEN RAISE EXCEPTION 'QA incomplete %',checks;END IF;
END $qa$;
SELECT 'PASS STEP11 7 Push proof assertions: provider acceptance, no device, historical uncertainty, replay, history, ACL and inbox fallback; rollback' result;
