BEGIN;
DO $qa$
DECLARE spec jsonb:='{"dashboard_filter_controls":{"screen":"dashboard","keys":["ffx-branch","ffx-kpi-reload","ffx-open-alerts"],"styleOnly":true},"dashboard_shell_controls":{"screen":"dashboard","keys":["ffx-menu","ffx-refresh","ffx-bell","ffx-theme-toggle","ffx-options","ffx-drawer-close"],"styleOnly":true},"dashboard_quick_controls":{"screen":"dashboard","keys":["ff2-close","ff2-search","ff3-close"],"styleOnly":true},"preferences_appearance":{"screen":"system","keys":["ffx-pref-close","ffx-density","ffx-auto","ffx-motion","ffx-fast","ffx-reset"],"styleOnly":true},"preferences_alerts":{"screen":"system","keys":["ffx-audio","ffx-visual","ffx-delay","ffx-sound","ffx-delay-sound","ffx-volume","ffx-repeat","ffx-play-sound","ffx-play-delay","ffx-push-permission","ff-luxe-audio-unlock"],"styleOnly":true},"preferences_tones":{"screen":"system","keys":["ff66-tone-name","ff66-tone-file","ff66-tone-add","ff66-tone-refresh"],"styleOnly":true},"reports_legacy_controls":{"screen":"reports","keys":["ff40ExportCSV","ff40ReportsClose","ff40From","ff40To","ff40ReportBranch","ff40RunReport"],"styleOnly":true},"message_ack_control":{"screen":"messages","keys":["ff39RequireAck"],"styleOnly":true},"dashboard_watch_options":{"screen":"dashboard","keys":["ff4-overdue","ff4-hidephones"],"styleOnly":true},"staff_share_control":{"screen":"staff","keys":["ffEditShare"],"styleOnly":true}}'; g record; rows jsonb; patch jsonb; invalid jsonb; a jsonb; b jsonb;
BEGIN
 FOR g IN SELECT * FROM jsonb_each(spec) LOOP
 SELECT jsonb_agg(jsonb_build_object('key',k,'shape','pack','size','normal','align','center','spaceBlock','wide','outerGap','normal') ORDER BY ord) INTO rows FROM jsonb_array_elements_text(g.value->'keys') WITH ORDINALITY a(k,ord);
 patch:=jsonb_build_object(g.key,rows);
 IF NOT ff_private.a07_valid_elements(patch,g.value->>'screen') THEN RAISE EXCEPTION 'new controls %',g.key;END IF;
 IF ff_private.a07_valid_elements(patch,'finance') OR ff_private.a07_valid_elements(jsonb_build_object(g.key,jsonb_set(rows,'{0,spaceBlock}','"1000px"')),g.value->>'screen') THEN RAISE EXCEPTION 'unsafe scope or spacing %',g.key;END IF;
 END LOOP;
 SELECT jsonb_agg(jsonb_build_object('key',k,'shape','pack','size','normal')||CASE WHEN k='orderSearch' THEN '{"tone":"dark","spaceBlock":"wide"}'::jsonb ELSE '{}'::jsonb END ORDER BY ord) INTO rows FROM unnest(ARRAY['orderSearch','orderBranchFilter','orderStatusFilter','auditRefreshBtn']) WITH ORDINALITY a(k,ord);
 a:=jsonb_build_object('order_search_controls',rows);
 IF NOT ff_private.a07_valid_elements(a,'orders') THEN RAISE EXCEPTION 'neutral field tone';END IF;
 IF ff_private.a09_merge_elements('orders',a,a,jsonb_set(a,'{order_search_controls,0,tone}','"light"'),ARRAY['layout','buttons','colors']) IS NOT NULL THEN RAISE EXCEPTION 'advanced tone delegation changed';END IF;
 b:='{"orders_status":[{"key":"orders_status_tag","shape":"pack","size":"normal","tone":"dark"},{"key":"orders_addition_warning","shape":"pack","size":"normal"}]}';
 IF ff_private.a07_valid_elements(b,'orders') THEN RAISE EXCEPTION 'status color override';END IF;
 SELECT jsonb_agg(jsonb_build_object('key',k,'shape','pack','size','normal')||CASE WHEN k='ffx-kpis' THEN '{"placement":"center"}'::jsonb ELSE '{}'::jsonb END ORDER BY ord) INTO rows FROM unnest(ARRAY['ffx-hero-title','ffx-hero-sub','ffx-kpis','ffx-shortcuts','ffx-order-list','ffx-overdue']) WITH ORDINALITY a(k,ord);
 IF NOT ff_private.a07_valid_elements(jsonb_build_object('dashboard_regions',rows),'dashboard') THEN RAISE EXCEPTION 'valid placement'; END IF;
 IF ff_private.a07_valid_elements(jsonb_set(a,'{order_search_controls,0,placement}','"end"'),'orders') THEN RAISE EXCEPTION 'unsafe placement'; END IF;
END $qa$;
SELECT 'PASS STEP03 shared controls, bounded layout, safe field colors and delegation' AS result;
ROLLBACK;
