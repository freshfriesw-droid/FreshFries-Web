
-- A07 property inheritance: only latest candidate per exact scope participates.
CREATE OR REPLACE FUNCTION ff_private.a07_ranked_candidates(p_screen text,p_role text,p_branch uuid,p_device text,p_actor uuid)
RETURNS TABLE(revision bigint,style jsonb,rank_order bigint)
LANGUAGE sql STABLE SET search_path='' AS $$
 WITH scoped AS (
 SELECT DISTINCT ON (v.screen_scope,v.role_scope,v.branch_id,v.device)
   v.id,v.style_config,v.screen_scope,v.role_scope,v.branch_id,v.device,v.published_at,trial.started_at
 FROM public.ff_ui_versions v
 LEFT JOIN LATERAL (SELECT max(t.started_at) AS started_at FROM public.ff_ui_trials t
  WHERE t.version_id=v.id AND t.recipient=p_actor AND t.stopped_at IS NULL AND t.ends_at>now() AND v.published_at IS NULL) trial ON true
 WHERE (v.published_at IS NOT NULL OR trial.started_at IS NOT NULL)
 AND v.screen_scope IN ('all',p_screen) AND v.role_scope IN ('all',p_role)
 AND (v.branch_id IS NULL OR v.branch_id=p_branch) AND v.device IN ('all',p_device)
 ORDER BY v.screen_scope,v.role_scope,v.branch_id,v.device,(trial.started_at IS NOT NULL) DESC,coalesce(trial.started_at,v.published_at) DESC,v.id DESC
 )
 SELECT id,style_config,row_number() OVER(ORDER BY (started_at IS NOT NULL) DESC,
 ((screen_scope<>'all')::int+(role_scope<>'all')::int+(branch_id IS NOT NULL)::int+(device<>'all')::int) DESC,
 (screen_scope<>'all') DESC,(role_scope<>'all') DESC,(branch_id IS NOT NULL) DESC,(device<>'all') DESC,
 coalesce(started_at,published_at) DESC,id DESC)
 FROM scoped
$$;
REVOKE ALL ON FUNCTION ff_private.a07_ranked_candidates(text,text,uuid,text,uuid) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION ff_private.a07_style_layers(p_screen text,p_role text,p_branch uuid,p_device text,p_actor uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $$
 WITH candidates AS (SELECT * FROM ff_private.a07_ranked_candidates(p_screen,p_role,p_branch,p_device,p_actor)),
 properties AS (
  SELECT DISTINCT ON (e.key) e.key,e.value,c.revision
  FROM candidates c CROSS JOIN LATERAL jsonb_each(c.style-'elements') e
  ORDER BY e.key,c.rank_order
 ), element_groups AS (
  SELECT DISTINCT ON (e.key) e.key,e.value,c.revision
  FROM candidates c CROSS JOIN LATERAL jsonb_each(coalesce(c.style->'elements','{}')) e
  WHERE ff_private.a07_valid_elements(jsonb_build_object(e.key,e.value),p_screen)
  ORDER BY e.key,c.rank_order
 )
 SELECT jsonb_build_object(
 'style',coalesce((SELECT jsonb_object_agg(key,value) FROM properties),'{}') ||
  CASE WHEN EXISTS(SELECT 1 FROM element_groups) THEN jsonb_build_object('elements',(SELECT jsonb_object_agg(key,value) FROM element_groups)) ELSE '{}'::jsonb END,
 'sources',coalesce((SELECT jsonb_object_agg(key,revision) FROM properties),'{}') ||
  coalesce((SELECT jsonb_object_agg('elements.'||key,revision) FROM element_groups),'{}')
 )
$$;
REVOKE ALL ON FUNCTION ff_private.a07_style_layers(text,text,uuid,text,uuid) FROM PUBLIC,anon,authenticated;
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
 SELECT coalesce(jsonb_object_agg(s.screen,(to_jsonb(v)-'actor_id'-'published_by'-'draft_description'-'draft_name'-'previous_id'-'restored_from') || jsonb_build_object('style_config',ff_private.a07_style_layers(s.screen,r,b,p_device,auth.uid())->'style')), '{}'::jsonb)
 INTO result FROM unnest(ARRAY['dashboard','orders','cashier','driver','assembly','burger_kitchen','catalog','customers','reports','staff','archive','ratings','cases','messages','reservations','system']) s(screen)
 CROSS JOIN LATERAL ff_private.a07_resolve(s.screen,r,b,p_device,auth.uid()) v;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.ff_a07_manager_style_layers(p_screen text,p_role text,p_branch uuid,p_device text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.ff_a07_manager_source(p_screen,p_role,p_branch,p_device);
 RETURN ff_private.a07_style_layers(p_screen,p_role,p_branch,p_device,NULL);
END $$;
REVOKE ALL ON FUNCTION public.ff_a07_manager_style_layers(text,text,uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a07_manager_style_layers(text,text,uuid,text) TO authenticated;
