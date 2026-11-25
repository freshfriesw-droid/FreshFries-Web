-- STEP08: retain the approved design and content version stores.
-- A trial is never a publication; only manager operations may create trials or release.
CREATE TABLE ff_private.step08_content_trials (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 version_id bigint NOT NULL REFERENCES public.ff_content_versions(id),
 recipient uuid NOT NULL REFERENCES public.ff_profiles(user_id),
 started_by uuid NOT NULL REFERENCES auth.users(id),
 started_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 ends_at timestamptz NOT NULL,
 stopped_at timestamptz,
 stopped_by uuid REFERENCES auth.users(id),
 CHECK (ends_at > started_at)
);
ALTER TABLE ff_private.step08_content_trials ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ff_private.step08_content_trials FROM PUBLIC,anon,authenticated;
CREATE INDEX step08_content_trial_recipient ON ff_private.step08_content_trials(recipient,version_id,ends_at) WHERE stopped_at IS NULL;

CREATE FUNCTION ff_private.step08_targets(p_role text,p_branch uuid)
RETURNS TABLE(account_id uuid,account_name text)
LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT p.user_id,p.display_name::text FROM public.ff_profiles p
 WHERE p.active AND (p_role='all' OR p.role::text=p_role)
 AND (p_branch IS NULL OR (EXISTS(SELECT FROM public.ff_branches b WHERE b.id=p_branch AND b.active) AND
 (p.role IN ('manager','customer_service') OR EXISTS(SELECT FROM public.ff_user_branches ub WHERE ub.user_id=p.user_id AND ub.branch_id=p_branch)
 OR (p.role='supervisor' AND NOT EXISTS(SELECT FROM public.ff_user_branches ub WHERE ub.user_id=p.user_id)))))
 ORDER BY p.display_name,p.user_id
$$;
REVOKE ALL ON FUNCTION ff_private.step08_targets(text,uuid) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION ff_private.step08_design_valid(v public.ff_ui_versions)
RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT coalesce(ff_private.a07_valid_style(v.style_config) AND public.ff81_validate_cards(v.card_layout)
 AND (NOT(v.style_config?'elements') OR ff_private.a07_valid_elements(v.style_config->'elements',v.screen_scope))
 AND EXISTS(SELECT FROM ff_private.a07_design_packs p WHERE p.code=v.pack)
 AND (v.branch_id IS NULL OR EXISTS(SELECT FROM public.ff_branches b WHERE b.id=v.branch_id AND b.active))
 AND (v.screen_scope IN ('all','dashboard') OR (v.card_layout IS NULL AND NOT(v.style_config?'dashboardPanels') AND NOT(v.style_config?'quickActions')))
 AND (v.screen_scope NOT IN ('login','customer_portal') OR (v.role_scope='all' AND v.branch_id IS NULL)),false)
$$;
REVOKE ALL ON FUNCTION ff_private.step08_design_valid(public.ff_ui_versions) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.ff_step08_release_impact(p_kind text,p_id bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v public.ff_ui_versions; c public.ff_content_versions; prior bigint; role_name text; b uuid; screen_name text; device_name text; valid boolean; public_scope boolean; recipients jsonb; n int;
BEGIN
 IF NOT EXISTS(SELECT FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN RAISE EXCEPTION 'غير مخول' USING ERRCODE='42501';END IF;
 IF p_kind='design' THEN
  SELECT * INTO STRICT v FROM public.ff_ui_versions WHERE id=p_id;
  role_name:=v.role_scope;b:=v.branch_id;screen_name:=v.screen_scope;device_name:=v.device;valid:=ff_private.step08_design_valid(v);
  SELECT id INTO prior FROM public.ff_ui_versions WHERE screen_scope=v.screen_scope AND role_scope=v.role_scope AND branch_id IS NOT DISTINCT FROM v.branch_id AND device=v.device AND published_at IS NOT NULL ORDER BY published_at DESC,id DESC LIMIT 1;
  valid:=valid AND v.published_at IS NULL AND prior IS NOT DISTINCT FROM v.previous_id;
 ELSIF p_kind='content' THEN
  SELECT * INTO STRICT c FROM public.ff_content_versions WHERE id=p_id;
  SELECT screen INTO screen_name FROM public.ff_content_catalog WHERE key=c.content_key;
  role_name:=c.role_scope;b:=c.branch_id;device_name:='all';
  SELECT id INTO prior FROM public.ff_content_versions WHERE content_key=c.content_key AND role_scope=c.role_scope AND branch_id IS NOT DISTINCT FROM c.branch_id AND published_at IS NOT NULL ORDER BY published_at DESC,id DESC LIMIT 1;
  valid:=c.published_at IS NULL AND prior IS NOT DISTINCT FROM c.previous_id AND public.ff83_valid_content(c.content_key,c.body) AND (b IS NULL OR EXISTS(SELECT FROM public.ff_branches WHERE id=b AND active));
 ELSE RAISE EXCEPTION 'نوع إصدار غير صالح' USING ERRCODE='22023';END IF;
 public_scope:=screen_name IN ('login','customer_portal');
 SELECT count(*)::int,coalesce(jsonb_agg(jsonb_build_object('account_id',account_id,'account_name',account_name) ORDER BY account_id),'[]') INTO n,recipients FROM ff_private.step08_targets(role_name,b) WHERE NOT public_scope;
 RETURN jsonb_build_object('kind',p_kind,'id',p_id,'valid',valid,'previous',prior,'screen',screen_name,'role',role_name,'branch',b,'device',device_name,'public',public_scope,'target_count',n,'targets',recipients,'trial_allowed',valid AND NOT public_scope);
END $$;
REVOKE ALL ON FUNCTION public.ff_step08_release_impact(text,bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_step08_release_impact(text,bigint) TO authenticated;

CREATE FUNCTION public.ff_step08_content_trial(p_id bigint,p_accounts uuid[],p_hours integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.ff_content_versions; impact jsonb; n integer; recipient_ids uuid[];
BEGIN
 IF NOT EXISTS(SELECT FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN
  PERFORM ff_private.a09_reject_manager('content_trial',p_id,'الإجراء للمدير العام فقط','42501');RETURN NULL;
 END IF;
 LOCK TABLE public.ff_content_versions IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO STRICT c FROM public.ff_content_versions WHERE id=p_id;
 IF p_hours=0 THEN
  UPDATE ff_private.step08_content_trials SET stopped_at=clock_timestamp(),stopped_by=auth.uid() WHERE version_id=p_id AND stopped_at IS NULL AND ends_at>clock_timestamp();
  GET DIAGNOSTICS n=ROW_COUNT;
 ELSE
  impact:=public.ff_step08_release_impact('content',p_id);
  IF impact->>'trial_allowed'<>'true' OR p_hours IS NULL OR p_hours NOT IN (1,8,24) OR coalesce(cardinality(p_accounts),0)=0 OR EXISTS(SELECT a FROM unnest(p_accounts) a EXCEPT SELECT account_id FROM ff_private.step08_targets(c.role_scope,c.branch_id)) THEN RAISE EXCEPTION 'تحقق من صلاحية المسودة والحسابات والمدة' USING ERRCODE='22023';END IF;
  UPDATE ff_private.step08_content_trials t SET stopped_at=clock_timestamp(),stopped_by=auth.uid()
   FROM public.ff_content_versions x WHERE x.id=t.version_id AND x.content_key=c.content_key AND x.role_scope=c.role_scope AND x.branch_id IS NOT DISTINCT FROM c.branch_id AND t.recipient=ANY(p_accounts) AND t.stopped_at IS NULL AND t.ends_at>clock_timestamp();
  INSERT INTO ff_private.step08_content_trials(version_id,recipient,started_by,ends_at)
   SELECT DISTINCT p_id,a,auth.uid(),clock_timestamp()+make_interval(hours=>p_hours) FROM unnest(p_accounts) a;
  GET DIAGNOSTICS n=ROW_COUNT;
 END IF;
 RETURN n;
END $$;
REVOKE ALL ON FUNCTION public.ff_step08_content_trial(bigint,uuid[],integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_step08_content_trial(bigint,uuid[],integer) TO authenticated;

CREATE FUNCTION ff_private.step08_content_trial_audit() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE b uuid;
BEGIN
 SELECT branch_id INTO b FROM public.ff_content_versions WHERE id=NEW.version_id;
 IF TG_OP='INSERT' THEN
  INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
  VALUES(NEW.started_by,'step08_content_trial_start','content',NEW.version_id::text,b,jsonb_build_object('recipient',NEW.recipient,'ends_at',NEW.ends_at));
 ELSIF OLD.stopped_at IS NULL AND NEW.stopped_at IS NOT NULL THEN
  INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
  VALUES(NEW.stopped_by,'step08_content_trial_stop','content',NEW.version_id::text,b,jsonb_build_object('recipient',NEW.recipient));
 END IF;RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION ff_private.step08_content_trial_audit() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER step08_content_trial_audit AFTER INSERT OR UPDATE OF stopped_at ON ff_private.step08_content_trials FOR EACH ROW EXECUTE FUNCTION ff_private.step08_content_trial_audit();

CREATE FUNCTION ff_private.step08_content_audit() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE targets jsonb;
BEGIN
 IF TG_OP='INSERT' THEN
  INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
  VALUES(NEW.actor_id,'step08_content_draft','content',NEW.id::text,NEW.branch_id,jsonb_build_object('key',NEW.content_key,'role',NEW.role_scope,'previous',NEW.previous_id));
 ELSIF OLD.published_at IS NULL AND NEW.published_at IS NOT NULL THEN
  SELECT coalesce(jsonb_agg(account_id ORDER BY account_id),'[]') INTO targets FROM ff_private.step08_targets(NEW.role_scope,NEW.branch_id)
  WHERE NOT EXISTS(SELECT FROM public.ff_content_catalog WHERE key=NEW.content_key AND screen IN ('login','customer_portal'));
  INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
  VALUES(NEW.published_by,'step08_content_publish','content',NEW.id::text,NEW.branch_id,jsonb_build_object('key',NEW.content_key,'role',NEW.role_scope,'previous',NEW.previous_id,'targets',targets));
 END IF;RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION ff_private.step08_content_audit() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER step08_content_audit AFTER INSERT OR UPDATE OF published_at ON public.ff_content_versions FOR EACH ROW EXECUTE FUNCTION ff_private.step08_content_audit();

CREATE FUNCTION public.ff_step08_content_restore(p_current bigint)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE cur public.ff_content_versions; prev public.ff_content_versions; revision bigint;
BEGIN
 IF NOT EXISTS(SELECT FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN
  PERFORM ff_private.a09_reject_manager('content_restore',p_current,'الاستعادة للمدير العام فقط','42501');RETURN NULL;
 END IF;
 LOCK TABLE public.ff_content_versions IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO STRICT cur FROM public.ff_content_versions WHERE id=p_current AND published_at IS NOT NULL;
 SELECT * INTO STRICT prev FROM public.ff_content_versions WHERE id=cur.previous_id AND published_at IS NOT NULL AND content_key=cur.content_key AND role_scope=cur.role_scope AND branch_id IS NOT DISTINCT FROM cur.branch_id;
 IF EXISTS(SELECT FROM public.ff_content_versions x WHERE x.content_key=cur.content_key AND x.role_scope=cur.role_scope AND x.branch_id IS NOT DISTINCT FROM cur.branch_id AND (x.published_at,x.id)>(cur.published_at,cur.id)) THEN RAISE EXCEPTION 'تغير الإصدار النشط';END IF;
 revision:=public.ff_content_create_draft(cur.content_key,cur.role_scope,cur.branch_id,prev.body);
 PERFORM public.ff_content_publish(revision);
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details) VALUES(auth.uid(),'step08_content_restore','content',revision::text,cur.branch_id,jsonb_build_object('restored_from',prev.id,'replaced',cur.id));
 RETURN revision;
END $$;
REVOKE ALL ON FUNCTION public.ff_step08_content_restore(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_step08_content_restore(bigint) TO authenticated;

CREATE OR REPLACE FUNCTION ff_private.a07_design_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE targets jsonb;
BEGIN
 IF TG_OP='INSERT' THEN
  INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
  VALUES(new.actor_id,'a07_design_draft','ui_design',new.id::text,new.branch_id,jsonb_build_object('screen',new.screen_scope,'role',new.role_scope,'device',new.device,'pack',new.pack,'restored_from',new.restored_from));
 ELSIF old.published_at IS NULL AND new.published_at IS NOT NULL THEN
  SELECT coalesce(jsonb_agg(account_id ORDER BY account_id),'[]') INTO targets FROM ff_private.step08_targets(new.role_scope,new.branch_id) WHERE new.screen_scope NOT IN ('login','customer_portal');
  INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
  VALUES(new.published_by,'a07_design_publish','ui_design',new.id::text,new.branch_id,jsonb_build_object('screen',new.screen_scope,'role',new.role_scope,'device',new.device,'pack',new.pack,'restored_from',new.restored_from,'targets',targets,'public',new.screen_scope IN ('login','customer_portal')));
 END IF;
 RETURN new;
END $function$;

CREATE OR REPLACE FUNCTION ff_private.a07_ranked_candidates(p_screen text, p_role text, p_branch uuid, p_device text, p_actor uuid)
 RETURNS TABLE(revision bigint, style jsonb, rank_order bigint)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 WITH scoped AS (
 SELECT DISTINCT ON (v.screen_scope,v.role_scope,v.branch_id,v.device)
   v.id,v.style_config,v.screen_scope,v.role_scope,v.branch_id,v.device,v.published_at,trial.started_at
 FROM public.ff_ui_versions v
 LEFT JOIN LATERAL (SELECT max(t.started_at) AS started_at FROM public.ff_ui_trials t
  WHERE t.version_id=v.id AND t.recipient=p_actor AND t.stopped_at IS NULL AND t.ends_at>statement_timestamp() AND v.published_at IS NULL
  AND NOT EXISTS(SELECT FROM public.ff_ui_versions newer WHERE newer.screen_scope=v.screen_scope AND newer.role_scope=v.role_scope AND newer.branch_id IS NOT DISTINCT FROM v.branch_id AND newer.device=v.device AND newer.published_at IS NOT NULL AND (v.previous_id IS NULL OR (newer.published_at,newer.id)>(SELECT q.published_at,q.id FROM public.ff_ui_versions q WHERE q.id=v.previous_id)))) trial ON true
 WHERE (v.published_at IS NOT NULL OR trial.started_at IS NOT NULL)
 AND (p_screen NOT IN ('login','customer_portal') OR (v.screen_scope=p_screen AND v.role_scope='all' AND v.branch_id IS NULL AND v.published_at IS NOT NULL))
 AND v.screen_scope IN ('all',p_screen) AND v.role_scope IN ('all',p_role)
 AND (v.branch_id IS NULL OR v.branch_id=p_branch) AND v.device IN ('all',p_device)
 ORDER BY v.screen_scope,v.role_scope,v.branch_id,v.device,(trial.started_at IS NOT NULL) DESC,coalesce(trial.started_at,v.published_at) DESC,v.id DESC
 )
 SELECT id,style_config,row_number() OVER(ORDER BY (started_at IS NOT NULL) DESC,
 ((screen_scope<>'all')::int+(role_scope<>'all')::int+(branch_id IS NOT NULL)::int+(device<>'all')::int) DESC,
 (screen_scope<>'all') DESC,(role_scope<>'all') DESC,(branch_id IS NOT NULL) DESC,(device<>'all') DESC,
 coalesce(started_at,published_at) DESC,id DESC)
 FROM scoped
$function$;

CREATE OR REPLACE FUNCTION ff_private.a07_resolve(p_screen text, p_role text, p_branch uuid, p_device text, p_actor uuid)
 RETURNS SETOF ff_ui_versions
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 SELECT v.* FROM public.ff_ui_versions v
 LEFT JOIN LATERAL (SELECT max(t.started_at) AS started_at FROM public.ff_ui_trials t
  WHERE t.version_id=v.id AND t.recipient=p_actor AND t.stopped_at IS NULL AND t.ends_at>statement_timestamp() AND v.published_at IS NULL
  AND NOT EXISTS(SELECT FROM public.ff_ui_versions newer WHERE newer.screen_scope=v.screen_scope AND newer.role_scope=v.role_scope AND newer.branch_id IS NOT DISTINCT FROM v.branch_id AND newer.device=v.device AND newer.published_at IS NOT NULL AND (v.previous_id IS NULL OR (newer.published_at,newer.id)>(SELECT q.published_at,q.id FROM public.ff_ui_versions q WHERE q.id=v.previous_id)))) trial ON true
 WHERE (v.published_at IS NOT NULL OR trial.started_at IS NOT NULL)
 AND (p_screen NOT IN ('login','customer_portal') OR (v.screen_scope=p_screen AND v.role_scope='all' AND v.branch_id IS NULL AND v.published_at IS NOT NULL))
 AND v.screen_scope IN ('all',p_screen) AND v.role_scope IN ('all',p_role)
 AND (v.branch_id IS NULL OR v.branch_id=p_branch) AND v.device IN ('all',p_device)
 ORDER BY (trial.started_at IS NOT NULL) DESC,
 ((v.screen_scope<>'all')::int+(v.role_scope<>'all')::int+(v.branch_id IS NOT NULL)::int+(v.device<>'all')::int) DESC,
 (v.screen_scope<>'all') DESC,(v.role_scope<>'all') DESC,(v.branch_id IS NOT NULL) DESC,(v.device<>'all') DESC,
 coalesce(trial.started_at,v.published_at) DESC,v.id DESC LIMIT 1
$function$;

CREATE OR REPLACE FUNCTION public.ff_content_effective(p_branch uuid)
 RETURNS TABLE(content_key text, body text, revision bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT DISTINCT ON(v.content_key) v.content_key,v.body,v.id
 FROM public.ff_content_versions v JOIN public.ff_profiles p ON p.user_id=auth.uid() AND p.active
 LEFT JOIN LATERAL (SELECT max(t.started_at) AS started_at FROM ff_private.step08_content_trials t WHERE t.version_id=v.id AND t.recipient=auth.uid() AND t.stopped_at IS NULL AND t.ends_at>statement_timestamp() AND v.published_at IS NULL AND NOT EXISTS(SELECT FROM public.ff_content_catalog c WHERE c.key=v.content_key AND c.screen IN ('login','customer_portal'))) trial ON true
 WHERE auth.uid() IS NOT NULL AND (v.published_at IS NOT NULL OR trial.started_at IS NOT NULL)
 AND (v.role_scope='all' OR v.role_scope=p.role::text)
 AND (v.branch_id IS NULL OR (v.branch_id=p_branch AND (
 public.ff_has_branch(v.branch_id) OR (p.role='customer_service' AND EXISTS(SELECT FROM public.ff_branches b WHERE b.id=v.branch_id AND b.active))
 OR (p.role='supervisor' AND NOT EXISTS(SELECT FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid()) AND EXISTS(SELECT FROM public.ff_branches b WHERE b.id=v.branch_id AND b.active))
 )))
 ORDER BY v.content_key,(trial.started_at IS NOT NULL) DESC,((v.role_scope<>'all')::int+(v.branch_id IS NOT NULL)::int) DESC,(v.role_scope<>'all') DESC,(v.branch_id IS NOT NULL) DESC,coalesce(trial.started_at,v.published_at) DESC,v.id DESC
$function$;

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
 if NOT public.ff83_valid_content(draft.content_key,draft.body) OR (draft.branch_id IS NOT NULL AND NOT EXISTS(SELECT FROM public.ff_branches WHERE id=draft.branch_id AND active)) THEN RAISE EXCEPTION 'النص أو الفرع غير صالح للنشر' USING ERRCODE='22023';END IF;
 select id into prior from public.ff_content_versions where content_key=draft.content_key and role_scope=draft.role_scope
  and branch_id is not distinct from draft.branch_id and published_at is not null order by published_at desc,id desc limit 1;
 if prior is distinct from draft.previous_id then raise exception 'تغير النص المنشور؛ احفظ مسودة جديدة بعد المراجعة'; end if;
 update ff_private.step08_content_trials t set stopped_at=clock_timestamp(),stopped_by=auth.uid() from public.ff_content_versions x where x.id=t.version_id and x.content_key=draft.content_key and x.role_scope=draft.role_scope and x.branch_id is not distinct from draft.branch_id and t.stopped_at is null and t.ends_at>clock_timestamp();
 update public.ff_content_versions set published_at=clock_timestamp(),published_by=auth.uid() where id=p_id;
end $function$;

CREATE OR REPLACE FUNCTION public.ff_ui_control_trial(p_id bigint, p_accounts uuid[], p_hours integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare affected integer; draft public.ff_ui_versions; impact jsonb;
begin
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN
  PERFORM ff_private.a09_reject_manager('design_trial',p_id,'الإجراء للمدير العام فقط','P0001');
  RETURN NULL;
 END IF;
 lock table public.ff_ui_versions in share row exclusive mode;
 select * into draft from public.ff_ui_versions where id=p_id and published_at is null;
 if not found then raise exception 'اختر مسودة متاحة';end if;
 if p_hours=0 then
  update public.ff_ui_trials set stopped_at=now(),stopped_by=auth.uid()
  where version_id=p_id and stopped_at is null and ends_at>now();
  get diagnostics affected=row_count;
  return affected;
 end if;
 impact:=public.ff_step08_release_impact('design',p_id);
 if impact->>'trial_allowed'<>'true' or p_hours is null or p_hours not in (1,8,24) or coalesce(cardinality(p_accounts),0)=0
 or exists(select account from unnest(p_accounts) account except select account_id from public.ff_ui_trial_accounts(p_id))
 then raise exception 'تحقق من مدة التجربة والحسابات المسموحة'; end if;
 update public.ff_ui_trials t set stopped_at=clock_timestamp(),stopped_by=auth.uid() from public.ff_ui_versions x
 where x.id=t.version_id and x.screen_scope=draft.screen_scope and x.role_scope=draft.role_scope and x.branch_id is not distinct from draft.branch_id and x.device=draft.device and t.recipient=ANY(p_accounts) and t.stopped_at is null and t.ends_at>clock_timestamp();
 insert into public.ff_ui_trials(version_id,recipient,started_by,ends_at)
 select distinct p_id,account,auth.uid(),now()+make_interval(hours=>p_hours) from unnest(p_accounts) account;
 get diagnostics affected=row_count;
 return affected;
end $function$;

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
 IF NOT ff_private.step08_design_valid(draft) THEN RAISE EXCEPTION 'خصائص أو نطاق غير صالح للنشر' USING ERRCODE='22023';END IF;
 SELECT id INTO prior FROM public.ff_ui_versions WHERE screen_scope=draft.screen_scope AND role_scope=draft.role_scope AND branch_id IS NOT DISTINCT FROM draft.branch_id AND device=draft.device AND published_at IS NOT NULL ORDER BY published_at DESC,id DESC LIMIT 1;
 IF prior IS DISTINCT FROM draft.previous_id THEN RAISE EXCEPTION 'تغير الإصدار المنشور. راجع التعديلات واحفظ مسودة جديدة'; END IF;
 UPDATE public.ff_ui_trials t SET stopped_at=clock_timestamp(),stopped_by=auth.uid() FROM public.ff_ui_versions x WHERE t.version_id=x.id AND x.screen_scope=draft.screen_scope AND x.role_scope=draft.role_scope AND x.branch_id IS NOT DISTINCT FROM draft.branch_id AND x.device=draft.device AND t.stopped_at IS NULL AND t.ends_at>clock_timestamp();
 UPDATE public.ff_ui_versions SET published_by=auth.uid(),published_at=clock_timestamp() WHERE id=p_id;
END $function$;

CREATE OR REPLACE FUNCTION public.ff_ui_trial_accounts(p_id bigint)
 RETURNS TABLE(account_id uuid, account_name text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select p.account_id,p.account_name from public.ff_ui_versions v cross join lateral ff_private.step08_targets(v.role_scope,v.branch_id) p
 where exists(select from public.ff_profiles m where m.user_id=auth.uid() and m.active and m.role='manager')
 and v.screen_scope NOT IN ('login','customer_portal') and v.published_at is null order by p.account_name,p.account_id
$function$;
