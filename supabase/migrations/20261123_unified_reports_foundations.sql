-- Fresh Fries LUXE reporting-only attendance history and approved report annotations.
-- Additive: no existing driver shifts, orders or live presence records are modified.
CREATE TABLE IF NOT EXISTS public.ff_report_driver_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.ff_drivers(id),
  started_at timestamptz NOT NULL,
  ended_at timestamptz,
  capture_source text NOT NULL DEFAULT 'tracked' CHECK (capture_source IN ('tracked','partial_start')),
  recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (ended_at IS NULL OR ended_at >= started_at)
);
CREATE UNIQUE INDEX IF NOT EXISTS ff_report_driver_one_open ON public.ff_report_driver_sessions(driver_id)
WHERE ended_at IS NULL;
CREATE INDEX IF NOT EXISTS ff_report_driver_session_period ON public.ff_report_driver_sessions(driver_id,started_at,ended_at);
ALTER TABLE public.ff_report_driver_sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ff_report_driver_sessions FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION ff_private.ff_report_capture_driver_session()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $body$
BEGIN
  IF TG_OP='INSERT' THEN
    IF NEW.state<>'offline' THEN
      INSERT INTO public.ff_report_driver_sessions(driver_id,started_at,capture_source)
      VALUES(NEW.driver_id,COALESCE(NEW.checked_in_at,clock_timestamp()),'tracked')
      ON CONFLICT (driver_id) WHERE ended_at IS NULL DO NOTHING;
    END IF;
  ELSIF OLD.state='offline' AND NEW.state<>'offline' THEN
    -- Only an explicit check-in can start a fresh session.
    INSERT INTO public.ff_report_driver_sessions(driver_id,started_at,capture_source)
    VALUES(NEW.driver_id,clock_timestamp(),'tracked')
    ON CONFLICT (driver_id) WHERE ended_at IS NULL DO NOTHING;
  ELSIF OLD.state<>'offline' AND NEW.state='offline' THEN
    UPDATE public.ff_report_driver_sessions
       SET ended_at=GREATEST(started_at,clock_timestamp())
     WHERE driver_id=NEW.driver_id AND ended_at IS NULL;
  END IF;
  RETURN NEW;
END $body$;
DROP TRIGGER IF EXISTS ff_report_driver_session_capture ON public.ff38_driver_presence;
CREATE TRIGGER ff_report_driver_session_capture
AFTER INSERT OR UPDATE OF state ON public.ff38_driver_presence
FOR EACH ROW EXECUTE FUNCTION ff_private.ff_report_capture_driver_session();

-- Existing active sessions lack historic start times: record ONLY the installation
-- moment, marked "partial_start". This prevents invented historic attendance.
INSERT INTO public.ff_report_driver_sessions(driver_id,started_at,capture_source)
SELECT p.driver_id,clock_timestamp(),'partial_start'
  FROM public.ff38_driver_presence p WHERE p.state<>'offline'
ON CONFLICT (driver_id) WHERE ended_at IS NULL DO NOTHING;

CREATE TABLE IF NOT EXISTS public.ff_report_manager_notes(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_key text NOT NULL UNIQUE,
  business_date date NOT NULL,
  branch_id uuid REFERENCES public.ff_branches(id),
  note_text text NOT NULL DEFAULT '',
  manual_expenses numeric(14,2),
  approver_name text,
  approved_at timestamptz,
  created_by uuid NOT NULL REFERENCES public.ff_profiles(user_id),
  modified_by uuid NOT NULL REFERENCES public.ff_profiles(user_id),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (manual_expenses IS NULL OR (manual_expenses>=0 AND manual_expenses<=100000000000)),
  CHECK (length(note_text)<=5000),
  CHECK (approver_name IS NULL OR length(approver_name)<=120)
);
ALTER TABLE public.ff_report_manager_notes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ff_report_manager_notes FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.ff_report_note_save(
 p_day date,p_branch uuid,p_note text DEFAULT '',p_manual_expenses numeric DEFAULT NULL,
 p_approver text DEFAULT NULL,p_approve boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $body$
DECLARE v_uid uuid:=auth.uid();v_key text;v_saved public.ff_report_manager_notes%ROWTYPE;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles
   WHERE user_id=v_uid AND role='manager' AND active) THEN
   RAISE EXCEPTION 'حفظ واعتماد تقارير الإدارة للمدير فقط' USING ERRCODE='42501';END IF;
 IF p_day IS NULL OR p_day<'2020-01-01'::date OR p_day>public.ff_business_date(now()) THEN
   RAISE EXCEPTION 'تاريخ التقرير غير صالح';END IF;
 IF p_branch IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.ff_branches WHERE id=p_branch) THEN
   RAISE EXCEPTION 'الفرع غير معروف';END IF;
 IF length(coalesce(p_note,''))>5000 OR length(coalesce(p_approver,''))>120 OR
  p_manual_expenses<0 OR p_manual_expenses>100000000000 THEN
   RAISE EXCEPTION 'تجاوزت حدود الملاحظات أو المبالغ';END IF;
 IF p_approve AND length(btrim(coalesce(p_approver,'')))<2 THEN
   RAISE EXCEPTION 'أدخل اسم المدير المعتمد قبل التوقيع';END IF;
 v_key:=to_char(p_day,'YYYY-MM-DD')||':'||coalesce(p_branch::text,'ALL');
 INSERT INTO public.ff_report_manager_notes AS n(
  note_key,business_date,branch_id,note_text,manual_expenses,
  approver_name,approved_at,created_by,modified_by)
 VALUES(v_key,p_day,p_branch,coalesce(p_note,''),p_manual_expenses,
  CASE WHEN p_approve THEN btrim(p_approver) ELSE NULL END,
  CASE WHEN p_approve THEN clock_timestamp() ELSE NULL END,v_uid,v_uid)
 ON CONFLICT(note_key) DO UPDATE SET
   note_text=EXCLUDED.note_text,
   manual_expenses=EXCLUDED.manual_expenses,
   approver_name=EXCLUDED.approver_name,
   approved_at=EXCLUDED.approved_at,
   modified_by=v_uid,updated_at=clock_timestamp()
 RETURNING * INTO v_saved;
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 VALUES(v_uid,CASE WHEN p_approve THEN 'report_approved' ELSE 'report_note_saved' END,
  'report_note',v_saved.id::text,p_branch,
  jsonb_build_object('day',p_day,'approved',p_approve,'manual_expenses',p_manual_expenses));
 RETURN jsonb_build_object('saved',true,'approved_at',v_saved.approved_at,'id',v_saved.id);
END $body$;

REVOKE ALL ON FUNCTION public.ff_report_note_save(date,uuid,text,numeric,text,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_report_note_save(date,uuid,text,numeric,text,boolean) TO authenticated;
