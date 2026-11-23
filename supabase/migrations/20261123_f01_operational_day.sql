-- F-01 / Fresh Fries LUXE / 2026-11-23
-- Apply on a *separate staging database* first; production deployment requires passing
-- supabase/tests/f01_business_date.sql and explicit production release verification.
-- This migration does not delete orders, reset sequence numbers, or alter operational_date.
-- Migration runners apply this file inside their own transaction.

CREATE OR REPLACE FUNCTION public.ff_business_date(ts timestamptz)
RETURNS date LANGUAGE sql IMMUTABLE STRICT SET search_path = ''
AS $$
  SELECT CASE
    WHEN EXTRACT(HOUR FROM ts AT TIME ZONE 'Asia/Aden') >= 8
    THEN (ts AT TIME ZONE 'Asia/Aden')::date
    ELSE ((ts AT TIME ZONE 'Asia/Aden')::date - 1)
  END
$$;
COMMENT ON FUNCTION public.ff_business_date(timestamptz) IS
'Business day begins 08:00 Asia/Aden. 00:00–07:59 belong to the previous business date.';
REVOKE ALL ON FUNCTION public.ff_business_date(timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ff_business_date(timestamptz) TO authenticated,service_role;

ALTER TABLE public.ff_orders
 ADD COLUMN IF NOT EXISTS business_date date,
 ADD COLUMN IF NOT EXISTS closed_hours_flag boolean;

-- Additive backfill: ONLY newly introduced fields. Existing created_at,
-- operational_date, order numbers, notes, order statuses and totals are unchanged.
UPDATE public.ff_orders o SET
  business_date = public.ff_business_date(o.created_at),
  closed_hours_flag = (
    EXTRACT(HOUR FROM (o.created_at AT TIME ZONE 'Asia/Aden')) >= 2
    AND EXTRACT(HOUR FROM (o.created_at AT TIME ZONE 'Asia/Aden')) < 8
  )
WHERE o.business_date IS DISTINCT FROM public.ff_business_date(o.created_at)
   OR o.closed_hours_flag IS DISTINCT FROM (
    EXTRACT(HOUR FROM (o.created_at AT TIME ZONE 'Asia/Aden')) >= 2
    AND EXTRACT(HOUR FROM (o.created_at AT TIME ZONE 'Asia/Aden')) < 8
  );

ALTER TABLE public.ff_orders
  ALTER COLUMN business_date SET NOT NULL,
  ALTER COLUMN closed_hours_flag SET DEFAULT false,
  ALTER COLUMN closed_hours_flag SET NOT NULL;

CREATE INDEX IF NOT EXISTS ff_orders_business_date_branch_idx
 ON public.ff_orders (business_date DESC,branch_id,created_at DESC);

CREATE OR REPLACE FUNCTION ff_private.ff_f01_stamp_order()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.business_date := public.ff_business_date(NEW.created_at);
    NEW.closed_hours_flag := (
      EXTRACT(HOUR FROM NEW.created_at AT TIME ZONE 'Asia/Aden') >= 2
      AND EXTRACT(HOUR FROM NEW.created_at AT TIME ZONE 'Asia/Aden') < 8
    );
    RETURN NEW;
  END IF;
  -- Never mutate the historic business date or its source timestamp.
  IF NEW.created_at IS DISTINCT FROM OLD.created_at
     OR NEW.business_date IS DISTINCT FROM OLD.business_date
     OR NEW.closed_hours_flag IS DISTINCT FROM OLD.closed_hours_flag
  THEN
    RAISE EXCEPTION 'لا يمكن تغيير التاريخ التشغيلي أو وقت إنشاء الطلب بعد الحفظ'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS ff_f01_stamp_order ON public.ff_orders;
CREATE TRIGGER ff_f01_stamp_order
BEFORE INSERT OR UPDATE OF created_at,business_date,closed_hours_flag
ON public.ff_orders FOR EACH ROW
EXECUTE FUNCTION ff_private.ff_f01_stamp_order();

-- Safe anomaly notification: strictly manager-only, no customer PII or
-- phone numbers in locked-screen notifications. Existing push pipeline used.
CREATE OR REPLACE FUNCTION ff_private.ff_f01_anomaly_notice()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF NOT NEW.closed_hours_flag THEN RETURN NEW; END IF;
  BEGIN
    INSERT INTO public.ff_audit_log
      (actor_id,action,entity_type,entity_id,branch_id,details)
    VALUES
      (NEW.created_by,'f01_closed_hours_order','order',NEW.id::text,NEW.branch_id,
      jsonb_build_object('order_number',NEW.order_number,
        'business_date',NEW.business_date,'created_at',NEW.created_at,
        'local_time',(NEW.created_at AT TIME ZONE 'Asia/Aden')));
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'F01 audit deferred: %',SQLERRM;
  END;
  BEGIN
    INSERT INTO public.ff_push_jobs(user_id,order_id,event_key,kind,title,body)
    SELECT p.user_id,NEW.id,'f01-closed-hours:'||NEW.id::text,
      'employee_notice','⚠️ طلب خارج ساعات العمل',
      'طلب رقم #'||NEW.order_number||' خارج نافذة 8 ص–2 ص؛ راجع سجل الطلب'
    FROM public.ff_profiles p WHERE p.role='manager' AND p.active=true
    ON CONFLICT (user_id,event_key) DO NOTHING;
    PERFORM ff_private.push_kick();
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'F01 manager push deferred: %',SQLERRM;
  END;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS ff_f01_anomaly_notice ON public.ff_orders;
CREATE TRIGGER ff_f01_anomaly_notice
AFTER INSERT ON public.ff_orders FOR EACH ROW
EXECUTE FUNCTION ff_private.ff_f01_anomaly_notice();

-- Separate readonly RPC, keeps ff38_snapshot and active/unfinished orders unfiltered.
CREATE OR REPLACE FUNCTION public.ff_f01_daily_summary(
 p_date date DEFAULT NULL, p_compare_date date DEFAULT NULL,
 p_branch uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_role text; v_date date:=coalesce(p_date,public.ff_business_date(now()));
  v_compare date:=coalesce(p_compare_date,v_date - 1);
  v_items jsonb;
BEGIN
  SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active=true;
  IF v_role NOT IN ('manager','customer_service','supervisor')
    OR NOT public.ff38_permission_allowed(auth.uid(),'view_reports')
  THEN RAISE EXCEPTION 'ليس لديك صلاحية الاطلاع على إحصائيات اليوم' USING ERRCODE='42501';
  END IF;
  IF v_date < date '2020-01-01' OR v_date>public.ff_business_date(now())
    OR v_compare < date '2020-01-01' OR v_compare>public.ff_business_date(now())
  THEN RAISE EXCEPTION 'تاريخ المقارنة غير صالح' USING ERRCODE='22023'; END IF;
  IF p_branch IS NOT NULL AND NOT EXISTS(
    SELECT 1 FROM public.ff_branches b WHERE b.id=p_branch AND b.active
      AND (v_role IN ('manager','customer_service') OR EXISTS (
        SELECT 1 FROM public.ff_user_branches ub
        WHERE ub.user_id=auth.uid() AND ub.branch_id=p_branch))
  ) THEN RAISE EXCEPTION 'الفرع غير مصرح به' USING ERRCODE='42501'; END IF;
  WITH days AS (SELECT v_date AS day UNION ALL SELECT v_compare),
  counts AS (
    SELECT d.day, count(o.id)::integer AS orders,
     count(o.id) FILTER (WHERE o.status='delivered')::integer AS delivered,
     count(o.id) FILTER (WHERE o.status IN ('cancelled','canceled'))::integer AS cancelled,
     count(o.id) FILTER (WHERE o.closed_hours_flag)::integer AS anomalies,
     coalesce(sum(o.total) FILTER (
       WHERE o.id IS NOT NULL AND o.status NOT IN ('cancelled','canceled')),0)::numeric AS value
    FROM days d
    LEFT JOIN public.ff_orders o ON o.business_date=d.day
      AND o.order_type='delivery'
      AND (p_branch IS NULL OR o.branch_id=p_branch)
      AND (v_role IN ('manager','customer_service') OR EXISTS (
        SELECT 1 FROM public.ff_user_branches ub
        WHERE ub.user_id=auth.uid() AND ub.branch_id=o.branch_id))
    GROUP BY d.day
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object('day',day,'orders',orders,
   'delivered',delivered,'cancelled',cancelled,'anomalies',anomalies,
   'value',value) ORDER BY day DESC),'[]'::jsonb)
  INTO v_items FROM counts;
  RETURN jsonb_build_object('business_date',v_date,'comparison_date',v_compare,
    'timezone','Asia/Aden','opens','08:00','closes','02:00','days',v_items);
END $$;
REVOKE ALL ON FUNCTION public.ff_f01_daily_summary(date,date,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_f01_daily_summary(date,date,uuid) TO authenticated,service_role;
