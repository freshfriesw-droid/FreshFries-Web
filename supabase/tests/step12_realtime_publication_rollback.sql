BEGIN;
DO $qa$
DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); sa uuid:=gen_random_uuid(); sb uuid:=gen_random_uuid(); suba uuid:=gen_random_uuid(); subb uuid:=gen_random_uuid(); mid uuid:=gen_random_uuid(); v_wal jsonb; a_seen boolean; b_seen boolean; checks int:=0; act text; expected_tables text[]:=ARRAY['ff27_branch_updates','ff38_delivery_tasks','ff38_order_additions','ff39_message_recipients','ff49_cashier_receipts','ff49_driver_transfers','ff_a09_grant_events','ff_burger_tickets','ff_order_items','ff_orders'];
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime' AND pubinsert AND pubupdate AND NOT pubdelete AND NOT pubtruncate AND NOT puballtables) THEN RAISE EXCEPTION 'unsafe publication actions';END IF;checks:=checks+1;
 IF (SELECT array_agg(tablename::text ORDER BY tablename::text COLLATE "C") FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public') IS DISTINCT FROM (SELECT array_agg(t ORDER BY t COLLATE "C") FROM unnest(expected_tables)t) OR (SELECT count(*) FROM pg_publication_tables WHERE pubname='supabase_realtime')<>10 THEN RAISE EXCEPTION 'unexpected publication membership';END IF;checks:=checks+1;
 INSERT INTO auth.users(id) VALUES(a),(b),(m);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(a,'QA STEP12 publication A','cashier',true),(b,'QA STEP12 publication B','cashier',true),(m,'QA STEP12 publication manager','manager',true);
 INSERT INTO auth.sessions(id,user_id,created_at,updated_at) VALUES(sa,a,now(),now()),(sb,b,now(),now());
 INSERT INTO public.ff39_messages(id,sender_id,title,body) VALUES(mid,m,'QA synthetic','QA synthetic');
 INSERT INTO public.ff39_message_recipients(message_id,user_id) VALUES(mid,a) ON CONFLICT DO NOTHING;
 INSERT INTO realtime.subscription(id,subscription_id,entity,claims,action_filter) OVERRIDING SYSTEM VALUE VALUES
 (-floor(random()*1e12)::bigint-1,suba,'public.ff39_message_recipients'::regclass,jsonb_build_object('role','authenticated','sub',a,'session_id',sa),'*'),
 (-floor(random()*1e12)::bigint-1,subb,'public.ff39_message_recipients'::regclass,jsonb_build_object('role','authenticated','sub',b,'session_id',sb),'*');
 PERFORM set_config('request.jwt.claim.sub','',true);
 FOREACH act IN ARRAY ARRAY['I','U'] LOOP
  v_wal:=jsonb_build_object('schema','public','table','ff39_message_recipients','action',act,'timestamp',now(),'pk',jsonb_build_array(jsonb_build_object('name','message_id'),jsonb_build_object('name','user_id')),'columns',jsonb_build_array(jsonb_build_object('name','message_id','type','uuid','typeoid','2950','value',mid),jsonb_build_object('name','user_id','type','uuid','typeoid','2950','value',a)),'identity',jsonb_build_array(jsonb_build_object('name','message_id','type','uuid','typeoid','2950','value',mid),jsonb_build_object('name','user_id','type','uuid','typeoid','2950','value',a)));
  SELECT coalesce(bool_or(suba=any(r.subscription_ids)),false),coalesce(bool_or(subb=any(r.subscription_ids)),false) INTO a_seen,b_seen FROM realtime.apply_rls(v_wal) r;
  IF NOT a_seen OR b_seen THEN RAISE EXCEPTION 'recipient isolation failed for %',act;END IF;checks:=checks+2;
 END LOOP;
 DELETE FROM auth.sessions WHERE id=sa AND user_id=a;
 SELECT coalesce(bool_or(suba=any(r.subscription_ids)),false) INTO a_seen FROM realtime.apply_rls(v_wal) r;
 IF a_seen THEN RAISE EXCEPTION 'revoked synthetic session still visible';END IF;checks:=checks+1;
 IF checks<>7 THEN RAISE EXCEPTION 'wrong assertion count';END IF;
END $qa$;
SELECT 'PASS STEP12 publication actions and Realtime apply_rls synthetic INSERT/UPDATE: 7 checks' AS result;
ROLLBACK;
