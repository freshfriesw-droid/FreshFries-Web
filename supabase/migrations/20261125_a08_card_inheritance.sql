-- A08: inherit card layouts separately from appearance properties; [] is an explicit empty layout.
CREATE OR REPLACE FUNCTION ff_private.a08_card_source(p_role text,p_branch uuid,p_device text,p_actor uuid)
RETURNS TABLE(revision bigint,layout jsonb) LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT v.id,v.card_layout FROM ff_private.a07_ranked_candidates('dashboard',p_role,p_branch,p_device,p_actor) c
 JOIN public.ff_ui_versions v ON v.id=c.revision WHERE v.card_layout IS NOT NULL ORDER BY c.rank_order LIMIT 1
$$;
REVOKE ALL ON FUNCTION ff_private.a08_card_source(text,uuid,text,uuid) FROM PUBLIC,anon,authenticated;
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
 SELECT coalesce(jsonb_object_agg(s.screen,(to_jsonb(v)-'actor_id'-'published_by'-'draft_description'-'draft_name'-'previous_id'-'restored_from') || jsonb_build_object('style_config',ff_private.a07_style_layers(s.screen,r,b,p_device,auth.uid())->'style') || CASE WHEN s.screen='dashboard' THEN jsonb_build_object('card_layout',cards.layout,'card_layout_source',cards.revision) ELSE '{}'::jsonb END), '{}'::jsonb)
 INTO result FROM unnest(ARRAY['dashboard','orders','cashier','driver','assembly','burger_kitchen','catalog','customers','reports','staff','archive','ratings','cases','messages','reservations','system']) s(screen)
 CROSS JOIN LATERAL ff_private.a07_resolve(s.screen,r,b,p_device,auth.uid()) v
 LEFT JOIN LATERAL ff_private.a08_card_source(r,b,p_device,auth.uid()) cards ON s.screen='dashboard';
 RETURN result;
END $$;


CREATE OR REPLACE FUNCTION public.ff_a08_manager_card_source(p_role text,p_branch uuid,p_device text)
RETURNS TABLE(revision bigint,layout jsonb) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.ff_a07_manager_source('dashboard',p_role,p_branch,p_device);
 RETURN QUERY SELECT * FROM ff_private.a08_card_source(p_role,p_branch,p_device,NULL);
END $$;
REVOKE ALL ON FUNCTION public.ff_a08_manager_card_source(text,uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a08_manager_card_source(text,uuid,text) TO authenticated;
