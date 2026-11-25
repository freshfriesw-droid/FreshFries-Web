# A12 — سجل المراجعة الشاملة قبل الاعتماد | 25 نوفمبر 2026

المرجع المغلق: وثيقة 24 نوفمبر 2026، 49 صفحة، SHA256 `18820bbd27e2939f21c617d5d34aafeccd491e4346c1f6f0b4a2d96288a6fc62`. المراجعة مرتبطة بمصفوفة A01 الأصلية وبطلبات الدمج وأدلتها؛ لا تغير الوثيقة ولا تعتبر الدليل المرحلي قبولًا فرديًا. لا إطلاق رسمي، ولا بدء خطة 15 خطوة المنفصلة.

## التنفيذ الفعلي في A12
- تصفير حسب الفرع والنوع والفترة، مع معاينة عدد السجلات والتبعيات، تأكيد مكتوب ومطابقة بصمة الخطة، حفظ نسخة محمية في المعاملة نفسها، تحقق بعد الحذف والاسترجاع، سجل دائم للعمليات وصلاحية المدير حصراً.
- النطاق الآمن: فقط الطلبات الاصطناعية التي ينشئها مدير عبر أداة الاختبار (ملغاة، صفر قيمة، دون عميل أو موصل)، وسطورها وأحداثها وروابط الكاشير المحددة. كل تبعية خارج القائمة تمنع التنفيذ، بما فيها SET NULL وCASCADE. لا تُصنّف الطلبات الموجودة مسبقًا كتجريبية بالتخمين. الحد 100 طلب و31 يومًا لكل دفعة.
- ترحيل `a12_selective_recovery` مطبق على قاعدة الموقع، 22 تحقق SQL قبل/بعد التطبيق وChrome [45535797970](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45535797970) ناجح. PR [#97](https://github.com/freshfriesw-droid/FreshFries-Web/pull/97) لتحديث التطبيق. ألغيت صلاحيات الدوال القديمة ذات التصفير العام.
- مراجعة إضافية: اكتشاف قراءة 21 سجل موظف و1 إعداد من حساب مصادق غير موظف. ترحيل `a12_legacy_privacy` مطبق؛ ضبط دليل الموظفين للمدير وإعدادات التشغيل والصلاحيات للموظف النشط، إزالة منح anon القديمة من سبعة جداول. ستة تحقق SQL ناجحة قبل/بعد التطبيق. إعادة A02 customer staff boundary (18 منع)، A05 staff scope (30)، A05 report scope (13) ناجحة بعد الإصلاح.
- قبل وبعد الاختبار: 82 طلبًا و13 حسابًا/ملفًا وظيفيًا و21 سجل تدقيق، دون بقايا QA. كل 102 جدول public عليها RLS؛ 0 جدول مع منح CRUD لـ anon بعد إصلاح الخصوصية. لا حذف لسجل تشغيلي أو حساب.

## إعادة التحقق المجمعة
نجحت 28 مجموعة SQL على قاعدة الموقع في معاملات تنتهي بالتراجع، قبل إصلاح الخصوصية؛ أعيدت المجموعات المرتبطة به بعده.
- A02–A04: order_roundtrip, rpc_write_boundary, addition_roundtrip, customer_staff_boundary, reservation_roundtrip, cashier_lifecycle, dispatch_rotation, dispatch_branch_scope, assembly_burger, branch_realtime.
- A05–A08: atomic_approval, branch_policy, cashier_desk_reset, report_scope, staff_scope, navigation_scope, elements_registry, property_layers, screen_design_scope, card_inheritance, dashboard.
- A09–A11: content_elements, design_delegation, manager_denial_audit, quality, reporting, communications, templates_attendance.
- A12: selective_recovery (22), legacy_privacy (6). لا عدّ لمجموعات الاختبار كأنها عدد تأكيدات فردية.
- نجاح النشر A11 موثق [45534553785](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45534553785) ومطابقة الأصل المنشور [45534554187](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45534554187) والثابت [45534554162](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45534554162). نتائج دمج ونشر A12 تضاف في سجل PR عند اكتمالها.

## قيود وعناصر مفتوحة
- نسخة الاسترجاع A12 هي لقطة لسجلات التجربة المحددة، وليست نسخة احتياطية كاملة لقاعدة البيانات. استعادة مشروع كامل في بيئة منفصلة غير مثبتة؛ لا حذف بيانات تشغيلية لإجراء الاختبار.
- فحص Security Advisor سجل تنبيهات RLS دون سياسة (بنية deny-by-default/RPC لبعض الجداول)، ودوال SECURITY DEFINER للمستخدم المصادق، وامتداد في public وحماية كلمات المرور المسربة. ليست جميعها أعطالًا مثبتة، لكن مراجعة الصلاحيات الفردية وحماية الحسابات تبقى شرط اعتماد. لا تزعم هذه المراجعة انعدام الثغرات.
- القبول الميداني: تسجيل دخول الموظفين الحقيقيين بحسب الدور والفرع، أجهزة هاتف وحاسوب، جلسات متزامنة فعلية، إشعارات وصوت وخلفية PWA/انقطاع الشبكة، طلب وتوزيع وتحضير وتسليم وتقييم، حضور واستراحة، تجربة الكاشير والمطبخ ونقاط التجميع للفروع الثلاثة، التقارير والطباعة والمشاركة، تحقق بيانات العمل والرسوم والأرقام المعتمدة. MicroPOS عند تفعيله. لقطات إثبات فعلية.
- لا تُنقل الاختبارات أو الإعدادات غير المثبتة إلى PASS جماعي. أي نقص تطويري يتكشف يجب معالجته قبل قبول P7.
- خطة 15 خطوة التالية ليست ضمن هذا التنفيذ؛ أسماء خطواتها الأصلية وترتيبها لم يُسترجعا بصورة موثوقة.

## مراجعة التتبع (149 صفاً من الأصل)
الروابط أدناه تشير إلى حزمة التنفيذ لا إلى شهادة قبول لكل صف. عمود المطلوب يعيد شرط الإغلاق الأصلي لتجنب إسقاط أي مطلب. اختبار القبول النهائي لكل صف باقٍ حتى إثباته، ولا يحل هذا السجل محل المرجع المغلق.

| الرمز | المطلب | الحزمة | دليل مرحلي | الحالة | معيار الإغلاق الأصلي |
|---|---|---|---|---|---|
| FIX-01 | تثبيت المصدر وخريطة الإصدارات | A01 | [A01](https://github.com/freshfriesw-droid/FreshFries-Web/pull/58) | PASS سابق موثق | مطابقة 53 ملفًا وبصماتها وإعادة بناء أرشيفي الأساس و#57 وسجل الفروق؛ لا يعني جاهزية الإطلاق |
| FIX-02 | إغلاق فشل اختبار كمية البرجر | A02 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | Chrome ناجح؛ إغلاق معيار السلة والتراجع ومطابقة قاعدة البيانات |
| FIX-03 | جرد التنقل الديناميكي والأزرار المخفية | A06 | [A06](https://github.com/freshfriesw-droid/FreshFries-Web/pull/90) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | خريطة FIX-03 جزئية؛ استكمال كل إجراء ودور وفرع |
| FIX-04 | التعامل مع 37 كتلة CSS والتعارضات | A06 | [A06](https://github.com/freshfriesw-droid/FreshFries-Web/pull/90) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | توحيد الدرج و7 كتل؛ باقي القواعد والمكونات واللقطات |
| FIX-05 | الإدخال السريع ومعاينة الطلب | A02 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبار النص الخام والمرادفات وجميع أمثلة الطلب والإضافة |
| FIX-06 | إنشاء الطلب والفرع والرسوم | A02 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبار رحلة طلب حقيقية لكل فرع ووسيلة إدخال |
| FIX-07 | تعديل بيانات العميل من الطلب | A02 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | SQL تصحيح بيانات العميل؛ اختبار المراحل والتنبيه والخصوصية |
| FIX-08 | إضافة صنف بعد إنشاء الطلب | A02 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبار الإضافات المعلقة والفاتورة والتسليم المتزامن |
| FIX-09 | الموصلون والتوزيع والمهل | A03 | [A03](https://github.com/freshfriesw-droid/FreshFries-Web/pull/87) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبار التناوب والإسناد والمهل 3/10 والانقطاع والبدائل |
| FIX-10 | إسناد الموصل الخاص إبراهيم الحداد | A03 | [A03](https://github.com/freshfriesw-droid/FreshFries-Web/pull/87) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | SQL سعة وتجاوز؛ تنافس جلستين متبقٍ |
| FIX-11 | دورة الكاشير والموصل | A03 | [A03](https://github.com/freshfriesw-droid/FreshFries-Web/pull/87) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | دورة كاملة وMicroPOS الاختياري والتعارضات |
| FIX-12 | نقطة التجميع لكل فرع | A04 | [A04](https://github.com/freshfriesw-droid/FreshFries-Web/pull/88) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبار الفروع الثلاثة والتشغيل الاختياري والتزامن |
| FIX-13 | مطبخ البرجر | A04 | [A04](https://github.com/freshfriesw-droid/FreshFries-Web/pull/88) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | SQL دورة الحالات؛ تحقق التشغيل اللحظي والأجهزة |
| FIX-14 | المستخدمون وطلبات الانضمام | A05 | [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اسم ثنائي والقبول/الرفض والتفعيل؛ PR2 غير مدمج |
| FIX-15 | الصلاحيات على الخادم وعزل الفروع | A05 | [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبارات RLS/RPC كاملة والأدوار والفرع |
| FIX-16 | تزامن الشاشات وحفظ تركيز الإدخال | A05 | [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبار جلسات مستقلة وعدم فقد التركيز والسلة |
| FIX-17 | الهوية والوسائط والاعتمادية | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبار Storage وشعار كل واجهة وانقطاع التحميل |
| FIX-18 | التقارير التشغيلية والفروقات المالية | A10 | [A10](https://github.com/freshfriesw-droid/FreshFries-Web/pull/95) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | مطابقة الأرقام وPDF والمشاركة والحدود المالية |
| FIX-19 | PWA والتنبيهات والحضور | A11 | [A11](https://github.com/freshfriesw-droid/FreshFries-Web/pull/96) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبار حضور واستراحة وعروض معلقة والخلفية وهاتفين |
| FIX-20 | التصفير الانتقائي في بيئة الاختبار | A12 | [A12](https://github.com/freshfriesw-droid/FreshFries-Web/pull/97) | PASS للنطاق الاصطناعي المحدد؛ لا يعمم على النسخ الكاملة | تجربة انتقائية مع استرجاع وإثبات حفظ الحسابات والسياسات |
| DEC-01 | مكتبة التصميم | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | 16 تخطيطًا؛ صفحتان لكل حزمة وأدوار وتباين |
| DEC-02 | اسم القسم المالية وحدوده | A10 | [A10](https://github.com/freshfriesw-droid/FreshFries-Web/pull/95) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | مطابقة وحدود مالية تشغيلية فقط |
| DEC-03 | التخصيص الشامل | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | محرر مستقل لكل شاشة/عنصر ومصدر الخاصية؛ خطة 09 |
| DEC-04 | دورة النشر | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | نطاقات وتجربة وانتشار واستعادة وحماية العناصر؛ خطة 12 |
| DEC-05 | القائمة الرئيسية الهجينة | A06 | [A06](https://github.com/freshfriesw-droid/FreshFries-Web/pull/90) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | تغطية كل مسار وتخصيص مركزي |
| DEC-06 | لوحة الرئيسية الديناميكية | A08 | [A08](https://github.com/freshfriesw-droid/FreshFries-Web/pull/92) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | بطاقات الأربع وإعادة وتراجع؛ مكتبة مؤشرات وإجراءات؛ خطة 10 |
| DEC-07 | تنقل الجوال خمسة أشكال | A06 | [A06](https://github.com/freshfriesw-droid/FreshFries-Web/pull/90) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | معاينة الأشكال؛ اختبار فعلي لكل شاشة ودور |
| DEC-08 | الموصل الخاص | A03 | [A03](https://github.com/freshfriesw-droid/FreshFries-Web/pull/87) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | تنافس وتوجيه جغرافي وسعة |
| DEC-09 | استوديو المحتوى | A09 | [A09](https://github.com/freshfriesw-droid/FreshFries-Web/pull/94) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | 53 مفتاحًا؛ باقي النصوص والمتغيرات والقوالب؛ خطة 11 |
| DEC-10 | التفويض المتدرج | A09 | [A09](https://github.com/freshfriesw-droid/FreshFries-Web/pull/94) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | تفويض النصوص؛ أنواع التصميم والتدقيق الموسع؛ خطة 12 |
| MSG-01 | الاستهداف بحسب الفئة | A11 | [A11](https://github.com/freshfriesw-droid/FreshFries-Web/pull/96) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | معاينة عدد المستلمين والاستهداف الشخصي ومنع خارج النطاق |
| MSG-02 | محتوى الرسالة والقوالب | A11 | [A11](https://github.com/freshfriesw-droid/FreshFries-Web/pull/96) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | قوالب الرسائل والأولوية والرابط الآمن ومعاينة الهاتف |
| MSG-03 | الإرسال اللحظي والتعويض عند عدم الاتصال | A11 | [A11](https://github.com/freshfriesw-droid/FreshFries-Web/pull/96) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اتصال/انقطاع وصندوق الوارد بعد العودة |
| MSG-04 | سجل وإحصاءات الرسائل | A11 | [A11](https://github.com/freshfriesw-droid/FreshFries-Web/pull/96) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | إرسال/تسليم/قراءة وأرشفة وإلغاء ومنع الإغراق |
| MSG-05 | تفويض الإرسال | A11 | [A11](https://github.com/freshfriesw-droid/FreshFries-Web/pull/96) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | تفويض الرسائل منفصلًا وتقييد الأولوية والفرع والفئة |
| UI-01 | تسجيل الدخول وبوابة الانضمام | A05 | [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبار الاسم الثنائي/الموافقة والتفعيل |
| UI-02 | الرئيسية حسب الدور | A08 | [A08](https://github.com/freshfriesw-droid/FreshFries-Web/pull/92) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبار كل دور والمؤشرات والتخصيص |
| UI-03 | خدمة العملاء | A02 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | دورة طلب حقيقية |
| UI-04 | واجهة الكاشير | A03 | [A03](https://github.com/freshfriesw-droid/FreshFries-Web/pull/87) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | تسليم وفاتورة وإضافات |
| UI-05 | واجهة الموصل | A03 | [A03](https://github.com/freshfriesw-droid/FreshFries-Web/pull/87) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | عروض ودوام ودورة التوصيل |
| UI-06 | نقطة تجميع الطلبات | A04 | [A04](https://github.com/freshfriesw-droid/FreshFries-Web/pull/88) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبار ثلاث فروع |
| UI-07 | مطبخ البرجر | A04 | [A04](https://github.com/freshfriesw-droid/FreshFries-Web/pull/88) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | دورة ومؤقت وتنبيه |
| UI-08 | واجهة العملاء | A02 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | إثبات ملكية الرقم والخصوصية |
| UI-09 | المنيو المصور والعروض | A02 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | إدخال وعروض وصور وأسعار |
| UI-10 | الحجوزات | A02 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | مسار الحجز وحالاته والصلاحيات |
| UI-11 | الشكاوى والتظلمات والتقييمات | A10 | [A10](https://github.com/freshfriesw-droid/FreshFries-Web/pull/95) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | مسارات الأدوار وتقييمات وتقارير |
| UI-12 | الموظفون والأدوار | A05 | [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | كل صلاحية وتفويض وفرع |
| UI-13 | مركز التقارير الإداري الموحد | A10 | [A10](https://github.com/freshfriesw-droid/FreshFries-Web/pull/95) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | مطابقة وتصدير |
| UI-14 | المالية — متابعة تشغيلية للرسوم والتسويات فقط | A10 | [A10](https://github.com/freshfriesw-droid/FreshFries-Web/pull/95) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | لا محاسبة؛ تحقق الأرقام |
| UI-15 | الفروع وأوقات العمل والأسعار | A05 | [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبار الإعدادات والتأريخ وعزل الفروع |
| UI-16 | الأمان والفحوصات والنسخ والتصفير | A12 | [A12](https://github.com/freshfriesw-droid/FreshFries-Web/pull/97) | PARTIAL — استرجاع اصطناعي ناجح؛ بيئة مستقلة/قبول نهائي مفتوح | استرجاع وفحص الأدوار |
| QA-01 | كل أزرار التنقل بلا وظائف يتيمة | A06 | [A06](https://github.com/freshfriesw-droid/FreshFries-Web/pull/90) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | جرد كامل لكل دور |
| QA-02 | نجاح CI كمية البرجر وبقية الواجهة الثابتة | A02 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84) | PASS لاختبار CI المحدد | معيار CI مجتاز؛ QA-26 وFIX-02 مستقلان ولا يغلقان به وحده |
| QA-03 | Create/edit/cancel/add item والمحلل والمعاينة | A02 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | دورة شاملة |
| QA-04 | المعاينة لا تنفذ فعلًا تشغيليًا | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | كل معاينات الرسائل والتصميم |
| QA-05 | حفظ الثيم بعد إعادة الفتح والتزامن | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | حسابان وأجهزة فعلية |
| QA-06 | خصائص كل واجهة مستقلة | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | محرر كل شاشة متبقٍ |
| QA-07 | أولوية الدور/الفرع/المستخدم/الجهاز | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | تخصيص عنصر ومستخدم وشاشة |
| QA-08 | إخفاء الواجهة لا يغير صلاحية الخادم | A05 | [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبار API لكل إجراء |
| QA-09 | تغيير نص/هوية زر لا يغير معرف الإجراء أو بياناته | A09 | [A09](https://github.com/freshfriesw-droid/FreshFries-Web/pull/94) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | كل المفاتيح والأيقونات |
| QA-10 | إرسال جماعي مرخص ومعاينة الجمهور | A11 | [A11](https://github.com/freshfriesw-droid/FreshFries-Web/pull/96) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبار مصرح/غير مصرح |
| QA-11 | عدم كشف بيانات العملاء حسب الدور | A05 | [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | بحث وتقارير وإشعار |
| QA-12 | التوزيع 3/10 دقائق والعداد وإعادة العرض | A03 | [A03](https://github.com/freshfriesw-droid/FreshFries-Web/pull/87) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | سيناريوهات كاملة |
| QA-13 | عدم الإسناد المزدوج | A03 | [A03](https://github.com/freshfriesw-droid/FreshFries-Web/pull/87) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | جلستان متزامنتان |
| QA-14 | الكاشير والتسليم والإضافات بلا تضارب | A03 | [A03](https://github.com/freshfriesw-droid/FreshFries-Web/pull/87) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | دورة متزامنة |
| QA-15 | التجميع لكل فرع مع مزامنة وتفويض | A04 | [A04](https://github.com/freshfriesw-droid/FreshFries-Web/pull/88) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | ثلاثة فروع |
| QA-16 | مطبخ البرجر الحالات والتنبيه والعداد | A04 | [A04](https://github.com/freshfriesw-droid/FreshFries-Web/pull/88) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبار حي |
| QA-17 | تمييز رسوم التوصيل والأصناف والتحصيل | A10 | [A10](https://github.com/freshfriesw-droid/FreshFries-Web/pull/95) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | مطابقة السجلات |
| QA-18 | عدم وجود صندوق أو مخزون أو أرباح أو POS | A10 | [A10](https://github.com/freshfriesw-droid/FreshFries-Web/pull/95) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | جرد جميع الواجهات |
| QA-19 | النسخ والتصفير الانتقائي والاسترجاع | A12 | [A12](https://github.com/freshfriesw-droid/FreshFries-Web/pull/97) | PASS للنطاق الاصطناعي المحدد؛ لا يعمم على النسخ الكاملة | تجربة استرجاع |
| QA-20 | PWA وPush والبديل والانقطاع والحضور | A11 | [A11](https://github.com/freshfriesw-droid/FreshFries-Web/pull/96) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | أجهزة فعلية |
| QA-21 | أحجام 320/360/390/430/768/1024/1440 | A06 | [A06](https://github.com/freshfriesw-droid/FreshFries-Web/pull/90) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | كل دور وشاشة |
| QA-22 | التصميمات والتباين والكثافة | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | كل تصميم ودور |
| QA-23 | لوحة المفاتيح والتركيز والتسميات والتحذيرات | A06 | [A06](https://github.com/freshfriesw-droid/FreshFries-Web/pull/90) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | جميع النماذج |
| QA-24 | استعادة الشعار والتصميم بلا تلف | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | شعار وأمر أثناء التجربة |
| QA-25 | لا أسرار أو صلاحيات إدارية للمتصفح وRLS صحيح | A05 | [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | فحص أمني شامل |
| QA-26 | البرجر 3→2→1 والرجوع 2→3 والملاحظات والسعر | A02 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | ثلاثة أجهزة وتطابق قاعدة البيانات |
| QA-27 | فهرس جميع مسارات التنقل القديمة والجديدة | A06 | [A06](https://github.com/freshfriesw-droid/FreshFries-Web/pull/90) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | جرد خاص بالشاشات والأدوار |
| QA-28 | سقف إبراهيم 5 وتجاوز موثق وتغيير للمدير | A03 | [A03](https://github.com/freshfriesw-droid/FreshFries-Web/pull/87) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | تزامن وعزل الفروع |
| QA-29 | نشر تجريبي ونشر الآن وانتشار واستعادة | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | حسابان مستقلان |
| QA-30 | رفض إخفاء تحذير حساس أو إجراء إلزامي بلا بديل | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | محرك حماية جميع العناصر |
| QA-31 | تغيير تصميم أثناء الإدخال لا يفقد التركيز والسلة والنص | A05 | [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | جلستان مستقلتان |
| QA-32 | أنماط الجوال الخمسة على 320/360/390/430 | A06 | [A06](https://github.com/freshfriesw-droid/FreshFries-Web/pull/90) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | تشغيل كل دور دون حجب الحفظ |
| QA-33 | رسائل متصل وغير متصل وتقارير قراءة | A11 | [A11](https://github.com/freshfriesw-droid/FreshFries-Web/pull/96) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبار متصل/غير متصل |
| QA-34 | 16 تصميمًا وصفحتان لكل نمط واتساق زر الخطر | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | الصفحة الثانية لكل نمط |
| QA-35 | لا نشر أو استعادة للموظف المفوض حتى API | A09 | [A09](https://github.com/freshfriesw-droid/FreshFries-Web/pull/94) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | أنواع التصميم كافة |
| QA-36 | انتهاء/سحب التفويض فورًا والتدقيق | A09 | [A09](https://github.com/freshfriesw-droid/FreshFries-Web/pull/94) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | نطاق النصوص مختبر؛ التصميم متبقٍ |
| QA-37 | KPI 4 حقيقية والزيادة والنقص والترتيب والاستعادة | A08 | [A08](https://github.com/freshfriesw-droid/FreshFries-Web/pull/92) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | نشر ومشاهدة عبر حسابات |
| QA-38 | تعديل شاشة وتعليمات ومتغير آمن والأصل | A09 | [A09](https://github.com/freshfriesw-droid/FreshFries-Web/pull/94) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | تغطية كل أنواع المحتوى |
| QA-39 | Accordion/Flat يحافظ على المجموعة والمسار | A06 | [A06](https://github.com/freshfriesw-droid/FreshFries-Web/pull/90) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | تبديل الثيم والأدوار |
| QA-40 | أعداد التقرير والوقت المحلي والفرع والدور وPDF | A10 | [A10](https://github.com/freshfriesw-droid/FreshFries-Web/pull/95) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | مطابقة بيانات PDF |
| QA-41 | أمن المتغيرات ضد HTML/JS والروابط والتصدير | A09 | [A09](https://github.com/freshfriesw-droid/FreshFries-Web/pull/94) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | بقية المتغيرات والتصدير |
| QA-42 | تصفير بيانات اختبار فقط دون إسقاط المستخدمين والسياسات | A12 | [A12](https://github.com/freshfriesw-droid/FreshFries-Web/pull/97) | PASS للنطاق الاصطناعي المحدد؛ لا يعمم على النسخ الكاملة | تنفيذ واسترجاع |
| QA-43 | قبول الاسم الثنائي وعدم الدخول قبل الموافقة | A05 | [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبار مستقل؛ PR2 مفتوح |
| QA-44 | الفروع الثلاثة والتجميع المعزول والخدمة بحسب التفويض | A04 | [A04](https://github.com/freshfriesw-droid/FreshFries-Web/pull/88) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | حسابات الفروع والتفويض |
| QA-45 | المالية التشغيلية فقط دون صندوق أو مخزون أو رواتب أو قيد | A10 | [A10](https://github.com/freshfriesw-droid/FreshFries-Web/pull/95) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | جرد الشاشات |
| T-01 | العملاء/المحلل/المعاينة/المرادفات | A02 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-02 | المنيو المصور والعروض والمرادفات والأسعار | A02 / A05 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84)، [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-03 | التوزيع الدوري ومهلة 3/10 والعداد | A03 | [A03](https://github.com/freshfriesw-droid/FreshFries-Web/pull/87) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-04 | الموصل الخاص والتوجيه الجغرافي | A03 | [A03](https://github.com/freshfriesw-droid/FreshFries-Web/pull/87) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-05 | دورة الكاشير والموصل وMicroPOS الاختياري | A03 | [A03](https://github.com/freshfriesw-droid/FreshFries-Web/pull/87) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-06 | نقطة التجميع المستقلة لكل فرع | A04 | [A04](https://github.com/freshfriesw-droid/FreshFries-Web/pull/88) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-07 | مطبخ البرجر وحالاته | A04 | [A04](https://github.com/freshfriesw-droid/FreshFries-Web/pull/88) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-08 | العميل وتعديل البيانات والمكالمات المباشرة | A02 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-09 | الانضمام والعمل بالموافقة والصلاحيات | A05 | [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-10 | إدارة الفروع وأوقات العمل والمنيو | A05 | [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-11 | التقييمات والشكاوى والتظلمات | A10 | [A10](https://github.com/freshfriesw-droid/FreshFries-Web/pull/95) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-12 | مركز التقارير الموحد وPDF/مشاركة | A10 | [A10](https://github.com/freshfriesw-droid/FreshFries-Web/pull/95) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-13 | نطاق مالي تشغيلي فقط | A10 | [A10](https://github.com/freshfriesw-droid/FreshFries-Web/pull/95) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-14 | التصفير الانتقائي ونسخ التجارب | A12 | [A12](https://github.com/freshfriesw-droid/FreshFries-Web/pull/97) | PASS للنطاق الاصطناعي المحدد؛ لا يعمم على النسخ الكاملة | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-15 | PWA/Push والأصوات والحضور | A11 | [A11](https://github.com/freshfriesw-droid/FreshFries-Web/pull/96) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-16 | تصميمات متعددة وثيمات وعربية وRTL | A06 / A07 | [A06](https://github.com/freshfriesw-droid/FreshFries-Web/pull/90)، [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-17 | تحكم المدير الكامل بالمظهر والنصوص | A07 / A09 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91)، [A09](https://github.com/freshfriesw-droid/FreshFries-Web/pull/94) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-18 | رسائل جماعية حسب الفئة | A11 / A05 | [A11](https://github.com/freshfriesw-droid/FreshFries-Web/pull/96)، [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-19 | إصلاح CSS والأزرار والقوائم | A06 | [A06](https://github.com/freshfriesw-droid/FreshFries-Web/pull/90) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| T-20 | الحالة ما زالت تطويرًا فقط | A01 | [A01](https://github.com/freshfriesw-droid/FreshFries-Web/pull/58) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-21 | قائمة المدير و16 تصميمًا | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-22 | المالية اسمًا وحدودًا | A10 | [A10](https://github.com/freshfriesw-droid/FreshFries-Web/pull/95) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-23 | تخصيص الدور والشاشة والفرع والجهاز | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-24 | مسودة ومعاينة وتجربة ونشر واستعادة | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-25 | Accordion وFlat | A06 | [A06](https://github.com/freshfriesw-droid/FreshFries-Web/pull/90) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-26 | لوحة ديناميكية KPI 4 | A08 | [A08](https://github.com/freshfriesw-droid/FreshFries-Web/pull/92) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-27 | الشريط السفلي 5 أشكال | A06 | [A06](https://github.com/freshfriesw-droid/FreshFries-Web/pull/90) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-28 | إبراهيم الحداد بسقف 5 قابل للتعديل | A03 | [A03](https://github.com/freshfriesw-droid/FreshFries-Web/pull/87) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-29 | النصوص والمسميات وقوالب الرسائل | A09 | [A09](https://github.com/freshfriesw-droid/FreshFries-Web/pull/94) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-30 | التفويض المتدرج والنشر الحصري | A09 | [A09](https://github.com/freshfriesw-droid/FreshFries-Web/pull/94) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-31 | رسائل جماعية للموصلين والكاشير والخدمة | A11 | [A11](https://github.com/freshfriesw-droid/FreshFries-Web/pull/96) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-32 | أوقات الدوام والحضور منفصل عن الاتصال | A03 / A11 | [A03](https://github.com/freshfriesw-droid/FreshFries-Web/pull/87)، [A11](https://github.com/freshfriesw-droid/FreshFries-Web/pull/96) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-33 | المعلومات التاريخية للرسوم ومناطق التوصيل | A02 / A05 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84)، [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-34 | إضافة الأصناف بعد الإنشاء بنفس المحلل | A02 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-35 | التقييمات المتبادلة غير الإجبارية | A10 | [A10](https://github.com/freshfriesw-droid/FreshFries-Web/pull/95) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-36 | بوابة العميل آمنة بتحقق ملكية الرقم | A02 / A05 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84)، [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-37 | MicroPOS اختياري وحالة توثيق | A03 / A10 | [A03](https://github.com/freshfriesw-droid/FreshFries-Web/pull/87)، [A10](https://github.com/freshfriesw-droid/FreshFries-Web/pull/95) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-38 | الشعار والصور والأصوات بخزن مركزي | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-39 | مركز التقارير الموحد PDF ومشاركة | A10 | [A10](https://github.com/freshfriesw-droid/FreshFries-Web/pull/95) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-40 | نقطة تجميع مستقلة اختيارية لكل فرع | A04 | [A04](https://github.com/freshfriesw-droid/FreshFries-Web/pull/88) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-41 | أدوار وصلاحيات فردية مع سحب فوري | A05 | [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-42 | عرض رقم الموصل الجاري ومؤقت العرض | A03 | [A03](https://github.com/freshfriesw-droid/FreshFries-Web/pull/87) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-43 | سرعة إنشاء الطلب ومنع التكرار | A02 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-44 | طلبات الانضمام بالاسم الثنائي | A05 | [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| TR-45 | بيئة تجريبية وبيانات تجريبية | A12 | [A12](https://github.com/freshfriesw-droid/FreshFries-Web/pull/97) | PARTIAL — استرجاع اصطناعي ناجح؛ بيئة مستقلة/قبول نهائي مفتوح | يرث شروط القبول من البنود المرتبطة؛ لا يعد مقبولًا بمجرد وجود الوظيفة. |
| P0 | الأساس والتحقق | A01 | [A01](https://github.com/freshfriesw-droid/FreshFries-Web/pull/58) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | جرد أساس وفروق واختبار إعادة البناء؛ جرد كل إجراء وصلاحية وتباين مفتوح |
| P1 | إصلاحات التشغيل | A02–A05 | [A02](https://github.com/freshfriesw-droid/FreshFries-Web/pull/84)، [A05](https://github.com/freshfriesw-droid/FreshFries-Web/pull/89) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | اختبارات عمليات مستقلة |
| P2 | بنية نظام التصميم | A06 | [A06](https://github.com/freshfriesw-droid/FreshFries-Web/pull/90) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | Tokens ومكتبة مكونات |
| P3 | النماذج المتعددة | A07 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | 16 تصميمًا على صفحتين |
| P4 | التنقل والشاشات | A06 | [A06](https://github.com/freshfriesw-droid/FreshFries-Web/pull/90) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | كل المسارات |
| P5 | شاشة المدير العام | A07–A09 | [A07](https://github.com/freshfriesw-droid/FreshFries-Web/pull/91)، [A09](https://github.com/freshfriesw-droid/FreshFries-Web/pull/94) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | محرر شامل وتفويض ونشر |
| P6 | مركز التقارير والجودة | A10–A11 | [A10](https://github.com/freshfriesw-droid/FreshFries-Web/pull/95)، [A11](https://github.com/freshfriesw-droid/FreshFries-Web/pull/96) | دليل مرحلي؛ القبول الفردي النهائي مفتوح | مطابقة وتقارير وأجهزة |
| P7 | اختبار الجاهزية | A12 | [A12](https://github.com/freshfriesw-droid/FreshFries-Web/pull/97) | PARTIAL — استرجاع اصطناعي ناجح؛ بيئة مستقلة/قبول نهائي مفتوح | بوابة نهائية مستقلة |
