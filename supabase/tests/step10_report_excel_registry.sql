DO $qa$
DECLARE patch jsonb:='{"report_excel_controls":[{"key":"ff76Excel","shape":"round","size":"normal","align":"center"}]}'; legacy jsonb;
BEGIN
 SELECT jsonb_build_object('report_more_controls',jsonb_agg(jsonb_build_object('key',x,'shape','round','size','normal','align','center') ORDER BY ord)) INTO legacy FROM unnest(ARRAY['ff76Close','ff76Today','ff76Yesterday','ff76Seven','ff76Thirty','ff76CSV','ff76SavePreset','ff76UsePreset','ffA10GrantSave','ff76SaveApproval']) WITH ORDINALITY t(x,ord);
 IF NOT ff_private.a07_valid_elements(patch,'reports') OR NOT ff_private.a07_valid_elements(legacy,'reports') THEN RAISE EXCEPTION 'Excel or legacy registry rejected';END IF;
 IF ff_private.a07_valid_elements(patch,'finance') OR ff_private.a07_valid_elements(jsonb_set(patch,'{report_excel_controls,0,hidden}','true'),'reports') THEN RAISE EXCEPTION 'Excel protected action bypass';END IF;
 IF ff_private.a09_merge_elements('reports',patch,patch,jsonb_set(patch,'{report_excel_controls,0,align}','"end"'),ARRAY['buttons']) IS NOT NULL THEN RAISE EXCEPTION 'delegated alignment bypass';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.ff_content_catalog WHERE key='reports.excel' AND screen='reports' AND original='تصدير Excel (.xlsx)') OR NOT public.ff83_valid_content('reports.excel','تصدير إكسل') THEN RAISE EXCEPTION 'Excel content registry';END IF;
END $qa$;
SELECT 'PASS STEP10: Excel registry, legacy compatibility, scope, mandatory action, delegation, content validation' AS result;
