# STEP08 — الإغلاق التقني للنشر والإصدارات والاستعادة — 25 نوفمبر 2026

**الحالة: PASS / CLOSED ضمن نطاق STEP08. لا إطلاق تشغيلي رسمي ولا تصفير.**
المراجع: وثيقة الاعتماد النهائي 24 نوفمبر §6.8 ص26–27، DEC-04، QA-24، QA-29، TR-24، والجزء ذي الصلة من P5 وQA-30؛ خطة الاستكمال 25 نوفمبر الخطوة 08؛ أمر التنفيذ الملزم.
SHA256 للاعتماد: 18820bbd27e2939f21c617d5d34aafeccd491e4346c1f6f0b4a2d96288a6fc62؛ للخطة: ab64f4ef554e93f06d9c6aa7200c6ef74af4ec78842931f0e39613432906557a.

## التنفيذ والإصلاح
- نقطة البدء STEP07 المغلقة، main `5097a6b8a68ca95f3608768312a0b4c856e205ec`. إعادة استخدام محرري التصميم والمحتوى ومخازن الإصدارات القائمة. لا نظام بديل.
- تقرير تأثير من الخادم قبل التجربة والنشر: صلاحية المسودة، نطاقها، الإصدار السابق، الحسابات المؤهلة وعددها. الحساب المؤهل ليس ضمانًا لتجاوز طبقة منشورة أكثر تخصيصًا. معاينة ومقارنة الإصدارات محفوظتان، والتجربة الإدارية والنشر والاستعادة للمدير فقط.
- تجربة تصميم محددة بالحساب والدور والفرع والشاشة والجهاز؛ تجربة النص ضمن نطاق المحتوى القائم بالحساب والدور والفرع ومفتاح الشاشة، عبر جميع الأجهزة؛ 1/8/24 ساعة، إيقاف، منع التجربة الحسابية للواجهات العامة غير المسجلة. النشر العام للواجهات العامة يبقى وفق آلية الإدارة القائمة.
- قفل نشر ذري وإعادة التحقق من الإصدار السابق؛ إيقاف التجارب القديمة عند نشر أحدث، وعزل النطاقات. استعادة النص السابق بدقة واستعمال آلية استعادة التصميم والبطاقات القائمة مع حماية الهوية والخصائص. إعادة القراءة الدورية للواجهة 3 ثوانٍ وإعادة القراءة عند تغير السياق؛ تأكيد النشر من سجل الخادم. سجلات موثوقة للمنفذ والمستهدفين والتجربة والنشر والاستعادة، مع منع تزوير سجل دورة الإصدار من العميل.
- إصلاح استعلام حسابات التجربة بربطه بمعرف المسودة؛ حماية الخصائص والإجراءات والمؤشرات المسجلة والعناصر الإلزامية؛ حظر النص غير الآمن. إصلاح التجاوز الأفقي في محرر المدير عند 320 عبر حاوية تمرير داخلية وحدود معاينة وقواعد استجابة، مع حفظ الحشو المعتمد وإتاحة الأزرار. إصلاح محاكي mobile-layout.py ليتحقق صراحةً من استدعاء تقرير التأثير قبل النشر؛ ليس تعطيلًا لاختبار.
- الملفات: index.html، scripts/luxe-dashboard-studio.js، scripts/luxe-content-studio.js، styles/luxe-dashboard-studio.css، scripts/a07-design-qa.py، scripts/step06-content-qa.py، scripts/a09-denial-http-qa.py، scripts/p2-component-qa.py، scripts/mobile-layout.py، supabase/migrations/20261125_step08_release_lifecycle.sql، supabase/tests/step08_release_lifecycle_rollback.sql.

## قاعدة البيانات والاختبارات الحقيقية
- ترحيل Supabase الدائم `step08_release_lifecycle` بالإصدار `20261125185146`. إضافة جدول تجربة النصوص الخاص وRLS وإلغاء الوصول المباشر، RPCs محمية، سياسات تمنع تزوير تدقيق دورة الإصدار. سبعة ملفات اختبار SQL نجحت قبل الترحيل وبعده: STEP08، A07 scoped design، dashboard design releases، STEP03، STEP06، STEP07، A09 manager denial. التحقق من دور وفرع وجهاز وحسابين مختلفين، تجربة وإيقافها وإصدار أحدث واستعادة، رفض الإجراء والمؤشر غير المسجلين والعنصر المحمي والنص غير الآمن، سلامة التدقيق وACL. المتصفح يعمل ببيانات ومحاكاة RPC؛ SQL منفصل على Supabase الفعلي.
- تجربة تنافس مستقلة عبر Supabase الفعلية بحسابات وفروع QA مؤقتة: نشر تصميم واحد ونص واحد، رفض التجربتين القديمتين، صفر تجارب وحدثا نشر؛ مراقب الأقفال المباشر لم يرصد صفوف انتظار، لذلك لا يدعى إثبات تداخل الأقفال على البيئة الفعلية. الاختبار المعزول PostgreSQL/PostgREST [HTTP](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45682268958) أثبت رصد قفلين منتظرين ورفض التجربتين بعد النشر الذري وصفر كتابة تجارب؛ تحقق رفض المدير غير المخول وتدقيق الرفض. حُذفت بيانات QA فقط بعد الاختبار.
- قراءة تحقق نهائية: 3 فروع نشطة و1 فرع غير نشط محفوظ؛ صفر حسابات أو فروع STEP08 QA، صفر سجلات تجارب نصية، صفر جداول public بلا RLS. لا تصفير أو تعديل بيانات تشغيلية. تحذيرات المستشار الأمنية العامة (بما فيها SECURITY DEFINER المقصود وRLS دون سياسة للجدول الخاص) تبقى ضمن تدقيق STEP12؛ صلاحيات RPC محددة وتحققت بالاختبار.
- رأس الإصدار النهائي `56448fefe21e392c9b616987a3041691d4861504`: 16/16 مجموعات CI ناجحة على الرأس نفسه:
  - [STEP05 media resilience QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45682269020) — PASS
  - [LUXE A09 content and delegation QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45682268923) — PASS
  - [LUXE A10 reports and quality QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45682268992) — PASS
  - [LUXE A07 scoped designs QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45682268882) — PASS
  - [LUXE A06 navigation QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45682268753) — PASS
  - [LUXE A04 operational browser QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45682269078) — PASS
  - [LUXE A02 customer UI QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45682268905) — PASS
  - [LUXE A09 denial HTTP QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45682268958) — PASS
  - [LUXE A08 dashboard QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45682269243) — PASS
  - [STEP06 content registry QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45682268872) — PASS
  - [LUXE A05 browser QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45682269010) — PASS
  - [A12 Selective Recovery QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45682268691) — PASS
  - [A11 Communications QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45682268963) — PASS
  - [LUXE FIX-08 addition workflow QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45682268724) — PASS
  - [LUXE P2 component cascade QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45682268696) — PASS
  - [Fresh Fries LUXE static QA](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45682269072) — PASS
- A07: 329 حالة دور/عرض/حزمة، دورة STEP08 كاملة و7 عروض (320–1440)، اختبار الأزرار واحتواء عرض المحرر. STEP06: تقرير التأثير والتجربة والإيقاف ورفض المسودة القديمة والمقارنة واسترجاع النص حرفيًا. P2: 147 مقارنة مرجعية و147 مقارنة للتطبيق؛ تطابق RGB صارم. إخفاقات سابقة: تجاوز عرض المحرر، تغير الحشو، فرق raster بمستوى قناة واحد، محاكي قديم لا يدعم تقرير التأثير. أصلحت أسباب العرض والمحاكي، أعدت فحص الصور دون خفض معيار المطابقة، ونجح الفحص على الرأس النهائي. لا اعتبار لاختبار سابق فاشل دليلًا للقبول.

## الدمج والنشر
- [PR #128](https://github.com/freshfriesw-droid/FreshFries-Web/pull/128) مدمج في main: `82ed53ed7a6127ed5818da902700dae6837c99b4`. شجرة Git للرأس المختبر والدمج متطابقة `e2e502ec240eb2fd323e0fd6f883633fdc188a77`.
- [GitHub Pages](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45683256401) PASS. Cloudflare Workers build للإصدار المدمج PASS. الفحص الأول/الثاني سبقا اكتمال تحديث Cloudflare فرفضا CSS القديم، ثم أعيدت المهمة بعد نجاح البناء.
- [النطاق الرسمي freshfriesz.com](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45683256808/job/139450429347) PASS و[النطاق الفرعي](https://github.com/freshfriesw-droid/FreshFries-Web/actions/runs/45683256881/job/139450447358) PASS. تطابق root وindex.html بعد استبعاد beacon Cloudflare المعروف فقط، و10 CSS و29 JS؛ SHA256 HTML `9c688c8f2fd897fdfebcdd9f6b507540dde731b1bba0061f7916b11dab892d65`. التحقق HTTPS عبر runner لأن الاتصال المباشر من بيئة المحادثة غير متاح. الفحص العام المتكرر بعد الدمج كان جاريًا عند تثبيت الدليل؛ شجرة الدمج نفسها اجتازت 16/16 قبل الدمج.
- لم يجر إطلاق تشغيل رسمي؛ الاختبار الميداني STEP14. لا إغلاق شامل لـP5/QA-30 العابرين لنطاق الخطوة الحالية، ولا نقل إلى الخطوة 09 قبل هذا الإغلاق.

## نقطة الاستئناف التالية
STEP09 — المراجعة التشغيلية الشاملة، وفق خطة 25 نوفمبر. لم يبدأ تنفيذها في هذا الإغلاق. 8/15 خطوات مغلقة تقنيًا (53.3%). يتعين مراجعة هذا السجل ومصفوفة المتطلبات والنسخة الفعلية قبل البدء.