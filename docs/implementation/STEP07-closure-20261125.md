# STEP07 — الإغلاق التقني للتفويض المتدرج — 25 نوفمبر 2026

**الحالة: PASS / CLOSED ضمن STEP07 فقط. لا إطلاق تشغيلي رسمي ولا تصفير.**
المراجع: وثيقة الاعتماد المغلقة 24 نوفمبر §6.6 (ص25–26)، DEC-10، QA-35/36، TR-30؛ خطة الاستكمال 25 نوفمبر خطوة 07؛ أمر التنفيذ الملزم.
SHA256 للاعتماد: 18820bbd27e2939f21c617d5d34aafeccd491e4346c1f6f0b4a2d96288a6fc62؛ للخطة: ab64f4ef554e93f06d9c6aa7200c6ef74af4ec78842931f0e39613432906557a.

## التنفيذ
- نقطة الانطلاق STEP06 مغلقة، main `acb303b2ae2de26db043adc782df531def1cfba1`. إعادة استخدام A09 والنطاق المرتبط بالحساب والدور والفرع والشاشة ونوع التعديل ومدة المنح. لا إعادة بناء أو توسيع صلاحيات تشغيلية.
- أنواع المنح: النصوص، الألوان والحدود، الأزرار والأيقونات، التخطيط والكثافة، حزم التصميم D01–D16، الخطوط، الهوية وموضع الشعار، اختيار صور الشعار المعتمدة، بطاقات الرئيسية؛ خصائص العناصر الآمنة وتخصيص اختصارات الرئيسية. الصلاحيات الأربع: المشاهدة والتحرير والمعاينة والمراجعة. النشر والاستعادة والتجربة الإدارية وإدارة المنح حصرية للمدير. المنح الفردية لا تشمل النطاق العام للشاشات العامة؛ أصول الوسائط المفوضة هي خيارات الشعار المعتمدة، لا إدارة صور المنيو أو النغمات أو الأسعار أو موارد التشغيل أو الرسائل الجماعية (صلاحيات مستقلة وفق §6.6).
- حفظ مسودات فقط، مقارنة المظهر والمصادر، رفض الخصائص غير المسجلة وHTML/CSS الخام والتجاوز خارج النوع. رفض المسودة القديمة/الغريبة أو التابعة لمنحة سابقة. لا تعديل للأصل التشغيلي أو بيانات المؤشرات أو الصلاحيات. توسيع التدقيق ليشمل أثر كتابة ومراجعة النص والتصميم ومعرف الإصدار المطلوب، بما في ذلك محاولات الرفض.
- إصلاحات الاستئناف: وراثة البطاقات من a08_card_source، دمج dashboardPanels الجزئي بدل محو إعدادات الأقسام الأخرى، حفظ تسميات البطاقات والاختصارات عند تحريرها؛ تحديث مراجع إصدار الأصلين. فاحص P2 يقبل تحديدًا تغيير مراجع إصدار الأصلين فقط ويقارن كل ما عداه؛ لم يخفف معيار الصورة. فاحص نشر A09 يقرأ مرجع الإصدار من HTML المدمج بدل تثبيت رقم إصدار قديم.
- ملفات التطبيق: scripts/luxe-content-delegation.js، scripts/luxe-a07-elements.js، index.html. الترحيل: supabase/migrations/20261125_step07_delegation_scope.sql. الاختبار: supabase/tests/step07_delegation_rollback.sql؛ scripts/a09-content-qa.py؛ scripts/a09-denial-http-qa.py؛ scripts/p2-component-qa.py؛ CI A09.

## الاختبارات الفعلية
- رأس التطبيق `a9b9d457201da60fa87e1de3c5cea2392899fc39` اجتاز 16/16 مجموعات CI؛ كل النتائج على نفس الرأس:
  - [STEP06 content registry QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417665) — PASS
  - [LUXE A04 operational browser QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417677) — PASS
  - [LUXE P2 component cascade QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417694) — PASS
  - [A11 Communications QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417618) — PASS
  - [LUXE FIX-08 addition workflow QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417592) — PASS
  - [LUXE A05 browser QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417631) — PASS
  - [LUXE A02 customer UI QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417564) — PASS
  - [STEP05 media resilience QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417579) — PASS
  - [Fresh Fries LUXE static QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417635) — PASS
  - [LUXE A09 denial HTTP QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417192) — PASS
  - [LUXE A09 content and delegation QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417622) — PASS
  - [LUXE A08 dashboard QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417158) — PASS
  - [A12 Selective Recovery QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417288) — PASS
  - [LUXE A06 navigation QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417614) — PASS
  - [LUXE A10 reports and quality QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417506) — PASS
  - [LUXE A07 scoped designs QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417626) — PASS
- [A09 Browser](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417622)، [job](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417622/job/139425052945): واجهة المدير، المنح المتدرجة، حفظ/مراجعة مسودة التصميم، أنواع الحزمة والخط والهوية والوسائط والأزرار والتخطيط والبطاقات، منع الواجهة الإدارية، سحب التفويض وتنظيف الحوار، 7 مقاسات (320–1440)، وعدم تبديل عناصر التشغيل. المتصفح يستخدم RPC اختبارية؛ التكامل الخلفي مثبت بفحوص SQL وHTTP منفصلة.
- [A09 HTTP](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417192)، [job](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417192/job/139425050182): 12 محاولة API مباشرة رُفضت بـ403 مع تدقيق محفوظ ودون أثر؛ نشر المدير بقي يعمل. PostgreSQL/PostgREST مستقلان لا بيانات تشغيلية: تنافس سحب المنحة وطلب تحرير HTTP على قفل فعلي (رُصد انتظار SHARE lock)، ثم رفض التحرير بعد السحب؛ انتهاء المنحة أثناء الانتظار أعيد التحقق منه بعد القفل ورفض الطلب وسُجل التدقيق. لا ادعاء اختبار تزامن ميداني بجهازين.
- [P2](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417694)، [job](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417694/job/139425052261): 147 مقارنة تاريخية و147 للتطبيق الحالي (7 أدوار ×7 مقاسات ×3 ثيمات)، تطابق الصور/الخصائص/التركيز/الرؤية. إخفاقات سابقة: فرق رسم 62 بكسل بقيمة قناة 1 في المرجع التاريخي؛ وفاحص مرجع إصدار قديم رفض المصدر. صُحح المرجع المحدد وأُعيد الاختبار بمعيار تطابق RGB صارم؛ PASS للرأس النهائي.
- [Static](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45676417635) — PASS، P0 role binding، FIX-02 منتقي البرجر، حفظ مسودة A02 والسلة والملاحظات، RTL الهاتف والكمبيوتر. A02/A04/A05/A06/A07/A08/A10/A11/A12/Media/FIX08/STEP06 ناجحة ضمن مجموعات 16/16.

## Supabase الفعلية
- الترحيل الدائم `step07_delegation_scope` مسجل 20261125183510. اختبار rollback قبل وبعد الترحيل PASS: ثمانية أنواع تصميم، 18 تحققًا إضافيًا (وراثة البطاقات، حفظ إعدادات الأقسام، خصائص عناصر، عزل النوع والفرع والحساب، منحة مجدولة/تعطيل حساب، محاولات النص والتدقيق)، 20 تحقق A09 سابق، 25 تحقق تدقيق الرفض/الحصرية، اختبار grant-window. جميع الاختبارات ببيانات اصطناعية تراجعية. اختبار مباشر لنشر/استعادة/تجربة وإدارة غير المدير؛ منع النشر المباشر للمفوض. لا حذف أو تصفير للبيانات الأصلية.
- بعد التراجع: 3 فروع نشطة، 0 منح، 0 حسابات QA-STEP07؛ 102/102 RLS. تسع RPCs الخاصة بالتفويض والتصميم غير قابلة لتنفيذ anon، متاحة للمصادق عليه بالتحقق الداخلي وsearch_path فارغ. خمسة جداول التفويض والتدقيق والمراجعة وإصدارات التصميم والنص مغلقة عن القراءة/الإدراج/التحديث/الحذف المباشر للمصادق عليه، وعن القراءة العامة. لا صلاحيات جديدة على بيانات التشغيل.
- Security advisors: تنبيهات RLS دون سياسة على الجداول المغلقة عمدًا، وSECURITY DEFINER RPC للمصادق عليه مقصودة وتحقق داخليًا من الهوية والنطاق؛ لا توسيع وصول عام. التدقيق العام للقاعدة والتنبيهات الأخرى ضمن STEP12؛ لا شهادة أمان/إطلاق نهائية.

## الدمج والنشر
- [PR #127](https://github.com/freshfriesw-droid/FreshFries-Web/pull/127) مدمج `8e3fa2562680c39f635a2468bed5b601d3ac7aae`؛ شجرة الدمج مطابقة حرفيًا لشجرة الرأس المختبر `2996962818439338201516cb00f54db76b81a1a3`.
- [Pages](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45677627156) PASS. المحاولة الأولى لفاحصي النشر وجدت ملف العناصر القديم قبل اكتمال Pages؛ أُعيدت بعد نجاح النشر دون تغيير التطبيق/معيار المطابقة.
- [مطابقة النطاق الرسمي](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45677628356)، [job](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45677628356/job/139429954475) PASS المحاولة 2، 18:42:17 UTC: HTTPS freshfriesz.com؛ HTML الجذر وindex مطابق بعد إزالة beacon Cloudflare المحدد فقط (واحد لكل استجابة)، 10 CSS و29 JS مطابقة حرفيًا، الروابط العادية وذات الإصدار مطابقة. SHA256 HTML `8c3b4cd27e88e35767eb85395a41bea68beae030476f89c946049c423c14256d`.
- [P2 النطاق الفرعي](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45677628470) PASS المحاولة 2؛ [A09 asset النطاق الفرعي](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45677628494) PASS، SHA256 ملف التفويض `2c61156bb7d1bfb27bacca8fcb947d30a54b1f29cff7ee7d74966c4c3fb6faa8`. تحقق النطاق من CI لأن DNS من بيئة المحادثة غير متاح؛ لا تغيير DNS/Cloudflare. الفحص static بعد الدمج [45677628495](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45677628495) كان جاريًا عند التوثيق؛ رأس التطبيق المطابق اجتاز static قبل الدمج. A11/A12 بعد الدمج ناجحان.
- لا تغيير على التطبيق في توثيق الإغلاق. تحديث 4 صفوف مصفوفة 149 مطلبًا: DEC-10 وQA-35 وQA-36 وTR-30.

**نقطة الاستئناف التالية: STEP08 — النشر والإصدارات والاستعادة.** لا بدء تنفيذها هنا. الاختبارات الميدانية على الأجهزة والحسابات الفعلية STEP14 والإطلاق النهائي مشروط بأمر المالك.
