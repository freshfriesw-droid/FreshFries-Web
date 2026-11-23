-- Burger kitchen safety + live availability, additive release.
-- Existing tickets and order workflows remain unchanged.
ALTER TABLE public.ff_burger_tickets
 ADD COLUMN IF NOT EXISTS notes_confirmed_at timestamptz,
 ADD COLUMN IF NOT EXISTS notes_confirmed_by uuid REFERENCES public.ff_profiles(user_id);

CREATE TABLE IF NOT EXISTS public.ff_burger_presence (
 user_id uuid PRIMARY KEY REFERENCES public.ff_profiles(user_id) ON DELETE CASCADE,
 branch_id uuid NOT NULL REFERENCES public.ff_branches(id),
 online boolean NOT NULL DEFAULT false,
 last_seen_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.ff_burger_presence ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ff_burger_presence FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.ff_burger_presence_ping(p_online boolean DEFAULT true)
RETURNS boolean LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=''
AS $body$
DECLARE v_branch uuid;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active AND p.role='burger_kitchen') THEN
  RAISE EXCEPTION 'الحضور لقسم البرجر فقط' USING ERRCODE='42501';
 END IF;
 SELECT ub.branch_id INTO v_branch FROM public.ff_user_branches ub JOIN public.ff_branches b ON b.id=ub.branch_id AND b.active
 WHERE ub.user_id=auth.uid() LIMIT 1;
 IF v_branch IS NULL THEN RAISE EXCEPTION 'حساب البرجر بلا فرع' USING ERRCODE='42501';END IF;
 INSERT INTO public.ff_burger_presence(user_id,branch_id,online,last_seen_at)
 VALUES(auth.uid(),v_branch,coalesce(p_online,true),clock_timestamp())
 ON CONFLICT(user_id) DO UPDATE SET branch_id=EXCLUDED.branch_id,online=EXCLUDED.online,
 last_seen_at=EXCLUDED.last_seen_at;
 RETURN true;
END $body$;

CREATE OR REPLACE FUNCTION public.ff_burger_online_status()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $body$
DECLARE v_role text;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role NOT IN ('cashier','burger_kitchen') THEN RAISE EXCEPTION 'غير مصرح' USING ERRCODE='42501'; END IF;
 RETURN coalesce((
  SELECT jsonb_agg(jsonb_build_object(
   'branch_id',b.id,'branch_name',b.name,'online_count',
   (SELECT count(*) FROM public.ff_burger_presence t JOIN public.ff_profiles p ON p.user_id=t.user_id AND p.active AND p.role='burger_kitchen'
    WHERE t.branch_id=b.id AND t.online AND t.last_seen_at>now()-interval '75 seconds'),
   'last_seen_at',(SELECT max(t.last_seen_at) FROM public.ff_burger_presence t
    JOIN public.ff_profiles p ON p.user_id=t.user_id AND p.active AND p.role='burger_kitchen' WHERE t.branch_id=b.id)
   ) ORDER BY b.name)
  FROM public.ff_user_branches ub JOIN public.ff_branches b ON b.id=ub.branch_id AND b.active
  WHERE ub.user_id=auth.uid()
 ),'[]'::jsonb);
END $body$;

CREATE OR REPLACE FUNCTION public.ff_burger_confirm_notes(p_ticket uuid)
RETURNS boolean LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=''
AS $body$
DECLARE v_ticket public.ff_burger_tickets%ROWTYPE;
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active AND p.role='burger_kitchen') THEN
  RAISE EXCEPTION 'يؤكد التنفيذ موظف البرجر المستلم فقط' USING ERRCODE='42501'; END IF;
 SELECT * INTO v_ticket FROM public.ff_burger_tickets WHERE id=p_ticket FOR UPDATE;
 IF NOT FOUND OR v_ticket.status<>'preparing' OR v_ticket.kitchen_id IS DISTINCT FROM auth.uid() THEN
  RAISE EXCEPTION 'لا يمكن اعتماد الملاحظات لهذا الطلب' USING ERRCODE='42501'; END IF;
 IF length(btrim(v_ticket.notes))=0 THEN RETURN true;END IF;
 IF v_ticket.notes_confirmed_at IS NULL THEN
  UPDATE public.ff_burger_tickets SET notes_confirmed_at=clock_timestamp(),notes_confirmed_by=auth.uid()
  WHERE id=p_ticket;
 END IF;
 RETURN true;
END $body$;

-- Also protect against any future RPC that changes status without confirmation.
CREATE OR REPLACE FUNCTION ff_private.ff_burger_ready_notes_guard()
RETURNS trigger LANGUAGE plpgsql SET search_path=''
AS $body$
BEGIN
 IF NEW.status='ready' AND OLD.status='preparing'
   AND length(btrim(NEW.notes))>0 AND NEW.notes_confirmed_at IS NULL THEN
  RAISE EXCEPTION 'لا يمكن إنهاء البرجر قبل تأكيد تنفيذ الملاحظات' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $body$;
DROP TRIGGER IF EXISTS ff_burger_ready_notes_guard ON public.ff_burger_tickets;
CREATE TRIGGER ff_burger_ready_notes_guard BEFORE UPDATE OF status ON public.ff_burger_tickets
FOR EACH ROW EXECUTE FUNCTION ff_private.ff_burger_ready_notes_guard();

DO $patch$
DECLARE source text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO source FROM pg_proc p
 WHERE p.pronamespace='public'::regnamespace AND p.proname='ff_burger_list';
 IF source IS NULL OR position('t.cashier_name,t.kitchen_id,t.kitchen_name,t.items,t.notes,t.status' in source)=0 THEN
   RAISE EXCEPTION 'Burger list source changed';END IF;
 source:=replace(source,'t.cashier_name,t.kitchen_id,t.kitchen_name,t.items,t.notes,t.status',
 't.cashier_name,t.kitchen_id,t.kitchen_name,t.items,t.notes,t.notes_confirmed_at,t.status');
 EXECUTE source;
 SELECT pg_get_functiondef(p.oid) INTO source FROM pg_proc p
 WHERE p.pronamespace='public'::regnamespace AND p.proname='ff_burger_transition';
 IF source IS NULL OR position('AND v_row.kitchen_id=auth.uid() THEN' in source)=0 THEN
   RAISE EXCEPTION 'Burger transition source changed';END IF;
 source:=replace(source,'AND v_row.kitchen_id=auth.uid() THEN',
  'AND v_row.kitchen_id=auth.uid() THEN
   IF length(btrim(v_row.notes))>0 AND v_row.notes_confirmed_at IS NULL THEN
     RAISE EXCEPTION ''أكد تنفيذ الملاحظات المرفقة قبل جاهزية الطلب'' USING ERRCODE=''42501'';
   END IF;');
 EXECUTE source;
END $patch$;
REVOKE ALL ON FUNCTION public.ff_burger_presence_ping(boolean) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.ff_burger_online_status() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.ff_burger_confirm_notes(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_burger_presence_ping(boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ff_burger_online_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.ff_burger_confirm_notes(uuid) TO authenticated;
