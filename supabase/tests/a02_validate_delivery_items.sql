-- Negative tests at the actual shared creation boundary. Every call must
-- reject before insertion. The exception block rolls back even unexpected writes.
DO $qa$
DECLARE v_manager uuid; v_branch uuid; v_case record; v_previous text; v_error text;
BEGIN
 SELECT user_id INTO v_manager FROM public.ff_profiles WHERE role='manager' AND active LIMIT 1;
 SELECT id INTO v_branch FROM public.ff_branches WHERE active LIMIT 1;
 IF v_manager IS NULL OR v_branch IS NULL THEN RAISE EXCEPTION 'QA context unavailable'; END IF;
 v_previous:=current_setting('request.jwt.claim.sub',true);
 PERFORM set_config('request.jwt.claim.sub',v_manager::text,true);
 FOR v_case IN SELECT * FROM (VALUES
  ('SQL NULL',NULL::jsonb,0::numeric),
  ('JSON null','null'::jsonb,0::numeric),
  ('object','{}'::jsonb,0::numeric),
  ('empty','[]'::jsonb,0::numeric),
  ('quantity NaN','[{"name":"QA","qty":"NaN","price":100}]'::jsonb,0::numeric),
  ('quantity infinity','[{"name":"QA","qty":"Infinity","price":100}]'::jsonb,0::numeric),
  ('price NaN','[{"name":"QA","qty":1,"price":"NaN"}]'::jsonb,0::numeric),
  ('price infinity','[{"name":"QA","qty":1,"price":"Infinity"}]'::jsonb,0::numeric),
  ('missing price','[{"name":"QA","qty":1}]'::jsonb,0::numeric),
  ('zero quantity','[{"name":"QA","qty":0,"price":100}]'::jsonb,0::numeric),
  ('fee NaN','[{"name":"QA","qty":1,"price":100}]'::jsonb,'NaN'::numeric),
  ('fee infinity','[{"name":"QA","qty":1,"price":100}]'::jsonb,'Infinity'::numeric),
  ('fee NULL','[{"name":"QA","qty":1,"price":100}]'::jsonb,NULL::numeric)
 ) AS t(label,items,fee) LOOP
  v_error:=NULL;
  BEGIN
   PERFORM public.ff38_create_delivery_order(v_branch,'700000000','QA area',v_case.items,v_case.fee,'A02 negative test');
   RAISE EXCEPTION 'Unexpected acceptance: %',v_case.label USING ERRCODE='P0001';
  EXCEPTION WHEN SQLSTATE '22023' THEN v_error:=SQLERRM;
  END;
  IF v_error NOT IN ('راجع الأصناف وأجرة التوصيل','الأصناف أو الأسعار غير صالحة') OR v_error IS NULL THEN
   RAISE EXCEPTION 'Invalid test result: %',v_case.label;
  END IF;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',coalesce(v_previous,''),true);
END $qa$;
