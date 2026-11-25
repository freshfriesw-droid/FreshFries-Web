-- A08: individual secondary panel preferences inherit independently across scopes.
CREATE OR REPLACE FUNCTION ff_private.a07_style_layers(p_screen text,p_role text,p_branch uuid,p_device text,p_actor uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $$
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
 ), element_groups AS (
  SELECT DISTINCT ON (e.key) e.key,e.value,c.revision
  FROM candidates c CROSS JOIN LATERAL jsonb_each(coalesce(c.style->'elements','{}')) e
  WHERE ff_private.a07_valid_elements(jsonb_build_object(e.key,e.value),p_screen)
  ORDER BY e.key,c.rank_order
 )
 SELECT jsonb_build_object(
 'style',coalesce((SELECT jsonb_object_agg(key,value) FROM properties),'{}') ||
  CASE WHEN EXISTS(SELECT 1 FROM panel_properties) THEN jsonb_build_object('dashboardPanels',(SELECT jsonb_object_agg(key,value) FROM panel_properties)) ELSE '{}'::jsonb END ||
  CASE WHEN EXISTS(SELECT 1 FROM element_groups) THEN jsonb_build_object('elements',(SELECT jsonb_object_agg(key,value) FROM element_groups)) ELSE '{}'::jsonb END,
 'sources',coalesce((SELECT jsonb_object_agg(key,revision) FROM properties),'{}') ||
  coalesce((SELECT jsonb_object_agg('dashboardPanels.'||key,revision) FROM panel_properties),'{}') ||
 coalesce((SELECT jsonb_object_agg('elements.'||key,revision) FROM element_groups),'{}')
 )
$$;
REVOKE ALL ON FUNCTION ff_private.a07_style_layers(text,text,uuid,text,uuid) FROM PUBLIC,anon,authenticated;
