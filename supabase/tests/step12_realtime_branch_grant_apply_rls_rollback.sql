BEGIN;
DO $qa$
DECLARE a uuid:=gen_random_uuid();b uuid:=gen_random_uuid();ba uuid:=gen_random_uuid();bb uuid:=gen_random_uuid();oa uuid:=gen_random_uuid();sa uuid:=gen_random_uuid();sb uuid:=gen_random_uuid();suba uuid;subb uuid;tbl text;pk text;pkval uuid;v_wal jsonb;act text;seen_a boolean;seen_b boolean;checks int:=0;
BEGIN
 INSERT INTO auth.users(id) VALUES(a),(b);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(a,'QA STEP12 transport A','cashier',true),(b,'QA STEP12 transport B','cashier',true);
 INSERT INTO public.ff_branches(id,code,name) VALUES(ba,'qa-rt-transport-'||ba,'QA RT A'),(bb,'qa-rt-transport-'||bb,'QA RT B');
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(a,ba),(b,bb);
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,status) VALUES(oa,-1000000000000-floor(random()*1e12)::bigint,ba,'000000000',public.ff_business_date(now()),'new');
 INSERT INTO public.ff27_branch_updates(order_id,branch_id) VALUES(oa,ba) ON CONFLICT(order_id) DO UPDATE SET branch_id=excluded.branch_id;
 INSERT INTO public.ff_a09_grant_events(recipient) VALUES(a) ON CONFLICT(recipient) DO NOTHING;
 INSERT INTO auth.sessions(id,user_id,created_at,updated_at) VALUES(sa,a,now(),now()),(sb,b,now(),now());
 PERFORM set_config('request.jwt.claim.sub','',true);
 FOREACH tbl IN ARRAY ARRAY['ff27_branch_updates','ff_a09_grant_events'] LOOP
  suba:=gen_random_uuid();subb:=gen_random_uuid();
  pk:=CASE WHEN tbl='ff27_branch_updates' THEN 'order_id' ELSE 'recipient' END;
  pkval:=CASE WHEN tbl='ff27_branch_updates' THEN oa ELSE a END;
  INSERT INTO realtime.subscription(id,subscription_id,entity,claims,action_filter) OVERRIDING SYSTEM VALUE VALUES
   (-floor(random()*1e12)::bigint-1,suba,format('public.%I',tbl)::regclass,jsonb_build_object('role','authenticated','sub',a,'session_id',sa),'*'),
   (-floor(random()*1e12)::bigint-1,subb,format('public.%I',tbl)::regclass,jsonb_build_object('role','authenticated','sub',b,'session_id',sb),'*');
  FOREACH act IN ARRAY ARRAY['I','U'] LOOP
   v_wal:=jsonb_build_object('schema','public','table',tbl,'action',act,'timestamp',now(),'pk',jsonb_build_array(jsonb_build_object('name',pk)),'columns',jsonb_build_array(jsonb_build_object('name',pk,'type','uuid','typeoid','2950','value',pkval)),'identity',jsonb_build_array(jsonb_build_object('name',pk,'type','uuid','typeoid','2950','value',pkval)));
   SELECT coalesce(bool_or(suba=any(r.subscription_ids)),false),coalesce(bool_or(subb=any(r.subscription_ids)),false) INTO seen_a,seen_b FROM realtime.apply_rls(v_wal) r;
   IF NOT seen_a OR seen_b THEN RAISE EXCEPTION 'scope failed for % %',tbl,act;END IF;checks:=checks+2;
  END LOOP;
 END LOOP;
 IF checks<>8 THEN RAISE EXCEPTION 'wrong assertion count';END IF;
END $qa$;
SELECT 'PASS STEP12 branch and grant event apply_rls: 8 synthetic assertions; rollback, no WebSocket transport' AS result;
ROLLBACK;
