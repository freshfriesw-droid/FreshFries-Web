-- UI-07: store item notes separately and require confirmation for either type of note.
CREATE OR REPLACE FUNCTION ff_private.a04_burger_has_notes(p_notes text,p_items jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $body$
 SELECT length(btrim(coalesce(p_notes,'')))>0 OR EXISTS(
 SELECT 1 FROM jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) i
 WHERE length(btrim(coalesce(i->>'item_notes','')))>0);
$body$;
REVOKE EXECUTE ON FUNCTION ff_private.a04_burger_has_notes(text,jsonb) FROM PUBLIC,anon,authenticated;
DO $migration$
DECLARE f regprocedure;src text;marker text;
BEGIN
 f:='public.ff_burger_send(uuid,text,uuid,text,jsonb,text,uuid)'::regprocedure;
 src:=pg_get_functiondef(f);
 marker:=$body$v_checked:=v_checked||jsonb_build_array(jsonb_build_object('id',v_item_id,'name',v_name,'qty',v_qty));$body$;
 IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected burger item projection';END IF;
 EXECUTE replace(src,marker,$body$
 IF (v_item ? 'item_notes' AND jsonb_typeof(v_item->'item_notes') NOT IN ('string','null'))
 OR length(btrim(coalesce(v_item->>'item_notes','')))>300 THEN RAISE EXCEPTION 'ملاحظة الصنف غير صالحة أو تتجاوز 300 حرف';END IF;
 v_checked:=v_checked||jsonb_build_array(jsonb_build_object('id',v_item_id,'name',v_name,'qty',v_qty,'item_notes',nullif(btrim(coalesce(v_item->>'item_notes','')),'')));
 $body$);
 f:='public.ff_burger_transition(uuid,text)'::regprocedure;
 src:=pg_get_functiondef(f);marker:='length(btrim(v_row.notes))>0';
 IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected transition notes guard';END IF;
 EXECUTE replace(src,marker,'ff_private.a04_burger_has_notes(v_row.notes,v_row.items)');
 f:='public.ff_burger_confirm_notes(uuid)'::regprocedure;
 src:=pg_get_functiondef(f);marker:='length(btrim(v_ticket.notes))=0';
 IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected confirm notes guard';END IF;
 EXECUTE replace(src,marker,'NOT ff_private.a04_burger_has_notes(v_ticket.notes,v_ticket.items)');
 f:='ff_private.ff_burger_ready_notes_guard()'::regprocedure;
 src:=pg_get_functiondef(f);marker:='length(btrim(NEW.notes))>0';
 IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected trigger notes guard';END IF;
 EXECUTE replace(src,marker,'ff_private.a04_burger_has_notes(NEW.notes,NEW.items)');
 -- Existing push pipeline: include granted assembly recipients on ready, keep actual branch membership.
 f:='ff_private.ff_burger_event_and_notify()'::regprocedure;
 src:=pg_get_functiondef(f);marker:=$body$(v_kind='ready' AND p.role='cashier')$body$;
 IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected burger notification recipients';END IF;
 EXECUTE replace(src,marker,$body$(v_kind='ready' AND (p.role='cashier' OR (p.role='assembly' AND EXISTS(
 SELECT 1 FROM public.ff_v9_assembly_access a WHERE a.user_id=p.user_id AND a.branch_id=NEW.branch_id AND a.enabled)
 AND (SELECT count(*) FROM public.ff_user_branches x JOIN public.ff_branches b ON b.id=x.branch_id AND b.active WHERE x.user_id=p.user_id)=1)))$body$);
 f:='public.ff_burger_online_status()'::regprocedure;
 src:=pg_get_functiondef(f);marker:='WHERE t.branch_id=b.id';
 IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected burger online status';END IF;
 EXECUTE replace(src,marker,'WHERE t.branch_id=b.id AND EXISTS(SELECT 1 FROM public.ff_user_branches current_branch WHERE current_branch.user_id=t.user_id AND current_branch.branch_id=t.branch_id) AND (SELECT count(*) FROM public.ff_user_branches current_branch JOIN public.ff_branches current_b ON current_b.id=current_branch.branch_id AND current_b.active WHERE current_branch.user_id=t.user_id)=1');
END $migration$;
