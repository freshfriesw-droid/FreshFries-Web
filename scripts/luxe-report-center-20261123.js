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
let reportRequest=0,pdfRevision=0,choiceInitialized=false,snapshotArgs=null,reportContent={};
function reportHeading(key,content=reportContent){const custom=content['reports.section.'+key];return custom?(['finance','approval'].includes(key)?headings[key]+' — '+custom:custom):(headings[key]||key)}
function me(){return typeof user!=='undefined' && user ? user.id : ''}
const root=document.createElement('section');root.id='ff76Center';root.dir='rtl';root.className='ff76-hidden';
root.innerHTML=[
'<header class="r-head"><div><h2>📊 مركز التقارير الإدارية الموحد</h2><p>Fresh Fries LUXE — بيانات تشغيلية حسب الصلاحيات والفروع</p></div><button id="ff76Close" type="button" class="r-plain">✕ إغلاق</button></header>',
'<div class="r-actions"><button id="ff76Today" class="r-plain">اليوم التشغيلي</button><button id="ff76Yesterday" class="r-plain">أمس</button><button id="ff76Seven" class="r-plain">آخر 7 أيام</button><button id="ff76Thirty" class="r-plain">آخر 30 يوماً</button></div>',
'<div class="r-filters">',
'<label>من تاريخ<input type="date" id="ff76From"></label><label>إلى تاريخ<input type="date" id="ff76To"></label>',
'<label>الفرع<select id="ff76Branch"><option value="">كل الفروع المخولة</option></select></label>',
'<label id="ff76DriverWrap">موصل محدد<select id="ff76Driver"><option value="">جميع الموصلين</option></select></label>',
'<label id="ffA10StaffWrap">الموظف<select id="ffA10Staff"><option value="">جميع الموظفين المخولين</option></select></label>',
'<label>المنطقة<select id="ffA10Area"><option value="">جميع المناطق</option></select></label>',
'<label>الصنف (طلبات تحتويه)<select id="ffA10Item"><option value="">جميع الأصناف</option></select></label>',
'<label>حالة الطلب<select id="ffA10Status"><option value="">جميع الحالات</option><option value="delivered">منجزة</option><option value="cancelled">ملغاة</option><option value="pending">قيد المتابعة</option></select></label>',
'<label>محتوى التقرير<select id="ff76Mode"><option value="full">شامل — جميع الأقسام المسموحة</option><option value="custom">أقسام مخصصة</option></select></label>',
'<label>تجميع الرسم البياني<select id="ff76Trend"><option value="daily">يومي</option><option value="weekly">أسبوعي</option><option value="monthly">شهري</option></select></label>',
'</div><div id="ff76Choices" class="r-choices" hidden></div>',
'<div class="r-actions"><button type="button" id="ff76Run" class="r-primary">إعداد التقرير</button>',
'<button type="button" id="ff76Preview" class="r-plain" disabled>👁️ معاينة PDF</button>',
'<button type="button" id="ff76Download" class="r-plain" disabled>⬇️ تصدير PDF</button>',
'<button type="button" id="ff76Share" class="r-plain" disabled>📤 مشاركة التقرير</button></div>',
 '<div class="r-actions"><button type="button" id="ff76CSV" class="r-plain" disabled>تصدير الأقسام CSV</button><button type="button" id="ff76Excel" class="r-plain" disabled>تصدير Excel (.xlsx)</button></div>',
 '<details><summary>قوالب أقسام التقرير</summary><label>اسم القالب<input id="ff76PresetName" maxlength="80"></label><button id="ff76SavePreset" type="button">حفظ الاختيارات</button><label>قوالبي<select id="ff76PresetList"></select></label><button id="ff76UsePreset" type="button">تطبيق القالب</button><p id="ff76PresetStatus" role="status"></p></details>',
'<details id="ffA10Grants" hidden><summary>تفويض أقسام التقارير — المدير العام</summary><p class="r-muted">التفويض يقيّد الأقسام المتاحة أصلاً للدور؛ لا يوسع الفرع أو صلاحية تشغيلية.</p><div class="r-filters"><label>الحساب<select id="ffA10GrantUser"></select></label><label>القسم<select id="ffA10GrantSection"></select></label><label>القرار<select id="ffA10GrantAllowed"><option value="inherit">افتراضي الدور</option><option value="true">السماح ضمن الدور</option><option value="false">حجب القسم</option></select></label></div><button type="button" id="ffA10GrantSave">حفظ التفويض</button><p id="ffA10GrantStatus" role="status"></p></details>',
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
function clearPDF(){document.querySelectorAll('[data-ff76-export-layer]').forEach(x=>x.remove());pdfRevision++;pdfPromise=null;if(previewDialog.open)previewDialog.close();if(pdfURL){URL.revokeObjectURL(pdfURL);pdfURL=null}pdf=null;fileName='';previewed=false;el('ff76PDFFrame').removeAttribute('src')}
function clear(){snapshotArgs=null;reportContent={};el('ffA10Grants').hidden=true;result=null;identity='';clearPDF();el('ff76ManagerName').value='';el('ff76ManagerNotes').value='';el('ff76ApprovalStatus').textContent='';el('ff76Body').textContent='';el('ff76ApprovalBox').hidden=true;el('ff76SaveApproval').disabled=false;['ff76Preview','ff76Download','ff76Share','ff76CSV','ff76Excel'].forEach(id=>el(id).disabled=true)}
function day(){if(typeof ff40TodayYemen==='function')return ff40TodayYemen();const p=Object.fromEntries(new Intl.DateTimeFormat('en-GB',{timeZone:'Asia/Aden',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date()).filter(x=>x.type!=='literal').map(x=>[x.type,x.value]));return p.year+'-'+p.month+'-'+p.day}
function changeDay(s,n){const d=new Date(s+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10)}
function period(days,offset){const end=changeDay(day(),offset);el('ff76To').value=end;el('ff76From').value=changeDay(end,-days+1);invalidate()}
function invalidate(){reportRequest++;pending=false;el('ff76Run').disabled=false;if(result||!root.classList.contains('ff76-hidden')){clear();el('ff76Status').textContent='تغيّر فلتر التقرير. اضغط إعداد التقرير من جديد.'}}
function options(id,rows,text,field,placeholder){const select=el(id),old=select.value,oldLabel=select.selectedOptions[0]?.textContent;select.replaceChildren(new Option(placeholder,''));(rows||[]).forEach(row=>select.append(new Option(row[text]||'غير محدد',row[field])));if(old&&['ff76Branch','ff76Driver','ffA10Staff','ffA10Area','ffA10Item'].includes(id)&&!Array.from(select.options).some(o=>o.value===old)&&snapshotArgs)select.add(new Option(oldLabel||'الفلتر السابق',old));if(Array.from(select.options).some(o=>o.value===old))select.value=old}
function args(){return {p_from:el('ff76From').value,p_to:el('ff76To').value,p_branch:el('ff76Branch').value||null,p_driver:el('ff76Driver').value||null,p_staff:el('ffA10Staff').value||null,p_area:el('ffA10Area').value||null,p_item:el('ffA10Item').value||null,p_status:el('ffA10Status').value||null}}
function partial(){const a=args();return !!(a.p_staff||a.p_area||a.p_item||a.p_status)}
function allowed(section){return (result?.available_sections||[]).includes(section)}
function selected(){if(!result)return[];if(el('ff76Mode').value==='full')return result.available_sections;return Array.from(el('ff76Choices').querySelectorAll('input:checked')).map(c=>c.value).filter(allowed)}
function choices(){const node=el('ff76Choices');node.hidden=el('ff76Mode').value!=='custom';if(!result)return;
const former=Array.from(node.querySelectorAll('input:checked')).map(n=>n.value);const selectAll=!choiceInitialized;choiceInitialized=true;
node.innerHTML=result.available_sections.map(key=>'<label><input type="checkbox" value="'+safe(key)+'" '+(selectAll||former.includes(key)?'checked':'')+'>'+safe(reportHeading(key))+'</label>').join('');
node.querySelectorAll('input').forEach(x=>x.onchange=()=>{clearPDF();draw()})}
function table(cols,rows){if(!rows?.length)return '<p class="r-muted">لا توجد بيانات موثقة للفترة المختارة.</p>';
return '<div class="r-scroll"><table><thead><tr>'+cols.map(c=>'<th>'+safe(c[0])+'</th>').join('')+'</tr></thead><tbody>'+
rows.map(x=>'<tr>'+cols.map(c=>'<td>'+safe(c[1](x)??'—')+'</td>').join('')+'</tr>').join('')+'</tbody></table></div>'}
function cards(rows){return '<div class="r-kpis">'+rows.map(x=>'<div class="r-kpi"><small>'+safe(x[0])+'</small><b>'+safe(x[1])+'</b></div>').join('')+'</div>'}
function renderSection(key,html,content){return '<section class="r-section" data-report-section="'+safe(key)+'"><h3>'+safe(reportHeading(key,content))+'</h3>'+html+'</section>'}
function weekly(date){const x=new Date(date+'T12:00:00Z');x.setUTCDate(x.getUTCDate()-((x.getUTCDay()+6)%7));return x.toISOString().slice(0,10)}
function trend(){const groups=new Map();(result.days||[]).forEach(row=>{const name=el('ff76Trend').value==='monthly'?row.work_day.slice(0,7):el('ff76Trend').value==='weekly'?weekly(row.work_day):row.work_day;const x=groups.get(name)||{label:name,orders:0,net:0};x.orders+=Number(row.orders||0);x.net+=Number(row.net||0);groups.set(name,x)});return Array.from(groups.values()).sort((a,b)=>a.label.localeCompare(b.label))}
function barChart(rows,key){if(!rows.length)return '<p class="r-muted">بيانات الرسم غير متوفرة.</p>';const max=Math.max(1,...rows.map(x=>Number(x[key]||0)));
return '<div class="r-scroll"><div class="r-bars">'+rows.map(x=>'<div class="r-barcol"><span>'+safe(fmt(x[key]))+'</span><div class="r-bar" style="height:'+Math.max(2,Math.round(105*Number(x[key]||0)/max))+'px"></div><span>'+safe(x.label)+'</span></div>').join('')+'</div></div>'}
function percentage(a,b){return b==null||Number(b)===0?'لا تتوفر مقارنة':(Number(a)>=Number(b)?'+':'')+fmt((Number(a)-Number(b))/Number(b)*100)+'%'}
function recommendations(t){const n=[];if(Number(t.cancellation_rate||0)>10)n.push('تحليل أسباب الإلغاء المرتفعة ومعالجة المتكرر منها.');
if(Number(t.late||0)>0)n.push('مراجعة الطلبات التي تجاوزت 60 دقيقة، خاصة ساعات الذروة.');
if(Number(t.low_ratings||0)>0)n.push('متابعة التقييمات المنخفضة وتعليقاتها واتخاذ إجراء تصحيحي.');
if(Number(t.free_delivery||0)>0)n.push('مراجعة حالات التوصيل المجاني مقابل العروض المعتمدة.');
if(allowed('attendance')&&!(result.attendance||[]).length)n.push('تفعيل توثيق فترات الدوام لمعرفة ساعات العمل الصافية.');
if(!n.length)n.push('لا تظهر مؤشرات استثنائية في القواعد الحالية؛ واصل المتابعة.');
return n}
function compose(keys,content=reportContent){
if(!result)return '';const section=(key,html)=>renderSection(key,html,content);const r=result,t=r.totals||{},selectedSet=new Set(keys),html=[];
if(selectedSet.has('summary'))html.push(section('summary',cards([
['جميع الطلبات',fmt(t.orders)],['المتأخرة قيد المتابعة',fmt(t.late_pending)],['المنجزة',fmt(t.delivered)],['الملغاة',fmt(t.cancelled)],['قيد المتابعة',fmt(t.pending)],['العملاء الجدد لأول مرة',fmt(t.new_customers)],['المناطق الجديدة',fmt(t.new_areas)],['عملاء سبق لهم الطلب',fmt(t.repeat_customers)],['توصيل مجاني',fmt(t.free_delivery)],['متوسط وقت التوصيل',t.avg_delivery_minutes==null?'—':fmt(t.avg_delivery_minutes)+' دقيقة']
])+'<p class="r-muted">اليوم التشغيلي من 08:00 صباحاً إلى 02:00 صباح اليوم التالي بتوقيت صنعاء، دون تصفير البيانات.</p>'));
if(selectedSet.has('finance'))html.push(section('finance',cards([
['قيمة الأصناف والإضافات المسجلة',cash(t.item_sales)],['رسوم التوصيل المسجلة / المستحقة',cash(t.delivery_fees)],['قيمة الفواتير المسجلة',cash(t.net)],['تحصيل مثبت بتسوية مقفلة',cash(r.finance_evidence?.confirmed_received)],['رسوم التوصيل المؤكدة بإثبات مستقل',cash(r.finance_evidence?.fee_collection_confirmed)],['مبالغ مستلمة في تسويات غير مقفلة — تحتاج مراجعة',cash(r.finance_evidence?.draft_received)],['فروق موثقة في تسويات مقفلة',cash(r.finance_evidence?.confirmed_difference)],['تسويات مقفلة',fmt(r.finance_evidence?.closed_statements)],['تسويات مقفلة دون إثبات تفصيلي للرسوم',fmt(r.finance_evidence?.fees_need_review)],['تقدير الخصومات',cash(t.discounts_estimate)],['متوسط قيمة الطلب المسلّم',cash(t.average_order)]
])+'<p class="r-muted">الطلب يقاس بيوم إنشائه التشغيلي، والتسوية بتاريخ التسليم المحلي (00:00–24:00). التحصيل المؤكد لا يُستنتج من التسليم أو الفاتورة. الرمز — يعني غير موثق أو غير منطبق، لا يعني عجزاً. عند فلترة صنف أو منطقة أو موظف أو حالة، لا توزع التسويات الكلية على جزء من الطلبات.</p>'));
if(selectedSet.has('orders'))html.push(section('orders',cards([
['المنجزة',fmt(t.delivered)],['الملغاة',fmt(t.cancelled)],['معدل الإلغاء',t.cancellation_rate==null?'—':fmt(t.cancellation_rate)+'%'],['المتأخرة أكثر من 60 دقيقة (منجزة أو جارية)',fmt(t.late)],['متأخرة وجارية',fmt(t.late_pending)],['متأخرة ومنجزة',fmt(t.late_completed)],['المئين 90 للتوصيل (دقائق)',fmt(t.p90_delivery_minutes)],['توصيل مجاني',fmt(t.free_delivery)],['أسرع طلب',t.fastest_minutes==null?'—':fmt(t.fastest_minutes)+' دقيقة']
])+'<h4>أسرع الطلبات</h4>'+table([['الطلب',x=>x.order_number],['الفرع',x=>x.branch_name],['الموصل',x=>x.driver_name],['دقائق',x=>x.minutes]],r.fastest)+
'<h4>الطلبات الملغية وأسباب الإلغاء</h4>'+table([['الطلب',x=>x.order_number],['الفرع',x=>x.branch_name],['التاريخ',x=>stamp(x.created_at)],['السبب',x=>x.reason]],r.cancellations)+
'<h4>تفاصيل الطلبات المتأخرة (أكثر من 60 دقيقة)</h4>'+table([['الطلب',x=>x.order_number],['الفرع',x=>x.branch_name],['الدقائق',x=>fmt(x.delivery_minutes)],['الحالة',x=>x.status==='delivered'?'منجزة':'جارية'],['وقت إنشاء الطلب',x=>stamp(x.created_at)]],r.late_orders)+
'<h4>تفاصيل طلبات التوصيل المجاني</h4>'+table([['الطلب',x=>x.order_number],['الفرع',x=>x.branch_name],...(allowed('finance')||r.role==='driver'&&allowed('drivers')?[['قيمة الفاتورة',x=>cash(x.total_amount)]]:[]),['تاريخ الإنشاء',x=>stamp(x.created_at)]],r.free_delivery_orders)+
 '<h4>مراحل رحلة الطلب — متوسط الدقائق المسجلة</h4>'+cards([['حتى الإسناد',fmt(r.phase_times?.assignment_minutes)],['من الإسناد حتى الاستلام',fmt(r.phase_times?.pickup_minutes)],['من الاستلام حتى الوصول',fmt(r.phase_times?.travel_minutes)],['من الوصول حتى التسليم',fmt(r.phase_times?.handover_minutes)]])+
 '<h4>مستويات التأخير</h4>'+cards([['أخضر ≤ 30 دقيقة',fmt(r.delay_bands?.green)],['أصفر 31–60 دقيقة',fmt(r.delay_bands?.yellow)],['أحمر أكثر من 60',fmt(r.delay_bands?.red)]])+
 '<h4>عروض الإسناد المسجلة</h4>'+cards([['مرسلة',fmt(r.dispatch?.offered)],['مقبولة',fmt(r.dispatch?.accepted)],['مرفوضة',fmt(r.dispatch?.rejected)],['منتهية',fmt(r.dispatch?.expired)],['مهلة 3 دقائق',fmt(r.dispatch?.three_minute)],['مهلة 10 دقائق',fmt(r.dispatch?.ten_minute)],['طلبات الإسناد اليدوي الموثقة',fmt(r.assignment_review?.manual_requests)],['طلبات مسندة بلا سجل يدوي',fmt(r.assignment_review?.assigned_without_manual_record)],['إسناد مباشر خاص موثق',fmt(r.assignment_review?.special_direct_confirmed)]])+
 '<p class="r-muted">عدم وجود سجل إسناد يدوي لا يثبت وحده أن الإسناد تلقائي أو خاص. لا تُحتسب الحالات غير الموثقة كوقائع مؤكدة.</p>'+
 '<h4>الإضافات</h4>'+cards([['عدد الإضافات',fmt(r.additions?.count)],['المفوترة',fmt(r.additions?.invoiced_count)],...(allowed('finance')||r.role==='driver'&&allowed('drivers')?[['قيمة الإضافات المفوترة',cash(r.additions?.invoiced_value)]]:[]),['متوسط الاعتماد (دقائق)',fmt(r.additions?.avg_minutes)]])+
 (r.invoice_review?'<h4>مراجع MicroPOS غير الموثقة (اختياري)</h4>'+table([['الطلب',x=>x.order_number],['الفرع',x=>x.branch_name]],r.invoice_review)+'<p class="r-muted">غياب المرجع يحتاج مراجعة عند استخدام MicroPOS؛ لا يعني إلغاء أو عجزاً.</p>':'')+
 (!r.partial_order_filter&&!r.filters?.driver&&['manager','supervisor','customer_service'].includes(r.role)?'<h4>حجوزات الاستلام المستقلة</h4>'+cards([['الحجوزات',fmt(r.reservation_summary?.total)],['تم الاستلام',fmt(r.reservation_summary?.collected)],['ملغاة',fmt(r.reservation_summary?.cancelled)],['قيد المتابعة',fmt(r.reservation_summary?.pending)]])+'<p class="r-muted">لا تدخل الحجوزات في توزيع الموصلين أو رسوم التوصيل.</p>':'')));
if(selectedSet.has('branches'))html.push(section('branches',table([['الفرع',x=>x.branch_name],['الكل',x=>fmt(x.orders)],['مسلّمة',x=>fmt(x.delivered)],['ملغاة',x=>fmt(x.cancelled)],...(allowed('finance')?[['قيمة الفواتير المسجلة',x=>cash(x.net)],['متوسط الفاتورة',x=>cash(x.average_order)]]:[])],r.branch_rows)));
if(selectedSet.has('drivers')){
 const top=(r.drivers||[]).slice().sort((a,b)=>Number(b.delivered)-Number(a.delivered))[0];
 // Balanced score is shown ONLY when attendance, internal reviews, and at least 3 completed jobs exist.
 const candidates=(r.drivers||[]).map(d=>({
  ...d,internal:(r.internal_driver_ratings||[]).find(x=>x.driver_id===d.driver_id),
  hours:(r.attendance||[]).filter(x=>x.driver_id===d.driver_id).reduce((a,x)=>a+Number(x.work_hours||0),0)
 })).filter(d=>d.delivered>=3&&Number(d.internal?.ratings)>=1&&d.hours>0&&d.average_minutes>0);
 const maxJobs=Math.max(1,...candidates.map(d=>Number(d.delivered)));
 const maxHours=Math.max(1,...candidates.map(d=>d.hours));
 const evaluated=candidates.map(d=>({name:d.driver_name,score:Math.round(100*(.25*Number(d.delivered)/maxJobs+.25*Math.min(1,30/Number(d.average_minutes))+.25*Number(d.internal.average_stars)/5+.25*d.hours/maxHours))})).sort((a,b)=>b.score-a.score);
 const champion=evaluated.length>=2?evaluated[0]:null;
 const fast=(r.drivers||[]).filter(x=>Number(x.delivered)>=2&&x.average_minutes!=null).sort((a,b)=>Number(a.average_minutes)-Number(b.average_minutes))[0];
 html.push(section('drivers','<p class="r-muted">الأكثر إنجازاً: '+safe(top?.driver_name||'غير متاح')+' | الأسرع بالمتوسط (طلبان على الأقل): '+safe(fast?.driver_name||'بيانات غير كافية')+'. تصنيف الأداء الشامل: '+safe(champion?champion.name+' — '+champion.score+'/100':'لا توجد بيانات كافية للترتيب العادل')+'. طريقة الترتيب عند توفر البيانات لموصلين اثنين على الأقل: 25% إنجاز، 25% سرعة، 25% تقييم داخلي، 25% ساعات عمل، بحد أدنى 3 طلبات وتقييم موثق ودوام.</p>'+
 table([['الموصل',x=>x.driver_name],['المسندة',x=>fmt(x.assigned)],['المنجزة',x=>fmt(x.delivered)],...(allowed('finance')||r.role==='driver'?[['رسوم مستحقة',x=>cash(x.delivery_fees_due)],['قيمة الفواتير المسجلة',x=>cash(x.invoice_value)],['متوسط الفاتورة',x=>cash(x.average_order)]]:[]),['متوسط التوصيل بالدقائق',x=>fmt(x.average_minutes)],...(allowed('ratings')?[['متوسط تقييم الطلب',x=>fmt(x.average_rating)]]:[])],r.drivers)+
(allowed('ratings')?'<h4>تقييمات الموصلين الداخلية</h4>'+table([['الموصل',x=>x.driver_name],['مرات التقييم',x=>fmt(x.ratings)],['متوسط النجوم',x=>fmt(x.average_stars)],['التقييمات المنخفضة',x=>fmt(x.low_ratings)]],r.internal_driver_ratings):'')+
 '<h4>عروض الإسناد حسب الموصل</h4>'+table([['الموصل',x=>x.driver_name],['المرسلة',x=>fmt(x.offered)],['المقبولة',x=>fmt(x.accepted)],['المرفوضة',x=>fmt(x.rejected)],['المنتهية',x=>fmt(x.expired)],['متوسط الرد بالثواني',x=>fmt(x.avg_response_seconds)]],r.dispatch_by_driver)+
 (r.settlements?'<h4>التسويات والتحصيل الموثق</h4>'+table([['الموصل',x=>x.driver_name],['التسويات',x=>fmt(x.statements)],['المبلغ المستحق المسجل',x=>cash(x.cash_due)],['المبلغ المستلم المسجل (يشمل المسودة)',x=>cash(x.cash_received)],['التحصيل المؤكد من المقفلة',x=>cash(x.confirmed_received)],['رسوم مؤكدة بإثبات',x=>cash(x.confirmed_delivery_fees)],['الفرق المثبت',x=>cash(x.confirmed_difference)],['التسويات المقفلة',x=>fmt(x.closed_statements)]],r.settlements)+'<p class="r-muted">تاريخ التسوية هو تاريخ التسليم المحلي وليس يوم إنشاء الطلب؛ لا تنسب التسويات الكلية إلى فلتر جزئي.</p>':'')
 ))}
if(selectedSet.has('staff'))html.push(section('staff',table([['الموظف',x=>x.staff_name],['الطلبات',x=>fmt(x.orders)],['الملغاة',x=>fmt(x.cancelled)],['المتأخرة',x=>fmt(x.late)],['متوسط الإنشاء حتى الإرسال (دقائق)',x=>fmt(x.average_process_minutes)],['التعديلات الموثقة',x=>fmt(x.changes)]],r.service_staff)));
if(selectedSet.has('areas'))html.push(section('areas','<h4>مناطق التوصيل</h4>'+table([['المنطقة',x=>x.area_name],['الطلبات',x=>fmt(x.orders)],['منجزة',x=>fmt(x.delivered)],['العملاء الجدد',x=>fmt(x.new_customers)]],r.areas)+
 (r.customers?.length?'<h4>العملاء المتكررون</h4>'+table([['العميل',x=>x.customer_name],['الرقم المخفي',x=>x.phone_masked],['الطلبات',x=>fmt(x.orders)]],r.customers):'')));
if(selectedSet.has('items'))html.push(section('items',table([['الصنف',x=>x.item_name],['الكمية',x=>fmt(x.quantity)],...(allowed('finance')?[['قيمة الأصناف المسجلة',x=>cash(x.revenue)]]:[])],r.items)+'<h4>أداء العروض المثبتة في أسطر الطلبات</h4>'+table([['العرض',x=>x.offer_name],['عدد الطلبات',x=>fmt(x.orders)],['الكمية',x=>fmt(x.quantity)],...(allowed('finance')?[['القيمة المسجلة',x=>cash(x.registered_value)]]:[])],r.offer_performance)+'<p class="r-muted">يبدأ إثبات اسم العرض من الإصدار الحالي. لا يعاد تصنيف الطلبات القديمة أو الأسماء الملتبسة كترويج مؤكد.</p>'));
if(selectedSet.has('ratings'))html.push(section('ratings',cards([['أعلى تقييم للطلب',fmt(t.rating_max)],['أدنى تقييم للطلب',fmt(t.rating_min)],['المتوسط',fmt(t.rating_avg)],['المنخفضة بنجمتين أو أقل',fmt(t.low_ratings)]])+
 table([['الطلب',x=>x.order_number],['النجوم',x=>x.rating],...(r.role==='manager'?[['الملاحظة',x=>x.rating_note||'دون تعليق']]:[]),['الوقت',x=>stamp(x.created_at)]],r.low_ratings)+
 '<h4>تقييمات الموظفين المنخفضة</h4>'+table([['الطلب',x=>x.order_number],['الفرع',x=>x.branch_name],['الدور',x=>x.rater_role],['النجوم',x=>x.stars],...(r.role==='manager'?[['ملاحظة خاصة',x=>x.note||'—']]:[]),['الوقت',x=>stamp(x.rated_at)]],r.internal_low_ratings)+
 '<h4>تقييم الموصل للتنسيق والخدمة</h4>'+table([['الطلب',x=>x.order_number],['خدمة العملاء',x=>x.customer_service_stars],['الكاشير',x=>x.cashier_stars],['العميل',x=>x.customer_stars],['عام',x=>x.overall_stars],...(r.role==='manager'?[['ملاحظة خاصة',x=>x.note||'—']]:[])],r.driver_feedback)+
 '<h4>تقييم الكاشير للتنسيق مع التحضير</h4>'+table([['الطلب',x=>x.order_number],['الفرع',x=>x.branch_name],['النجوم',x=>x.stars],...(r.role==='manager'?[['ملاحظة خاصة',x=>x.note||'—']]:[]),['الوقت',x=>stamp(x.created_at)]],r.cashier_coordination)+
 '<p class="r-muted">التقييمات اختيارية؛ لا يترتب عليها إلغاء الطلب أو عقوبة تلقائية.</p>'));
if(selectedSet.has('cases'))html.push(section('cases','<h4>الشكاوى المرتبطة بالطلبات</h4>'+table([['الموضوع',x=>x.subject],['الطلب',x=>x.order_number||'بدون طلب'],['الفرع',x=>x.branch_name],['الحالة',x=>x.status]],r.complaints)+
 '<h4>تظلمات الموصلين</h4>'+table([['التصنيف',x=>x.category],['التفاصيل',x=>x.details],['الحالة',x=>x.status]],r.grievances)+'<h4>تظلمات الموظفين الخاصة</h4>'+table([['الموضوع',x=>x.subject],['الحالة',x=>x.status],['الوقت',x=>stamp(x.created_at)]],r.staff_grievances)));
if(selectedSet.has('attendance'))html.push(section('attendance','<p class="r-muted">صافي الحضور = مجموع فترات الحضور في اليوم التشغيلي بعد طرح الاستراحات. البيانات القديمة غير الموثقة لا يمكن استرجاعها.</p>'+
 table([['اليوم',x=>x.report_day],['الموصل',x=>x.driver_name],['فترات الحضور',x=>fmt(x.sessions)],['الحضور الفعلي',x=>stamp(x.first_checkin)],['آخر خروج',x=>stamp(x.last_checkout)],['صافي الساعات',x=>fmt(x.work_hours)]],r.attendance)));
if(selectedSet.has('analytics'))html.push(section('analytics','<h4>الطلبات '+safe(el('ff76Trend').selectedOptions[0]?.textContent)+'</h4>'+barChart(trend(),'orders')+(allowed('finance')?'<h4>الفواتير المسلّمة</h4>'+barChart(trend(),'net'):'')+
'<h4>أوقات الذروة</h4>'+barChart((r.hourly||[]).map(x=>({label:String(x.hour_of_day).padStart(2,'0')+':00',orders:Number(x.orders)})),'orders')+
'<p class="r-muted">نسبة الطلبات «المؤجلة» لا تُحسب دون حالة تأجيل مستقلة موثقة في قاعدة البيانات.</p>'));
if(selectedSet.has('comparisons')){
 const c=r.comparison||{},today=c.today||{},old=c.yesterday||{},week=c.last_week||{},avgWeek=c.previous_week_average||{};
 html.push(section('comparisons',table([['الفترة',x=>x.label],['الطلبات',x=>fmt(x.orders)],['المسلّمة',x=>fmt(x.delivered)],...(allowed('finance')?[['القيمة',x=>cash(x.net)]]:[])],[{label:'نهاية الفترة',...today},{label:'اليوم السابق',...old},{label:'نفس اليوم الأسبوع الماضي',...week},{label:'متوسط السبعة أيام السابقة',...avgWeek}])+
 cards([['تغيير الطلبات عن أمس',percentage(today.orders,old.orders)],...(allowed('finance')?[['تغيير قيمة الفواتير عن أمس',percentage(today.net,old.net)]]:[]),['الفرق عن الأسبوع الماضي',percentage(today.orders,week.orders)],['الفرق عن متوسط الأسبوع',percentage(today.orders,avgWeek.orders)]])+
 '<p class="r-muted">المقارنة تخص تاريخ نهاية الفترة المختارة فقط.</p>'))}
if(selectedSet.has('approval'))html.push(section('approval',r.approval?.approved_at?
 '<div class="r-stamp"><b>اعتماد إداري: '+safe(r.approval.manager_name||'المدير')+'</b><div>تاريخ الاعتماد '+safe(stamp(r.approval.approved_at))+'</div><p>'+safe(r.approval.manager_notes)+'</p></div>':
 '<p class="r-muted">لم يعتمد هذا التقرير إدارياً بعد.</p>'));
if(selectedSet.has('summary')||selectedSet.has('comparisons'))html.push('<section class="r-section"><h3>المؤشر الإداري والخاتمة والتوصيات</h3><p class="r-muted">توصيات تشغيلية للمدير والمشرف وخدمة العملاء بحسب المؤشرات، وتحتاج مراجعة مسؤول معتمد.</p><ul>'+recommendations(t).map(x=>'<li>'+safe(x)+'</li>').join('')+'</ul></section>');
return html.join('')}
function draw(){if(!result)return;el('ff76Body').innerHTML=compose(selected())||'<p class="r-muted">حدد قسماً واحداً على الأقل.</p>';
const allowedApproval=allowed('approval')&&result.role==='manager'&&el('ff76From').value===el('ff76To').value&&!el('ff76Driver').value&&!partial();
 el('ffA10Grants').hidden=result.role!=='manager';
 if(result.role==='manager'&&selected().includes('ratings')&&(result.internal_low_ratings||[]).some(x=>x.rating_id)){const box=document.createElement('div');box.className='r-actions';box.dataset.a10Action='quality';const label=document.createElement('label');label.textContent='تصعيد يدوي لتقييم منخفض (لا يصدّر)';const select=document.createElement('select');select.id='ffA10RatingEscalate';for(const r of result.internal_low_ratings.filter(x=>x.rating_id))select.add(new Option('#'+r.order_number+' — '+r.stars+' نجوم · '+r.rater_role,r.rating_id));label.append(select);const btn=document.createElement('button');btn.type='button';btn.textContent='إنشاء متابعة جودة';btn.onclick=async()=>{const note=prompt('اكتب سبب المتابعة التشغيلية دون نقل الملاحظة الخاصة');if(note===null)return;const who=me(),tag=identity;btn.disabled=true;try{const v=await rpc('ff_a10_escalate_rating',{p_rating:select.value,p_note:note});if(who===me()&&tag===identity){el('ff76Status').textContent=v.already_exists?'توجد متابعة سابقة':'تم إنشاء متابعة جودة في مركز الشكاوى';}}catch(e){if(who===me()&&tag===identity)el('ff76Status').textContent=e.message}finally{btn.disabled=false}};box.append(label,btn);el('ff76Body').append(box)}
el('ff76ApprovalBox').hidden=!allowedApproval;
['ff76Preview','ff76Download','ff76Share','ff76CSV','ff76Excel'].forEach(id=>el(id).disabled=!selected().length)}
async function load(){
 if(!me()||pending)return;
 const from=el('ff76From').value,to=el('ff76To').value,branch=el('ff76Branch').value||null,driver=el('ff76Driver').value||null;
 const days=(new Date(to+'T12:00:00Z')-new Date(from+'T12:00:00Z'))/86400000;
 if(!from||!to||from>to||to>day()||days>89){el('ff76Status').textContent='فترة غير صحيحة؛ يجب ألا تتجاوز 90 يوماً ولا تشمل المستقبل.';return}
 const viewer=me(),request=++reportRequest;pending=true;el('ff76Run').disabled=true;clear();el('ff76Status').textContent='جاري جمع البيانات بحسب صلاحيات المستخدم...';
 try{
 const requested=args(),data=await rpc('ff_a10_reporting_center',requested);
 if(request!==reportRequest||me()!==viewer)return;
 if(!data?.totals||!Array.isArray(data.available_sections))throw Error('استجابة التقرير غير صالحة');
 snapshotArgs=requested;result=data;identity=viewer+':'+request+':'+from+':'+to+':'+String(branch)+':'+String(driver);
 el('ff76ManagerName').value=data.approval?.manager_name||'';el('ff76ManagerNotes').value=data.approval?.manager_notes||'';
 options('ff76Branch',data.branches,'name','id','جميع الفروع المسموحة');if(branch)el('ff76Branch').value=branch;
 options('ff76Driver',(data.driver_options||[]).filter(x=>!branch||x.branch_id===branch),'name','id','جميع الموصلين');if(driver)el('ff76Driver').value=driver;
 const fo=data.filter_options||{};options('ffA10Staff',fo.staff,'name','id','جميع الموظفين المخولين');options('ffA10Area',(fo.areas||[]).map(x=>({name:x,id:x})),'name','id','جميع المناطق');options('ffA10Item',(fo.items||[]).map(x=>({name:x,id:x})),'name','id','جميع الأصناف');el('ffA10StaffWrap').hidden=!fo.staff?.length;
 if(data.role==='manager')void refreshGrants(request);
 el('ff76DriverWrap').hidden=!(data.driver_options||[]).length;
 const content=await window.ffContentStudio?.reportText(branch)||{};if(request!==reportRequest||me()!==viewer)return;reportContent=content;
 choices();draw();void refreshPresets(request);
 el('ff76Status').textContent=(reportContent['reports.success']||'تقرير')+' '+from+' إلى '+to+' | '+data.scope+' | '+fmt(data.totals.orders)+' طلب. مصدر البيانات: Supabase · '+stamp(data.generated_at)+' · بيانات تشغيلية وليست إقفالات محاسبية.';
 }catch(e){if(request!==reportRequest||me()!==viewer)return;clear();el('ff76Status').textContent=(window.ffContentStudio?.text('reports.error','تعذر إعداد التقرير',branch)||'تعذر إعداد التقرير')+': '+(e.message||e)}finally{if(request===reportRequest){pending=false;el('ff76Run').disabled=false}}
}
function open(){if(!me()){typeof toast==='function'&&toast('سجّل الدخول أولاً');return}el('ff40ReportsPanel')?.classList.add('hidden');const special=typeof ffV12AssemblyActive!=='undefined'&&ffV12AssemblyActive?el('ffV12AssemblyWorkspace'):window.ffBurgerActive?.()?el('ffBurgerKitchenWorkspace'):null;if(special&&!special.contains(root))special.append(root);else if(!special&&anchor&&root.parentNode!==anchor.parentNode)anchor.after(root);root.classList.remove('ff76-hidden');
if(!el('ff76From').value)period(1,0);root.scrollIntoView({behavior:'smooth',block:'start'});if(!result)void load()}
window.ff76OpenReports=open;
el('ff76Close').onclick=()=>{root.classList.add('ff76-hidden');reportRequest++;pending=false;el('ff76Run').disabled=false;clear();el('ff76Status').textContent='حدد الفترة واضغط إعداد التقرير.'};
[['ff76Today',1,0],['ff76Yesterday',1,-1],['ff76Seven',7,0],['ff76Thirty',30,0]].forEach(x=>el(x[0]).onclick=()=>{period(x[1],x[2]);void load()});
el('ff76Run').onclick=load;['ff76From','ff76To','ff76Branch','ff76Driver','ffA10Staff','ffA10Area','ffA10Item','ffA10Status'].forEach(id=>el(id).addEventListener('change',()=>{if(id==='ff76Branch'){el('ff76Driver').value='';for(const key of ['ffA10Staff','ffA10Area','ffA10Item'])el(key).value=''}invalidate()}));
el('ff76Mode').onchange=()=>{choices();clearPDF();draw()};el('ff76Trend').onchange=()=>{clearPDF();draw()};
el('ff76SaveApproval').onclick=async()=>{if(!result||!allowed('approval')||result.role!=='manager'||el('ff76From').value!==el('ff76To').value||el('ff76Driver').value||partial())return;
const uid=me(),tag=identity;el('ff76SaveApproval').disabled=true;
try{const res=await rpc('ff76_report_approval_save',{p_day:el('ff76To').value,p_branch:el('ff76Branch').value||null,p_notes:el('ff76ManagerNotes').value,p_manager_name:el('ff76ManagerName').value});
if(me()!==uid||tag!==identity)return;result.approval={...res,manager_notes:res.notes};el('ff76ManagerName').value=result.approval.manager_name||'';el('ff76ManagerNotes').value=result.approval.manager_notes||'';clearPDF();draw();el('ff76ApprovalStatus').textContent='تم توثيق اعتماد المدير وتاريخ حفظه.'+(reportContent['reports.approval_success']?' — '+reportContent['reports.approval_success']:'')}
catch(e){if(me()===uid&&tag===identity)el('ff76ApprovalStatus').textContent='فشل الاعتماد: '+e.message+(reportContent['reports.approval_error']?' — '+reportContent['reports.approval_error']:'')}finally{if(me()===uid&&tag===identity)el('ff76SaveApproval').disabled=false}};
let grantsData=null;
 async function refreshGrants(request){const who=me();try{const value=await rpc('ff_a10_report_grants');if(request!==reportRequest||who!==me()||result?.role!=='manager')return;grantsData=value;options('ffA10GrantUser',value.accounts,'name','id','اختر حسابًا');options('ffA10GrantSection',Object.entries(headings).map(([id,name])=>({id,name})),'name','id','اختر قسمًا');showGrant()}catch(e){if(request===reportRequest&&who===me())el('ffA10GrantStatus').textContent=e.message}}
 function showGrant(){const g=grantsData?.grants?.find(x=>x.user_id===el('ffA10GrantUser').value&&x.section===el('ffA10GrantSection').value);el('ffA10GrantAllowed').value=g?String(g.allowed):'inherit'}
 el('ffA10GrantUser').onchange=el('ffA10GrantSection').onchange=showGrant;el('ffA10GrantSave').onclick=async()=>{const who=me(),req=reportRequest;const u=el('ffA10GrantUser').value,section=el('ffA10GrantSection').value,choice=el('ffA10GrantAllowed').value;if(!u||!section||result?.role!=='manager')return;try{await rpc('ff_a10_report_grant',{p_user:u,p_section:section,p_allowed:choice==='inherit'?null:choice==='true'});if(who===me()&&req===reportRequest){await refreshGrants(req);el('ffA10GrantStatus').textContent='تم حفظ التفويض'}}catch(e){if(who===me()&&req===reportRequest)el('ffA10GrantStatus').textContent=e.message}};
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
 if(/^[\t\r\n]|^[\s\u0000-\u001f\u061c\u200b-\u200f\u202a-\u202e\u2060-\u206f]*[=+@\-＝＋＠－]/u.test(text))text="'"+text;
 return '"'+text.replace(/"/g,'""')+'"';
}
// Both files are produced from the same permission-filtered rendered report.
function exportRows(){
 const rows=[['التقرير',result.from,result.to,result.scope],['مصدر البيانات','Supabase','وقت البيانات',stamp(result.generated_at)],['الفلاتر',filterText()]];
 const scratch=document.createElement('div');scratch.innerHTML=compose(selected());
 for(const section of scratch.querySelectorAll('section')){
  rows.push([], [section.querySelector('h3')?.textContent]);
  for(const node of section.querySelectorAll('h4,.r-kpi,tr,p,li,.r-barcol')){
   if(node.matches('tr'))rows.push(Array.from(node.children,x=>x.textContent));
   else if(node.matches('.r-kpi,.r-barcol'))rows.push(Array.from(node.children,x=>x.textContent).filter(Boolean));
   else rows.push([node.textContent]);
  }
 }
 return rows;
}
// Minimal OOXML workbook: inline strings cannot become formulas or hyperlinks.
// ZIP STORE (no external script or network), UTF-8, RTL, exact displayed values.
function excelBlob(rows){
 const encoder=new TextEncoder(),xml=s=>String(s??'').replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\ufffe\uffff]/g,'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&apos;');
 const col=i=>{let c='';for(i++;i>0;i=Math.floor((i-1)/26))c=String.fromCharCode(65+(i-1)%26)+c;return c};
 const ns='http://schemas.openxmlformats.org/spreadsheetml/2006/main',rel='http://schemas.openxmlformats.org/officeDocument/2006/relationships',pkg='http://schemas.openxmlformats.org/package/2006/relationships',decl='<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
 const width=Math.max(1,...rows.map(r=>r.length));
 const sheet=decl+'<worksheet xmlns="'+ns+'"><sheetViews><sheetView rightToLeft="1" workbookViewId="0"/></sheetViews><cols><col min="1" max="1" width="42" customWidth="1"/>'+(width>1?'<col min="2" max="'+width+'" width="25" customWidth="1"/>':'')+'</cols><sheetData>'+rows.map((row,i)=>'<row r="'+(i+1)+'">'+row.map((v,j)=>'<c r="'+col(j)+(i+1)+'" t="inlineStr"><is><t xml:space="preserve">'+xml(v)+'</t></is></c>').join('')+'</row>').join('')+'</sheetData></worksheet>';
 const files=[
 ['[Content_Types].xml',decl+'<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>'],
 ['_rels/.rels',decl+'<Relationships xmlns="'+pkg+'"><Relationship Id="rId1" Type="'+rel+'/officeDocument" Target="xl/workbook.xml"/></Relationships>'],
 ['xl/workbook.xml',decl+'<workbook xmlns="'+ns+'" xmlns:r="'+rel+'"><sheets><sheet name="التقرير التشغيلي" sheetId="1" r:id="rId1"/></sheets></workbook>'],
 ['xl/_rels/workbook.xml.rels',decl+'<Relationships xmlns="'+pkg+'"><Relationship Id="rId1" Type="'+rel+'/worksheet" Target="worksheets/sheet1.xml"/></Relationships>'],
 ['xl/worksheets/sheet1.xml',sheet]];
 const crcTable=Uint32Array.from({length:256},(_,i)=>{for(let j=0;j<8;j++)i=(i>>>1)^((i&1)?0xedb88320:0);return i>>>0});
 const crc32=bytes=>{let crc=0xffffffff;for(const x of bytes)crc=(crc>>>8)^crcTable[(crc^x)&255];return(crc^0xffffffff)>>>0};
 const header=n=>{const buf=new Uint8Array(n),v=new DataView(buf.buffer);return {buf,u16:(p,x)=>v.setUint16(p,x,true),u32:(p,x)=>v.setUint32(p,x,true)}};
 const local=[],central=[];let offset=0,centralSize=0;
 for(const [name,value] of files){
  const n=encoder.encode(name),bytes=encoder.encode(value),crc=crc32(bytes),l=header(30),c=header(46);
  l.u32(0,0x04034b50);l.u16(4,20);l.u16(6,0x800);l.u16(12,0x21);l.u32(14,crc);l.u32(18,bytes.length);l.u32(22,bytes.length);l.u16(26,n.length);
  c.u32(0,0x02014b50);c.u16(4,20);c.u16(6,20);c.u16(8,0x800);c.u16(14,0x21);c.u32(16,crc);c.u32(20,bytes.length);c.u32(24,bytes.length);c.u16(28,n.length);c.u32(42,offset);
  local.push(l.buf,n,bytes);central.push(c.buf,n);offset+=30+n.length+bytes.length;centralSize+=46+n.length;
 }
 const end=header(22);end.u32(0,0x06054b50);end.u16(8,files.length);end.u16(10,files.length);end.u32(12,centralSize);end.u32(16,offset);
 return new Blob([...local,...central,end.buf],{type:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'});
}
async function exportTable(format){
 if(!result||!selected().length||!identity.startsWith(me()+':'))return;
 const uid=me(),tag=identity,revision=pdfRevision;
 try{
  await verifyExport(uid,tag,revision);authorized(uid,tag,revision);
  const rows=exportRows(),blob=format==='xlsx'?excelBlob(rows):new Blob(['\uFEFF',rows.map(row=>row.map(csvField).join(',')).join('\r\n')],{type:'text/csv;charset=utf-8'});
  const link=document.createElement('a');link.href=URL.createObjectURL(blob);link.download='FreshFries_'+result.from+'_'+result.to+'.'+format;
  link.click();setTimeout(()=>URL.revokeObjectURL(link.href),5000);
 }catch(e){if(me()===uid)el('ff76Status').textContent=e.message;}
}
el('ff76CSV').onclick=()=>exportTable('csv');
el('ff76Excel').onclick=()=>exportTable('xlsx');
window.addEventListener('ff-luxe-session-reset',()=>{
 presets=[];el('ff76PresetList').replaceChildren();el('ff76PresetName').value='';el('ff76PresetStatus').textContent='';
});
function pdfLibrary(){if(window.html2pdf)return Promise.resolve();if(libPromise)return libPromise;
libPromise=new Promise((resolve,reject)=>{const s=document.createElement('script');s.src='https://cdn.jsdelivr.net/npm/html2pdf.js@0.10.1/dist/html2pdf.bundle.min.js';s.onload=()=>window.html2pdf?resolve():reject(Error('مكتبة PDF غير جاهزة'));s.onerror=()=>reject(Error('مكتبة PDF تحتاج اتصالاً بالإنترنت'));document.head.append(s)}).catch(e=>{libPromise=null;throw e});return libPromise}
function filterText(){const labels=['ff76Branch','ff76Driver','ffA10Staff','ffA10Area','ffA10Item','ffA10Status'];return labels.filter(id=>el(id).value).map(id=>el(id).selectedOptions[0]?.textContent).filter(Boolean).join(' · ')||'جميع النطاقات المسموحة'}
 async function verifyExport(uid,tag,revision){authorized(uid,tag,revision);if(!result||!identity.startsWith(uid+':'))throw Error('أعد التقرير');if(JSON.stringify(args())!==JSON.stringify(snapshotArgs)){clear();throw Error('تغيرت عوامل التصفية؛ أعد إعداد التقرير')}const prior=result;let check;try{check=await rpc('ff_a10_reporting_center',args())}catch(e){if(me()===uid&&identity===tag){clear();el('ff76Status').textContent='تغيرت الصلاحيات؛ أعد التقرير'}throw e}authorized(uid,tag,revision);if(!check||check.role!==prior.role||check.access_key!==prior.access_key||JSON.stringify(check.available_sections)!==JSON.stringify(prior.available_sections)){clear();throw Error('تغيرت الصلاحيات أو النطاق؛ أعد إعداد التقرير قبل التصدير')}
 // A branch/role hash alone cannot detect row ownership or note changes.
 // Reject a stale file if any identity-bearing/private detail changed. Timers
 // remain an explicitly dated snapshot; time-only changes don't invalidate it.
 const details=['customers','cancellations','free_delivery_orders','fastest','late_orders','invoice_review','low_ratings','internal_low_ratings','driver_feedback','cashier_coordination','complaints','grievances','staff_grievances','approval','settlements','finance_evidence'];
 const canonical=(v)=>Array.isArray(v)?v.map(canonical).sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b))):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).filter(k=>k!=='delivery_minutes').sort().map(k=>[k,canonical(v[k])])):v;
 if(details.some(k=>JSON.stringify(canonical(prior[k]))!==JSON.stringify(canonical(check[k])))){clear();throw Error('تغيرت تفاصيل التقرير؛ أعد إعداده قبل التصدير أو المشاركة')}
 return true}
 function authorized(uid,tag,revision){if(me()!==uid||identity!==tag||revision!==pdfRevision)throw Error('تغير الحساب أو التقرير')}
async function producePDF(){if(pdf)return pdf;if(pdfPromise)return pdfPromise;if(!result||!me()||!identity.startsWith(me()+':')||!selected().length)throw Error('أعد التقرير وحدد أقسامه');
const uid=me(),tag=identity,revision=pdfRevision;pdfPromise=(async()=>{
 await verifyExport(uid,tag,revision);await pdfLibrary();authorized(uid,tag,revision);
 const content=await window.ffContentStudio?.reportText(el('ff76Branch').value||null)||{};authorized(uid,tag,revision);
 const page=document.createElement('div');page.dir='rtl';page.lang='ar';
 page.style.cssText='width:720px;background:#fff;color:#181818;padding:25px;font:14px Tahoma,Arial,sans-serif;line-height:1.7;position:relative;box-sizing:border-box;max-width:none';
 page.innerHTML='<div style="border-bottom:4px solid #c51b30;padding:10px 0;margin-bottom:15px"><h1>'+safe(content['reports.pdf_title']||'FRESH FRIES LUXE — مركز التقارير')+'</h1><b>'+safe(result.from)+' إلى '+safe(result.to)+'</b><p>'+safe(result.scope)+'</p><p>مصدر البيانات: Supabase · '+safe(stamp(result.generated_at))+'</p><p>الفلاتر: '+safe(filterText())+'</p></div>'+
 '<style>.r-section{border:1px solid #ccc;padding:10px;margin:12px 0;break-inside:auto}.r-section h3{border-right:4px solid #c51b30;padding-right:8px}.r-kpis{display:flex;flex-wrap:wrap;gap:7px}.r-kpi{border:1px solid #ddd;padding:8px;min-width:135px}.r-kpi b{display:block;font-size:18px}.r-scroll{overflow:visible}table{border-collapse:collapse;width:100%;font-size:11px}th,td{text-align:right;border:1px solid #ddd;padding:7px;overflow-wrap:anywhere}th{background:#eee}.r-muted{font-size:11px;color:#444}.r-bars{display:flex;align-items:flex-end;height:150px}.r-barcol{height:150px;width:65px;display:flex;flex-direction:column;align-items:center;justify-content:flex-end}.r-bar{width:34px;background:#c51b30}.r-barcol span{font-size:10px}.r-stamp{border:2px dashed #c51b30;padding:9px}</style>'+
 compose(selected(),content)+(content['reports.pdf_note']?'<p class="r-muted">'+safe(content['reports.pdf_note'])+'</p>':'')+'<footer style="margin-top:20px;border-top:1px solid #ddd">فريش فرايز — تقرير تشغيلي لا يثبت التحصيل المالي.</footer>';
 const staging=document.createElement('div');staging.dataset.ff76ExportLayer='staging';staging.style.cssText='position:fixed;inset:0;overflow:auto;background:white;z-index:2147483000;pointer-events:none';staging.append(page);document.body.append(staging);
 let overlay;
 try{
 const worker=window.html2pdf().set({margin:8,filename:'FreshFries_LUXE_'+result.from+'_'+result.to+'.pdf',
 html2canvas:{scale:1.25,logging:false,windowWidth:800,scrollX:0,scrollY:0,backgroundColor:'#ffffff'},jsPDF:{unit:'mm',format:'a4',orientation:'portrait'},
 pagebreak:{mode:['css','legacy'],avoid:['tr','.r-kpi']}}).from(page);
 await worker.toContainer();
 const container=await worker.get('container');overlay=await worker.get('overlay');overlay.dataset.ff76ExportLayer='render';authorized(uid,tag,revision);
 Object.assign(overlay.style,{opacity:'1',backgroundColor:'#ffffff',zIndex:'2147483001',overflow:'auto'});
 Object.assign(container.style,{position:'relative',left:'0',right:'auto',top:'0',margin:'0'});
 const canvas=await worker.toCanvas().get('canvas');
 const pixels=canvas.getContext('2d').getImageData(0,0,canvas.width,canvas.height).data;
 let ink=0;for(let i=0;i<pixels.length;i+=32){if(pixels[i+3]>0&&Math.min(pixels[i],pixels[i+1],pixels[i+2])<180)ink++;}
 if(ink<100)throw Error('تعذر رسم محتوى التقرير؛ لم يُحفظ ملف فارغ.');
 const blob=await worker.toPdf().outputPdf('blob');
 authorized(uid,tag,revision);if(!(blob instanceof Blob)||blob.size<500)throw Error('ملف PDF غير صالح');
 pdf=blob;fileName='FreshFries_LUXE_Report_'+result.from+'_'+result.to+'.pdf';return blob
 }finally{overlay?.remove();staging.remove()}})();
 try{return await pdfPromise}finally{if(revision===pdfRevision)pdfPromise=null}}
function saveBlob(){if(!pdf||!me()||!identity.startsWith(me()+':'))return;const url=pdfURL||URL.createObjectURL(pdf),a=document.createElement('a');a.href=url;a.download=fileName;a.click();if(!pdfURL)setTimeout(()=>URL.revokeObjectURL(url),5000)}
async function download(){if(!pdf||!me())return;const uid=me(),tag=identity,revision=pdfRevision;try{await verifyExport(uid,tag,revision);saveBlob()}catch(e){if(me()===uid)el('ff76Status').textContent=e.message}}
 async function preview(){const uid=me(),tag=identity,revision=pdfRevision;el('ff76Preview').disabled=true;el('ff76Status').textContent='إعداد ملف PDF للمعاينة...';
try{await verifyExport(uid,tag,revision);await producePDF();authorized(uid,tag,revision);if(!pdfURL)pdfURL=URL.createObjectURL(pdf);el('ff76PDFFrame').src=pdfURL;if(!previewDialog.open)previewDialog.showModal();previewed=true;el('ff76Status').textContent='راجع ملف PDF قبل الإرسال.'}
catch(e){if(me()===uid&&tag===identity&&revision===pdfRevision)el('ff76Status').textContent='تعذر إنشاء PDF: '+e.message}finally{if(me()===uid&&tag===identity&&revision===pdfRevision)el('ff76Preview').disabled=!selected().length}}
async function share(){if(!pdf||!previewed){await preview();return}const uid=me(),tag=identity,revision=pdfRevision;if(!uid||!tag.startsWith(uid+':'))return;const file=new File([pdf],fileName,{type:'application/pdf'});
try{await verifyExport(uid,tag,revision);if(navigator.canShare?.({files:[file]})&&navigator.share)await navigator.share({title:'تقرير فريش فرايز',files:[file]});
else{saveBlob();el('ff76Status').textContent='بدأ حفظ PDF؛ يمكن مشاركته من مدير ملفات الجهاز.'}}catch(e){if(e.name!=='AbortError'&&me()===uid&&tag===identity&&revision===pdfRevision)el('ff76Status').textContent='لم تكتمل المشاركة: '+e.message}}
el('ff76Preview').onclick=preview;el('ff76Download').onclick=async()=>{const uid=me(),tag=identity,revision=pdfRevision;try{await producePDF();authorized(uid,tag,revision);await download()}catch(e){if(me()===uid&&tag===identity&&revision===pdfRevision)el('ff76Status').textContent=e.message}};
el('ff76Share').onclick=share;
el('ff76DlgDownload').onclick=download;el('ff76DlgShare').onclick=share;el('ff76DlgClose').onclick=()=>previewDialog.close();
previewDialog.addEventListener('close',()=>{if(!previewDialog.open)el('ff76PDFFrame').removeAttribute('src')});
window.addEventListener('ff-luxe-session-reset',()=>{reportRequest++;pending=false;el('ff76Run').disabled=false;el('ff76ManagerNotes').value='';el('ff76ManagerName').value='';el('ff76Choices').replaceChildren();choiceInitialized=false;el('ff76Mode').value='full';el('ff76Trend').value='daily';el('ff76From').value='';el('ff76To').value='';el('ff76ApprovalStatus').textContent='';el('ff76Status').textContent='حدد الفترة واضغط إعداد التقرير.';if(previewDialog.open)previewDialog.close();clear();root.classList.add('ff76-hidden');options('ff76Branch',[],'name','id','كل الفروع');options('ff76Driver',[],'name','id','كل الموصلين');for(const id of ['ffA10Staff','ffA10Area','ffA10Item'])options(id,[],'name','id','الكل');el('ffA10Status').value='';grantsData=null;el('ffA10Grants').hidden=true;el('ffA10GrantUser').replaceChildren();el('ffA10GrantSection').replaceChildren();el('ffA10GrantStatus').textContent=''});
el('ff40ReportsBtn')?.addEventListener('click',e=>{e.preventDefault();e.stopImmediatePropagation();open()},true);
for(const id of ['ffV12AssemblyWorkspace','ffBurgerKitchenWorkspace']){
 const host=el(id);if(!host)continue;const b=document.createElement('button');b.type='button';b.className='outline';b.textContent='📊 تقرير التشغيل';b.onclick=open;host.prepend(b)
}
})();