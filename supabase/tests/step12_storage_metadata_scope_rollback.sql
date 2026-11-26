BEGIN;
DO $qa$
DECLARE u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); inactive uuid:=gen_random_uuid(); sid uuid:=gen_random_uuid(); other_sid uuid:=gen_random_uuid(); expired_sid uuid:=gen_random_uuid(); disabled_sid uuid:=gen_random_uuid(); n bigint; private_expected bigint; public_expected bigint; probe text; checks int:=0;
BEGIN
 SELECT count(*) INTO private_expected FROM storage.objects o WHERE o.bucket_id='ff-luxe-tones' AND EXISTS(SELECT FROM public.ff66_tones t WHERE t.storage_path=o.name AND t.is_active);
 SELECT count(*) INTO public_expected FROM storage.objects WHERE bucket_id='ff_menu_media';
 IF private_expected<1 OR public_expected<1 THEN RAISE EXCEPTION 'Storage read fixtures unavailable'; END IF;
 INSERT INTO auth.users(id) VALUES(u),(v),(inactive);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(u,'QA STEP12 storage staff','cashier',true),(inactive,'QA STEP12 storage disabled','cashier',false);
 INSERT INTO auth.sessions(id,user_id,created_at,updated_at,not_after) VALUES(sid,u,now(),now(),NULL),(other_sid,v,now(),now(),NULL),(expired_sid,u,now(),now(),now()-interval '1 minute'),(disabled_sid,inactive,now(),now(),NULL);
 PERFORM set_config('request.jwt.claim.sub',u::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated','session_id',sid)::text,true);
 SET LOCAL ROLE authenticated;
 SELECT count(*) INTO n FROM storage.objects WHERE bucket_id='ff-luxe-tones';IF n<>private_expected THEN RAISE EXCEPTION 'Active staff tone metadata unavailable';END IF;checks:=checks+1;
 SELECT count(*) INTO n FROM storage.objects WHERE bucket_id='ff_menu_media';IF n<>public_expected THEN RAISE EXCEPTION 'Active staff menu metadata unavailable';END IF;checks:=checks+1;
 FOREACH probe IN ARRAY ARRAY[NULL,other_sid::text,expired_sid::text,gen_random_uuid()::text] LOOP
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated','session_id',probe)::text,true);
  SELECT count(*) INTO n FROM storage.objects WHERE bucket_id='ff-luxe-tones';
  IF n<>0 THEN RAISE EXCEPTION 'Invalid session private storage metadata visible'; END IF;checks:=checks+1;
 END LOOP;
 RESET ROLE;
 DELETE FROM auth.sessions WHERE id=sid AND user_id=u;
 SET LOCAL ROLE authenticated;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated','session_id',sid)::text,true);
 SELECT count(*) INTO n FROM storage.objects WHERE bucket_id='ff-luxe-tones';IF n<>0 THEN RAISE EXCEPTION 'Revoked session private storage metadata visible';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',inactive::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',inactive,'role','authenticated','session_id',disabled_sid)::text,true);
 SELECT count(*) INTO n FROM storage.objects WHERE bucket_id='ff-luxe-tones';IF n<>0 THEN RAISE EXCEPTION 'Disabled staff private storage metadata visible';END IF;checks:=checks+1;
 RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub','',true);PERFORM set_config('request.jwt.claims','{"role":"anon"}',true);SET LOCAL ROLE anon;
 SELECT count(*) INTO n FROM storage.objects WHERE bucket_id='ff-luxe-tones';IF n<>0 THEN RAISE EXCEPTION 'Anon private storage metadata visible';END IF;checks:=checks+1;
 SELECT count(*) INTO n FROM storage.objects WHERE bucket_id='ff_menu_media';IF n<>public_expected THEN RAISE EXCEPTION 'Public menu metadata unavailable';END IF;checks:=checks+1;
 RESET ROLE;
 IF checks<>10 THEN RAISE EXCEPTION 'Incomplete checks %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 storage metadata RLS: 10 assertions; active staff/public paths and invalid/revoked/disabled session denial' result;
ROLLBACK;
