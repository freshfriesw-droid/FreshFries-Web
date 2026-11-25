-- A09 explicit catalog. Stable keys; operational actions and protected financial labels remain fixed.
INSERT INTO public.ff_content_catalog(key,screen,label,original) VALUES
('orders.cancel','orders','تسمية زر إلغاء الطلب','🚫 إلغاء الطلب'),
('orders.add','orders','تسمية زر إضافة أصناف','➕ إضافة أصناف للطلب'),
('orders.add_late','orders','تسمية زر إضافة متأخرة','➕ إضافة بعد خروج الموصل'),
('driver.attend','driver','زر الحضور','تسجيل حضور'),
('driver.leave','driver','زر إنهاء الدوام','إنهاء الدوام'),
('driver.break','driver','زر الاستراحة','الاستراحة'),
('assembly.open','assembly','زر فتح التجميع','فتح التجميع'),
('assembly.burger','assembly','زر أوامر البرجر','أوامر البرجر'),
('burger_kitchen.refresh','burger_kitchen','زر تحديث المطبخ','تحديث'),
('burger_kitchen.finished','burger_kitchen','زر الطلبات المنتهية','الطلبات المنتهية'),
('burger_kitchen.notifications','burger_kitchen','زر إشعارات المطبخ','الإشعارات'),
('catalog.item_save','catalog','زر حفظ الصنف','حفظ الصنف'),
('catalog.offer_save','catalog','زر حفظ العرض','حفظ العرض'),
('archive.export','archive','زر تصدير الأرشيف','تصدير'),
('system.refresh','system','زر تحديث التشخيص','تحديث'),
('system.export','system','زر تصدير التشخيص','تصدير'),
('dashboard.shortcuts','dashboard','عنوان الإجراءات السريعة','الوصول السريع'),
('dashboard.branches','dashboard','عنوان حالة الفروع','حالة الفروع ضمن نطاقك'),
('dashboard.activity','dashboard','عنوان الأنشطة الحديثة','الأنشطة الحديثة — اليوم التشغيلي'),
('reports.pdf_title','reports','عنوان ملف PDF','FRESH FRIES LUXE — مركز التقارير'),
('reports.pdf_note','reports','ملاحظة إضافية في ملف PDF',''),
('orders.success','orders','رسالة نجاح الاعتماد','تم حفظ الطلب'),
('notices.order_summary','notices','قالب ملخص الطلب المعروض','طلب #{order_number} · الموصل: {driver_name} · رسوم التوصيل: {delivery_fee}'),
('notices.new_order','notices','رسالة طلب جديد','طلب جديد بانتظار المتابعة'),
('nav.home','dashboard','القائمة: لوحة التحكم','لوحة التحكم'),
('nav.new','orders','القائمة: طلب جديد','طلب جديد'),
('nav.orders','orders','القائمة: الطلبات والمتابعة','الطلبات والمتابعة'),
('nav.late','notices','القائمة: الطلبات المتأخرة','الطلبات المتأخرة'),
('nav.drivers','driver','القائمة: الموصلون','الموصلون'),
('nav.driver','driver','القائمة: بوابة الموصل','بوابة الموصل'),
('nav.cashier','cashier','القائمة: شاشة الكاشير','شاشة الكاشير'),
('nav.reservations','reservations','القائمة: الحجوزات','الحجوزات'),
('nav.transfer','driver','القائمة: نقل الموصل','نقل الموصل'),
('nav.routes','orders','القائمة: توجيه مناطق الجامعات','توجيه مناطق الجامعات'),
('nav.messages','messages','القائمة: الرسائل','الرسائل'),
('nav.cases','cases','القائمة: الشكاوى والتظلمات','الشكاوى والتظلمات'),
('nav.offers','driver','القائمة: عروض الإسناد','عروض الإسناد'),
('nav.attendance','driver','القائمة: دوامي','دوامي'),
('nav.burger','burger_kitchen','القائمة: أوامر البرجر','أوامر البرجر'),
('nav.cashier_finished','cashier','القائمة: الطلبات المنتهية','الطلبات المنتهية'),
('nav.reports','reports','القائمة: مركز التقارير الإداري','مركز التقارير الإداري'),
('nav.archive','archive','القائمة: الأرشيف','الأرشيف'),
('nav.ratings','ratings','القائمة: التقييمات','التقييمات'),
('nav.catalog','catalog','القائمة: المنيو والعروض','المنيو والعروض'),
('nav.customers','customers','القائمة: العملاء','العملاء'),
('nav.changes','orders','القائمة: تعديل الطلبات','تعديل الطلبات'),
('nav.team','staff','القائمة: الموظفون والصلاحيات','الموظفون والصلاحيات'),
('nav.assembly_admin','assembly','القائمة: إدارة نقطة التجميع','إدارة نقطة التجميع'),
('nav.applications','staff','القائمة: طلبات الانضمام','طلبات الانضمام'),
('nav.application_alerts','staff','القائمة: إشعارات الانضمام','إشعارات الانضمام'),
('nav.branch_policy','staff','القائمة: الفروع وساعات العمل والرسوم','الفروع وساعات العمل والرسوم'),
('nav.staff_link','staff','القائمة: إعادة ربط موظف معتمد','إعادة ربط موظف معتمد'),
('nav.studio','system','القائمة: شاشة تحكم المدير العام','شاشة تحكم المدير العام'),
('nav.data_center','system','القائمة: إدارة البيانات والتصفير','إدارة البيانات والتصفير'),
('nav.security','system','القائمة: أمان النظام','أمان النظام'),
('nav.integrity','system','القائمة: تدقيق سلامة البيانات','تدقيق سلامة البيانات'),
('nav.access','system','القائمة: عزل الفروع','عزل الفروع'),
('nav.readiness','system','القائمة: جاهزية الإطلاق','جاهزية الإطلاق'),
('nav.qa','system','القائمة: الاختبار الشامل','الاختبار الشامل'),
('nav.diagnostics','system','القائمة: تشخيص النسخة','تشخيص النسخة')
ON CONFLICT(key) DO NOTHING;
CREATE OR REPLACE FUNCTION public.ff83_valid_content(p_key text,p_body text)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
DECLARE clean text:=p_body; max_len integer:=180; token text;
BEGIN
 IF p_body IS NULL THEN RETURN true; END IF;
 IF p_key IN ('notices.delayed','notices.reminder','notices.order_summary') THEN
  FOREACH token IN ARRAY ARRAY['order_number','customer_name','driver_name','delivery_fee'] LOOP
   clean:=replace(clean,'{'||token||'}','');
  END LOOP;
 ELSIF p_key IN ('orders.guidance','reports.guidance') THEN
  max_len:=1000;
  clean:=replace(replace(clean,chr(10),''),'[فتح النظام](https://delivery.freshfriesz.com/)','');
 END IF;
 RETURN length(btrim(p_body)) BETWEEN 1 AND max_len AND length(btrim(clean))>0
 AND clean !~ '[<>{}[:cntrl:]]'
 AND clean !~* '(https?://|www\.|javascript:|data:|vbscript:|//)'
 AND translate(p_body,U&'\061C\200E\200F\202A\202B\202C\202D\202E\2066\2067\2068\2069','')=p_body;
END $$;
-- Central service and unassigned supervisors follow the already approved branch scope.
CREATE OR REPLACE FUNCTION public.ff_content_effective(p_branch uuid)
RETURNS TABLE(content_key text,body text,revision bigint) LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT DISTINCT ON(v.content_key) v.content_key,v.body,v.id
 FROM public.ff_content_versions v JOIN public.ff_profiles p ON p.user_id=auth.uid() AND p.active
 WHERE auth.uid() IS NOT NULL AND v.published_at IS NOT NULL
 AND (v.role_scope='all' OR v.role_scope=p.role::text)
 AND (v.branch_id IS NULL OR (v.branch_id=p_branch AND (
 public.ff_has_branch(v.branch_id) OR (p.role='customer_service' AND EXISTS(SELECT FROM public.ff_branches b WHERE b.id=v.branch_id AND b.active))
 OR (p.role='supervisor' AND NOT EXISTS(SELECT FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid()) AND EXISTS(SELECT FROM public.ff_branches b WHERE b.id=v.branch_id AND b.active))
 )))
 ORDER BY v.content_key,((v.role_scope<>'all')::int+(v.branch_id IS NOT NULL)::int) DESC,(v.role_scope<>'all') DESC,(v.branch_id IS NOT NULL) DESC,v.published_at DESC,v.id DESC
$$;
