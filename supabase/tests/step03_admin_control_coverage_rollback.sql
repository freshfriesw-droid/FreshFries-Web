BEGIN;
DO $qa$
DECLARE spec jsonb:='{"system_qa_controls":{"screen":"system","keys":["ff47Reload","ff47Close","ff47Version","ff47Title","ff47Create","ff47Runs","ff47Export","ff47Finish","ff47Reopen","ff47Category","ff47Filter"],"styleOnly":true},"system_readiness_controls":{"screen":"system","keys":["ff46Run","ff46Export","ff46Close"],"styleOnly":true},"system_access_controls":{"screen":"system","keys":["ff45Run","ff45Export","ff45Close"],"styleOnly":true},"system_integrity_controls":{"screen":"system","keys":["ff44Export","ff44Close","ff44From","ff44To","ff44Run"],"styleOnly":true},"system_security_controls":{"screen":"system","keys":["ff43Run","ff43Export","ff43Close"],"styleOnly":true},"case_contact_controls":{"screen":"cases","keys":["ff41Order","ff41CustomerName","ff41CustomerPhone","ff41Channel","ff41Create"],"styleOnly":true},"message_delivery_controls":{"screen":"messages","keys":["ff39Send","ff39SentRefresh"],"styleOnly":true},"dashboard_alert_controls":{"screen":"dashboard","keys":["ff40AlertRefresh","ff40AlertsClose","ff40AlertBranch"],"styleOnly":true},"staff_filter_controls":{"screen":"staff","keys":["ffEditMyAccount","staffAdminRefresh","ffA05StaffSearch","ffA05StaffRole","ffA05StaffActive","ffA05StaffSort","permissionEmployee","permissionLoad"],"styleOnly":true},"catalog_edit_controls":{"screen":"catalog","keys":["ff51CatalogRefresh","ff51CatalogClose","ffCatalogCardTarget","ffCatalogCardSort","ffCatalogCardStyle","ffCatalogCardSave","ffAliasTarget","ffAliasNames","ffAliasSave","ffAliasDefault"],"styleOnly":true},"customer_close_control":{"screen":"customers","keys":["ff51CustomersClose"],"styleOnly":true},"archive_page_controls":{"screen":"archive","keys":["ff51ArchivePrev","ff51ArchiveNext"],"styleOnly":true},"order_change_controls":{"screen":"orders","keys":["ff50Refresh","ff50Close","ff50RequestItems","ff50RequestReason","ff50RequestSave","ff50RequestCancel"],"styleOnly":true},"order_transfer_controls":{"screen":"orders","keys":["ff49TransferRefresh","ff49TransferClose"],"styleOnly":true},"reservation_save_control":{"screen":"reservations","keys":["ff49ReserveSave"],"styleOnly":true},"assembly_sound_control":{"screen":"assembly","keys":["ff66AssemblySoundSettings"],"styleOnly":true},"staff_edit_controls":{"screen":"staff","keys":["ffEditClose","ffEditSave"],"styleOnly":true}}'::jsonb; g record; rows jsonb; patch jsonb; invalid jsonb; rev jsonb;
BEGIN
 FOR g IN SELECT * FROM jsonb_each(spec) LOOP
 SELECT jsonb_agg(jsonb_build_object('key',k,'shape','pack','size','normal','align','center') ORDER BY ord) INTO rows FROM jsonb_array_elements_text(g.value->'keys') WITH ORDINALITY AS a(k,ord);
 patch:=jsonb_build_object(g.key,rows);
 IF NOT ff_private.a07_valid_elements(patch,g.value->>'screen') OR NOT ff_private.a07_valid_style(jsonb_build_object('elements',patch)) THEN RAISE EXCEPTION 'valid new controls rejected %',g.key; END IF;
 invalid:=jsonb_build_object(g.key,jsonb_set(rows,'{0,key}','"unknown_unsafe"'));
 IF ff_private.a07_valid_elements(invalid,g.value->>'screen') OR ff_private.a07_valid_elements(patch,CASE WHEN g.value->>'screen'='driver' THEN 'cashier' ELSE 'driver' END) THEN RAISE EXCEPTION 'unlisted or cross-screen control accepted %',g.key; END IF;
 IF jsonb_array_length(rows)>1 THEN
 SELECT jsonb_agg(a ORDER BY ord DESC) INTO rev FROM jsonb_array_elements(rows) WITH ORDINALITY AS r(a,ord);
 IF ff_private.a07_valid_elements(jsonb_build_object(g.key,rev),g.value->>'screen') THEN RAISE EXCEPTION 'reorder protected controls accepted %',g.key; END IF;
 END IF;
 invalid:=jsonb_build_object(g.key,jsonb_set(rows,'{0,align}','"end"'));
 IF ff_private.a09_merge_elements(g.value->>'screen',patch,patch,invalid,ARRAY['buttons','layout','colors']) IS NOT NULL THEN RAISE EXCEPTION 'delegation bypass %',g.key; END IF;
 END LOOP;
END $qa$;
SELECT 'PASS STEP03 68 additional admin controls: scope, identity, fixed order, delegation' AS result;
ROLLBACK;
