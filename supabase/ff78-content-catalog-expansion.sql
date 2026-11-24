-- DEC-09: add fixed plain-text controls across operational screens.
insert into public.ff_content_catalog(key,screen,label,original) values
 ('orders.parse','orders','زر تحليل الطلب','تحليل الأسطر ومعاينتها'),
 ('orders.menu','orders','زر المنيو التفاعلي','🍟 المنيو التفاعلي'),
 ('orders.text','orders','زر المحلل','🧠 الانتقال إلى المحلّل'),
 ('orders.refresh','orders','زر تحديث المنيو','تحديث المنيو'),
 ('orders.save','orders','زر اعتماد الطلب','اعتماد الطلب وحفظه'),
 ('catalog.refresh','catalog','زر تحديث المنيو والعروض','تحديث'),
 ('customers.find','customers','زر بحث العملاء','بحث'),
 ('customers.note','customers','زر حفظ ملاحظة العميل','حفظ ملاحظة العميل'),
 ('staff.refresh','staff','زر تحديث الموظفين','تحديث الموظفين'),
 ('staff.permissions','staff','زر عرض الصلاحيات','عرض صلاحيات الموظف'),
 ('cases.refresh','cases','زر تحديث البلاغات','تحديث البلاغات'),
 ('messages.refresh','messages','زر تحديث الرسائل','تحديث الرسائل'),
 ('archive.find','archive','زر بحث الأرشيف','بحث'),
 ('ratings.refresh','ratings','زر تحديث التقييمات','تحديث'),
 ('assembly.refresh','assembly','زر تحديث طلبات التجميع','تحديث الطلبات'),
 ('reservations.refresh','reservations','زر تحديث الحجوزات','تحديث')
on conflict(key) do nothing;
