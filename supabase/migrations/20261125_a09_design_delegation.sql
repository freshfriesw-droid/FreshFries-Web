
-- A09: one active narrow grant, independent modification classes, same revocation/audit lifecycle.
ALTER TABLE public.ff82_content_grants ADD COLUMN edit_kinds text[] NOT NULL DEFAULT ARRAY['text']::text[] CHECK(cardinality(edit_kinds)>0 AND array_position(edit_kinds,NULL) IS NULL AND edit_kinds <@ ARRAY['text','colors','buttons','layout']::text[]);
ALTER TABLE public.ff82_content_audit ADD COLUMN design_revision bigint REFERENCES public.ff_ui_versions(id);
CREATE OR REPLACE FUNCTION public.ff_a09_set_grant(p_recipient uuid,p_branch uuid,p_screen text,p_capabilities text[],p_start timestamptz,p_end timestamptz,p_kinds text[])
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r text; new_id bigint; old_id bigint;
BEGIN
 IF auth.uid() IS NULL OR NOT public.ff_is_manager() THEN RAISE EXCEPTION 'إدارة التفويض للمدير فقط' USING ERRCODE='42501';END IF;
 SELECT a.role INTO r FROM public.ff82_manager_accounts() a WHERE a.user_id=p_recipient AND a.branch_id=p_branch;
 IF r IS NULL OR p_screen IS NULL OR p_kinds IS NULL OR cardinality(p_kinds)=0 OR array_position(p_kinds,NULL) IS NOT NULL OR NOT(p_kinds <@ ARRAY['text','colors','buttons','layout']::text[])
 OR ('text'=ANY(p_kinds) AND NOT EXISTS(SELECT 1 FROM public.ff_content_catalog c WHERE c.screen=p_screen))
 OR (p_kinds && ARRAY['colors','buttons','layout']::text[] AND p_screen NOT IN ('dashboard','orders','cashier','driver','assembly','burger_kitchen','catalog','customers','reports','staff','archive','ratings','cases','messages','reservations','system'))
 OR p_start IS NULL OR p_end IS NULL OR p_end<=greatest(p_start,clock_timestamp()) OR p_capabilities IS NULL OR cardinality(p_capabilities)=0 OR array_position(p_capabilities,NULL) IS NOT NULL OR NOT(p_capabilities <@ ARRAY['view','edit','preview','review']::text[]) THEN
 RAISE EXCEPTION 'تحقق من النطاق ونوع التعديل والمدة' USING ERRCODE='22023';END IF;
 LOCK TABLE public.ff82_content_grants IN SHARE ROW EXCLUSIVE MODE;
 UPDATE public.ff82_content_grants SET revoked_at=clock_timestamp(),revoked_by=auth.uid() WHERE recipient=p_recipient AND revoked_at IS NULL RETURNING id INTO old_id;
 IF old_id IS NOT NULL THEN INSERT INTO public.ff82_content_audit(actor_id,grant_id,action,outcome,reason) VALUES(auth.uid(),old_id,'revoke','allowed','replaced');END IF;
 INSERT INTO public.ff82_content_grants(recipient,role_scope,branch_id,screen,capabilities,starts_at,ends_at,granted_by,edit_kinds) VALUES(p_recipient,r,p_branch,p_screen,p_capabilities,p_start,p_end,auth.uid(),p_kinds) RETURNING id INTO new_id;
 INSERT INTO public.ff82_content_audit(actor_id,grant_id,action,outcome,reason) VALUES(auth.uid(),new_id,'grant','allowed',array_to_string(p_kinds,','));
 RETURN new_id;
END $$;
CREATE OR REPLACE FUNCTION public.ff82_delegate_catalog()
 RETURNS SETOF ff_content_catalog
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select c.* from public.ff_content_catalog c join public.ff82_my_grant() g on g.screen=c.screen
 where 'text'=ANY(g.edit_kinds) and g.capabilities && array['view','edit','preview','review']::text[] order by c.key
$function$;
CREATE OR REPLACE FUNCTION public.ff82_delegate_history(p_key text)
 RETURNS SETOF ff_content_versions
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select v.* from public.ff_content_versions v join public.ff_content_catalog c on c.key=v.content_key
 join public.ff82_my_grant() g on g.screen=c.screen and g.role_scope=v.role_scope and g.branch_id=v.branch_id
 where 'text'=ANY(g.edit_kinds) and v.content_key=p_key and g.capabilities && array['view','preview','review','edit']::text[]
 and (v.published_at is not null or v.actor_id=auth.uid() or 'review'=any(g.capabilities)) order by v.id desc limit 100
$function$;
CREATE OR REPLACE FUNCTION public.ff82_delegate_draft(p_key text, p_body text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare g public.ff82_content_grants; prior bigint; revision bigint; why text;
begin
 if auth.uid() is null then return jsonb_build_object('ok',false,'reason','authentication');end if;
 -- Serialize write with revocation and replacement. Recheck using the current grant after locking.
 lock table public.ff82_content_grants in share mode;
 select * into g from public.ff82_my_grant();
 if g.id is null or not('text'=ANY(g.edit_kinds)) or not('edit'=any(g.capabilities)) or not exists(select 1 from public.ff_content_catalog c where c.key=p_key and c.screen=g.screen) then why:='outside_edit_scope';
 elsif p_body is null then why:='restore_manager_only';
 else
  select id into prior from public.ff_content_versions where content_key=p_key and role_scope=g.role_scope and branch_id=g.branch_id and published_at is not null order by published_at desc,id desc limit 1;
  begin
   insert into public.ff_content_versions(content_key,role_scope,branch_id,body,actor_id,previous_id)
   values(p_key,g.role_scope,g.branch_id,btrim(p_body),auth.uid(),prior) returning id into revision;
  exception when check_violation then why:='invalid_text';end;
 end if;
 insert into public.ff82_content_audit(actor_id,grant_id,action,outcome,reason,content_key,revision_id)
 values(auth.uid(),g.id,'draft',case when why is null then 'allowed' else 'denied' end,coalesce(why,''),left(p_key,150),revision);
 return jsonb_build_object('ok',why is null,'reason',why,'revision',revision);
end $function$;
CREATE OR REPLACE FUNCTION public.ff82_delegate_review(p_revision bigint, p_note text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare g public.ff82_content_grants; v public.ff_content_versions; why text;
begin
 if auth.uid() is null then return jsonb_build_object('ok',false,'reason','authentication');end if;
 lock table public.ff82_content_grants in share mode;
 select * into g from public.ff82_my_grant();
 select * into v from public.ff_content_versions where id=p_revision;
 if g.id is null or not('text'=ANY(g.edit_kinds)) or not('review'=any(g.capabilities)) or v.id is null or v.published_at is not null or v.role_scope<>g.role_scope or v.branch_id is distinct from g.branch_id
 or not exists(select 1 from public.ff_content_catalog c where c.key=v.content_key and c.screen=g.screen) then why:='outside_review_scope';
 else
  begin insert into public.ff82_content_reviews(revision_id,grant_id,reviewer,note) values(v.id,g.id,auth.uid(),btrim(p_note));
  exception when check_violation or not_null_violation then why:='invalid_note';end;
 end if;
 insert into public.ff82_content_audit(actor_id,grant_id,action,outcome,reason,revision_id)
 values(auth.uid(),g.id,'review',case when why is null then 'allowed' else 'denied' end,coalesce(why,''),case when why is null then v.id end);
 return jsonb_build_object('ok',why is null,'reason',why);
end $function$;
CREATE OR REPLACE FUNCTION public.ff_a09_design_history(p_device text)
RETURNS SETOF public.ff_ui_versions LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT v.* FROM public.ff_ui_versions v JOIN public.ff82_my_grant() g ON v.screen_scope=g.screen AND v.role_scope=g.role_scope AND v.branch_id=g.branch_id
 WHERE g.edit_kinds && ARRAY['colors','buttons','layout']::text[] AND v.device=p_device AND (v.published_at IS NOT NULL OR v.actor_id=auth.uid() OR 'review'=ANY(g.capabilities)) ORDER BY v.id DESC LIMIT 100
$$;
CREATE OR REPLACE FUNCTION public.ff_a09_design_draft(p_device text,p_patch jsonb,p_name text,p_base bigint DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE g public.ff82_content_grants; v public.ff_ui_versions; effective public.ff_ui_versions; prior bigint; revision bigint; why text; k text; allowed text[]:='{}'; merged jsonb;
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
  IF EXISTS(SELECT 1 FROM jsonb_object_keys(p_patch) k0 WHERE NOT(k0=ANY(allowed))) THEN why:='outside_edit_kind';END IF;
  SELECT * INTO v FROM public.ff_ui_versions WHERE screen_scope=g.screen AND role_scope=g.role_scope AND branch_id=g.branch_id AND device=p_device AND published_at IS NOT NULL ORDER BY published_at DESC,id DESC LIMIT 1;
  prior:=v.id;
  IF p_base IS NOT NULL THEN
   SELECT * INTO v FROM public.ff_ui_versions WHERE id=p_base AND actor_id=auth.uid() AND published_at IS NULL AND screen_scope=g.screen AND role_scope=g.role_scope AND branch_id=g.branch_id AND device=p_device AND previous_id IS NOT DISTINCT FROM prior AND EXISTS(SELECT 1 FROM public.ff82_content_audit a WHERE a.design_revision=p_base AND a.grant_id=g.id AND a.actor_id=auth.uid() AND a.action='design_draft' AND a.outcome='allowed');
   IF v.id IS NULL THEN why:='stale_or_foreign_draft';END IF;
  END IF;
  IF why IS NULL THEN
   SELECT * INTO effective FROM ff_private.a07_resolve(g.screen,g.role_scope,g.branch_id,CASE WHEN p_device='all' THEN 'desktop' ELSE p_device END,NULL);
   merged:=coalesce(v.style_config,'{}')||p_patch;
   BEGIN
    INSERT INTO public.ff_ui_versions(screen_scope,role_scope,branch_id,device,pack,layout_text,bar,actor_id,previous_id,style_config,card_layout,draft_name,draft_description)
    VALUES(g.screen,g.role_scope,g.branch_id,p_device,coalesce(v.pack,effective.pack,'D01'),coalesce(v.layout_text,effective.layout_text,''),coalesce(v.bar,effective.bar,'labels'),auth.uid(),prior,merged,v.card_layout,btrim(p_name),'مسودة مفوضة للمراجعة') RETURNING id INTO revision;
   EXCEPTION WHEN check_violation OR foreign_key_violation THEN why:='invalid_design';END;
  END IF;
 END IF;
 INSERT INTO public.ff82_content_audit(actor_id,grant_id,action,outcome,reason,design_revision) VALUES(auth.uid(),g.id,'design_draft',CASE WHEN why IS NULL THEN 'allowed' ELSE 'denied' END,coalesce(why,''),revision);
 RETURN jsonb_build_object('ok',why IS NULL,'reason',why,'revision',revision);
END $$;
CREATE OR REPLACE FUNCTION public.ff_a09_design_review(p_revision bigint,p_note text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE g public.ff82_content_grants; v public.ff_ui_versions; why text;
BEGIN
 IF auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'reason','authentication');END IF;
 LOCK TABLE public.ff82_content_grants IN SHARE MODE;
 SELECT * INTO g FROM public.ff82_my_grant();
 SELECT * INTO v FROM public.ff_ui_versions WHERE id=p_revision;
 IF g.id IS NULL OR NOT('review'=ANY(g.capabilities)) OR NOT(g.edit_kinds && ARRAY['colors','buttons','layout']::text[]) OR v.id IS NULL OR v.published_at IS NOT NULL OR v.screen_scope<>g.screen OR v.role_scope<>g.role_scope OR v.branch_id IS DISTINCT FROM g.branch_id THEN why:='outside_review_scope';
 ELSIF p_note IS NULL OR length(btrim(p_note)) NOT BETWEEN 1 AND 500 OR p_note ~ '[<>{}[:cntrl:]]' OR p_note ~* '(https?://|www\\.|javascript:|data:|vbscript:|//)' OR translate(p_note,U&'\\061C\\200E\\200F\\202A\\202B\\202C\\202D\\202E\\2066\\2067\\2068\\2069','')<>p_note THEN why:='invalid_note';END IF;
 INSERT INTO public.ff82_content_audit(actor_id,grant_id,action,outcome,reason,design_revision) VALUES(auth.uid(),g.id,'design_review',CASE WHEN why IS NULL THEN 'allowed' ELSE 'denied' END,coalesce(why,btrim(p_note)),CASE WHEN why IS NULL THEN v.id END);
 RETURN jsonb_build_object('ok',why IS NULL,'reason',why);
END $$;
REVOKE ALL ON FUNCTION public.ff_a09_set_grant(uuid,uuid,text,text[],timestamptz,timestamptz,text[]),public.ff_a09_design_history(text),public.ff_a09_design_draft(text,jsonb,text,bigint),public.ff_a09_design_review(bigint,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a09_set_grant(uuid,uuid,text,text[],timestamptz,timestamptz,text[]),public.ff_a09_design_history(text),public.ff_a09_design_draft(text,jsonb,text,bigint),public.ff_a09_design_review(bigint,text) TO authenticated;
