-- Validate existing approved customer-edit reason constraint without changing rows or its expression.
ALTER TABLE public.ff_order_customer_edits VALIDATE CONSTRAINT ff_order_customer_edit_reason_required;
