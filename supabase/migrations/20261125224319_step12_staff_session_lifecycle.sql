-- STEP12: prevent pre-suspension sessions from regaining application access after reactivation.
CREATE TABLE ff_private.step12_staff_session_cutoffs (
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 not_before timestamptz NOT NULL
);
ALTER TABLE ff_private.step12_staff_session_cutoffs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE ff_private.step12_staff_session_cutoffs FROM PUBLIC, anon, authenticated;

CREATE FUNCTION ff_private.step12_mark_staff_session_cutoff()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF OLD.active IS DISTINCT FROM NEW.active THEN
  INSERT INTO ff_private.step12_staff_session_cutoffs(user_id,not_before)
  VALUES(NEW.user_id,clock_timestamp())
  ON CONFLICT(user_id) DO UPDATE SET not_before=greatest(ff_private.step12_staff_session_cutoffs.not_before,EXCLUDED.not_before);
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION ff_private.step12_mark_staff_session_cutoff() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER ff_step12_staff_session_cutoff
 AFTER UPDATE OF active ON public.ff_profiles FOR EACH ROW
 WHEN (OLD.active IS DISTINCT FROM NEW.active)
 EXECUTE FUNCTION ff_private.step12_mark_staff_session_cutoff();

CREATE OR REPLACE FUNCTION public.ff_step12_session_valid()
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid; v_session uuid; v_claim text;
BEGIN
 v_uid:=auth.uid(); v_claim:=auth.jwt()->>'session_id';
 IF v_uid IS NULL OR v_claim IS NULL OR v_claim !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN RETURN false; END IF;
 v_session:=v_claim::uuid;
 RETURN EXISTS(SELECT 1 FROM auth.sessions s JOIN auth.users u ON u.id=s.user_id
 WHERE s.id=v_session AND s.user_id=v_uid AND u.deleted_at IS NULL
 AND (u.banned_until IS NULL OR u.banned_until<=statement_timestamp())
 AND (s.not_after IS NULL OR s.not_after>statement_timestamp())
 AND NOT EXISTS(SELECT 1 FROM public.ff_profiles p WHERE p.user_id=v_uid AND NOT p.active)
 AND NOT EXISTS(SELECT 1 FROM ff_private.step12_staff_session_cutoffs c
 WHERE c.user_id=v_uid AND (s.created_at IS NULL OR s.created_at<c.not_before)));
EXCEPTION WHEN invalid_text_representation THEN RETURN false;
END $$;
REVOKE ALL ON FUNCTION public.ff_step12_session_valid() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.ff_step12_session_valid() TO authenticated;
