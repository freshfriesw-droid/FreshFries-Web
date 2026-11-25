# STEP09 — مراجعة التشغيل الشاملة (25 نوفمبر 2026)
الحالة: قيد التنفيذ — ليست مغلقة. 8/15 مغلقة.
مرجع البداية: main b6dffd60a6601f2c7cf9531e8346fcc0f6ea6eac؛ وثيقة 24 نوفمبر وخطة 25 نوفمبر وأمر التنفيذ؛ STEP08 مغلقة. لا إطلاق ولا تصفير.
فرع العمل: step09-operational-integration-20261125؛ [PR #129](https://github.com/freshfriesw-droid/FreshFries-Web/pull/129). رأس التصحيح 3fee967e3c440db84b77fd81bec72142a4685287. الكود التشغيلي لا يتغير إلا في محلل الإدخال السريع؛ بيانات حقيقية محفوظة.
## أدلة Supabase الحية
22 مجموعة SQL ناجحة (PASS صريح، rollback)، دون ترحيل جديد:
- a02_order_roundtrip_rollback, a02_addition_roundtrip_rollback, a03_dispatch_rotation_rollback, a04_assembly_burger_rollback, a05_staff_scope_rollback, a06_navigation_scope_rollback
- a03_offer_deadline_rollback, a03_reassignment_scope_rollback, a04_branch_realtime_rollback, a05_atomic_approval_rollback, a02_contact_sync_rollback, a02_addition_events_rollback
- a03_managed_reoffer_rollback, a03_reply_lock_order_rollback, a03_cashier_lifecycle_rollback, a02_catalog_integrity_rollback, a02_ui_completion_rollback, a05_cashier_desk_reset_rollback, a02_order_edit_cancel_rollback, a02_rpc_write_boundary_rollback
- step09_operational_integration_rollback (جديد، commit 67de5d0521025468f63ead87948be33d4bee6c86): طلب القاهرة، عرض وقبول، منع تسليم الكاشير والتجميع مع إضافة معلقة، فاتورة وإلغاء، إرسال برجر مرتبط بالطلب واستلامه وتأكيد الملاحظات وتجهيزه وإقراره، تحديث حالة التجميع والكاشير المشتركة، إضافة متأخرة بموافقة الموصل وفاتورتها واستلامها ووصول وتسليم. حسابا QA للتجميع والمطبخ مؤقتان داخل المعاملة؛ تأكيد اختفاء الحسابين والتذكرة وعودة حالة حضور الموصل.
- special_courier_capacity: خمسة تكليفات/عروض، رفض السادس، عدم ازدواج العرض والمهمة، تجاوز المدير بسبب وسجل تدقيق، تغيير السقف، تحرير السعة بالإلغاء وإعادة الإسناد.
## التصحيح والتحقق
- FIX-05: سطر حر بعد أجرة التوصيل كان يُفسّر كاسم موصل دون التحقق. الآن اسم مسجل كامل أو اسم أول فريد فقط؛ الاسم الأول الملتبس يظهر خطأ معاينة، والملاحظة الحرة لا تضيع، والحقل المسمى صراحة محفوظ. اختبارات ثابتة للتمييز والالتباس والأسماء غير النشطة.
- فشل P2 الأول [45687436569](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45687436569) عند حارس التطابق النصي بعد نجاح 147 مقارنة تاريخية، لأن التعديل المقصود خارج قائمة الفروق. أضيف تطبيع **كتلة المصدر القديمة والجديدة المحددتين حرفيًا فقط** إلى الحارس، مع استمرار مقارنة المتصفحات وRGB الفعلية دون تغيير. إعادة الاختبار [45687815529](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45687815529) جارية عند تسجيل هذا السجل. لا ادعاء نجاحها قبل ظهور النتيجة.
## مصفوفة تقدم STEP09 (لا قبول نهائي بعد)
| البند | الدليل المثبت | المتبقي |
|---|---|---|
| FIX-02 | Chrome static head الأول: اختيار البرجر والسلة والتراجع ناجحة؛ A02 SQL roundtrip | نجاح CI الرأس النهائي |
| FIX-03 / DEC-05 / DEC-07 | A06 SQL وChrome؛ [الدليل السابق](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45513491807) | مراجعة تغطية كل المسارات غير المثبتة |
| FIX-05 | تصحيح المحلل واختباره الثابت نجح ضمن فحص validate frontend للرأس الأول | الدمج والنشر |
| FIX-06 | إنشاء الطلب وتطابق البيانات في SQL | رحلة متصفح متكاملة لكل فرع وطريقة غير المثبتة |
| FIX-07 | contact sync rollback | التنبيه عبر هاتف فعلي STEP14 |
| FIX-08 | addition rollback/events + integration + [Chrome](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45687815470) | نشر الرأس النهائي |
| FIX-09 / FIX-10 / DEC-08 | rotation/deadline/reassignment/reoffer/capacity SQL؛ [تنافس PostgreSQL سابق](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45503116787) | تغطية التزامن المكملة غير المثبتة |
| FIX-11 / FIX-12 / FIX-13 | integration + cashier lifecycle + assembly 40 assertions؛ [تنافس سابق](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45506019343) | التكامل المتعدد للجلسات المكمل؛ الأجهزة STEP14 |
| FIX-14 / FIX-15 | staff scope 30 + atomic approval 7 + RPC write boundary؛ [Edge سابق](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45509575723) | تحقق تغطية الصلاحيات المكملة |
| FIX-16 | branch realtime 9 + draft cart Chrome + [A05 browser](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45687815208) | اختبار استقبال تحديث طلب من جلسة أخرى أثناء تحرير طلب دون فقد التركيز والسلة |
## الاستئناف
تابع CI على رأس PR #129؛ لا دمج قبل نجاح جميع الاختبارات المطلوبة. ثم تحقق نشر النطاق الرسمي ونطاقه الفرعي، وأكمل تغطية السيناريوهات غير المثبتة أعلاه فقط. فحص الاتصال المباشر بالموقع من البيئة الحالية تعذر بسبب DNS؛ استخدم دليل runner بعد الدمج. الاختبارات الميدانية فقط STEP14؛ التدقيق الأمني العام STEP12. لا تبدأ STEP10 ولا تغير حالة الإغلاق حتى استيفاء الشروط.
