-- STEP05: verify two independent event updates and stale same-event rejection.
BEGIN;
DO $qa$
DECLARE m uuid:=gen_random_uuid(); n uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); original jsonb; v jsonb; denied boolean; c int:=0;
BEGIN
 INSERT INTO auth.users(id) VALUES(m),(n),(u);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP05 tone writer A','manager',true),(n,'QA STEP05 tone writer B','manager',true),(u,'QA STEP05 tone reader','cashier',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 SELECT setting_value INTO original FROM public.ff_app_settings WHERE setting_key='ff_global_tones';
 IF original IS NULL THEN original:='{"new_order":{"type":"built_in","key":"soft"},"delay":{"type":"built_in","key":"soft"}}';END IF;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 v:=public.ff_step05_set_global_tone('new_order','{"type":"built_in","key":"digital"}',original->'new_order');
 IF v->'delay' IS DISTINCT FROM original->'delay' OR v->'new_order'->>'key'<>'digital' THEN RAISE EXCEPTION 'first independent update failed';END IF;c:=c+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',n::text,true);SET LOCAL ROLE authenticated;
 v:=public.ff_step05_set_global_tone('delay','{"type":"built_in","key":"urgent"}',original->'delay');
 IF v->'new_order'->>'key'<>'digital' OR v->'delay'->>'key'<>'urgent' THEN RAISE EXCEPTION 'independent updates lost one event';END IF;c:=c+1;
 denied:=false;BEGIN PERFORM public.ff_step05_set_global_tone('new_order','{"type":"built_in","key":"classic"}','{"type":"built_in","key":"soft"}');EXCEPTION WHEN SQLSTATE '40001' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'stale writer accepted';END IF;c:=c+1;
 denied:=false;BEGIN PERFORM public.ff_step05_set_global_tone('bad','{"type":"built_in","key":"soft"}','{}');EXCEPTION WHEN SQLSTATE '22023' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'unknown event accepted';END IF;c:=c+1;
 denied:=false;BEGIN PERFORM public.ff_step05_set_global_tone('delay','{"type":"built_in"}','{"type":"built_in","key":"urgent"}');EXCEPTION WHEN SQLSTATE '22023' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'bad tone accepted';END IF;c:=c+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',u::text,true);SET LOCAL ROLE authenticated;
 denied:=false;BEGIN PERFORM public.ff_step05_set_global_tone('delay','{"type":"built_in","key":"soft"}','{"type":"built_in","key":"urgent"}');EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'nonmanager accepted';END IF;c:=c+1;
 RESET ROLE;IF has_function_privilege('anon','public.ff_step05_set_global_tone(text,jsonb,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'anon grant';END IF;c:=c+1;
 PERFORM set_config('ff.qa.step05.cas',jsonb_build_object('assertions',c,'independent_events_preserved',true,'stale_writer_rejected',true)::text,true);
END $qa$;
SELECT current_setting('ff.qa.step05.cas')::jsonb AS result;
ROLLBACK;
