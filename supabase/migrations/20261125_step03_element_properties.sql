CREATE OR REPLACE FUNCTION ff_private.a07_valid_elements(v jsonb, p_screen text)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE g record; e jsonb; seen text[]; allowed text[]; spec jsonb:='{"dashboard_regions":{"screen":"dashboard","keys":["ffx-hero-title","ffx-hero-sub","ffx-kpis","ffx-shortcuts","ffx-order-list","ffx-overdue"],"styleOnly":true},"order_fields":{"screen":"orders","keys":["newBranch","ffbQuickInput","newPhone","newArea","newFee","newNotes","newCustomerName","newChannel","newFullAddress","ffbMenuSearch","newItems"],"styleOnly":true},"order_tabs":{"screen":"orders","keys":["ffbTabMenu","ffbTabText"],"styleOnly":false},"order_tools":{"screen":"orders","keys":["ffbApplyText","ffbMenuReload"],"styleOnly":true},"cashier_regions":{"screen":"cashier","keys":["cashierOrders"],"styleOnly":true},"assembly_regions":{"screen":"assembly","keys":["ffV12BranchTitle","ffV12AssemblyStatus","ffV12AssemblySummary","ffV12AssemblyOrders"],"styleOnly":true},"catalog_fields":{"screen":"catalog","keys":["ff51CatName","ff51ItemName","ff51ItemPrice","ff51OfferName","ff51OfferPrice"],"styleOnly":true},"catalog_regions":{"screen":"catalog","keys":["ff51CatalogItems","ff51OffersList"],"styleOnly":true},"customer_fields":{"screen":"customers","keys":["ff51CustomerSearch","ff51CustomerNoteText"],"styleOnly":true},"customer_regions":{"screen":"customers","keys":["ff51CustomersList","ff51CustomerHistory","ff51CustomerNotesList"],"styleOnly":true},"report_fields":{"screen":"reports","keys":["ff76From","ff76To","ff76Branch","ff76Driver","ffA10Staff","ffA10Area","ffA10Item","ffA10Status","ff76Mode","ff76Trend"],"styleOnly":true},"report_regions":{"screen":"reports","keys":["ff76Status","ff76Body","ff76ApprovalBox"],"styleOnly":true},"staff_regions":{"screen":"staff","keys":["staffAdminList","staffAuditList"],"styleOnly":true},"archive_fields":{"screen":"archive","keys":["ff51ArchiveFrom","ff51ArchiveTo","ff51ArchiveStatus","ff51ArchiveBranch"],"styleOnly":true},"archive_regions":{"screen":"archive","keys":["ff51ArchiveCount","ff51ArchiveList"],"styleOnly":true},"ratings_regions":{"screen":"ratings","keys":["ff51RatingBranch","ff51RatingsList"],"styleOnly":true},"reservation_fields":{"screen":"reservations","keys":["ff49ReserveBranch","ff49ReserveName","ff49ReservePhone","ff49ReserveNotes","ff49ReservePickup","ff49ReserveItems"],"styleOnly":true},"reservation_regions":{"screen":"reservations","keys":["ff49ReservationsList"],"styleOnly":true},"case_fields":{"screen":"cases","keys":["ff41Kind","ff41Branch","ff41Priority","ff41Subject","ff41Description","ff41FilterKind","ff41FilterStatus"],"styleOnly":true},"case_regions":{"screen":"cases","keys":["ff41CaseList","ff41Detail"],"styleOnly":true},"message_fields":{"screen":"messages","keys":["ff39Title","ff39Role","ff39Branch","ff39Body"],"styleOnly":true},"message_regions":{"screen":"messages","keys":["ff39InboxList","ff39SentLog"],"styleOnly":true},"system_regions":{"screen":"system","keys":["ff48Summary","ff48Rows","ff47Stats","ff47Cases","ff46Summary","ff44Results","ff43Findings"],"styleOnly":true},"reports_actions":{"screen":"reports","keys":["ff76Run","ff76Preview","ff76Download","ff76Share"]},"dashboard_actions":{"screen":"dashboard","keys":["ffx-hero-new","ffx-hero-reserve","ffx-hero-overdue"]},"orders_actions":{"screen":"orders","keys":["createBtn","ffA06DiscardDraft","ffReserveBottom"]},"driver_actions":{"screen":"driver","keys":["ff51BreakBtn","clockInBtn","clockOutBtn"]},"assembly_actions":{"screen":"assembly","keys":["ffV12Toggle","ffV12Refresh","ffV12BurgerOpen","ffV12Logout"]},"burger_actions":{"screen":"burger_kitchen","keys":["ffBurgerKitchenNotifications","ffBurgerViewFinished","ffBurgerKitchenRefresh","ffBurgerKitchenLogout"]},"catalog_actions":{"screen":"catalog","keys":["ff51ItemSave","ff51ItemReset"]},"catalog_offers":{"screen":"catalog","keys":["ff51OfferSave","ff51OfferReset"]},"archive_actions":{"screen":"archive","keys":["ff51ArchiveRefresh","ff51ArchiveExport","ff51ArchiveClose"]},"ratings_actions":{"screen":"ratings","keys":["ff51RatingsRefresh","ff51RatingsClose"]},"reservations_actions":{"screen":"reservations","keys":["ff49ReservationsRefresh","ff49ReservationsClose"]},"cases_actions":{"screen":"cases","keys":["ff41Refresh","ff41Close"]},"messages_actions":{"screen":"messages","keys":["ff39Refresh","ff39Close"]},"system_actions":{"screen":"system","keys":["ff48Refresh","ff48Export","ff48Close"]},"driver_regions":{"screen":"driver","keys":["clockInBtn","driverOffers","driverTasks"]},"assembly_stats":{"screen":"assembly","keys":["ffV12CountAll","ffV12CountPrinted","ffV12CountPreparing","ffV12CountReady"]},"cashier_stage":{"screen":"cashier","keys":["cashier_stage"]},"staff_actions":{"screen":"staff","keys":["staffAuditRefresh"]},"customers_actions":{"screen":"customers","keys":["ff51CustomerFind","ff51CustomerNoteSave"]}}'::jsonb;
BEGIN
 IF v IS NULL OR jsonb_typeof(v)<>'object' THEN RETURN false; END IF;
 FOR g IN SELECT * FROM jsonb_each(v) LOOP
  IF NOT spec ? g.key OR (p_screen<>'all' AND spec->g.key->>'screen'<>p_screen) OR jsonb_typeof(g.value)<>'array' THEN RETURN false; END IF;
  SELECT array_agg(k) INTO allowed FROM jsonb_array_elements_text(spec->g.key->'keys') k;
  IF jsonb_array_length(g.value)<>cardinality(allowed) THEN RETURN false; END IF;
  IF coalesce((spec->g.key->>'styleOnly')::boolean,false) AND (SELECT array_agg(a.row->>'key' ORDER BY a.ord) FROM jsonb_array_elements(g.value) WITH ORDINALITY a(row,ord)) IS DISTINCT FROM allowed THEN RETURN false; END IF;
  seen:='{}';
  FOR e IN SELECT * FROM jsonb_array_elements(g.value) LOOP
   IF jsonb_typeof(e)<>'object' THEN RETURN false; END IF;
   IF NOT (e ?& ARRAY['key','shape','size']) OR EXISTS(SELECT 1 FROM jsonb_object_keys(e) k WHERE k NOT IN ('key','shape','size','font','weight','spacing','border','shadow','tone'))
      OR NOT coalesce(e->>'key'=ANY(allowed),false) OR coalesce(e->>'key'=ANY(seen),true)
      OR NOT coalesce(e->>'shape' IN ('inherit','pack','square','round','pill','outline','icon_label'),false)
      OR NOT coalesce(e->>'size' IN ('inherit','normal','large'),false) THEN RETURN false;END IF;
   IF EXISTS(SELECT 1 FROM jsonb_each(e) x WHERE x.key NOT IN ('key','shape','size') AND NOT CASE x.key
      WHEN 'font' THEN x.value IN ('"system"'::jsonb,'"tahoma"'::jsonb,'"serif"'::jsonb)
      WHEN 'weight' THEN x.value IN ('"normal"'::jsonb,'"strong"'::jsonb)
      WHEN 'spacing' THEN x.value IN ('"normal"'::jsonb,'"wide"'::jsonb)
      WHEN 'border' THEN x.value IN ('"thin"'::jsonb,'"strong"'::jsonb)
      WHEN 'shadow' THEN x.value IN ('"none"'::jsonb,'"soft"'::jsonb)
      WHEN 'tone' THEN x.value IN ('"navy"'::jsonb,'"red"'::jsonb,'"light"'::jsonb,'"dark"'::jsonb) AND e->>'key' IN ('ff76Run','ff76Preview','ff76Download','ff76Share','ffx-hero-new','ffx-hero-reserve','ff51ArchiveRefresh','ff51ArchiveExport','ff51CustomerFind')
      ELSE false END) THEN RETURN false; END IF;
   seen:=array_append(seen,e->>'key');
  END LOOP;
 END LOOP;
 RETURN true;
END $function$;

CREATE OR REPLACE FUNCTION ff_private.a09_merge_elements(p_screen text, p_exact jsonb, p_inherited jsonb, p_patch jsonb, p_kinds text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE spec jsonb:='{"dashboard_regions":{"screen":"dashboard","keys":["ffx-hero-title","ffx-hero-sub","ffx-kpis","ffx-shortcuts","ffx-order-list","ffx-overdue"],"styleOnly":true},"order_fields":{"screen":"orders","keys":["newBranch","ffbQuickInput","newPhone","newArea","newFee","newNotes","newCustomerName","newChannel","newFullAddress","ffbMenuSearch","newItems"],"styleOnly":true},"order_tabs":{"screen":"orders","keys":["ffbTabMenu","ffbTabText"],"styleOnly":false},"order_tools":{"screen":"orders","keys":["ffbApplyText","ffbMenuReload"],"styleOnly":true},"cashier_regions":{"screen":"cashier","keys":["cashierOrders"],"styleOnly":true},"assembly_regions":{"screen":"assembly","keys":["ffV12BranchTitle","ffV12AssemblyStatus","ffV12AssemblySummary","ffV12AssemblyOrders"],"styleOnly":true},"catalog_fields":{"screen":"catalog","keys":["ff51CatName","ff51ItemName","ff51ItemPrice","ff51OfferName","ff51OfferPrice"],"styleOnly":true},"catalog_regions":{"screen":"catalog","keys":["ff51CatalogItems","ff51OffersList"],"styleOnly":true},"customer_fields":{"screen":"customers","keys":["ff51CustomerSearch","ff51CustomerNoteText"],"styleOnly":true},"customer_regions":{"screen":"customers","keys":["ff51CustomersList","ff51CustomerHistory","ff51CustomerNotesList"],"styleOnly":true},"report_fields":{"screen":"reports","keys":["ff76From","ff76To","ff76Branch","ff76Driver","ffA10Staff","ffA10Area","ffA10Item","ffA10Status","ff76Mode","ff76Trend"],"styleOnly":true},"report_regions":{"screen":"reports","keys":["ff76Status","ff76Body","ff76ApprovalBox"],"styleOnly":true},"staff_regions":{"screen":"staff","keys":["staffAdminList","staffAuditList"],"styleOnly":true},"archive_fields":{"screen":"archive","keys":["ff51ArchiveFrom","ff51ArchiveTo","ff51ArchiveStatus","ff51ArchiveBranch"],"styleOnly":true},"archive_regions":{"screen":"archive","keys":["ff51ArchiveCount","ff51ArchiveList"],"styleOnly":true},"ratings_regions":{"screen":"ratings","keys":["ff51RatingBranch","ff51RatingsList"],"styleOnly":true},"reservation_fields":{"screen":"reservations","keys":["ff49ReserveBranch","ff49ReserveName","ff49ReservePhone","ff49ReserveNotes","ff49ReservePickup","ff49ReserveItems"],"styleOnly":true},"reservation_regions":{"screen":"reservations","keys":["ff49ReservationsList"],"styleOnly":true},"case_fields":{"screen":"cases","keys":["ff41Kind","ff41Branch","ff41Priority","ff41Subject","ff41Description","ff41FilterKind","ff41FilterStatus"],"styleOnly":true},"case_regions":{"screen":"cases","keys":["ff41CaseList","ff41Detail"],"styleOnly":true},"message_fields":{"screen":"messages","keys":["ff39Title","ff39Role","ff39Branch","ff39Body"],"styleOnly":true},"message_regions":{"screen":"messages","keys":["ff39InboxList","ff39SentLog"],"styleOnly":true},"system_regions":{"screen":"system","keys":["ff48Summary","ff48Rows","ff47Stats","ff47Cases","ff46Summary","ff44Results","ff43Findings"],"styleOnly":true},"reports_actions":{"screen":"reports","keys":["ff76Run","ff76Preview","ff76Download","ff76Share"]},"dashboard_actions":{"screen":"dashboard","keys":["ffx-hero-new","ffx-hero-reserve","ffx-hero-overdue"]},"orders_actions":{"screen":"orders","keys":["createBtn","ffA06DiscardDraft","ffReserveBottom"]},"driver_actions":{"screen":"driver","keys":["ff51BreakBtn","clockInBtn","clockOutBtn"]},"assembly_actions":{"screen":"assembly","keys":["ffV12Toggle","ffV12Refresh","ffV12BurgerOpen","ffV12Logout"]},"burger_actions":{"screen":"burger_kitchen","keys":["ffBurgerKitchenNotifications","ffBurgerViewFinished","ffBurgerKitchenRefresh","ffBurgerKitchenLogout"]},"catalog_actions":{"screen":"catalog","keys":["ff51ItemSave","ff51ItemReset"]},"catalog_offers":{"screen":"catalog","keys":["ff51OfferSave","ff51OfferReset"]},"archive_actions":{"screen":"archive","keys":["ff51ArchiveRefresh","ff51ArchiveExport","ff51ArchiveClose"]},"ratings_actions":{"screen":"ratings","keys":["ff51RatingsRefresh","ff51RatingsClose"]},"reservations_actions":{"screen":"reservations","keys":["ff49ReservationsRefresh","ff49ReservationsClose"]},"cases_actions":{"screen":"cases","keys":["ff41Refresh","ff41Close"]},"messages_actions":{"screen":"messages","keys":["ff39Refresh","ff39Close"]},"system_actions":{"screen":"system","keys":["ff48Refresh","ff48Export","ff48Close"]},"driver_regions":{"screen":"driver","keys":["clockInBtn","driverOffers","driverTasks"]},"assembly_stats":{"screen":"assembly","keys":["ffV12CountAll","ffV12CountPrinted","ffV12CountPreparing","ffV12CountReady"]},"cashier_stage":{"screen":"cashier","keys":["cashier_stage"]},"staff_actions":{"screen":"staff","keys":["staffAuditRefresh"]},"customers_actions":{"screen":"customers","keys":["ff51CustomerFind","ff51CustomerNoteSave"]}}'::jsonb; g record; old_rows jsonb; new_rows jsonb; out_rows jsonb:=coalesce(p_exact,'{}'); old_order text[]; new_order text[];
BEGIN
 IF NOT ff_private.a07_valid_elements(p_patch,p_screen) THEN RETURN NULL; END IF;
 FOR g IN SELECT * FROM jsonb_each(p_patch) LOOP
  old_rows:=coalesce(p_exact->g.key,p_inherited->g.key);
  IF old_rows IS NULL THEN SELECT jsonb_agg(jsonb_build_object('key',k,'shape','pack','size','normal') ORDER BY ord) INTO old_rows FROM jsonb_array_elements_text(spec->g.key->'keys') WITH ORDINALITY AS a(k,ord);END IF;
  new_rows:=g.value;
  SELECT array_agg(e->>'key' ORDER BY ord) INTO old_order FROM jsonb_array_elements(old_rows) WITH ORDINALITY a(e,ord);
  SELECT array_agg(e->>'key' ORDER BY ord) INTO new_order FROM jsonb_array_elements(new_rows) WITH ORDINALITY a(e,ord);
  IF NOT ('layout'=ANY(p_kinds)) AND old_order IS DISTINCT FROM new_order THEN RETURN NULL; END IF;
  IF NOT ('buttons'=ANY(p_kinds)) AND EXISTS(SELECT FROM jsonb_array_elements(old_rows) a JOIN jsonb_array_elements(new_rows) b ON a->>'key'=b->>'key' WHERE a->>'shape' IS DISTINCT FROM b->>'shape' OR a->>'size' IS DISTINCT FROM b->>'size') THEN RETURN NULL; END IF;
  IF EXISTS(
   SELECT 1 FROM jsonb_array_elements(new_rows) b
   LEFT JOIN LATERAL (SELECT a FROM jsonb_array_elements(coalesce(p_exact->g.key,'[]')) a WHERE a->>'key'=b->>'key') ex ON true
   LEFT JOIN LATERAL (SELECT a FROM jsonb_array_elements(coalesce(p_inherited->g.key,'[]')) a WHERE a->>'key'=b->>'key') inh ON true
   WHERE (b-ARRAY['key','shape','size']) IS DISTINCT FROM
     ((coalesce(inh.a,'{}')||coalesce(ex.a,'{}'))-ARRAY['key','shape','size'])
  ) THEN RETURN NULL; END IF;
  SELECT jsonb_agg((b.row-ARRAY['font','weight','spacing','border','shadow','tone'])||
     (coalesce((SELECT a FROM jsonb_array_elements(coalesce(p_exact->g.key,'[]')) a WHERE a->>'key'=b.row->>'key'),'{}')-ARRAY['key','shape','size']) ORDER BY b.ord)
  INTO new_rows FROM jsonb_array_elements(new_rows) WITH ORDINALITY b(row,ord);
  out_rows:=out_rows||jsonb_build_object(g.key,new_rows);
 END LOOP;
 RETURN out_rows;
END $function$;

CREATE OR REPLACE FUNCTION ff_private.a07_style_layers(p_screen text, p_role text, p_branch uuid, p_device text, p_actor uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 WITH candidates AS (SELECT * FROM ff_private.a07_ranked_candidates(p_screen,p_role,p_branch,p_device,p_actor)),
 properties AS (
  SELECT DISTINCT ON (e.key) e.key,e.value,c.revision
  FROM candidates c CROSS JOIN LATERAL jsonb_each(c.style-ARRAY['elements','dashboardPanels']) e
  ORDER BY e.key,c.rank_order
 ), panel_properties AS (
  SELECT DISTINCT ON (e.key) e.key,e.value,c.revision
  FROM candidates c CROSS JOIN LATERAL jsonb_each(coalesce(c.style->'dashboardPanels','{}')) e
  WHERE p_screen IN ('dashboard','all')
  ORDER BY e.key,c.rank_order
 ), eligible_groups AS (
  SELECT e.key,e.value,c.revision,c.rank_order
  FROM candidates c CROSS JOIN LATERAL jsonb_each(coalesce(c.style->'elements','{}')) e
  WHERE ff_private.a07_valid_elements(jsonb_build_object(e.key,e.value),p_screen)
 ), element_groups AS (
  SELECT DISTINCT ON (key) key,value,revision FROM eligible_groups ORDER BY key,rank_order
 ), element_properties AS (
  SELECT DISTINCT ON (g.key,r.row->>'key',p.key)
   g.key AS group_key,r.row->>'key' AS element_key,p.key AS property,p.value,g.revision
  FROM eligible_groups g CROSS JOIN LATERAL jsonb_array_elements(g.value) r(row)
  CROSS JOIN LATERAL jsonb_each(r.row-'key') p
  WHERE p.value <> '"inherit"'::jsonb
  ORDER BY g.key,r.row->>'key',p.key,g.rank_order
 ), resolved_groups AS (
  SELECT g.key,jsonb_agg(jsonb_build_object('key',r.row->>'key','shape','pack','size','normal') ||
    coalesce((SELECT jsonb_object_agg(p.property,p.value) FROM element_properties p WHERE p.group_key=g.key AND p.element_key=r.row->>'key'),'{}') ORDER BY r.ord) AS value
  FROM element_groups g CROSS JOIN LATERAL jsonb_array_elements(g.value) WITH ORDINALITY r(row,ord)
  GROUP BY g.key
 ), element_sources AS (
 SELECT 'elements.'||group_key||'.'||element_key||'.'||property AS key,revision FROM element_properties
 UNION ALL
 SELECT 'elements.'||g.key||'.'||(r.row->>'key')||'.order',g.revision
 FROM element_groups g CROSS JOIN LATERAL jsonb_array_elements(g.value) r(row)
 )
 SELECT jsonb_build_object(
 'style',coalesce((SELECT jsonb_object_agg(key,value) FROM properties),'{}') ||
  CASE WHEN EXISTS(SELECT 1 FROM panel_properties) THEN jsonb_build_object('dashboardPanels',(SELECT jsonb_object_agg(key,value) FROM panel_properties)) ELSE '{}'::jsonb END ||
  CASE WHEN EXISTS(SELECT 1 FROM element_groups) THEN jsonb_build_object('elements',(SELECT jsonb_object_agg(key,value) FROM resolved_groups)) ELSE '{}'::jsonb END,
 'sources',coalesce((SELECT jsonb_object_agg(key,revision) FROM properties),'{}') ||
  coalesce((SELECT jsonb_object_agg('dashboardPanels.'||key,revision) FROM panel_properties),'{}') ||
 coalesce((SELECT jsonb_object_agg('elements.'||key,revision) FROM element_groups),'{}') || coalesce((SELECT jsonb_object_agg(key,revision) FROM element_sources),'{}')
 )
$function$;
