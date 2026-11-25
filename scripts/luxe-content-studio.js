/* A09: explicit stable content keys, bounded safe formatting and authorized templates. */
(()=>{
'use strict';
const targets={
 "orders.field.branch":"#serviceOnly label[for=\"newBranch\"]",
 "orders.field.phone":"#serviceOnly label[for=\"newPhone\"]",
 "orders.field.area":"#serviceOnly label[for=\"newArea\"]",
 "orders.field.fee":"#serviceOnly label[for=\"newFee\"]",
 "orders.field.notes":"#serviceOnly label[for=\"newNotes\"]",
 "orders.field.customer":"#serviceOnly label[for=\"newCustomerName\"]",
 "orders.field.channel":"#serviceOnly label[for=\"newChannel\"]",
 "orders.field.address":"#serviceOnly label[for=\"newFullAddress\"]",
 "orders.field.items":"#serviceOnly label[for=\"newItems\"]",
 "orders.field.quick":"#serviceOnly label[for=\"ffbQuickInput\"]",
 "orders.title":"#serviceOnly .ff-neworder-workspace > h2",
 "orders.analyzer.title":"#ffbTextPanel > h3",
 "orders.cart.title":"#ffbMenuPanel .ffb-v2-cart > h3",
 "cashier.title":"#cashierView .card > h2",
 "driver.title":"#driverView .card .sectionbar > h2",
 'dashboard.title':'#ffx-hero-title','dashboard.new':'#ffx-hero-new','dashboard.reserve':'#ffx-hero-reserve','dashboard.late':'#ffx-hero-overdue',
 'reports.title':'#ff76Center .r-head h2','reports.subtitle':'#ff76Center .r-head p','reports.run':'#ff76Run',
 'reports.preview':'#ff76Preview','reports.download':'#ff76Download','reports.share':'#ff76Share','reports.csv':'#ff76CSV','reports.close':'#ff76Close',
 'orders.parse':'#ffbApplyText',
 'orders.menu':'#ffbTabMenu',
 'orders.text':'#ffbTabText',
 'orders.refresh':'#ffbMenuReload',
 'orders.save':'#createBtn',
 'catalog.refresh':'#ff51CatalogRefresh',
 'customers.find':'#ff51CustomerFind',
 'customers.note':'#ff51CustomerNoteSave',
 'staff.refresh':'#staffAdminRefresh',
 'staff.permissions':'#permissionLoad',
 'cases.refresh':'#ff41Refresh',
 'messages.refresh':'#ff39Refresh',
 'archive.find':'#ff51ArchiveRefresh',
 'ratings.refresh':'#ff51RatingsRefresh',
 'assembly.refresh':'#ffV12Refresh',
 'reservations.refresh':'#ff49ReservationsRefresh'
};
Object.assign(targets,{
 'catalog.title':"#ff51CatalogPanel .sectionbar h2",
 'customers.title':"#ff51CustomersPanel .sectionbar h2",
 'staff.title':"#staffAdminCard .sectionbar h2",
 'archive.title':"#ff51ArchivePanel .sectionbar h2",
 'ratings.title':"#ff51RatingsPanel .sectionbar h2",
 'cases.title':"#ff41Panel .ff41-header h2",
 'messages.title':"#ff39Panel .sectionbar h2",
 'reservations.title':"#ff49ReservationsPanel .sectionbar h2",
 'system.title':"#ff48DiagnosticsPanel .sectionbar h2",
 'assembly.title':"#ffV12AssemblyWorkspace .sectionbar h2",
 'burger_kitchen.title':"#ffBurgerKitchenWorkspace .ff-burger-head h2",
 'orders.cancel':'[data-cancel-order]','orders.add':'[data-open-addition]','orders.add_late':'[data-ff52-late]',
 'driver.attend':'#clockInBtn','driver.leave':'#clockOutBtn','driver.break':'#ff51BreakBtn',
 'assembly.open':'#ffV12Toggle','assembly.burger':'#ffV12BurgerOpen',
 'burger_kitchen.refresh':'#ffBurgerKitchenRefresh','burger_kitchen.finished':'#ffBurgerViewFinished','burger_kitchen.notifications':'#ffBurgerKitchenNotifications',
 'catalog.item_save':'#ff51ItemSave','catalog.offer_save':'#ff51OfferSave','archive.export':'#ff51ArchiveExport',
 'system.refresh':'#ff48Refresh','system.export':'#ff48Export','dashboard.shortcuts':'#ffA08ShortcutsHeading h3',
 'dashboard.branches':'#ffA08Branches h3','dashboard.activity':'#ffA08Activity h3'
});
// STEP06: explicit fixed source registry; no selectors supplied by edited content.
const additionalContent=[{"key":"orders.control.ffa06discarddraft","selector":"#ffA06DiscardDraft","original":"بدء مسودة فارغة","mode":"text"},{"key":"orders.control.ffreservebottom","selector":"#ffReserveBottom","original":"📅 حجز للاستلام","mode":"protected"},{"key":"assembly.control.ffv12logout","selector":"#ffV12Logout","original":"🚪 تسجيل الخروج","mode":"protected"},{"key":"burger_kitchen.control.ffburgerkitchenlogout","selector":"#ffBurgerKitchenLogout","original":"🚪 تسجيل الخروج","mode":"protected"},{"key":"catalog.control.ff51itemreset","selector":"#ff51ItemReset","original":"إلغاء التعديل","mode":"protected"},{"key":"catalog.control.ff51offerreset","selector":"#ff51OfferReset","original":"إلغاء التعديل","mode":"protected"},{"key":"archive.control.ff51archiveclose","selector":"#ff51ArchiveClose","original":"إغلاق","mode":"text"},{"key":"ratings.control.ff51ratingsclose","selector":"#ff51RatingsClose","original":"إغلاق","mode":"text"},{"key":"reservations.control.ff49reservationsclose","selector":"#ff49ReservationsClose","original":"إغلاق","mode":"text"},{"key":"cases.control.ff41close","selector":"#ff41Close","original":"إغلاق","mode":"text"},{"key":"messages.control.ff39close","selector":"#ff39Close","original":"إغلاق","mode":"text"},{"key":"system.control.ff48close","selector":"#ff48Close","original":"إغلاق","mode":"protected"},{"key":"staff.control.staffauditrefresh","selector":"#staffAuditRefresh","original":"عرض السجل","mode":"protected"},{"key":"orders.hint.ffbquickinput","selector":"#ffbQuickInput","original":"1 تشكن بدون شطة 1 استربس رقم العميل 77xxxxxxx المنطقة شارع القاهرة أجرة التوصيل 500 اسم الموصل أحمد ملاحظة الاتصال قبل الوصول","mode":"hint"},{"key":"orders.hint.newitems","selector":"#newItems","original":"1 تشكن 2 استربس ملاحظة بدون شطة","mode":"hint"},{"key":"catalog.field.ff51catname","selector":"label:has(+ #ff51CatName)","original":"القسم","mode":"label"},{"key":"catalog.hint.ff51catname","selector":"#ff51CatName","original":"الوجبات الرئيسية","mode":"hint"},{"key":"catalog.field.ff51itemname","selector":"label:has(+ #ff51ItemName)","original":"اسم الصنف","mode":"label"},{"key":"catalog.field.ff51itemprice","selector":"label:has(+ #ff51ItemPrice)","original":"السعر بالريال","mode":"label"},{"key":"catalog.field.ff51offername","selector":"label:has(+ #ff51OfferName)","original":"اسم العرض","mode":"label"},{"key":"catalog.field.ff51offerprice","selector":"label:has(+ #ff51OfferPrice)","original":"سعر العرض","mode":"label"},{"key":"customers.hint.ff51customersearch","selector":"#ff51CustomerSearch","original":"ابحث برقم الهاتف أو اسم العميل","mode":"hint"},{"key":"customers.field.ff51customernotetext","selector":"label:has(+ #ff51CustomerNoteText)","original":"إضافة ملاحظة","mode":"label"},{"key":"reports.field.ff76from","selector":"label:has(> #ff76From)","original":"من تاريخ","mode":"label"},{"key":"reports.field.ff76to","selector":"label:has(> #ff76To)","original":"إلى تاريخ","mode":"label"},{"key":"reports.field.ff76branch","selector":"label:has(> #ff76Branch)","original":"الفرع","mode":"label"},{"key":"reports.field.ff76driver","selector":"label:has(> #ff76Driver)","original":"موصل محدد","mode":"label"},{"key":"reports.field.ffa10staff","selector":"label:has(> #ffA10Staff)","original":"الموظف","mode":"label"},{"key":"reports.field.ffa10area","selector":"label:has(> #ffA10Area)","original":"المنطقة","mode":"label"},{"key":"reports.field.ffa10item","selector":"label:has(> #ffA10Item)","original":"الصنف (طلبات تحتويه)","mode":"label"},{"key":"reports.field.ffa10status","selector":"label:has(> #ffA10Status)","original":"حالة الطلب","mode":"label"},{"key":"reports.field.ff76mode","selector":"label:has(> #ff76Mode)","original":"محتوى التقرير","mode":"label"},{"key":"reports.field.ff76trend","selector":"label:has(> #ff76Trend)","original":"تجميع الرسم البياني","mode":"label"},{"key":"archive.field.ff51archivefrom","selector":"label:has(+ #ff51ArchiveFrom)","original":"من تاريخ","mode":"label"},{"key":"archive.field.ff51archiveto","selector":"label:has(+ #ff51ArchiveTo)","original":"إلى تاريخ","mode":"label"},{"key":"archive.field.ff51archivestatus","selector":"label:has(+ #ff51ArchiveStatus)","original":"الحالة","mode":"label"},{"key":"archive.field.ff51archivebranch","selector":"label:has(+ #ff51ArchiveBranch)","original":"الفرع","mode":"label"},{"key":"ratings.field.ff51ratingbranch","selector":"label:has(+ #ff51RatingBranch)","original":"فرع تقييمات الموصلين","mode":"label"},{"key":"reservations.field.ff49reservebranch","selector":"label:has(+ #ff49ReserveBranch)","original":"فرع الاستلام","mode":"label"},{"key":"reservations.field.ff49reservename","selector":"label:has(+ #ff49ReserveName)","original":"اسم العميل","mode":"label"},{"key":"reservations.field.ff49reservephone","selector":"label:has(+ #ff49ReservePhone)","original":"الهاتف","mode":"label"},{"key":"reservations.field.ff49reservenotes","selector":"label:has(+ #ff49ReserveNotes)","original":"ملاحظات الحجز","mode":"label"},{"key":"reservations.field.ff49reservepickup","selector":"label:has(+ #ff49ReservePickup)","original":"موعد الاستلام بتوقيت اليمن (اختياري)","mode":"label"},{"key":"reservations.field.ff49reserveitems","selector":"label:has(+ #ff49ReserveItems)","original":"الأصناف — كل صنف بسطر ويبدأ بالعدد","mode":"label"},{"key":"reservations.hint.ff49reserveitems","selector":"#ff49ReserveItems","original":"1 تشكن | 1500 2 استربس | 900","mode":"hint"},{"key":"cases.field.ff41kind","selector":"label:has(+ #ff41Kind)","original":"نوع البلاغ","mode":"label"},{"key":"cases.field.ff41branch","selector":"label:has(+ #ff41Branch)","original":"الفرع","mode":"label"},{"key":"cases.field.ff41priority","selector":"label:has(+ #ff41Priority)","original":"الأولوية","mode":"label"},{"key":"cases.field.ff41subject","selector":"label:has(+ #ff41Subject)","original":"عنوان البلاغ","mode":"label"},{"key":"cases.hint.ff41subject","selector":"#ff41Subject","original":"عنوان واضح ومختصر","mode":"hint"},{"key":"cases.field.ff41description","selector":"label:has(+ #ff41Description)","original":"التفاصيل","mode":"label"},{"key":"cases.hint.ff41description","selector":"#ff41Description","original":"اكتب المشكلة أو التظلم بوضوح، دون إدخال معلومات غير ضرورية","mode":"hint"},{"key":"cases.field.ff41filterkind","selector":"label:has(+ #ff41FilterKind)","original":"النوع","mode":"label"},{"key":"cases.field.ff41filterstatus","selector":"label:has(+ #ff41FilterStatus)","original":"الحالة","mode":"label"},{"key":"messages.field.ff39title","selector":"label:has(+ #ff39Title)","original":"عنوان الرسالة","mode":"label"},{"key":"messages.field.ff39role","selector":"label:has(+ #ff39Role)","original":"المستلمون","mode":"label"},{"key":"messages.field.ff39branch","selector":"label:has(+ #ff39Branch)","original":"الفرع","mode":"label"},{"key":"messages.field.ff39body","selector":"label:has(+ #ff39Body)","original":"نص الرسالة","mode":"label"},{"key":"messages.hint.ff39body","selector":"#ff39Body","original":"اكتب التعليمات أو التنبيه الإداري...","mode":"hint"},{"key":"finance.control.ff42load","selector":"#ff42Load","original":"عرض التسويات","mode":"protected"},{"key":"finance.control.ff42export","selector":"#ff42Export","original":"تصدير CSV","mode":"protected"},{"key":"finance.control.ff42closepanel","selector":"#ff42ClosePanel","original":"إغلاق","mode":"protected"},{"key":"finance.control.ff42save","selector":"#ff42Save","original":"حفظ التسوية","mode":"protected"},{"key":"finance.control.ff42closesettlement","selector":"#ff42CloseSettlement","original":"🔒 إقفال التسوية","mode":"protected"},{"key":"finance.control.ff42showdetail","selector":"#ff42ShowDetail","original":"عرض الطلبات والسجل","mode":"protected"},{"key":"finance.field.ff42day","selector":"label:has(+ #ff42Day)","original":"تاريخ التسليم","mode":"label"},{"key":"finance.field.ff42branch","selector":"label:has(+ #ff42Branch)","original":"الفرع","mode":"label"},{"key":"finance.field.ff42cashdue","selector":"label:has(+ #ff42CashDue)","original":"النقد الواجب توريده (ريال يمني)","mode":"label"},{"key":"finance.hint.ff42cashdue","selector":"#ff42CashDue","original":"أدخل الرقم المعتمد يدويًا","mode":"hint"},{"key":"finance.field.ff42cashreceived","selector":"label:has(+ #ff42CashReceived)","original":"النقد المستلم فعليًا (ريال يمني)","mode":"label"},{"key":"finance.hint.ff42cashreceived","selector":"#ff42CashReceived","original":"أدخل المستلم فعليًا","mode":"hint"},{"key":"finance.field.ff42notes","selector":"label:has(+ #ff42Notes)","original":"توضيح المدفوعات غير النقدية أو فروقات التوريد","mode":"label"},{"key":"finance.hint.ff42notes","selector":"#ff42Notes","original":"مثلاً: طلبات على حساب شركة توصيل / دفع إلكتروني / مبلغ لم يستلم بعد","mode":"hint"},{"key":"branches.control.ffa05branchpolicybtn","selector":"#ffA05BranchPolicyBtn","original":"ساعات العمل والرسوم وسجل الأسعار","mode":"protected"},{"key":"branches.control.ffa05close","selector":"#ffA05Close","original":"إغلاق","mode":"protected"},{"key":"branches.control.ffa05savehours","selector":"#ffA05SaveHours","original":"حفظ ساعات اليوم","mode":"protected"},{"key":"branches.control.ffa05savetariff","selector":"#ffA05SaveTariff","original":"حفظ الرسم","mode":"protected"},{"key":"branches.control.ffa05pricehistory","selector":"#ffA05PriceHistory","original":"سجل أسعار الأصناف والعروض","mode":"protected"},{"key":"branches.field.ffa05policybranch","selector":"label:has(> #ffA05PolicyBranch)","original":"الفرع","mode":"label"},{"key":"branches.field.ffa05effective","selector":"label:has(> #ffA05Effective)","original":"وقت السريان (اختياري)","mode":"label"},{"key":"branches.field.ffa05reason","selector":"label:has(> #ffA05Reason)","original":"سبب التغيير","mode":"label"},{"key":"branches.hint.ffa05reason","selector":"#ffA05Reason","original":"سبب معتمد من الإدارة","mode":"hint"},{"key":"branches.field.ffa05day","selector":"label:has(> #ffA05Day)","original":"اليوم","mode":"label"},{"key":"branches.field.ffa05open","selector":"label:has(> #ffA05Open)","original":"فتح","mode":"label"},{"key":"branches.field.ffa05closetime","selector":"label:has(> #ffA05CloseTime)","original":"إغلاق","mode":"label"},{"key":"branches.field.ffa05shift","selector":"label:has(> #ffA05Shift)","original":"تبديل الوردية (اختياري)","mode":"label"},{"key":"branches.field.ffa05area","selector":"label:has(> #ffA05Area)","original":"المنطقة","mode":"label"},{"key":"branches.field.ffa05tariff","selector":"label:has(> #ffA05Tariff)","original":"الرسم بالريال","mode":"label"},{"key":"system.control.ff47reload","selector":"#ff47Reload","original":"تحديث النتائج","mode":"protected"},{"key":"system.control.ff47close","selector":"#ff47Close","original":"إغلاق","mode":"protected"},{"key":"system.field.ff47version","selector":"label:has(> #ff47Version)","original":"رقم النسخة","mode":"label"},{"key":"system.field.ff47title","selector":"label:has(> #ff47Title)","original":"عنوان الجولة","mode":"label"},{"key":"system.control.ff47create","selector":"#ff47Create","original":"إنشاء جولة اختبار","mode":"protected"},{"key":"system.field.ff47runs","selector":"label:has(> #ff47Runs)","original":"الجولات المحفوظة","mode":"label"},{"key":"system.control.ff47export","selector":"#ff47Export","original":"تصدير النتائج CSV","mode":"protected"},{"key":"system.control.ff47finish","selector":"#ff47Finish","original":"اعتماد اكتمال الجولة","mode":"protected"},{"key":"system.control.ff47reopen","selector":"#ff47Reopen","original":"إعادة فتح الجولة","mode":"protected"},{"key":"system.field.ff47category","selector":"label:has(> #ff47Category)","original":"القسم","mode":"label"},{"key":"system.field.ff47filter","selector":"label:has(> #ff47Filter)","original":"النتيجة","mode":"label"},{"key":"system.control.ff46run","selector":"#ff46Run","original":"فحص جاهزية النسخة","mode":"protected"},{"key":"system.control.ff46export","selector":"#ff46Export","original":"تصدير CSV","mode":"protected"},{"key":"system.control.ff46close","selector":"#ff46Close","original":"إغلاق","mode":"protected"},{"key":"system.control.ff45run","selector":"#ff45Run","original":"فحص الوصول","mode":"protected"},{"key":"system.control.ff45export","selector":"#ff45Export","original":"تصدير CSV","mode":"protected"},{"key":"system.control.ff45close","selector":"#ff45Close","original":"إغلاق","mode":"protected"},{"key":"system.control.ff44export","selector":"#ff44Export","original":"تصدير النتائج CSV","mode":"protected"},{"key":"system.control.ff44close","selector":"#ff44Close","original":"إغلاق","mode":"protected"},{"key":"system.field.ff44from","selector":"label:has(+ #ff44From)","original":"من تاريخ","mode":"label"},{"key":"system.field.ff44to","selector":"label:has(+ #ff44To)","original":"إلى تاريخ","mode":"label"},{"key":"system.control.ff44run","selector":"#ff44Run","original":"بدء فحص البيانات","mode":"protected"},{"key":"system.control.ff43run","selector":"#ff43Run","original":"فحص الآن","mode":"protected"},{"key":"system.control.ff43export","selector":"#ff43Export","original":"تصدير نتائج CSV","mode":"protected"},{"key":"system.control.ff43close","selector":"#ff43Close","original":"إغلاق","mode":"protected"},{"key":"cases.field.ff41order","selector":"label:has(+ #ff41Order)","original":"الطلب المرتبط (اختياري)","mode":"label"},{"key":"cases.field.ff41customername","selector":"label:has(+ #ff41CustomerName)","original":"اسم العميل (اختياري)","mode":"label"},{"key":"cases.hint.ff41customername","selector":"#ff41CustomerName","original":"اسم العميل","mode":"hint"},{"key":"cases.field.ff41customerphone","selector":"label:has(+ #ff41CustomerPhone)","original":"رقم التواصل (اختياري)","mode":"label"},{"key":"cases.field.ff41channel","selector":"label:has(+ #ff41Channel)","original":"مصدر الشكوى","mode":"label"},{"key":"cases.control.ff41create","selector":"#ff41Create","original":"حفظ البلاغ","mode":"text"},{"key":"messages.control.ff39send","selector":"#ff39Send","original":"إرسال التعميم","mode":"protected"},{"key":"messages.control.ff39sentrefresh","selector":"#ff39SentRefresh","original":"سجل الإرسال","mode":"protected"},{"key":"dashboard.control.ff40alertrefresh","selector":"#ff40AlertRefresh","original":"تحديث التنبيهات","mode":"text"},{"key":"dashboard.control.ff40alertsclose","selector":"#ff40AlertsClose","original":"إغلاق","mode":"text"},{"key":"dashboard.field.ff40alertbranch","selector":"label:has(+ #ff40AlertBranch)","original":"فلتر الفرع","mode":"label"},{"key":"staff.control.ffeditmyaccount","selector":"#ffEditMyAccount","original":"✏️ تعديل حساب المدير","mode":"protected"},{"key":"staff.field.ffa05staffsearch","selector":"label:has(> #ffA05StaffSearch)","original":"بحث الموظفين","mode":"label"},{"key":"staff.field.ffa05staffrole","selector":"label:has(> #ffA05StaffRole)","original":"الدور","mode":"label"},{"key":"staff.field.ffa05staffactive","selector":"label:has(> #ffA05StaffActive)","original":"الحالة","mode":"label"},{"key":"staff.field.ffa05staffsort","selector":"label:has(> #ffA05StaffSort)","original":"الفرز","mode":"label"},{"key":"staff.field.permissionemployee","selector":"label:has(+ #permissionEmployee)","original":"الموظف","mode":"label"},{"key":"catalog.control.ff51catalogclose","selector":"#ff51CatalogClose","original":"إغلاق","mode":"text"},{"key":"catalog.field.ffcatalogcardtarget","selector":"label:has(> #ffCatalogCardTarget)","original":"الصنف أو العرض","mode":"label"},{"key":"catalog.field.ffcatalogcardsort","selector":"label:has(+ #ffCatalogCardSort)","original":"ترتيب البطاقة (الأصغر أولًا)","mode":"label"},{"key":"catalog.field.ffcatalogcardstyle","selector":"label:has(+ #ffCatalogCardStyle)","original":"تصميم البطاقة","mode":"label"},{"key":"catalog.control.ffcatalogcardsave","selector":"#ffCatalogCardSave","original":"حفظ تصميم البطاقة مركزيًا","mode":"text"},{"key":"catalog.field.ffaliastarget","selector":"label:has(> #ffAliasTarget)","original":"الصنف أو العرض","mode":"label"},{"key":"catalog.field.ffaliasnames","selector":"label:has(> #ffAliasNames)","original":"المرادفات، كل مرادف في سطر","mode":"label"},{"key":"catalog.control.ffaliassave","selector":"#ffAliasSave","original":"حفظ المرادفات","mode":"text"},{"key":"catalog.control.ffaliasdefault","selector":"#ffAliasDefault","original":"استعادة المرادفات الافتراضية","mode":"protected"},{"key":"customers.control.ff51customersclose","selector":"#ff51CustomersClose","original":"إغلاق","mode":"text"},{"key":"archive.control.ff51archiveprev","selector":"#ff51ArchivePrev","original":"الصفحة السابقة","mode":"text"},{"key":"archive.control.ff51archivenext","selector":"#ff51ArchiveNext","original":"الصفحة التالية","mode":"text"},{"key":"orders.control.ff50refresh","selector":"#ff50Refresh","original":"تحديث","mode":"text"},{"key":"orders.control.ff50close","selector":"#ff50Close","original":"إغلاق","mode":"text"},{"key":"orders.field.ff50requestitems","selector":"label:has(+ #ff50RequestItems)","original":"الأصناف الجديدة كاملة (كل صنف يبدأ بالعدد)","mode":"label"},{"key":"orders.field.ff50requestreason","selector":"label:has(+ #ff50RequestReason)","original":"سبب التعديل","mode":"label"},{"key":"orders.hint.ff50requestreason","selector":"#ff50RequestReason","original":"اشرح ما طلبه العميل (إلزامي)","mode":"hint"},{"key":"orders.control.ff50requestsave","selector":"#ff50RequestSave","original":"إرسال طلب التعديل للكاشير","mode":"protected"},{"key":"orders.control.ff50requestcancel","selector":"#ff50RequestCancel","original":"إلغاء","mode":"protected"},{"key":"orders.control.ff49transferrefresh","selector":"#ff49TransferRefresh","original":"تحديث","mode":"text"},{"key":"orders.control.ff49transferclose","selector":"#ff49TransferClose","original":"إغلاق","mode":"text"},{"key":"reservations.control.ff49reservesave","selector":"#ff49ReserveSave","original":"حفظ الحجز وإرساله لكاشير الفرع","mode":"protected"},{"key":"assembly.control.ff66assemblysoundsettings","selector":"#ff66AssemblySoundSettings","original":"🔔 النغمات","mode":"text"},{"key":"staff.control.ffeditclose","selector":"#ffEditClose","original":"إغلاق ✕","mode":"protected"},{"key":"staff.control.ffeditsave","selector":"#ffEditSave","original":"💾 حفظ البيانات","mode":"protected"},{"key":"orders.field.ordersearch","selector":"label:has(+ #orderSearch)","original":"رقم الطلب أو الهاتف أو اسم العميل أو المنطقة","mode":"label"},{"key":"orders.field.orderbranchfilter","selector":"label:has(+ #orderBranchFilter)","original":"الفرع","mode":"label"},{"key":"orders.field.orderstatusfilter","selector":"label:has(+ #orderStatusFilter)","original":"الحالة","mode":"label"},{"key":"orders.control.auditrefreshbtn","selector":"#auditRefreshBtn","original":"تحديث السجل","mode":"text"},{"key":"orders.control.ff49manualclose","selector":"#ff49ManualClose","original":"إغلاق","mode":"text"},{"key":"orders.field.ff49manualdriver","selector":"label:has(+ #ff49ManualDriver)","original":"الموصل المرشح","mode":"label"},{"key":"orders.field.ff49manualreason","selector":"label:has(+ #ff49ManualReason)","original":"سبب اختيار الموصل","mode":"label"},{"key":"orders.hint.ff49manualreason","selector":"#ff49ManualReason","original":"مثال: في طريقه لنفس المنطقة","mode":"hint"},{"key":"orders.control.ff49manualconfirm","selector":"#ff49ManualConfirm","original":"تأكيد الإسناد وتوثيق السبب","mode":"protected"},{"key":"orders.control.ff52lateclose","selector":"#ff52LateClose","original":"إغلاق","mode":"text"},{"key":"orders.field.ff52lateitems","selector":"label:has(+ #ff52LateItems)","original":"الأصناف (العدد أولًا، مع السعر أو اسم من المنيو)","mode":"label"},{"key":"orders.hint.ff52lateitems","selector":"#ff52LateItems","original":"1 تشكن | 1500 2 بطاطس | 300","mode":"hint"},{"key":"orders.control.ff75latepreview","selector":"#ff75LatePreview","original":"🔎 تحليل ومعاينة الإضافة","mode":"text"},{"key":"orders.control.ff52latesave","selector":"#ff52LateSave","original":"تأكيد إرسال الإضافة إلى الموصل للموافقة","mode":"protected"},{"key":"orders.control.ffbclosereview","selector":"#ffbCloseReview","original":"إغلاق","mode":"text"},{"key":"orders.control.ffbconfirmsave","selector":"#ffbConfirmSave","original":"تأكيد إنشاء الطلب","mode":"protected"},{"key":"orders.control.ffbcancelreview","selector":"#ffbCancelReview","original":"عودة للتعديل","mode":"text"},{"key":"driver.control.ff52routesclose","selector":"#ff52RoutesClose","original":"إغلاق","mode":"text"},{"key":"driver.field.ff52routebranch","selector":"label:has(+ #ff52RouteBranch)","original":"الفرع","mode":"label"},{"key":"driver.field.ff52routedriver","selector":"label:has(+ #ff52RouteDriver)","original":"الموصل","mode":"label"},{"key":"driver.field.ff52routeareas","selector":"label:has(+ #ff52RouteAreas)","original":"المناطق — افصل بينها بالفاصلة (،)","mode":"label"},{"key":"driver.field.ff52routestart","selector":"label:has(+ #ff52RouteStart)","original":"من الساعة","mode":"label"},{"key":"driver.field.ff52routeend","selector":"label:has(+ #ff52RouteEnd)","original":"حتى","mode":"label"},{"key":"driver.field.ff52routeactive","selector":"label:has(+ #ff52RouteActive)","original":"حالة التوجيه","mode":"label"},{"key":"driver.control.ff52routesave","selector":"#ff52RouteSave","original":"حفظ قاعدة التوجيه","mode":"text"},{"key":"staff.field.addemail","selector":"label:has(+ #addEmail)","original":"بريد الموظف","mode":"label"},{"key":"staff.field.addname","selector":"label:has(+ #addName)","original":"اسم الموظف","mode":"label"},{"key":"staff.hint.addname","selector":"#addName","original":"اسم الموظف","mode":"hint"},{"key":"staff.field.addrole","selector":"label:has(+ #addRole)","original":"الدور","mode":"label"},{"key":"staff.field.addbranch","selector":"label:has(+ #addBranch)","original":"الفرع (للموصل والكاشير ونقطة التجميع)","mode":"label"},{"key":"staff.control.linkuserbtn","selector":"#linkUserBtn","original":"ربط الحساب","mode":"protected"},{"key":"dashboard.control.ff60_refresh","selector":"#ff60-refresh","original":"تحديث البيانات","mode":"text"},{"key":"dashboard.control.ff60_close","selector":"#ff60-close","original":"إغلاق","mode":"text"},{"key":"dashboard.field.ff60_search","selector":"label:has(> #ff60-search)","original":"بحث برقم الطلب أو المنطقة","mode":"label"},{"key":"dashboard.hint.ff60_search","selector":"#ff60-search","original":"بحث سريع","mode":"hint"},{"key":"dashboard.field.ff60_branch","selector":"label:has(> #ff60-branch)","original":"الفرع","mode":"label"},{"key":"dashboard.field.ff60_state","selector":"label:has(> #ff60-state)","original":"مرحلة الطلب","mode":"label"},{"key":"dashboard.control.ff60_open_old","selector":"#ff60-open-old","original":"الواجهة الأصلية","mode":"text"},{"key":"dashboard.field.ff60_fast","selector":"label:has(> #ff60-fast)","original":"عند وجود موصل بديل جاهز (بالدقائق)","mode":"label"},{"key":"dashboard.field.ff60_slow","selector":"label:has(> #ff60-slow)","original":"عند عدم وجود بديل (بالدقائق)","mode":"label"},{"key":"dashboard.control.ff60_save_policy","selector":"#ff60-save-policy","original":"حفظ المهل للطلبات الجديدة","mode":"text"},{"key":"dashboard.control.ff4_refresh","selector":"#ff4-refresh","original":"تحديث البيانات","mode":"text"},{"key":"dashboard.control.ff4_export","selector":"#ff4-export","original":"تصدير CSV","mode":"text"},{"key":"dashboard.control.ff4_close","selector":"#ff4-close","original":"إغلاق ×","mode":"text"},{"key":"dashboard.field.ff4_search","selector":"label:has(> #ff4-search)","original":"بحث برقم الطلب أو المنطقة","mode":"label"},{"key":"dashboard.hint.ff4_search","selector":"#ff4-search","original":"بحث سريع","mode":"hint"},{"key":"dashboard.field.ff4_branch","selector":"label:has(> #ff4-branch)","original":"الفرع","mode":"label"},{"key":"dashboard.field.ff4_state","selector":"label:has(> #ff4-state)","original":"الحالة","mode":"label"},{"key":"dashboard.field.ff4_minutes","selector":"label:has(> #ff4-minutes)","original":"حد التأخير بالدقائق","mode":"label"},{"key":"dashboard.control.ff5_refresh","selector":"#ff5-refresh","original":"تحديث مباشر","mode":"text"},{"key":"dashboard.control.ff5_export","selector":"#ff5-export","original":"تصدير المتابعة CSV","mode":"text"},{"key":"dashboard.control.ff5_close","selector":"#ff5-close","original":"إغلاق","mode":"text"},{"key":"dashboard.field.ff5_search","selector":"label:has(> #ff5-search)","original":"بحث الطلب / المنطقة","mode":"label"},{"key":"dashboard.hint.ff5_search","selector":"#ff5-search","original":"رقم الطلب أو المنطقة","mode":"hint"},{"key":"dashboard.field.ff5_branch","selector":"label:has(> #ff5-branch)","original":"الفرع","mode":"label"},{"key":"dashboard.field.ff5_age","selector":"label:has(> #ff5-age)","original":"أقدم من (دقيقة)","mode":"label"},{"key":"dashboard.field.ff5_sort","selector":"label:has(> #ff5-sort)","original":"الترتيب","mode":"label"},{"key":"orders.field.additionitemsinput","selector":"label:has(+ #additionItemsInput)","original":"محلّل أصناف الإضافة","mode":"label"},{"key":"orders.hint.additionitemsinput","selector":"#additionItemsInput","original":"1 تشكن بدون شطة 1 جبن ذرة ملاحظة الاتصال بالعميل","mode":"hint"},{"key":"cases.field.ff41nextstatus","selector":"label:has(+ #ff41NextStatus)","original":"الحالة التالية","mode":"label"},{"key":"cases.field.ff41resolution","selector":"label:has(+ #ff41Resolution)","original":"الحل أو الملاحظة (إلزامي عند «تم الحل»)","mode":"label"},{"key":"cases.hint.ff41resolution","selector":"#ff41Resolution","original":"اشرح الإجراء المتخذ أو الحل المقترح","mode":"hint"},{"key":"cases.hint.ff41commentbody","selector":"#ff41CommentBody","original":"اكتب ردك أو الملاحظة...","mode":"hint"},{"key":"dashboard.control.ffx_kpi_reload","selector":"#ffx-kpi-reload","original":"تحديث","mode":"text"},{"key":"dashboard.control.ffx_open_alerts","selector":"#ffx-open-alerts","original":"عرض مركز المتابعة","mode":"text"},{"key":"dashboard.hint.ff2_search","selector":"#ff2-search","original":"ابحث عن صفحة أو وظيفة...","mode":"hint"},{"key":"dashboard.control.ff3_close","selector":"#ff3-close","original":"إغلاق ×","mode":"text"},{"key":"system.field.ffx_density","selector":"label:has(+ #ffx-density)","original":"حجم الواجهة","mode":"label"},{"key":"system.field.ffx_auto","selector":"label:has(+ #ffx-auto)","original":"الوضع الليلي تلقائيًا","mode":"label"},{"key":"system.control.ffx_reset","selector":"#ffx-reset","original":"استعادة تفضيلات التصميم الافتراضية","mode":"protected"},{"key":"system.field.ffx_sound","selector":"label:has(+ #ffx-sound)","original":"صوت الطلب الجديد والتنبيه","mode":"label"},{"key":"system.field.ffx_delay_sound","selector":"label:has(+ #ffx-delay-sound)","original":"صوت التأخير","mode":"label"},{"key":"system.field.ffx_repeat","selector":"label:has(+ #ffx-repeat)","original":"إعادة تنبيه التأخير (دقائق)","mode":"label"},{"key":"system.control.ffx_play_sound","selector":"#ffx-play-sound","original":"تجربة النغمة","mode":"protected"},{"key":"system.control.ffx_play_delay","selector":"#ffx-play-delay","original":"تجربة تنبيه التأخير","mode":"protected"},{"key":"system.control.ffx_push_permission","selector":"#ffx-push-permission","original":"🔔 تفعيل إشعارات الخلفية واختبارها","mode":"protected"},{"key":"system.control.ff_luxe_audio_unlock","selector":"#ff-luxe-audio-unlock","original":"🔊 تفعيل وتشغيل النغمة التجريبية","mode":"protected"},{"key":"system.field.ff66_tone_name","selector":"label:has(> #ff66-tone-name)","original":"اسم النغمة","mode":"label"},{"key":"system.hint.ff66_tone_name","selector":"#ff66-tone-name","original":"مثلاً: نغمة وصول طلب جديد","mode":"hint"},{"key":"system.control.ff66_tone_add","selector":"#ff66-tone-add","original":"➕ إضافة النغمة للمطعم","mode":"protected"},{"key":"system.control.ff66_tone_refresh","selector":"#ff66-tone-refresh","original":"🔄 تحديث مكتبة النغمات","mode":"protected"},{"key":"reports.control.ff40exportcsv","selector":"#ff40ExportCSV","original":"تصدير CSV","mode":"text"},{"key":"reports.control.ff40reportsclose","selector":"#ff40ReportsClose","original":"إغلاق","mode":"text"},{"key":"reports.field.ff40from","selector":"label:has(+ #ff40From)","original":"من تاريخ","mode":"label"},{"key":"reports.field.ff40to","selector":"label:has(+ #ff40To)","original":"إلى تاريخ","mode":"label"},{"key":"reports.field.ff40reportbranch","selector":"label:has(+ #ff40ReportBranch)","original":"الفرع","mode":"label"},{"key":"reports.control.ff40runreport","selector":"#ff40RunReport","original":"إعداد التقرير","mode":"text"},{"key":"staff.control.ffeditshare","selector":"#ffEditShare","original":"📤 مشاركة بيانات الدخول","mode":"protected"},{"key":"reports.control.ff76today","selector":"#ff76Today","original":"اليوم التشغيلي","mode":"text"},{"key":"reports.control.ff76yesterday","selector":"#ff76Yesterday","original":"أمس","mode":"text"},{"key":"reports.control.ff76seven","selector":"#ff76Seven","original":"آخر 7 أيام","mode":"text"},{"key":"reports.control.ff76thirty","selector":"#ff76Thirty","original":"آخر 30 يوماً","mode":"text"},{"key":"reports.control.ff76savepreset","selector":"#ff76SavePreset","original":"حفظ الاختيارات","mode":"text"},{"key":"reports.control.ff76usepreset","selector":"#ff76UsePreset","original":"تطبيق القالب","mode":"text"},{"key":"reports.control.ffa10grantsave","selector":"#ffA10GrantSave","original":"حفظ التفويض","mode":"protected"},{"key":"reports.control.ff76saveapproval","selector":"#ff76SaveApproval","original":"حفظ واعتماد التقرير","mode":"protected"},{"key":"reports.control.ff76dlgdownload","selector":"#ff76DlgDownload","original":"حفظ الملف","mode":"text"},{"key":"reports.control.ff76dlgshare","selector":"#ff76DlgShare","original":"مشاركة الملف","mode":"text"},{"key":"reports.control.ff76dlgclose","selector":"#ff76DlgClose","original":"✕ إغلاق","mode":"text"},{"key":"messages.field.ffa11priority","selector":"label:has(> #ffA11Priority)","original":"أولوية الرسالة","mode":"label"},{"key":"messages.field.ffa11route","selector":"label:has(> #ffA11Route)","original":"انتقال داخلي اختياري","mode":"label"},{"key":"messages.field.ffa11template","selector":"label:has(> #ffA11Template)","original":"قالب محفوظ","mode":"label"},{"key":"messages.field.ffa11templatename","selector":"label:has(> #ffA11TemplateName)","original":"اسم القالب","mode":"label"},{"key":"messages.control.ffa11templatesave","selector":"#ffA11TemplateSave","original":"حفظ القالب","mode":"text"},{"key":"messages.control.ffa11templatedelete","selector":"#ffA11TemplateDelete","original":"حذف القالب المحدد","mode":"protected"},{"key":"messages.control.ffa11preview","selector":"#ffA11Preview","original":"معاينة المستلمين","mode":"text"},{"key":"messages.field.ffa11grantuser","selector":"label:has(> #ffA11GrantUser)","original":"الموظف","mode":"label"},{"key":"messages.field.ffa11grantrole","selector":"label:has(> #ffA11GrantRole)","original":"الفئة","mode":"label"},{"key":"messages.field.ffa11grantbranch","selector":"label:has(> #ffA11GrantBranch)","original":"الفرع","mode":"label"},{"key":"messages.control.ffa11grantsave","selector":"#ffA11GrantSave","original":"منح التفويض","mode":"protected"},{"key":"messages.control.ffa11grantrefresh","selector":"#ffA11GrantRefresh","original":"تحديث التفويضات","mode":"protected"},{"key":"messages.control.ffa11audit","selector":"#ffA11Audit","original":"سجل التدقيق","mode":"text"},{"key":"system.field.ffa12scope","selector":"label:has(> #ffA12Scope)","original":"نطاق البيانات","mode":"label"},{"key":"system.field.ffa12branch","selector":"label:has(> #ffA12Branch)","original":"الفرع","mode":"label"},{"key":"system.field.ffa12type","selector":"label:has(> #ffA12Type)","original":"نوع الطلب","mode":"label"},{"key":"system.field.ffa12from","selector":"label:has(> #ffA12From)","original":"من تاريخ (توقيت صنعاء)","mode":"label"},{"key":"system.field.ffa12to","selector":"label:has(> #ffA12To)","original":"إلى تاريخ","mode":"label"},{"key":"system.control.ffa12preview","selector":"#ffA12Preview","original":"معاينة التبعيات والأعداد","mode":"protected"},{"key":"system.control.ffa12execute","selector":"#ffA12Execute","original":"حفظ نسخة على الخادم وتصفير المحدد","mode":"protected"},{"key":"system.control.ffa12list","selector":"#ffA12List","original":"تحديث النسخ","mode":"protected"},{"key":"system.field.ffa12batch","selector":"label:has(> #ffA12Batch)","original":"اختر نسخة","mode":"label"},{"key":"system.control.ffa12restore","selector":"#ffA12Restore","original":"استرجاع النسخة والتحقق من تطابقها","mode":"protected"},{"key":"system.field.ffa12fixturetype","selector":"label:has(> #ffA12FixtureType)","original":"النوع","mode":"label"},{"key":"system.field.ffa12fixturedate","selector":"label:has(> #ffA12FixtureDate)","original":"تاريخ الاختبار","mode":"label"},{"key":"system.field.ffa12fixtureconfirm","selector":"label:has(> #ffA12FixtureConfirm)","original":"اكتب: إنشاء طلب اختبار","mode":"label"},{"key":"system.control.ffa12fixture","selector":"#ffA12Fixture","original":"إنشاء طلب الاختبار","mode":"protected"},{"key":"messages.field.ffa11grantpriority","selector":"label:has(> #ffA11GrantPriority)","original":"أقصى أولوية","mode":"label"},{"key":"messages.field.ffa11granthours","selector":"label:has(> #ffA11GrantHours)","original":"مدة التفويض بالساعات","mode":"label"},{"key":"reports.field.ff76presetname","selector":"label:has(> #ff76PresetName)","original":"اسم القالب","mode":"label"},{"key":"reports.field.ff76presetlist","selector":"label:has(> #ff76PresetList)","original":"قوالبي","mode":"label"},{"key":"reports.field.ffa10grantuser","selector":"label:has(> #ffA10GrantUser)","original":"الحساب","mode":"label"},{"key":"reports.field.ffa10grantsection","selector":"label:has(> #ffA10GrantSection)","original":"القسم","mode":"label"},{"key":"reports.field.ffa10grantallowed","selector":"label:has(> #ffA10GrantAllowed)","original":"القرار","mode":"label"},{"key":"reports.field.ff76managername","selector":"label:has(> #ff76ManagerName)","original":"اسم المدير","mode":"label"},{"key":"reports.field.ff76managernotes","selector":"label:has(> #ff76ManagerNotes)","original":"ملاحظات الإدارة","mode":"label"},{"key":"cashier.control.ffburgerpaneltoggle","selector":"#ffBurgerPanelToggle","original":"🍔 أوامر قسم البرجر","mode":"text"},{"key":"cashier.control.ffburgernew","selector":"#ffBurgerNew","original":"🍔 إعلام قسم البرجر","mode":"text"},{"key":"cashier.control.ffburgercollapse","selector":"#ffBurgerCollapse","original":"✕ إغلاق القائمة","mode":"text"},{"key":"cashier.control.ffburgersubmit","selector":"#ffBurgerSubmit","original":"✅ اعتماد وإرسال الطلب","mode":"protected"},{"key":"cashier.control.ffburgercancel","selector":"#ffBurgerCancel","original":"إلغاء","mode":"protected"},{"key":"finance.title","selector":"#ff42Panel .sectionbar h2","original":"💰 تسويات الموصلين النقدية","mode":"protected"},{"key":"branches.title","selector":"#ffA05BranchCard .sectionbar h3","original":"إعدادات الفروع والأسعار","mode":"protected"},{"key":"dashboard.alerts_title","selector":"#ff40AlertsPanel .sectionbar h2","original":"⚠️ المتابعة التشغيلية للطلبات","mode":"protected"},{"key":"reports.legacy_title","selector":"#ff40ReportsPanel .sectionbar h2","original":"📊 التقارير التشغيلية للفروع","mode":"protected"},{"key":"system.security_title","selector":"#ff43SecurityPanel .sectionbar h2","original":"🛡️ أمان النظام — فحص قاعدة البيانات","mode":"protected"},{"key":"system.integrity_title","selector":"#ff44IntegrityPanel .sectionbar h2","original":"🔎 تدقيق سلامة البيانات","mode":"protected"},{"key":"system.access_title","selector":"#ff45AccessPanel .sectionbar h2","original":"🔐 مراجعة عزل الفروع والصلاحيات","mode":"protected"},{"key":"system.readiness_title","selector":"#ff46ReadinessPanel .sectionbar h2","original":"🧪 جاهزية النظام للتجربة الشاملة","mode":"protected"},{"key":"system.qa_title","selector":"#ff47QAPanel .sectionbar h2","original":"📋 مركز التجربة الشاملة","mode":"protected"},{"key":"orders.changes_title","selector":"#ff50ChangesPanel .sectionbar h2","original":"📝 تعديلات الطلبات بموافقة الكاشير","mode":"protected"},{"key":"orders.transfer_title","selector":"#ff49TransferPanel .sectionbar h2","original":"🔄 طلبات نقل الموصل بعد القطع","mode":"protected"},{"key":"orders.manual_title","selector":"#ff49ManualPanel .sectionbar h2","original":"🛵 إسناد يدوي معلّل","mode":"protected"},{"key":"orders.late_title","selector":"#ff52LatePanel .sectionbar h2","original":"➕ إضافة متأخرة بعد مغادرة الموصل","mode":"protected"},{"key":"driver.routes_title","selector":"#ff52RoutesPanel .sectionbar h2","original":"📍 توجيه مناطق الجامعات","mode":"protected"},{"key":"driver.offers_title","selector":"#driverView .card:has(#driverOffers) > h2","original":"🔔 عروض الطلبات الجديدة","mode":"protected"},{"key":"cashier.guidance","selector":"#cashierView .card","original":"أكد الاستلام أولًا، ثم أدخل رقم فاتورة MicroPOS بعد قطعها خارجيًا. لا يصدر هذا النظام فاتورة.","mode":"guide"},{"key":"driver.guidance","selector":"#driverView .card:has(#clockInBtn)","original":"تسجيل الدخول لا يبدأ الدوام تلقائيًا. اضغط تسجيل حضور عند بدء العمل.","mode":"guide"},{"key":"finance.guidance","selector":"#ff42Panel","original":"تقرير تشغيلي؛ ليس إثباتًا للتحصيل النقدي أو تسوية المحاسبة.","mode":"guide"},{"key":"branches.guidance","selector":"#ffA05BranchDialog","original":"وقت السريان بتوقيت صنعاء. لا تتغير أسعار الطلبات القديمة.","mode":"guide"},{"key":"system.security_guidance","selector":"#ff43SecurityPanel","original":"عدم ظهور تحذيرات لا يثبت أن النظام آمن.","mode":"guide"},{"key":"orders.late_guidance","selector":"#ff52LatePanel","original":"لن تُحسب الإضافة ضمن المبلغ النهائي قبل موافقة الموصل وتأكيد الكاشير.","mode":"guide"},{"key":"orders.transfer_guidance","selector":"#ff49TransferPanel","original":"لا تنفّذ تأكيدًا قبل تحديث البرنامج الخارجي.","mode":"guide"},{"key":"messages.guidance","selector":"#ff39Panel","original":"إرشادات إضافية للتعميم الإداري.","mode":"guide"}];
for(const r of additionalContent)if(r.mode!=='hint'&&r.mode!=='guide')targets[r.key]=r.selector;
const navKeys=['home','new','orders','late','drivers','driver','cashier','reservations','transfer','routes','messages','cases','offers','attendance','burger','cashier_finished','reports','archive','ratings','catalog','customers','changes','team','assembly_admin','applications','application_alerts','branch_policy','staff_link','studio','data_center','security','integrity','access','readiness','qa','diagnostics'];
for(const key of navKeys)targets['nav.'+key]='#ffx-nav button[data-key="'+key+'"] > span:first-of-type,#ffx-mobile-nav button[data-key="'+key+'"] > span:first-of-type,#ffx-shortcuts button[data-a08-action="'+key+'"] > span:first-of-type';
const extraText=new Set(['reports.pdf_title','reports.pdf_note','orders.success','orders.error','notices.new_order']);
const hintTargets={"orders.hint.phone":"#newPhone","orders.hint.area":"#newArea","orders.hint.fee":"#newFee","orders.hint.notes":"#newNotes","orders.hint.menu":"#ffbMenuSearch","orders.hint.search":"#orderSearch"};
for(const r of additionalContent)if(r.mode==='hint')hintTargets[r.key]=r.selector;
const hintOriginals=new WeakMap();
const templates=new Set(['notices.delayed','notices.reminder','notices.order_summary']);
const variableKeys=['order_number','customer_name','driver_name','delivery_fee'];
const officialLink='[فتح النظام](https://delivery.freshfriesz.com/)';
const guides={'orders.guidance':{parent:'#ffbTextPanel',original:'راجع الأصناف والكميات في المعاينة قبل الاعتماد.'},'reports.guidance':{parent:'#ff76Center .r-head',original:'اختر الفترة والأقسام المطلوبة، ثم اضغط إعداد التقرير.'}};
for(const r of additionalContent)if(r.mode==='guide')guides[r.key]={parent:r.selector,original:r.original,supplemental:true};
const known=k=>Object.hasOwn(targets,k)||Object.hasOwn(hintTargets,k)||templates.has(k)||Object.hasOwn(guides,k)||extraText.has(k);
function isGuide(k){return Object.hasOwn(guides,k)}
function appendInline(node,line){
 for(const part of line.split(/(\*\*[^*\n]+\*\*|\[فتح النظام\]\(https:\/\/delivery\.freshfriesz\.com\/\))/g)){
  if(part===officialLink){const link=document.createElement('a');link.href='https://delivery.freshfriesz.com/';link.target='_blank';link.rel='noopener noreferrer';link.textContent='فتح النظام';node.append(link);continue}
  if(part.startsWith('**')&&part.endsWith('**')&&part.length>4){const strong=document.createElement('strong');strong.textContent=part.slice(2,-2);node.append(strong)}
  else node.append(document.createTextNode(part));
 }
}
function formatGuide(root,text){
 root.replaceChildren();let list=null;
 for(const line of String(text||'').split('\n')){
  if(!line.trim()){list=null;continue}
  if(line.startsWith('- ')){if(!list){list=document.createElement('ul');root.append(list)}const li=document.createElement('li');appendInline(li,line.slice(2));list.append(li)}
  else{list=null;const p=document.createElement('p');appendInline(p,line);root.append(p)}
 }
}
function renderGuide(key,value){
 const guide=guides[key],parent=document.querySelector(guide.parent);if(!parent)return;
 let node=parent.querySelector('[data-ff-guidance="'+key+'"]');
 if(guide.supplemental&&(!actor()||typeof value!=='string'||!validText(value,key))){node?.remove();return}
 if(!node){node=document.createElement('div');node.className='ff-safe-guidance';node.dataset.ffGuidance=key;node.setAttribute('aria-label','إرشادات إضافية');parent.append(node)}
 const body=actor()&&typeof value==='string'&&validText(value,key)?value:guide.original;
 if(node.dataset.source!==body){node.dataset.source=body;formatGuide(node,body)}
}
const screens={finance:'التسويات النقدية',branches:'الفروع والأسعار',burger_kitchen:'مطبخ البرجر',system:'النظام والأمان',cashier:'واجهة الكاشير',driver:'واجهة الموصل',notices:'التنبيهات التشغيلية',dashboard:'الرئيسية',reports:'التقارير',orders:'إدخال الطلبات',catalog:'المنيو والعروض',customers:'العملاء',staff:'الموظفون والصلاحيات',cases:'الشكاوى والتظلمات',messages:'الرسائل',archive:'الأرشيف',ratings:'التقييمات',assembly:'نقطة التجميع',reservations:'الحجوزات'};
const roles={all:'كل الأدوار',manager:'المدير العام',supervisor:'المشرف',customer_service:'خدمة العملاء',cashier:'الكاشير',driver:'الموصل',assembly:'نقطة التجميع',burger_kitchen:'مطبخ البرجر'};
const originalTitles={manager:'إدارة ذكية، ورؤية أوضح لكل فرع',driver:'توصيلاتك... بوضوح وسرعة',cashier:'كل طلب في وقته الصحيح',customer_service:'خدمة سريعة، وتجربة عميل أجمل',supervisor:'متابعة دقيقة في كل لحظة'};
const currentRole=()=>typeof ffV12AssemblyActive!=='undefined'&&ffV12AssemblyActive?'assembly':window.ffBurgerActive?.()?'burger_kitchen':typeof data!=='undefined'?data?.role:null;
const actor=()=>typeof user!=='undefined'&&user?.id&&currentRole()?user.id:'';
const manager=()=>!!actor()&&currentRole()==='manager';
const branch=()=>currentRole()==='assembly'?(typeof ffV12AssemblyPayload!=='undefined'?ffV12AssemblyPayload?.branch?.id||null:null):currentRole()==='burger_kitchen'?(window.ffBurgerContentBranch?.()||null):document.querySelector('#ffx-branch')?.value||(data?.branches?.length===1?data.branches[0].id:null);
const originals=new WeakMap();
let values=new Map(),context='',last=0,serial=0,session=0,catalog=[],history=[],busy=false;
const dialog=document.createElement('dialog');dialog.id='ffContentStudio';dialog.dir='rtl';dialog.setAttribute('aria-labelledby','ffContentHeading');
dialog.innerHTML='<div class="sectionbar"><h2 id="ffContentHeading">استوديو المحتوى والمسميات</h2><button type="button" data-content-close>إغلاق</button></div>'+
 '<p>تعديل النصوص المحددة فقط؛ لا تتغير وظائف الأزرار أو الصلاحيات أو قواعد العمل.</p>'+
 '<label>بحث في النصوص<input data-content-search type="search" placeholder="اسم الشاشة أو العنصر"></label><label>تصفية الواجهة<select data-content-screen></select></label>'+
 '<label>العنصر<select data-content-key></select></label><label>الدور<select data-content-role></select></label><label>الفرع<select data-content-branch></select></label>'+
 '<label>النص الجديد<textarea data-content-body maxlength="180" rows="3"></textarea></label>'+
 '<div data-content-tools hidden class="actions"><button type="button" data-content-bold>خط عريض</button><button type="button" data-content-bullet>نقطة قائمة</button><small>تنسيق موثوق فقط؛ الرابط الوحيد المسموح: [فتح النظام](https://delivery.freshfriesz.com/)؛ دون HTML.</small></div>'+
 '<p data-content-vars hidden>المتغيرات المتاحة: {order_number}، {customer_name}، {driver_name}، {delivery_fee} — المعاينة اصطناعية فقط.</p>'+
 '<section class="ff-content-preview"><h3>معاينة قبل / بعد</h3><p>الأصل: <b data-content-original></b></p><p>المسودة: <b data-content-preview></b></p><div data-content-rich-preview hidden></div></section>'+
 '<div class="actions"><button type="button" data-content-save>حفظ مسودة</button><button type="button" data-content-restore>استعادة الأصل كمسودة</button></div>'+
 '<div class="actions"><label>دور الإصدارات<select data-content-history-role></select></label><label>فرع الإصدارات<select data-content-history-branch></select></label></div><label>الإصدارات (أحدث 200 نتيجة في النطاق)<select data-content-history></select></label><p data-content-audit></p>'+
 '<div class="actions"><button type="button" data-content-load>معاينة الإصدار</button><button type="button" data-content-publish>نشر الإصدار المحدد</button></div>'+
 '<p data-content-status role="status" aria-live="polite"></p>';
document.body.append(dialog);
const q=s=>dialog.querySelector('[data-content-'+s+']');
const labelFor=k=>catalog.find(x=>x.key===k);
const selected=()=>history.find(x=>String(x.id)===q('history').value);
function originalText(key,role=data?.role){return key==='dashboard.title'?(originalTitles[role]||(role==='all'?'العنوان الأصلي بحسب الدور':'مساحة العمل الذكية')):(labelFor(key)?.original||'');}
function write(key,value){for(const node of document.querySelectorAll(targets[key]))writeNode(key,node,value)}
const preserveState=new Set(['driver.break','assembly.open','burger_kitchen.finished',...additionalContent.filter(r=>r.mode==='protected').map(r=>r.key)]);
function writeNode(key,node,value){
 if(value!=null&&!validText(value,key))value=null;
 if(key==='dashboard.title'){
  // paintStatus regenerates the title each cycle, so restore the role-specific source text.
  const fallback=actor()?originalText(key,currentRole()):'التحكم في كل التفاصيل، من شاشة واحدة';
  if(node.textContent!==(value??fallback))node.textContent=value??fallback;
  return;
 }
 // Apply only to live text nodes; never rewrite an operational label that has no override.
 const current=Array.from(node.childNodes).filter(n=>n.nodeType===Node.TEXT_NODE);
 let saved=originals.get(node);
 if(saved&&(!saved.every(([n])=>n.parentNode===node)||current.length!==saved.length)){
  originals.delete(node);saved=undefined;
 }
 if(value==null){
  if(saved){for(const [text,original,applied] of saved){if(text.data===applied)text.data=original}originals.delete(node)}
  return;
 }
 if(!current.length)return;
 const binding=additionalContent.find(r=>r.key===key);
 if(binding?.mode==='label'&&!saved&&current.map(n=>n.data).join('').trim()!==binding.original)return;
 if(!saved){saved=current.map(n=>[n,n.data,null]);originals.set(node,saved)}
 for(let i=0;i<saved.length;i++){
  const item=saved[i],text=item[0];
  if(item[2]!==null&&text.data!==item[2])item[1]=text.data;
  const next=i===0?(preserveState.has(key)?item[1]+' — '+value:' '+value+(key==='assembly.title'?' · ':'')):preserveState.has(key)?item[1]:'';
  if(text.data!==next)text.data=next;
  item[2]=next;
 }
}
function writeHint(key,body){
 const node=document.querySelector(hintTargets[key]);if(!node)return;
 const prior=hintOriginals.get(node),current=node.getAttribute('placeholder');
 if(body==null){if(prior){if(current===prior.applied){if(prior.original===null)node.removeAttribute('placeholder');else node.setAttribute('placeholder',prior.original)}hintOriginals.delete(node)}return}
 if(!validText(body,key))return;
 const original=prior&&current===prior.applied?prior.original:current;
 node.setAttribute('placeholder',body);hintOriginals.set(node,{original,applied:body});
}
function render(){for(const key of Object.keys(targets))write(key,values.get(key)?.body??null);for(const key of navKeys){const b=document.querySelector('#ffx-mobile-nav button[data-key="'+key+'"]');if(b){const label=b.querySelector('span')?.textContent?.trim();if(label){b.setAttribute('aria-label',label);b.title=label}}}for(const key of Object.keys(hintTargets))writeHint(key,values.get(key)?.body??null);for(const key of Object.keys(guides))renderGuide(key,values.get(key)?.body??null)}
function reset(){
 serial++;session++;context='';last=0;values.clear();catalog=[];history=[];busy=false;
 if(dialog.open)dialog.close();for(const name of ['key','history','branch'])q(name).replaceChildren();
 for(const name of ['search','body'])q(name).value='';for(const name of ['status','audit','original','preview','rich-preview'])q(name).textContent='';
 render();
}
async function sync(force=false){
 const who=actor();if(!who){if(context||dialog.open)reset();return}
 const b=branch(),role=currentRole(),key=[who,role,b].join('|');
 if(key!==context){serial++;values.clear();if(dialog.open&&(!manager()||(context&&context.split('|')[0]!==who)))reset();context=key;last=0}
 render();
 if(!force&&Date.now()-last<30000)return;
 last=Date.now();const request=++serial;
 try{
  const rows=await rpc('ff_content_effective',{p_branch:b});
  if(request!==serial||actor()!==who||branch()!==b||currentRole()!==role)return;
  values=new Map((rows||[]).filter(r=>known(r.content_key)&&(r.body===null||typeof r.body==='string'&&validText(r.body,r.content_key))).map(r=>[r.content_key,r]));render();
 }catch{/* Old database or network loss: keep confirmed values within the same account/scope only. */}
}
const forbiddenFormat=/[\u0000-\u001f\u007f-\u009f\u00ad\u061c\u200b\u200e\u200f\u2028\u2029\u202a-\u202e\u2060-\u2064\u2066-\u2069\ufeff]/u;
const forbiddenLink=/(https?:\/\/|www\.|javascript:|data:|vbscript:|\/\/|&(#([0-9]+|x[0-9a-f]+);?|lt;|gt;|colon;|tab;|newline;))/i;
function validText(s,key){
 if(typeof s!=='string')return false;
 let clean=s;
 if(templates.has(key))for(const variable of variableKeys)clean=clean.replaceAll('{'+variable+'}','');
 else if(isGuide(key))clean=clean.replaceAll('\n','').replaceAll(officialLink,'');
 return !!clean.trim()&&[...s].length<=(isGuide(key)?1000:180)&&!/[<>{}]/u.test(clean)&&!forbiddenFormat.test(clean)&&!forbiddenLink.test(clean);
}
const sampleVars={order_number:'990001 (تجريبي)',customer_name:'عميل تجريبي',driver_name:'موصل تجريبي',delivery_fee:'500'};
function substitute(body,vars){return body.replace(/\{([a-z_]+)\}/g,(_,key)=>Object.hasOwn(vars,key)?String(vars[key]??'—'):'—')}
function preview(){
 const key=q('key').value,original=originalText(key,q('role').value);
 const rich=isGuide(key);q('body').maxLength=rich?1000:180;q('tools').hidden=!rich;q('rich-preview').hidden=!rich;q('preview').parentElement.hidden=rich;
 if(rich){const draft=q('body').value;formatGuide(q('rich-preview'),draft?(validText(draft,key)?draft:'النص غير صالح للمعاينة — أزل الرموز أو الروابط غير المسموح بها.'):'—')}else q('rich-preview').replaceChildren();
 q('vars').hidden=!templates.has(key);
 q('original').textContent=original;
 const binding=additionalContent.find(r=>r.key===key);q('original').parentElement.title=binding?.mode==='protected'||binding?.mode==='guide'?'يبقى النص الرسمي ظاهرًا؛ النص المعدل توضيح إضافي.':'';
 q('preview').textContent=(templates.has(key)?substitute(q('body').value,sampleVars):q('body').value)||'—';
}
function audit(){
 const row=selected();
 q('audit').textContent=row?('الإصدار #'+row.id+' · '+(row.published_at?'منشور':'مسودة')+' · '+new Date(row.created_at).toLocaleString('ar-YE')+' · محرر: '+row.actor_id+(row.published_by?' · نشر: '+row.published_by:'')):'لا يوجد إصدار محدد';
 q('publish').disabled=busy||!row||!!row.published_at;q('load').disabled=busy||!row;
}
function controls(){
 for(const name of ['search','screen','key','role','branch','body','history','history-role','history-branch','bold','bullet'])q(name).disabled=busy;
 for(const name of ['save','restore'])q(name).disabled=busy||!q('key').value;
 audit();
}
function setKeys(){
 const normalize=s=>String(s).normalize('NFKC').replace(/[َ-ْـ]/g,'').replace(/[أإآ]/g,'ا').trim().toLocaleLowerCase('ar');
 const term=normalize(q('search').value),old=q('key').value,screen=q('screen').value;
 const rows=catalog.filter(x=>(!screen||x.screen===screen)&&normalize([x.key,x.screen,x.label,x.original,screens[x.screen]||x.screen].join(' ')).includes(term));
 q('key').replaceChildren(...rows.map(x=>new Option(x.label+' — '+(screens[x.screen]||x.screen),x.key)));
 if(rows.some(x=>x.key===old))q('key').value=old;
}
async function getHistory(token,selectId){
 const key=q('key').value,who=actor(),role=q('history-role').value,branchFilter=q('history-branch').value;history=[];q('history').replaceChildren();controls();
 if(!key)return;
 const rows=role||branchFilter?await rpc('ff86_content_history_scoped',{p_key:key,p_role:role||null,p_branch:branchFilter==='__global__'?null:branchFilter||null,p_global_branch:branchFilter==='__global__'}):await rpc('ff_content_history',{p_key:key});
 if(token!==session||who!==actor()||!manager()||q('key').value!==key||q('history-role').value!==role||q('history-branch').value!==branchFilter)return;
 history=rows||[];
 q('history').replaceChildren(...history.map(r=>new Option('#'+r.id+' · '+(r.published_at?'منشور':'مسودة')+' · '+roles[r.role_scope]+' · '+(r.branch_id?(data.branches||[]).find(b=>b.id===r.branch_id)?.name||'فرع محدد':'كل الفروع'),String(r.id))));
 if(selectId&&history.some(r=>String(r.id)===String(selectId)))q('history').value=String(selectId);controls();
}
async function run(action){
 if(!manager()||busy)return;const token=session,who=actor();busy=true;controls();
 try{await action(token,who)}catch(e){if(token===session&&who===actor())q('status').textContent=e.message||'تعذر تنفيذ الإجراء'}
 finally{if(token===session&&who===actor()){busy=false;controls()}}
}
async function open(selection={}){
 if(!manager()||dialog.open)return;
 session++;busy=false;catalog=[];history=[];q('search').value='';q('body').value='';q('status').textContent='';q('key').replaceChildren();q('history').replaceChildren();
 q('role').replaceChildren(...Object.entries(roles).map(([k,v])=>new Option(v,k)));
 q('branch').replaceChildren(new Option('كل الفروع',''),...(data.branches||[]).map(b=>new Option(b.name,b.id)));
 q('screen').replaceChildren(new Option('كل الواجهات',''));
 q('history-role').replaceChildren(new Option('جميع نطاقات الأدوار',''),...Object.entries(roles).map(([k,v])=>new Option(v,k)));
 q('history-branch').replaceChildren(new Option('جميع نطاقات الفروع',''),new Option('عام دون فرع','__global__'),...(data.branches||[]).map(b=>new Option(b.name,b.id)));
 dialog.showModal();controls();
 await run(async(token,who)=>{
  const rows=await rpc('ff_content_catalog_list');
  if(token!==session||who!==actor()||!manager())return;
  catalog=(rows||[]).filter(r=>known(r.key));q('screen').replaceChildren(new Option('كل الواجهات',''),...[...new Set(catalog.map(r=>r.screen))].map(k=>new Option(screens[k]||k,k)));setKeys();const chosen=catalog.find(r=>r.key===selection?.key);if(chosen){q('screen').value=chosen.screen;setKeys();q('key').value=chosen.key;if(Object.hasOwn(roles,selection.role))q('role').value=selection.role;if([...q('branch').options].some(o=>o.value===selection.branch))q('branch').value=selection.branch;q('history-role').value=q('role').value;q('history-branch').value=q('branch').value||'__global__'}preview();await getHistory(token);
 });
}
function selectKey(){q('body').value='';preview();void run(token=>getHistory(token))}
let searchTimer;q('search').oninput=()=>{clearTimeout(searchTimer);const token=session;searchTimer=setTimeout(()=>{if(token!==session||!dialog.open||busy)return;const old=q('key').value;setKeys();if(old!==q('key').value)selectKey();else controls()},220)};
function insertFormat(prefix,suffix){
 const area=q('body');if(busy||!isGuide(q('key').value))return;
 const from=area.selectionStart,to=area.selectionEnd,chosen=area.value.slice(from,to)||'نص';
 const before=area.value.slice(0,from),after=area.value.slice(to);
 const next=before+prefix+chosen+suffix+after;if(next.length>1000)return;
 area.value=next;area.focus();area.setSelectionRange(from+prefix.length,from+prefix.length+chosen.length);preview()
}
q('bold').onclick=()=>insertFormat('**','**');
q('bullet').onclick=()=>insertFormat(q('body').selectionStart===0||q('body').value[q('body').selectionStart-1]==='\n'?'- ':'\n- ','');
q('screen').onchange=()=>{setKeys();selectKey()};q('history-role').onchange=q('history-branch').onchange=()=>void run(token=>getHistory(token));
q('key').onchange=selectKey;q('role').onchange=preview;q('body').oninput=preview;q('history').onchange=audit;
q('load').onclick=()=>{const row=selected();if(!row)return;q('role').value=row.role_scope;q('branch').value=row.branch_id||'';q('body').value=row.body??originalText(row.content_key,row.role_scope);preview()};
async function draft(restore){
 const key=q('key').value,role=q('role').value,b=q('branch').value||null,body=restore?null:q('body').value.trim();
 if(!key||(!restore&&!validText(body,key))){q('status').textContent='أدخل نصاً آمناً دون رموز برمجية أو روابط غير معتمدة';return}
 await run(async(token,who)=>{
  const id=await rpc('ff_content_create_draft',{p_key:key,p_role:role,p_branch:b,p_body:body});
  if(token!==session||who!==actor()||!manager())return;
  if(!Number.isSafeInteger(Number(id))||Number(id)<=0)throw Error('لم يحفظ الخادم المسودة؛ تحقق من الصلاحية');
  q('history-role').value=role;q('history-branch').value=b||'__global__';
  await getHistory(token,id);if(token===session&&who===actor())q('status').textContent='حُفظت المسودة #'+id+'؛ لم تُنشر بعد.';
 });
}
q('save').onclick=()=>void draft(false);q('restore').onclick=()=>void draft(true);
q('publish').onclick=()=>void run(async(token,who)=>{
 const row=selected();if(!row||row.published_at)return;
 const scope=roles[row.role_scope]+' · '+(row.branch_id?(data.branches||[]).find(b=>b.id===row.branch_id)?.name||'فرع محدد':'كل الفروع');
 if(!confirm('نشر النص المحدد #'+row.id+'؟\n'+scope+'\n'+(row.body??'استعادة النص الأصلي')))return;
 await rpc('ff_content_publish',{p_id:row.id});
 if(token!==session||who!==actor()||!manager())return;
 await getHistory(token,row.id);if(token===session&&who===actor()&&manager()){if(!history.some(x=>String(x.id)===String(row.id)&&x.published_at))throw Error('لم يثبت نشر الإصدار؛ أعد تحميل السجل');q('status').textContent='تم نشر النص #'+row.id;void sync(true)}
});
q('close').onclick=()=>dialog.close();dialog.onclose=()=>{session++;busy=false;q('rich-preview').replaceChildren();q('body').value=''};
const studio=document.querySelector('#ffStudio form');
if(studio){
 const button=document.createElement('button');button.type='button';button.textContent='استوديو المحتوى والمسميات';button.id='ffContentOpen';
 button.onclick=()=>{if(!manager())return;document.getElementById('ffStudio').close();void open()};studio.prepend(button);
}
window.addEventListener('ff-luxe-session-reset',reset);
function safeValue(v){
 if(v==null)return '—';
 return String(v).replace(new RegExp(forbiddenFormat.source,'gu'),'').replace(/[<>{}]/gu,'').slice(0,120)||'—';
}
function currentText(key,fallback,orderBranch=branch()){
 if(!actor()||context!==[actor(),currentRole(),branch()].join('|')||(branch()&&orderBranch!==branch()))return fallback;
 const body=values.get(key)?.body;return typeof body==='string'&&validText(body,key)?body:fallback;
}
function notice(key,fallback,number,orderBranch){
 if(!templates.has(key)||!actor()||context!==[actor(),currentRole(),branch()].join('|'))return fallback;
 if(branch()&&orderBranch!==branch())return fallback;
 const body=values.get(key)?.body;if(typeof body!=='string'||!validText(body,key))return fallback;
 const safe=/^\d{1,20}$/.test(String(number??''))?String(number):'—';
 const vars={order_number:safe};
 // Customer/driver/fee values are read only from the already-authorized account snapshot.
 // Only the on-screen summary may include them; notification bodies never include private names or fees.
 if(key==='notices.order_summary'&&safe!=='—'&&orderBranch&&['manager','supervisor','customer_service','cashier','driver'].includes(currentRole())){
  const matches=(Array.isArray(data?.orders)?data.orders:[]).filter(o=>String(o.number)===safe&&o.branch_id===orderBranch);
  if(matches.length===1){
   const o=matches[0];vars.driver_name=safeValue(o.driver_name);
   if(['manager','supervisor','customer_service','cashier'].includes(currentRole()))vars.customer_name=safeValue(o.customer_name);
   if(o.delivery_fee!=null&&Number.isFinite(Number(o.delivery_fee))&&Number(o.delivery_fee)>=0)vars.delivery_fee=String(Number(o.delivery_fee));
  }
 }
 return substitute(body,vars);
}
async function reportText(reportBranch){
 const who=actor(),role=currentRole();if(!who)return {};
 try{
  const rows=await rpc('ff_content_effective',{p_branch:reportBranch||null});
  if(actor()!==who||currentRole()!==role)return {};
  return Object.fromEntries((rows||[]).filter(r=>['reports.pdf_title','reports.pdf_note'].includes(r.content_key)&&typeof r.body==='string'&&validText(r.body,r.content_key)).map(r=>[r.content_key,r.body]));
 }catch{return {}}
}
window.ffContentStudio={sync,open,notice,text:currentText,reportText,registry:()=>additionalContent.map(r=>({...r})),validate:validText};
setInterval(()=>{if(actor())void sync()},3000);
})();
