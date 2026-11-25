-- STEP07: extend existing scoped grants; no operational permissions or publishing.
ALTER TABLE public.ff82_content_grants DROP CONSTRAINT ff82_content_grants_edit_kinds_check;
ALTER TABLE public.ff82_content_grants ADD CONSTRAINT ff82_content_grants_edit_kinds_check CHECK (cardinality(edit_kinds)>0 AND array_position(edit_kinds,NULL) IS NULL AND edit_kinds <@ ARRAY['text','colors','buttons','layout','design','fonts','identity','media','cards']::text[]);

CREATE OR REPLACE FUNCTION public.ff_a09_design_context(p_device text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE g public.ff82_content_grants; v public.ff_ui_versions; style jsonb;
BEGIN
 SELECT * INTO g FROM public.ff82_my_grant();
 IF g.id IS NULL OR p_device IS NULL OR p_device NOT IN ('all','mobile','desktop') OR NOT(g.edit_kinds && ARRAY['colors','buttons','layout','design','fonts','identity','media','cards']::text[]) THEN RETURN NULL; END IF;
 SELECT * INTO v FROM ff_private.a07_resolve(g.screen,g.role_scope,g.branch_id,p_device,NULL);
 style:=ff_private.a07_style_layers(g.screen,g.role_scope,g.branch_id,p_device,NULL)->'style';
 RETURN jsonb_build_object('id',v.id,'pack',coalesce(v.pack,'D01'),'style_config',coalesce(style,'{}'),'screen',g.screen,'bar',coalesce(v.bar,'labels'),'card_layout',v.card_layout);
END $function$;

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
 IF g.id IS NULL OR NOT('edit'=ANY(g.capabilities)) OR NOT(g.edit_kinds && ARRAY['colors','buttons','layout','design','fonts','identity','media','cards']::text[]) THEN why:='outside_edit_scope';
 ELSIF p_device IS NULL OR p_device NOT IN ('all','mobile','desktop') OR jsonb_typeof(p_patch) IS DISTINCT FROM 'object' OR p_patch='{}' OR NOT ff_private.a07_valid_style(p_patch-ARRAY['designPack','designBar','cardLayout']) OR NOT public.ff83_valid_content('design.name',p_name) OR p_name IS NULL OR length(btrim(p_name))>80 THEN why:='invalid_design';
 ELSE
  IF 'colors'=ANY(g.edit_kinds) THEN allowed:=allowed||ARRAY['accent','surface','border','shadow'];END IF;
  IF 'buttons'=ANY(g.edit_kinds) THEN allowed:=allowed||ARRAY['button','iconSize'];END IF;
  IF 'layout'=ANY(g.edit_kinds) THEN allowed:=allowed||ARRAY['layout','density','radius','scale','font','weight','logoSize','logoAlign','designBar','dialogRadius','dialogPadding','ratingScale'];END IF;
  IF 'fonts'=ANY(g.edit_kinds) THEN allowed:=allowed||ARRAY['font','scale','weight'];END IF;
  IF 'identity'=ANY(g.edit_kinds) THEN allowed:=allowed||ARRAY['logoSize','logoAlign','logoWidth','logoPosition'];END IF;
  IF 'media'=ANY(g.edit_kinds) THEN allowed:=allowed||ARRAY['logoAsset','logoDarkAsset'];END IF;
  IF 'design'=ANY(g.edit_kinds) THEN allowed:=allowed||ARRAY['designPack'];END IF;
  IF g.edit_kinds && ARRAY['buttons','layout']::text[] THEN allowed:=allowed||ARRAY['elements'];END IF;
  IF 'layout'=ANY(g.edit_kinds) AND g.screen='dashboard' THEN allowed:=allowed||ARRAY['dashboardPanels','quickActions'];END IF;
  IF 'cards'=ANY(g.edit_kinds) AND g.screen='dashboard' THEN allowed:=allowed||ARRAY['dashboardPanels','cardLayout'];END IF;
  IF 'buttons'=ANY(g.edit_kinds) AND g.screen='dashboard' THEN allowed:=allowed||ARRAY['quickActions'];END IF;
  IF EXISTS(SELECT 1 FROM jsonb_object_keys(p_patch) k0 WHERE NOT(k0=ANY(allowed))) THEN why:='outside_edit_kind';
  ELSIF p_patch ? 'designPack' AND (jsonb_typeof(p_patch->'designPack') IS DISTINCT FROM 'string' OR NOT EXISTS(SELECT 1 FROM ff_private.a07_design_packs WHERE code=p_patch->>'designPack')) THEN why:='invalid_design_pack';
  ELSIF p_patch ? 'designBar' AND (jsonb_typeof(p_patch->'designBar') IS DISTINCT FROM 'string' OR (p_patch->>'designBar') NOT IN ('labels','icons','wide','floating','compact')) THEN why:='invalid_design_bar';
  ELSIF p_patch ? 'cardLayout' AND (jsonb_typeof(p_patch->'cardLayout') IS DISTINCT FROM 'array' OR NOT public.ff81_validate_cards(p_patch->'cardLayout')) THEN why:='invalid_card_layout';
  END IF;
  SELECT * INTO v FROM public.ff_ui_versions WHERE screen_scope=g.screen AND role_scope=g.role_scope AND branch_id=g.branch_id AND device=p_device AND published_at IS NOT NULL ORDER BY published_at DESC,id DESC LIMIT 1;
  prior:=v.id;
  IF p_base IS NOT NULL THEN
   SELECT * INTO v FROM public.ff_ui_versions WHERE id=p_base AND actor_id=auth.uid() AND published_at IS NULL AND screen_scope=g.screen AND role_scope=g.role_scope AND branch_id=g.branch_id AND device=p_device AND previous_id IS NOT DISTINCT FROM prior AND EXISTS(SELECT 1 FROM public.ff82_content_audit a WHERE a.design_revision=p_base AND a.grant_id=g.id AND a.actor_id=auth.uid() AND a.action='design_draft' AND a.outcome='allowed');
   IF v.id IS NULL THEN why:='stale_or_foreign_draft';END IF;
  END IF;
  IF why IS NULL THEN
   SELECT * INTO effective FROM ff_private.a07_resolve(g.screen,g.role_scope,g.branch_id,p_device,NULL);
   merged:=coalesce(v.style_config,'{}')||(p_patch-ARRAY['elements','designPack','designBar','cardLayout']);
   IF p_patch ? 'elements' THEN
    inherited:=ff_private.a07_style_layers(g.screen,g.role_scope,g.branch_id,p_device,NULL)->'style'->'elements';
    element_config:=ff_private.a09_merge_elements(g.screen,v.style_config->'elements',inherited,p_patch->'elements',g.edit_kinds);
    IF element_config IS NULL THEN why:='outside_element_kind'; ELSE merged:=merged||jsonb_build_object('elements',element_config);END IF;
   END IF;
   IF why IS NULL THEN
   BEGIN
    INSERT INTO public.ff_ui_versions(screen_scope,role_scope,branch_id,device,pack,layout_text,bar,actor_id,previous_id,style_config,card_layout,draft_name,draft_description)
    VALUES(g.screen,g.role_scope,g.branch_id,p_device,coalesce(p_patch->>'designPack',v.pack,effective.pack,'D01'),coalesce(v.layout_text,effective.layout_text,''),coalesce(p_patch->>'designBar',v.bar,effective.bar,'labels'),auth.uid(),prior,merged,coalesce(p_patch->'cardLayout',v.card_layout),btrim(p_name),'مسودة مفوضة للمراجعة') RETURNING id INTO revision;
   EXCEPTION WHEN check_violation OR foreign_key_violation THEN why:='invalid_design';END;
   END IF;
  END IF;
 END IF;
 INSERT INTO public.ff82_content_audit(actor_id,grant_id,action,outcome,reason,design_revision,attempted_revision,effect) VALUES(auth.uid(),g.id,'design_draft',CASE WHEN why IS NULL THEN 'allowed' ELSE 'denied' END,coalesce(why,''),revision,p_base,CASE WHEN why IS NULL THEN 'draft_only' ELSE 'no_change' END);
 RETURN jsonb_build_object('ok',why IS NULL,'reason',why,'revision',revision);
END $function$;

CREATE OR REPLACE FUNCTION public.ff_a09_design_history(p_device text)
 RETURNS SETOF ff_ui_versions
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT v.* FROM public.ff_ui_versions v JOIN public.ff82_my_grant() g ON v.screen_scope=g.screen AND v.role_scope=g.role_scope AND v.branch_id=g.branch_id
 WHERE g.edit_kinds && ARRAY['colors','buttons','layout','design','fonts','identity','media','cards']::text[] AND v.device=p_device AND (v.published_at IS NOT NULL OR v.actor_id=auth.uid() OR 'review'=ANY(g.capabilities)) ORDER BY v.id DESC LIMIT 100
$function$;

CREATE OR REPLACE FUNCTION public.ff_a09_design_review(p_revision bigint, p_note text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE g public.ff82_content_grants; v public.ff_ui_versions; why text;
BEGIN
 IF auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'reason','authentication');END IF;
 LOCK TABLE public.ff82_content_grants IN SHARE MODE;
 SELECT * INTO g FROM public.ff82_my_grant();
 SELECT * INTO v FROM public.ff_ui_versions WHERE id=p_revision;
 IF g.id IS NULL OR NOT('review'=ANY(g.capabilities)) OR NOT(g.edit_kinds && ARRAY['colors','buttons','layout','design','fonts','identity','media','cards']::text[]) OR v.id IS NULL OR v.published_at IS NOT NULL OR v.screen_scope<>g.screen OR v.role_scope<>g.role_scope OR v.branch_id IS DISTINCT FROM g.branch_id THEN why:='outside_review_scope';
 ELSIF p_note IS NULL OR length(btrim(p_note)) NOT BETWEEN 1 AND 500 OR NOT public.ff83_valid_content('orders.guidance',p_note) THEN why:='invalid_note';END IF;
 INSERT INTO public.ff82_content_audit(actor_id,grant_id,action,outcome,reason,design_revision,attempted_revision,effect) VALUES(auth.uid(),g.id,'design_review',CASE WHEN why IS NULL THEN 'allowed' ELSE 'denied' END,coalesce(why,btrim(p_note)),CASE WHEN why IS NULL THEN v.id END,p_revision,CASE WHEN why IS NULL THEN 'review_only' ELSE 'no_change' END);
 RETURN jsonb_build_object('ok',why IS NULL,'reason',why);
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
 IF r IS NULL OR p_screen IS NULL OR p_kinds IS NULL OR cardinality(p_kinds)=0 OR array_position(p_kinds,NULL) IS NOT NULL OR NOT(p_kinds <@ ARRAY['text','colors','buttons','layout','design','fonts','identity','media','cards']::text[])
 OR ('text'=ANY(p_kinds) AND NOT EXISTS(SELECT 1 FROM public.ff_content_catalog c WHERE c.screen=p_screen))
 OR (p_kinds && ARRAY['colors','buttons','layout','design','fonts','identity','media','cards']::text[] AND p_screen NOT IN ('dashboard','orders','cashier','driver','assembly','burger_kitchen','catalog','customers','reports','staff','archive','ratings','cases','messages','reservations','system','finance','branches'))
 OR ('cards'=ANY(p_kinds) AND p_screen<>'dashboard')
 OR p_start IS NULL OR p_end IS NULL OR p_end<=greatest(p_start,clock_timestamp()) OR p_capabilities IS NULL OR cardinality(p_capabilities)=0 OR array_position(p_capabilities,NULL) IS NOT NULL OR NOT(p_capabilities <@ ARRAY['view','edit','preview','review']::text[]) THEN
 RAISE EXCEPTION 'تحقق من النطاق ونوع التعديل والمدة' USING ERRCODE='22023';END IF;
 LOCK TABLE public.ff82_content_grants IN SHARE ROW EXCLUSIVE MODE;
 UPDATE public.ff82_content_grants SET revoked_at=clock_timestamp(),revoked_by=auth.uid() WHERE recipient=p_recipient AND revoked_at IS NULL RETURNING id INTO old_id;
 IF old_id IS NOT NULL THEN INSERT INTO public.ff82_content_audit(actor_id,grant_id,action,outcome,reason) VALUES(auth.uid(),old_id,'revoke','allowed','replaced');END IF;
 INSERT INTO public.ff82_content_grants(recipient,role_scope,branch_id,screen,capabilities,starts_at,ends_at,granted_by,edit_kinds) VALUES(p_recipient,r,p_branch,p_screen,p_capabilities,p_start,p_end,auth.uid(),p_kinds) RETURNING id INTO new_id;
 INSERT INTO public.ff82_content_audit(actor_id,grant_id,action,outcome,reason) VALUES(auth.uid(),new_id,'grant','allowed',array_to_string(p_kinds,','));
 RETURN new_id;
END $function$;
