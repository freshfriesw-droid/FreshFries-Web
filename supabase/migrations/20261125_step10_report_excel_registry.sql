-- STEP10: add a separate protected Excel control group.
-- Existing group identities and lengths are preserved, so saved designs remain valid.
DO $migration$
DECLARE f regprocedure; d text; old_key text:='"report_more_controls":{"screen":"reports"'; new_key text:='"report_excel_controls":{"screen":"reports","keys":["ff76Excel"],"styleOnly":true},' || old_key;
BEGIN
 FOREACH f IN ARRAY ARRAY['ff_private.a07_valid_elements(jsonb,text)'::regprocedure,'ff_private.a09_merge_elements(text,jsonb,jsonb,jsonb,text[])'::regprocedure] LOOP
  d:=pg_get_functiondef(f);
  IF strpos(d,new_key)>0 THEN CONTINUE; END IF;
  IF (length(d)-length(replace(d,old_key,'')))/length(old_key)<>1 THEN RAISE EXCEPTION 'Unexpected report control registry %',f;END IF;
  EXECUTE replace(d,old_key,new_key);
 END LOOP;
END $migration$;
INSERT INTO public.ff_content_catalog(key,screen,label,original) VALUES ('reports.excel','reports','زر تصدير Excel','تصدير Excel (.xlsx)') ON CONFLICT(key) DO NOTHING;
