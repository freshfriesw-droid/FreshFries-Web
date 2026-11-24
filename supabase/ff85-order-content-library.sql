-- DEC-09 §6.5: fixed field labels, input hints and screen headings. No action/validation changes.
insert into public.ff_content_catalog(key,screen,label,original) values
 ('orders.field.branch','orders','حقل: الفرع','الفرع'),
 ('orders.field.phone','orders','حقل: هاتف العميل','هاتف العميل'),
 ('orders.field.area','orders','حقل: المنطقة','المنطقة'),
 ('orders.field.fee','orders','حقل: رسوم التوصيل','رسوم التوصيل'),
 ('orders.field.notes','orders','حقل: ملاحظات الطلب','ملاحظات الطلب'),
 ('orders.field.customer','orders','حقل: اسم العميل (اختياري)','اسم العميل (اختياري)'),
 ('orders.field.channel','orders','حقل: مصدر الطلب','مصدر الطلب'),
 ('orders.field.address','orders','حقل: العنوان التفصيلي (اختياري)','العنوان التفصيلي (اختياري)'),
 ('orders.field.items','orders','حقل: الأصناف النهائية (يمكن تعديلها يدويًا)','الأصناف النهائية (يمكن تعديلها يدويًا)'),
 ('orders.field.quick','orders','حقل: ألصق بيانات الطلب هنا ثم عاينها قبل الاعتماد','ألصق بيانات الطلب هنا ثم عاينها قبل الاعتماد'),
 ('orders.hint.phone','orders','تلميح: 77xxxxxxx','77xxxxxxx'),
 ('orders.hint.area','orders','تلميح: اسم المنطقة بالتحديد','اسم المنطقة بالتحديد'),
 ('orders.hint.fee','orders','تلميح: اكتب الأجرة أو 0 للمجاني','اكتب الأجرة أو 0 للمجاني'),
 ('orders.hint.notes','orders','تلميح: ملاحظة العميل','ملاحظة العميل'),
 ('orders.hint.menu','orders','تلميح: 🔎 ابحث عن صنف أو عرض','🔎 ابحث عن صنف أو عرض'),
 ('orders.hint.search','orders','تلميح: ابحث في الطلبات الظاهرة','ابحث في الطلبات الظاهرة'),
 ('orders.title','orders','عنوان: 🍟 طلب جديد — خدمة العملاء','🍟 طلب جديد — خدمة العملاء'),
 ('orders.analyzer.title','orders','عنوان: 🧠 محلّل بيانات الطلب','🧠 محلّل بيانات الطلب'),
 ('orders.cart.title','orders','عنوان: 🧾 سلة الطلب','🧾 سلة الطلب'),
 ('cashier.title','cashier','عنوان: 🧾 شاشة الكاشير — طلبات التوصيل فقط','🧾 شاشة الكاشير — طلبات التوصيل فقط'),
 ('driver.title','driver','عنوان: 🛵 بوابة الموصل','🛵 بوابة الموصل')
on conflict(key) do nothing;
