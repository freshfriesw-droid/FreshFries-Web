/* Fresh Fries LUXE — Cairo pinned courier, compact mobile interface. */
(function(){
'use strict';
var $=function(id){return document.getElementById(id)};
var safe=function(v){return String(v==null?'':v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})};
var create=$('createBtn'),branch=$('newBranch');if(!create||!branch)return;
var css=document.createElement('style');css.textContent='#ffPinnedCairo{margin:12px 0;padding:12px;border:1px solid #ce2634;border-radius:14px;background:var(--ffb-card,#fff);max-width:100%;box-sizing:border-box}#ffPinnedCairo[hidden],#ffPinnedPreview[hidden]{display:none!important}#ffPinnedCairo .ffpc-row{display:flex;gap:8px;flex-wrap:wrap;align-items:center}#ffPinnedCairo button{min-height:42px}#ffPinnedCairo select{min-width:0;flex:1 1 180px;max-width:100%;padding:10px}#ffPinnedCairo small{display:block;margin:8px 0;color:var(--ffb-muted,#666)}#ffPinnedPreview{position:fixed;inset:0;z-index:999999;background:#0009;display:grid;place-items:center;padding:15px;overflow-y:auto}#ffPinnedPreview article{background:var(--ffb-card,#fff);color:var(--ffb-ink,#222);border-radius:16px;padding:18px;width:min(100%,480px);max-height:90vh;overflow:auto}#ffPinnedPreview .ffpc-row{display:flex;flex-wrap:wrap;gap:9px}#ffPinnedPreview button,#ffPinnedCairo button{border-radius:10px}#ffPinnedCairo .ffpc-primary,#ffPinnedPreview .ffpc-primary{background:#cb172e;color:white}';document.head.appendChild(css);
var panel=document.createElement('section');panel.id='ffPinnedCairo';panel.hidden=true;panel.innerHTML='<strong>🛵 الموصل المثبت — القاهرة</strong><small id="ffpcState">لم يتم تحميل بيانات التثبيت</small><small id="ffpcCapacity" role="status"></small><button type="button" id="ffpcDirect" class="ffpc-primary">مراجعة وإسناد للموصل المثبت</button><details style="margin-top:10px"><summary style="cursor:pointer;font-weight:bold">⚙️ تثبيت الموصل أو تغييره</summary><p style="font-size:12px">موصل خاص بأجر يومي، خارج الدور التلقائي، إسناد فوري دون انتظار قبول، وأجرة التوصيل صفر.</p><div class="ffpc-row"><select id="ffpcDriver"><option value="">بدون موصل</option></select><button id="ffpcSave" type="button">حفظ التثبيت</button><button id="ffpcRefresh" type="button">تحديث</button></div><label id="ffpcCapEdit" hidden>سقف الطلبات والعروض الجارية<input id="ffpcLimit" type="number" min="1" step="1"><button type="button" id="ffpcSetLimit">حفظ السقف</button></label></details>';
(create.closest('.actions')||create.parentElement).before(panel);
var overlay=document.createElement('div');overlay.id='ffPinnedPreview';overlay.hidden=true;overlay.innerHTML='<article role="dialog" aria-modal="true" aria-labelledby="ffpcTitle"><h3 id="ffpcTitle">معاينة الإسناد المباشر</h3><div id="ffpcSummary"></div><label id="ffpcReasonLabel" hidden>سبب التجاوز الاستثنائي<input id="ffpcOverrideReason" maxlength="300"></label><div class="ffpc-row"><button type="button" id="ffpcConfirm" class="ffpc-primary">تأكيد وإنشاء الطلب</button><button type="button" id="ffpcCancel">إلغاء</button></div></article>';document.body.appendChild(overlay);
var capacity=null,epoch=0,pin=null,loading=false,sending=false,previewing=false,savingPin=false,lastLoad=0,previewSequence=0;
const draftFields=['newPhone','newArea','newCustomerName','newFullAddress','newNotes','newItems'];
function draftSnapshot(){return JSON.stringify([branch.value,window.ffLuxeChosenCashierDesk?.()||'cairo_first',...draftFields.map(id=>$(id)?.value??'')])}
function dismissPreview(){previewSequence++;previewing=false;overlay.hidden=true;$('ffpcConfirm').onclick=null;$('ffpcSummary').replaceChildren();$('ffpcOverrideReason').value='';refreshUI()}
function sameSession(request,actor){return request===epoch&&typeof user!=='undefined'&&user?.id===actor}
function cairo(){return branch.selectedOptions[0]?.textContent.includes('القاهرة')||Boolean(pin&&branch.value===pin.branch_id)}
function msg(m){$('ffpcState').textContent=m}
function refreshUI(){panel.hidden=!cairo();$('ffpcDirect').disabled=!pin?.driver_id||sending||loading||previewing||savingPin}
function showCapacity(info){
 capacity=info;
 $('ffpcCapacity').textContent=info?'الطلبات والعروض الجارية: '+info.active+' من '+info.capacity+(info.active>=info.capacity?' — اكتمل السقف':''):'';
 $('ffpcCapEdit').hidden=!info?.can_manage;
 if(info&&document.activeElement!==$('ffpcLimit'))$('ffpcLimit').value=String(info.capacity);
}
window.addEventListener('ff-luxe-session-reset',()=>{
 epoch++;pin=null;loading=false;sending=false;savingPin=false;lastLoad=0;dismissPreview();$('ffpcConfirm').disabled=false;$('ffpcSave').disabled=false;$('ffpcSetLimit').disabled=false;
 $('ffpcDriver').replaceChildren();$('ffpcSummary').replaceChildren();$('ffpcOverrideReason').value='';
 msg('لم يتم تحميل بيانات التثبيت');showCapacity(null);refreshUI();
});
async function load(force){
 if(typeof user==='undefined'||!user||loading||(!force&&Date.now()-lastLoad<25000)){refreshUI();return}
 const actor=user.id,request=epoch;loading=true;refreshUI();
 try{
  const [p,ds]=await Promise.all([rpc('ff62_get_pinned'),rpc('ff62_cairo_drivers')]);
  const info=p?.driver_id?await rpc('ff_special_courier_status',{p_driver:p.driver_id}):null;
  if(request!==epoch||actor!==user?.id)return;
  pin=p;showCapacity(info);
  const sel=$('ffpcDriver');
  sel.innerHTML='<option value="">بدون موصل</option>'+(Array.isArray(ds)?ds:[]).map(d=>'<option value="'+safe(d.id)+'">'+safe(d.name)+'</option>').join('');
  sel.value=p?.driver_id||'';msg(p?.driver_name?'المثبت حاليًا: '+p.driver_name:'لا يوجد موصل مثبت');lastLoad=Date.now();
 }catch(e){if(request===epoch){pin=null;showCapacity(null);msg('تعذر تحميل التثبيت: '+e.message)}}
 finally{if(request===epoch){loading=false;refreshUI()}}
}
$('ffpcSetLimit').onclick=async function(){
 const id=pin?.driver_id,request=epoch,value=Number($('ffpcLimit').value);
 if(!id||!capacity?.can_manage||!Number.isSafeInteger(value)||value<1)return msg('أدخل سقفًا صحيحًا موجبًا');
 this.disabled=true;
 try{const info=await rpc('ff_set_special_courier_capacity',{p_driver:id,p_capacity:value});
  if(request===epoch&&pin?.driver_id===id){showCapacity(info);msg('تم حفظ السقف')}
 }catch(e){if(request===epoch)msg(e.message)}finally{this.disabled=false}
};
$('ffpcRefresh').onclick=function(){void load(true)};
$('ffpcSave').onclick=async function(){
 if(savingPin||sending||typeof user==='undefined'||!user)return;
 const btn=this,request=epoch,actor=user.id;
 dismissPreview();savingPin=true;btn.disabled=true;refreshUI();
 try{const updated=await rpc('ff62_set_pinned',{p_driver:$('ffpcDriver').value||null});if(!sameSession(request,actor))return;pin=updated;lastLoad=0;await load(true)}
 catch(e){if(sameSession(request,actor))msg('فشل تثبيت الموصل: '+e.message)}
 finally{if(sameSession(request,actor)){savingPin=false;btn.disabled=false;refreshUI()}}
};
branch.addEventListener('change',function(){if(!sending)dismissPreview();refreshUI();if(cairo())void load(true)});
window.addEventListener('focus',function(){if(cairo())void load(true)});
$('ffpcCancel').onclick=function(){if(!sending)dismissPreview()};
overlay.addEventListener('click',function(e){if(e.target===overlay&&!sending)dismissPreview()});
document.addEventListener('input',e=>{if(draftFields.includes(e.target?.id)&&!sending&&(!overlay.hidden||previewing))dismissPreview()},true);
$('ffpcDirect').onclick=async function(){
 if(previewing||sending||savingPin||typeof user==='undefined'||!user)return;
 const request=epoch,actor=user.id,sequence=++previewSequence,snapshot=draftSnapshot();
 previewing=true;refreshUI();
 const validPreview=()=>sameSession(request,actor)&&sequence===previewSequence&&draftSnapshot()===snapshot;
 try{if(!cairo()||!pin?.driver_id)throw Error('اختر موصلًا مثبتًا أولًا');const selectedDriver=pin.driver_id,selectedBranch=branch.value,selectedDesk=window.ffLuxeChosenCashierDesk?.()||'cairo_first';
 const info=await rpc('ff_special_courier_status',{p_driver:selectedDriver});
 if(!validPreview()||pin?.driver_id!==selectedDriver||branch.value!==selectedBranch)return;
 showCapacity(info);
 const full=Boolean(info&&info.active>=info.capacity);
 if(full&&!info.can_manage)throw Error('اكتمل سقف الموصل الخاص. يلزم اعتماد المدير للتجاوز.');
 $('ffpcReasonLabel').hidden=!full;$('ffpcOverrideReason').value='';
 await ff49LoadCatalog();if(!validPreview()||pin?.driver_id!==selectedDriver||branch.value!==selectedBranch)return;
 var parsed=ff49ParseItemsAndNotes($('newItems').value);if(parsed.errors?.length)throw Error(parsed.errors.join('، '));if(parsed.warnings?.length)throw Error('راجع السطور غير الواضحة في الطلب أولًا');if(!parsed.items?.length)throw Error('لا توجد أصناف صالحة');var phone=String(parsed.meta?.phone||$('newPhone')?.value||'').trim(),area=String(parsed.meta?.area||$('newArea')?.value||'').trim();if(!phone||!area)throw Error('رقم الهاتف والمنطقة مطلوبان');var notes=[$('newNotes')?.value,Array.isArray(parsed.notes)?parsed.notes.join('؛ '):parsed.notes,$('newCustomerName')?.value?'اسم العميل: '+$('newCustomerName').value:'',$('newFullAddress')?.value?'العنوان: '+$('newFullAddress').value:''].filter(Boolean).join(' | ');var sum=parsed.items.reduce(function(v,i){return v+Number(i.price)*Number(i.qty)},0);$('ffpcSummary').innerHTML='<p><b>الموصل:</b> '+safe(pin.driver_name)+' — <b>أجرة التوصيل:</b> 0 ريال</p><p><b>الهاتف:</b> '+safe(phone)+' — <b>المنطقة:</b> '+safe(area)+'</p>'+parsed.items.map(function(i){return '<p>'+safe(i.name)+' × '+safe(i.qty)+' — '+safe(Number(i.price)*Number(i.qty))+' ريال</p>'}).join('')+'<p><b>الإجمالي: '+safe(sum)+' ريال</b></p><p>'+safe(notes)+'</p>';overlay.hidden=false;
$('ffpcConfirm').onclick=async function(){
 if(sending||overlay.hidden)return;
 if(!validPreview()){dismissPreview();return toast('تغيرت بيانات الطلب؛ أعد المعاينة قبل التأكيد')}
 sending=true;this.disabled=true;refreshUI();
 try{var p=await rpc('ff62_get_pinned');if(!sameSession(request,actor))return;
 if(!validPreview()||p?.driver_id!==selectedDriver){dismissPreview();throw Error('تغيرت بيانات الطلب أو الموصل المثبت؛ أعد المعاينة')}
 const reason=full?$('ffpcOverrideReason').value.trim():'';
 if(full&&!reason)throw Error('اكتب سبب التجاوز قبل التأكيد');
 var out=await rpc('ff_confirm_pinned_order',{p_driver:selectedDriver,p_branch:selectedBranch,p_desk:selectedDesk,p_phone:phone,p_area:area,p_items:parsed.items,p_notes:notes,p_override_reason:reason});
 if(!sameSession(request,actor))return;
 const unchanged=draftSnapshot()===snapshot;
 dismissPreview();void load(true);toast('تم إنشاء الطلب رقم '+out.order_number+' وإسناده للموصل المثبت');
 if(unchanged)draftFields.forEach(id=>{if($(id))$(id).value=''});
 try{await reload(true)}catch(e){if(sameSession(request,actor))toast('تم حفظ الطلب؛ تعذر تحديث القائمة: '+e.message)}
 }catch(e){if(sameSession(request,actor))toast('تعذر الإسناد المباشر: '+e.message)}
 finally{if(sameSession(request,actor)){sending=false;$('ffpcConfirm').disabled=false;refreshUI()}}
 };
 }catch(e){if(validPreview())toast('تعذر عرض المعاينة: '+e.message)}
 finally{if(sameSession(request,actor)&&sequence===previewSequence){previewing=false;refreshUI()}}
};
setInterval(function(){if(typeof user!=='undefined'&&user&&cairo())void load(false)},20000);
setTimeout(function(){refreshUI();if(cairo())void load(true)},1100);
})();