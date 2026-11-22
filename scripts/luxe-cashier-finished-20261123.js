/* Fresh Fries LUXE — cashier finished orders with follow-up actions.
   Never reopens an operational order or silently changes a customer rating. */
'use strict';
(()=>{
 const $=id=>document.getElementById(id);
 const view=$('cashierView'),live=$('cashierOrders');
 if(!view||!live)return;
 const style=document.createElement('style');style.id='ff-luxe-completed-cashier-styles';
 style.textContent=[
 '#fflCashierFinished{margin:12px 0 19px;direction:rtl}',
 '#fflCashierFinishedToggle{width:100%;min-height:56px;border:2px solid #d82b44!important;border-radius:14px;background:linear-gradient(120deg,#ac1026,#e71f43)!important;color:white!important;display:flex;align-items:center;justify-content:space-between;gap:10px;padding:12px 18px!important;font-weight:950!important;font-size:clamp(16px,2.7vw,20px)!important;box-shadow:0 6px 18px #a1123030}',
 '#fflCashierFinishedToggle .ffl-arrow{font-size:21px;transition:transform .2s}',
 '#fflCashierFinishedToggle[aria-expanded=true] .ffl-arrow{transform:rotate(180deg)}',
 '#fflCashierFinishedPanel{background:var(--ffb-surface,#fff);border:2px solid var(--ffb-line,#ddd);padding:clamp(11px,2.4vw,18px);border-radius:0 0 16px 16px;margin-top:-2px}',
 '#fflCashierFinishedPanel[hidden],#fflCashierFinished[hidden]{display:none!important}',
 '.ffl-finished-tools{display:flex;align-items:center;flex-wrap:wrap;gap:9px;margin:10px 0}',
 '.ffl-finished-tools input{min-width:170px;flex:1;min-height:43px}',
 '.ffl-finished-tools button{min-height:43px}',
 '.ffl-finished-result{color:var(--ffb-muted,#646464);font-weight:750;font-size:12px;margin:10px 0}',
 '.ffl-finished-card{border:3px solid #2570d0;border-radius:16px;background:var(--ffb-surface,#fff);margin:11px 0;box-shadow:0 4px 17px #255db01c;overflow:hidden}',
 '.ffl-finished-card>summary{cursor:pointer;padding:15px;list-style:none;display:flex;flex-direction:column;gap:6px;line-height:1.65}',
 '.ffl-finished-card>summary::-webkit-details-marker{display:none}',
 '.ffl-finished-card>summary::after{content:"⌄ اضغط لعرض كل التفاصيل والإجراءات";color:#b71d36;font-weight:900;font-size:12px}',
 '.ffl-finished-card[open]>summary::after{content:"⌃ إخفاء التفاصيل";color:#b71d36}',
 '.ffl-finished-main{display:flex;align-items:center;justify-content:space-between;gap:9px;flex-wrap:wrap}',
 '.ffl-finished-main b{font-size:17px}',
 '.ffl-finished-status{border-radius:30px;padding:3px 8px;background:#d5e7ff;color:#124a8f;font-weight:900;font-size:12px}',
 '.ffl-finished-status.cancelled{background:#ffe1e4;color:#a11229}',
 '.ffl-finished-tags{display:flex;gap:6px;flex-wrap:wrap}',
 '.ffl-finished-tags span{border:1px solid #ddd;border-radius:7px;padding:3px 7px;font-size:12px;font-weight:800}',
 '.ffl-finished-tags .missing{color:#ac122d;border-color:#d34758;background:#fff0f2}',
 '.ffl-finished-details{padding:0 14px 17px;line-height:1.8;overflow-wrap:anywhere}',
 '.ffl-finished-meta{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:7px;margin:10px 0}',
 '.ffl-finished-meta>div{background:var(--ffb-soft,#f4f5f7);border:1px solid var(--ffb-line,#ddd);border-radius:9px;padding:8px 10px}',
 '.ffl-finished-products{background:var(--ffb-soft,#f6f6f6);border:1px solid var(--ffb-line,#ddd);padding:10px;border-radius:10px;margin:9px 0}',
 '.ffl-finished-actions{display:flex;flex-wrap:wrap;gap:7px;margin:12px 0}',
 '.ffl-finished-actions button{min-height:45px;flex:1 1 145px;font-weight:900}',
 '.ffl-finished-form{margin-top:9px;padding:13px;border:1px solid #d44b59;border-radius:12px;background:var(--ffb-soft,#f7f7f7)}',
 '.ffl-finished-form[hidden]{display:none!important}',
 '.ffl-finished-form label{display:block;font-size:13px;font-weight:850;margin:10px 0 4px}',
 '.ffl-finished-form input,.ffl-finished-form select,.ffl-finished-form textarea{width:100%;max-width:100%;min-height:42px}',
 '.ffl-finished-form button{min-height:46px;margin-top:10px}',
 '.ffl-finished-form textarea{min-height:82px}',
 '.ffl-finished-form .ffl-help{font-size:12px;color:var(--ffb-muted,#666)}',
 '.ffl-finished-empty{padding:20px;border-radius:12px;background:var(--ffb-soft,#f4f4f4);text-align:center}',
 '@media(max-width:560px){.ffl-finished-meta{grid-template-columns:1fr}.ffl-finished-main b{font-size:15px}.ffl-finished-card>summary{padding:12px}}'
 ].join('\n');document.head.append(style);

 const box=document.createElement('section');box.id='fflCashierFinished';box.hidden=true;
 const button=document.createElement('button');button.type='button';button.id='fflCashierFinishedToggle';
 button.setAttribute('aria-expanded','false');
 button.setAttribute('aria-controls','fflCashierFinishedPanel');
 const text=document.createElement('span');text.textContent='🗂️ الطلبات المنتهية';
 const arrow=document.createElement('span');arrow.className='ffl-arrow';arrow.setAttribute('aria-hidden','true');arrow.textContent='⌄';
 button.append(text,arrow);
 const panel=document.createElement('div');panel.id='fflCashierFinishedPanel';panel.hidden=true;
 panel.innerHTML='<p class="muted">الطلبات المكتملة أو التي انتهى دور الكاشير فيها. استكمل رقم فاتورة MicroPOS أو تقييم الموصل، أو ارفع بلاغًا مرتبطًا بالطلب. لا تتغير حالة الطلب أثناء الاستكمال.</p>'+
 '<div class="ffl-finished-tools"><input id="fflFinishedSearch" placeholder="🔎 ابحث في الطلبات المحمّلة: رقم الطلب، هاتف العميل، الموصل" aria-label="بحث في الطلبات المنتهية"><button id="fflFinishedRefresh" type="button" class="outline">🔄 تحديث</button></div>'+
 '<p id="fflFinishedStatus" class="ffl-finished-result" role="status" aria-live="polite"></p>'+
 '<div id="fflFinishedList"></div>'+
 '<div class="ffl-finished-tools"><button type="button" class="outline" id="fflFinishedMore" hidden>عرض 30 طلبًا أقدم</button></div>';
 box.append(button,panel);live.before(box);
 const status=$('fflFinishedStatus'),list=$('fflFinishedList'),search=$('fflFinishedSearch');
 const more=$('fflFinishedMore'),refresh=$('fflFinishedRefresh');
 const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const amount=n=>Number(n||0).toLocaleString('ar-YE',{maximumFractionDigits:2});
 const fmt=t=>{if(!t)return '—';const d=new Date(t);return Number.isNaN(d.getTime())?'—':d.toLocaleString('ar-YE',{timeZone:'Asia/Aden',day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'})};
 const finished=o=>!['cancelled','canceled','closed'].includes(String(o.status||'')) ;
 const seen=new Map();
 let viewer='',loaded=[],offset=0,hasMore=true,loading=false,open=false,lastUpdated=0,generation=0;
 let openCards=new Set(),activeAction=null;
 function cashier(){return typeof data!=='undefined'&&data?.role==='cashier'&&!!user?.id}
 function clear(){
  generation++;viewer='';loaded=[];offset=0;hasMore=true;loading=false;open=false;lastUpdated=0;openCards.clear();
  activeAction=null;seen.clear();list.replaceChildren();status.textContent='';
  search.value='';panel.hidden=true;button.setAttribute('aria-expanded','false');box.hidden=true;
 }
 function maintainViewer(){
  const current=cashier()?String(user.id):'';
  if(viewer!==current){clear();viewer=current}
  box.hidden=!current;
  return !!current;
 }
 function info(o){
  const cancellation=!finished(o);
  const workDone=!cancellation&&o.cashier_stage==='handed_over';
  const label=cancellation?'🚫 ملغي':o.status==='delivered'?'✅ تم التسليم للعميل':workDone?'✅ انتهى دور الكاشير — التوصيل مستمر':'✅ منتهٍ';
  const invoice=String(o.invoice_ref||'').trim();
  const stars=Number(o.cashier_rating||0);
  const canInvoice=!cancellation&&!invoice&&(o.status==='delivered'||workDone);
  const canRate=!cancellation&&!stars&&workDone&&o.driver_id;
  return {cancellation,label,invoice,stars,canInvoice,canRate};
 }
 function makeCard(o){
  const summary=info(o);
  const el=document.createElement('details');el.className='ffl-finished-card';el.dataset.fflFinishedOrder=String(o.id);
  el.open=openCards.has(o.id);
  const invoices=summary.invoice?'🧾 فاتورة: '+esc(summary.invoice):'⚠️ رقم فاتورة غير مسجل';
  const rating=summary.stars?'⭐ تقييم الكاشير: '+summary.stars+'/5':'⚠️ تقييم الكاشير ناقص';
  const top=document.createElement('summary');
  const meta=esc(o.customer_name||'عميل')+' · '+esc(o.driver_name||'—')+' · '+esc(o.area||'—');
  top.innerHTML='<div class="ffl-finished-main"><b>طلب #'+esc(o.number)+'</b><span class="ffl-finished-status'+(summary.cancellation?' cancelled':'')+'">'+summary.label+'</span></div>'+
    '<span class="muted">'+meta+' · '+esc(fmt(o.created_at))+'</span>'+
    '<div class="ffl-finished-tags"><span class="'+(!summary.invoice?'missing':'')+'">'+invoices+'</span>'+
    (!summary.cancellation?'<span class="'+(!summary.stars?'missing':'')+'">'+rating+'</span>':'')+
    (Number(o.case_count)>0?'<span>📢 بلاغات مرتبطة: '+esc(o.case_count)+'</span>':'')+'</div>';
  el.append(top);
  const body=document.createElement('div');body.className='ffl-finished-details';
  const products=(Array.isArray(o.items)?o.items:[]).map(it=>
    '<div>'+esc(it.qty||0)+' × '+esc(it.name||'صنف')+
    ' — '+amount(it.line_total)+' ريال'+
    (it.notes?'<div class="muted">📝 ملاحظة الصنف: '+esc(it.notes)+'</div>':'')+'</div>'
  ).join('')||'<div>لا توجد أصناف مسجلة</div>';
  body.innerHTML=
    '<div class="ffl-finished-meta">'+
    '<div><b>👤 العميل:</b> '+esc(o.customer_name||'عميل')+'</div>'+
    '<div><b>📞 هاتف العميل:</b> '+esc(o.phone||'—')+'</div>'+
    '<div><b>📍 العنوان:</b> '+esc(o.full_address||o.area||'—')+'</div>'+
    '<div><b>🛵 الموصل:</b> '+esc(o.driver_name||'—')+'</div>'+
    '<div><b>🕒 الإسناد:</b> '+esc(fmt(o.assigned_at))+'</div>'+
    '<div><b>🕒 انتهاء التوصيل:</b> '+esc(fmt(o.delivered_at))+'</div>'+
    '</div>'+
    '<b>🍟 تفاصيل الطلب:</b><div class="ffl-finished-products">'+products+'</div>'+
    '<p><b>الأصناف:</b> '+amount(o.items_total)+' ريال · <b>التوصيل:</b> '+amount(o.delivery_fee)+' ريال · <b>الإجمالي:</b> '+amount(o.total)+' ريال</p>'+
    (o.notes?'<p><b>ملاحظات الطلب:</b> '+esc(o.notes)+'</p>':'')+
    (summary.cancellation?'<p style="color:#bb142d"><b>سبب الإلغاء:</b> '+esc(o.cancel_reason||'غير مذكور')+'</p>':'')+
    '<p><b>رقم الفاتورة:</b> '+(summary.invoice?esc(summary.invoice):'غير موثق')+
    ' · <b>تقييم الكاشير:</b> '+(summary.stars?summary.stars+'/5':'غير مسجل')+'</p>'+
    (summary.stars&&o.cashier_rating_note?'<p class="muted">ملاحظة التقييم: '+esc(o.cashier_rating_note)+'</p>':'')+
    '<div class="ffl-finished-actions">'+
    (summary.canInvoice?'<button type="button" class="primary" data-ffl-show="invoice">🧾 إضافة رقم الفاتورة</button>':'')+
    (summary.canRate?'<button type="button" class="outline" data-ffl-show="rating">⭐ إضافة تقييم الموصل</button>':'')+
    '<button type="button" class="outline" data-ffl-show="report">📢 بلاغ / شكوى للإدارة</button>'+
    '</div>'+
    (summary.cancellation?'<p class="muted">الطلب ملغي؛ لا يمكن إضافة فاتورة جديدة أو تقييم موصل له من الأرشيف.</p>':'')+
    (summary.canInvoice?'<form class="ffl-finished-form" data-ffl-action="invoice" hidden>'+
      '<label>رقم فاتورة MicroPOS</label><input name="invoice" required maxlength="80" placeholder="رقم الفاتورة الفعلي">'+
      '<p class="ffl-help">التوثيق لاحق فقط. لن نعيد فتح الطلب أو نغيّر حالته.</p>'+
      '<button type="submit" class="primary">حفظ رقم الفاتورة</button></form>':'')+
    (summary.canRate?'<form class="ffl-finished-form" data-ffl-action="rating" hidden>'+
      '<label>تقييم الموصل</label><select name="rating" required>'+
      '<option value="">اختر عدد النجوم</option>'+
      [1,2,3,4,5].map(n=>'<option value="'+n+'">'+n+' من 5 ⭐</option>').join('')+
      '</select><label>ملاحظة التقييم (اختيارية)</label><textarea name="note" maxlength="500" placeholder="ملاحظات أداء الموصل"></textarea>'+
      '<button type="submit" class="primary">حفظ التقييم</button></form>':'')+
    '<form class="ffl-finished-form" data-ffl-action="report" hidden>'+
    '<label>نوع البلاغ</label><select name="category" required>'+
    '<option value="operational">بلاغ تشغيلي متعلق بالطلب</option><option value="management_complaint">شكوى للإدارة مرتبطة بالطلب</option></select>'+
    '<label>أولوية البلاغ</label><select name="priority"><option value="normal">عادي</option><option value="high">عاجل</option><option value="low">منخفض</option></select>'+
    '<label>عنوان البلاغ</label><input name="subject" required minlength="4" maxlength="110" placeholder="اكتب موضوع البلاغ">'+
    '<label>الشرح والتفاصيل</label><textarea name="description" required minlength="10" maxlength="4000" placeholder="ما المشكلة، وما المطلوب من الإدارة؟"></textarea>'+
    '<p class="ffl-help">سيُحفظ البلاغ في مركز البلاغات مربوطًا تلقائيًا برقم الطلب، لتتابعه الإدارة.</p>'+
    '<button type="submit" class="primary">إرسال البلاغ للإدارة</button></form>';
  el.append(body);
  el.addEventListener('toggle',()=>{if(el.open)openCards.add(o.id);else openCards.delete(o.id)});
  return el;
 }
 function render(){
  if(!maintainViewer()||!open)return;
  const value=search.value.trim().toLowerCase();
  // Search applies to the securely loaded (paged) cashier-only results.
  const result=loaded.filter(o=>!value||[o.number,o.customer_name,o.phone,o.driver_name,o.area,o.invoice_ref]
    .some(v=>String(v??'').toLowerCase().includes(value)));
  const saved=[...list.querySelectorAll('details[open][data-ffl-finished-order]')].map(n=>n.dataset.fflFinishedOrder);
  saved.forEach(id=>openCards.add(id));
  const frag=document.createDocumentFragment();
  if(!result.length){
    const empty=document.createElement('p');empty.className='ffl-finished-empty';
    empty.textContent=value?'لا توجد نتائج في الطلبات المحمّلة. استخدم «عرض 30 طلبًا أقدم» للبحث في طلبات أقدم.':'لا توجد طلبات منتهية لهذا الكاشير.';
    frag.append(empty);
  }else for(const o of result)frag.append(makeCard(o));
  list.replaceChildren(frag);
  more.hidden=!hasMore;
  status.textContent='المعروض '+result.length+' من '+loaded.length+' طلبًا تم تحميله'+(hasMore?' · توجد طلبات أقدم':'')+
    (lastUpdated?' · تحديث '+new Date(lastUpdated).toLocaleTimeString('ar-YE',{timeZone:'Asia/Aden'}):'');
 }
 async function load(reset=false){
  if(!maintainViewer()||!open||loading)return;
  const current=String(user.id),requestGeneration=generation;loading=true;
  more.disabled=true;refresh.disabled=true;
  status.textContent=reset?'جارٍ تحديث الطلبات المنتهية...':'جارٍ تحميل طلبات أقدم...';
  try{
   const result=await rpc('ff_luxe_cashier_completed_orders',{p_limit:30,p_offset:reset?0:offset});
   if(requestGeneration!==generation||!cashier()||String(user.id)!==current||!open)return;
   if(!result||!Array.isArray(result.items))throw Error('استجابة قائمة الطلبات المنتهية غير مكتملة');
   loaded=reset?result.items:[...loaded,...result.items.filter(o=>!loaded.some(x=>x.id===o.id))];
   offset=(reset?0:offset)+result.items.length;
   hasMore=result.has_more===true;
   lastUpdated=Date.now();
   render();
  }catch(e){
   status.textContent='⚠️ تعذر تحميل الطلبات المنتهية: '+String(e?.message||e);
  }finally{loading=false;more.disabled=false;refresh.disabled=false}
 }
 button.addEventListener('click',()=>{
  if(!maintainViewer())return;
  open=!open;panel.hidden=!open;button.setAttribute('aria-expanded',String(open));
  if(open){if(!loaded.length)void load(true);else render()}
 });
 refresh.onclick=()=>void load(true);
 more.onclick=()=>void load(false);
 search.addEventListener('input',render);
 list.addEventListener('click',event=>{
  const b=event.target.closest('[data-ffl-show]');if(!b)return;
  const card=b.closest('[data-ffl-finished-order]');if(!card)return;
  const type=b.dataset.fflShow,form=card.querySelector('[data-ffl-action="'+type+'"]');
  if(!form)return;
  const show=form.hidden;
  card.querySelectorAll('.ffl-finished-form').forEach(x=>x.hidden=true);
  form.hidden=!show;if(show)form.querySelector('input,select,textarea')?.focus({preventScroll:true});
 });
 list.addEventListener('submit',async event=>{
  const form=event.target.closest('form[data-ffl-action]');if(!form)return;
  event.preventDefault();
  if(!maintainViewer()||!form.reportValidity())return;
  const card=form.closest('[data-ffl-finished-order]'),orderId=card?.dataset.fflFinishedOrder;
  const o=loaded.find(x=>x.id===orderId);if(!o)return;
  const action=form.dataset.fflAction,infoNow=info(o);
  if(action==='invoice'&&!infoNow.canInvoice)return toast('رقم الفاتورة مسجل أو الطلب غير قابل للاستكمال');
  if(action==='rating'&&!infoNow.canRate)return toast('تم تسجيل التقييم مسبقًا أو الطلب غير مؤهل');
  if(!['invoice','rating','report'].includes(action))return;
  if(activeAction)return toast('هناك عملية أخرى جارٍ تنفيذها');
  const current=String(user.id),submit=form.querySelector('button[type=submit]');
  activeAction=orderId;submit.disabled=true;
  const original=submit.textContent;submit.textContent='جارٍ الحفظ...';
  try{
   let result;
   if(action==='invoice'){
    const invoice=form.elements.namedItem('invoice').value.trim();
    if(!invoice)throw Error('أدخل رقم الفاتورة أولًا');
    result=await rpc('ff_luxe_cashier_completed_invoice',{p_order:orderId,p_invoice_ref:invoice});
   }else if(action==='rating'){
    const stars=Number(form.elements.namedItem('rating').value);
    result=await rpc('ff_luxe_cashier_completed_rating',{
      p_order:orderId,p_stars:stars,p_note:form.elements.namedItem('note').value.trim()
    });
   }else{
    const title=form.elements.namedItem('subject').value.trim(),description=form.elements.namedItem('description').value.trim();
    result=await rpc('ff_luxe_cashier_completed_report',{
      p_order:orderId,p_category:form.elements.namedItem('category').value,
      p_subject:title,p_description:description,p_priority:form.elements.namedItem('priority').value
    });
   }
   if(!result?.saved&&!result?.case_id)throw Error('لم يؤكد الخادم حفظ الإجراء');
   if(current!==String(user?.id||''))return;
   const message={invoice:'تم حفظ رقم الفاتورة وتوثيق الاستكمال',rating:'تم إرسال تقييم الكاشير',report:'تم إرسال البلاغ وربطه بالطلب'};
   toast('✅ '+message[action]);
   openCards.add(orderId);
   await load(true);
  }catch(e){if(current===String(user?.id||''))toast('تعذر استكمال الطلب: '+(e?.message||e))}
  finally{activeAction=null;submit.disabled=false;submit.textContent=original}
 });
 window.addEventListener('ff-assembly-snapshot-success',()=>{
  // The role, selected cashier desk and authorized branch may change on snapshot refresh.
  if(!maintainViewer())return;
  if(open&&Date.now()-lastUpdated>90000&&!loading)void load(true);
 });
 document.addEventListener('visibilitychange',()=>{
  if(!document.hidden&&open&&cashier()&&Date.now()-lastUpdated>90000)void load(true)
 });
 const oldReset=resetUI;resetUI=function(){clear();oldReset()};
 // Keep the active order stream untouched.
 maintainViewer();
})();