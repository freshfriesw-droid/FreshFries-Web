-- A09 stable titles; leave child nodes (including the current branch) intact.
INSERT INTO public.ff_content_catalog(key,screen,label,original) VALUES
('catalog.title','catalog','عنوان الشاشة','🍟 إدارة المنيو والعروض'),
('customers.title','customers','عنوان الشاشة','👥 دليل العملاء وملاحظاتهم'),
('staff.title','staff','عنوان الشاشة','👥 إدارة الموظفين والحسابات'),
('archive.title','archive','عنوان الشاشة','📁 أرشيف الطلبات والتعديلات'),
('ratings.title','ratings','عنوان الشاشة','⭐ تقييم الموصلين'),
('cases.title','cases','عنوان الشاشة','📋 مركز الشكاوى والتظلمات'),
('messages.title','messages','عنوان الشاشة','📨 مركز الرسائل الداخلية'),
('reservations.title','reservations','عنوان الشاشة','📅 حجوزات الاستلام — دون توصيل'),
('system.title','system','عنوان الشاشة','🩺 تشخيص النسخة والأخطاء التقنية'),
('assembly.title','assembly','عنوان الشاشة','📦 نقطة التجميع'),
('burger_kitchen.title','burger_kitchen','عنوان الشاشة','🍔 المطبخ · قسم البرجر')
ON CONFLICT(key) DO NOTHING;
