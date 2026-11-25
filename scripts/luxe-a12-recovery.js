/* A12: manager-only, branch/type/date-limited development order reset and exact recovery. */
(()=>{
'use strict';
const panel=document.getElementById('ff62DataCenter');if(!panel)return;
const n=(tag,text)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;return e};
const section=n('section');section.id='ffA12Recovery';section.hidden=true;
section.innerHTML='<h3>النسخ والاسترجاع والتصفير الانتقائي — طلبات الاختبار فقط</h3><p>بيئة التطوير: الطلبات الاصطناعية الجديدة أو مجموعة الطلبات السابقة التي أكد المالك أنها تجريبية. الحسابات والفروع والمنيو والإعدادات وسجل الأمان محفوظة. التبعيات غير المدعومة تمنع التنفيذ بالكامل.</p><label>نطاق البيانات<select id="ffA12Scope"><option value="synthetic">الطلبات الاصطناعية الجديدة</option><option value="legacy">الطلبات التجريبية السابقة (المجموعة المعتمدة)</option></select></label><p id="ffA12ScopeInfo" role="status"></p><div class="ffA12Grid"><label>الفرع<select id="ffA12Branch"></select></label><label>نوع الطلب<select id="ffA12Type"><option value="all">كل أنواع الاختبار</option><option value="delivery">توصيل</option><option value="reservation">حجز</option></select></label><label>من تاريخ (توقيت صنعاء)<input id="ffA12From" type="date"></label><label>إلى تاريخ<input id="ffA12To" type="date"></label></div><button type="button" id="ffA12Preview" class="primary">معاينة التبعيات والأعداد</button><div id="ffA12PreviewResult" aria-live="polite"></div><label><span id="ffA12ConfirmLabel">للتأكيد اكتب: تصفير طلبات الاختبار فقط</span><input id="ffA12Confirm" autocomplete="off" placeholder="تصفير طلبات الاختبار فقط"></label><button type="button" id="ffA12Execute" class="ffA12Danger" disabled>حفظ نسخة على الخادم وتصفير المحدد</button><hr><h4>النسخ المحفوظة والاسترجاع</h4><button type="button" id="ffA12List" class="outline">تحديث النسخ</button><label>اختر نسخة<select id="ffA12Batch"><option value="">اختر نسخة محفوظة</option></select></label><div id="ffA12BatchInfo"></div><label><span id="ffA12RestoreLabel">للتأكيد اكتب: استرجاع نسخة الاختبار</span><input id="ffA12RestoreConfirm" autocomplete="off"></label><button type="button" id="ffA12Restore" class="outline" disabled>استرجاع النسخة والتحقق من تطابقها</button><details id="ffA12FixturePanel"><summary>إنشاء طلب اصطناعي لاختبار التصفير</summary><p>لا تستخدم هذه الأداة للطلبات الفعلية. ينشئ الخادم طلبًا ملغيًا برقم اختبار منفصل، وصنفًا بقيمة صفر، دون ربط عميل أو موصل. يظهر في سجلات الاختبار إلى أن يتم تصفيره.</p><label>النوع<select id="ffA12FixtureType"><option value="delivery">توصيل</option><option value="reservation">حجز</option></select></label><label>تاريخ الاختبار<input type="date" id="ffA12FixtureDate"></label><label>اكتب: إنشاء طلب اختبار<input id="ffA12FixtureConfirm" autocomplete="off"></label><button type="button" id="ffA12Fixture" class="outline" disabled>إنشاء طلب الاختبار</button></details><p id="ffA12Status" role="status" aria-live="polite"></p>';
panel.append(section);
const style=n('style');style.textContent='#ffA12Recovery{border:1px solid var(--ffb-line,#bcbcbc);border-radius:12px;padding:12px;margin-top:12px;overflow-wrap:anywhere}#ffA12Recovery[hidden]{display:none!important}#ffA12Recovery label{display:grid;gap:5px;margin:8px 0;min-width:0}#ffA12Recovery input,#ffA12Recovery select{min-height:44px;width:100%;max-width:100%}#ffA12Recovery button{min-height:44px;margin:4px 0;white-space:normal}#ffA12Recovery button:disabled{opacity:.5}#ffA12Recovery .ffA12Danger{background:#a81926;color:white;font-weight:bold}#ffA12Recovery .ffA12Grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}#ffA12PreviewResult{max-height:340px;overflow:auto}#ffA12Recovery details{margin-top:12px}#ffA12Recovery summary{cursor:pointer;font-weight:bold}@media(max-width:520px){#ffA12Recovery .ffA12Grid{grid-template-columns:minmax(0,1fr)}#ffA12Recovery button{width:100%}}';document.head.append(style);
const $=id=>document.getElementById('ffA12'+id);
const labels={orders:'الطلبات',items:'الأصناف',events:'أحداث الطلب',desks:'روابط مكاتب الكاشير',
 'public.ff_orders':'الطلبات','public.ff_order_items':'أصناف الطلب','public.ff_order_events':'أحداث الطلب','public.ff_luxe_cashier_order_desks':'روابط مكاتب الكاشير',
 'public.ff_burger_tickets':'تذاكر مطبخ البرجر','public.ff_burger_ticket_events':'أحداث مطبخ البرجر','public.ff_luxe_cancel_ack':'إقرار الإلغاء',
 'public.ff_luxe_driver_cancel_skip':'تجاوز الإلغاء','public.ff_luxe_driver_feedback':'ملاحظات الموصل','public.ff_luxe_driver_grievances':'التظلمات',
 'public.ff_luxe_late_invoice_refs':'مراجع الفواتير المتأخرة','public.ff_order_customer_edits':'تعديلات بيانات الطلب',
 'ff_private.a10_cashier_coordination':'تنسيق الكاشير','public.ff_push_jobs':'سجل إشعارات الطلب','public.ff27_branch_updates':'تحديثات الفرع',
 'public.ff38_delivery_tasks':'مهام التوصيل','public.ff38_dispatch_offers':'عروض الإسناد','public.ff38_order_additions':'الإضافات',
 'public.ff38_order_addition_items':'أصناف الإضافات','public.ff38_order_cancellation_audit':'تدقيق الإلغاء','public.ff38_reject_permission_audit':'تدقيق الرفض',
 'public.ff41_cases':'الشكاوى','public.ff41_case_events':'أحداث الشكاوى','public.ff_case_alert_receipts':'إيصالات تنبيهات الشكاوى',
 'public.ff49_cashier_receipts':'إيصالات الكاشير','public.ff49_driver_transfers':'تحويلات الموصل','public.ff49_manual_dispatch_audit':'تدقيق الإسناد اليدوي',
 'public.ff49_order_details':'تفاصيل الطلبات','public.ff50_order_changes':'تغييرات الطلبات','public.ff50_order_change_events':'أحداث التغييرات',
 'public.ff51_driver_ratings':'تقييمات الموصل','public.ff52_driver_reassignment_audit':'تدقيق إعادة الإسناد',
 'public.ff52_addition_pos':'ربط الإضافات بالفواتير','public.ff52_late_addition_consent':'موافقات الإضافات المتأخرة'};
const legacy=()=>$('Scope').value==='legacy';
const deletePhrase=()=>legacy()?'تصفير البيانات التجريبية السابقة':'تصفير طلبات الاختبار فقط';
const restorePhrase=()=>legacy()?'استرجاع البيانات التجريبية السابقة':'استرجاع نسخة الاختبار';
const orderCount=c=>Number(c?.orders??c?.['public.ff_orders']??0);
const previewKey=()=>JSON.stringify([$('Scope').value,filters()]);
const typeLabel={all:'الكل',delivery:'توصيل',reservation:'حجز'};
const actor=()=>document.body.dataset.access==='staff'&&data?.role==='manager'&&user?.id?user.id:'';
let epoch=0,busy=false,preview=null,batches=[],owner='';
const today=()=>{const p=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Aden',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date());return ['year','month','day'].map(k=>p.find(x=>x.type===k).value).join('-')};
const filters=()=>({p_branch:$('Branch').value,p_type:$('Type').value,p_from:$('From').value,p_to:$('To').value});
const selectedBatch=()=>batches.find(b=>b.id===$('Batch').value);
const validFilters=()=>{const f=filters();return !!(f.p_branch&&f.p_from&&f.p_to&&f.p_from<=f.p_to)};
const status=s=>{$('Status').textContent=s};
const counts=c=>Object.entries(c||{}).map(([k,v])=>(labels[k]||k)+': '+String(v)).join(' · ');
function sync(){
 const allowed=!!actor()&&panel.open&&!busy;
 $('Scope').disabled=!allowed;
 $('Preview').disabled=!allowed||!validFilters();
 $('Execute').disabled=!allowed||!preview||preview.key!==previewKey()||!preview.result.token||!(orderCount(preview.result.counts)>0)||Object.keys(preview.result.blockers||{}).length>0||$('Confirm').value.trim()!==deletePhrase();
 $('List').disabled=!allowed;
 $('Restore').disabled=!allowed||!selectedBatch()||!!selectedBatch()?.restored_at||$('RestoreConfirm').value.trim()!==restorePhrase();
 $('Fixture').disabled=!allowed||legacy()||!$('Branch').value||!$('FixtureDate').value||$('FixtureConfirm').value.trim()!=='إنشاء طلب اختبار';
}
function invalidate(message='أعد المعاينة قبل التصفير.'){preview=null;$('Confirm').value='';$('PreviewResult').textContent=message;sync()}
function clear(){
 epoch++;busy=false;preview=null;batches=[];owner='';section.hidden=true;
 $('Branch').replaceChildren(new Option('اختر الفرع',''));$('Batch').replaceChildren(new Option('اختر نسخة محفوظة',''));
 $('BatchInfo').textContent='';$('PreviewResult').textContent='';$('Confirm').value='';$('RestoreConfirm').value='';$('FixtureConfirm').value='';status('');sync();
}
function open(){
 clear();const id=actor();if(!id)return;owner=id;section.hidden=false;
 $('Branch').replaceChildren(new Option('اختر الفرع',''),...(data?.branches||[]).map(b=>new Option(b.name,b.id)));
 $('Scope').value='synthetic';$('Type').value='all';$('FixtureDate').value=today();applyScope();
 invalidate('حدد الفرع ونوع الطلب والفترة ثم اعرض المعاينة.');void list();
}
function applyScope(){
 $('From').value=legacy()?'2026-11-13':today();$('To').value=legacy()?'2026-11-23':today();
 $('ScopeInfo').textContent=legacy()?'المجموعة السابقة المعتمدة: 82 طلباً، من 13 إلى 23 نوفمبر 2026. لا تدخل الطلبات العادية الجديدة تلقائياً. قد تمنع التبعيات أو حالة الطلب التصفير.':'طلبات الاختبار الاصطناعية المنشأة من الأداة أدناه فقط.';
 $('ConfirmLabel').textContent='للتأكيد اكتب: '+deletePhrase();$('Confirm').placeholder=deletePhrase();
 $('RestoreLabel').textContent='للتأكيد اكتب: '+restorePhrase();$('RestoreConfirm').placeholder=restorePhrase();
 $('FixturePanel').hidden=legacy();batches=[];$('Batch').replaceChildren(new Option('اختر نسخة محفوظة',''));$('BatchInfo').textContent='';$('RestoreConfirm').value='';
}
function valid(token,id){return epoch===token&&owner===id&&actor()===id&&panel.open}
async function action(fn){
 if(busy||!actor()||!panel.open||owner!==actor())return;
 const token=epoch,id=owner;busy=true;sync();status('جارٍ التحقق من قاعدة البيانات…');
 try{await fn(()=>valid(token,id))}catch(err){if(valid(token,id))status('تعذر التنفيذ: '+(err?.message||String(err)))}
 finally{if(valid(token,id)){busy=false;sync()}}
}
function renderPreview(r){
 const out=$('PreviewResult');out.replaceChildren(n('b','المعاينة قبل الحذف'),n('p',counts(r.counts)),n('p',legacy()?'إجمالي الطلبات الحالية: '+r.total_orders+' · المحددة: '+r.eligible_orders+' · خارج النطاق: '+(r.total_orders-r.eligible_orders):'إجمالي الطلبات الحالية: '+r.total_orders+' · غير المصنفة للاختبار والمحمية: '+r.protected_orders));
 const ul=n('ul');for(const o of r.orders||[])ul.append(n('li','#'+o.number+' · '+(typeLabel[o.type]||o.type)+' · '+o.date));out.append(ul);
 const blocked=Object.entries(r.blockers||{});
 if(blocked.length)out.append(n('p','تبعيات محمية تمنع التصفير: '+blocked.map(([k,v])=>k+': '+v).join(' · ')));
 else out.append(n('p',orderCount(r.counts)>0?'سيحفظ الخادم نسخة مطابقة قبل الحذف، أو يتراجع عن المعاملة بالكامل عند الفشل.':'لا توجد طلبات اختبار مؤهلة في هذه الفترة.'));
}
$('Preview').onclick=()=>action(async current=>{
 const f=filters(),key=previewKey();invalidate('جارٍ المعاينة…');
 const r=legacy()?await rpc('ff_a12_legacy_preview',f):await rpc('ff_a12_reset_preview',f);
 if(!current()||key!==previewKey())return;
 if(!r?.token||!r.counts||!Array.isArray(r.orders)||!r.blockers)throw Error('لم يؤكد الخادم نتيجة المعاينة');
 preview={key,result:r};renderPreview(r);status('المعاينة جاهزة. لا تعديل حتى التأكيد.');
});
$('Execute').onclick=()=>action(async current=>{
 const f=filters(),p=preview,confirmation=$('Confirm').value.trim();
 if(!p||p.key!==previewKey()||confirmation!==deletePhrase()||Object.keys(p.result.blockers).length||!orderCount(p.result.counts))throw Error('المعاينة والتأكيد مطلوبان');
 if(!window.confirm('سيتم حفظ نسخة آمنة وحذف طلبات الاختبار المحددة فقط. هل تريد التنفيذ؟')){status('أُلغي الإجراء.');return}
 invalidate('جارٍ حفظ النسخة والتصفير…');
 const args={...f,p_token:p.result.token,p_confirmation:confirmation};
 const r=legacy()?await rpc('ff_a12_legacy_execute',args):await rpc('ff_a12_reset_execute',args);
 if(!current())return;
 if(r?.ok!==true||r.backup_saved!==true)throw Error('لم يؤكد الخادم حفظ النسخة والتصفير');
 $('PreviewResult').replaceChildren(n('b','تم التصفير والتحقق'),n('p','المزال: '+counts(r.removed)),n('p','المتبقي من المحدد: '+counts(r.remaining_selected)),n('p','إجمالي الطلبات قبل: '+r.total_before+' · بعد: '+r.total_after),n('p','رقم النسخة: '+r.batch_id));
 status('تم الحفظ والتصفير. النسخة متاحة للاسترجاع.');await loadBatches(current,r.batch_id);
});
async function loadBatches(current,select=''){
 const r=legacy()?await rpc('ff_a12_legacy_batches'):await rpc('ff_a12_reset_batches');if(!current())return;
 if(!Array.isArray(r))throw Error('لم يؤكد الخادم قائمة النسخ');
 batches=r;const names=new Map((data?.branches||[]).map(b=>[b.id,b.name]));
 $('Batch').replaceChildren(new Option('اختر نسخة محفوظة',''),...r.map(b=>new Option((names.get(b.branch_id)||b.branch_id)+' · '+b.date_from+'–'+b.date_to+' · '+(typeLabel[b.order_type]||b.order_type)+' · '+(b.restored_at?'مسترجعة':'محفوظة')+' · '+orderCount(b.counts)+' طلب',b.id)));
 if(r.some(b=>b.id===select))$('Batch').value=select;showBatch();
}
function showBatch(){const b=selectedBatch();$('RestoreConfirm').value='';$('BatchInfo').textContent=b?(counts(b.counts)+' · '+(b.restored_at?'سبق استرجاعها':'قابلة للاسترجاع')+' · '+b.id):'';sync()}
function list(){return action(async current=>{await loadBatches(current);if(current())status('تم تحميل سجل النسخ من الخادم.')})}
$('List').onclick=list;$('Batch').onchange=showBatch;
$('Restore').onclick=()=>action(async current=>{
 const b=selectedBatch(),c=$('RestoreConfirm').value.trim();
 if(!b||b.restored_at||c!==restorePhrase())throw Error('اختر نسخة غير مسترجعة واكتب التأكيد');
 if(!window.confirm('استرجاع طلبات الاختبار من النسخة المحفوظة؟')){status('أُلغي الإجراء.');return}
 const args={p_batch:b.id,p_confirmation:c};
 const r=legacy()?await rpc('ff_a12_legacy_restore',args):await rpc('ff_a12_restore',args);
 if(!current())return;
 if(r?.ok!==true||r.exact_match!==true)throw Error('لم يؤكد الخادم تطابق الاسترجاع');
 invalidate('تم الاسترجاع بالتطابق الكامل: '+counts(r.restored));status('نجح الاسترجاع والتحقق.');await loadBatches(current,b.id);
});
$('Fixture').onclick=()=>action(async current=>{
 const f=filters(),c=$('FixtureConfirm').value.trim(),date=$('FixtureDate').value,type=$('FixtureType').value;
 if(legacy()||!f.p_branch||!date||c!=='إنشاء طلب اختبار')throw Error('الفرع والتاريخ والتأكيد مطلوبة');
 if(!window.confirm('إنشاء طلب اصطناعي ملغى، ليس طلبًا تشغيليًا؟')){status('أُلغي الإجراء.');return}
 const r=await rpc('ff_a12_create_fixture',{p_branch:f.p_branch,p_type:type,p_date:date,p_confirmation:c});
 if(!current())return;
 if(r?.test_only!==true)throw Error('لم يؤكد الخادم إنشاء طلب اختبار');
 $('FixtureConfirm').value='';invalidate('تم إنشاء طلب اختبار #'+r.number+'، أعد المعاينة.');status('تم إنشاء طلب اختبار فقط.');
});
$('Scope').onchange=()=>{if(busy)return;applyScope();invalidate();void list()};
for(const id of ['Branch','Type','From','To'])$(id).addEventListener('change',()=>invalidate());
for(const id of ['Confirm','RestoreConfirm','FixtureConfirm','FixtureDate'])$(id).addEventListener('input',sync);
new MutationObserver(()=>{if(panel.open){if(owner!==actor()||section.hidden)open()}else clear()}).observe(panel,{attributes:true,attributeFilter:['open']});
panel.addEventListener('close',()=>{if(!panel.open)clear()});
window.addEventListener('ff-luxe-session-reset',()=>{clear();if(panel.open)panel.close()});
clear();
})();
