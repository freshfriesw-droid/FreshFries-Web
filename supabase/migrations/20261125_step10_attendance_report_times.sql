-- Preserve the existing clipped attendance interval and hours. Also expose actual recorded entry/exit.
DO $migration$
DECLARE d text; a text; z text;
BEGIN
d:=pg_get_functiondef('ff_private.a10_report_core(date,date,uuid,uuid,uuid,text,text,text)'::regprocedure);
a:=$s$SELECT w.driver_id,sh.report_day,greatest(w.checked_in_at,sh.start_time) AS begin_at,$s$;
z:=$s$SELECT w.driver_id,sh.report_day,w.checked_in_at AS actual_in,w.checked_out_at AS actual_out,greatest(w.checked_in_at,sh.start_time) AS begin_at,$s$;
IF (length(d)-length(replace(d,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'attendance pieces anchor';END IF;d:=replace(d,a,z);
a:=$s$SELECT p.driver_id,p.report_day,p.begin_at,p.end_at,$s$;z:=$s$SELECT p.driver_id,p.report_day,p.begin_at,p.end_at,p.actual_in,p.actual_out,$s$;
IF (length(d)-length(replace(d,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'attendance net anchor';END IF;d:=replace(d,a,z);
a:=$s$min(n.begin_at) AS first_checkin,max(n.end_at) AS last_checkout,$s$;
z:=$s$min(n.begin_at) AS first_checkin,max(n.end_at) AS last_checkout,
    min(n.actual_in) AS actual_first_checkin, CASE WHEN bool_or(n.actual_out IS NULL) THEN NULL ELSE max(n.actual_out) END AS actual_last_checkout,
    bool_or(n.actual_out IS NULL) AS open_session,$s$;
IF (length(d)-length(replace(d,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'attendance aggregation anchor';END IF;d:=replace(d,a,z);
EXECUTE d;
END $migration$;
