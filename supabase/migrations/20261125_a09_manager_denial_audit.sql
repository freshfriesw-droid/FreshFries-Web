-- A09 closure: preserve SQL exception semantics while committing the audit for denied HTTP RPCs.
-- A PostgREST response status override is not a SQL exception and therefore does not roll back the audit.
ALTER TABLE public.ff82_content_audit ADD COLUMN attempted_revision bigint;
ALTER TABLE public.ff82_content_audit ADD COLUMN effect text;
CREATE OR REPLACE FUNCTION ff_private.a09_reject_manager(p_action text,p_target bigint,p_message text,p_sqlstate text)
RETURNS void LANGUAGE plpgsql SET search_path='' AS $audit$
DECLARE g public.ff82_content_grants; who uuid:=auth.uid(); why text;
BEGIN
 SELECT * INTO g FROM public.ff82_content_grants WHERE recipient=who ORDER BY id DESC LIMIT 1;
 why:=CASE WHEN who IS NULL THEN 'authentication' WHEN g.id IS NULL THEN 'manager_only:no_grant'
 WHEN g.revoked_at IS NOT NULL THEN 'manager_only:revoked' WHEN clock_timestamp()>=g.ends_at THEN 'manager_only:expired'
 WHEN clock_timestamp()<g.starts_at THEN 'manager_only:not_started' ELSE 'manager_only:restricted_grant' END;
 -- Server logs survive transaction rollback, including non-HTTP SQL exceptions or read-only requests.
 RAISE LOG 'FF_A09_DENIED actor=% action=% requested_id=% reason=% effect=no_change',who,p_action,p_target,why;
 IF current_setting('request.method',true)='POST' AND who IS NOT NULL THEN
  INSERT INTO public.ff82_content_audit(actor_id,grant_id,action,outcome,reason,attempted_revision,effect)
  VALUES(who,g.id,p_action,'denied',why,p_target,'no_change');
  PERFORM set_config('response.status','403',true);
  RETURN;
 END IF;
 RAISE EXCEPTION USING MESSAGE=p_message,ERRCODE=p_sqlstate;
END $audit$;
REVOKE ALL ON FUNCTION ff_private.a09_reject_manager(text,bigint,text,text) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.ff_ui_publish(p_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE draft public.ff_ui_versions; prior bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN
  PERFORM ff_private.a09_reject_manager('design_publish',p_id,'غير مخول','42501');
  RETURN;
 END IF;
 LOCK TABLE public.ff_ui_versions IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO STRICT draft FROM public.ff_ui_versions WHERE id=p_id;
 IF draft.published_at IS NOT NULL THEN RETURN; END IF;
 SELECT id INTO prior FROM public.ff_ui_versions WHERE screen_scope=draft.screen_scope AND role_scope=draft.role_scope AND branch_id IS NOT DISTINCT FROM draft.branch_id AND device=draft.device AND published_at IS NOT NULL ORDER BY published_at DESC,id DESC LIMIT 1;
 IF prior IS DISTINCT FROM draft.previous_id THEN RAISE EXCEPTION 'تغير الإصدار المنشور. راجع التعديلات واحفظ مسودة جديدة'; END IF;
 UPDATE public.ff_ui_versions SET published_by=auth.uid(),published_at=clock_timestamp() WHERE id=p_id;
END $function$;
CREATE OR REPLACE FUNCTION public.ff_ui_rollback(p_current bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE active_release public.ff_ui_versions; previous_release public.ff_ui_versions; revision bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN
  PERFORM ff_private.a09_reject_manager('design_restore',p_current,'الاستعادة للمدير العام فقط','42501');
  RETURN NULL;
 END IF;
 LOCK TABLE public.ff_ui_versions IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO STRICT active_release FROM public.ff_ui_versions WHERE id=p_current AND published_at IS NOT NULL;
 IF active_release.previous_id IS NULL THEN RAISE EXCEPTION 'لا يوجد إصدار سابق لهذا النطاق'; END IF;
 IF EXISTS(SELECT FROM public.ff_ui_versions v WHERE v.screen_scope=active_release.screen_scope AND v.role_scope=active_release.role_scope AND v.branch_id IS NOT DISTINCT FROM active_release.branch_id AND v.device=active_release.device AND (v.published_at,v.id)>(active_release.published_at,active_release.id)) THEN RAISE EXCEPTION 'تغير الإصدار النشط، حدّث السجل'; END IF;
 SELECT * INTO STRICT previous_release FROM public.ff_ui_versions WHERE id=active_release.previous_id;
 revision:=public.ff_ui_save_draft(previous_release.role_scope,previous_release.branch_id,previous_release.device,previous_release.pack,previous_release.layout_text,previous_release.bar,previous_release.id);
 UPDATE public.ff_ui_versions SET draft_name=previous_release.draft_name,draft_description=previous_release.draft_description WHERE id=revision;
 PERFORM public.ff_ui_publish(revision); RETURN revision;
END $function$;
CREATE OR REPLACE FUNCTION public.ff_ui_control_trial(p_id bigint, p_accounts uuid[], p_hours integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare affected integer;
begin
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN
  PERFORM ff_private.a09_reject_manager('design_trial',p_id,'الإجراء للمدير العام فقط','P0001');
  RETURN NULL;
 END IF;
 perform 1 from public.ff_ui_versions where id=p_id and published_at is null for update;
 if not found then raise exception 'اختر مسودة متاحة';end if;
 if p_hours=0 then
  update public.ff_ui_trials set stopped_at=now(),stopped_by=auth.uid()
  where version_id=p_id and stopped_at is null and ends_at>now();
  get diagnostics affected=row_count;
  return affected;
 end if;
 if p_hours is null or p_hours not in (1,8,24) or coalesce(cardinality(p_accounts),0)=0
 or exists(select account from unnest(p_accounts) account except select account_id from public.ff_ui_trial_accounts(p_id))
 then raise exception 'تحقق من مدة التجربة والحسابات المسموحة'; end if;
 update public.ff_ui_trials set stopped_at=now(),stopped_by=auth.uid()
 where version_id=p_id and stopped_at is null and ends_at>now();
 insert into public.ff_ui_trials(version_id,recipient,started_by,ends_at)
 select distinct p_id,account,auth.uid(),now()+make_interval(hours=>p_hours) from unnest(p_accounts) account;
 get diagnostics affected=row_count;
 return affected;
end $function$;
CREATE OR REPLACE FUNCTION public.ff_content_publish(p_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare draft public.ff_content_versions; prior bigint;
begin
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN
  PERFORM ff_private.a09_reject_manager('content_publish',p_id,'النشر للمدير العام فقط','P0001');
  RETURN;
 END IF;
 lock table public.ff_content_versions in share row exclusive mode;
 select * into strict draft from public.ff_content_versions where id=p_id;
 if draft.published_at is not null then return; end if;
 select id into prior from public.ff_content_versions where content_key=draft.content_key and role_scope=draft.role_scope
  and branch_id is not distinct from draft.branch_id and published_at is not null order by published_at desc,id desc limit 1;
 if prior is distinct from draft.previous_id then raise exception 'تغير النص المنشور؛ احفظ مسودة جديدة بعد المراجعة'; end if;
 update public.ff_content_versions set published_at=clock_timestamp(),published_by=auth.uid() where id=p_id;
end $function$;
CREATE OR REPLACE FUNCTION public.ff_content_create_draft(p_key text, p_role text, p_branch uuid, p_body text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare prior bigint; new_id bigint;
begin
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN
  PERFORM ff_private.a09_reject_manager(CASE WHEN p_body IS NULL THEN 'content_restore' ELSE 'content_manager_draft' END,NULL,'تحرير المحتوى للمدير العام فقط','P0001');
  RETURN NULL;
 END IF;
 select id into prior from public.ff_content_versions where content_key=p_key and role_scope=p_role
  and branch_id is not distinct from p_branch and published_at is not null order by published_at desc,id desc limit 1;
 insert into public.ff_content_versions(content_key,role_scope,branch_id,body,actor_id,previous_id)
 values(p_key,p_role,p_branch,btrim(p_body),auth.uid(),prior) returning id into new_id;
 return new_id;
end $function$;
CREATE OR REPLACE FUNCTION public.ff_a07_named_design(p_screen text, p_role text, p_branch uuid, p_device text, p_pack text, p_text text, p_bar text, p_name text, p_description text, p_cards jsonb, p_style jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE revision bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN
  PERFORM ff_private.a09_reject_manager('design_manager_draft',NULL,'غير مخول','42501');
  RETURN NULL;
 END IF;
 IF nullif(trim(p_name),'') IS NULL OR NOT public.ff81_validate_cards(p_cards) OR NOT ff_private.a07_valid_style(p_style) THEN RAISE EXCEPTION 'مسودة أو خصائص غير صالحة'; END IF;
 revision:=ff_private.a07_save_design(p_screen,p_role,p_branch,p_device,p_pack,p_text,p_bar,NULL);
 UPDATE public.ff_ui_versions SET draft_name=trim(p_name),draft_description=trim(p_description),card_layout=p_cards,style_config=p_style WHERE id=revision AND published_at IS NULL;
 RETURN revision;
END $function$;
CREATE OR REPLACE FUNCTION public.ff_ui_save_draft(p_role text, p_branch uuid, p_device text, p_pack text, p_text text, p_bar text, p_restore bigint DEFAULT NULL::bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN
  PERFORM ff_private.a09_reject_manager(CASE WHEN p_restore IS NULL THEN 'design_manager_draft' ELSE 'design_restore_draft' END,p_restore,'غير مخول','42501');
  RETURN NULL;
 END IF;
 RETURN ff_private.a07_save_design('dashboard',p_role,p_branch,p_device,p_pack,p_text,p_bar,p_restore);
END $function$;
CREATE OR REPLACE FUNCTION public.ff_ui_named_draft(p_role text, p_branch uuid, p_device text, p_pack text, p_text text, p_bar text, p_name text, p_description text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare revision bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN
  PERFORM ff_private.a09_reject_manager('design_manager_draft',NULL,'غير مخول','42501');
  RETURN NULL;
 END IF;
 if nullif(trim(p_name),'') is null then raise exception 'أدخل اسم المسودة'; end if;
 revision:=public.ff_ui_save_draft(p_role,p_branch,p_device,p_pack,p_text,p_bar);
 update public.ff_ui_versions set draft_name=trim(p_name),draft_description=trim(p_description) where id=revision;
 return revision;
end $function$;
CREATE OR REPLACE FUNCTION public.ff81_named_card_draft(p_role text, p_branch uuid, p_device text, p_pack text, p_text text, p_bar text, p_name text, p_description text, p_cards jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare revision bigint;
begin
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN
  PERFORM ff_private.a09_reject_manager('design_card_draft',NULL,'غير مخول','P0001');
  RETURN NULL;
 END IF;
 if not public.ff81_validate_cards(p_cards) then raise exception 'محتوى البطاقات غير صالح';end if;
 revision:=public.ff_ui_named_draft(p_role,p_branch,p_device,p_pack,p_text,p_bar,p_name,p_description);
 update public.ff_ui_versions set card_layout=p_cards where id=revision and published_at is null;
 return revision;
end $function$;
CREATE OR REPLACE FUNCTION public.ff82_set_grant(p_recipient uuid, p_branch uuid, p_screen text, p_capabilities text[], p_start timestamp with time zone, p_end timestamp with time zone)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r text; new_id bigint; old_id bigint;
begin
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN
  PERFORM ff_private.a09_reject_manager('grant_manage',NULL,'إدارة التفويض للمدير العام فقط','P0001');
  RETURN NULL;
 END IF;
 select a.role into r from public.ff82_manager_accounts() a where a.user_id=p_recipient and a.branch_id=p_branch;
 if r is null or not exists(select 1 from public.ff_content_catalog c where c.screen=p_screen)
 or p_start is null or p_end is null or p_end<=greatest(p_start,now()) or p_capabilities is null or cardinality(p_capabilities)=0
 or array_position(p_capabilities,null) is not null or not(p_capabilities <@ array['view','edit','preview','review']::text[])
 then raise exception 'تحقق من الحساب والفرع والواجهة والصلاحيات والمدة';end if;
 lock table public.ff82_content_grants in share row exclusive mode;
 update public.ff82_content_grants set revoked_at=clock_timestamp(),revoked_by=auth.uid()
 where recipient=p_recipient and revoked_at is null returning id into old_id;
 if old_id is not null then insert into public.ff82_content_audit(actor_id,grant_id,action,outcome,reason) values(auth.uid(),old_id,'revoke','allowed','replaced');end if;
 insert into public.ff82_content_grants(recipient,role_scope,branch_id,screen,capabilities,starts_at,ends_at,granted_by)
 values(p_recipient,r,p_branch,p_screen,p_capabilities,p_start,p_end,auth.uid()) returning id into new_id;
 insert into public.ff82_content_audit(actor_id,grant_id,action,outcome) values(auth.uid(),new_id,'grant','allowed');
 return new_id;
end $function$;
CREATE OR REPLACE FUNCTION public.ff82_revoke_grant(p_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN
  PERFORM ff_private.a09_reject_manager('grant_revoke',p_id,'إلغاء التفويض للمدير العام فقط','P0001');
  RETURN false;
 END IF;
 update public.ff82_content_grants set revoked_at=clock_timestamp(),revoked_by=auth.uid() where id=p_id and revoked_at is null;
 if not found then return false;end if;
 insert into public.ff82_content_audit(actor_id,grant_id,action,outcome) values(auth.uid(),p_id,'revoke','allowed');
 return true;
end $function$;
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
 OR (p_kinds && ARRAY['colors','buttons','layout']::text[] AND p_screen NOT IN ('dashboard','orders','cashier','driver','assembly','burger_kitchen','catalog','customers','reports','staff','archive','ratings','cases','messages','reservations','system'))
 OR p_start IS NULL OR p_end IS NULL OR p_end<=greatest(p_start,clock_timestamp()) OR p_capabilities IS NULL OR cardinality(p_capabilities)=0 OR array_position(p_capabilities,NULL) IS NOT NULL OR NOT(p_capabilities <@ ARRAY['view','edit','preview','review']::text[]) THEN
 RAISE EXCEPTION 'تحقق من النطاق ونوع التعديل والمدة' USING ERRCODE='22023';END IF;
 LOCK TABLE public.ff82_content_grants IN SHARE ROW EXCLUSIVE MODE;
 UPDATE public.ff82_content_grants SET revoked_at=clock_timestamp(),revoked_by=auth.uid() WHERE recipient=p_recipient AND revoked_at IS NULL RETURNING id INTO old_id;
 IF old_id IS NOT NULL THEN INSERT INTO public.ff82_content_audit(actor_id,grant_id,action,outcome,reason) VALUES(auth.uid(),old_id,'revoke','allowed','replaced');END IF;
 INSERT INTO public.ff82_content_grants(recipient,role_scope,branch_id,screen,capabilities,starts_at,ends_at,granted_by,edit_kinds) VALUES(p_recipient,r,p_branch,p_screen,p_capabilities,p_start,p_end,auth.uid(),p_kinds) RETURNING id INTO new_id;
 INSERT INTO public.ff82_content_audit(actor_id,grant_id,action,outcome,reason) VALUES(auth.uid(),new_id,'grant','allowed',array_to_string(p_kinds,','));
 RETURN new_id;
END $function$;

-- Existing grants and return signatures remain unchanged. Private helper has no client EXECUTE.
