-- STEP11: preserve the delivery evidence used by message history.
-- The established 30-day cleanup remains unchanged for completed operational alerts.
DO $migration$
DECLARE d text; a text; z text;
BEGIN
 d:=pg_get_functiondef('ff_private.push_cron_tick()'::regprocedure);
 a:=$s$where status in ('sent','failed')$s$;
 z:=$s$where kind <> 'message' and status in ('sent','failed')$s$;
 IF (length(d)-length(replace(d,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'Unexpected cleanup anchor';END IF;
 EXECUTE replace(d,a,z);
END $migration$;