-- Authorization hardening: supervisor sees only mapped branch orders, alerts and ratings.
DO $patch$
DECLARE s text;
BEGIN
 SELECT pg_get_functiondef(oid) INTO s FROM pg_proc
 WHERE pronamespace='public'::regnamespace AND proname='ff40_operations_report';
 IF s IS NULL OR position('v_role IN (''manager'',''customer_service'',''supervisor'')' in s)=0 THEN
  RAISE EXCEPTION 'Report scope anchor changed';END IF;
 s:=replace(s,
  'v_role IN (''manager'',''customer_service'',''supervisor'')',
  'v_role IN (''manager'',''customer_service'') OR
   (v_role=''supervisor'' AND EXISTS (
     SELECT 1 FROM public.ff_user_branches ub
     WHERE ub.user_id=v_uid AND ub.branch_id=o.branch_id))');
 EXECUTE s;
 SELECT pg_get_functiondef(oid) INTO s FROM pg_proc
 WHERE pronamespace='public'::regnamespace AND proname='ff40_operations_alerts';
 IF s IS NULL OR position('v_role IN (''manager'',''customer_service'',''supervisor'')' in s)=0 THEN
  RAISE EXCEPTION 'Alerts scope anchor changed';END IF;
 s:=replace(s,
  'v_role IN (''manager'',''customer_service'',''supervisor'')',
  'v_role IN (''manager'',''customer_service'')');
 EXECUTE s;
 SELECT pg_get_functiondef(oid) INTO s FROM pg_proc
 WHERE pronamespace='public'::regnamespace AND proname='ff_luxe_rating_summary_period';
 IF s IS NULL OR position(
  'v_role in (''manager'',''supervisor'') or (v_role=''driver'' and d.id=v_driver)' in s)=0
 THEN RAISE EXCEPTION 'Ratings scope anchor changed';END IF;
 s:=replace(s,
  'v_role in (''manager'',''supervisor'') or (v_role=''driver'' and d.id=v_driver)',
  'v_role=''manager'' or
   (v_role=''supervisor'' AND EXISTS (
     SELECT 1 FROM public.ff_user_branches ub
      WHERE ub.user_id=auth.uid() AND ub.branch_id=d.branch_id))
   or (v_role=''driver'' and d.id=v_driver)');
 EXECUTE s;
END $patch$;
