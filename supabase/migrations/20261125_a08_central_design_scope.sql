-- A08: keep design branch scope consistent with central customer service and unassigned supervisor policy.
CREATE OR REPLACE FUNCTION public.ff_a07_effective_designs(p_branch uuid,p_device text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
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
 INTO result FROM unnest(ARRAY['dashboard','orders','cashier','driver','assembly','burger_kitchen','catalog','customers','reports','staff','archive','ratings','cases','messages','reservations','system']) s(screen)
 CROSS JOIN LATERAL ff_private.a07_resolve(s.screen,r,b,p_device,auth.uid()) v
 LEFT JOIN LATERAL ff_private.a08_card_source(r,b,p_device,auth.uid()) cards ON s.screen='dashboard';
 RETURN result;
END $$;


