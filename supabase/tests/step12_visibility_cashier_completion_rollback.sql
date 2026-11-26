BEGIN;
DO $qa$
DECLARE b1 uuid:=gen_random_uuid();b2 uuid:=gen_random_uuid();m uuid:=gen_random_uuid();cs uuid:=gen_random_uuid();c uuid:=gen_random_uuid();s uuid:=gen_random_uuid();du uuid:=gen_random_uuid();a uuid:=gen_random_uuid();k uuid:=gen_random_uuid();u uuid:=gen_random_uuid();x uuid:=gen_random_uuid();d1 uuid:=gen_random_uuid();d2 uuid:=gen_random_uuid();d3 uuid:=gen_random_uuid();o uuid[]:=ARRAY[gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];ad uuid[]:=ARRAY[gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];dk1 text:='qa-'||gen_random_uuid();dk2 text:='qa-'||gen_random_uuid();r jsonb;actor uuid;i int;n bigint:=-1000000000000-floor(random()*1e12)::bigint;checks int:=0;expected uuid[];
BEGIN
 INSERT INTO auth.users(id) VALUES(m),(cs),(c),(s),(du),(a),(k),(u),(x);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 visibility manager','manager',true),(cs,'QA STEP12 visibility CS','customer_service',true),(c,'QA STEP12 visibility cashier','cashier',true),(s,'QA STEP12 visibility supervisor','supervisor',true),(du,'QA STEP12 visibility driver','driver',true),(a,'QA STEP12 visibility assembly','assembly',true),(k,'QA STEP12 visibility kitchen','burger_kitchen',true),(x,'QA STEP12 visibility disabled','cashier',false);
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-step12-vis-'||b1,'QA STEP12 visibility one'),(b2,'qa-step12-vis-'||b2,'QA STEP12 visibility two');
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c,b1),(s,b1),(du,b1),(a,b1),(k,b1),(x,b1);
 INSERT INTO public.ff38_staff_permission_overrides(user_id,permission_key,allowed,updated_by) VALUES(c,'edit_order',true,m);
 INSERT INTO public.ff_luxe_cashier_desks(code,label,branch_id,sort_order) VALUES(dk1,'QA desk 1',b1,1),(dk2,'QA desk 2',b1,2);
 INSERT INTO public.ff_luxe_cashier_staff_desks(user_id,desk_code,assigned_by) VALUES(c,dk1,m);
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d1,'QA visibility driver A',b1),(d2,'QA visibility driver B',b1),(d3,'QA visibility driver C',b2);
 INSERT INTO public.ff38_driver_links(user_id,driver_id) VALUES(du,d1);
 INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d1,'busy',now(),now()),(d2,'busy',now(),now()),(d3,'busy',now(),now()) ON CONFLICT(driver_id) DO UPDATE SET state='busy',checked_in_at=now(),last_seen_at=now();
 FOR i IN 1..7 LOOP
  INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,area_snapshot,status,created_by,items_total,delivery_fee,total,driver_id)
  VALUES(o[i],n-i,CASE WHEN i IN(3,6) THEN b2 ELSE b1 END,'000000000','QA area',CASE WHEN i IN(4,5,6) THEN 'cancelled' ELSE 'sent' END,cs,100,0,100,CASE WHEN i IN(1,4,7) THEN d1 WHEN i IN(2,5) THEN d2 ELSE d3 END);
  IF i IN(1,2,3,7) THEN
   INSERT INTO public.ff38_delivery_tasks(order_id,driver_id,phase,cashier_stage) VALUES(o[i],CASE WHEN i IN(1,7) THEN d1 WHEN i=2 THEN d2 ELSE d3 END,CASE WHEN i=7 THEN 'on_way' ELSE 'assigned' END,CASE WHEN i=7 THEN 'handed_over' ELSE 'waiting' END);
  ELSE INSERT INTO public.ff_luxe_cancel_ack(order_id,branch_id,cancelled_by,reason) VALUES(o[i],CASE WHEN i=6 THEN b2 ELSE b1 END,m,'QA synthetic cancel');END IF;
  IF i IN(1,2,4,5,7) THEN INSERT INTO public.ff_luxe_cashier_order_desks(order_id,desk_code) VALUES(o[i],CASE WHEN i IN(1,4,7) THEN dk1 ELSE dk2 END);END IF;
  IF i<=3 THEN INSERT INTO public.ff38_order_additions(id,order_id,requested_by) VALUES(ad[i],o[i],cs);END IF;
 END LOOP;
 SET LOCAL ROLE authenticated;
 FOREACH actor IN ARRAY ARRAY[m,cs,c,s,du] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  expected:=CASE WHEN actor IN(m,cs) THEN ARRAY[o[1],o[2],o[3]] WHEN actor=s THEN ARRAY[o[1],o[2]] ELSE ARRAY[o[1]] END;
  r:=public.ff49_snapshot();
  IF EXISTS(SELECT FROM unnest(o[1:3]) z WHERE (EXISTS(SELECT FROM jsonb_array_elements(r->'orders') j WHERE j->>'id'=z::text)) IS DISTINCT FROM (z=ANY(expected))) THEN RAISE EXCEPTION 'Snapshot visibility mismatch';END IF;checks:=checks+1;
  r:=public.ff38_list_visible_additions();
  IF EXISTS(SELECT FROM unnest(o[1:3]) z WHERE (EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'order_id'=z::text)) IS DISTINCT FROM (z=ANY(expected))) THEN RAISE EXCEPTION 'Addition visibility mismatch';END IF;checks:=checks+1;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY[a,k,u,x] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff38_list_visible_additions();RAISE EXCEPTION 'Unauthorized additions accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'المستخدم غير مخول' THEN RAISE;END IF;END;checks:=checks+1;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY[u,x] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff49_snapshot();RAISE EXCEPTION 'Inactive snapshot accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY[m,cs,c,s,du,a,k,u,x] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  r:=public.ff_luxe_cashier_cancel_alerts();
  expected:=CASE WHEN actor=m THEN ARRAY[o[4],o[5],o[6]] WHEN actor=c THEN ARRAY[o[4]] ELSE ARRAY[]::uuid[] END;
  IF EXISTS(SELECT FROM unnest(o[4:6]) z WHERE (EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'order_id'=z::text)) IS DISTINCT FROM (z=ANY(expected))) THEN RAISE EXCEPTION 'Cancellation alert scope mismatch';END IF;checks:=checks+1;
  IF actor<>c THEN
   BEGIN PERFORM public.ff_luxe_cashier_completed_orders(60,0);RAISE EXCEPTION 'Noncashier completed list accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
   BEGIN PERFORM public.ff_luxe_cashier_completed_invoice(o[7],'QA invoice');RAISE EXCEPTION 'Noncashier completed invoice accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  END IF;
  IF actor<>m THEN
   BEGIN PERFORM public.ff_luxe_manager_driver_progress(o[7],'arrived','QA reason');RAISE EXCEPTION 'Nonmanager progress accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
  END IF;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);
 r:=public.ff_luxe_cashier_completed_orders(60,0);
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(r->'items') j WHERE j->>'id'=o[4]::text) OR NOT EXISTS(SELECT FROM jsonb_array_elements(r->'items') j WHERE j->>'id'=o[7]::text) OR EXISTS(SELECT FROM jsonb_array_elements(r->'items') j WHERE j->>'id' IN(o[5]::text,o[6]::text)) THEN RAISE EXCEPTION 'Completed cashier desk scope mismatch';END IF;checks:=checks+1;
 BEGIN PERFORM public.ff_luxe_cashier_completed_invoice(o[5],'QA invoice');RAISE EXCEPTION 'Other desk invoice accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 BEGIN PERFORM public.ff_order_customer_edit(o[2],'000000001','QA area','QA name','QA address','QA reason');RAISE EXCEPTION 'Other desk edit accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 BEGIN PERFORM public.ff_order_customer_edit_with_note(o[3],'000000001','QA area','QA name','QA address','QA reason','');RAISE EXCEPTION 'Other branch edit accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 BEGIN PERFORM public.ff_order_customer_edit_with_note(o[1],'000000001','QA area','QA name','QA address','QA reason','QA private note');RAISE EXCEPTION 'Cashier private customer note accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN insufficient_privilege THEN NULL;END;checks:=checks+1;
 PERFORM public.ff_luxe_cashier_completed_invoice(o[7],'QA invoice');checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 r:=public.ff_luxe_manager_driver_progress(o[7],'arrived','QA manager reason');IF r->>'phase' IS DISTINCT FROM 'arrived' THEN RAISE EXCEPTION 'Manager progress failed';END IF;checks:=checks+1;
 RESET ROLE;
 IF (SELECT phase FROM public.ff38_delivery_tasks WHERE order_id=o[7]) IS DISTINCT FROM 'arrived' OR NOT EXISTS(SELECT FROM public.ff_audit_log WHERE entity_id=o[7]::text AND action='manager_driver_progress' AND actor_id=m) OR NOT EXISTS(SELECT FROM public.ff_luxe_late_invoice_refs WHERE order_id=o[7] AND invoice_ref='QA invoice') THEN RAISE EXCEPTION 'Authorized state evidence missing';END IF;checks:=checks+1;
 IF EXISTS(SELECT FROM public.ff_order_customer_edits WHERE order_id=ANY(o)) OR EXISTS(SELECT FROM public.ff_luxe_late_invoice_refs WHERE order_id IN(o[5],o[6])) THEN RAISE EXCEPTION 'Denied action wrote data';END IF;checks:=checks+1;
 IF checks<>58 THEN RAISE EXCEPTION 'Expected 58 assertions, got %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 visibility and cashier completion: 58 assertions; snapshot/addition scope, desk alerts/invoices, contact edit denial, manager progress audit; rollback' result;
ROLLBACK;
