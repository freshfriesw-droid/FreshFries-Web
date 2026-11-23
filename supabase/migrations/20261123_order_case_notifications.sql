-- Order-linked customer complaints: push to manager, CS, branch supervisor
-- with a durable in-app notification list and per-recipient read receipts.
CREATE TABLE IF NOT EXISTS public.ff_case_alert_receipts (
 case_id uuid NOT NULL REFERENCES public.ff41_cases(id) ON DELETE CASCADE,
 user_id uuid NOT NULL REFERENCES public.ff_profiles(user_id) ON DELETE CASCADE,
 seen_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(case_id,user_id)
);
ALTER TABLE public.ff_case_alert_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ff_case_alert_receipts FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.ff_case_alerts(p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $body$
DECLARE v_role text; v_count integer;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role NOT IN ('manager','supervisor','customer_service') THEN
  RAISE EXCEPTION 'لا توجد صلاحية الاطلاع على إشعارات الشكاوى' USING ERRCODE='42501';
 END IF;
 SELECT count(*) INTO v_count FROM public.ff41_cases c
 WHERE c.kind='customer_complaint' AND c.order_id IS NOT NULL
  AND c.status IN ('open','in_review')
  AND (v_role IN ('manager','customer_service') OR EXISTS
   (SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid() AND ub.branch_id=c.branch_id))
  AND NOT EXISTS(SELECT 1 FROM public.ff_case_alert_receipts r WHERE r.case_id=c.id AND r.user_id=auth.uid());
 RETURN jsonb_build_object('unread_count',v_count,'items',coalesce((
  SELECT jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC) FROM
  (SELECT c.id,c.subject,c.priority,c.status,c.created_at,c.branch_id,c.order_id,o.order_number,
  b.name as branch_name, (r.seen_at IS NOT NULL) as seen
  FROM public.ff41_cases c LEFT JOIN public.ff_orders o ON o.id=c.order_id
   LEFT JOIN public.ff_branches b ON b.id=c.branch_id
   LEFT JOIN public.ff_case_alert_receipts r ON r.case_id=c.id AND r.user_id=auth.uid()
  WHERE c.kind='customer_complaint' AND c.order_id IS NOT NULL
    AND (v_role IN ('manager','customer_service') OR EXISTS(
     SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid() AND ub.branch_id=c.branch_id))
  ORDER BY c.created_at DESC LIMIT least(greatest(coalesce(p_limit,50),1),100)) t
 ),'[]'::jsonb));
END $body$;

CREATE OR REPLACE FUNCTION public.ff_case_alert_read(p_case uuid)
RETURNS boolean LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=''
AS $body$
DECLARE v_role text;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role NOT IN ('manager','supervisor','customer_service') OR NOT EXISTS (
  SELECT 1 FROM public.ff41_cases c WHERE c.id=p_case AND c.kind='customer_complaint'
   AND c.order_id IS NOT NULL
   AND (v_role IN ('manager','customer_service') OR EXISTS
    (SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid() AND ub.branch_id=c.branch_id))
 ) THEN RAISE EXCEPTION 'البلاغ غير متاح لحسابك' USING ERRCODE='42501';END IF;
 INSERT INTO public.ff_case_alert_receipts(case_id,user_id)
 VALUES(p_case,auth.uid()) ON CONFLICT(case_id,user_id) DO NOTHING;
 RETURN true;
END $body$;

CREATE OR REPLACE FUNCTION ff_private.ff_case_order_push()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $body$
BEGIN
 IF NEW.kind<>'customer_complaint' OR NEW.order_id IS NULL THEN RETURN NEW;END IF;
 BEGIN
 INSERT INTO public.ff_push_jobs(user_id,order_id,event_key,kind,title,body)
 SELECT p.user_id,NEW.order_id,'ff-case:'||NEW.id::text,'employee_notice',
  '🚨 بلاغ مرتبط بطلب',
  'شكوى جديدة للطلب #'||coalesce(o.order_number::text,'—')||' · افتح مركز البلاغات'
 FROM public.ff_profiles p
 LEFT JOIN public.ff_orders o ON o.id=NEW.order_id
 WHERE p.active AND (p.role IN ('manager','customer_service') OR
  (p.role='supervisor' AND EXISTS (
   SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=p.user_id AND ub.branch_id=NEW.branch_id)))
 ON CONFLICT(user_id,event_key) DO NOTHING;
 PERFORM ff_private.push_kick();
 EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'تعذر إرسال إشعار الشكوى، البلاغ محفوظ: %',SQLERRM;
 END;
 RETURN NEW;
END $body$;
DROP TRIGGER IF EXISTS ff_case_order_push ON public.ff41_cases;
CREATE TRIGGER ff_case_order_push AFTER INSERT ON public.ff41_cases
FOR EACH ROW EXECUTE FUNCTION ff_private.ff_case_order_push();

REVOKE ALL ON FUNCTION public.ff_case_alerts(integer) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.ff_case_alert_read(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_case_alerts(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ff_case_alert_read(uuid) TO authenticated;
