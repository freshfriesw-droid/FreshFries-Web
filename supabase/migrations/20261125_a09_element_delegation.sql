-- A09 granular element property edits preserve existing ordering and appearance unless granted separately.

CREATE OR REPLACE FUNCTION ff_private.a09_merge_elements(p_screen text,p_exact jsonb,p_inherited jsonb,p_patch jsonb,p_kinds text[])
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
DECLARE spec jsonb:='{"dashboard_actions":{"screen":"dashboard","keys":["ffx-hero-new","ffx-hero-reserve","ffx-hero-overdue"]},"orders_actions":{"screen":"orders","keys":["createBtn","ffA06DiscardDraft","ffReserveBottom"]},"driver_actions":{"screen":"driver","keys":["ff51BreakBtn","clockInBtn","clockOutBtn"]},"assembly_actions":{"screen":"assembly","keys":["ffV12Toggle","ffV12Refresh","ffV12BurgerOpen","ffV12Logout"]},"burger_actions":{"screen":"burger_kitchen","keys":["ffBurgerKitchenNotifications","ffBurgerViewFinished","ffBurgerKitchenRefresh","ffBurgerKitchenLogout"]},"catalog_actions":{"screen":"catalog","keys":["ff51ItemSave","ff51ItemReset"]},"catalog_offers":{"screen":"catalog","keys":["ff51OfferSave","ff51OfferReset"]},"archive_actions":{"screen":"archive","keys":["ff51ArchiveRefresh","ff51ArchiveExport","ff51ArchiveClose"]},"ratings_actions":{"screen":"ratings","keys":["ff51RatingsRefresh","ff51RatingsClose"]},"reservations_actions":{"screen":"reservations","keys":["ff49ReservationsRefresh","ff49ReservationsClose"]},"cases_actions":{"screen":"cases","keys":["ff41Refresh","ff41Close"]},"messages_actions":{"screen":"messages","keys":["ff39Refresh","ff39Close"]},"system_actions":{"screen":"system","keys":["ff48Refresh","ff48Export","ff48Close"]},"driver_regions":{"screen":"driver","keys":["clockInBtn","driverOffers","driverTasks"]},"assembly_stats":{"screen":"assembly","keys":["ffV12CountAll","ffV12CountPrinted","ffV12CountPreparing","ffV12CountReady"]},"cashier_stage":{"screen":"cashier","keys":["cashier_stage"]},"staff_actions":{"screen":"staff","keys":["staffAuditRefresh"]},"customers_actions":{"screen":"customers","keys":["ff51CustomerFind","ff51CustomerNoteSave"]}}'::jsonb; g record; old_rows jsonb; new_rows jsonb; out_rows jsonb:=coalesce(p_exact,'{}'); old_order text[]; new_order text[];
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
  out_rows:=out_rows||jsonb_build_object(g.key,new_rows);
 END LOOP;
 RETURN out_rows;
END $$;
REVOKE ALL ON FUNCTION ff_private.a09_merge_elements(text,jsonb,jsonb,jsonb,text[]) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.ff_a09_design_context(p_device text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE g public.ff82_content_grants; v public.ff_ui_versions; style jsonb;
BEGIN
 SELECT * INTO g FROM public.ff82_my_grant();
 IF g.id IS NULL OR p_device IS NULL OR p_device NOT IN ('all','mobile','desktop') OR NOT(g.edit_kinds && ARRAY['colors','buttons','layout']::text[]) THEN RETURN NULL; END IF;
 SELECT * INTO v FROM ff_private.a07_resolve(g.screen,g.role_scope,g.branch_id,p_device,NULL);
 style:=ff_private.a07_style_layers(g.screen,g.role_scope,g.branch_id,p_device,NULL)->'style';
 RETURN jsonb_build_object('id',v.id,'pack',coalesce(v.pack,'D01'),'style_config',coalesce(style,'{}'),'screen',g.screen);
END $$;
REVOKE ALL ON FUNCTION public.ff_a09_design_context(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a09_design_context(text) TO authenticated;
CREATE OR REPLACE FUNCTION public.ff_a09_design_draft(p_device text, p_patch jsonb, p_name text, p_base bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE g public.ff82_content_grants; v public.ff_ui_versions; effective public.ff_ui_versions; prior bigint; revision bigint; why text; k text; allowed text[]:='{}'; merged jsonb; inherited jsonb; element_config jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'reason','authentication');END IF;
 LOCK TABLE public.ff82_content_grants IN SHARE MODE;
 SELECT * INTO g FROM public.ff82_my_grant();
 IF g.id IS NULL OR NOT('edit'=ANY(g.capabilities)) OR NOT(g.edit_kinds && ARRAY['colors','buttons','layout']::text[]) THEN why:='outside_edit_scope';
 ELSIF p_device IS NULL OR p_device NOT IN ('all','mobile','desktop') OR jsonb_typeof(p_patch) IS DISTINCT FROM 'object' OR p_patch='{}' OR NOT ff_private.a07_valid_style(p_patch) OR NOT public.ff83_valid_content('design.name',p_name) OR p_name IS NULL OR length(btrim(p_name))>80 THEN why:='invalid_design';
 ELSE
  IF 'colors'=ANY(g.edit_kinds) THEN allowed:=allowed||ARRAY['accent','surface','border','shadow'];END IF;
  IF 'buttons'=ANY(g.edit_kinds) THEN allowed:=allowed||ARRAY['button','iconSize'];END IF;
  IF 'layout'=ANY(g.edit_kinds) THEN allowed:=allowed||ARRAY['layout','density','radius','scale','font','weight','logoSize','logoAlign'];END IF;
  IF g.edit_kinds && ARRAY['buttons','layout']::text[] THEN allowed:=allowed||ARRAY['elements'];END IF;
  IF 'layout'=ANY(g.edit_kinds) AND g.screen='dashboard' THEN allowed:=allowed||ARRAY['dashboardPanels','quickActions'];END IF;
  IF EXISTS(SELECT 1 FROM jsonb_object_keys(p_patch) k0 WHERE NOT(k0=ANY(allowed))) THEN why:='outside_edit_kind';END IF;
  SELECT * INTO v FROM public.ff_ui_versions WHERE screen_scope=g.screen AND role_scope=g.role_scope AND branch_id=g.branch_id AND device=p_device AND published_at IS NOT NULL ORDER BY published_at DESC,id DESC LIMIT 1;
  prior:=v.id;
  IF p_base IS NOT NULL THEN
   SELECT * INTO v FROM public.ff_ui_versions WHERE id=p_base AND actor_id=auth.uid() AND published_at IS NULL AND screen_scope=g.screen AND role_scope=g.role_scope AND branch_id=g.branch_id AND device=p_device AND previous_id IS NOT DISTINCT FROM prior AND EXISTS(SELECT 1 FROM public.ff82_content_audit a WHERE a.design_revision=p_base AND a.grant_id=g.id AND a.actor_id=auth.uid() AND a.action='design_draft' AND a.outcome='allowed');
   IF v.id IS NULL THEN why:='stale_or_foreign_draft';END IF;
  END IF;
  IF why IS NULL THEN
   SELECT * INTO effective FROM ff_private.a07_resolve(g.screen,g.role_scope,g.branch_id,p_device,NULL);
   merged:=coalesce(v.style_config,'{}')||(p_patch-'elements');
   IF p_patch ? 'elements' THEN
    inherited:=ff_private.a07_style_layers(g.screen,g.role_scope,g.branch_id,p_device,NULL)->'style'->'elements';
    element_config:=ff_private.a09_merge_elements(g.screen,v.style_config->'elements',inherited,p_patch->'elements',g.edit_kinds);
    IF element_config IS NULL THEN why:='outside_element_kind'; ELSE merged:=merged||jsonb_build_object('elements',element_config);END IF;
   END IF;
   IF why IS NULL THEN
   BEGIN
    INSERT INTO public.ff_ui_versions(screen_scope,role_scope,branch_id,device,pack,layout_text,bar,actor_id,previous_id,style_config,card_layout,draft_name,draft_description)
    VALUES(g.screen,g.role_scope,g.branch_id,p_device,coalesce(v.pack,effective.pack,'D01'),coalesce(v.layout_text,effective.layout_text,''),coalesce(v.bar,effective.bar,'labels'),auth.uid(),prior,merged,v.card_layout,btrim(p_name),'مسودة مفوضة للمراجعة') RETURNING id INTO revision;
   EXCEPTION WHEN check_violation OR foreign_key_violation THEN why:='invalid_design';END;
   END IF;
  END IF;
 END IF;
 INSERT INTO public.ff82_content_audit(actor_id,grant_id,action,outcome,reason,design_revision) VALUES(auth.uid(),g.id,'design_draft',CASE WHEN why IS NULL THEN 'allowed' ELSE 'denied' END,coalesce(why,''),revision);
 RETURN jsonb_build_object('ok',why IS NULL,'reason',why,'revision',revision);
END $function$;
