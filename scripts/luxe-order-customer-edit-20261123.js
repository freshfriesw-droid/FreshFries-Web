/* Change order contact details regardless of order phase; manager/CS/delegated cashier. */
(function(){
'use strict';
const $=id=>document.getElementById(id);
const permitted=()=>!!(typeof user!=='undefined'&&user?.id&&typeof data!=='undefined'&&
 ['manager','customer_service','cashier'].includes(data?.role)&&typeof canAction==='function'&&canAction('edit_order'));
const modal=document.createElement('dialog');modal.id='ffCustomerEditDialog';
modal.style.cssText='width:min(95vw,565px);max-height:90vh;overflow:auto;border:2px solid #c8273e;border-radius:16px;padding:16px;direction:rtl;background:#fff;color:#111';
modal.innerHTML='<h2>✏️ تعديل بيانات العميل</h2><p id="ffCustomerEditTitle"></p>'+
'<form id="ffCustomerEditForm" autocomplete="off">'+
'<label>اسم العميل<input name="name" required minlength="2" maxlength="100"></label>'+
'<label>رقم هاتف العميل<input name="phone" required inputmode="tel" maxlength="30"></label>'+
'<label>المنطقة<input name="area" required minlength="2" maxlength="150"></label>'+
'<label>العنوان الكامل<input name="address" required minlength="2" maxlength="500"></label>'+
'<label>سبب التعديل<input name="reason" required maxlength="300" placeholder="مثال: صحّح العميل رقم الهاتف"></label>'+
'<label id="ffCustomerEditNoteLabel" hidden>ملاحظة جديدة خاصة بسجل العميل (اختيارية)<textarea name="customer_note" minlength="3" maxlength="2000"></textarea><small>تحفظ للرقم الحالي بعد التصحيح؛ لا تُنقل ملاحظات الرقم السابق تلقائيًا.</small></label>'+
'<p id="ffCustomerEditMessage" role="status"></p><div class="actions">'+
'<button id="ffCustomerEditSave" type="submit" class="primary">✅ حفظ التعديل وإشعار الموصل</button>'+
'<button id="ffCustomerEditCancel" type="button" class="outline">إلغاء</button></div></form>';
document.body.append(modal);
const form=$('ffCustomerEditForm'),field=x=>form.elements.namedItem(x);
let order='',working=false,nonce=0,observed=new Map(),viewer='';
function reset(){nonce++;order='';working=false;observed.clear();viewer='';form.reset();$('ffCustomerEditSave').disabled=false;$('ffCustomerEditTitle').textContent='';$('ffCustomerEditMessage').textContent='';if(modal.open)modal.close()}
window.addEventListener('ff-luxe-session-reset',reset);
function mark(){
 const current=typeof user!=='undefined'&&user?.id||'';
 if(viewer!==current){viewer=current;observed.clear()}
 for(const o of typeof data!=='undefined'&&Array.isArray(data?.orders)?data.orders:[]){
  if(o.id==null)continue;
  const time=o.customer_update?.at;
  const before=observed.get(o.id);
  if(data?.role==='driver'&&time&&observed.has(o.id)&&time!==before){
   try{if(typeof ding==='function')ding()}catch(_){}
   try{if(typeof toast==='function')toast('⚠️ تم تعديل هاتف أو عنوان العميل لطلب #'+o.number)}catch(_){}
  }
  observed.set(o.id,time||null);
 }
}
window.addEventListener('ff-assembly-snapshot-success',mark);
window.ffCustomerEdit=async id=>{
 if(!permitted()){if(typeof toast==='function')toast('هذه الصلاحية تحتاج تخويل المدير');return}
 const actor=user?.id,request=++nonce;order='';working=false;
 form.reset();$('ffCustomerEditNoteLabel').hidden=!['manager','customer_service'].includes(data?.role);field('customer_note').disabled=$('ffCustomerEditNoteLabel').hidden;$('ffCustomerEditSave').disabled=true;$('ffCustomerEditTitle').textContent='';
 $('ffCustomerEditMessage').textContent='جارٍ تحميل بيانات الطلب...';
 if(!modal.open)modal.showModal();
 try{
  const rec=await rpc('ff_order_customer_read',{p_order:id});
  if(nonce!==request||actor!==user?.id||!permitted())return;
  order=rec.id;$('ffCustomerEditSave').disabled=false;
  $('ffCustomerEditTitle').textContent='طلب #'+rec.number+' · الحالة: '+rec.status;
  for(const k of ['name','phone','area','address'])field(k).value=String(rec[k]||'');
  field('reason').value='';
  $('ffCustomerEditMessage').textContent='سيتم الاحتفاظ بسجل التعديل وتنبيه الموصل. حالة الطلب لا تتغير.';
 }catch(e){if(request!==nonce||actor!==user?.id)return;$('ffCustomerEditMessage').textContent='تعذر فتح بيانات العميل: '+String(e.message||e)}
};
$('ffCustomerEditCancel').onclick=()=>{if(!working)modal.close()};
form.addEventListener('submit',async event=>{
 event.preventDefault();
 if(!permitted()||!order||working)return;
 if(!field('reason').value.trim()){
  $('ffCustomerEditMessage').textContent='اكتب سبب تعديل بيانات العميل';
  field('reason').focus();return;
 }
 const actor=user.id,request=nonce;working=true;$('ffCustomerEditSave').disabled=true;
 $('ffCustomerEditMessage').textContent='جارٍ حفظ التعديل...';
 try{
  const input={
   p_order:order,p_phone:field('phone').value.trim(),p_area:field('area').value.trim(),
   p_name:field('name').value.trim(),p_address:field('address').value.trim(),
   p_reason:field('reason').value.trim()
  };
  const note=field('customer_note').disabled?'':field('customer_note').value.trim();
  const result=await rpc(note?'ff_order_customer_edit_with_note':'ff_order_customer_edit',note?{...input,p_note:note}:input);
  if(actor!==user?.id||request!==nonce)return;
  if(!result?.saved)throw Error('تعذر تأكيد حفظ التعديل من الخادم');
  $('ffCustomerEditMessage').textContent='✅ حُفظ تعديل العميل وسيظهر تنبيه في بطاقة الموصل';
  if(typeof toast==='function')toast('تم حفظ تعديل بيانات العميل');
  modal.close();if(typeof reload==='function')void reload(true);
 }catch(e){if(request!==nonce||actor!==user?.id)return;$('ffCustomerEditMessage').textContent='⚠️ '+String(e.message||e)}
 finally{if(request===nonce){working=false;$('ffCustomerEditSave').disabled=false}}
});
document.addEventListener('click',event=>{
 const b=event.target.closest('[data-ff-customer-edit]');
 if(!b)return;
 event.preventDefault();event.stopImmediatePropagation();
 void window.ffCustomerEdit(b.dataset.ffCustomerEdit);
},true);
function attachFinished(){
 if(!permitted())return;
 for(const card of document.querySelectorAll('.ffl-finished-card[data-ffl-finished-order]')){
  if(card.querySelector('[data-ff-customer-edit]'))continue;
  const button=document.createElement('button');button.type='button';button.className='outline';
  button.dataset.ffCustomerEdit=card.dataset.fflFinishedOrder;button.textContent='✏️ تعديل بيانات العميل';
  const row=card.querySelector('.ffl-finished-actions');if(row)row.append(button);
 }
}
const observer=new MutationObserver(attachFinished);
observer.observe(document.body,{subtree:true,childList:true});
setInterval(attachFinished,10000);
})();
