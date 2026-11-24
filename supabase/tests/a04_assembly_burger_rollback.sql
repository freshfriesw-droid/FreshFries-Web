-- A04 production RPC regression. All fixtures rolled back.
DO $qa$
DECLARE bs uuid[]:=ARRAY[gen_random_uuid(),gen_random_uuid(),gen_random_uuid()]; 
 ass uuid[]:=ARRAY[gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];
 ks uuid[]:=ARRAY[gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];
 ds uuid[]:=ARRAY[gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];
 os uuid[]:=ARRAY[gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];
 ts uuid[]:=ARRAY[gen_random_uuid(),gen_random_uuid(),gen_random_uuid()];
 m uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); k2 uuid:=gen_random_uuid(); cat uuid:=gen_random_uuid(); item uuid:=gen_random_uuid();
 j int; passes int:=0; r jsonb; denied boolean; token uuid; oid uuid; ticket uuid; note_at timestamptz;
BEGIN
 BEGIN
 INSERT INTO auth.users(id) SELECT unnest(ass||ks||ARRAY[m,c,k2]);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active)
 SELECT u,'QA assembly','assembly',true FROM unnest(ass) u
 UNION ALL SELECT u,'QA kitchen','burger_kitchen',true FROM unnest(ks||ARRAY[k2]) u
 UNION ALL SELECT m,'QA manager','manager',true
 UNION ALL SELECT c,'QA cashier','cashier',true
 ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_menu_categories(id,name) VALUES(cat,'QA برجر '||cat);
 INSERT INTO public.ff_menu_items(id,category_id,name,price) VALUES(item,cat,'QA burger',1000);
 FOR j IN 1..3 LOOP
 INSERT INTO public.ff_branches(id,code,name) VALUES(bs[j],'qa-'||bs[j],'QA branch '||j);
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(ks[j],bs[j]);
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(ds[j],'QA driver',bs[j]);
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot,driver_id,status)
 VALUES(os[j],-(1+floor(random()*1e12)::bigint),bs[j],'000000000',public.ff_business_date(now()),'QA',ds[j],'sent');
 INSERT INTO public.ff38_delivery_tasks(order_id,driver_id) VALUES(os[j],ds[j]);
 INSERT INTO public.ff49_cashier_receipts(order_id,received_by,invoiced_by,invoiced_at) VALUES(os[j],c,c,now());
 UPDATE public.ff38_delivery_tasks SET cashier_stage='printed' WHERE order_id=os[j];
 END LOOP;
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c,bs[1]),(k2,bs[1]);
 FOR j IN 1..3 LOOP
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 PERFORM public.ff62_assembly_set_branch(ass[j],bs[j],true);RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub',ass[j]::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff_v12_assembly_snapshot();
 IF r->'branch'->>'id' IS DISTINCT FROM bs[j]::text OR jsonb_array_length(r->'orders')<>1 OR r->'orders'->0->>'id' IS DISTINCT FROM os[j]::text THEN RAISE EXCEPTION 'Assembly isolation mismatch: %',j;END IF;passes:=passes+1;
 denied:=false;BEGIN PERFORM public.ff_v12_assembly_set_stage(os[(j%3)+1],'preparing','printed');EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Cross branch assembly accepted';END IF;passes:=passes+1;
 r:=public.ff_v12_assembly_set_stage(os[j],'preparing','printed');IF r->>'stage'<>'preparing' THEN RAISE EXCEPTION 'Preparation failed';END IF;
 denied:=false;BEGIN PERFORM public.ff_v12_assembly_set_stage(os[j],'preparing','printed');EXCEPTION WHEN SQLSTATE '40001' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Stale duplicate accepted';END IF;passes:=passes+1;
 PERFORM public.ff_v12_assembly_set_stage(os[j],'ready','preparing');
 PERFORM public.ff_v12_assembly_set_stage(os[j],'handed_over','ready');
 r:=public.ff_v12_assembly_snapshot();IF jsonb_array_length(r->'orders')<>0 THEN RAISE EXCEPTION 'Handed-over order still active';END IF;passes:=passes+1;
 -- Burger local ticket, optional invoice and notes.
 token:=gen_random_uuid();
 r:=public.ff_burger_send(bs[j],'local',null,'',jsonb_build_array(jsonb_build_object('id',item,'qty',2)),'QA notes',token);
 ts[j]:=(r->>'id')::uuid;
 r:=public.ff_burger_send(bs[j],'local',null,'',jsonb_build_array(jsonb_build_object('id',item,'qty',2)),'QA notes',token);
 IF r->>'id' IS DISTINCT FROM ts[j]::text OR r->>'duplicate' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Burger token replay failed';END IF;passes:=passes+1;
 RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub',ks[j]::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff_burger_list(150);
 IF jsonb_array_length(r)<>1 OR r->0->>'id' IS DISTINCT FROM ts[j]::text THEN RAISE EXCEPTION 'Kitchen isolation mismatch';END IF;passes:=passes+1;
 denied:=false;BEGIN PERFORM public.ff_burger_transition(ts[j],'ready');EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Unreceived ticket completed';END IF;passes:=passes+1;
 PERFORM public.ff_burger_transition(ts[j],'receive');
 denied:=false;BEGIN PERFORM public.ff_burger_transition(ts[j],'receive');EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Duplicate receive accepted';END IF;passes:=passes+1;
 denied:=false;BEGIN PERFORM public.ff_burger_transition(ts[j],'ready');EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Unconfirmed notes ignored';END IF;passes:=passes+1;
 PERFORM public.ff_burger_confirm_notes(ts[j]);PERFORM public.ff_burger_transition(ts[j],'ready');
 RESET ROLE;
 PERFORM set_config('request.jwt.claim.sub',ass[j]::text,true);SET LOCAL ROLE authenticated;
 PERFORM public.ff_burger_transition(ts[j],'skip');RESET ROLE;
 IF NOT EXISTS(SELECT 1 FROM public.ff_burger_tickets WHERE id=ts[j] AND status='acknowledged' AND kitchen_id=ks[j] AND notes_confirmed_by=ks[j] AND acknowledged_by=ass[j] AND sent_at<=accepted_at AND accepted_at<=ready_at AND ready_at<=acknowledged_at AND invoice_ref='') THEN RAISE EXCEPTION 'Lifecycle audit mismatch';END IF;passes:=passes+1;
 END LOOP;
 IF (SELECT count(*) FROM public.ff_audit_log WHERE action='assembly_stage_changed' AND entity_id IN(os[1]::text,os[2]::text,os[3]::text))<>9 THEN RAISE EXCEPTION 'Assembly audit mismatch';END IF;passes:=passes+1;
 IF has_function_privilege('authenticated','public.ff_v9_assembly_set_stage(uuid,text,text)','execute') THEN RAISE EXCEPTION 'Legacy bypass remains';END IF;passes:=passes+1;
 -- Revoked assembly authorization must block every burger entry point, even if a stale membership exists.
 UPDATE public.ff_v9_assembly_access SET enabled=false WHERE user_id=ass[1];
 PERFORM set_config('request.jwt.claim.sub',ass[1]::text,true);SET LOCAL ROLE authenticated;
 denied:=false;BEGIN PERFORM public.ff_burger_list(150);EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Revoked assembly could list';END IF;passes:=passes+1;
 denied:=false;BEGIN PERFORM public.ff_burger_send(bs[1],'local',null,'',jsonb_build_array(jsonb_build_object('id',item,'qty',1)),'',gen_random_uuid());EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Revoked assembly could send';END IF;passes:=passes+1;
 RESET ROLE;
 -- Cross branch and invalid quantity, then branch reassignment of original kitchen actor.
 PERFORM set_config('request.jwt.claim.sub',c::text,true);SET LOCAL ROLE authenticated;
 denied:=false;BEGIN PERFORM public.ff_burger_send(bs[2],'local',null,'',jsonb_build_array(jsonb_build_object('id',item,'qty',1)),'',gen_random_uuid());EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Cross branch send accepted';END IF;passes:=passes+1;
 denied:=false;BEGIN PERFORM public.ff_burger_send(bs[1],'local',null,'',jsonb_build_array(jsonb_build_object('id',item)),'',gen_random_uuid());EXCEPTION WHEN raise_exception THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Missing quantity accepted';END IF;passes:=passes+1;
 r:=public.ff_burger_send(bs[1],'delivery',os[1],'QA reference',jsonb_build_array(jsonb_build_object('id',item,'qty',1)),'QA notes',gen_random_uuid());ticket:=(r->>'id')::uuid;
 PERFORM set_config('request.jwt.claim.sub',ks[1]::text,true);PERFORM public.ff_burger_transition(ticket,'receive');
 PERFORM set_config('request.jwt.claim.sub',k2::text,true);
 denied:=false;BEGIN PERFORM public.ff_burger_confirm_notes(ticket);EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Other kitchen staff confirmed notes';END IF;passes:=passes+1;
 RESET ROLE;
 UPDATE public.ff_user_branches SET branch_id=bs[2] WHERE user_id=ks[1];
 PERFORM set_config('request.jwt.claim.sub',ks[1]::text,true);SET LOCAL ROLE authenticated;
 denied:=false;BEGIN PERFORM public.ff_burger_confirm_notes(ticket);EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Moved kitchen staff confirmed old branch';END IF;passes:=passes+1;
 RESET ROLE;
 UPDATE public.ff_orders SET status='delivered' WHERE id=os[1];
 PERFORM set_config('request.jwt.claim.sub',c::text,true);SET LOCAL ROLE authenticated;
 denied:=false;BEGIN PERFORM public.ff_burger_send(bs[1],'delivery',os[1],'',jsonb_build_array(jsonb_build_object('id',item,'qty',1)),'',gen_random_uuid());EXCEPTION WHEN raise_exception THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Delivered order accepted new burger ticket';END IF;passes:=passes+1;
 RESET ROLE;
 IF (SELECT count(*) FROM public.ff_burger_tickets WHERE branch_id=ANY(bs))<>4 THEN RAISE EXCEPTION 'Duplicate/invalid ticket persisted';END IF;passes:=passes+1;
 RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF passes<>40 OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id=ANY(bs)) OR EXISTS(SELECT 1 FROM auth.users WHERE id=ANY(ass||ks||ARRAY[m,c,k2])) THEN RAISE EXCEPTION 'Incomplete coverage or rollback: %',passes;END IF;
END $qa$;
SELECT 'PASS A04: 40 assertions across three branches, assembly delegation and stages, burger lifecycle and replay, branch/role boundaries, notes, invalid/terminal inputs, audit; rollback' AS result;