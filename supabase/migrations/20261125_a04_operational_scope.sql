-- A04: preserve legacy RPC implementations while tightening all entry points.
DO $migration$
DECLARE f regprocedure; src text; marker text; patch text;
BEGIN
 f:='public.ff_v9_assembly_set_stage(uuid,text,text)'::regprocedure;
 src:=pg_get_functiondef(f);
 marker:='SELECT o.branch_id,t.cashier_stage,t.driver_id,o.driver_id,t.phase,o.status';
 IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected assembly lock source';END IF;
 src:=replace(src,marker,$body$
 IF v_role <> 'manager' AND (v_role <> 'assembly' OR public.ff_v12_assembly_me()->>'is_assembly' IS DISTINCT FROM 'true') THEN
 RAISE EXCEPTION 'صلاحية التجميع غير متاحة' USING ERRCODE='42501';END IF;
 PERFORM 1 FROM public.ff_orders WHERE id=p_order FOR UPDATE;
 $body$||marker);
 src:=replace(src,'FOR UPDATE OF t,o','FOR UPDATE OF t');
 src:=replace(src,'''cancelled'',''canceled'',''closed'',''delivered''','''cancelled'',''canceled'',''closed'',''delivered'',''reservation_completed''');
 EXECUTE src;
 f:='public.ff_v12_assembly_snapshot()'::regprocedure;
 src:=pg_get_functiondef(f);
 marker:=$body$'name',i.item_name,'qty',i.quantity$body$;
 IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected assembly item projection';END IF;
 EXECUTE replace(src,marker,marker||$body$,'item_notes',i.item_notes$body$);
 f:='public.ff_burger_my_branch()'::regprocedure;
 src:=pg_get_functiondef(f);
 marker:='SELECT coalesce(jsonb_agg';
 IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected burger branch function';END IF;
 EXECUTE replace(src,marker,$body$
 IF v_role='assembly' AND public.ff_v12_assembly_me()->>'is_assembly' IS DISTINCT FROM 'true' THEN
 RAISE EXCEPTION 'صلاحية نقطة التجميع غير متاحة' USING ERRCODE='42501';END IF;
 $body$||marker);
 FOREACH f IN ARRAY ARRAY[
 'public.ff_burger_list(integer)'::regprocedure,
 'public.ff_burger_online_status()'::regprocedure,
 'public.ff_burger_presence_ping(boolean)'::regprocedure,
 'public.ff_burger_send(uuid,text,uuid,text,jsonb,text,uuid)'::regprocedure,
 'public.ff_burger_transition(uuid,text)'::regprocedure,
 'public.ff_burger_confirm_notes(uuid)'::regprocedure
 ] LOOP
 src:=pg_get_functiondef(f);
 marker:='BEGIN';
 IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected burger source %',f;END IF;
 src:=overlay(src placing E'BEGIN\n PERFORM public.ff_burger_my_branch();' from strpos(src,marker) for length(marker));
 IF f='public.ff_burger_list(integer)'::regprocedure THEN
  src:=replace(src,'WHERE EXISTS(SELECT 1 FROM public.ff_user_branches','WHERE b.active AND EXISTS(SELECT 1 FROM public.ff_user_branches');
 ELSIF f='public.ff_burger_transition(uuid,text)'::regprocedure THEN
  src:=replace(src,'FROM public.ff_user_branches WHERE user_id=auth.uid() AND branch_id=v_row.branch_id',
   'FROM public.ff_user_branches ub JOIN public.ff_branches b ON b.id=ub.branch_id AND b.active WHERE ub.user_id=auth.uid() AND ub.branch_id=v_row.branch_id');
 ELSIF f='public.ff_burger_confirm_notes(uuid)'::regprocedure THEN
  marker:='IF length(btrim(v_ticket.notes))=0';
  IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected note guard';END IF;
  src:=replace(src,marker,$body$
   IF NOT EXISTS(SELECT 1 FROM public.ff_user_branches ub JOIN public.ff_branches b ON b.id=ub.branch_id AND b.active
   WHERE ub.user_id=auth.uid() AND ub.branch_id=v_ticket.branch_id) THEN
   RAISE EXCEPTION 'طلب يخص فرعًا آخر' USING ERRCODE='42501';END IF;
  $body$||marker);
 ELSIF f='public.ff_burger_send(uuid,text,uuid,text,jsonb,text,uuid)'::regprocedure THEN
  src:=replace(src,'IF p_order_kind NOT IN','IF p_order_kind IS NULL OR p_order_kind NOT IN');
  src:=replace(src,'''cancelled'',''canceled'',''closed''','''cancelled'',''canceled'',''closed'',''delivered'',''reservation_completed''');
  src:=replace(src,$body$(v_item->>'qty') !~$body$,$body$coalesce(v_item->>'qty','') !~$body$);
 END IF;
 EXECUTE src;
 END LOOP;
END $migration$;
-- Only the current scoped wrapper may invoke the old assembly implementation.
REVOKE EXECUTE ON FUNCTION public.ff_v9_assembly_set_stage(uuid,text,text) FROM PUBLIC,anon,authenticated;
