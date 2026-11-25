-- A09 Realtime invalidation contains only recipient and revision timestamp, never grant settings.
CREATE TABLE public.ff_a09_grant_events(recipient uuid PRIMARY KEY REFERENCES public.ff_profiles(user_id) ON DELETE CASCADE,changed_at timestamptz NOT NULL DEFAULT clock_timestamp());
ALTER TABLE public.ff_a09_grant_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ff_a09_grant_events FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.ff_a09_grant_events TO authenticated;
CREATE POLICY a09_own_grant_event ON public.ff_a09_grant_events FOR SELECT TO authenticated USING (recipient=(SELECT auth.uid()));
CREATE OR REPLACE FUNCTION ff_private.a09_emit_grant_event() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO public.ff_a09_grant_events(recipient,changed_at) VALUES(NEW.recipient,clock_timestamp()) ON CONFLICT(recipient) DO UPDATE SET changed_at=excluded.changed_at;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION ff_private.a09_emit_grant_event() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER a09_grant_changed AFTER INSERT OR UPDATE ON public.ff82_content_grants FOR EACH ROW EXECUTE FUNCTION ff_private.a09_emit_grant_event();
DO $$BEGIN
 IF EXISTS(SELECT FROM pg_publication WHERE pubname='supabase_realtime') AND NOT EXISTS(SELECT FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='ff_a09_grant_events') THEN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.ff_a09_grant_events;
 END IF;
END $$;
