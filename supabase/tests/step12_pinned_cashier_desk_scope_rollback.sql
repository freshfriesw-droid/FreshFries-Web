BEGIN;
DO $qa$
DECLARE b uuid; old_pinned uuid; m uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); o1 uuid:=gen_random_uuid(); o2 uuid:=gen_random_uuid(); desk1 text:='qa-'||gen_random_uuid(); desk2 text:='qa-'||gen_random_uuid(); r jsonb;checks int:=0;
BEGIN
 SELECT id INTO STRICT b FROM public.ff_branches WHERE code='cairo';
 SELECT driver_id INTO STRICT old_pinned FROM public.ff62_pinned_drivers WHERE branch_id=b;
 BEGIN
 INSERT INTO auth.users(id) VALUES(m),(c);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 pinned manager','manager',true),(c,'QA STEP12 pinned cashier','cashier',true);
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c,b);
 INSERT INTO public.ff38_staff_permission_overrides(user_id,permission_key,allowed,updated_by) VALUES(c,'assign_driver',true,m);
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d,'QA pinned isolated',b);
 UPDATE public.ff62_pinned_drivers SET driver_id=d WHERE branch_id=b;
 INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d,'ready',now(),now()) ON CONFLICT(driver_id) DO UPDATE SET state='ready',checked_in_at=now(),last_seen_at=now(),checked_out_at=NULL;
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,area_snapshot,business_date,created_by,items_total,delivery_fee,total) VALUES(o1,-1000000000000-floor(random()*1e12)::bigint,b,'000000000','QA',public.ff_business_date(now()),m,1000,500,1500),(o2,-1000000000000-floor(random()*1e12)::bigint,b,'000000000','QA',public.ff_business_date(now()),m,1000,500,1500);
 INSERT INTO public.ff_luxe_cashier_desks(code,label,branch_id,sort_order) VALUES(desk1,'QA pinned desk1',b,9997),(desk2,'QA pinned desk2',b,9998);
 INSERT INTO public.ff_luxe_cashier_staff_desks(user_id,desk_code,assigned_by) VALUES(c,desk1,m);
 INSERT INTO public.ff_luxe_cashier_order_desks(order_id,desk_code) VALUES(o1,desk1),(o2,desk2) ON CONFLICT(order_id) DO UPDATE SET desk_code=excluded.desk_code;
 SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',c::text,true);
 BEGIN PERFORM public.ff62_assign_pinned(o2);RAISE EXCEPTION 'Wrong desk accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 RESET ROLE;
 IF EXISTS(SELECT FROM public.ff38_delivery_tasks WHERE order_id=o2) OR (SELECT driver_id FROM public.ff_orders WHERE id=o2) IS NOT NULL THEN RAISE EXCEPTION 'Denied assignment mutated order';END IF;checks:=checks+1;
 SET LOCAL ROLE authenticated;
 r:=public.ff62_assign_pinned(o1);
 IF r->>'state'<>'assigned_pinned' OR (r->>'delivery_fee')::numeric<>0 THEN RAISE EXCEPTION 'Own desk assignment failed';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 r:=public.ff62_assign_pinned(o2);
 IF r->>'state'<>'assigned_pinned' OR (r->>'delivery_fee')::numeric<>0 THEN RAISE EXCEPTION 'Manager assignment failed';END IF;checks:=checks+1;
 RESET ROLE;
 IF NOT EXISTS(SELECT FROM public.ff38_driver_presence WHERE driver_id=d AND state='busy') THEN RAISE EXCEPTION 'Pinned presence not updated';END IF;checks:=checks+1;
 RAISE EXCEPTION 'fixture rollback' USING ERRCODE='ZQ012';
 EXCEPTION WHEN SQLSTATE 'ZQ012' THEN NULL; END;
 IF (SELECT driver_id FROM public.ff62_pinned_drivers WHERE branch_id=b) IS DISTINCT FROM old_pinned OR EXISTS(SELECT FROM public.ff_drivers WHERE id=d) OR EXISTS(SELECT FROM public.ff_orders WHERE id IN(o1,o2)) THEN RAISE EXCEPTION 'Rollback failed';END IF;checks:=checks+1;
 IF checks<>6 THEN RAISE EXCEPTION 'Incomplete pinned scope test';END IF;
END $qa$;
SELECT 'PASS STEP12 pinned desk: 6 assertions including denied wrong desk, own desk, manager, fee and rollback' result;
ROLLBACK;
