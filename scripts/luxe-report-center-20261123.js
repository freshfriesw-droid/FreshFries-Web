/* FF76 — Fresh Fries LUXE unified administrative reports. Database RPC enforces access. */
(function () {
'use strict';
const el = id => document.getElementById(id);
const safe = value => String(value == null ? '' : value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const fmt = value => value === null || value === undefined ? '—' : Number(value).toLocaleString('ar-YE',{maximumFractionDigits:2});
const cash = value => value === null || value === undefined ? '—' : fmt(value)+' ر.ي';
const stamp = date => date ? new Date(date).toLocaleString('ar-YE',{timeZone:'Asia/Aden',dateStyle:'short',timeStyle:'short'}) : '—';
const headings = {summary:'الملخص اليومي',finance:'المبالغ المسجلة ورسوم التوصيل',orders:'الطلبات والإلغاءات',branches:'الفروع',drivers:'أداء الموصلين',staff:'موظفو خدمة العملاء',areas:'العملاء والمناطق',items:'الأصناف الأكثر طلباً',ratings:'التقييمات',cases:'الشكاوى والتظلمات',attendance:'الدوام والاستراحات',analytics:'التحليلات المتقدمة',comparisons:'المقارنات',approval:'اعتماد المدير'};
let result=null,identity='',pdf=null,pdfURL=null,fileName='',pending=false,pdfPromise=null,libPromise=null,previewed=false;
let reportRequest=0,pdfRevision=0;
function me(){return typeof user!=='undefined' && user ? user.id : ''}
const root=document.createElement('section');root.id='ff76Center';root.dir='rtl';root.className='ff76-hidden';
root.innerHTML=[
'<header class="r-head"><div><h2>📊 مركز التقارير الإدارية الموحد</h2><p>Fresh Fries LUXE — بيانات تشغيلية حسب الصلاحيات والفروع</p></div><button id="ff76Close" type="button" class="r-plain">✕ إغلاق</button></header>',
'<div class="r-actions"><button id="ff76Today" class="r-plain">اليوم التشغيلي</button><button id="ff76Yesterday" class="r-plain">أمس</button><button id="ff76Seven" class="r-plain">آخر 7 أيام</button><button id="ff76Thirty" class="r-plain">آخر 30 يوماً</button></div>',
'<div class="r-filters">',
'<label>من تاريخ<input type="date" id="ff76From"></label><label>إلى تاريخ<input type="date" id="ff76To"></label>',
'<label>الفرع<select id="ff76Branch"><option value="">كل الفروع المخولة</option></select></label>',
'<label id="ff76DriverWrap">موصل محدد<select id="ff76Driver"><option value="">جميع الموصلين</option></select></label>',
'<label>محتوى التقرير<select id="ff76Mode"><option value="full">شامل — جميع الأقسام المسموحة</option><option value="custom">أقسام مخصصة</option></select></label>',
'<label>تجميع الرسم البياني<select id="ff76Trend"><option value="daily">يومي</option><option value="weekly">أسبوعي</option><option value="monthly">شهري</option></select></label>',
'</div><div id="ff76Choices" class="r-choices" hidden></div>',
'<div class="r-actions"><button type="button" id="ff76Run" class="r-primary">إعداد التقرير</button>',
'<button type="button" id="ff76Preview" class="r-plain" disabled>👁️ معاينة PDF</button>',
'<button type="button" id="ff76Download" class="r-plain" disabled>⬇️ تصدير PDF</button>',
'<button type="button" id="ff76Share" class="r-plain" disabled>📤 مشاركة التقرير</button></div>',
 '<button type="button" id="ff76CSV" class="r-plain" disabled>تصدير الأقسام CSV</button>',
 '<details><summary>قوالب أقسام التقرير</summary><label>اسم القالب<input id="ff76PresetName" maxlength="80"></label><button id="ff76SavePreset" type="button">حفظ الاختيارات</button><label>قوالبي<select id="ff76PresetList"></select></label><button id="ff76UsePreset" type="button">تطبيق القالب</button><p id="ff76PresetStatus" role="status"></p></details>',
'<p id="ff76Status" class="r-muted" role="status" aria-live="polite">حدد الفترة واضغط إعداد التقرير.</p>',
'<div id="ff76Body"></div>',
'<section id="ff76ApprovalBox" class="r-section" hidden><h3>🖋️ ملاحظات المدير واعتماد التقرير</h3>',
'<p class="r-muted">اعتماد إداري باسم المدير وتاريخه؛ ليس توقيعاً رقمياً مشفراً أو اعتماداً محاسبياً.</p>',
'<label>اسم المدير<input id="ff76ManagerName" maxlength="120"></label>',
'<label>ملاحظات الإدارة<textarea id="ff76ManagerNotes" rows="3" maxlength="3000"></textarea></label>',
'<div class="r-actions"><button type="button" id="ff76SaveApproval" class="r-primary">حفظ واعتماد التقرير</button></div>',
'<p id="ff76ApprovalStatus" class="r-muted"></p></section>'
].join('');
const anchor=el('ff40ReportsPanel');
if(anchor)anchor.after(root);else document.querySelector('main')?.append(root);
const previewDialog=document.createElement('dialog');previewDialog.id='ff76PdfDialog';previewDialog.dir='rtl';
previewDialog.innerHTML='<header class="r-dialoghead"><b>معاينة PDF الكاملة قبل الإرسال</b><div><button id="ff76DlgDownload">حفظ الملف</button> <button id="ff76DlgShare" class="r-primary">مشاركة الملف</button> <button id="ff76DlgClose">✕ إغلاق</button></div></header><iframe id="ff76PDFFrame" title="معاينة PDF"></iframe>';
document.body.append(previewDialog);
function clearPDF(){pdfRevision++;pdfPromise=null;if(previewDialog.open)previewDialog.close();if(pdfURL){URL.revokeObjectURL(pdfURL);pdfURL=null}pdf=null;fileName='';previewed=false;el('ff76PDFFrame').removeAttribute('src')}
function clear(){result=null;identity='';clearPDF();el('ff76Body').textContent='';el('ff76ApprovalBox').hidden=true;['ff76Preview','ff76Download','ff76Share','ff76CSV'].forEach(id=>el(id).disabled=true)}
function day(){if(typeof ff40TodayYemen==='function')return ff40TodayYemen();const p=Object.fromEntries(new Intl.DateTimeFormat('en-GB',{timeZone:'Asia/Aden',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date()).filter(x=>x.type!=='literal').map(x=>[x.type,x.value]));return p.year+'-'+p.month+'-'+p.day}
function changeDay(s,n){const d=new Date(s+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10)}
function period(days,offset){const end=changeDay(day(),offset);el('ff76To').value=end;el('ff76From').value=changeDay(end,-days+1);invalidate()}
function invalidate(){reportRequest++;pending=false;el('ff76Run').disabled=false;if(result||!root.classList.contains('ff76-hidden')){clear();el('ff76Status').textContent='تغيّر فلتر التقرير. اضغط إعداد التقرير من جديد.'}}
function options(id,rows,text,field,placeholder){const select=el(id),old=select.value;select.replaceChildren(new Option(placeholder,''));(rows||[]).forEach(row=>select.append(new Option(row[text]||'غير محدد',row[field])));if(Array.from(select.options).some(o=>o.value===old))select.value=old}
function allowed(section){return (result?.available_sections||[]).includes(section)}
function selected(){if(!result)return[];if(el('ff76Mode').value==='full')return result.available_sections;return Array.from(el('ff76Choices').querySelectorAll('input:checked')).map(c=>c.value).filter(allowed)}
function choices(){const node=el('ff76Choices');node.hidden=el('ff76Mode').value!=='custom';if(!result)return;
const former=Array.from(node.querySelectorAll('input:checked')).map(n=>n.value);
node.innerHTML=result.available_sections.map(key=>'<label><input type="checkbox" value="'+safe(key)+'" '+(!former.length||former.includes(key)?'checked':'')+'>'+safe(headings[key]||key)+'</label>').join('');
node.querySelectorAll('input').forEach(x=>x.onchange=()=>{clearPDF();draw()})}
function table(cols,rows){if(!rows?.length)return '<p class="r-muted">لا توجد بيانات موثقة للفترة المختارة.</p>';
return '<div class="r-scroll"><table><thead><tr>'+cols.map(c=>'<th>'+safe(c[0])+'</th>').join('')+'</tr></thead><tbody>'+
rows.map(x=>'<tr>'+cols.map(c=>'<td>'+safe(c[1](x)??'—')+'</td>').join('')+'</tr>').join('')+'</tbody></table></div>'}
function cards(rows){return '<div class="r-kpis">'+rows.map(x=>'<div class="r-kpi"><small>'+safe(x[0])+'</small><b>'+safe(x[1])+'</b></div>').join('')+'</div>'}
function section(key,html){return '<section class="r-section"><h3>'+safe(headings[key])+'</h3>'+html+'</section>'}
function weekly(date){const x=new Date(date+'T12:00:00Z');x.setUTCDate(x.getUTCDate()-((x.getUTCDay()+6)%7));return x.toISOString().slice(0,10)}
function trend(){const groups=new Map();(result.days||[]).forEach(row=>{const name=el('ff76Trend').value==='monthly'?row.work_day.slice(0,7):el('ff76Trend').value==='weekly'?weekly(row.work_day):row.work_day;const x=groups.get(name)||{label:name,orders:0,net:0};x.orders+=Number(row.orders||0);x.net+=Number(row.net||0);groups.set(name,x)});return Array.from(groups.values()).sort((a,b)=>a.label.localeCompare(b.label))}
function barChart(rows,key){if(!rows.length)return '<p class="r-muted">بيانات الرسم غير متوفرة.</p>';const max=Math.max(1,...rows.map(x=>Number(x[key]||0)));
return '<div class="r-scroll"><div class="r-bars">'+rows.map(x=>'<div class="r-barcol"><span>'+safe(fmt(x[key]))+'</span><div class="r-bar" style="height:'+Math.max(2,Math.round(105*Number(x[key]||0)/max))+'px"></div><span>'+safe(x.label)+'</span></div>').join('')+'</div></div>'}
function percentage(a,b){return b==null||Number(b)===0?'لا تتوفر مقارنة':(Number(a)>=Number(b)?'+':'')+fmt((Number(a)-Number(b))/Number(b)*100)+'%'}
function recommendations(t){const n=[];if(Number(t.cancellation_rate||0)>10)n.push('تحليل أسباب الإلغاء المرتفعة ومعالجة المتكرر منها.');
if(Number(t.late||0)>0)n.push('مراجعة الطلبات التي تجاوزت 60 دقيقة، خاصة ساعات الذروة.');
if(Number(t.low_ratings||0)>0)n.push('متابعة التقييمات المنخفضة وتعليقاتها واتخاذ إجراء تصحيحي.');
if(Number(t.free_delivery||0)>0)n.push('مراجعة حالات التوصيل المجاني مقابل العروض المعتمدة.');
if(!(result.attendance||[]).length)n.push('تفعيل توثيق فترات الدوام لمعرفة ساعات العمل الصافية.');
if(!n.length)n.push('لا تظهر مؤشرات استثنائية في القواعد الحالية؛ واصل المتابعة.');
return n}
function compose(keys){
if(!result)return '';const r=result,t=r.totals||{},selectedSet=new Set(keys),html=[];
if(selectedSet.has('summary'))html.push(section('summary',cards([
['جميع الطلبات',fmt(t.orders)],['المنجزة',fmt(t.delivered)],['الملغاة',fmt(t.cancelled)],['قيد المتابعة',fmt(t.pending)],['العملاء الجدد لأول مرة',fmt(t.new_customers)],['المناطق الجديدة',fmt(t.new_areas)],['توصيل مجاني',fmt(t.free_delivery)],['متوسط وقت التوصيل',t.avg_delivery_minutes==null?'—':fmt(t.avg_delivery_minutes)+' دقيقة']
])+'<p class="r-muted">اليوم التشغيلي من 08:00 صباحاً إلى 02:00 صباح اليوم التالي بتوقيت صنعاء، دون تصفير البيانات.</p>'));
if(selectedSet.has('finance'))html.push(section('finance',cards([
['مبيعات أصناف الطلبات المسلّمة',cash(t.item_sales)],['رسوم التوصيل المستحقة',cash(t.delivery_fees)],['تقدير الخصومات',cash(t.discounts_estimate)],['الإجمالي النهائي المسجل',cash(t.net)],['متوسط قيمة الطلب المسلّم',cash(t.average_order)]
])+'<p class="r-muted">قيم الفواتير تشغيلية وليست تحصيلاً نقدياً مؤكداً. تقدير الخصومات من الفرق بين الأصناف + التوصيل والإجمالي المسجل؛ الإضافات المفوترة ضمن المبيعات والصافي.</p>'));
if(selectedSet.has('orders'))html.push(section('orders',cards([
['المنجزة',fmt(t.delivered)],['الملغاة',fmt(t.cancelled)],['معدل الإلغاء',t.cancellation_rate==null?'—':fmt(t.cancellation_rate)+'%'],['المتأخرة أكثر من 60 دقيقة',fmt(t.late)],['توصيل مجاني',fmt(t.free_delivery)],['أسرع طلب',t.fastest_minutes==null?'—':fmt(t.fastest_minutes)+' دقيقة']
])+'<h4>أسرع الطلبات</h4>'+table([['الطلب',x=>x.order_number],['الفرع',x=>x.branch_name],['الموصل',x=>x.driver_name],['دقائق',x=>x.minutes]],r.fastest)+
'<h4>الطلبات الملغية وأسباب الإلغاء</h4>'+table([['الطلب',x=>x.order_number],['الفرع',x=>x.branch_name],['التاريخ',x=>stamp(x.created_at)],['السبب',x=>x.reason]],r.cancellations)+
'<h4>تفاصيل الطلبات المتأخرة (أكثر من 60 دقيقة)</h4>'+table([['الطلب',x=>x.order_number],['الفرع',x=>x.branch_name],['الدقائق',x=>fmt(x.delivery_minutes)],['وقت إنشاء الطلب',x=>stamp(x.created_at)]],r.late_orders)+
'<h4>تفاصيل طلبات التوصيل المجاني</h4>'+table([['الطلب',x=>x.order_number],['الفرع',x=>x.branch_name],['قيمة الفاتورة',x=>cash(x.total_amount)],['تاريخ الإنشاء',x=>stamp(x.created_at)]],r.free_delivery_orders)));
if(selectedSet.has('branches'))html.push(section('branches',table([['الفرع',x=>x.branch_name],['الكل',x=>fmt(x.orders)],['مسلّمة',x=>fmt(x.delivered)],['ملغاة',x=>fmt(x.cancelled)],['صافي الفواتير',x=>cash(x.net)],['متوسط الفاتورة',x=>cash(x.average_order)]],r.branch_rows)));
if(selectedSet.has('drivers')){
 const top=(r.drivers||[]).slice().sort((a,b)=>Number(b.delivered)-Number(a.delivered))[0];
 // Balanced score is shown ONLY when attendance, internal reviews, and at least 3 completed jobs exist.
 const candidates=(r.drivers||[]).map(d=>({
  ...d,internal:(r.internal_driver_ratings||[]).find(x=>x.driver_name===d.driver_name),
  hours:(r.attendance||[]).filter(x=>x.driver_id===d.driver_id).reduce((a,x)=>a+Number(x.work_hours||0),0)
 })).filter(d=>d.delivered>=3&&Number(d.internal?.ratings)>=1&&d.hours>0&&d.average_minutes>0);
 const maxJobs=Math.max(1,...candidates.map(d=>Number(d.delivered)));
 const maxHours=Math.max(1,...candidates.map(d=>d.hours));
 const evaluated=candidates.map(d=>({name:d.driver_name,score:Math.round(100*(.25*Number(d.delivered)/maxJobs+.25*Math.min(1,30/Number(d.average_minutes))+.25*Number(d.internal.average_stars)/5+.25*d.hours/maxHours))})).sort((a,b)=>b.score-a.score);
 const champion=evaluated.length>=2?evaluated[0]:null;
 const fast=(r.drivers||[]).filter(x=>Number(x.delivered)>=2&&x.average_minutes!=null).sort((a,b)=>Number(a.average_minutes)-Number(b.average_minutes))[0];
 html.push(section('drivers','<p class="r-muted">الأكثر إنجازاً: '+safe(top?.driver_name||'غير متاح')+' | الأسرع بالمتوسط (طلبان على الأقل): '+safe(fast?.driver_name||'بيانات غير كافية')+'. تصنيف الأداء الشامل: '+safe(champion?champion.name+' — '+champion.score+'/100':'لا توجد بيانات كافية للترتيب العادل')+'. طريقة الترتيب عند توفر البيانات لموصلين اثنين على الأقل: 25% إنجاز، 25% سرعة، 25% تقييم داخلي، 25% ساعات عمل، بحد أدنى 3 طلبات وتقييم موثق ودوام.</p>'+
 table([['الموصل',x=>x.driver_name],['المسندة',x=>fmt(x.assigned)],['المنجزة',x=>fmt(x.delivered)],['رسوم مستحقة',x=>cash(x.delivery_fees_due)],['قيمة الفواتير',x=>cash(x.invoice_value)],['متوسط الفاتورة',x=>cash(x.average_order)],['متوسط التوصيل بالدقائق',x=>fmt(x.average_minutes)],['متوسط تقييم الطلب',x=>fmt(x.average_rating)]],r.drivers)+
'<h4>تقييمات الموصلين الداخلية</h4>'+table([['الموصل',x=>x.driver_name],['مرات التقييم',x=>fmt(x.ratings)],['متوسط النجوم',x=>fmt(x.average_stars)],['التقييمات المنخفضة',x=>fmt(x.low_ratings)]],r.internal_driver_ratings)+
'<h4>التسويات والتحصيل الفعلي المسجل</h4>'+table([['الموصل',x=>x.driver_name],['التسويات',x=>fmt(x.statements)],['المبلغ المستحق',x=>cash(x.cash_due)],['المبلغ المسجل مستلماً',x=>cash(x.cash_received)],['التسويات المقفلة',x=>fmt(x.closed_statements)]],r.settlements)+
'<p class="r-muted">لا يُعد المبلغ المستحق تحصيلاً مؤكداً؛ استند إلى سجلات التسويات المقفلة عند المطابقة المالية.</p>'))}
if(selectedSet.has('staff'))html.push(section('staff',table([['الموظف',x=>x.staff_name],['الطلبات',x=>fmt(x.orders)]],r.service_staff)));
if(selectedSet.has('areas'))html.push(section('areas','<h4>مناطق التوصيل</h4>'+table([['المنطقة',x=>x.area_name],['الطلبات',x=>fmt(x.orders)],['منجزة',x=>fmt(x.delivered)],['العملاء الجدد',x=>fmt(x.new_customers)]],r.areas)+
 (r.customers?.length?'<h4>العملاء المتكررون</h4>'+table([['العميل',x=>x.customer_name],['الرقم المخفي',x=>x.phone_masked],['الطلبات',x=>fmt(x.orders)]],r.customers):'')));
if(selectedSet.has('items'))html.push(section('items',table([['الصنف',x=>x.item_name],['الكمية',x=>fmt(x.quantity)],['الإيراد',x=>cash(x.revenue)]],r.items)));
if(selectedSet.has('ratings'))html.push(section('ratings',cards([['أعلى تقييم للطلب',fmt(t.rating_max)],['أدنى تقييم للطلب',fmt(t.rating_min)],['المتوسط',fmt(t.rating_avg)],['المنخفضة بنجمتين أو أقل',fmt(t.low_ratings)]])+
 table([['الطلب',x=>x.order_number],['النجوم',x=>x.rating],['الملاحظة',x=>x.rating_note||'دون تعليق'],['الوقت',x=>stamp(x.created_at)]],r.low_ratings)));
if(selectedSet.has('cases'))html.push(section('cases','<h4>الشكاوى المرتبطة بالطلبات</h4>'+table([['الموضوع',x=>x.subject],['الطلب',x=>x.order_number||'بدون طلب'],['الفرع',x=>x.branch_name],['الحالة',x=>x.status]],r.complaints)+
 '<h4>تظلمات الموصلين</h4>'+table([['التصنيف',x=>x.category],['التفاصيل',x=>x.details],['الحالة',x=>x.status]],r.grievances)));
if(selectedSet.has('attendance'))html.push(section('attendance','<p class="r-muted">صافي الحضور = مجموع فترات الحضور في اليوم التشغيلي بعد طرح الاستراحات. البيانات القديمة غير الموثقة لا يمكن استرجاعها.</p>'+
 table([['اليوم',x=>x.report_day],['الموصل',x=>x.driver_name],['فترات الحضور',x=>fmt(x.sessions)],['الحضور الفعلي',x=>stamp(x.first_checkin)],['آخر خروج',x=>stamp(x.last_checkout)],['صافي الساعات',x=>fmt(x.work_hours)]],r.attendance)));
if(selectedSet.has('analytics'))html.push(section('analytics','<h4>الطلبات '+safe(el('ff76Trend').selectedOptions[0]?.textContent)+'</h4>'+barChart(trend(),'orders')+'<h4>الفواتير المسلّمة</h4>'+barChart(trend(),'net')+
'<h4>أوقات الذروة</h4>'+barChart((r.hourly||[]).map(x=>({label:String(x.hour_of_day).padStart(2,'0')+':00',orders:Number(x.orders)})),'orders')+
'<p class="r-muted">نسبة الطلبات «المؤجلة» لا تُحسب دون حالة تأجيل مستقلة موثقة في قاعدة البيانات.</p>'));
if(selectedSet.has('comparisons')){
 const c=r.comparison||{},today=c.today||{},old=c.yesterday||{},week=c.last_week||{},avgWeek=c.previous_week_average||{};
 html.push(section('comparisons',table([['الفترة',x=>x.label],['الطلبات',x=>fmt(x.orders)],['المسلّمة',x=>fmt(x.delivered)],['القيمة',x=>cash(x.net)]],[{label:'نهاية الفترة',...today},{label:'اليوم السابق',...old},{label:'نفس اليوم الأسبوع الماضي',...week},{label:'متوسط السبعة أيام السابقة',...avgWeek}])+
 cards([['تغيير الطلبات عن أمس',percentage(today.orders,old.orders)],['تغيير قيمة الفواتير عن أمس',percentage(today.net,old.net)],['الفرق عن الأسبوع الماضي',percentage(today.orders,week.orders)],['الفرق عن متوسط الأسبوع',percentage(today.orders,avgWeek.orders)]])+
 '<p class="r-muted">المقارنة تخص تاريخ نهاية الفترة المختارة فقط.</p>'))}
if(selectedSet.has('approval'))html.push(section('approval',r.approval?.approved_at?
 '<div class="r-stamp"><b>اعتماد إداري: '+safe(r.approval.manager_name||'المدير')+'</b><div>تاريخ الاعتماد '+safe(stamp(r.approval.approved_at))+'</div><p>'+safe(r.approval.manager_notes)+'</p></div>':
 '<p class="r-muted">لم يعتمد هذا التقرير إدارياً بعد.</p>'));
if(selectedSet.has('summary')||selectedSet.has('comparisons'))html.push('<section class="r-section"><h3>المؤشر الإداري والخاتمة والتوصيات</h3><p class="r-muted">توصيات تشغيلية للمدير والمشرف وخدمة العملاء بحسب المؤشرات، وتحتاج مراجعة مسؤول معتمد.</p><ul>'+recommendations(t).map(x=>'<li>'+safe(x)+'</li>').join('')+'</ul></section>');
return html.join('')}
function draw(){if(!result)return;el('ff76Body').innerHTML=compose(selected())||'<p class="r-muted">حدد قسماً واحداً على الأقل.</p>';
const allowedApproval=result.role==='manager'&&el('ff76From').value===el('ff76To').value&&!el('ff76Driver').value;
el('ff76ApprovalBox').hidden=!allowedApproval;
if(allowedApproval){el('ff76ManagerName').value=result.approval?.manager_name||'';el('ff76ManagerNotes').value=result.approval?.manager_notes||''}
['ff76Preview','ff76Download','ff76Share','ff76CSV'].forEach(id=>el(id).disabled=!selected().length)}
async function load(){
 if(!me()||pending)return;
 const from=el('ff76From').value,to=el('ff76To').value,branch=el('ff76Branch').value||null,driver=el('ff76Driver').value||null;
 const days=(new Date(to+'T12:00:00Z')-new Date(from+'T12:00:00Z'))/86400000;
 if(!from||!to||from>to||to>day()||days>89){el('ff76Status').textContent='فترة غير صحيحة؛ يجب ألا تتجاوز 90 يوماً ولا تشمل المستقبل.';return}
 const viewer=me(),request=++reportRequest;pending=true;el('ff76Run').disabled=true;clear();el('ff76Status').textContent='جاري جمع البيانات بحسب صلاحيات المستخدم...';
 try{
 const data=await rpc('ff76_reporting_center',{p_from:from,p_to:to,p_branch:branch,p_driver:driver});
 if(request!==reportRequest||me()!==viewer)return;
 if(!data?.totals||!Array.isArray(data.available_sections))throw Error('استجابة التقرير غير صالحة');
 result=data;identity=viewer+':'+from+':'+to+':'+String(branch)+':'+String(driver);
 options('ff76Branch',data.branches,'name','id','جميع الفروع المسموحة');if(branch)el('ff76Branch').value=branch;
 options('ff76Driver',data.driver_options,'name','id','جميع الموصلين');if(driver)el('ff76Driver').value=driver;
 el('ff76DriverWrap').hidden=!(data.driver_options||[]).length;
 choices();draw();void refreshPresets(request);
 el('ff76Status').textContent='تقرير '+from+' إلى '+to+' | '+data.scope+' | '+fmt(data.totals.orders)+' طلب. بيانات تشغيلية وليست إقفالات محاسبية.';
 }catch(e){if(request!==reportRequest)return;clear();el('ff76Status').textContent='تعذر إعداد التقرير: '+(e.message||e)}finally{if(request===reportRequest){pending=false;el('ff76Run').disabled=false}}
}
function open(){if(!me()){typeof toast==='function'&&toast('سجّل الدخول أولاً');return}el('ff40ReportsPanel')?.classList.add('hidden');root.classList.remove('ff76-hidden');
if(!el('ff76From').value)period(1,0);root.scrollIntoView({behavior:'smooth',block:'start'});if(!result)void load()}
window.ff76OpenReports=open;
el('ff76Close').onclick=()=>root.classList.add('ff76-hidden');
[['ff76Today',1,0],['ff76Yesterday',1,-1],['ff76Seven',7,0],['ff76Thirty',30,0]].forEach(x=>el(x[0]).onclick=()=>{period(x[1],x[2]);void load()});
el('ff76Run').onclick=load;['ff76From','ff76To','ff76Branch','ff76Driver'].forEach(id=>el(id).addEventListener('change',invalidate));
el('ff76Mode').onchange=()=>{choices();clearPDF();draw()};el('ff76Trend').onchange=()=>{clearPDF();draw()};
el('ff76SaveApproval').onclick=async()=>{if(!result||result.role!=='manager'||el('ff76From').value!==el('ff76To').value||el('ff76Driver').value)return;
const uid=me(),tag=identity;el('ff76SaveApproval').disabled=true;
try{const res=await rpc('ff76_report_approval_save',{p_day:el('ff76To').value,p_branch:el('ff76Branch').value||null,p_notes:el('ff76ManagerNotes').value,p_manager_name:el('ff76ManagerName').value});
if(me()!==uid||tag!==identity)throw Error('تغير الحساب أو التقرير');result.approval={...res,manager_notes:res.notes};clearPDF();draw();el('ff76ApprovalStatus').textContent='تم توثيق اعتماد المدير وتاريخ حفظه.'}
catch(e){el('ff76ApprovalStatus').textContent='فشل الاعتماد: '+e.message}finally{el('ff76SaveApproval').disabled=false}};
let presets=[];
async function refreshPresets(request){
 const viewer=me();
 try{
  const rows=await rpc('ff_report_preset_list');
  if(viewer!==me()||request!==reportRequest)return;
  presets=rows||[];
  options('ff76PresetList',presets,'title','title','اختر القالب');
 }catch(e){if(viewer===me()&&request===reportRequest)el('ff76PresetStatus').textContent=e.message}
}
el('ff76SavePreset').onclick=async()=>{
 const title=el('ff76PresetName').value.trim(),sections=selected(),request=reportRequest,viewer=me();
 if(!result||!title||!sections.length){el('ff76PresetStatus').textContent='أدخل اسم القالب واختر الأقسام';return}
 if(presets.some(p=>p.title===title)&&!confirm('تحديث القالب '+title+'؟'))return;
 try{
  await rpc('ff_report_preset_save',{p_title:title,p_sections:sections,p_trend:el('ff76Trend').value});
  if(request!==reportRequest||viewer!==me())return;
  await refreshPresets(request);
  if(request===reportRequest&&viewer===me()){el('ff76PresetList').value=title;el('ff76PresetStatus').textContent='حُفظ القالب'}
 }catch(e){if(request===reportRequest&&viewer===me())el('ff76PresetStatus').textContent=e.message}
};
el('ff76UsePreset').onclick=()=>{
 const preset=presets.find(p=>p.title===el('ff76PresetList').value);
 if(!result||!preset)return;
 el('ff76Mode').value='custom';choices();
 el('ff76Choices').querySelectorAll('input').forEach(box=>box.checked=preset.sections.includes(box.value)&&allowed(box.value));
 el('ff76Trend').value=preset.trend;
 el('ff76PresetName').value=preset.title;clearPDF();draw();
 el('ff76PresetStatus').textContent='عدد الأقسام المتاحة من القالب '+selected().length;
};
function csvField(value){
 let text=String(value??'');
 if(/^[\s]*[=+@-]/.test(text))text="'"+text;
 return '"'+text.replace(/"/g,'""')+'"';
}
el('ff76CSV').onclick=()=>{
 if(!result||!selected().length||!identity.startsWith(me()+':'))return;
 const rows=[['التقرير',result.from,result.to,result.scope]];
 for(const section of el('ff76Body').querySelectorAll('section')){
  rows.push([], [section.querySelector('h3')?.textContent]);
  for(const node of section.querySelectorAll('.r-kpi,tr,p,li,.r-barcol')){
   if(node.matches('tr,.r-kpi,.r-barcol'))rows.push(Array.from(node.children,x=>x.textContent).filter(Boolean));
   else rows.push([node.textContent]);
  }
 }
 const blob=new Blob(['\uFEFF',rows.map(row=>row.map(csvField).join(',')).join('\r\n')],{type:'text/csv;charset=utf-8'});
 const link=document.createElement('a');link.href=URL.createObjectURL(blob);link.download='FreshFries_'+result.from+'_'+result.to+'.csv';
 link.click();setTimeout(()=>URL.revokeObjectURL(link.href),5000);
};
window.addEventListener('ff-luxe-session-reset',()=>{
 presets=[];el('ff76PresetList').replaceChildren();el('ff76PresetName').value='';el('ff76PresetStatus').textContent='';
});
function pdfLibrary(){if(window.html2pdf)return Promise.resolve();if(libPromise)return libPromise;
libPromise=new Promise((resolve,reject)=>{const s=document.createElement('script');s.src='https://cdn.jsdelivr.net/npm/html2pdf.js@0.10.1/dist/html2pdf.bundle.min.js';s.onload=()=>window.html2pdf?resolve():reject(Error('مكتبة PDF غير جاهزة'));s.onerror=()=>reject(Error('مكتبة PDF تحتاج اتصالاً بالإنترنت'));document.head.append(s)}).catch(e=>{libPromise=null;throw e});return libPromise}
function authorized(uid,tag,revision){if(me()!==uid||identity!==tag||revision!==pdfRevision)throw Error('تغير الحساب أو التقرير')}
async function producePDF(){if(pdf)return pdf;if(pdfPromise)return pdfPromise;if(!result||!selected().length)throw Error('أعد التقرير وحدد أقسامه');
const uid=me(),tag=identity,revision=pdfRevision;pdfPromise=(async()=>{
 await pdfLibrary();authorized(uid,tag,revision);
 const page=document.createElement('div');page.dir='rtl';page.lang='ar';
 page.style.cssText='width:720px;background:#fff;color:#181818;padding:25px;font:14px Tahoma,Arial,sans-serif;line-height:1.7;position:absolute;left:-99999px;top:0';
 page.innerHTML='<div style="border-bottom:4px solid #c51b30;padding:10px 0;margin-bottom:15px"><h1>FRESH FRIES LUXE — مركز التقارير</h1><b>'+safe(result.from)+' إلى '+safe(result.to)+'</b><p>'+safe(result.scope)+'</p></div>'+
 '<style>.r-section{border:1px solid #ccc;padding:10px;margin:12px 0;break-inside:avoid-page}.r-section h3{border-right:4px solid #c51b30;padding-right:8px}.r-kpis{display:flex;flex-wrap:wrap;gap:7px}.r-kpi{border:1px solid #ddd;padding:8px;min-width:135px}.r-kpi b{display:block;font-size:18px}.r-scroll{overflow:visible}table{border-collapse:collapse;width:100%;font-size:11px}th,td{text-align:right;border:1px solid #ddd;padding:7px;overflow-wrap:anywhere}th{background:#eee}.r-muted{font-size:11px;color:#444}.r-bars{display:flex;align-items:flex-end;height:150px}.r-barcol{height:150px;width:65px;display:flex;flex-direction:column;align-items:center;justify-content:flex-end}.r-bar{width:34px;background:#c51b30}.r-barcol span{font-size:10px}.r-stamp{border:2px dashed #c51b30;padding:9px}</style>'+
 compose(selected())+'<footer style="margin-top:20px;border-top:1px solid #ddd">فريش فرايز — تقرير تشغيلي لا يثبت التحصيل المالي.</footer>';
 document.body.append(page);
 try{const blob=await window.html2pdf().set({margin:8,filename:'FreshFries_LUXE_'+result.from+'_'+result.to+'.pdf',
 html2canvas:{scale:1.25,logging:false,backgroundColor:'#ffffff'},jsPDF:{unit:'mm',format:'a4',orientation:'portrait'},
 pagebreak:{mode:['css','legacy'],avoid:['tr','.r-kpi']}}).from(page).outputPdf('blob');
 authorized(uid,tag,revision);if(!(blob instanceof Blob)||blob.size<500)throw Error('ملف PDF غير صالح');
 pdf=blob;fileName='FreshFries_LUXE_Report_'+result.from+'_'+result.to+'.pdf';return blob}finally{page.remove()}})();
 try{return await pdfPromise}finally{if(revision===pdfRevision)pdfPromise=null}}
function download(){if(!pdf)return;const url=pdfURL||URL.createObjectURL(pdf),a=document.createElement('a');a.href=url;a.download=fileName;a.click();if(!pdfURL)setTimeout(()=>URL.revokeObjectURL(url),5000)}
async function preview(){el('ff76Preview').disabled=true;el('ff76Status').textContent='إعداد ملف PDF للمعاينة...';
try{await producePDF();if(!pdfURL)pdfURL=URL.createObjectURL(pdf);el('ff76PDFFrame').src=pdfURL;previewDialog.showModal();previewed=true;el('ff76Status').textContent='راجع ملف PDF قبل الإرسال.'}
catch(e){el('ff76Status').textContent='تعذر إنشاء PDF: '+e.message}finally{el('ff76Preview').disabled=!result}}
async function share(){if(!pdf||!previewed){await preview();return}const file=new File([pdf],fileName,{type:'application/pdf'});
try{if(navigator.canShare?.({files:[file]})&&navigator.share)await navigator.share({title:'تقرير فريش فرايز',files:[file]});
else{download();el('ff76Status').textContent='بدأ حفظ PDF؛ يمكن مشاركته من مدير ملفات الجهاز.'}}catch(e){if(e.name!=='AbortError')el('ff76Status').textContent='لم تكتمل المشاركة: '+e.message}}
el('ff76Preview').onclick=preview;el('ff76Download').onclick=async()=>{try{await producePDF();download()}catch(e){el('ff76Status').textContent=e.message}};
el('ff76Share').onclick=share;
el('ff76DlgDownload').onclick=download;el('ff76DlgShare').onclick=share;el('ff76DlgClose').onclick=()=>previewDialog.close();
previewDialog.addEventListener('close',()=>el('ff76PDFFrame').removeAttribute('src'));
window.addEventListener('ff-luxe-session-reset',()=>{reportRequest++;pending=false;el('ff76Run').disabled=false;el('ff76ManagerNotes').value='';el('ff76ManagerName').value='';el('ff76Choices').replaceChildren();el('ff76ApprovalStatus').textContent='';el('ff76Status').textContent='حدد الفترة واضغط إعداد التقرير.';if(previewDialog.open)previewDialog.close();clear();root.classList.add('ff76-hidden');options('ff76Branch',[],'name','id','كل الفروع');options('ff76Driver',[],'name','id','كل الموصلين')});
el('ff40ReportsBtn')?.addEventListener('click',e=>{e.preventDefault();e.stopImmediatePropagation();open()},true);
for(const id of ['ffV12AssemblyWorkspace','ffBurgerKitchenWorkspace']){
 const host=el(id);if(!host)continue;const b=document.createElement('button');b.type='button';b.className='outline';b.textContent='📊 تقرير التشغيل';b.onclick=open;host.prepend(b)
}
})();