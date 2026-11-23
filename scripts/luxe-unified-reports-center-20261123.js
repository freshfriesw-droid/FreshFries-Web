/* Fresh Fries LUXE — unified, role-scoped reports. 2026-11-23 */
(()=>{
'use strict';
if(window.ffReportsCenterOpen)return;
const $=id=>document.getElementById(id);
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const n=v=>v===null||v===undefined||Number.isNaN(Number(v))?'—':Number(v).toLocaleString('ar-YE',{maximumFractionDigits:2});
const money=v=>v===null||v===undefined?'غير موثّق':n(v)+' ريال';
const pct=(v,d)=>Number(d)>0?n(100*Number(v||0)/d)+'%':'—';
const dt=v=>v?new Date(v).toLocaleString('ar-YE',{timeZone:'Asia/Aden'}):'—';
const date=()=>window.ffF01BusinessDate?.()||(()=>{const p=new Intl.DateTimeFormat('en-GB',{timeZone:'Asia/Aden',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date());const val=k=>p.find(x=>x.type===k)?.value;return val('year')+'-'+val('month')+'-'+val('day')})();
const previous=(d,n)=>{const v=new Date(d+'T12:00:00Z');v.setUTCDate(v.getUTCDate()-n);return v.toISOString().slice(0,10)};
const uid=()=>typeof user!=='undefined'&&user?.id?String(user.id):'';
const role=()=>window.ffBurgerActive?.()?'burger_kitchen':(typeof data!=='undefined'&&data?.role)||'';
const permission={manager:['overview','finance','charts','branches','orders','drivers','staff','items','customers','ratings','cases','kitchen','rewards','settlements','notes','advice'],
supervisor:['overview','finance','charts','branches','orders','drivers','staff','items','customers','ratings','cases','kitchen','advice'],
customer_service:['overview','charts','branches','orders','drivers','staff','items','customers','ratings','cases','kitchen','advice'],
cashier:['overview','charts','orders','staff','items'],
driver:['overview','drivers','ratings'],
assembly:['overview','orders'],
burger_kitchen:['overview','kitchen']};
const names={overview:'الملخص اليومي',finance:'الإيرادات والخصومات',charts:'الرسوم البيانية',branches:'مقارنة الفروع',orders:'الطلبات والإلغاء والتأخير',drivers:'الموصلون وساعات الدوام',staff:'خدمة العملاء والكاشير',items:'الأصناف الأكثر مبيعًا',customers:'العملاء ومناطق التوصيل',ratings:'التقييمات والجودة',cases:'الشكاوى والتظلمات',kitchen:'مطبخ البرجر',rewards:'أكواد التعويض والضيافة',settlements:'التسويات النقدية',notes:'ملاحظات واعتماد المدير',advice:'تحليل الإدارة والتوصيات'};
const allowed=()=>permission[role()]||[];
const auth=()=>Boolean(uid())&&allowed().length>0;
const dialog=document.createElement('dialog');dialog.id='ffr-center';dialog.dir='rtl';
dialog.innerHTML='<div class="ffr-title"><div><h2>📊 مركز التقارير والتحليلات — فريش فرايز</h2><p id="ffr-scope">تقارير مخصصة حسب الصلاحية</p></div><button type="button" id="ffr-close">✕ إغلاق</button></div>'+
'<div class="ffr-filters"><label>من تاريخ<input type="date" id="ffr-from"></label><label>إلى تاريخ<input type="date" id="ffr-to"></label>'+
'<label>الفرع<select id="ffr-branch"><option value="">كل الفروع المسموح بها</option></select></label>'+
'<label id="ffr-driver-field">الموصل<select id="ffr-driver"><option value="">جميع الموصلين</option></select></label>'+
'<button type="button" id="ffr-today">اليوم</button><button type="button" id="ffr-week">7 أيام</button>'+
'<button type="button" id="ffr-month">30 يومًا</button><button type="button" class="ffr-primary" id="ffr-run">إعداد التقرير</button></div>'+
'<div class="ffr-filters ffr-options"><label>محتوى التقرير<select id="ffr-mode">'+
'<option value="all">شامل — جميع أقسام حسابك</option><option value="one">القسم الحالي فقط</option><option value="custom">تحديد أقسام معينة</option></select></label>'+
'<button type="button" class="ffr-primary" id="ffr-preview">👁️ معاينة قبل الإرسال</button>'+
'<button type="button" id="ffr-csv">📥 CSV</button><button type="button" id="ffr-share">↗ مشاركة خارجية</button></div>'+
'<details id="ffr-custom" hidden><summary>اختر الأقسام التي تريد تضمينها بالتقرير</summary><div id="ffr-checks" class="ffr-checks"></div></details>'+
'<p id="ffr-status" role="status" aria-live="polite"></p><div id="ffr-tabs" class="ffr-tabs"></div>'+
'<article id="ffr-content" class="ffr-section"></article>';
document.body.append(dialog);
const preview=document.createElement('dialog');preview.dir='rtl';preview.id='ffr-preview-dialog';
preview.innerHTML='<div class="ffr-title"><h2>معاينة التقرير الكامل</h2><div class="ffr-actions">'+
'<button type="button" class="ffr-primary" id="ffr-print">🖨️ حفظ PDF / طباعة</button>'+
'<button type="button" id="ffr-preview-share">↗ مشاركة الملخص</button><button type="button" id="ffr-preview-close">إغلاق</button></div></div>'+
'<div class="ffr-help">راجع التقرير هنا قبل الطباعة. اختر «حفظ كملف PDF» من نافذة طباعة الهاتف، ثم شاركه كملف على واتساب؛ المشاركة المباشرة تنقل ملخصًا نصيًا.</div>'+
'<div id="ffr-preview-document"></div>';
document.body.append(preview);
const st=document.createElement('style');st.textContent=[
'#ffr-center,#ffr-preview-dialog{box-sizing:border-box;width:min(97vw,1250px);max-width:1250px;max-height:96vh;overflow:auto;border:2px solid #c5263c;border-radius:16px;padding:15px;background:#fff;color:#1b1b1b;font:14px Tahoma,Arial,sans-serif;direction:rtl;box-shadow:0 20px 70px #0007}',
'#ffr-preview-dialog{max-width:880px}#ffr-center::backdrop,#ffr-preview-dialog::backdrop{background:#000b}',
'#ffr-center *,#ffr-preview-dialog *{box-sizing:border-box}.ffr-title{display:flex;align-items:start;justify-content:space-between;gap:12px;border-bottom:3px solid #c5263c;padding-bottom:10px;flex-wrap:wrap}',
'.ffr-title h2{font-size:clamp(17px,3vw,25px);margin:5px 0;color:#b31a33}.ffr-title p{color:#666;margin:4px 0}',
'.ffr-filters{display:flex;flex-wrap:wrap;gap:8px;align-items:end;margin:12px 0}.ffr-filters label{display:grid;gap:5px;min-width:135px;flex:1 1 165px;font-weight:bold}',
'.ffr-filters input,.ffr-filters select{width:100%;padding:9px;min-height:42px;border:1px solid #aaa;border-radius:9px;background:white;color:black}',
'#ffr-center button,#ffr-preview-dialog button{min-height:41px;padding:7px 12px;border-radius:8px;border:1px solid #bd263b;background:#fff;color:#9a1529;font-weight:800;cursor:pointer}',
'#ffr-center .ffr-primary,#ffr-preview-dialog .ffr-primary{background:#c7253b;color:#fff}#ffr-center button:disabled{opacity:.5}',
'.ffr-options{background:#f7f7f7;padding:9px;border-radius:12px}.ffr-tabs{display:flex;overflow-x:auto;gap:7px;padding:12px 0;border-bottom:1px solid #ddd}',
'.ffr-tabs button{white-space:nowrap;flex:none}.ffr-tabs .on{background:#c7253b!important;color:white!important}',
'.ffr-checks{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:10px;padding:10px}.ffr-checks label{display:flex;gap:8px;align-items:center}',
'.ffr-section h3{color:#a7152e;font-size:20px;margin:15px 0 7px}.ffr-section h4{font-size:16px;margin:12px 0}',
'.ffr-tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:9px;margin:12px 0}.ffr-tile{background:#fff8f9;border:1px solid #ddd;border-right:4px solid #cf2b40;border-radius:10px;padding:12px}',
'.ffr-tile small{display:block;color:#666}.ffr-tile b{display:block;font-size:20px;margin:8px 0;overflow-wrap:anywhere}',
'.ffr-table-wrap{overflow-x:auto}.ffr-table{border-collapse:collapse;width:100%;font-size:12px;margin:8px 0}.ffr-table th,.ffr-table td{padding:10px 8px;border-bottom:1px solid #ddd;text-align:right;overflow-wrap:anywhere}',
'.ffr-table th{background:#222;color:white;white-space:nowrap}.ffr-table tr:nth-child(even){background:#f6f6f6}',
'.ffr-help,.ffr-warn{padding:10px;margin:10px 0;line-height:1.8;border-radius:9px}.ffr-help{background:#eff5ff;color:#244260}.ffr-warn{background:#fff3e8;color:#812d19;border:1px solid #e7ad7d}',
'.ffr-bars{display:grid;gap:8px}.ffr-bar{display:grid;grid-template-columns:100px minmax(100px,1fr) 75px;gap:8px;align-items:center;font-size:12px}.ffr-bar-track{height:19px;border-radius:9px;background:#eee;overflow:hidden}.ffr-bar-fill{height:100%;background:#cb2840;border-radius:9px}',
'.ffr-paper{background:#fff;color:#111;padding:17px;max-width:850px;margin:auto}.ffr-paper h1{color:#b71d32;border-bottom:3px solid #be213b;padding-bottom:10px}.ffr-stamp{border:2px dashed #ba3648;padding:12px;text-align:center;margin:15px 0}.ffr-foot{font-size:11px;color:#666}',
'.ffr-notes label{display:grid;gap:6px;margin:9px 0}.ffr-notes input,.ffr-notes textarea{padding:9px;border:1px solid #aaa;border-radius:9px;width:100%}.ffr-actions{display:flex;gap:7px;flex-wrap:wrap}',
'@media(max-width:590px){#ffr-center,#ffr-preview-dialog{width:99vw;max-height:99vh;padding:10px}.ffr-tiles{grid-template-columns:repeat(2,minmax(0,1fr))}.ffr-tile b{font-size:17px}.ffr-bar{grid-template-columns:78px minmax(80px,1fr) 65px}}'
].join('\n');document.head.append(st);
let report=null,reportAt='',active='overview',actor='',busy=false,serial=0;
const from=$('ffr-from'),to=$('ffr-to'),branch=$('ffr-branch'),driver=$('ffr-driver');from.value=to.value=date();
const empty='<p class="ffr-help">لا تتوفر سجلات موثقة لهذا القسم في الفترة المختارة.</p>';
function branchName(id){return (typeof data!=='undefined'&&data?.branches||[]).find(x=>x.id===id)?.name||'فرع مسجل'}
function stats(rows){return '<div class="ffr-tiles">'+rows.map(x=>'<div class="ffr-tile"><small>'+esc(x[0])+'</small><b>'+esc(x[1])+'</b></div>').join('')+'</div>'}
function table(rows,columns){
 if(!rows?.length)return empty;
 return '<div class="ffr-table-wrap"><table class="ffr-table"><thead><tr>'+columns.map(c=>'<th>'+esc(c[0])+'</th>').join('')+
 '</tr></thead><tbody>'+rows.map(r=>'<tr>'+columns.map(c=>'<td>'+esc(typeof c[1]==='function'?c[1](r):r[c[1]]??'—')+'</td>').join('')+'</tr>').join('')+'</tbody></table></div>';
}
function bars(rows,key,field,title){
 if(!rows?.length)return empty;
 const max=Math.max(1,...rows.map(x=>Number(x[key])||0));
 return '<h4>'+esc(title)+'</h4><div class="ffr-bars">'+rows.map(x=>'<div class="ffr-bar"><span>'+
 esc(typeof field==='function'?field(x):x[field])+'</span><div class="ffr-bar-track"><div class="ffr-bar-fill" style="width:'+
 Math.max(1,Math.round((Number(x[key])||0)/max*100))+'%"></div></div><strong>'+n(x[key])+'</strong></div>').join('')+'</div>';
}
function section(key,r){
 const t=r.totals||{},R=x=>Array.isArray(x)?x:[],p=r.previous_comparison||[];
 const d=p.find(x=>x.day===r.meta.to),prev=p.find(x=>x.day===previous(r.meta.to,1)),week=p.find(x=>x.day===previous(r.meta.to,7));
 if(key==='overview'){
  if(role()==='burger_kitchen')return stats([['إشعارات البرجر',n(R(r.kitchen).reduce((a,x)=>a+Number(x.sent||0),0))],
   ['منتهية',n(R(r.kitchen).reduce((a,x)=>a+Number(x.finished||0),0))],['متوسط التحضير',r.kitchen?.[0]?.avg_prep_minutes==null?'—':n(r.kitchen[0].avg_prep_minutes)+' دقيقة']]);
  return stats([['إجمالي الطلبات',n(t.orders)],['المسلّمة',n(t.delivered)],['الملغاة',n(t.cancelled)],['الجارية',n(t.in_progress)],
    ['معدل الإلغاء',pct(t.cancelled,t.orders)],['متوسط زمن الرحلة',t.avg_trip_minutes==null?'—':n(t.avg_trip_minutes)+' دقيقة'],
    ['قيمة الطلبات المسلّمة',money(t.invoice_value)],['توصيل مجاني',n(t.free_delivery)]])+
   '<h4>مقارنة آخر يوم تشغيلي</h4>'+stats([['اليوم '+r.meta.to,n(d?.orders||0)],
   ['اليوم السابق',n(prev?.orders||0)],['نفس يوم الأسبوع الماضي',n(week?.orders||0)]])+
   '<p class="ffr-help">يبدأ اليوم التشغيلي الساعة 8 صباحًا؛ طلبات 12–2 بعد منتصف الليل تتبع اليوم السابق، و2–8 صباحًا مسجلة كحالات خارج الدوام دون حذفها.</p>';
 }
 if(key==='finance')return stats([['مبيعات الأصناف في المسلّمة',money(t.items_sales)],
  ['رسوم التوصيل',money(t.delivery_fees)],['الإضافات المفوترة',money(t.invoiced_additions)],
  ['إجمالي الفواتير المسلّمة',money(Number(t.invoice_value||0)+Number(t.invoiced_additions||0))],
  ['الخصومات الفعلية',money(t.recorded_discounts)],['صافي المبيعات بعد الخصومات',money(t.net_after_discounts)],
  ['صافي الربح',money(t.net_profit)],['متوسط الفاتورة',money(t.average_order_value)]])+
  '<p class="ffr-warn">لا تتوفر حقول موثوقة لخصومات الطلبات الفعلية أو تكلفة المخزون، ولذلك لا نعرض صفرًا مضللًا كصافي خصم أو ربح. المبالغ اليدوية في ملاحظات المدير ليست قيودًا محاسبية.</p>';
 if(key==='charts')return bars(R(r.daily),'delivered_value','day','قيمة الفواتير المسلّمة يوميًا')+
  bars(R(r.weekly),'value','week','مقارنة أسابيع الفترة')+bars(R(r.monthly),'value','month','مقارنة أشهر الفترة')+
  bars(R(r.hours),'orders',x=>x.hour_of_day+':00','أوقات الذروة حسب الساعة');
 if(key==='branches')return bars(R(r.branches),'delivered','branch_name','مقارنة الطلبات المسلّمة')+
  table(R(r.branches),[['الفرع','branch_name'],['الطلبات','orders'],['المسلّمة','delivered'],['الملغاة','cancelled'],
  ['قيمة الفواتير',x=>money(x.invoice_value)],['متوسط الطلب',x=>money(x.avg_order_value)],['التوصيل',x=>money(x.delivery_fees)]])+
  '<h4>مقارنة كل فرع بآخر يوم وأمس ونفس يوم الأسبوع الماضي</h4>'+
  table(R(r.branch_comparison),[['الفرع','branch_name'],['تاريخ اليومية','day'],['الطلبات','orders'],['المسلّمة','delivered'],['قيمة المسلّمة',x=>money(x.value)]]);
 if(key==='orders')return stats([['الطلبات',n(t.orders)],['المنجزة',n(t.delivered)],['الملغاة',n(t.cancelled)],
  ['تأخر في الرحلة (> 40 دقيقة)',n(t.delayed_delivered)],['متأخر حاليًا',n(t.currently_late)],
  ['توصيل مجاني',n(t.free_delivery)],['خارج الدوام',n(t.out_of_hours)],['الطلبات المؤجلة',t.deferred_orders==null?'غير مصنفة':n(t.deferred_orders)],
  ['أسرع طلب',r.fastest_order?'#'+r.fastest_order.order_number+' — '+n(r.fastest_order.minutes)+' دقيقة':'—']])+
  '<h4>إلغاءات الطلبات وأسبابها</h4>'+
  table(R(r.cancellations),[['رقم الطلب','order_number'],['الفرع',x=>branchName(x.branch_id)],['السبب','reason'],['وقت الطلب',x=>dt(x.created_at)]])+
  '<p class="ffr-help">عتبة التأخير الحالية في التحليل 40 دقيقة بعد انطلاق الموصل. «الطلبات المؤجلة» تحتاج حالة معتمدة مستقلة في النظام لتظهر كمؤشر دقيق.</p>';
 if(key==='drivers'){
  const rows=R(r.drivers),fast=[...rows].filter(x=>x.avg_trip_minutes!=null&&x.delivered>0).sort((a,b)=>a.avg_trip_minutes-b.avg_trip_minutes)[0],
   top=[...rows].filter(x=>x.average_rating!=null).sort((a,b)=>b.average_rating-a.average_rating)[0],
   most=[...rows].sort((a,b)=>b.delivered-a.delivered)[0];
  const mostDeliveries=Math.max(1,...rows.map(x=>Number(x.delivered||0)));
  const mostHours=Math.max(1,...rows.map(x=>Number(x.work_hours||0)));
  const ranked=rows.filter(x=>Number(x.trip_sample)>=3&&Number(x.rating_count)>=3&&
    Number(x.sessions)>=1&&x.work_hours!=null&&!x.partial_attendance).map(x=>({
    ...x,score:35*(Number(x.on_time)/Number(x.trip_sample))+
    30*(Number(x.average_rating)/5)+20*(Number(x.delivered)/mostDeliveries)+
    15*(Number(x.work_hours)/mostHours)
  })).sort((a,b)=>b.score-a.score);
  const best=ranked[0];
  return stats([['أفضل أداء مركب',best?best.name+' — '+n(best.score)+'/100':'بانتظار بيانات كافية'],
   ['أسرع متوسط رحلة',fast?fast.name+' · '+n(fast.avg_trip_minutes)+' دقيقة':'—'],
   ['أعلى تقييم',top?top.name+' ⭐ '+n(top.average_rating):'—'],['أكثر طلبات مسلّمة',most?most.name+' · '+n(most.delivered):'—']])+
   table(rows,[['الموصل','name'],['الفرع','branch_name'],['المسندة','assigned'],['المنجزة','delivered'],
    ['قيمة الفواتير',x=>money(x.invoice_value)],['رسوم التوصيل',x=>money(x.delivery_fees)],
    ['متوسط الرحلة',x=>x.avg_trip_minutes==null?'—':n(x.avg_trip_minutes)+' دقيقة'],
    ['الالتزام 40 د',x=>pct(x.on_time,x.trip_sample)],
    ['النجوم',x=>x.average_rating==null?'—':n(x.average_rating)+' /5 ('+x.rating_count+')'],
    ['ساعات الدوام الصافية',x=>x.work_hours==null?'غير مسجلة':n(x.work_hours)+' س'],
    ['ساعات الاستراحة',x=>x.break_hours==null?'—':n(x.break_hours)+' س'],
    ['جلسات الحضور','sessions'],['أول حضور',x=>dt(x.first_attendance)],['آخر نشاط',x=>dt(x.last_attendance)]])+
   '<p class="ffr-help">مؤشر الأداء المركب استرشادي: 35% التزام زمن الرحلة، 30% التقييم، 20% عدد التوصيلات، 15% ساعات الدوام الصافية. يتطلب 3 رحلات، و3 تقييمات وجلسة دوام موثقة كاملة.</p>'+
   '<p class="ffr-warn">يتوقف احتساب الدوام أثناء الاستراحة، وتُجمع مرات الحضور بنفس اليومية، لكن جلسات ما قبل تفعيل هذا السجل لا يمكن استرجاع بدايتها بدقة. ترتيب أفضل موصل استرشادي حتى تتوفر عينات كافية من التقييمات والحضور.</p>';
 }
 if(key==='staff')return '<h4>عمل موظفي خدمة العملاء</h4>'+
   table(R(r.customer_service),[['الموظف','employee'],['الطلبات المسجلة','orders'],['المنجزة','delivered'],['الملغاة','cancelled']])+
   '<h4>أداء الكاشير والفواتير</h4>'+
   table(R(r.cashiers),[['الموظف','employee'],['مستلمة / مفوترة','orders'],['مفوترة','invoiced'],['بدون رقم','missing_invoice']])+
   '<p class="ffr-help">الطلبات تُنسب لصاحب حساب إنشاء الطلب، والفواتير إلى الكاشير في سجل الفوترة، دون تخمين موظف للطلبات التاريخية غير المنسوبة.</p>';
 if(key==='items')return table(R(r.items),[['الصنف','name'],['الكمية',x=>n(x.qty)],['الإيراد',x=>money(x.revenue)]])+
   '<p class="ffr-help">يشمل الأصناف في الطلبات المسلّمة والإضافات المفوترة، دون احتساب تكلفة المكونات.</p>';
 if(key==='customers')return stats([['عملاء أول مرة',n(r.new_counts?.new_customers)],['مناطق أول مرة',n(r.new_counts?.new_areas)],
   ['عملاء مميزون خلال الفترة',n(r.new_counts?.total_unique_customers)]])+
   '<h4>تحليل مناطق التوصيل</h4>'+table(R(r.areas),[['المنطقة','area'],['الطلبات','orders'],['العملاء','customers'],
    ['طلبات في مناطق جديدة','new_area_orders'],['متوسط فاتورة',x=>money(x.avg_order)]])+
   '<h4>العملاء المتكررون</h4>'+table(R(r.customers),[['العميل','customer_name'],['رقم الهاتف المخوّل','phone'],
    ['عدد الطلبات','orders'],['قيمة المسلّمة',x=>money(x.delivered_value)]])+
   '<p class="ffr-help">«أول مرة» يقصد بها أول ظهور في سجلات الطلبات الحالية، ولا يُحتسب تاريخ تعامل العميل قبل وجود النظام. يجب توحيد أسماء المناطق لتجنب التكرار.</p>';
 if(key==='ratings'){
  const low=R(r.ratings).filter(x=>x.stars<=2),hi=[...R(r.ratings)].sort((a,b)=>b.stars-a.stars).slice(0,12);
  return stats([['تقييمات موصلين منخفضة',n(low.length)],['تقييمات طلبات منخفضة',n(R(r.order_ratings).filter(x=>x.rating<=2).length)],
   ['أعلى تقييم',hi.length?n(hi[0].stars)+' / 5':'—'],
   ['أدنى تقييم',r.ratings?.length?n(r.ratings[0].stars)+' / 5':'—']])+
   '<h4>ملاحظات التقييمات المنخفضة</h4>'+
   table(low,[['الموصل','driver_name'],['رقم الطلب','order_number'],['التقييم','stars'],['الملاحظات',x=>x.note||'بدون ملاحظات'],['الوقت',x=>dt(x.rated_at)]])+
   '<h4>تقييمات العملاء للطلبات</h4>'+
   table(R(r.order_ratings),[['الطلب','order_number'],['الفرع',x=>branchName(x.branch_id)],['التقييم','rating'],['ملاحظة العميل',x=>x.rating_note||'—']])+
   '<h4>أعلى تقييمات الموصلين</h4>'+table(hi,[['الموصل','driver_name'],['النجوم','stars'],['الملاحظة',x=>x.note||'—']])+
   (r.quality_detail?'<h4>الجودة والفوترة — للمدير</h4>'+stats([['الفواتير الموثقة',n(r.quality_detail.documented)],['الفواتير دون رقم',n(r.quality_detail.undocumented)],['التقييمات المنخفضة',n(r.quality_detail.low)],['متوسط تقييم العميل',n(r.quality_detail.average)],['النقد في تسويات مقفلة',money(r.quality_detail.confirmed_cash)]]):'');
 }
 if(key==='cases'){
  const cs=R(r.cases),cols=[['الطلب',x=>x.order_number||'غير مرتبط'],['الفرع',x=>branchName(x.branch_id)],['الموضوع','subject'],
   ['التفاصيل','description'],['الحالة','status'],['الرد',x=>x.resolution||'—'],['التاريخ',x=>dt(x.created_at)]];
  return stats([['الشكاوى',n(cs.filter(x=>x.kind==='customer_complaint').length)],
   ['التظلمات',n(cs.filter(x=>x.kind==='staff_grievance').length)],
   ['بانتظار الإغلاق',n(cs.filter(x=>!['closed','resolved'].includes(x.status)).length)]])+
   '<h4>شكاوى الطلبات</h4>'+table(cs.filter(x=>x.kind==='customer_complaint'&&x.order_number),cols)+
   '<h4>شكاوى أخرى</h4>'+table(cs.filter(x=>x.kind==='customer_complaint'&&!x.order_number),cols)+
   '<h4>تظلمات الموصلين والموظفين</h4>'+table(cs.filter(x=>x.kind==='staff_grievance'),cols);
 }
 if(key==='kitchen')return stats([['إشعارات البرجر',n(R(r.kitchen).reduce((a,x)=>a+Number(x.sent),0))],
   ['منتهية',n(R(r.kitchen).reduce((a,x)=>a+Number(x.finished),0))],
   ['ملاحظات مؤكد تنفيذها',n(R(r.kitchen).reduce((a,x)=>a+Number(x.confirmed_notes),0))]])+
  table(R(r.kitchen),[['الفرع','branch_name'],['مرسلة','sent'],['منتهية','finished'],['ذات ملاحظات','with_notes'],
   ['ملاحظات منفّذة','confirmed_notes'],['متوسط التحضير',x=>x.avg_prep_minutes==null?'—':n(x.avg_prep_minutes)+' دقيقة'],
   ['أسرع تحضير',x=>x.fastest_prep_minutes==null?'—':n(x.fastest_prep_minutes)+' دقيقة']])+
  '<h4>أداء موظفي قسم البرجر</h4>'+table(R(r.kitchen_staff),[['الموظف','employee'],['الفرع',x=>branchName(x.branch_id)],['المستلمة','received'],['المنتهية','finished'],['ملاحظات مؤكد تنفيذها','confirmed_notes'],['متوسط التحضير',x=>x.avg_prep_minutes==null?'—':n(x.avg_prep_minutes)+' دقيقة']]);
 if(key==='rewards')return stats([['الأكواد الصادرة خلال الفترة',n(R(r.rewards).length)],
   ['المستهلكة',n(R(r.rewards).filter(x=>x.status==='redeemed').length)]])+
  table(R(r.rewards),[['الكود','code'],['النوع','kind'],['العميل','recipient_name'],['آخر الهاتف','phone_suffix'],
   ['الأصناف',x=>R(x.items).map(y=>y.qty+' × '+y.name).join('، ')],['الحالة','status'],
   ['تاريخ الإصدار',x=>dt(x.issued_at)],['الاستهلاك',x=>dt(x.redeemed_at)]]);
 if(key==='settlements')return stats([['عدد التسويات',n(r.settlement_detail?.totals?.settlements)],['عدد الطلبات المسلّمة',n(r.settlement_detail?.totals?.delivered_orders)],['النقد المطلوب',money(r.settlement_detail?.totals?.cash_due)],['النقد المستلم',money(r.settlement_detail?.totals?.cash_received)]])+
  '<h4>التسويات المقفلة والمسودات خلال الفترة</h4>'+table(R(r.settlement_detail?.rows),[['اليوم','day'],['الفرع','branch'],['المسلّمة','delivered_orders'],['قيمة الفواتير',x=>money(x.delivered_value)],['التسويات','settlements'],['المطلوب',x=>money(x.cash_due)],['المستلم',x=>money(x.cash_received)],['الفرق',x=>money(x.difference)]])+
  '<p class="ffr-help">الملخص للقراءة فقط؛ التعديل والإقفال من شاشة تسويات الموصلين للمدير.</p>'+
  '<p class="ffr-warn">يظل التقرير التشغيلي هنا قائمًا على تاريخ إنشاء الطلب، بينما التسوية النقدية اليومية تعتمد تاريخ التسليم الفعلي. لا تُجمع المبالغ بينهما دون مطابقة.</p>';
 if(key==='notes'){
  return '<div class="ffr-help">الملاحظات ومبلغ المصاريف اليدوي للتوثيق الإداري فقط. اعتماد التقرير يحفظ اسم المدير ووقت الاعتماد في سجل التدقيق، وليس توقيعًا رقميًا قانونيًا مشفّرًا.</div>'+
  '<div class="ffr-notes"><label>خلاصة المدير والمصاريف والملاحظات<textarea id="ffr-note" rows="4" maxlength="5000"></textarea></label>'+
  '<label>المصاريف المدونة يدويًا (لا تُخصم محاسبيًا)<input id="ffr-expenses" type="number" min="0" max="100000000000" step="0.01"></label>'+
  '<label>اسم المدير المعتمد<input id="ffr-signer" maxlength="120"></label>'+
  '<div class="ffr-actions"><button type="button" id="ffr-save-note">حفظ الملاحظات</button>'+
  '<button type="button" id="ffr-approve-note" class="ffr-primary">✍️ اعتماد وختم التقرير</button></div><p id="ffr-note-message"></p></div>'+
  '<h4>السجل السابق</h4>'+table(R(r.manager_notes),[['اليوم','business_date'],['الفرع',x=>x.branch_id?branchName(x.branch_id):'جميع الفروع'],
   ['الملاحظات','note_text'],['المصاريف اليدوية',x=>money(x.manual_expenses)],
   ['المعتمد',x=>x.approver_name||'غير معتمد'],['وقت الاعتماد',x=>dt(x.approved_at)]]);
 }
 if(key==='advice'){
  const notes=[];if(!t.orders)notes.push('لا توجد طلبات ضمن الفترة المختارة، فلا يمكن الحكم على أداء هذا اليوم.');
  if(t.orders&&t.cancelled/t.orders>.15)notes.push('نسبة الإلغاء تتجاوز 15%؛ يُنصح بتحليل أسباب الإلغاء لكل فرع.');
  if(t.delayed_delivered>0)notes.push('توجد رحلات توصيل متأخرة وفق معيار 40 دقيقة؛ راجع أوقات الذروة.');
  if(t.out_of_hours>0)notes.push('يوجد طلب خارج نافذة الدوام؛ راجع الواقعة في سجل اليومية.');
  if(R(r.ratings).some(x=>x.stars<=2)||R(r.order_ratings).some(x=>x.rating<=2))notes.push('توجد تقييمات منخفضة تستدعي متابعة الشكاوى والملاحظات.');
  if(R(r.cases).some(x=>!['closed','resolved'].includes(x.status)))notes.push('توجد شكاوى أو تظلمات غير مغلقة؛ كلف المسؤول بالمتابعة.');
  if(r.meta?.historical_attendance_incomplete)notes.push('سجلات الدوام قبل بدء هذا الإصدار غير مكتملة؛ لا تعتمد ترتيب الالتزام بساعات الدوام على بيانات تاريخية ناقصة.');
  notes.push('طابق قيمة الفواتير مع تسويات النقد الفعلي؛ لا تعاملها كتحصيل نقدي مؤكَّد.');
  notes.push('صافي الربح والخصومات الحقيقية يحتاجان إلى نظام حسابات ومخزون موثق قبل الاعتماد.');
  return '<h4>توصيات آلية للإدارة والمشرف وخدمة العملاء</h4>'+
   '<div class="ffr-warn">'+notes.map((x,i)=>'<p><b>'+(i+1)+'.</b> '+esc(x)+'</p>').join('')+'</div>'+
   '<p class="ffr-help">هذه استنتاجات استرشادية وليست قرارًا إداريًا أو توقيع اعتماد.</p>';
 }
 return empty;
}
function draw(){
 if(!report||!auth())return;
 const keys=allowed();if(!keys.includes(active))active=keys[0];
 $('ffr-tabs').querySelectorAll('button').forEach(b=>b.classList.toggle('on',b.dataset.part===active));
 $('ffr-content').innerHTML='<h3>'+esc(names[active])+'</h3>'+section(active,report);
 if(active==='notes')setupNotes();
}
function setupNotes(){
 const current=report.manager_notes?.find(x=>x.business_date===report.meta.to&&(x.branch_id||'')===(report.meta.branch_id||''))||{};
 $('ffr-note').value=current.note_text||'';$('ffr-expenses').value=current.manual_expenses??'';$('ffr-signer').value=current.approver_name||'';
 for(const [id,approved] of [['ffr-save-note',false],['ffr-approve-note',true]]){
  $(id).onclick=async()=>{
   const b=$(id);b.disabled=true;const actor=uid();$('ffr-note-message').textContent='جارٍ الحفظ...';
   try{
    const ans=await rpc('ff_report_note_save',{p_day:report.meta.to,p_branch:report.meta.branch_id||null,
     p_note:$('ffr-note').value,p_manual_expenses:$('ffr-expenses').value===''?null:Number($('ffr-expenses').value),
     p_approver:$('ffr-signer').value.trim()||null,p_approve:approved});
    if(uid()!==actor||!ans.saved)return;
    $('ffr-note-message').textContent='✅ حُفظت الملاحظات';await load();
   }catch(e){$('ffr-note-message').textContent='⚠️ '+String(e.message||e)}
   finally{b.disabled=false}
  };
 }
}
function buildTabs(){
 $('ffr-tabs').replaceChildren();$('ffr-checks').replaceChildren();
 for(const key of allowed()){
  const b=document.createElement('button');b.dataset.part=key;b.type='button';b.textContent=names[key];
  b.onclick=()=>{active=key;draw()};$('ffr-tabs').append(b);
  const label=document.createElement('label'),check=document.createElement('input');check.type='checkbox';check.value=key;check.checked=true;
  label.append(check,document.createTextNode(names[key]));$('ffr-checks').append(label);
 }
}
function choices(){
 const id=branch.value;branch.replaceChildren(new Option('كل الفروع المخولة',''));
 for(const b of (typeof data!=='undefined'&&data?.branches||[]))branch.add(new Option(b.name,b.id));
 if(Array.from(branch.options).some(x=>x.value===id))branch.value=id;
 const prior=driver.value;driver.replaceChildren(new Option('جميع الموصلين',''));
 $('ffr-driver-field').hidden=!['manager','supervisor'].includes(role());
 if(['manager','supervisor'].includes(role()))for(const d of (typeof data!=='undefined'&&data?.drivers||[])){
  if(branch.value&&branch.value!==d.branch_id)continue;
  driver.add(new Option(d.name,d.id));
 }
 if(Array.from(driver.options).some(x=>x.value===prior))driver.value=prior;
}
function open(){
 if(!auth())return;
 if(actor!==uid()){actor=uid();report=null;from.value=to.value=date();active='overview'}
 from.max=to.max=date();choices();buildTabs();
 $('ffr-scope').textContent='صلاحية '+role()+' · يبدأ اليوم التشغيلي 8 صباحًا، وتتبع طلبات ما بعد منتصف الليل اليوم السابق';
 if(!dialog.open)dialog.showModal();if(!report)void load();else draw();
}
window.ffReportsCenterOpen=open;
$('ff40ReportsBtn')?.addEventListener('click',e=>{if(auth()){e.preventDefault();e.stopImmediatePropagation();open()}},true);
$('ffr-close')?.addEventListener('click',()=>{if(preview.open)preview.close()});
$('ffr-close').onclick=()=>dialog.close();$('ffr-preview-close').onclick=()=>preview.close();
$('ffr-today').onclick=()=>{from.value=to.value=date();void load()};
$('ffr-week').onclick=()=>{to.value=date();from.value=previous(to.value,6);void load()};
$('ffr-month').onclick=()=>{to.value=date();from.value=previous(to.value,29);void load()};
$('ffr-run').onclick=()=>void load();
branch.onchange=()=>{driver.value='';choices()};
$('ffr-mode').onchange=()=>{$('ffr-custom').hidden=$('ffr-mode').value!=='custom'};
function chosen(){const mode=$('ffr-mode').value;return mode==='one'?[active]:mode==='custom'?
 Array.from($('ffr-checks').querySelectorAll('input:checked')).map(x=>x.value):allowed()}
async function load(){
 if(!auth()||busy)return;
 if(!from.value||!to.value||from.value>to.value||to.value>date()){ $('ffr-status').textContent='فترة غير صالحة';return}
 const who=uid(),whichRole=role(),revision=++serial;busy=true;$('ffr-run').disabled=true;
 $('ffr-status').textContent='جارٍ احتساب النتائج من Supabase...';
 try{
  const response=await rpc('ff_reports_center',{p_from:from.value,p_to:to.value,p_branch:branch.value||null,p_driver:driver.value||null});
  if(serial!==revision||uid()!==who||role()!==whichRole)return;
  if(!response?.meta||!response?.totals)throw Error('بيانات التقرير غير مكتملة');
  if(whichRole==='manager'){
    const [settlements,quality]=await Promise.allSettled([
      rpc('ff_luxe_settlement_period',{p_from:from.value,p_to:to.value,p_branch:branch.value||null}),
      rpc('ff27_quality',{p_from:from.value,p_to:to.value,p_branch:branch.value||null})
    ]);
    if(serial!==revision||uid()!==who||role()!==whichRole)return;
    response.settlement_detail=settlements.status==='fulfilled'?settlements.value:null;
    response.quality_detail=quality.status==='fulfilled'?quality.value:null;
  }
  report=response;reportAt=new Date().toISOString();$('ffr-status').textContent='✅ تم إعداد تقرير '+response.meta.from+' — '+response.meta.to+
   ' · '+response.meta.scope_note+' · '+dt(reportAt);
  draw();
 }catch(e){if(serial===revision)$('ffr-status').textContent='⚠️ '+String(e.message||e)}
 finally{if(serial===revision){busy=false;$('ffr-run').disabled=false}}
}
function htmlForPrint(){
 if(!report)return'';
 const stamp=report.manager_notes?.find(x=>x.business_date===report.meta.to&&(x.branch_id||'')===(report.meta.branch_id||''))||{};
 return '<div class="ffr-paper"><h1>FRESH FRIES LUXE — التقرير الإداري</h1>'+
  '<p><strong>الفترة '+esc(report.meta.from)+' — '+esc(report.meta.to)+'</strong> · '+esc(report.meta.scope_note)+'</p>'+
  '<p>إنشاء التقرير '+esc(dt(reportAt))+' · بتوقيت صنعاء · اليومية تبدأ 8 صباحًا</p>'+
  chosen().filter(x=>allowed().includes(x)).map(key=>'<section class="ffr-section"><h3>'+esc(names[key])+'</h3>'+
   (key==='notes'?'<h4>الملاحظات المعتمدة</h4>'+table(report.manager_notes||[],[['التاريخ','business_date'],['الملاحظات','note_text'],['الاعتماد',x=>x.approver_name||'—']]):section(key,report))+'</section>').join('')+
  '<div class="ffr-stamp"><b>ختم اعتماد المدير</b><p>'+esc(stamp.approver_name||'لم يعتمد')+' · '+esc(dt(stamp.approved_at))+'</p></div>'+
  '<p class="ffr-foot">Fresh Fries LUXE · بيانات النظام الحالية تجريبية · الخصومات والتكاليف غير الموثقة مستبعدة من الصافي · لا تُعتبر القيمة تحصيلاً نقديًا</p></div>';
}
$('ffr-preview').onclick=()=>{
 if(!report)return;$('ffr-preview-document').innerHTML=htmlForPrint();
 if(!preview.open)preview.showModal();
};
$('ffr-print').onclick=()=>{
 if(!report)return;const win=window.open('','_blank');if(!win){alert('اسمح بفتح نافذة الطباعة');return}
 win.opener=null;
 const html='<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><title>Fresh Fries — '+esc(report.meta.to)+'</title><style>'+
 st.textContent+'@page{size:A4;margin:12mm}@media print{#ffr-print-page{display:none!important}.ffr-paper{margin:0;max-width:unset;padding:0}.ffr-section{break-inside:avoid}.ffr-table tr,.ffr-tile{break-inside:avoid}}</style></head><body>'+
 '<button id="ffr-print-page" style="padding:14px;background:#cb293d;color:white;border:0;border-radius:9px" onclick="window.print()">🖨️ طباعة / حفظ PDF</button>'+
 htmlForPrint()+'</body></html>';
 win.document.open();win.document.write(html);win.document.close();win.focus();
};
async function share(){
 if(!report)return;
 const r=report.totals,txt='تقرير Fresh Fries LUXE '+report.meta.from+' إلى '+report.meta.to+
  '\nالأقسام: '+chosen().map(x=>names[x]).join('، ')+
  '\nالطلبات: '+r.orders+' | المسلّمة: '+r.delivered+' | الملغاة: '+r.cancelled+
  '\nقيمة المسلّمة: '+money(Number(r.invoice_value||0)+Number(r.invoiced_additions||0))+
  '\nملف PDF الكامل: احفظه أولًا من خيار طباعة/PDF ثم شاركه كملف.';
 try{if(navigator.share)await navigator.share({title:'تقرير فريش فرايز',text:txt});
  else if(navigator.clipboard?.writeText){await navigator.clipboard.writeText(txt);$('ffr-status').textContent='تم نسخ ملخص التقرير للمشاركة'}
 }catch(e){if(e.name!=='AbortError')$('ffr-status').textContent=String(e.message||e)}
}
$('ffr-share').onclick=share;$('ffr-preview-share').onclick=share;
$('ffr-csv').onclick=()=>{
 if(!report)return;
 const rows=[['القسم','العنصر','القيمة']];
 for(const key of chosen()){
  const src={overview:report.totals,finance:report.totals,charts:report.daily,branches:report.branches,orders:report.cancellations,drivers:report.drivers,staff:report.customer_service,items:report.items,
   customers:report.customers,ratings:report.ratings,cases:report.cases,kitchen:report.kitchen,rewards:report.rewards,notes:report.manager_notes}[key];
  if(Array.isArray(src))for(const x of src)rows.push([names[key],Object.values(x).slice(0,2).join(' / '),JSON.stringify(x)]);
  else if(src)for(const [k,v] of Object.entries(src))rows.push([names[key],k,v]);
 }
 const csvCell=x=>{const raw=String(x??'');const safe=/^[\s\uFEFF]*[=+@-]/.test(raw)?"'"+raw:raw;return '"'+safe.replace(/"/g,'""')+'"'};
 const text='\uFEFF'+rows.map(x=>x.map(csvCell).join(',')).join('\r\n');
 const url=URL.createObjectURL(new Blob([text],{type:'text/csv;charset=utf-8'}));
 const a=document.createElement('a');a.href=url;a.download='FreshFries_Reports_'+report.meta.from+'_'+report.meta.to+'.csv';a.click();
 setTimeout(()=>URL.revokeObjectURL(url),2000);
};
function reset(){
 serial++;report=null;actor='';busy=false;if(dialog.open)dialog.close();if(preview.open)preview.close();
}
window.addEventListener('ff-luxe-session-reset',reset);$('logoutBtn')?.addEventListener('click',reset);
function attach(){
 if(!auth())return;
 const nav=$('ffx-nav');if(nav&&!$('ffr-menu')){
  const b=document.createElement('button');b.id='ffr-menu';b.type='button';b.className='ffx-side-link';
  b.textContent='📊 '+(role()==='manager'?'مركز التقارير الإداري':'تقاريري');b.onclick=open;nav.append(b);
 }
 const workplace=role()==='burger_kitchen'?$('ffBurgerKitchenWorkspace'):role()==='assembly'?$('ffV12AssemblyWorkspace'):null;
 if(workplace&&!workplace.querySelector('#ffr-workplace')){
  const b=document.createElement('button');b.id='ffr-workplace';b.type='button';b.textContent='📊 تقاريري';
  b.style.cssText='display:block;width:100%;margin:10px 0;padding:13px;color:#fff;background:#b71e36;border:0;border-radius:11px;font-weight:900';b.onclick=open;workplace.prepend(b);
 }
 const top=$('ffx-topbar');if(top&&!$('ffr-top')&&role()!=='burger_kitchen'&&role()!=='assembly'){
  const b=document.createElement('button');b.id='ffr-top';b.type='button';b.textContent='📊 التقارير';b.onclick=open;
  b.style.cssText='border:1px solid #c5263c;background:#fff;color:#9f1b30;border-radius:9px;margin:0 6px;min-height:38px;padding:6px;font-weight:900';top.append(b);
 }
}
new MutationObserver(()=>{if(auth())attach()}).observe(document.body,{childList:true,subtree:true});
window.addEventListener('ff-assembly-snapshot-success',()=>{if(auth())attach();else if(dialog.open)reset()});
setInterval(()=>{if(auth())attach();else if(dialog.open)reset()},5000);
attach();
})();