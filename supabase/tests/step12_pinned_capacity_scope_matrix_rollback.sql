BEGIN;
DO $qa$
DECLARE b uuid;b2 uuid:=gen_random_uuid();m uuid:=gen_random_uuid();cs uuid:=gen_random_uuid();c uuid:=gen_random_uuid();s uuid:=gen_random_uuid();duser uuid:=gen_random_uuid();a uuid:=gen_random_uuid();k uuid:=gen_random_uuid();u uuid:=gen_random_uuid();x uuid:=gen_random_uuid();d uuid:=gen_random_uuid();d2 uuid:=gen_random_uuid();actor uuid;desk text:='qa-'||gen_random_uuid();items jsonb:='[{"name":"QA pinned item","qty":1,"price":100}]';r jsonb;oid uuid;oid2 uuid;oid3 uuid;oldpin uuid;checks int:=0;
BEGIN
 SELECT id INTO STRICT b FROM public.ff_branches WHERE code='cairo' AND active;
 SELECT driver_id INTO oldpin FROM public.ff62_pinned_drivers WHERE branch_id=b;
 INSERT INTO auth.users(id) VALUES(m),(cs),(c),(s),(duser),(a),(k),(u),(x);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 pin manager','manager',true),(cs,'QA STEP12 pin CS','customer_service',true),(c,'QA STEP12 pin cashier','cashier',true),(s,'QA STEP12 pin supervisor','supervisor',true),(duser,'QA STEP12 pin driver','driver',true),(a,'QA STEP12 pin assembly','assembly',true),(k,'QA STEP12 pin kitchen','burger_kitchen',true),(x,'QA STEP12 pin disabled','manager',false);
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 INSERT INTO public.ff_branches(id,code,name) VALUES(b2,'qa-step12-pin-'||b2,'QA STEP12 pin branch');
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c,b2),(s,b2),(duser,b2),(a,b2),(k,b2);
 INSERT INTO public.ff_luxe_cashier_desks(code,label,branch_id,sort_order) VALUES(desk,'QA pinned desk',b,9998);
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d,'QA STEP12 pinned driver',b),(d2,'QA STEP12 special driver',b2);
 INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d,'ready',now(),now()),(d2,'ready',now(),now()) ON CONFLICT(driver_id) DO UPDATE SET state='ready',checked_in_at=now(),last_seen_at=now();
 INSERT INTO ff_private.special_courier_capacity(driver_id) VALUES(d2);
 SET LOCAL ROLE authenticated;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 r:=public.ff62_set_pinned(d);IF r->>'driver_id' IS DISTINCT FROM d::text THEN RAISE EXCEPTION 'Manager pin lost';END IF;checks:=checks+1;
 FOREACH actor IN ARRAY ARRAY[c,s,duser,a,k,u,x] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff62_cairo_drivers();RAISE EXCEPTION 'Other branch Cairo drivers visible' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff62_get_pinned();RAISE EXCEPTION 'Other branch pinned identity visible' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff62_set_pinned(d);RAISE EXCEPTION 'Unauthorized pinned mutation' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff62_create_pinned_order(b,'000000000','QA area',items,0,'QA');RAISE EXCEPTION 'Unauthorized pinned creation' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff_luxe_create_pinned_order_in_desk(b,desk,'000000000','QA area',items,0,'QA');RAISE EXCEPTION 'Unauthorized desk pinned creation' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff_luxe_create_delivery_order_in_desk(b,desk,'000000000','QA area',items,0,'QA');RAISE EXCEPTION 'Unauthorized desk delivery creation' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff_confirm_pinned_order(d,b,desk,'000000000','QA area',items,'QA','');RAISE EXCEPTION 'Unauthorized pinned confirmation' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff_set_special_courier_capacity(d2,7);RAISE EXCEPTION 'Unauthorized capacity change' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY[c,duser,a,k,u,x] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff_special_courier_status(d2);RAISE EXCEPTION 'Unauthorized capacity read' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY[m,cs] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  r:=public.ff62_cairo_drivers();IF NOT EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'id'=d::text) THEN RAISE EXCEPTION 'Cairo driver fixture missing';END IF;checks:=checks+1;
  r:=public.ff62_get_pinned();IF r->>'driver_id' IS DISTINCT FROM d::text THEN RAISE EXCEPTION 'Central pinned read lost';END IF;checks:=checks+1;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',s::text,true);
 r:=public.ff_special_courier_status(d2);IF r->>'capacity' IS DISTINCT FROM '5' OR r->>'can_manage' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Scoped supervisor capacity read lost';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',cs::text,true);
 BEGIN PERFORM public.ff_set_special_courier_capacity(d2,7);RAISE EXCEPTION 'CS capacity mutation accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 BEGIN PERFORM public.ff_confirm_pinned_order(d,b,desk,'000000000','QA area',items,'QA','QA override');RAISE EXCEPTION 'CS override accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 r:=public.ff62_set_pinned(d);IF r->>'driver_id' IS DISTINCT FROM d::text THEN RAISE EXCEPTION 'Authorized CS pin lost';END IF;checks:=checks+1;
 r:=public.ff_confirm_pinned_order(d,b,desk,'000000000','QA area',items,'QA','');oid:=(r->>'order_id')::uuid;IF r#>>'{dispatch,state}' IS DISTINCT FROM 'assigned_pinned' THEN RAISE EXCEPTION 'Pinned confirmation lost';END IF;checks:=checks+1;
 r:=public.ff62_create_pinned_order(b,'000000000','QA area',items,999,'QA');oid2:=(r->>'order_id')::uuid;IF r#>>'{dispatch,state}' IS DISTINCT FROM 'assigned_pinned' THEN RAISE EXCEPTION 'Legacy pinned creation lost';END IF;checks:=checks+1;
 -- Ordinary delivery uses an isolated branch/desk rather than any actual courier.
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',m::text,true);
 INSERT INTO public.ff_luxe_cashier_desks(code,label,branch_id,sort_order) VALUES(desk||'-2','QA delivery desk',b2,9998);
 SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',cs::text,true);
 r:=public.ff_luxe_create_delivery_order_in_desk(b2,desk||'-2','000000000','QA area',items,100,'QA');oid3:=(r->>'order_id')::uuid;IF oid3 IS NULL THEN RAISE EXCEPTION 'Authorized desk delivery lost';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 r:=public.ff_set_special_courier_capacity(d2,7);IF r->>'capacity' IS DISTINCT FROM '7' OR r->>'can_manage' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Manager capacity update lost';END IF;checks:=checks+1;
 RESET ROLE;
 IF (SELECT count(*) FROM public.ff_orders WHERE id IN(oid,oid2) AND delivery_fee=0 AND driver_id=d)<>2 OR NOT EXISTS(SELECT FROM public.ff_luxe_cashier_order_desks WHERE order_id=oid AND desk_code=desk) THEN RAISE EXCEPTION 'Pinned fee or desk persistence mismatch';END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT FROM public.ff_luxe_cashier_order_desks WHERE order_id=oid3 AND desk_code=desk||'-2') THEN RAISE EXCEPTION 'Delivery desk persistence mismatch';END IF;checks:=checks+1;
 IF checks<>77 THEN RAISE EXCEPTION 'Expected 77 assertions, got %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 pinned order and capacity matrix: 77 assertions; scoped roles, central pin, zero fee, desk routing and manager-only capacity; rollback' result;
ROLLBACK;
