-- STEP03: approved public/finance/branch screen scopes. No operating data changes.
ALTER TABLE public.ff_ui_versions DROP CONSTRAINT ff_a07_screen_valid;
ALTER TABLE public.ff_ui_versions ADD CONSTRAINT ff_a07_screen_valid CHECK (screen_scope IN ('all','dashboard','orders','cashier','driver','assembly','burger_kitchen','catalog','customers','reports','staff','archive','ratings','cases','messages','reservations','system','finance','branches','login','customer_portal'));
ALTER TABLE public.ff_ui_versions ADD CONSTRAINT ff_step03_public_scope CHECK (screen_scope NOT IN ('login','customer_portal') OR (role_scope='all' AND branch_id IS NULL));
CREATE OR REPLACE FUNCTION ff_private.a07_ranked_candidates(p_screen text, p_role text, p_branch uuid, p_device text, p_actor uuid)
 RETURNS TABLE(revision bigint, style jsonb, rank_order bigint)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 WITH scoped AS (
 SELECT DISTINCT ON (v.screen_scope,v.role_scope,v.branch_id,v.device)
   v.id,v.style_config,v.screen_scope,v.role_scope,v.branch_id,v.device,v.published_at,trial.started_at
 FROM public.ff_ui_versions v
 LEFT JOIN LATERAL (SELECT max(t.started_at) AS started_at FROM public.ff_ui_trials t
  WHERE t.version_id=v.id AND t.recipient=p_actor AND t.stopped_at IS NULL AND t.ends_at>now() AND v.published_at IS NULL) trial ON true
 WHERE (v.published_at IS NOT NULL OR trial.started_at IS NOT NULL)
 AND (p_screen NOT IN ('login','customer_portal') OR (v.screen_scope=p_screen AND v.role_scope='all' AND v.branch_id IS NULL AND v.published_at IS NOT NULL))
 AND v.screen_scope IN ('all',p_screen) AND v.role_scope IN ('all',p_role)
 AND (v.branch_id IS NULL OR v.branch_id=p_branch) AND v.device IN ('all',p_device)
 ORDER BY v.screen_scope,v.role_scope,v.branch_id,v.device,(trial.started_at IS NOT NULL) DESC,coalesce(trial.started_at,v.published_at) DESC,v.id DESC
 )
 SELECT id,style_config,row_number() OVER(ORDER BY (started_at IS NOT NULL) DESC,
 ((screen_scope<>'all')::int+(role_scope<>'all')::int+(branch_id IS NOT NULL)::int+(device<>'all')::int) DESC,
 (screen_scope<>'all') DESC,(role_scope<>'all') DESC,(branch_id IS NOT NULL) DESC,(device<>'all') DESC,
 coalesce(started_at,published_at) DESC,id DESC)
 FROM scoped
$function$;
CREATE OR REPLACE FUNCTION ff_private.a07_resolve(p_screen text, p_role text, p_branch uuid, p_device text, p_actor uuid)
 RETURNS SETOF ff_ui_versions
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 SELECT v.* FROM public.ff_ui_versions v
 LEFT JOIN LATERAL (SELECT max(t.started_at) AS started_at FROM public.ff_ui_trials t
  WHERE t.version_id=v.id AND t.recipient=p_actor AND t.stopped_at IS NULL AND t.ends_at>now() AND v.published_at IS NULL) trial ON true
 WHERE (v.published_at IS NOT NULL OR trial.started_at IS NOT NULL)
 AND (p_screen NOT IN ('login','customer_portal') OR (v.screen_scope=p_screen AND v.role_scope='all' AND v.branch_id IS NULL AND v.published_at IS NOT NULL))
 AND v.screen_scope IN ('all',p_screen) AND v.role_scope IN ('all',p_role)
 AND (v.branch_id IS NULL OR v.branch_id=p_branch) AND v.device IN ('all',p_device)
 ORDER BY (trial.started_at IS NOT NULL) DESC,
 ((v.screen_scope<>'all')::int+(v.role_scope<>'all')::int+(v.branch_id IS NOT NULL)::int+(v.device<>'all')::int) DESC,
 (v.screen_scope<>'all') DESC,(v.role_scope<>'all') DESC,(v.branch_id IS NOT NULL) DESC,(v.device<>'all') DESC,
 coalesce(trial.started_at,v.published_at) DESC,v.id DESC LIMIT 1
$function$;
CREATE OR REPLACE FUNCTION ff_private.a07_valid_elements(v jsonb, p_screen text)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE g record; e jsonb; seen text[]; allowed text[]; spec jsonb:='{"dashboard_status":{"screen":"dashboard","keys":["dashboard_status_tag"],"styleOnly":true},"orders_status":{"screen":"orders","keys":["orders_status_tag","orders_addition_warning"],"styleOnly":true},"driver_status":{"screen":"driver","keys":["driver_offer_countdown","driver_status_tag"],"styleOnly":true},"cashier_status":{"screen":"cashier","keys":["cashier_status_tag","cashier_addition_warning"],"styleOnly":true},"burger_regions":{"screen":"burger_kitchen","keys":["ffBurgerKitchenStatus","ffBurgerKitchenBranch","ffBurgerKitchenActive","ffBurgerKitchenFinished"],"styleOnly":true},"dashboard_regions":{"screen":"dashboard","keys":["ffx-hero-title","ffx-hero-sub","ffx-kpis","ffx-shortcuts","ffx-order-list","ffx-overdue"],"styleOnly":true},"order_fields":{"screen":"orders","keys":["newBranch","ffbQuickInput","newPhone","newArea","newFee","newNotes","newCustomerName","newChannel","newFullAddress","ffbMenuSearch","newItems"],"styleOnly":true},"order_tabs":{"screen":"orders","keys":["ffbTabMenu","ffbTabText"],"styleOnly":false},"order_tools":{"screen":"orders","keys":["ffbApplyText","ffbMenuReload"],"styleOnly":true},"cashier_regions":{"screen":"cashier","keys":["cashierOrders"],"styleOnly":true},"assembly_regions":{"screen":"assembly","keys":["ffV12BranchTitle","ffV12AssemblyStatus","ffV12AssemblySummary","ffV12AssemblyOrders"],"styleOnly":true},"catalog_fields":{"screen":"catalog","keys":["ff51CatName","ff51ItemName","ff51ItemPrice","ff51OfferName","ff51OfferPrice"],"styleOnly":true},"catalog_regions":{"screen":"catalog","keys":["ff51CatalogItems","ff51OffersList"],"styleOnly":true},"customer_fields":{"screen":"customers","keys":["ff51CustomerSearch","ff51CustomerNoteText"],"styleOnly":true},"customer_regions":{"screen":"customers","keys":["ff51CustomersList","ff51CustomerHistory","ff51CustomerNotesList"],"styleOnly":true},"report_fields":{"screen":"reports","keys":["ff76From","ff76To","ff76Branch","ff76Driver","ffA10Staff","ffA10Area","ffA10Item","ffA10Status","ff76Mode","ff76Trend"],"styleOnly":true},"report_regions":{"screen":"reports","keys":["ff76Status","ff76Body","ff76ApprovalBox"],"styleOnly":true},"staff_regions":{"screen":"staff","keys":["staffAdminList","staffAuditList"],"styleOnly":true},"archive_fields":{"screen":"archive","keys":["ff51ArchiveFrom","ff51ArchiveTo","ff51ArchiveStatus","ff51ArchiveBranch"],"styleOnly":true},"archive_regions":{"screen":"archive","keys":["ff51ArchiveCount","ff51ArchiveList"],"styleOnly":true},"ratings_regions":{"screen":"ratings","keys":["ff51RatingBranch","ff51RatingsList"],"styleOnly":true},"reservation_fields":{"screen":"reservations","keys":["ff49ReserveBranch","ff49ReserveName","ff49ReservePhone","ff49ReserveNotes","ff49ReservePickup","ff49ReserveItems"],"styleOnly":true},"reservation_regions":{"screen":"reservations","keys":["ff49ReservationsList"],"styleOnly":true},"case_fields":{"screen":"cases","keys":["ff41Kind","ff41Branch","ff41Priority","ff41Subject","ff41Description","ff41FilterKind","ff41FilterStatus"],"styleOnly":true},"case_regions":{"screen":"cases","keys":["ff41CaseList","ff41Detail"],"styleOnly":true},"message_fields":{"screen":"messages","keys":["ff39Title","ff39Role","ff39Branch","ff39Body"],"styleOnly":true},"message_regions":{"screen":"messages","keys":["ff39InboxList","ff39SentLog"],"styleOnly":true},"system_regions":{"screen":"system","keys":["ff48Summary","ff48Rows","ff47Stats","ff47Cases","ff46Summary","ff44Results","ff43Findings"],"styleOnly":true},"reports_actions":{"screen":"reports","keys":["ff76Run","ff76Preview","ff76Download","ff76Share"]},"dashboard_actions":{"screen":"dashboard","keys":["ffx-hero-new","ffx-hero-reserve","ffx-hero-overdue"]},"orders_actions":{"screen":"orders","keys":["createBtn","ffA06DiscardDraft","ffReserveBottom"]},"driver_actions":{"screen":"driver","keys":["ff51BreakBtn","clockInBtn","clockOutBtn"]},"assembly_actions":{"screen":"assembly","keys":["ffV12Toggle","ffV12Refresh","ffV12BurgerOpen","ffV12Logout"]},"burger_actions":{"screen":"burger_kitchen","keys":["ffBurgerKitchenNotifications","ffBurgerViewFinished","ffBurgerKitchenRefresh","ffBurgerKitchenLogout"]},"catalog_actions":{"screen":"catalog","keys":["ff51ItemSave","ff51ItemReset"]},"catalog_offers":{"screen":"catalog","keys":["ff51OfferSave","ff51OfferReset"]},"archive_actions":{"screen":"archive","keys":["ff51ArchiveRefresh","ff51ArchiveExport","ff51ArchiveClose"]},"ratings_actions":{"screen":"ratings","keys":["ff51RatingsRefresh","ff51RatingsClose"]},"reservations_actions":{"screen":"reservations","keys":["ff49ReservationsRefresh","ff49ReservationsClose"]},"cases_actions":{"screen":"cases","keys":["ff41Refresh","ff41Close"]},"messages_actions":{"screen":"messages","keys":["ff39Refresh","ff39Close"]},"system_actions":{"screen":"system","keys":["ff48Refresh","ff48Export","ff48Close"]},"driver_regions":{"screen":"driver","keys":["clockInBtn","driverOffers","driverTasks"]},"assembly_stats":{"screen":"assembly","keys":["ffV12CountAll","ffV12CountPrinted","ffV12CountPreparing","ffV12CountReady"]},"cashier_stage":{"screen":"cashier","keys":["cashier_stage"]},"staff_actions":{"screen":"staff","keys":["staffAuditRefresh"]},"customers_actions":{"screen":"customers","keys":["ff51CustomerFind","ff51CustomerNoteSave"]},"finance_actions":{"screen":"finance","keys":["ff42Load","ff42Export","ff42ClosePanel","ff42Save","ff42CloseSettlement","ff42ShowDetail"],"styleOnly":true},"finance_fields":{"screen":"finance","keys":["ff42Day","ff42Branch","ff42CashDue","ff42CashReceived","ff42Difference","ff42Notes"],"styleOnly":true},"finance_regions":{"screen":"finance","keys":["ff42Status","ff42Summary","ff42List","ff42Form","ff42Detail"],"styleOnly":true},"branches_actions":{"screen":"branches","keys":["ffA05BranchPolicyBtn","ffA05Close","ffA05SaveHours","ffA05SaveTariff","ffA05PriceHistory"],"styleOnly":true},"branches_fields":{"screen":"branches","keys":["ffA05PolicyBranch","ffA05Effective","ffA05Reason","ffA05Day","ffA05Closed","ffA05Open","ffA05CloseTime","ffA05Shift","ffA05Area","ffA05Tariff"],"styleOnly":true},"branches_regions":{"screen":"branches","keys":["ffA05PolicyStatus","ffA05PolicyCurrent","ffA05PolicyHistory","ffA05PriceRows"],"styleOnly":true},"login_actions":{"screen":"login","keys":["loginBtn","ff61ApplyToggle","ff61StatusToggle","ff71CustomerToggle","ff71CustomerSend","ff71CustomerVerify","ff61ApplySend","ff61TrackSend"],"styleOnly":true},"login_fields":{"screen":"login","keys":["email","password","ff71CustomerPhone","ff71CustomerCode","ff61TrackCode","loginStatus","ff71CustomerMessage"],"styleOnly":true},"join_fields":{"screen":"login","keys":["join_name","join_email","join_phone","join_qualification","join_address","join_age","join_marital","join_role","join_experience","join_message","ff61Consent","ff61ApplyInfo"],"styleOnly":true},"customer_portal_actions":{"screen":"customer_portal","keys":["ff28Refresh","ff28Logout"],"styleOnly":true},"customer_portal_regions":{"screen":"customer_portal","keys":["ff28Title","ff28State","ff28Rows","ff28Name","ff28Role"],"styleOnly":true}}'::jsonb;
BEGIN
 IF v IS NULL OR jsonb_typeof(v)<>'object' THEN RETURN false; END IF;
 FOR g IN SELECT * FROM jsonb_each(v) LOOP
  IF NOT spec ? g.key OR (p_screen<>'all' AND spec->g.key->>'screen'<>p_screen) OR jsonb_typeof(g.value)<>'array' THEN RETURN false; END IF;
  SELECT array_agg(k) INTO allowed FROM jsonb_array_elements_text(spec->g.key->'keys') k;
  IF jsonb_array_length(g.value)<>cardinality(allowed) THEN RETURN false; END IF;
  IF coalesce((spec->g.key->>'styleOnly')::boolean,false) AND (SELECT array_agg(a.row->>'key' ORDER BY a.ord) FROM jsonb_array_elements(g.value) WITH ORDINALITY a(row,ord)) IS DISTINCT FROM allowed THEN RETURN false; END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(g.value) a WHERE a->>'orderMode'='inherit') NOT IN (0,cardinality(allowed)) THEN RETURN false; END IF;
  seen:='{}';
  FOR e IN SELECT * FROM jsonb_array_elements(g.value) LOOP
   IF jsonb_typeof(e)<>'object' THEN RETURN false; END IF;
   IF NOT (e ?& ARRAY['key','shape','size']) OR EXISTS(SELECT 1 FROM jsonb_object_keys(e) k WHERE k NOT IN ('key','shape','size','font','weight','spacing','border','shadow','tone','orderMode','icon','hover','press'))
      OR NOT coalesce(e->>'key'=ANY(allowed),false) OR coalesce(e->>'key'=ANY(seen),true)
      OR NOT coalesce(e->>'shape' IN ('inherit','pack','square','round','pill','outline','icon_label'),false)
      OR NOT coalesce(e->>'size' IN ('inherit','normal','large'),false) THEN RETURN false;END IF;
   IF EXISTS(SELECT 1 FROM jsonb_each(e) x WHERE x.key NOT IN ('key','shape','size') AND NOT CASE x.key
      WHEN 'orderMode' THEN x.value='"inherit"'::jsonb
      WHEN 'font' THEN x.value IN ('"system"'::jsonb,'"tahoma"'::jsonb,'"serif"'::jsonb)
      WHEN 'weight' THEN x.value IN ('"normal"'::jsonb,'"strong"'::jsonb)
      WHEN 'spacing' THEN x.value IN ('"normal"'::jsonb,'"wide"'::jsonb)
      WHEN 'border' THEN x.value IN ('"thin"'::jsonb,'"strong"'::jsonb)
      WHEN 'shadow' THEN x.value IN ('"none"'::jsonb,'"soft"'::jsonb)
      WHEN 'icon' THEN x.value IN ('"none"'::jsonb,'"check"'::jsonb,'"arrow"'::jsonb,'"star"'::jsonb,'"search"'::jsonb,'"file"'::jsonb) AND e->>'key' IN ('ff76Run','ff76Preview','ff76Download','ff76Share','ffx-hero-new','ffx-hero-reserve','ff51ArchiveRefresh','ff51ArchiveExport','ff51CustomerFind')
      WHEN 'hover' THEN x.value IN ('"none"'::jsonb,'"outline"'::jsonb,'"shadow"'::jsonb) AND e->>'key' IN ('ff76Run','ff76Preview','ff76Download','ff76Share','ffx-hero-new','ffx-hero-reserve','ff51ArchiveRefresh','ff51ArchiveExport','ff51CustomerFind')
      WHEN 'press' THEN x.value IN ('"none"'::jsonb,'"inset"'::jsonb) AND e->>'key' IN ('ff76Run','ff76Preview','ff76Download','ff76Share','ffx-hero-new','ffx-hero-reserve','ff51ArchiveRefresh','ff51ArchiveExport','ff51CustomerFind')
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
DECLARE spec jsonb:='{"dashboard_status":{"screen":"dashboard","keys":["dashboard_status_tag"],"styleOnly":true},"orders_status":{"screen":"orders","keys":["orders_status_tag","orders_addition_warning"],"styleOnly":true},"driver_status":{"screen":"driver","keys":["driver_offer_countdown","driver_status_tag"],"styleOnly":true},"cashier_status":{"screen":"cashier","keys":["cashier_status_tag","cashier_addition_warning"],"styleOnly":true},"burger_regions":{"screen":"burger_kitchen","keys":["ffBurgerKitchenStatus","ffBurgerKitchenBranch","ffBurgerKitchenActive","ffBurgerKitchenFinished"],"styleOnly":true},"dashboard_regions":{"screen":"dashboard","keys":["ffx-hero-title","ffx-hero-sub","ffx-kpis","ffx-shortcuts","ffx-order-list","ffx-overdue"],"styleOnly":true},"order_fields":{"screen":"orders","keys":["newBranch","ffbQuickInput","newPhone","newArea","newFee","newNotes","newCustomerName","newChannel","newFullAddress","ffbMenuSearch","newItems"],"styleOnly":true},"order_tabs":{"screen":"orders","keys":["ffbTabMenu","ffbTabText"],"styleOnly":false},"order_tools":{"screen":"orders","keys":["ffbApplyText","ffbMenuReload"],"styleOnly":true},"cashier_regions":{"screen":"cashier","keys":["cashierOrders"],"styleOnly":true},"assembly_regions":{"screen":"assembly","keys":["ffV12BranchTitle","ffV12AssemblyStatus","ffV12AssemblySummary","ffV12AssemblyOrders"],"styleOnly":true},"catalog_fields":{"screen":"catalog","keys":["ff51CatName","ff51ItemName","ff51ItemPrice","ff51OfferName","ff51OfferPrice"],"styleOnly":true},"catalog_regions":{"screen":"catalog","keys":["ff51CatalogItems","ff51OffersList"],"styleOnly":true},"customer_fields":{"screen":"customers","keys":["ff51CustomerSearch","ff51CustomerNoteText"],"styleOnly":true},"customer_regions":{"screen":"customers","keys":["ff51CustomersList","ff51CustomerHistory","ff51CustomerNotesList"],"styleOnly":true},"report_fields":{"screen":"reports","keys":["ff76From","ff76To","ff76Branch","ff76Driver","ffA10Staff","ffA10Area","ffA10Item","ffA10Status","ff76Mode","ff76Trend"],"styleOnly":true},"report_regions":{"screen":"reports","keys":["ff76Status","ff76Body","ff76ApprovalBox"],"styleOnly":true},"staff_regions":{"screen":"staff","keys":["staffAdminList","staffAuditList"],"styleOnly":true},"archive_fields":{"screen":"archive","keys":["ff51ArchiveFrom","ff51ArchiveTo","ff51ArchiveStatus","ff51ArchiveBranch"],"styleOnly":true},"archive_regions":{"screen":"archive","keys":["ff51ArchiveCount","ff51ArchiveList"],"styleOnly":true},"ratings_regions":{"screen":"ratings","keys":["ff51RatingBranch","ff51RatingsList"],"styleOnly":true},"reservation_fields":{"screen":"reservations","keys":["ff49ReserveBranch","ff49ReserveName","ff49ReservePhone","ff49ReserveNotes","ff49ReservePickup","ff49ReserveItems"],"styleOnly":true},"reservation_regions":{"screen":"reservations","keys":["ff49ReservationsList"],"styleOnly":true},"case_fields":{"screen":"cases","keys":["ff41Kind","ff41Branch","ff41Priority","ff41Subject","ff41Description","ff41FilterKind","ff41FilterStatus"],"styleOnly":true},"case_regions":{"screen":"cases","keys":["ff41CaseList","ff41Detail"],"styleOnly":true},"message_fields":{"screen":"messages","keys":["ff39Title","ff39Role","ff39Branch","ff39Body"],"styleOnly":true},"message_regions":{"screen":"messages","keys":["ff39InboxList","ff39SentLog"],"styleOnly":true},"system_regions":{"screen":"system","keys":["ff48Summary","ff48Rows","ff47Stats","ff47Cases","ff46Summary","ff44Results","ff43Findings"],"styleOnly":true},"reports_actions":{"screen":"reports","keys":["ff76Run","ff76Preview","ff76Download","ff76Share"]},"dashboard_actions":{"screen":"dashboard","keys":["ffx-hero-new","ffx-hero-reserve","ffx-hero-overdue"]},"orders_actions":{"screen":"orders","keys":["createBtn","ffA06DiscardDraft","ffReserveBottom"]},"driver_actions":{"screen":"driver","keys":["ff51BreakBtn","clockInBtn","clockOutBtn"]},"assembly_actions":{"screen":"assembly","keys":["ffV12Toggle","ffV12Refresh","ffV12BurgerOpen","ffV12Logout"]},"burger_actions":{"screen":"burger_kitchen","keys":["ffBurgerKitchenNotifications","ffBurgerViewFinished","ffBurgerKitchenRefresh","ffBurgerKitchenLogout"]},"catalog_actions":{"screen":"catalog","keys":["ff51ItemSave","ff51ItemReset"]},"catalog_offers":{"screen":"catalog","keys":["ff51OfferSave","ff51OfferReset"]},"archive_actions":{"screen":"archive","keys":["ff51ArchiveRefresh","ff51ArchiveExport","ff51ArchiveClose"]},"ratings_actions":{"screen":"ratings","keys":["ff51RatingsRefresh","ff51RatingsClose"]},"reservations_actions":{"screen":"reservations","keys":["ff49ReservationsRefresh","ff49ReservationsClose"]},"cases_actions":{"screen":"cases","keys":["ff41Refresh","ff41Close"]},"messages_actions":{"screen":"messages","keys":["ff39Refresh","ff39Close"]},"system_actions":{"screen":"system","keys":["ff48Refresh","ff48Export","ff48Close"]},"driver_regions":{"screen":"driver","keys":["clockInBtn","driverOffers","driverTasks"]},"assembly_stats":{"screen":"assembly","keys":["ffV12CountAll","ffV12CountPrinted","ffV12CountPreparing","ffV12CountReady"]},"cashier_stage":{"screen":"cashier","keys":["cashier_stage"]},"staff_actions":{"screen":"staff","keys":["staffAuditRefresh"]},"customers_actions":{"screen":"customers","keys":["ff51CustomerFind","ff51CustomerNoteSave"]},"finance_actions":{"screen":"finance","keys":["ff42Load","ff42Export","ff42ClosePanel","ff42Save","ff42CloseSettlement","ff42ShowDetail"],"styleOnly":true},"finance_fields":{"screen":"finance","keys":["ff42Day","ff42Branch","ff42CashDue","ff42CashReceived","ff42Difference","ff42Notes"],"styleOnly":true},"finance_regions":{"screen":"finance","keys":["ff42Status","ff42Summary","ff42List","ff42Form","ff42Detail"],"styleOnly":true},"branches_actions":{"screen":"branches","keys":["ffA05BranchPolicyBtn","ffA05Close","ffA05SaveHours","ffA05SaveTariff","ffA05PriceHistory"],"styleOnly":true},"branches_fields":{"screen":"branches","keys":["ffA05PolicyBranch","ffA05Effective","ffA05Reason","ffA05Day","ffA05Closed","ffA05Open","ffA05CloseTime","ffA05Shift","ffA05Area","ffA05Tariff"],"styleOnly":true},"branches_regions":{"screen":"branches","keys":["ffA05PolicyStatus","ffA05PolicyCurrent","ffA05PolicyHistory","ffA05PriceRows"],"styleOnly":true},"login_actions":{"screen":"login","keys":["loginBtn","ff61ApplyToggle","ff61StatusToggle","ff71CustomerToggle","ff71CustomerSend","ff71CustomerVerify","ff61ApplySend","ff61TrackSend"],"styleOnly":true},"login_fields":{"screen":"login","keys":["email","password","ff71CustomerPhone","ff71CustomerCode","ff61TrackCode","loginStatus","ff71CustomerMessage"],"styleOnly":true},"join_fields":{"screen":"login","keys":["join_name","join_email","join_phone","join_qualification","join_address","join_age","join_marital","join_role","join_experience","join_message","ff61Consent","ff61ApplyInfo"],"styleOnly":true},"customer_portal_actions":{"screen":"customer_portal","keys":["ff28Refresh","ff28Logout"],"styleOnly":true},"customer_portal_regions":{"screen":"customer_portal","keys":["ff28Title","ff28State","ff28Rows","ff28Name","ff28Role"],"styleOnly":true}}'::jsonb; g record; old_rows jsonb; new_rows jsonb; out_rows jsonb:=coalesce(p_exact,'{}'); old_order text[]; new_order text[];
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
   WHERE (b-ARRAY['key','shape','size','orderMode']) IS DISTINCT FROM
     ((coalesce(inh.a,'{}')||coalesce(ex.a,'{}'))-ARRAY['key','shape','size','orderMode'])
  ) THEN RETURN NULL; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(new_rows) b WHERE b ? 'orderMode') AND NOT ('layout'=ANY(p_kinds)) THEN RETURN NULL; END IF;
  SELECT jsonb_agg((b.row-ARRAY['font','weight','spacing','border','shadow','tone','orderMode','icon','hover','press'])||
     (coalesce((SELECT a FROM jsonb_array_elements(coalesce(p_exact->g.key,'[]')) a WHERE a->>'key'=b.row->>'key'),'{}')-ARRAY['key','shape','size','orderMode']) || CASE WHEN NOT ('layout'=ANY(p_kinds)) AND (p_exact->g.key->0->>'orderMode'='inherit' OR p_exact->g.key IS NULL) THEN '{"orderMode":"inherit"}'::jsonb WHEN 'layout'=ANY(p_kinds) AND b.row->>'orderMode'='inherit' THEN '{"orderMode":"inherit"}'::jsonb ELSE '{}'::jsonb END ORDER BY b.ord)
  INTO new_rows FROM jsonb_array_elements(new_rows) WITH ORDINALITY b(row,ord);
  out_rows:=out_rows||jsonb_build_object(g.key,new_rows);
 END LOOP;
 RETURN out_rows;
END $function$;
CREATE OR REPLACE FUNCTION public.ff_a07_effective_designs(p_branch uuid, p_device text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE r text; b uuid:=p_branch; n integer; result jsonb;
BEGIN
 SELECT p.role::text INTO r FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active;
 IF r IS NULL OR r NOT IN ('manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen') OR p_device IS NULL OR p_device NOT IN ('mobile','desktop') THEN RAISE EXCEPTION 'غير مخول' USING ERRCODE='42501'; END IF;
 IF b IS NULL AND r NOT IN ('manager','customer_service') THEN
  SELECT count(*),min(ub.branch_id::text)::uuid INTO n,b FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid();
  IF n<>1 THEN b:=NULL; END IF;
 END IF;
 IF b IS NOT NULL AND (NOT EXISTS(SELECT 1 FROM public.ff_branches br WHERE br.id=b) OR NOT (
 public.ff_has_branch(b) OR
 (r='customer_service' AND EXISTS(SELECT 1 FROM public.ff_branches br WHERE br.id=b AND br.active)) OR
 (r='supervisor' AND NOT EXISTS(SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid()) AND EXISTS(SELECT 1 FROM public.ff_branches br WHERE br.id=b AND br.active))
 )) THEN
  RAISE EXCEPTION 'فرع غير مصرح' USING ERRCODE='42501';
 END IF;
 SELECT coalesce(jsonb_object_agg(s.screen,(to_jsonb(v)-'actor_id'-'published_by'-'draft_description'-'draft_name'-'previous_id'-'restored_from') || jsonb_build_object('style_config',ff_private.a07_style_layers(s.screen,r,b,p_device,auth.uid())->'style') || CASE WHEN s.screen='dashboard' THEN jsonb_build_object('card_layout',cards.layout,'card_layout_source',cards.revision) ELSE '{}'::jsonb END), '{}'::jsonb)
 INTO result FROM unnest(ARRAY['dashboard','orders','cashier','driver','assembly','burger_kitchen','catalog','customers','reports','staff','archive','ratings','cases','messages','reservations','system','finance','branches']) s(screen)
 CROSS JOIN LATERAL ff_private.a07_resolve(s.screen,r,b,p_device,auth.uid()) v
 LEFT JOIN LATERAL ff_private.a08_card_source(r,b,p_device,auth.uid()) cards ON s.screen='dashboard';
 RETURN result;
END $function$;
CREATE OR REPLACE FUNCTION public.ff_a07_manager_source(p_screen text, p_role text, p_branch uuid, p_device text)
 RETURNS SETOF ff_ui_versions
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active AND p.role='manager') THEN RAISE EXCEPTION 'غير مخول' USING ERRCODE='42501'; END IF;
 IF p_screen IS NULL OR p_screen NOT IN ('all','dashboard','orders','cashier','driver','assembly','burger_kitchen','catalog','customers','reports','staff','archive','ratings','cases','messages','reservations','system','finance','branches','login','customer_portal')
 OR p_role IS NULL OR (CASE WHEN p_screen IN ('login','customer_portal') THEN p_role<>'all' OR p_branch IS NOT NULL ELSE p_role NOT IN ('manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen') END)
 OR p_device IS NULL OR p_device NOT IN ('mobile','desktop')
 OR (p_branch IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.ff_branches WHERE id=p_branch)) THEN RAISE EXCEPTION 'نطاق غير صالح'; END IF;
 RETURN QUERY SELECT * FROM ff_private.a07_resolve(p_screen,p_role,p_branch,p_device,NULL);
END $function$;
CREATE OR REPLACE FUNCTION public.ff_a07_preview_scope(p_screen_scope text, p_role_scope text, p_branch_scope uuid, p_device_scope text, p_pack text, p_style jsonb, p_target_screen text, p_target_role text, p_target_branch uuid, p_target_device text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE oldrow public.ff_ui_versions; before_layers jsonb; after_layers jsonb; before_view jsonb; after_view jsonb; applies boolean; candidates jsonb; chosen_pack text;
BEGIN
 PERFORM public.ff_a07_manager_source(p_target_screen,p_target_role,p_target_branch,p_target_device);
 IF p_target_screen='all' OR p_screen_scope IS NULL OR p_screen_scope NOT IN ('all','dashboard','orders','cashier','driver','assembly','burger_kitchen','catalog','customers','reports','staff','archive','ratings','cases','messages','reservations','system','finance','branches','login','customer_portal')
 OR (p_screen_scope IN ('login','customer_portal') AND (p_role_scope IS DISTINCT FROM 'all' OR p_branch_scope IS NOT NULL))
 OR p_role_scope IS NULL OR p_role_scope NOT IN ('all','manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen')
 OR p_device_scope IS NULL OR p_device_scope NOT IN ('all','mobile','desktop')
 OR (p_branch_scope IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.ff_branches WHERE id=p_branch_scope))
 OR NOT EXISTS(SELECT 1 FROM ff_private.a07_design_packs WHERE code=p_pack)
 OR NOT ff_private.a07_valid_style(p_style) OR pg_column_size(p_style)>131072
 OR (p_style ? 'elements' AND NOT ff_private.a07_valid_elements(p_style->'elements',p_screen_scope))
 OR (p_screen_scope NOT IN ('all','dashboard') AND (p_style ? 'dashboardPanels' OR p_style ? 'quickActions'))
 THEN RAISE EXCEPTION 'نطاق أو خصائص معاينة غير صالحة' USING ERRCODE='22023'; END IF;
 SELECT * INTO oldrow FROM ff_private.a07_resolve(p_target_screen,p_target_role,p_target_branch,p_target_device,NULL);
 before_layers:=ff_private.a07_style_layers(p_target_screen,p_target_role,p_target_branch,p_target_device,NULL);
 before_view:=jsonb_build_object('pack',coalesce(oldrow.pack,'D01'),'style_config',before_layers->'style');
 applies:=(p_target_screen NOT IN ('login','customer_portal') OR p_screen_scope=p_target_screen) AND p_screen_scope IN ('all',p_target_screen) AND p_role_scope IN ('all',p_target_role)
 AND (p_branch_scope IS NULL OR p_branch_scope IS NOT DISTINCT FROM p_target_branch) AND p_device_scope IN ('all',p_target_device);
 IF NOT applies THEN RETURN jsonb_build_object('applies',false,'before',before_view,'after',before_view,'before_sources',before_layers->'sources','after_sources',before_layers->'sources'); END IF;
 WITH published AS (
  SELECT DISTINCT ON (v.screen_scope,v.role_scope,v.branch_id,v.device)
   v.id,v.style_config,v.pack,v.screen_scope,v.role_scope,v.branch_id,v.device,v.published_at
  FROM public.ff_ui_versions v
  WHERE v.published_at IS NOT NULL AND (p_target_screen NOT IN ('login','customer_portal') OR (v.screen_scope=p_target_screen AND v.role_scope='all' AND v.branch_id IS NULL)) AND v.screen_scope IN ('all',p_target_screen) AND v.role_scope IN ('all',p_target_role)
  AND (v.branch_id IS NULL OR v.branch_id=p_target_branch) AND v.device IN ('all',p_target_device)
  AND NOT(v.screen_scope=p_screen_scope AND v.role_scope=p_role_scope AND v.branch_id IS NOT DISTINCT FROM p_branch_scope AND v.device=p_device_scope)
  ORDER BY v.screen_scope,v.role_scope,v.branch_id,v.device,v.published_at DESC,v.id DESC
 ), hypothetical AS (
  SELECT * FROM published UNION ALL SELECT -1::bigint,p_style,p_pack,p_screen_scope,p_role_scope,p_branch_scope,p_device_scope,now()
 ), ranked AS (
  SELECT id AS revision,style_config AS style,pack,row_number() OVER(ORDER BY
   ((screen_scope<>'all')::int+(role_scope<>'all')::int+(branch_id IS NOT NULL)::int+(device<>'all')::int) DESC,
   (screen_scope<>'all') DESC,(role_scope<>'all') DESC,(branch_id IS NOT NULL) DESC,(device<>'all') DESC,
   (id=-1) DESC,published_at DESC,id DESC) AS rank_order FROM hypothetical
 )
 SELECT jsonb_agg(jsonb_build_object('revision',revision,'style',style,'rank_order',rank_order)),(array_agg(pack ORDER BY rank_order))[1] INTO candidates,chosen_pack FROM ranked;
 after_layers:=ff_private.a07_merge_style_candidates(p_target_screen,candidates);
 after_view:=jsonb_build_object('pack',coalesce(chosen_pack,'D01'),'style_config',after_layers->'style');
 RETURN jsonb_build_object('applies',true,'before',before_view,'after',after_view,'before_sources',before_layers->'sources','after_sources',after_layers->'sources');
END $function$;
CREATE OR REPLACE FUNCTION public.ff_a09_set_grant(p_recipient uuid, p_branch uuid, p_screen text, p_capabilities text[], p_start timestamp with time zone, p_end timestamp with time zone, p_kinds text[])
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE r text; new_id bigint; old_id bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN
  PERFORM ff_private.a09_reject_manager('grant_manage',NULL,'إدارة التفويض للمدير فقط','42501');
  RETURN NULL;
 END IF;
 SELECT a.role INTO r FROM public.ff82_manager_accounts() a WHERE a.user_id=p_recipient AND a.branch_id=p_branch;
 IF r IS NULL OR p_screen IS NULL OR p_kinds IS NULL OR cardinality(p_kinds)=0 OR array_position(p_kinds,NULL) IS NOT NULL OR NOT(p_kinds <@ ARRAY['text','colors','buttons','layout']::text[])
 OR ('text'=ANY(p_kinds) AND NOT EXISTS(SELECT 1 FROM public.ff_content_catalog c WHERE c.screen=p_screen))
 OR (p_kinds && ARRAY['colors','buttons','layout']::text[] AND p_screen NOT IN ('dashboard','orders','cashier','driver','assembly','burger_kitchen','catalog','customers','reports','staff','archive','ratings','cases','messages','reservations','system','finance','branches'))
 OR p_start IS NULL OR p_end IS NULL OR p_end<=greatest(p_start,clock_timestamp()) OR p_capabilities IS NULL OR cardinality(p_capabilities)=0 OR array_position(p_capabilities,NULL) IS NOT NULL OR NOT(p_capabilities <@ ARRAY['view','edit','preview','review']::text[]) THEN
 RAISE EXCEPTION 'تحقق من النطاق ونوع التعديل والمدة' USING ERRCODE='22023';END IF;
 LOCK TABLE public.ff82_content_grants IN SHARE ROW EXCLUSIVE MODE;
 UPDATE public.ff82_content_grants SET revoked_at=clock_timestamp(),revoked_by=auth.uid() WHERE recipient=p_recipient AND revoked_at IS NULL RETURNING id INTO old_id;
 IF old_id IS NOT NULL THEN INSERT INTO public.ff82_content_audit(actor_id,grant_id,action,outcome,reason) VALUES(auth.uid(),old_id,'revoke','allowed','replaced');END IF;
 INSERT INTO public.ff82_content_grants(recipient,role_scope,branch_id,screen,capabilities,starts_at,ends_at,granted_by,edit_kinds) VALUES(p_recipient,r,p_branch,p_screen,p_capabilities,p_start,p_end,auth.uid(),p_kinds) RETURNING id INTO new_id;
 INSERT INTO public.ff82_content_audit(actor_id,grant_id,action,outcome,reason) VALUES(auth.uid(),new_id,'grant','allowed',array_to_string(p_kinds,','));
 RETURN new_id;
END $function$;
CREATE OR REPLACE FUNCTION public.ff_ui_trial_accounts(p_id bigint)
 RETURNS TABLE(account_id uuid, account_name text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select p.user_id,p.display_name::text from public.ff_profiles p join public.ff_ui_versions v on v.id=p_id
 where exists(select from public.ff_profiles m where m.user_id=auth.uid() and m.active and m.role='manager')
 and v.screen_scope NOT IN ('login','customer_portal') and v.published_at is null and p.active and (v.role_scope='all' or p.role::text=v.role_scope)
 and (v.branch_id is null or p.role='manager' or exists(select from public.ff_user_branches b
 where b.user_id=p.user_id and b.branch_id=v.branch_id)) order by p.display_name,p.user_id
$function$;
CREATE OR REPLACE FUNCTION public.ff_a07_public_appearance(p_screen text,p_device text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $public_design$
DECLARE v public.ff_ui_versions; styles jsonb;
BEGIN
 IF p_screen IS NULL OR p_screen NOT IN ('login','customer_portal') OR p_device IS NULL OR p_device NOT IN ('mobile','desktop') THEN RAISE EXCEPTION 'نطاق عام غير صالح' USING ERRCODE='22023'; END IF;
 SELECT * INTO v FROM ff_private.a07_resolve(p_screen,'all',NULL,p_device,NULL);
 IF v.id IS NULL THEN RETURN '{}'::jsonb;END IF;
 styles:=ff_private.a07_style_layers(p_screen,'all',NULL,p_device,NULL)->'style';
 RETURN jsonb_build_object('pack',v.pack,'layout_text',v.layout_text,'style_config',styles);
END $public_design$;
REVOKE ALL ON FUNCTION public.ff_a07_public_appearance(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ff_a07_public_appearance(text,text) TO anon,authenticated;
