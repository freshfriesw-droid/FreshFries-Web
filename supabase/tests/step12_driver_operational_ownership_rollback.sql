BEGIN;
DO $qa$
DECLARE b uuid:=gen_random_uuid();u1 uuid:=gen_random_uuid();u2 uuid:=gen_random_uuid();m uuid:=gen_random_uuid();d1 uuid:=gen_random_uuid();d2 uuid:=gen_random_uuid();o1 uuid:=gen_random_uuid();o2 uuid:=gen_random_uuid();od uuid:=gen_random_uuid();oc uuid:=gen_random_uuid();ofr uuid:=gen_random_uuid();f uuid:=gen_random_uuid();r jsonb;checks int:=0;
BEGIN
 INSERT INTO auth.users(id) VALUES(u1),(u2),(m);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(u1,'QA STEP12 driver one','driver',true),(u2,'QA STEP12 driver two','driver',true),(m,'QA STEP12 manager','manager',true);
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-driver-owner-'||b,'QA driver scope');
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(u1,b),(u2,b);
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d1,'QA driver one',b),(d2,'QA driver two',b);
 INSERT INTO public.ff38_driver_links(user_id,driver_id) VALUES(u1,d1),(u2,d2);
 INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d1,'busy',now(),now()),(d2,'busy',now(),now()) ON CONFLICT(driver_id) DO UPDATE SET state=excluded.state,checked_in_at=excluded.checked_in_at,last_seen_at=excluded.last_seen_at;
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,driver_id,status,area_snapshot) VALUES
 (o1,-1000000000000-floor(random()*1e12)::bigint,b,'000000000',public.ff_business_date(now()),d1,'sent','QA area'),
 (o2,-1000000000000-floor(random()*1e12)::bigint,b,'000000000',public.ff_business_date(now()),d2,'sent','QA area'),
 (od,-1000000000000-floor(random()*1e12)::bigint,b,'000000000',public.ff_business_date(now()),d2,'delivered','QA area'),
 (oc,-1000000000000-floor(random()*1e12)::bigint,b,'000000000',public.ff_business_date(now()),d2,'cancelled','QA area'),
 (ofr,-1000000000000-floor(random()*1e12)::bigint,b,'000000000',public.ff_business_date(now()),NULL,'new','QA area');
 INSERT INTO public.ff38_delivery_tasks(order_id,driver_id) VALUES(o1,d1),(o2,d2);
 INSERT INTO public.ff38_delivery_tasks(order_id,driver_id,phase,cashier_stage,delivered_at) VALUES(od,d2,'delivered','handed_over',now()),(oc,d2,'assigned','waiting',now());
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 INSERT INTO public.ff38_dispatch_offers(id,order_id,driver_id,expires_at) VALUES(f,ofr,d2,now()+interval '10 minutes');
 INSERT INTO public.ff_luxe_cancel_ack(order_id,branch_id,cancelled_by,reason) VALUES(oc,b,m,'QA synthetic cancelled');
 SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',u1::text,true);
 BEGIN PERFORM public.ff38_driver_progress(o2,'on_way');RAISE EXCEPTION 'Other driver progress accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'الطلب ليس نشطاً أو ليس مسنداً لحسابك' THEN RAISE;END IF;END;checks:=checks+1;
 BEGIN PERFORM public.ff38_driver_reply(f,true,NULL);RAISE EXCEPTION 'Other driver offer accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'العرض غير متاح' THEN RAISE;END IF;END;checks:=checks+1;
 BEGIN PERFORM public.ff_luxe_driver_grievance(o2,'other','QA synthetic details');RAISE EXCEPTION 'Other driver grievance accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 BEGIN PERFORM public.ff_luxe_driver_rate_order(od,5,5,5,5,'QA synthetic');RAISE EXCEPTION 'Other driver feedback accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 BEGIN PERFORM public.ff_luxe_skip_driver_cancel(oc);RAISE EXCEPTION 'Other driver skip accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 BEGIN PERFORM public.ff60_list_workflow(o2,20);RAISE EXCEPTION 'Other driver workflow accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 r:=public.ff_luxe_driver_cancel_alerts();IF EXISTS(SELECT FROM jsonb_array_elements(r) z WHERE z->>'order_id'=oc::text) THEN RAISE EXCEPTION 'Other driver cancel alert visible';END IF;checks:=checks+1;
 r:=public.ff_a10_driver_rating_queue();IF EXISTS(SELECT FROM jsonb_array_elements(r) z WHERE z->>'id'=od::text) THEN RAISE EXCEPTION 'Other driver rating queue visible';END IF;checks:=checks+1;
 r:=public.ff60_list_workflow(o1,20);IF jsonb_typeof(r) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Own workflow broken';END IF;checks:=checks+1;
 r:=public.ff_luxe_driver_grievance(o1,'other','QA synthetic details');IF r->>'submitted' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Own grievance broken';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',u2::text,true);
 r:=public.ff_a10_driver_rating_queue();IF NOT EXISTS(SELECT FROM jsonb_array_elements(r) z WHERE z->>'id'=od::text) THEN RAISE EXCEPTION 'Own rating queue broken';END IF;checks:=checks+1;
 r:=public.ff_luxe_driver_rate_order(od,5,5,5,5,'QA synthetic');IF r->>'saved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Own feedback broken';END IF;checks:=checks+1;
 r:=public.ff_luxe_driver_cancel_alerts();IF NOT EXISTS(SELECT FROM jsonb_array_elements(r) z WHERE z->>'order_id'=oc::text) THEN RAISE EXCEPTION 'Own cancel alert broken';END IF;checks:=checks+1;
 PERFORM public.ff_luxe_skip_driver_cancel(oc);
 r:=public.ff_luxe_driver_cancel_alerts();IF EXISTS(SELECT FROM jsonb_array_elements(r) z WHERE z->>'order_id'=oc::text) THEN RAISE EXCEPTION 'Own cancel skip broken';END IF;checks:=checks+1;
 RESET ROLE;
 IF (SELECT status FROM public.ff38_dispatch_offers WHERE id=f) IS DISTINCT FROM 'offered' OR (SELECT phase FROM public.ff38_delivery_tasks WHERE order_id=o2) IS DISTINCT FROM 'assigned' THEN RAISE EXCEPTION 'Denied action altered data';END IF;checks:=checks+1;
 IF checks<>15 THEN RAISE EXCEPTION 'Expected 15 checks got %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 driver operational ownership: 15 assertions' result;
ROLLBACK;
