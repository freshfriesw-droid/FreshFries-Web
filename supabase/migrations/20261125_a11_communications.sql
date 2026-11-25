-- A11 MSG-01..05: extend existing message store; no historical rows deleted.
ALTER TABLE public.ff39_messages ADD COLUMN IF NOT EXISTS priority text NOT NULL DEFAULT 'information' CHECK(priority IN ('information','operational','urgent')),
 ADD COLUMN IF NOT EXISTS internal_route text CHECK(internal_route IN ('home','messages','attendance','orders','driver','cashier','burger','assembly')),
 ADD COLUMN IF NOT EXISTS archived_at timestamptz, ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;
ALTER TABLE public.ff39_messages DROP CONSTRAINT ff39_messages_target_role_check;
ALTER TABLE public.ff39_messages ADD CONSTRAINT ff39_messages_target_role_check CHECK(target_role IN ('all','manager','customer_service','cashier','driver','supervisor','assembly','burger_kitchen'));
CREATE TABLE public.ff_a11_message_grants (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES public.ff_profiles(user_id),
 target_role text NOT NULL CHECK(target_role IN ('all','manager','customer_service','cashier','driver','supervisor','assembly','burger_kitchen')),
 branch_id uuid REFERENCES public.ff_branches(id), max_priority text NOT NULL CHECK(max_priority IN ('information','operational','urgent')),
 granted_by uuid NOT NULL REFERENCES public.ff_profiles(user_id), granted_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL, revoked_at timestamptz
);
CREATE INDEX ON public.ff_a11_message_grants(user_id,expires_at) WHERE revoked_at IS NULL;
CREATE TABLE public.ff_a11_message_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, actor_id uuid, event text NOT NULL, message_id uuid,
 detail jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.ff_a11_message_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ff_a11_message_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ff_a11_message_grants,public.ff_a11_message_audit FROM PUBLIC,anon,authenticated;
CREATE FUNCTION ff_private.a11_priority(p text) RETURNS integer LANGUAGE sql IMMUTABLE SET search_path='' AS $$ SELECT CASE p WHEN 'information' THEN 1 WHEN 'operational' THEN 2 WHEN 'urgent' THEN 3 ELSE 0 END $$;
CREATE FUNCTION ff_private.a11_message_allowed(p_role text,p_branch uuid,p_priority text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active)
 AND p_role IN ('all','manager','customer_service','cashier','driver','supervisor','assembly','burger_kitchen')
 AND ff_private.a11_priority(p_priority)>0
 AND (p_branch IS NULL OR EXISTS(SELECT FROM public.ff_branches b WHERE b.id=p_branch AND b.active))
 AND (public.ff_is_manager() OR EXISTS(SELECT FROM public.ff_a11_message_grants g
 WHERE g.user_id=auth.uid() AND g.revoked_at IS NULL AND g.expires_at>now()
 AND (g.target_role='all' OR g.target_role=p_role)
 AND (g.branch_id IS NULL OR g.branch_id=p_branch)
 AND ff_private.a11_priority(g.max_priority)>=ff_private.a11_priority(p_priority)))
$$;
CREATE FUNCTION ff_private.a11_message_audience(p_role text,p_branch uuid,p_people uuid[]) RETURNS TABLE(user_id uuid,display_name text,role text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT p.user_id,p.display_name,p.role FROM public.ff_profiles p
 WHERE p.active AND p.user_id<>auth.uid() AND (p_role='all' OR p.role=p_role)
 AND (p_people IS NULL OR p.user_id=ANY(p_people))
 AND (p.role<>'assembly' OR EXISTS(SELECT FROM public.ff_v9_assembly_access a JOIN public.ff_branches b ON b.id=a.branch_id AND b.active WHERE a.user_id=p.user_id AND a.enabled AND (p_branch IS NULL OR a.branch_id=p_branch)))
 AND (p.role<>'driver' OR EXISTS(SELECT FROM public.ff38_driver_links l JOIN public.ff_drivers d ON d.id=l.driver_id JOIN public.ff_branches b ON b.id=d.branch_id AND b.active WHERE l.user_id=p.user_id AND d.active AND (p_branch IS NULL OR d.branch_id=p_branch)))
 AND (p_branch IS NULL OR p.role IN ('assembly','driver') OR EXISTS(SELECT FROM public.ff_user_branches u WHERE u.user_id=p.user_id AND u.branch_id=p_branch))
 ORDER BY p.user_id LIMIT 501
$$;
CREATE FUNCTION public.ff_a11_message_access() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('manager',public.ff_is_manager(),'can_send',EXISTS(SELECT FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active) AND (public.ff_is_manager() OR EXISTS(SELECT FROM public.ff_a11_message_grants g WHERE g.user_id=auth.uid() AND g.revoked_at IS NULL AND g.expires_at>now())),
 'grants',coalesce((SELECT jsonb_agg(jsonb_build_object('role',g.target_role,'branch',g.branch_id,'priority',g.max_priority,'expires_at',g.expires_at)) FROM public.ff_a11_message_grants g WHERE g.user_id=auth.uid() AND g.revoked_at IS NULL AND g.expires_at>now()),'[]'::jsonb))
$$;
CREATE FUNCTION public.ff_a11_message_preview(p_role text,p_branch uuid,p_priority text,p_people uuid[] DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE a jsonb; n integer;
BEGIN
 IF ff_private.a11_message_allowed(p_role,p_branch,p_priority) IS DISTINCT FROM true THEN
  INSERT INTO public.ff_a11_message_audit(actor_id,event,detail) VALUES(auth.uid(),'denied_preview',jsonb_build_object('role',p_role,'branch',p_branch,'priority',p_priority));
  RETURN jsonb_build_object('ok',false,'error','غير مخول للاستهداف');
 END IF;
 SELECT count(*),coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.user_id),'[]') INTO n,a FROM ff_private.a11_message_audience(p_role,p_branch,p_people) x;
 IF n>500 OR (p_people IS NOT NULL AND n<>(SELECT count(DISTINCT u) FROM unnest(p_people) u)) THEN RETURN jsonb_build_object('ok',false,'error','المستلمون خارج النطاق أو تجاوزوا الحد');END IF;
 RETURN jsonb_build_object('ok',true,'count',n,'people',a);
END $$;
CREATE FUNCTION public.ff_a11_message_send(p_title text,p_body text,p_role text,p_branch uuid,p_priority text,p_people uuid[],p_expected uuid[],p_ack boolean DEFAULT false,p_route text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid();v_ids uuid[];v_n integer;v_msg uuid;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtext('ff39-send-'||coalesce(v_uid::text,'')));
 IF ff_private.a11_message_allowed(p_role,p_branch,p_priority) IS DISTINCT FROM true THEN
  INSERT INTO public.ff_a11_message_audit(actor_id,event,detail) VALUES(v_uid,'denied_send',jsonb_build_object('role',p_role,'branch',p_branch,'priority',p_priority));
  RETURN jsonb_build_object('ok',false,'error','غير مخول للإرسال');
 END IF;
 IF char_length(btrim(coalesce(p_title,''))) NOT BETWEEN 2 AND 120 OR char_length(btrim(coalesce(p_body,''))) NOT BETWEEN 1 AND 2000 OR (p_route IS NOT NULL AND p_route NOT IN ('home','messages','attendance','orders','driver','cashier','burger','assembly')) THEN
 RETURN jsonb_build_object('ok',false,'error','عنوان أو محتوى أو رابط غير صالح');END IF;
 IF (SELECT count(*) FROM public.ff39_messages WHERE sender_id=v_uid AND created_at>now()-interval '1 hour')>=30 THEN RETURN jsonb_build_object('ok',false,'error','تم بلوغ حد الإرسال خلال ساعة');END IF;
 SELECT array_agg(x.user_id ORDER BY x.user_id),count(*) INTO v_ids,v_n FROM ff_private.a11_message_audience(p_role,p_branch,p_people) x;
 IF v_n NOT BETWEEN 1 AND 500 OR (p_people IS NOT NULL AND v_n<>(SELECT count(DISTINCT u) FROM unnest(p_people) u)) OR v_ids IS DISTINCT FROM (SELECT array_agg(DISTINCT u ORDER BY u) FROM unnest(p_expected) u) THEN
 RETURN jsonb_build_object('ok',false,'error','تغير الجمهور؛ أعد المعاينة');END IF;
 INSERT INTO public.ff39_messages(sender_id,title,body,target_role,target_branch,requires_ack,priority,internal_route)
 VALUES(v_uid,btrim(p_title),btrim(p_body),p_role,p_branch,coalesce(p_ack,false),p_priority,p_route) RETURNING id INTO v_msg;
 INSERT INTO public.ff39_message_recipients(message_id,user_id) SELECT v_msg,unnest(v_ids);
 INSERT INTO public.ff_a11_message_audit(actor_id,event,message_id,detail) VALUES(v_uid,'sent',v_msg,jsonb_build_object('recipients',v_n,'role',p_role,'branch',p_branch,'priority',p_priority));
 RETURN jsonb_build_object('ok',true,'sent',true,'message_id',v_msg,'recipients',v_n);
END $$;
CREATE FUNCTION public.ff_a11_message_grant(p_user uuid,p_role text,p_branch uuid,p_priority text,p_expires timestamptz) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_id uuid;
BEGIN
 IF NOT coalesce(public.ff_is_manager(),false) THEN
 INSERT INTO public.ff_a11_message_audit(actor_id,event) VALUES(auth.uid(),'denied_grant');RETURN jsonb_build_object('ok',false,'error','المدير فقط');END IF;
 IF NOT EXISTS(SELECT FROM public.ff_profiles p WHERE p.user_id=p_user AND p.active AND p.role<>'manager') OR p_role IS NULL OR p_role NOT IN ('all','manager','customer_service','cashier','driver','supervisor','assembly','burger_kitchen') OR ff_private.a11_priority(p_priority)=0 OR p_expires IS NULL OR p_expires<=now() OR p_expires>now()+interval '365 days' OR (p_branch IS NOT NULL AND NOT EXISTS(SELECT FROM public.ff_branches WHERE id=p_branch AND active)) THEN RETURN jsonb_build_object('ok',false,'error','تفويض غير صالح');END IF;
 INSERT INTO public.ff_a11_message_grants(user_id,target_role,branch_id,max_priority,granted_by,expires_at) VALUES(p_user,p_role,p_branch,p_priority,auth.uid(),p_expires) RETURNING id INTO v_id;
 INSERT INTO public.ff_a11_message_audit(actor_id,event,detail) VALUES(auth.uid(),'grant',jsonb_build_object('id',v_id,'user',p_user,'role',p_role,'branch',p_branch,'priority',p_priority,'expires',p_expires));
 RETURN jsonb_build_object('ok',true,'id',v_id);
END $$;
CREATE FUNCTION public.ff_a11_message_revoke(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT coalesce(public.ff_is_manager(),false) THEN INSERT INTO public.ff_a11_message_audit(actor_id,event) VALUES(auth.uid(),'denied_revoke');RETURN jsonb_build_object('ok',false,'error','المدير فقط');END IF;
 UPDATE public.ff_a11_message_grants SET revoked_at=now() WHERE id=p_id AND revoked_at IS NULL;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'error','التفويض غير متاح');END IF;
 INSERT INTO public.ff_a11_message_audit(actor_id,event,detail) VALUES(auth.uid(),'revoke',jsonb_build_object('id',p_id));RETURN jsonb_build_object('ok',true);
END $$;
CREATE FUNCTION public.ff_a11_message_grants() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT coalesce(public.ff_is_manager(),false) THEN RAISE EXCEPTION 'MANAGER_ONLY' USING ERRCODE='42501';END IF;
 RETURN jsonb_build_object('grants',coalesce((SELECT jsonb_agg(to_jsonb(g)||jsonb_build_object('name',p.display_name) ORDER BY g.granted_at DESC) FROM public.ff_a11_message_grants g JOIN public.ff_profiles p ON p.user_id=g.user_id WHERE g.revoked_at IS NULL AND g.expires_at>now()),'[]'),
 'staff',coalesce((SELECT jsonb_agg(jsonb_build_object('id',p.user_id,'name',p.display_name,'role',p.role) ORDER BY p.display_name) FROM public.ff_profiles p WHERE p.active AND p.role<>'manager'),'[]'));
END $$;
CREATE FUNCTION public.ff_a11_message_history(p_limit integer DEFAULT 50) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF NOT EXISTS(SELECT FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active) THEN RAISE EXCEPTION 'FORBIDDEN' USING ERRCODE='42501';END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC),'[]') INTO result FROM (
 SELECT m.id,m.title,m.target_role AS role,m.target_branch AS branch_id,m.priority,m.created_at,m.archived_at,m.cancelled_at,m.requires_ack,p.display_name AS sender,
 (SELECT count(*) FROM public.ff39_message_recipients r WHERE r.message_id=m.id) AS recipients,
 (SELECT count(*) FROM public.ff39_message_recipients r WHERE r.message_id=m.id AND r.read_at IS NOT NULL) AS read_count,
 (SELECT count(*) FROM public.ff39_message_recipients r WHERE r.message_id=m.id AND r.acknowledged_at IS NOT NULL) AS ack_count,
 (SELECT count(DISTINCT j.user_id) FROM public.ff_push_jobs j WHERE j.event_key='message:'||m.id AND j.status='sent') AS push_accepted_count
 FROM public.ff39_messages m JOIN public.ff_profiles p ON p.user_id=m.sender_id
 WHERE public.ff_is_manager() OR m.sender_id=auth.uid() ORDER BY m.created_at DESC LIMIT greatest(1,least(coalesce(p_limit,50),100))
 ) x;RETURN result;
END $$;
CREATE FUNCTION public.ff_a11_message_state(p_id uuid,p_action text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE m public.ff39_messages%ROWTYPE;
BEGIN
 SELECT * INTO m FROM public.ff39_messages WHERE id=p_id FOR UPDATE;
 IF m.id IS NULL OR NOT EXISTS(SELECT FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active) OR (NOT public.ff_is_manager() AND (m.sender_id<>auth.uid() OR ff_private.a11_message_allowed(m.target_role,m.target_branch,m.priority) IS DISTINCT FROM true)) THEN
 INSERT INTO public.ff_a11_message_audit(actor_id,event,message_id) VALUES(auth.uid(),'denied_state',p_id);RETURN jsonb_build_object('ok',false,'error','غير مخول');END IF;
 IF p_action='archive' THEN UPDATE public.ff39_messages SET archived_at=coalesce(archived_at,now()) WHERE id=p_id;
 ELSIF p_action='cancel' THEN
 IF EXISTS(SELECT FROM public.ff39_message_recipients r WHERE r.message_id=p_id AND r.read_at IS NOT NULL) THEN RETURN jsonb_build_object('ok',false,'error','تمت قراءة الرسالة؛ يمكن أرشفتها فقط');END IF;
 UPDATE public.ff39_messages SET cancelled_at=coalesce(cancelled_at,now()) WHERE id=p_id;
 ELSE RETURN jsonb_build_object('ok',false,'error','إجراء غير صالح');END IF;
 INSERT INTO public.ff_a11_message_audit(actor_id,event,message_id) VALUES(auth.uid(),p_action,p_id);
 RETURN jsonb_build_object('ok',true);
END $$;
CREATE OR REPLACE FUNCTION public.ff39_inbox(p_limit integer DEFAULT 60,p_unread_only boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); a jsonb; u integer; k integer;
BEGIN
 IF NOT EXISTS(SELECT FROM public.ff_profiles p WHERE p.user_id=v_uid AND p.active) THEN RAISE EXCEPTION 'حساب غير مفعل' USING ERRCODE='42501';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'عدد الرسائل غير صالح';END IF;
 SELECT count(*) FILTER(WHERE r.read_at IS NULL),count(*) FILTER(WHERE m.requires_ack AND r.acknowledged_at IS NULL) INTO u,k FROM public.ff39_message_recipients r JOIN public.ff39_messages m ON m.id=r.message_id WHERE r.user_id=v_uid AND m.cancelled_at IS NULL;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC,x.id DESC),'[]') INTO a FROM (
 SELECT m.id,m.title,m.body,p.display_name AS sender,m.created_at,r.read_at,m.requires_ack,r.acknowledged_at,m.target_role AS role,m.target_branch AS branch_id,m.priority,m.internal_route
 FROM public.ff39_message_recipients r JOIN public.ff39_messages m ON m.id=r.message_id JOIN public.ff_profiles p ON p.user_id=m.sender_id WHERE r.user_id=v_uid AND m.cancelled_at IS NULL AND (NOT coalesce(p_unread_only,false) OR r.read_at IS NULL) ORDER BY m.created_at DESC,m.id DESC LIMIT p_limit) x;
 RETURN jsonb_build_object('items',a,'unread_count',u,'pending_ack_count',k);
END $$;
CREATE OR REPLACE FUNCTION public.ff39_mark_read(p_message uuid,p_ack boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid();m public.ff39_messages%ROWTYPE;v_read timestamptz;v_ack timestamptz;
BEGIN
 IF NOT EXISTS(SELECT FROM public.ff_profiles p WHERE p.user_id=v_uid AND p.active) THEN RAISE EXCEPTION 'FORBIDDEN' USING ERRCODE='42501';END IF;
 SELECT * INTO m FROM public.ff39_messages WHERE id=p_message FOR UPDATE;
 IF m.id IS NULL OR m.cancelled_at IS NOT NULL THEN RAISE EXCEPTION 'الرسالة غير متاحة' USING ERRCODE='42501';END IF;
 UPDATE public.ff39_message_recipients r SET read_at=coalesce(r.read_at,now()),acknowledged_at=CASE WHEN p_ack IS TRUE AND m.requires_ack THEN coalesce(r.acknowledged_at,now()) ELSE r.acknowledged_at END WHERE r.message_id=p_message AND r.user_id=v_uid RETURNING r.read_at,r.acknowledged_at INTO v_read,v_ack;
 IF NOT FOUND THEN RAISE EXCEPTION 'الرسالة غير متاحة' USING ERRCODE='42501';END IF;
 RETURN jsonb_build_object('saved',true,'read_at',v_read,'acknowledged_at',v_ack);
END $$;
-- Legacy manager-only entry points retain compatibility while enforcing the same strict branch audience.
CREATE OR REPLACE FUNCTION public.ff39_admin_send(p_title text,p_body text,p_role text DEFAULT 'all',p_branch uuid DEFAULT NULL,p_requires_ack boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ids uuid[];r jsonb;
BEGIN
 IF NOT coalesce(public.ff_is_manager(),false) THEN RAISE EXCEPTION 'MANAGER_ONLY' USING ERRCODE='42501';END IF;
 SELECT array_agg(user_id ORDER BY user_id) INTO ids FROM ff_private.a11_message_audience(p_role,p_branch,NULL);
 r:=public.ff_a11_message_send(p_title,p_body,p_role,p_branch,'information',NULL,ids,p_requires_ack,NULL);
 IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION '%',r->>'error';END IF;RETURN r;
END $$;
CREATE OR REPLACE FUNCTION public.ff69_admin_send_assembly(p_title text,p_body text,p_branch uuid DEFAULT NULL,p_requires_ack boolean DEFAULT false) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT public.ff39_admin_send(p_title,p_body,'assembly',p_branch,p_requires_ack) $$;
-- Recipient rows expose no message body and are visible only to their active owner for Realtime.
GRANT SELECT ON public.ff39_message_recipients TO authenticated;
CREATE POLICY a11_recipient_realtime ON public.ff39_message_recipients FOR SELECT TO authenticated USING (user_id=(SELECT auth.uid()) AND EXISTS(SELECT FROM public.ff_profiles p WHERE p.user_id=(SELECT auth.uid()) AND p.active));
DO $$ BEGIN IF EXISTS(SELECT FROM pg_publication WHERE pubname='supabase_realtime') AND NOT EXISTS(SELECT FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='ff39_message_recipients') THEN ALTER PUBLICATION supabase_realtime ADD TABLE public.ff39_message_recipients;END IF;END $$;
REVOKE ALL ON FUNCTION ff_private.a11_priority(text),ff_private.a11_message_allowed(text,uuid,text),ff_private.a11_message_audience(text,uuid,uuid[]) FROM PUBLIC,anon,authenticated;
DO $$ DECLARE r record;BEGIN FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname LIKE 'ff_a11_message_%' LOOP EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon',r.sig);EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',r.sig);END LOOP;END $$;
