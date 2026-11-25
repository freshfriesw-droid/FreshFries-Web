# STEP11 — اختبارات SQL الحية الإضافية

26 نوفمبر 2026، توقيت عدن. تم تنفيذ الاستعلامين التاليين فعليًا على مشروع Supabase الرسمي بعد ترحيلات STEP11، ونجحا. بيانات الاختبار داخل subtransaction متراجعة بالكامل؛ لا تشغيل ميداني ولا إرسال خارجي ملتزم ولا حذف دائم. كل التحقق من الجداول العامة معزول بأرقام UUID اختبارية. اختبار no-device منفصل موثق في سجل STEP11-progress.

## التأخير: النتيجة PASS
```sql
DO $qa$
DECLARE b uuid:=gen_random_uuid(); b2 uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); x uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); o uuid:=gen_random_uuid(); f uuid:=gen_random_uuid(); before_count int; k text;
BEGIN
 BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-step11-'||b,'QA isolated'),(b2,'qa-step11-'||b2,'QA foreign');
 INSERT INTO auth.users(id) VALUES(m),(c),(x);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA manager','manager',true),(c,'QA cashier','cashier',true),(x,'QA foreign','cashier',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c,b),(x,b2);
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d,'QA late driver',b);
 INSERT INTO public.ff38_driver_presence(driver_id,state,checked_in_at,last_seen_at) VALUES(d,'ready',now(),now());
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,area_snapshot,created_by,items_total,delivery_fee,total) VALUES(o,-1000000000000-floor(random()*1e12)::bigint,b,'000000000','QA',m,1000,500,1500),(f,-2000000000000-floor(random()*1e12)::bigint,b,'000000000','QA',m,1000,500,1500);
 INSERT INTO public.ff38_delivery_tasks(order_id,driver_id,assigned_at) VALUES(o,d,now()-interval '35 minutes'),(f,d,now()-interval '5 minutes');
 PERFORM ff_private.push_late_orders();
 k:='late:'||o||':'||(floor(extract(epoch from now())/900))::bigint;
 IF NOT EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE order_id=o AND event_key=k AND user_id=c) OR NOT EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE order_id=o AND event_key=k AND user_id=m) THEN RAISE EXCEPTION 'Late warning missing';END IF;
 IF EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE order_id=o AND event_key=k AND user_id=x) OR EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE order_id=f AND kind='late') THEN RAISE EXCEPTION 'Late scope or time invalid';END IF;
 SELECT count(*) INTO before_count FROM public.ff_push_jobs WHERE order_id=o AND event_key=k;
 PERFORM ff_private.push_late_orders();
 IF (SELECT count(*) FROM public.ff_push_jobs WHERE order_id=o AND event_key=k)<>before_count THEN RAISE EXCEPTION 'Duplicate late warning';END IF;
 RAISE EXCEPTION 'rollback' USING ERRCODE='PZ011';
 EXCEPTION WHEN SQLSTATE 'PZ011' THEN NULL;END;
 IF EXISTS(SELECT 1 FROM public.ff_branches WHERE id IN (b,b2)) OR EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE order_id IN (o,f)) THEN RAISE EXCEPTION 'Rollback incomplete';END IF;
END $qa$;
SELECT 'PASS STEP11 late threshold, branch isolation, manager notification, deduplication and rollback' result;
```

## حفظ دليل الرسالة من تنظيف 30 يومًا: النتيجة PASS
```sql
DO $qa$
DECLARE u uuid:=gen_random_uuid(); k text:='qa-step11-retention:'||gen_random_uuid();
BEGIN
 BEGIN
 INSERT INTO auth.users(id) VALUES(u);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(u,'QA retention','customer_service',true) ON CONFLICT(user_id) DO NOTHING;
 INSERT INTO public.ff_push_jobs(user_id,event_key,kind,title,body,status,created_at,sent_at,provider_accepted_at) VALUES
 (u,k||':message','message','QA','QA','sent',now()-interval '31 days',now()-interval '31 days',now()-interval '31 days'),
 (u,k||':alert','late','QA','QA','sent',now()-interval '31 days',now()-interval '31 days',null),
 (u,k||':pending','late','QA','QA','pending',now()-interval '31 days',null,null);
 PERFORM ff_private.push_cron_tick();
 IF NOT EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE event_key=k||':message' AND provider_accepted_at IS NOT NULL) OR EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE event_key=k||':alert') OR NOT EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE event_key=k||':pending') THEN RAISE EXCEPTION 'Retention behavior incorrect';END IF;
 RAISE EXCEPTION 'rollback' USING ERRCODE='PZ011';
 EXCEPTION WHEN SQLSTATE 'PZ011' THEN NULL;END;
 IF EXISTS(SELECT 1 FROM auth.users WHERE id=u) OR EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE user_id=u) THEN RAISE EXCEPTION 'QA rollback incomplete';END IF;
END $qa$;
SELECT 'PASS STEP11 actual cron: old message evidence preserved, completed operational alerts expire, pending survives, rollback' result;
```

## تحقق لاحق حي
- 3 فروع نشطة، 0 فروع QA، 0 حسابات QA المتبقية التي أنشأناها، 0 وظائف retention QA، 0 جداول public دون RLS.
- 15/15 دورة cron ناجحة؛ آخر دورة وقت الفحص 2026-11-25 21:33:00 UTC، كل دقيقة، صفر فشل.
- لا يوجد إثبات provider_accepted_at لرسالة حقيقية حتى لحظة الفحص؛ لا ادعاء باستلام هاتف فعلي. اختبار الجهاز الحقيقي ضمن STEP14.
