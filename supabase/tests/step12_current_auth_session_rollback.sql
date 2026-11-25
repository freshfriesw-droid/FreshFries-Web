BEGIN;
DO $qa$
DECLARE u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); sid uuid:=gen_random_uuid(); foreign_sid uuid:=gen_random_uuid(); expired_sid uuid:=gen_random_uuid(); n int; passes int:=0; probe text;
BEGIN
 INSERT INTO auth.users(id) VALUES(u),(v);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(u,'STEP12 session QA','cashier',true);
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-session-'||b,'STEP12 QA');
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(u,b);
 INSERT INTO auth.sessions(id,user_id,created_at,updated_at,not_after) VALUES(sid,u,now(),now(),NULL),(foreign_sid,v,now(),now(),NULL),(expired_sid,u,now(),now(),now()-interval '1 minute');
 PERFORM set_config('request.jwt.claim.sub',u::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated','session_id',sid)::text,true);
 SET LOCAL ROLE authenticated;
 IF NOT public.ff_step12_session_valid() OR NOT public.ff_step12_session_context() THEN RAISE EXCEPTION 'Valid session refused'; END IF;
 PERFORM public.ff_step12_assert_session();
 SELECT count(*) INTO n FROM public.ff_branches WHERE id=b; IF n<>1 THEN RAISE EXCEPTION 'Valid session branch access broken';END IF;passes:=passes+1;
 FOR probe IN SELECT unnest(ARRAY[gen_random_uuid()::text,foreign_sid::text,expired_sid::text,'invalid',NULL]::text[]) LOOP
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated','session_id',probe)::text,true);
  IF public.ff_step12_session_valid() OR public.ff_step12_session_context() THEN RAISE EXCEPTION 'Invalid session accepted'; END IF;
  BEGIN PERFORM public.ff_step12_assert_session(); RAISE EXCEPTION 'Pre-request accepted invalid session' USING ERRCODE='ZQA12'; EXCEPTION WHEN SQLSTATE 'PT401' THEN NULL; END;
  SELECT count(*) INTO n FROM public.ff_branches WHERE id=b; IF n<>0 THEN RAISE EXCEPTION 'Invalid session RLS read';END IF;passes:=passes+1;
 END LOOP;
 RESET ROLE;
 DELETE FROM auth.sessions WHERE id=sid AND user_id=u;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated','session_id',sid)::text,true);
 SET LOCAL ROLE authenticated;
 IF public.ff_step12_session_valid() OR public.ff_step12_session_context() THEN RAISE EXCEPTION 'Revoked session accepted';END IF;
 BEGIN PERFORM public.ff_step12_assert_session(); RAISE EXCEPTION 'Revoked session hook accepted' USING ERRCODE='ZQA12'; EXCEPTION WHEN SQLSTATE 'PT401' THEN NULL;END;
 SELECT count(*) INTO n FROM public.ff_branches WHERE id=b; IF n<>0 THEN RAISE EXCEPTION 'Revoked session RLS read';END IF;passes:=passes+1;
 RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub','',true); PERFORM set_config('request.jwt.claims','{"role":"anon"}',true); SET LOCAL ROLE anon; PERFORM public.ff_step12_assert_session(); RESET ROLE; passes:=passes+1;
 PERFORM set_config('request.jwt.claims','{"role":"service_role"}',true); SET LOCAL ROLE service_role; PERFORM public.ff_step12_assert_session(); RESET ROLE; passes:=passes+1;
 IF passes<>9 THEN RAISE EXCEPTION 'Incomplete session QA %',passes;END IF;
END $qa$;
SELECT 'PASS STEP12: 9 session cases; current session allowed; missing, foreign, expired, malformed and revoked sessions denied by hook and RLS; public and service paths preserved' AS result;
ROLLBACK;
