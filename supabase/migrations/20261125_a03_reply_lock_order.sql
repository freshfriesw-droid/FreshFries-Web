-- FIX-09 / QA-13. Acquire order and branch locks before the offer row.
-- Previously reply locked the offer before the order, opposite to dispatch/cancellation.
-- The initial read is only for locating the locks; recheck ownership and status after locking.
do $migration$
declare
 src text:=pg_get_functiondef('public.ff38_driver_reply(uuid,boolean,text)'::regprocedure);
 old_decl text:='v_driver uuid;v_offer public.ff38_dispatch_offers%ROWTYPE;v_result jsonb;';
 new_decl text:='v_driver uuid;v_offer public.ff38_dispatch_offers%ROWTYPE;v_result jsonb;v_order_id uuid;v_branch uuid;';
 old_read text:='SELECT * INTO v_offer FROM public.ff38_dispatch_offers WHERE id=p_offer FOR UPDATE;';
 new_read text:=$body$
  IF p_accept IS NULL THEN RAISE EXCEPTION 'حدد قبول العرض أو رفضه'; END IF;
  SELECT order_id INTO v_order_id FROM public.ff38_dispatch_offers WHERE id=p_offer AND driver_id=v_driver;
  IF v_order_id IS NULL THEN RAISE EXCEPTION 'العرض غير متاح'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-o-'||v_order_id::text));
  SELECT branch_id INTO v_branch FROM public.ff_orders WHERE id=v_order_id FOR UPDATE;
  IF v_branch IS NULL THEN RAISE EXCEPTION 'العرض غير متاح'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-branch-rr-'||v_branch::text));
  SELECT * INTO v_offer FROM public.ff38_dispatch_offers WHERE id=p_offer AND order_id=v_order_id FOR UPDATE;
$body$;
begin
 if strpos(src,old_decl)=0 or strpos(src,old_read)=0 then
  raise exception 'Unexpected driver reply source; inspect before applying';
 end if;
 execute replace(replace(src,old_decl,new_decl),old_read,new_read);
end $migration$;
revoke execute on function public.ff38_driver_reply(uuid,boolean,text) from public,anon;
grant execute on function public.ff38_driver_reply(uuid,boolean,text) to authenticated;
