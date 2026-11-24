DO $qa$
DECLARE b1 uuid:=gen_random_uuid(); b2 uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); k uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); o uuid:=gen_random_uuid(); o2 uuid:=gen_random_uuid(); t1 uuid:=gen_random_uuid(); t2 uuid:=gen_random_uuid(); n int; rev bigint; passes int:=0;
BEGIN
 BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-'||b1,'QA RT1'),(b2,'qa-'||b2,'QA RT2');
 INSERT INTO auth.users(id) VALUES(a),(c),(k),(m);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(a,'QA assembly','assembly',true),(c,'QA cashier','cashier',true),(k,'QA kitchen','burger_kitchen',true),(m,'QA manager','manager',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(a,b1),(c,b1),(k,b2);
 INSERT INTO public.ff_v9_assembly_access(user_id,branch_id,enabled,granted_by) VALUES(a,b1,true,m);
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d,'QA driver',b1);
 INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d,'busy',now(),now()) ON CONFLICT(driver_id) DO UPDATE SET state='busy',checked_in_at=now(),last_seen_at=now();
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot,driver_id,status)
 VALUES(o,-(1+floor(random()*1e12)::bigint),b1,'000000000',public.ff_business_date(now()),'QA',d,'sent');
 INSERT INTO public.ff38_delivery_tasks(order_id,driver_id) VALUES(o,d);
 INSERT INTO public.ff49_cashier_receipts(order_id,received_by,invoiced_by,invoiced_at) VALUES(o,c,c,now());
 UPDATE public.ff38_delivery_tasks SET cashier_stage='printed' WHERE order_id=o;
 SELECT revision INTO rev FROM public.ff27_branch_updates WHERE branch_id=b1;
 IF rev<>2 THEN RAISE EXCEPTION 'Initial hint revision mismatch: %',rev;END IF;passes:=passes+1;
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot)
 VALUES(o2,-(1+floor(random()*1e12)::bigint),b2,'000000000',public.ff_business_date(now()),'QA');
 INSERT INTO public.ff27_branch_updates(order_id,branch_id,revision) VALUES(o2,b2,1);
 INSERT INTO public.ff_burger_tickets(id,client_token,branch_id,order_kind,cashier_id,cashier_name,items,notes)
 VALUES(t1,gen_random_uuid(),b1,'local',c,'QA',jsonb_build_array(jsonb_build_object('name','QA','qty',1)),''),
 (t2,gen_random_uuid(),b2,'local',c,'QA',jsonb_build_array(jsonb_build_object('name','QA','qty',1)),'');
 PERFORM set_config('request.jwt.claim.sub',a::text,true);SET LOCAL ROLE authenticated;
 SELECT count(*) INTO n FROM public.ff27_branch_updates WHERE branch_id IN(b1,b2);
 IF n<>1 OR NOT EXISTS(SELECT 1 FROM public.ff27_branch_updates WHERE branch_id=b1) THEN RAISE EXCEPTION 'Assembly hint isolation';END IF;passes:=passes+1;
 IF (SELECT count(*) FROM public.ff_burger_tickets WHERE id IN(t1,t2))<>1 OR NOT EXISTS(SELECT 1 FROM public.ff_burger_tickets WHERE id=t1) THEN RAISE EXCEPTION 'Assembly ticket realtime isolation';END IF;passes:=passes+1;
 PERFORM public.ff_v12_assembly_set_stage(o,'preparing','printed');
 RESET ROLE;
 IF (SELECT revision FROM public.ff27_branch_updates WHERE branch_id=b1)<>rev+1 THEN RAISE EXCEPTION 'Assembly action did not signal';END IF;passes:=passes+1;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);SET LOCAL ROLE authenticated;
 IF (SELECT count(*) FROM public.ff27_branch_updates WHERE branch_id IN(b1,b2))<>1 THEN RAISE EXCEPTION 'Cashier hint isolation';END IF;passes:=passes+1;
 PERFORM public.ff38_cashier_set_stage(o,'ready');
 RESET ROLE;
 IF (SELECT revision FROM public.ff27_branch_updates WHERE branch_id=b1)<>rev+2 THEN RAISE EXCEPTION 'Cashier action did not signal';END IF;passes:=passes+1;
 UPDATE public.ff_v9_assembly_access SET enabled=false WHERE user_id=a;
 PERFORM set_config('request.jwt.claim.sub',a::text,true);SET LOCAL ROLE authenticated;
 IF EXISTS(SELECT 1 FROM public.ff27_branch_updates WHERE branch_id=b1) OR EXISTS(SELECT 1 FROM public.ff_burger_tickets WHERE id=t1) THEN RAISE EXCEPTION 'Revoked realtime access remains';END IF;passes:=passes+1;
 PERFORM set_config('request.jwt.claim.sub',k::text,true);
 IF (SELECT count(*) FROM public.ff_burger_tickets WHERE id IN(t1,t2))<>1 OR NOT EXISTS(SELECT 1 FROM public.ff_burger_tickets WHERE id=t2) THEN RAISE EXCEPTION 'Kitchen realtime isolation';END IF;passes:=passes+1;
 RESET ROLE;
 IF NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='ff27_branch_updates')
 OR has_table_privilege('authenticated','public.ff27_branch_updates','INSERT,UPDATE,DELETE') OR has_table_privilege('anon','public.ff27_branch_updates','SELECT') THEN RAISE EXCEPTION 'Publication or grants unsafe';END IF;passes:=passes+1;
 RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF passes<>9 OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id IN(b1,b2)) OR EXISTS(SELECT 1 FROM public.ff27_branch_updates WHERE branch_id IN(b1,b2)) THEN RAISE EXCEPTION 'Incomplete QA or rollback: %',passes;END IF;
END $qa$;
SELECT 'PASS A04 realtime: 9 assertions, assembly and cashier revisions, active branch isolation and revocation, publication and grants; rollback' AS result;