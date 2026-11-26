SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';
CREATE INDEX IF NOT EXISTS ff_order_items_order_id_idx ON public.ff_order_items USING btree (order_id);
