/* Single-use gifts/compensation/hospitality codes. Issuance manager-only, redemption atomic. */
(function(){
'use strict';
const $=id=>document.getElementById(id);
const el=(tag,txt)=>{const x=document.createElement(tag);if(txt!==undefined)x.textContent=String(txt);return x};
const role=()=>typeof data!=='undefined'?data?.role:'';
const authed=()=>typeof user!=='undefined'&&!!user?.id;
const canRedeem=()=>authed()&&['manager','customer_service','cashier'].includes(role());
const authManager=()=>authed()&&role()==='manager';
let catalog=[],issueQuantities=new Map(),issued='',redeemCode='',chosen=null,redeemMode='',token=null,submitBusy=false;
const css=el('style');
css.textContent='#ffRewardManager,#ffRewardService,#ffRewardCashier{border:2px solid #c62239;border-radius:15px;padding:15px;margin:12px 0;background:var(--ffb-surface,#fff);direction:rtl}'+
'.ff-reward-form{display:flex;gap:9px;flex-wrap:wrap;align-items:end}.ff-reward-form label{flex:1 1 130px;display:grid;gap:6px;font-weight:850}'+
'#ffRewardManagerItems{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:8px;margin:10px 0}'+
'.ff-reward-item{border:1px solid #ddd;border-radius:10px;padding:9px;display:grid;gap:7px}.ff-reward-count{display:flex;justify-content:space-between;align-items:center;gap:8px}'+
'.ff-reward-count button{min-height:40px;min-width:46px;font-weight:900}#ffRewardRedeemDialog{width:min(95vw,550px);max-height:90vh;overflow:auto;background:#fff;color:#111;border:2px solid #ce2b43;border-radius:16px;padding:17px;direction:rtl}'+
'#ffRewardResult{font-size:22px;font-weight:900;overflow-wrap:anywhere;color:#9e1331;padding:10px}';
document.head.append(css);
const manager=el('section');manager.id='ffRewardManager';manager.hidden=true;
manager.innerHTML='<h2>🎟️ أكواد التعويض والجوائز والضيافة</h2>'+
'<p class="muted">كل كود خاص بعميل واحد، صالح للاستخدام مرة واحدة في أي فرع، ويمنح الأصناف المحددة مجانًا. يتحمل العميل أجرة التوصيل إن كانت محددة.</p>'+
'<form id="ffRewardIssueForm">'+
'<div class="ff-reward-form"><label>نوع الكود<select name="kind"><option value="compensation">تعويض</option><option value="prize">جائزة</option><option value="hospitality">ضيافة</option></select></label>'+
'<label>اسم العميل<input name="name" required minlength="2" maxlength="100"></label>'+
'<label>رقم الهاتف<input name="phone" required inputmode="tel" maxlength="30"></label>'+
'<label>انتهاء الصلاحية (اختياري)<input name="expiry" type="date"></label></div>'+
'<h3>أصناف الكود من المنيو</h3><input id="ffRewardItemSearch" placeholder="🔎 ابحث عن صنف" autocomplete="off">'+
'<div id="ffRewardManagerItems"></div><button class="primary" type="submit" id="ffRewardIssue">إصدار كود جديد</button></form>'+
'<p id="ffRewardIssueStatus" role="status"></p><div id="ffRewardResult"></div>'+
'<div class="actions"><button id="ffRewardCodesRefresh" class="outline" type="button">📋 الأكواد الصادرة</button></div>'+
'<div id="ffRewardCodesList"></div>';
$('staffView')?.prepend(manager);
const service=el('div');service.id='ffRewardService';service.hidden=true;
service.innerHTML='<div class="ff-reward-form"><label>🎟️ كود خصم<input id="ffRewardServiceCode" placeholder="FF-XXXX-XXXX-XXXX-XXXX" autocomplete="off"></label><button type="button" id="ffRewardServiceApply" class="primary">🔎 عرض أصناف التعويض</button></div>';
$('newPhone')?.closest('.row')?.after(service);
const cashier=el('section');cashier.id='ffRewardCashier';cashier.hidden=true;
cashier.innerHTML='<h3>🎟️ كود خصم · تحضير كود ضيافة</h3><div class="ff-reward-form">'+
'<label>رمز الكود<input id="ffRewardCashierCode" placeholder="FF-XXXX-XXXX-XXXX-XXXX"></label>'+
'<button type="button" class="primary" id="ffRewardCashierApply">إنشاء بطاقة تحضير بالكود</button></div>';
$('cashierView')?.prepend(cashier);
const dialog=el('dialog');dialog.id='ffRewardRedeemDialog';
dialog.innerHTML='<h2>🎟️ مراجعة كود الخصم</h2><p id="ffRewardPreview"></p><div id="ffRewardPreviewItems"></div>'+
'<form id="ffRewardRedeemForm"><div class="ff-reward-form">'+
'<label>الفرع<select name="branch" required></select></label>'+
'<label id="ffRewardChannelLabel">نوع الاستلام<select name="channel">'+
'<option value="delivery">توصيل</option><option value="reservation">حجز لاستلام المطعم</option></select></label></div>'+
'<div id="ffRewardDeliveryDetails"><label>عنوان التوصيل أو المنطقة<input name="area" maxlength="300"></label>'+
'<label>أجرة التوصيل (المنتجات مجانية)<input name="fee" type="number" min="0" max="50000" step="0.01" value="0"></label></div>'+
'<label>ملاحظات (اختياري)<textarea name="notes" rows="2" maxlength="1000"></textarea></label>'+
'<label style="display:flex;align-items:start;gap:10px;font-weight:850;margin:12px 0"><input name="verify" type="checkbox" required> أؤكد مطابقة اسم العميل ورقمه للكود قبل استهلاكه</label>'+
'<p id="ffRewardRedeemStatus" role="status"></p><div class="actions">'+
'<button class="primary" id="ffRewardRedeemButton" type="submit">✅ اعتماد واستهلاك الكود مرة واحدة</button>'+
'<button type="button" id="ffRewardRedeemClose" class="outline">إلغاء</button></div></form>';
document.body.append(dialog);
const issueForm=$('ffRewardIssueForm'),redeemForm=$('ffRewardRedeemForm'),iff=k=>issueForm.elements.namedItem(k),rff=k=>redeemForm.elements.namedItem(k);
function syncRole(){
 manager.hidden=!authManager();service.hidden=!(authed()&&['manager','customer_service'].includes(role()));
 cashier.hidden=!(authed()&&role()==='cashier');
}
window.addEventListener('ff-assembly-snapshot-success',syncRole);
window.addEventListener('ff-luxe-session-reset',()=>{catalog=[];issueQuantities.clear();chosen=null;token=null;submitBusy=false;manager.hidden=true;service.hidden=true;cashier.hidden=true;if(dialog.open)dialog.close()});
setInterval(syncRole,8000);syncRole();
async function loadCatalog(){
 if(catalog.length)return catalog;
 const result=await rpc('ff49_catalog');
 if(!Array.isArray(result))throw Error('تعذر تحميل المنيو');
 catalog=result.filter(x=>x?.kind==='item'&&x.id&&x.name);
 return catalog;
}
function renderManagerItems(){
 const list=$('ffRewardManagerItems');list.replaceChildren();
 const query=$('ffRewardItemSearch').value.trim().toLowerCase();
 const matches=catalog.filter(x=>(x.name+' '+(x.category||'')).toLowerCase().includes(query));
 for(const item of matches){
  const card=el('div');card.className='ff-reward-item';
  const add=el('button',item.name);add.type='button';add.className='outline';
  const row=el('div');row.className='ff-reward-count';
  const minus=el('button','−');minus.type='button';minus.className='outline';
  const count=el('strong');const plus=el('button','+');plus.type='button';plus.className='primary';
  const update=()=>{const q=issueQuantities.get(item.id)||0;count.textContent=q+' قطعة';plus.disabled=q>=99;minus.disabled=q<=0};
  const set=delta=>{issueQuantities.set(item.id,Math.max(0,Math.min(99,(issueQuantities.get(item.id)||0)+delta)));update()};
  add.onclick=()=>set(1);minus.onclick=()=>set(-1);plus.onclick=()=>set(1);
  row.append(minus,count,plus);card.append(add,row);list.append(card);update();
 }
}
async function managerOpen(){
 if(!authManager())return;
 try{await loadCatalog();renderManagerItems()}catch(e){$('ffRewardIssueStatus').textContent='تعذر تحميل المنيو: '+String(e.message||e)}
}
$('ffRewardItemSearch').oninput=renderManagerItems;
issueForm.addEventListener('submit',async ev=>{
 ev.preventDefault();if(!authManager()||submitBusy)return;
 const selected=catalog.filter(x=>Number(issueQuantities.get(x.id))>0).map(x=>({id:x.id,qty:issueQuantities.get(x.id)}));
 if(!selected.length){$('ffRewardIssueStatus').textContent='اختر الأصناف والكميات من المنيو';return}
 const btn=$('ffRewardIssue');btn.disabled=true;submitBusy=true;
 try{
  const res=await rpc('ff_reward_issue',{
   p_kind:iff('kind').value,p_name:iff('name').value.trim(),p_phone:iff('phone').value.trim(),
   p_items:selected,p_expiry_date:iff('expiry').value||null
  });
  if(!res?.saved)throw Error('لم يؤكد الخادم إصدار الكود');
  $('ffRewardResult').textContent='الكود: '+res.code;
  $('ffRewardIssueStatus').textContent='✅ تم إصدار الكود. يُستهلك مرة واحدة بأي فرع. احتفظ به لإرساله للعميل.';
  issueQuantities.clear();renderManagerItems();void managerRefresh();
 }catch(e){$('ffRewardIssueStatus').textContent='⚠️ '+String(e.message||e)}
 finally{btn.disabled=false;submitBusy=false}
});
async function managerRefresh(){
 if(!authManager())return;
 const box=$('ffRewardCodesList');box.textContent='جارٍ تحميل الأكواد...';
 try{
  const rows=await rpc('ff_reward_list',{p_limit:50});
  box.replaceChildren();
  if(!rows?.length)box.textContent='لا توجد أكواد صادرة.';
  for(const x of rows){
   const line=el('article');line.style.cssText='border:1px solid #ccc;border-radius:10px;padding:10px;margin:8px 0';
   line.append(el('strong',x.code+' · '+({compensation:'تعويض',prize:'جائزة',hospitality:'ضيافة'}[x.kind]||x.kind)));
   line.append(el('p',x.recipient_name+' · '+x.recipient_phone+' · '+(x.status==='issued'?'متاح':'مستخدم/ملغى')));
   line.append(el('p',(x.items||[]).map(y=>y.qty+' × '+y.name).join('، ')));
   if(x.status==='issued'){
    const cancel=el('button','إلغاء الكود');cancel.type='button';cancel.className='outline';
    cancel.onclick=async()=>{if(!confirm('هل تلغي هذا الكود غير المستخدم؟'))return;await rpc('ff_reward_void',{p_code:x.code});void managerRefresh()};
    line.append(cancel);
   }
   box.append(line);
  }
 }catch(e){box.textContent='تعذر جلب الأكواد: '+String(e.message||e)}
}
$('ffRewardCodesRefresh').onclick=()=>void managerRefresh();
function updateMode(){
 const mode=rff('channel').value;
 $('ffRewardDeliveryDetails').hidden=mode!=='delivery';
 rff('area').required=mode==='delivery';
}
rff('channel').onchange=updateMode;
async function beginRedeem(code,mode){
 if(!canRedeem())return;
 const input=String(code||'').trim().toUpperCase();
 if(!input)return typeof toast==='function'&&toast('أدخل كود الخصم');
 const actor=user.id;redeemMode=mode;redeemCode=input;chosen=null;token=crypto.randomUUID();
 $('ffRewardRedeemStatus').textContent='جارٍ فحص الكود...';
 if(!dialog.open)dialog.showModal();
 try{
  const x=await rpc('ff_reward_check',{p_code:input});
  if(actor!==user?.id||!canRedeem())return;
  chosen=x;
  $('ffRewardPreview').textContent=({compensation:'تعويض',prize:'جائزة',hospitality:'ضيافة'}[x.kind]||x.kind)+
   ' · العميل: '+x.customer_name+' · الهاتف: '+x.customer_phone;
  const items=$('ffRewardPreviewItems');items.replaceChildren();
  for(const item of x.items||[])items.append(el('p','🍟 '+item.qty+' × '+item.name+' · الأصناف مجانية'));
  const branch=rff('branch');branch.replaceChildren();
  for(const b of data?.branches||[])branch.add(new Option(b.name,b.id));
  rff('channel').value=mode==='cashier'?'reservation':'delivery';
  $('ffRewardChannelLabel').hidden=mode==='cashier';
  rff('channel').disabled=mode==='cashier';
  rff('verify').checked=false;rff('notes').value='';rff('area').value='';
  rff('fee').value='0';updateMode();
  $('ffRewardDeliveryDetails').hidden=mode==='cashier';
  $('ffRewardRedeemStatus').textContent='تأكد من هوية العميل. لن يُخصم الكود إلا عند حفظ الطلب بنجاح.';
 }catch(e){$('ffRewardRedeemStatus').textContent='⚠️ '+String(e.message||e)}
}
$('ffRewardServiceApply').onclick=()=>beginRedeem($('ffRewardServiceCode').value,'service');
$('ffRewardCashierApply').onclick=()=>beginRedeem($('ffRewardCashierCode').value,'cashier');
$('ffRewardRedeemClose').onclick=()=>{if(!submitBusy)dialog.close()};
redeemForm.addEventListener('submit',async e=>{
 e.preventDefault();
 if(!chosen||submitBusy||!canRedeem())return;
 if(!rff('verify').checked){$('ffRewardRedeemStatus').textContent='أكد مطابقة بيانات العميل';return}
 submitBusy=true;const button=$('ffRewardRedeemButton');button.disabled=true;
 const channel=redeemMode==='cashier'?'cashier_pickup':rff('channel').value;
 try{
  const result=await rpc('ff_reward_redeem',{
   p_code:redeemCode,p_branch:rff('branch').value,p_channel:channel,
   p_area:channel==='delivery'?rff('area').value.trim():'',
   p_fee:channel==='delivery'?Number(rff('fee').value):0,
   p_notes:rff('notes').value.trim(),p_token:token,p_identity_confirmed:true
  });
  if(!result?.saved)throw Error('لم يؤكد الخادم الاستهلاك');
  dialog.close();token=null;chosen=null;
  if(typeof toast==='function')toast('✅ تم إنشاء طلب التعويض واستُهلك الكود مرة واحدة');
  if(channel!=='delivery'&&typeof ff49OpenReservations==='function')ff49OpenReservations();
  if(typeof reload==='function')void reload(true);
  if(redeemMode==='cashier')$('ffRewardCashierCode').value='';
  else $('ffRewardServiceCode').value='';
 }catch(e){$('ffRewardRedeemStatus').textContent='⚠️ '+String(e.message||e)}
 finally{submitBusy=false;button.disabled=false}
});
const observer=new MutationObserver(()=>{if(authManager()&&!manager.hidden&&catalog.length===0)void managerOpen()});
observer.observe(document.getElementById('staffView')||document.body,{attributes:true,attributeFilter:['class','hidden'],subtree:false});
document.addEventListener('click',ev=>{if(ev.target.closest('#ffRewardManager')&&!catalog.length)void managerOpen()},true);
setInterval(()=>{if(authManager()&&!catalog.length)void managerOpen()},13000);
})();
