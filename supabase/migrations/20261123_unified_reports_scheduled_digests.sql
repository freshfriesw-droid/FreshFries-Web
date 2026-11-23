-- Scheduled manager-only daily/weekly reporting digests via the existing push queue.
-- pg_cron timezone is GMT: 05:05 UTC = 08:05 Asia/Aden.
-- No external WhatsApp, email or PDF is sent without a provider integration.
CREATE OR REPLACE FUNCTION ff_private.ff_reports_enqueue_digest(p_period text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $body$
DECLARE v_end date:=public.ff_business_date(now())-1;
 v_start date;v_orders integer;v_delivered integer;v_cancelled integer;
 v_amount numeric;v_count integer:=0;v_title text;v_body text;
BEGIN
 IF p_period NOT IN ('daily','weekly') THEN RAISE EXCEPTION 'invalid report period';END IF;
 v_start:=CASE WHEN p_period='weekly' THEN v_end-6 ELSE v_end END;
 SELECT count(*)::integer,
  count(*) FILTER(WHERE status='delivered')::integer,
  count(*) FILTER(WHERE status='cancelled')::integer,
  COALESCE(sum(total) FILTER(WHERE status='delivered'),0)
 INTO v_orders,v_delivered,v_cancelled,v_amount
 FROM public.ff_orders
 WHERE business_date BETWEEN v_start AND v_end AND order_type='delivery';
 v_title:=CASE WHEN p_period='daily' THEN '📊 تقرير فريش فرايز اليومي' ELSE '📊 تقرير فريش فرايز الأسبوعي' END;
 v_body:=v_start||CASE WHEN p_period='weekly' THEN ' إلى '||v_end ELSE '' END||
  ' | الطلبات '||v_orders||' | المسلّمة '||v_delivered||
  ' | الملغاة '||v_cancelled||' | قيمة المسلّمة '||v_amount||
  ' ر.ي | افتح مركز التقارير للتفاصيل والمعاينة';
 INSERT INTO public.ff_push_jobs(user_id,order_id,event_key,kind,title,body)
 SELECT p.user_id,NULL,'ff-report:'||p_period||':'||v_end::text,
   'employee_notice',v_title,v_body
 FROM public.ff_profiles p WHERE p.active AND p.role='manager'
 ON CONFLICT(user_id,event_key) DO NOTHING;
 GET DIAGNOSTICS v_count=ROW_COUNT;
 IF v_count>0 THEN PERFORM ff_private.push_kick();END IF;
 RETURN v_count;
END $body$;
REVOKE ALL ON FUNCTION ff_private.ff_reports_enqueue_digest(text) FROM PUBLIC,anon,authenticated;
-- Reliable scheduler; re-applying same named job replaces schedule without duplicates.
SELECT cron.schedule('ff_luxe_manager_daily_report','5 5 * * *',
  'SELECT ff_private.ff_reports_enqueue_digest(''daily'');');
SELECT cron.schedule('ff_luxe_manager_weekly_report','7 5 * * 1',
  'SELECT ff_private.ff_reports_enqueue_digest(''weekly'');');
