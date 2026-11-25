-- A07 / DEC-03, DEC-04: additive screen-scoped design versions.
-- Existing versions keep their historical dashboard-only scope.
ALTER TABLE public.ff_ui_versions ADD COLUMN IF NOT EXISTS screen_scope text NOT NULL DEFAULT 'dashboard';
ALTER TABLE public.ff_ui_versions ADD COLUMN IF NOT EXISTS style_config jsonb NOT NULL DEFAULT '{}'::jsonb;
CREATE OR REPLACE FUNCTION ff_private.a07_valid_style(v jsonb) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
SELECT CASE WHEN jsonb_typeof(v)<>'object' OR v IS NULL THEN false ELSE
  NOT EXISTS(SELECT 1 FROM jsonb_each(v) e WHERE NOT CASE e.key
  WHEN 'font' THEN e.value IN ('"system"'::jsonb,'"tahoma"'::jsonb,'"serif"'::jsonb)
  WHEN 'scale' THEN e.value IN ('"normal"'::jsonb,'"large"'::jsonb,'"xlarge"'::jsonb)
  WHEN 'density' THEN e.value IN ('"normal"'::jsonb,'"compact"'::jsonb,'"spacious"'::jsonb)
  WHEN 'radius' THEN e.value IN ('"pack"'::jsonb,'"square"'::jsonb,'"round"'::jsonb)
  WHEN 'button' THEN e.value IN ('"pack"'::jsonb,'"square"'::jsonb,'"round"'::jsonb,'"pill"'::jsonb)
  WHEN 'shadow' THEN e.value IN ('"pack"'::jsonb,'"none"'::jsonb,'"soft"'::jsonb)
  WHEN 'logoSize' THEN e.value IN ('"normal"'::jsonb,'"small"'::jsonb,'"large"'::jsonb)
  WHEN 'logoAlign' THEN e.value IN ('"start"'::jsonb,'"center"'::jsonb,'"end"'::jsonb)
  ELSE false END) END;
$$;
ALTER TABLE public.ff_ui_versions ADD CONSTRAINT ff_a07_screen_valid CHECK(screen_scope IN ('all','dashboard','orders','cashier','driver','assembly','burger_kitchen','catalog','customers','reports','staff','archive','ratings','cases','messages','reservations','system'));
ALTER TABLE public.ff_ui_versions ADD CONSTRAINT ff_a07_style_valid CHECK(ff_private.a07_valid_style(style_config));
CREATE INDEX IF NOT EXISTS ff_a07_design_scope_idx ON public.ff_ui_versions(screen_scope,role_scope,branch_id,device,published_at DESC,id DESC);
-- Resolver inaccessible to API roles; callers validate active account and branch.
CREATE OR REPLACE FUNCTION ff_private.a07_resolve(p_screen text,p_role text,p_branch uuid,p_device text,p_actor uuid)
RETURNS SETOF public.ff_ui_versions LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT v.* FROM public.ff_ui_versions v
 LEFT JOIN LATERAL (SELECT max(t.started_at) AS started_at FROM public.ff_ui_trials t
  WHERE t.version_id=v.id AND t.recipient=p_actor AND t.stopped_at IS NULL AND t.ends_at>now() AND v.published_at IS NULL) trial ON true
 WHERE (v.published_at IS NOT NULL OR trial.started_at IS NOT NULL)
 AND v.screen_scope IN ('all',p_screen) AND v.role_scope IN ('all',p_role)
 AND (v.branch_id IS NULL OR v.branch_id=p_branch) AND v.device IN ('all',p_device)
 ORDER BY (trial.started_at IS NOT NULL) DESC,
 ((v.screen_scope<>'all')::int+(v.role_scope<>'all')::int+(v.branch_id IS NOT NULL)::int+(v.device<>'all')::int) DESC,
 (v.screen_scope<>'all') DESC,(v.role_scope<>'all') DESC,(v.branch_id IS NOT NULL) DESC,(v.device<>'all') DESC,
 coalesce(trial.started_at,v.published_at) DESC,v.id DESC LIMIT 1
$$;
REVOKE ALL ON FUNCTION ff_private.a07_resolve(text,text,uuid,text,uuid) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.ff_a07_effective_designs(p_branch uuid,p_device text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE r text; b uuid:=p_branch; n integer; result jsonb;
BEGIN
 SELECT p.role::text INTO r FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active;
 IF r IS NULL OR p_device IS NULL OR p_device NOT IN ('mobile','desktop') THEN RAISE EXCEPTION 'غير مخول' USING ERRCODE='42501'; END IF;
 IF b IS NULL AND r<>'manager' THEN
  SELECT count(*),min(ub.branch_id::text)::uuid INTO n,b FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid();
  IF n<>1 THEN b:=NULL; END IF;
 END IF;
 IF b IS NOT NULL AND (NOT EXISTS(SELECT 1 FROM public.ff_branches br WHERE br.id=b) OR NOT public.ff_has_branch(b)) THEN
  RAISE EXCEPTION 'فرع غير مصرح' USING ERRCODE='42501';
 END IF;
 SELECT coalesce(jsonb_object_agg(s.screen,to_jsonb(v)-'actor_id'-'published_by'-'draft_description'-'draft_name'-'previous_id'-'restored_from'), '{}'::jsonb)
 INTO result FROM unnest(ARRAY['dashboard','orders','cashier','driver','assembly','burger_kitchen','catalog','customers','reports','staff','archive','ratings','cases','messages','reservations','system']) s(screen)
 CROSS JOIN LATERAL ff_private.a07_resolve(s.screen,r,b,p_device,auth.uid()) v;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.ff_a07_manager_source(p_screen text,p_role text,p_branch uuid,p_device text)
RETURNS SETOF public.ff_ui_versions LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active AND p.role='manager') THEN RAISE EXCEPTION 'غير مخول' USING ERRCODE='42501'; END IF;
 IF p_screen IS NULL OR p_screen NOT IN ('all','dashboard','orders','cashier','driver','assembly','burger_kitchen','catalog','customers','reports','staff','archive','ratings','cases','messages','reservations','system')
 OR p_role IS NULL OR p_role NOT IN ('manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen')
 OR p_device IS NULL OR p_device NOT IN ('mobile','desktop')
 OR (p_branch IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.ff_branches WHERE id=p_branch)) THEN RAISE EXCEPTION 'نطاق غير صالح'; END IF;
 RETURN QUERY SELECT * FROM ff_private.a07_resolve(p_screen,p_role,p_branch,p_device,NULL);
END $$;
CREATE OR REPLACE FUNCTION ff_private.a07_save_design(p_screen text,p_role text,p_branch uuid,p_device text,p_pack text,p_text text,p_bar text,p_restore bigint)
RETURNS bigint LANGUAGE plpgsql SET search_path='' AS $$
DECLARE new_id bigint; prior bigint; old public.ff_ui_versions;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN RAISE EXCEPTION 'غير مخول' USING ERRCODE='42501'; END IF;
 IF p_restore IS NOT NULL THEN
  SELECT * INTO STRICT old FROM public.ff_ui_versions WHERE id=p_restore AND published_at IS NOT NULL;
  p_screen:=old.screen_scope;p_role:=old.role_scope;p_branch:=old.branch_id;p_device:=old.device;p_pack:=old.pack;p_text:=old.layout_text;p_bar:=old.bar;
 END IF;
 SELECT id INTO prior FROM public.ff_ui_versions WHERE screen_scope=p_screen AND role_scope=p_role AND branch_id IS NOT DISTINCT FROM p_branch AND device=p_device AND published_at IS NOT NULL ORDER BY published_at DESC,id DESC LIMIT 1;
 INSERT INTO public.ff_ui_versions(screen_scope,role_scope,branch_id,device,pack,layout_text,bar,actor_id,previous_id,restored_from,style_config)
 VALUES(p_screen,p_role,p_branch,p_device,p_pack,p_text,p_bar,auth.uid(),prior,p_restore,coalesce(old.style_config,'{}')) RETURNING id INTO new_id;
 RETURN new_id;
END $$;
REVOKE ALL ON FUNCTION ff_private.a07_save_design(text,text,uuid,text,text,text,text,bigint) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.ff_a07_named_design(p_screen text,p_role text,p_branch uuid,p_device text,p_pack text,p_text text,p_bar text,p_name text,p_description text,p_cards jsonb,p_style jsonb)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE revision bigint;
BEGIN
 IF nullif(trim(p_name),'') IS NULL OR NOT public.ff81_validate_cards(p_cards) OR NOT ff_private.a07_valid_style(p_style) THEN RAISE EXCEPTION 'مسودة أو خصائص غير صالحة'; END IF;
 revision:=ff_private.a07_save_design(p_screen,p_role,p_branch,p_device,p_pack,p_text,p_bar,NULL);
 UPDATE public.ff_ui_versions SET draft_name=trim(p_name),draft_description=trim(p_description),card_layout=p_cards,style_config=p_style WHERE id=revision AND published_at IS NULL;
 RETURN revision;
END $$;
-- Backward-compatible legacy RPCs. Old clients still write dashboard scope.
CREATE OR REPLACE FUNCTION public.ff_ui_save_draft(p_role text,p_branch uuid,p_device text,p_pack text,p_text text,p_bar text,p_restore bigint DEFAULT NULL)
RETURNS bigint LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT ff_private.a07_save_design('dashboard',p_role,p_branch,p_device,p_pack,p_text,p_bar,p_restore)
$$;
CREATE OR REPLACE FUNCTION public.ff_ui_effective(p_branch uuid,p_device text)
RETURNS TABLE(id bigint,pack text,layout_text text,bar text) LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT (v->>'id')::bigint,v->>'pack',v->>'layout_text',v->>'bar'
 FROM (SELECT public.ff_a07_effective_designs(p_branch,p_device)->'dashboard' v) s WHERE v IS NOT NULL
$$;
CREATE OR REPLACE FUNCTION public.ff_ui_manager_source(p_role text,p_branch uuid,p_device text)
RETURNS TABLE(id bigint,role_scope text,branch_id uuid,device text,pack text,layout_text text,bar text,published_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT v.id,v.role_scope,v.branch_id,v.device,v.pack,v.layout_text,v.bar,v.published_at
 FROM public.ff_a07_manager_source('dashboard',p_role,p_branch,p_device) v
$$;
CREATE OR REPLACE FUNCTION public.ff_ui_publish(p_id bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE draft public.ff_ui_versions; prior bigint;
BEGIN
 IF NOT EXISTS(SELECT FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN RAISE EXCEPTION 'غير مخول' USING ERRCODE='42501';END IF;
 LOCK TABLE public.ff_ui_versions IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO STRICT draft FROM public.ff_ui_versions WHERE id=p_id;
 IF draft.published_at IS NOT NULL THEN RETURN; END IF;
 SELECT id INTO prior FROM public.ff_ui_versions WHERE screen_scope=draft.screen_scope AND role_scope=draft.role_scope AND branch_id IS NOT DISTINCT FROM draft.branch_id AND device=draft.device AND published_at IS NOT NULL ORDER BY published_at DESC,id DESC LIMIT 1;
 IF prior IS DISTINCT FROM draft.previous_id THEN RAISE EXCEPTION 'تغير الإصدار المنشور. راجع التعديلات واحفظ مسودة جديدة'; END IF;
 UPDATE public.ff_ui_versions SET published_by=auth.uid(),published_at=clock_timestamp() WHERE id=p_id;
END $$;
CREATE OR REPLACE FUNCTION public.ff_ui_rollback(p_current bigint)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE active_release public.ff_ui_versions; previous_release public.ff_ui_versions; revision bigint;
BEGIN
 IF NOT EXISTS(SELECT FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN RAISE EXCEPTION 'الاستعادة للمدير العام فقط' USING ERRCODE='42501'; END IF;
 LOCK TABLE public.ff_ui_versions IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO STRICT active_release FROM public.ff_ui_versions WHERE id=p_current AND published_at IS NOT NULL;
 IF active_release.previous_id IS NULL THEN RAISE EXCEPTION 'لا يوجد إصدار سابق لهذا النطاق'; END IF;
 IF EXISTS(SELECT FROM public.ff_ui_versions v WHERE v.screen_scope=active_release.screen_scope AND v.role_scope=active_release.role_scope AND v.branch_id IS NOT DISTINCT FROM active_release.branch_id AND v.device=active_release.device AND (v.published_at,v.id)>(active_release.published_at,active_release.id)) THEN RAISE EXCEPTION 'تغير الإصدار النشط، حدّث السجل'; END IF;
 SELECT * INTO STRICT previous_release FROM public.ff_ui_versions WHERE id=active_release.previous_id;
 revision:=public.ff_ui_save_draft(previous_release.role_scope,previous_release.branch_id,previous_release.device,previous_release.pack,previous_release.layout_text,previous_release.bar,previous_release.id);
 UPDATE public.ff_ui_versions SET draft_name=previous_release.draft_name,draft_description=previous_release.draft_description WHERE id=revision;
 PERFORM public.ff_ui_publish(revision); RETURN revision;
END $$;
REVOKE ALL ON FUNCTION public.ff_a07_effective_designs(uuid,text),public.ff_a07_manager_source(text,text,uuid,text),public.ff_a07_named_design(text,text,uuid,text,text,text,text,text,text,jsonb,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a07_effective_designs(uuid,text),public.ff_a07_manager_source(text,text,uuid,text),public.ff_a07_named_design(text,text,uuid,text,text,text,text,text,text,jsonb,jsonb) TO authenticated;
