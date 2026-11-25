-- A11 saved composition templates and cancelled push jobs.
CREATE TABLE public.ff_a11_message_templates(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), owner_id uuid NOT NULL REFERENCES public.ff_profiles(user_id),
 name text NOT NULL CHECK(char_length(btrim(name)) BETWEEN 2 AND 80),
 title text NOT NULL CHECK(char_length(btrim(title)) BETWEEN 2 AND 120),
 body text NOT NULL CHECK(char_length(btrim(body)) BETWEEN 1 AND 2000),
 priority text NOT NULL CHECK(priority IN ('information','operational','urgent')),
 internal_route text CHECK(internal_route IN ('home','messages','attendance','orders','driver','cashier','burger','assembly')),
 requires_ack boolean NOT NULL DEFAULT false, updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(owner_id,name)
);
ALTER TABLE public.ff_a11_message_templates ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ff_a11_message_templates FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.ff_a11_message_templates() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce(jsonb_agg(to_jsonb(t)-'owner_id' ORDER BY t.name),'[]') FROM public.ff_a11_message_templates t WHERE t.owner_id=auth.uid() AND EXISTS(SELECT FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active)
$$;
CREATE FUNCTION public.ff_a11_message_template_save(p_name text,p_title text,p_body text,p_priority text,p_route text,p_ack boolean) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_id uuid;
BEGIN
 IF public.ff_a11_message_access()->>'can_send' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('ok',false,'error','غير مخول');END IF;
 IF char_length(btrim(coalesce(p_name,''))) NOT BETWEEN 2 AND 80 OR char_length(btrim(coalesce(p_title,''))) NOT BETWEEN 2 AND 120 OR char_length(btrim(coalesce(p_body,''))) NOT BETWEEN 1 AND 2000 OR ff_private.a11_priority(p_priority)=0 OR (p_route IS NOT NULL AND p_route NOT IN ('home','messages','attendance','orders','driver','cashier','burger','assembly')) THEN RETURN jsonb_build_object('ok',false,'error','قالب غير صالح');END IF;
 PERFORM pg_advisory_xact_lock(hashtext('a11-template-'||auth.uid()::text));
 IF (SELECT count(*) FROM public.ff_a11_message_templates WHERE owner_id=auth.uid())>=50 AND NOT EXISTS(SELECT FROM public.ff_a11_message_templates WHERE owner_id=auth.uid() AND name=btrim(p_name)) THEN RETURN jsonb_build_object('ok',false,'error','حد القوالب 50');END IF;
 INSERT INTO public.ff_a11_message_templates(owner_id,name,title,body,priority,internal_route,requires_ack) VALUES(auth.uid(),btrim(p_name),btrim(p_title),btrim(p_body),p_priority,p_route,coalesce(p_ack,false))
 ON CONFLICT(owner_id,name) DO UPDATE SET title=excluded.title,body=excluded.body,priority=excluded.priority,internal_route=excluded.internal_route,requires_ack=excluded.requires_ack,updated_at=now() RETURNING id INTO v_id;
 RETURN jsonb_build_object('ok',true,'id',v_id);
END $$;
CREATE FUNCTION public.ff_a11_message_template_delete(p_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT EXISTS(SELECT FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active) THEN RETURN jsonb_build_object('ok',false,'error','غير مخول');END IF;
 DELETE FROM public.ff_a11_message_templates WHERE id=p_id AND owner_id=auth.uid();
 RETURN jsonb_build_object('ok',FOUND);
END $$;
REVOKE ALL ON FUNCTION public.ff_a11_message_templates(),public.ff_a11_message_template_save(text,text,text,text,text,boolean),public.ff_a11_message_template_delete(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a11_message_templates(),public.ff_a11_message_template_save(text,text,text,text,text,boolean),public.ff_a11_message_template_delete(uuid) TO authenticated;
CREATE FUNCTION ff_private.a11_message_cancel_push() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.cancelled_at IS NOT NULL AND OLD.cancelled_at IS NULL THEN
  UPDATE public.ff_push_jobs SET status='failed',last_error='MESSAGE_CANCELLED',updated_at=now() WHERE event_key='message:'||NEW.id AND status IN ('pending','retry');
  -- An already dispatched OS notification cannot be recalled. Notify connected inboxes to refresh.
  UPDATE public.ff39_message_recipients SET read_at=read_at WHERE message_id=NEW.id;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION ff_private.a11_message_cancel_push() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER a11_message_cancel_push AFTER UPDATE OF cancelled_at ON public.ff39_messages FOR EACH ROW EXECUTE FUNCTION ff_private.a11_message_cancel_push();
CREATE OR REPLACE FUNCTION public.ff_push_claim_jobs(p_limit integer DEFAULT 60) RETURNS TABLE(id bigint,user_id uuid,kind text,title text,body text,event_key text)
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 WITH selected AS (
 SELECT j.id FROM public.ff_push_jobs j WHERE j.status IN ('pending','retry','sending') AND j.next_attempt_at<=now() AND j.attempts<5
 AND NOT EXISTS(SELECT FROM public.ff39_messages m WHERE j.kind='message' AND j.event_key='message:'||m.id AND m.cancelled_at IS NOT NULL)
 ORDER BY j.created_at,j.id FOR UPDATE SKIP LOCKED LIMIT least(80,greatest(coalesce(p_limit,60),1))),
 claimed AS (UPDATE public.ff_push_jobs j SET status='sending',attempts=j.attempts+1,next_attempt_at=now()+interval '2 minutes',updated_at=now() FROM selected WHERE selected.id=j.id RETURNING j.id,j.user_id,j.kind,j.title,j.body,j.event_key)
 SELECT claimed.id,claimed.user_id,claimed.kind,claimed.title,claimed.body,claimed.event_key FROM claimed
$$;
CREATE INDEX IF NOT EXISTS ff_a11_message_cancelled_event ON public.ff39_messages (('message:'||id::text)) WHERE cancelled_at IS NOT NULL;
-- Preserve manager-only audit; no message bodies or user secrets in denial details.
CREATE FUNCTION public.ff_a11_message_audit(p_limit integer DEFAULT 50) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT coalesce(public.ff_is_manager(),false) THEN RAISE EXCEPTION 'MANAGER_ONLY' USING ERRCODE='42501';END IF;
 RETURN (SELECT coalesce(jsonb_agg(to_jsonb(a) ORDER BY a.created_at DESC),'[]') FROM (SELECT e.id,e.actor_id,p.display_name AS actor,e.event,e.message_id,e.detail,e.created_at FROM public.ff_a11_message_audit e LEFT JOIN public.ff_profiles p ON p.user_id=e.actor_id ORDER BY e.created_at DESC LIMIT greatest(1,least(coalesce(p_limit,50),100))) a);
END $$;
REVOKE ALL ON FUNCTION public.ff_a11_message_audit(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a11_message_audit(integer) TO authenticated;
