-- FIX-11 / QA-14: order-first locks and terminal-state guard for cashier actions.
-- Preserve optional MicroPOS reference and existing role checks.
do $migration$
declare f regprocedure; src text; needle text; replacement text;
begin
 foreach f in array array[
 'public.ff49_cashier_receive(uuid)'::regprocedure,
 'public.ff49_cashier_invoice(uuid,text)'::regprocedure,
 'public.ff38_cashier_set_stage(uuid,text)'::regprocedure
 ] loop
  src:=pg_get_functiondef(f);
  needle:='FOR UPDATE OF T';
  if strpos(upper(src),needle)=0 then raise exception 'Unexpected cashier lock definition: %',f;end if;
  -- The earlier SELECT joins both records; explicitly lock the order before locking the task.
  if f='public.ff38_cashier_set_stage(uuid,text)'::regprocedure then
   needle:='select o.branch_id,t.cashier_stage,o.status,t.delivered_at into';
  else
   needle:='SELECT o.branch_id,t.cashier_stage INTO';
  end if;
  if strpos(src,needle)=0 then raise exception 'Unexpected cashier select: %',f;end if;
  replacement:=$body$
  PERFORM 1 FROM public.ff_orders WHERE id=p_order FOR UPDATE;
  $body$||needle;
  src:=replace(src,needle,replacement);
  if f='public.ff49_cashier_receive(uuid)'::regprocedure or f='public.ff49_cashier_invoice(uuid,text)'::regprocedure then
   needle:='IF v_stage<>';
   if strpos(src,needle)=0 then raise exception 'Unexpected cashier stage guard: %',f;end if;
   replacement:=$body$
   IF EXISTS(SELECT 1 FROM public.ff_orders o JOIN public.ff38_delivery_tasks t ON t.order_id=o.id
       WHERE o.id=p_order AND (o.order_type<>'delivery' OR o.status IN ('cancelled','delivered','reservation_completed') OR t.delivered_at IS NOT NULL))
   THEN RAISE EXCEPTION 'الطلب ملغي أو منتهٍ؛ لا يمكن استلامه أو اعتماد فاتورته'; END IF;
   $body$||needle;
   src:=replace(src,needle,replacement);
  end if;
  execute src;
 end loop;
end $migration$;
