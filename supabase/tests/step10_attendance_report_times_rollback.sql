DO $qa$
DECLARE b uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); d2 uuid:=gen_random_uuid(); dy date:=public.ff_business_date(now())-3; rr jsonb; a jsonb; start_at timestamptz; stop_at timestamptz;
BEGIN
BEGIN
start_at:=(dy+time '08:00') AT TIME ZONE 'Asia/Aden'; stop_at:=((dy+1)+time '02:00') AT TIME ZONE 'Asia/Aden';
INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-step10-att-'||b,'QA attendance');
INSERT INTO auth.users(id) VALUES(m);
INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA manager','manager',true) ON CONFLICT(user_id) DO UPDATE SET role='manager',active=true;
INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d,'QA clipped',b),(d2,'QA open',b);
INSERT INTO public.ff76_driver_work_sessions(driver_id,checked_in_at,checked_out_at,source) VALUES(d,start_at-interval '1 hour',stop_at+interval '1 hour','presence_trigger'),(d2,start_at+interval '1 hour',NULL,'presence_trigger');
PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
rr:=public.ff_a10_reporting_center(dy,dy,b,NULL,NULL,NULL,NULL,NULL);
SELECT x INTO a FROM jsonb_array_elements(rr->'attendance') x WHERE x->>'driver_id'=d::text;
IF a IS NULL OR (a->>'actual_first_checkin')::timestamptz<>start_at-interval '1 hour' OR (a->>'actual_last_checkout')::timestamptz<>stop_at+interval '1 hour' OR (a->>'first_checkin')::timestamptz<>start_at OR (a->>'last_checkout')::timestamptz<>stop_at OR (a->>'work_hours')::numeric<>18 OR (a->>'open_session')::boolean THEN RAISE EXCEPTION 'Clipped session mismatch';END IF;
SELECT x INTO a FROM jsonb_array_elements(rr->'attendance') x WHERE x->>'driver_id'=d2::text;
IF a IS NULL OR NOT (a->>'open_session')::boolean OR a->>'actual_last_checkout' IS NOT NULL OR (a->>'work_hours')::numeric<>17 THEN RAISE EXCEPTION 'Open session false checkout';END IF;
rr:=public.ff_a10_reporting_center(dy,dy,b,NULL,NULL,'QA filter',NULL,NULL);
IF jsonb_array_length(rr->'attendance')<>0 THEN RAISE EXCEPTION 'Attendance attributed to partial filter';END IF;
RESET ROLE;
RAISE EXCEPTION 'rollback QA' USING ERRCODE='PZ010';
EXCEPTION WHEN SQLSTATE 'PZ010' THEN NULL;END;
IF EXISTS(SELECT 1 FROM public.ff_branches WHERE id=b) THEN RAISE EXCEPTION 'Rollback failed';END IF;
END $qa$;
SELECT 'PASS STEP10 attendance actual timestamps, operating boundary, open session and partial filter; rollback' result;
