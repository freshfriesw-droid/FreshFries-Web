-- FFL Reports: close existing supervisor report leaks while preserving manager/CS access.
DO $patch$
DECLARE s text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO s FROM pg_proc p
 WHERE p.pronamespace='public'::regnamespace AND p.proname='ff40_operations_report';
 IF s IS NULL OR position(
  'v_role IN (''manager'',''customer_service'',''supervisor'') OR (v_role=''cashier''' in s)=0
 THEN RAISE EXCEPTION 'Operations report authorization source changed';END IF;
 s:=replace(s,
  'v_role IN (''manager'',''customer_service'',''supervisor'') OR (v_role=''cashier''',
  'v_role IN (''manager'',''customer_service'') OR
   (v_role=''supervisor'' AND EXISTS (SELECT 1 FROM public.ff_user_branches ub
    WHERE ub.user_id=v_uid AND ub.branch_id=o.branch_id)) OR (v_role=''cashier''');
 EXECUTE s;
 SELECT pg_get_functiondef(p.oid) INTO s FROM pg_proc p
 WHERE p.pronamespace='public'::regnamespace AND p.proname='ff40_operations_alerts';
 IF s IS NULL OR position('v_role IN (''manager'',''customer_service'',''supervisor'') OR EXISTS(' in s)=0
 THEN RAISE EXCEPTION 'Operations alerts authorization source changed';END IF;
 s:=replace(s,'v_role IN (''manager'',''customer_service'',''supervisor'') OR EXISTS(',
  'v_role IN (''manager'',''customer_service'') OR EXISTS(');
 EXECUTE s;
 SELECT pg_get_functiondef(p.oid) INTO s FROM pg_proc p
 WHERE p.pronamespace='public'::regnamespace AND p.proname='ff_luxe_rating_summary_period';
 IF s IS NULL OR position('v_role in (''manager'',''supervisor'') or (v_role=''driver'' and d.id=v_driver)' in s)=0
 THEN RAISE EXCEPTION 'Rating summary authorization source changed';END IF;
 s:=replace(s,
  'v_role in (''manager'',''supervisor'') or (v_role=''driver'' and d.id=v_driver)',
  'v_role=''manager'' or (v_role=''supervisor'' and exists (
     select 1 from public.ff_user_branches ub
     where ub.user_id=auth.uid() and ub.branch_id=d.branch_id))
    or (v_role=''driver'' and d.id=v_driver)');
 EXECUTE s;
END $patch$;
