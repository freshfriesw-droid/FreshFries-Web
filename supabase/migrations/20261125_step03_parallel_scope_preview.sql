CREATE OR REPLACE FUNCTION ff_private.a07_merge_style_candidates(p_screen text,p_candidates jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $function$
WITH candidates AS (SELECT * FROM jsonb_to_recordset(coalesce(p_candidates,'[]'::jsonb)) AS c(revision bigint,style jsonb,rank_order bigint)),
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
  SELECT DISTINCT ON (key) key,value,revision FROM eligible_groups ORDER BY key,((value->0->>'orderMode') IS NOT DISTINCT FROM 'inherit'),rank_order
 ), element_properties AS (
  SELECT DISTINCT ON (g.key,r.row->>'key',p.key)
   g.key AS group_key,r.row->>'key' AS element_key,p.key AS property,p.value,g.revision
  FROM eligible_groups g CROSS JOIN LATERAL jsonb_array_elements(g.value) r(row)
  CROSS JOIN LATERAL jsonb_each(r.row-ARRAY['key','orderMode']) p
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
 WHERE (g.value->0->>'orderMode') IS DISTINCT FROM 'inherit'
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
REVOKE ALL ON FUNCTION ff_private.a07_merge_style_candidates(text,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION ff_private.a07_style_layers(p_screen text,p_role text,p_branch uuid,p_device text,p_actor uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT ff_private.a07_merge_style_candidates(p_screen,coalesce((SELECT jsonb_agg(to_jsonb(c)) FROM ff_private.a07_ranked_candidates(p_screen,p_role,p_branch,p_device,p_actor) c),'[]'::jsonb));
$$;

CREATE OR REPLACE FUNCTION public.ff_a07_preview_scope(
 p_screen_scope text,p_role_scope text,p_branch_scope uuid,p_device_scope text,p_pack text,p_style jsonb,
 p_target_screen text,p_target_role text,p_target_branch uuid,p_target_device text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE oldrow public.ff_ui_versions; before_layers jsonb; after_layers jsonb; before_view jsonb; after_view jsonb; applies boolean; candidates jsonb; chosen_pack text;
BEGIN
 PERFORM public.ff_a07_manager_source(p_target_screen,p_target_role,p_target_branch,p_target_device);
 IF p_target_screen='all' OR p_screen_scope IS NULL OR p_screen_scope NOT IN ('all','dashboard','orders','cashier','driver','assembly','burger_kitchen','catalog','customers','reports','staff','archive','ratings','cases','messages','reservations','system')
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
 applies:=p_screen_scope IN ('all',p_target_screen) AND p_role_scope IN ('all',p_target_role)
 AND (p_branch_scope IS NULL OR p_branch_scope IS NOT DISTINCT FROM p_target_branch) AND p_device_scope IN ('all',p_target_device);
 IF NOT applies THEN RETURN jsonb_build_object('applies',false,'before',before_view,'after',before_view,'before_sources',before_layers->'sources','after_sources',before_layers->'sources'); END IF;
 WITH published AS (
  SELECT DISTINCT ON (v.screen_scope,v.role_scope,v.branch_id,v.device)
   v.id,v.style_config,v.pack,v.screen_scope,v.role_scope,v.branch_id,v.device,v.published_at
  FROM public.ff_ui_versions v
  WHERE v.published_at IS NOT NULL AND v.screen_scope IN ('all',p_target_screen) AND v.role_scope IN ('all',p_target_role)
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
END $$;
REVOKE ALL ON FUNCTION public.ff_a07_preview_scope(text,text,uuid,text,text,jsonb,text,text,uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a07_preview_scope(text,text,uuid,text,text,jsonb,text,text,uuid,text) TO authenticated;
