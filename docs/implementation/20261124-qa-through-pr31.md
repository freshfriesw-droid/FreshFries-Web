# أدلة قبول جزئية — 24 نوفمبر 2026

النسخة التجريبية المفحوصة `19717a64df7488ffde9fffc39c331edc2b862ee9`. ما زال قرار الجاهزية النهائي مفتوحًا.

| الفحص | النتيجة | حدود الدليل |
|---|---|---|
| جرد الأساس | PASS | مطابقة 53 ملفًا في شجرة Git، انظر خريطة FIX-03 |
| مرادفات الأصناف والعروض | PASS للاختبارات الآلية | نجاح المحلل واختبار SQL للأدوار، والتحديث المتزامن، والاستعادة. لم تُجرَ رحلة طلب من حسابين على الموقع |
| تاريخ العمل | PASS | دالة تاريخ العمل عند الحدود الزمنية واتساق الحقول التاريخية وفق `supabase/tests/f01_business_date.sql` |
| سعة الموصل الخاص | PASS | بلوغ السقف، والاستثناء مع السبب، وتحرير السعة بعد الإلغاء والنقل وفق `supabase/tests/special_courier_capacity.sql`. اختبار تنافس جلستين على الإسناد ما زال مفتوحًا |
| عرض القائمة عند تغيير حجم الشاشة | PASS | تذكرت الواجهة وضع الجوال والكمبيوتر في الجلسة نفسها عبر الانتقال 390 ← 1024 ← 390 |
| أحجام واجهة RTL | PASS للسيناريوهات المشمولة | اختبر Chrome المقاسات 320 و344 و360 و390 و430 و768 و850 و851 و1024 و1280 و1440. مصفوفة كل تصميم ودور وجهاز فعلي ما زالت مفتوحة |
| تنزيل النسخة التجريبية | PASS | تطابقت صفحة HTML من النطاق التجريبي مع بصمة Git المنشورة. بصمة SHA-256 هي `c97c3415b223f25729f959140858b69d1e874b45aac97de51540bb4e202e8b45` |

تراجعت معاملات اختبارات قاعدة البيانات بعد التحقق. لم تتضمن هذه الفحوص تصفيرًا أو إرسال طلب تشغيلي. نتائج Chrome متاحة في [اختبارات المرادفات](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45296620122) و[اختبارات تغير الجهاز والمقاسات](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45338436540).

## ملفات النشر

تطابقت الملفات الـ25 أدناه بايتًا ببايت مع النسخة السابقة المختبرة `5e88b97`. أظهر فرق Git حتى `19717a6` أن أيًا من هذه الأصول لم يتغير. أُعيد فحص HTML على النسخة الأخيرة بصورة مستقلة.

- `./assets/ff-icon-192.png`
- `./assets/ff-pinned-cairo-v38-37.js?v=20261124-preview-guard`
- `./assets/luxe-report-center-20261123.css`
- `./manifest.webmanifest`
- `./offline.html`
- `./scripts/luxe-all-menus-fold-20261123.js?v=20261123-unified-menu3`
- `./scripts/luxe-burger-kitchen-20261123.js?v=20261123-unified-menu3`
- `./scripts/luxe-case-alerts-20261123.js`
- `./scripts/luxe-cashier-destinations-20261122.js`
- `./scripts/luxe-collapsible-sections-manager-create-20261123.js`
- `./scripts/luxe-completed-detail-popup-20261123.js`
- `./scripts/luxe-completed-universal-20261123.js`
- `./scripts/luxe-driver-cancel-20261122.js`
- `./scripts/luxe-f01-operational-day-20261123.js`
- `./scripts/luxe-foreground-ring-20261122.js`
- `./scripts/luxe-history-period-20261123.js`
- `./scripts/luxe-one-time-rewards-20261123.js`
- `./scripts/luxe-operational-fixes-20261121.js`
- `./scripts/luxe-operational-polish-20261121.js`
- `./scripts/luxe-order-customer-edit-20261123.js?v=20261124-reason`
- `./scripts/luxe-report-center-20261123.js`
- `./scripts/luxe-shared-photo-menu-20261123.js?v=20261123-unified-menu3`
- `./scripts/luxe-unified-order-inputs-20261123.js?v=20261123-unified-menu3`
- `./styles/ffx-nav-groups.css`
- `./sw.js`

## بنود مفتوحة

يلزم استكمال جرد الإجراءات داخل الواجهات الخاصة، ومسارات إنشاء الطلب والإضافة بعد الإنشاء وتعديل العميل بحسابات تجريبية مفوضة، والتزامن بين الجلسات، قبل إغلاق بوابات التشغيل. لكل من التصاميم الستة عشر، وتفويض محرر التصميم، والرسائل، والتقارير، والتجربة على الأجهزة الفعلية أدلة قبول مستقلة لم تُجمع في هذا التقرير.
