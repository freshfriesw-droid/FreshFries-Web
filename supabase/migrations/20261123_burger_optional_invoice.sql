-- Fresh Fries LUXE burger ordering — invoice number is optional.
-- Additive, preserves all existing burger tickets and status history.
-- Keeps NOT NULL invoice_ref; empty string represents an omitted invoice number.
ALTER TABLE public.ff_burger_tickets
  ALTER COLUMN invoice_ref SET DEFAULT '';
ALTER TABLE public.ff_burger_tickets
  DROP CONSTRAINT ff_burger_tickets_invoice_ref_check;
ALTER TABLE public.ff_burger_tickets
  ADD CONSTRAINT ff_burger_tickets_invoice_ref_check
  CHECK (length(btrim(invoice_ref)) <= 80);

DO $migration$
DECLARE
 v_fn text;
 v_before text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO v_fn
 FROM pg_proc p
 WHERE p.pronamespace='public'::regnamespace
   AND p.proname='ff_burger_send'
   AND pg_get_function_identity_arguments(p.oid) LIKE 'p_branch uuid%';
 IF v_fn IS NULL THEN
   RAISE EXCEPTION 'ff_burger_send signature not found';
 END IF;
 v_before := $old$IF length(btrim(coalesce(p_invoice,''))) NOT BETWEEN 1 AND 80
 THEN RAISE EXCEPTION 'اكتب رقم فاتورة الكاشير المرتبطة بالطلب (80 حرفًا كحد أقصى)';END IF;$old$;
 IF position(v_before in v_fn)=0 THEN
   RAISE EXCEPTION 'ff_burger_send original invoice validation changed; stop migration';
 END IF;
 v_fn := replace(v_fn,v_before,$new$IF length(btrim(coalesce(p_invoice,''))) > 80
 THEN RAISE EXCEPTION 'رقم الفاتورة أطول من 80 حرفًا';END IF;$new$);
 IF position('p_delivery_order,btrim(p_invoice),auth.uid()' in v_fn)=0 THEN
   RAISE EXCEPTION 'ff_burger_send invoice insert signature changed';
 END IF;
 v_fn:=replace(v_fn,'p_delivery_order,btrim(p_invoice),auth.uid()',
   $new$p_delivery_order,btrim(coalesce(p_invoice,'')),auth.uid()$new$);
 EXECUTE v_fn;

 SELECT pg_get_functiondef(p.oid) INTO v_fn
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='ff_private' AND p.proname='ff_burger_event_and_notify';
 IF v_fn IS NULL THEN RAISE EXCEPTION 'Burger push trigger missing'; END IF;
 v_before := $old$'فاتورة #'||NEW.invoice_ref||' · '||v_message$old$;
 IF position(v_before in v_fn)=0 THEN RAISE EXCEPTION 'Burger push label changed; stop migration';END IF;
 v_fn:=replace(v_fn,v_before,
   $new$(CASE WHEN btrim(NEW.invoice_ref)<>'' THEN
    'فاتورة #'||NEW.invoice_ref ELSE 'طلب برجر بدون رقم فاتورة' END)||' · '||v_message$new$);
 EXECUTE v_fn;
END $migration$;
