-- Preserve historical audit entries. Require a reason on subsequent corrections.
ALTER TABLE public.ff_order_customer_edits
  ADD CONSTRAINT ff_order_customer_edit_reason_required
  CHECK (reason ~ '[^[:space:]]') NOT VALID;
