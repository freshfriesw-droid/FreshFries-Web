-- A04 item notes, push recipients, presence and financial isolation. Synthetic actors only; rollback.
DO $qa$
DECLARE b uuid:=gen_random_uuid(); b2 uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); k uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); ar uuid:=gen_random_uuid(); cat uuid:=gen_random_uuid(); item uuid:=gen_random_uuid(); ticket uuid; r jsonb; blocked boolean; passes int:=0;
BEGIN
 BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-'||b,'QA notes'),(b2,'qa-'||b2,'QA other');
 INSERT INTO auth.users(id) VALUES(a),(ar),(c),(k),(m);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(a,'QA assembly','assembly',true),(ar,'QA revoked','assembly',true),(c,'QA cashier','cashier',true),(k,'QA kitchen','burger_kitchen',true),(m,'QA manager','manager',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(a,b),(ar,b),(c,b),(k,b);
 INSERT INTO public.ff_v9_assembly_access(user_id,branch_id,enabled,granted_by) VALUES(a,b,true,m),(ar,b,false,m);
 INSERT INTO public.ff_menu_categories(id,name) VALUES(cat,'QA برجر '||cat);
 INSERT INTO public.ff_menu_items(id,category_id,name,price) VALUES(item,cat,'QA burger',1000);
 PERFORM set_config('request.jwt.claim.sub',c::text,true);SET LOCAL ROLE authenticated;
 blocked:=false;
 BEGIN PERFORM public.ff_burger_send(b,'local',null,'',jsonb_build_array(jsonb_build_object('id',item,'qty',1,'item_notes',repeat('x',301))),'',gen_random_uuid());EXCEPTION WHEN raise_exception THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Long item note accepted';END IF;passes:=passes+1;
 r:=public.ff_burger_send(b,'local',null,'',jsonb_build_array(jsonb_build_object('id',item,'qty',1,'item_notes',' QA no onion ')),'',gen_random_uuid());
 ticket:=(r->>'id')::uuid;
 RESET ROLE;
 IF NOT EXISTS(SELECT 1 FROM public.ff_burger_tickets WHERE id=ticket AND items->0->>'item_notes'='QA no onion' AND notes='' AND invoice_ref='' AND delivery_order_id IS NULL) THEN RAISE EXCEPTION 'Item note not stored independently';END IF;passes:=passes+1;
 PERFORM set_config('request.jwt.claim.sub',k::text,true);SET LOCAL ROLE authenticated;
 PERFORM public.ff_burger_presence_ping(true);
 PERFORM public.ff_burger_transition(ticket,'receive');
 blocked:=false;BEGIN PERFORM public.ff_burger_transition(ticket,'ready');EXCEPTION WHEN SQLSTATE '42501' THEN blocked:=true;END;
 IF NOT blocked THEN RAISE EXCEPTION 'Item note bypass';END IF;passes:=passes+1;
 PERFORM public.ff_burger_confirm_notes(ticket);
 PERFORM public.ff_burger_transition(ticket,'ready');
 RESET ROLE;
 IF NOT EXISTS(SELECT 1 FROM public.ff_burger_tickets WHERE id=ticket AND status='ready' AND notes_confirmed_by=k AND ready_at>=notes_confirmed_at) THEN RAISE EXCEPTION 'Item note confirmation missing';END IF;passes:=passes+1;
 IF (SELECT count(*) FROM public.ff_push_jobs WHERE event_key='burger:ready:'||ticket::text AND user_id IN(a,c))<>2
 OR EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE event_key='burger:ready:'||ticket::text AND user_id=ar) THEN RAISE EXCEPTION 'Ready notification scope wrong';END IF;passes:=passes+1;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff_burger_online_status();
 IF r->0->>'online_count'<>'1' THEN RAISE EXCEPTION 'Online presence missing: %',r;END IF;passes:=passes+1;
 RESET ROLE;
 UPDATE public.ff_user_branches SET branch_id=b2 WHERE user_id=k;
 PERFORM set_config('request.jwt.claim.sub',c::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff_burger_online_status();
 IF r->0->>'online_count'<>'0' THEN RAISE EXCEPTION 'Moved kitchen still counted: %',r;END IF;passes:=passes+1;
 RESET ROLE;
 IF (SELECT count(*) FROM public.ff_burger_ticket_events WHERE ticket_id=ticket)<>3 THEN RAISE EXCEPTION 'Ticket audit event count';END IF;passes:=passes+1;
 IF EXISTS(SELECT 1 FROM public.ff_orders WHERE branch_id IN(b,b2)) THEN RAISE EXCEPTION 'Kitchen ticket created financial/order records';END IF;passes:=passes+1;
 RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF passes<>9 OR EXISTS(SELECT 1 FROM public.ff_branches WHERE id IN(b,b2)) OR EXISTS(SELECT 1 FROM public.ff_burger_tickets WHERE id=ticket) THEN RAISE EXCEPTION 'Incomplete QA/rollback: %',passes;END IF;
END $qa$;
SELECT 'PASS A04 item notes: nine assertions, per-item notes and confirmation, push scope, presence revocation, audit and no order mutation; rollback' AS result;