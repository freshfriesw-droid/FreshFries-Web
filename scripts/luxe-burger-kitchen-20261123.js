/* Fresh Fries LUXE - Cashier to Burger Kitchen, realtime + safe polling. */
(function(){
'use strict';
const $=id=>document.getElementById(id);
const make=(tag,txt,cls)=>{const el=document.createElement(tag);if(txt!==undefined)el.textContent=String(txt);if(cls)el.className=cls;return el};
const time=v=>v?new Date(v).toLocaleString('ar-YE',{timeZone:'Asia/Aden',hour:'2-digit',minute:'2-digit',day:'2-digit',month:'2-digit'}):'—';
const clock=v=>{const n=Math.max(0,Math.floor(v));return [Math.floor(n/3600),Math.floor(n/60)%60,n%60].map(x=>String(x).padStart(2,'0')).join(':')};
const css=make('style');
css.textContent='#ffBurgerCashierPanel,#ffBurgerKitchenWorkspace{border:2px solid #d52a3a;border-radius:15px;padding:15px;margin:12px 0;background:var(--ffb-surface,#fff);direction:rtl;color:var(--ffb-ink,#111)}'+
'.ff-burger-head{display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px}.ff-burger-list{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(280px,100%),1fr));gap:12px;margin:12px 0}'+
'.ff-burger-card{border:1px solid #bcbcbc;border-right:5px solid #d52a3a;border-radius:11px;padding:12px;background:var(--ffb-surface,#fff)}.ff-burger-card.ready{border-color:#117d5b}.ff-burger-card p{margin:6px 0;white-space:pre-wrap;overflow-wrap:anywhere}'+
'.ff-burger-clock{direction:ltr;font:800 22px monospace;color:#c21b31}.ff-burger-chip{background:#eee;color:#222;padding:4px 7px;border-radius:8px;font-size:12px}'+
'#ffBurgerDialog{width:min(95vw,580px);max-height:90vh;overflow:auto;border:0;border-top:6px solid #d52a3a;border-radius:15px;padding:17px;color:#111;background:#fff;direction:rtl}'+
'#ffBurgerDialog::backdrop{background:#000b}.ff-burger-item{display:grid;grid-template-columns:1fr 95px;gap:10px;padding:8px;border:1px solid #ddd;border-radius:9px;align-items:center;margin:6px 0}.ff-burger-item input{text-align:center;direction:ltr}'+
'body.ff-burger-kitchen-mode main>:not(#ffBurgerKitchenWorkspace){display:none!important}body.ff-burger-kitchen-mode #ffBurgerKitchenWorkspace{display:block!important}'+
'@media(max-width:600px){.ff-burger-list{display:block}.ff-burger-card{margin-bottom:10px}#ffBurgerDialog{padding:12px}}';
css.textContent +=
 '.ff-burger-item{grid-template-columns:minmax(0,1fr) 124px;align-items:stretch;background:var(--ffb-surface,#fff);transition:border-color .18s,background-color .18s;gap:9px}'+
 '.ff-burger-item.selected{border-color:#d72e42;background:rgba(209,33,53,.07)}'+
 '.ff-burger-product{width:100%;height:100%;min-height:85px;text-align:right;white-space:normal;padding:12px;border-radius:10px;font-weight:800;line-height:1.5;overflow-wrap:anywhere;border:1px solid #bdc0c4;background:#f7f7f7;color:#171717;box-shadow:none!important}'+
 '.ff-burger-item.selected .ff-burger-product{border-color:#ca2036;background:#fbe6e9;color:#9e132a}'+
 '.ff-burger-qty{display:flex;flex-direction:column;gap:6px;align-items:center;justify-content:center;min-width:0}'+
 '.ff-burger-qty input{width:100%;max-width:115px;min-height:42px;text-align:center;direction:ltr;font-size:20px;font-weight:800;border-radius:9px}'+
 '.ff-burger-stepper{display:grid;grid-template-columns:1fr 1fr;gap:5px;width:100%;direction:ltr}'+
 '.ff-burger-stepper button{min-height:40px;padding:4px;border:1px solid #be263b;border-radius:9px;font-size:23px;font-weight:900;box-shadow:none!important;background:#ca2137;color:white;touch-action:manipulation}'+
 '.ff-burger-stepper button:disabled{opacity:.35;cursor:not-allowed}'+
 '.ff-burger-stepper .ff-burger-minus{background:#fff;color:#ad2133}'+
 '@media(max-width:360px){.ff-burger-item{grid-template-columns:minmax(0,1fr) 110px;gap:6px}.ff-burger-product{padding:8px}}';
css.textContent += '.ff-burger-ticket-products{margin:13px 0;padding:11px;border:1px solid #d9d9d9;border-radius:12px;background:var(--ffb-soft,#f8f8f8)}.ff-burger-ticket-products h5{font-size:15px;margin:0 0 9px;font-weight:800}.ff-burger-ticket-product-list{display:flex;flex-direction:column;gap:7px}.ff-burger-ticket-product-row{display:flex;align-items:flex-start;gap:10px;padding:10px 9px;border:1px solid #e0e0e0;border-radius:9px;background:var(--ffb-surface,#fff);font-size:16px;font-weight:700;line-height:1.5}.ff-burger-ticket-product-qty{display:inline-flex;flex:0 0 auto;min-width:55px;justify-content:center;background:#b91c30;color:#fff;border-radius:7px;padding:3px 8px;font-weight:900;font-variant-numeric:tabular-nums}.ff-burger-ticket-product-name{flex:1;overflow-wrap:anywhere}';\ncss.textContent += '.ff-burger-urgent-note{border:3px solid #e0203c;background:#fff1e7;color:#76132b;padding:13px;border-radius:12px;margin:11px 0;font-size:clamp(17px,3.5vw,21px);font-weight:950;white-space:pre-wrap;overflow-wrap:anywhere;line-height:1.8}'+
'.ff-burger-note-confirm{display:flex;align-items:start;gap:10px;border:2px solid #c12e48;border-radius:9px;padding:12px;background:#fff8ee;font-size:15px;font-weight:800;color:#832034}'+
'.ff-burger-note-confirm input{width:24px;height:24px;flex-shrink:0;accent-color:#c12e48}'+
'.ff-burger-online{display:inline-block;border:1px solid #999;border-radius:9px;padding:8px;font-weight:900;margin:7px 0}'+
'.ff-burger-online.live{border-color:#128157;color:#128157;background:#e7fff1}'+
'.ff-burger-online.offline{border-color:#b91c1c;color:#b91c1c;background:#fff2f2}';
document.head.append(css);
const main=document.querySelector('main');if(!main)return;
const kitchen=make('section');kitchen.id='ffBurgerKitchenWorkspace';kitchen.className='card hidden';
kitchen.innerHTML='<div class="ff-burger-head"><h2>🍔 المطبخ · قسم البرجر</h2><button type="button" class="outline" id="ffBurgerKitchenNotifications">🔔 تفعيل الإشعارات</button><button type="button" class="primary" id="ffBurgerViewFinished">✅ الطلبات المنتهية <span id="ffBurgerDoneCount">0</span></button><button type="button" class="outline" id="ffBurgerKitchenRefresh">تحديث</button><button type="button" class="outline" id="ffBurgerKitchenLogout">🚪 تسجيل الخروج</button></div>'+
'<p id="ffBurgerKitchenBranch" class="muted"></p><p id="ffBurgerKitchenStatus" role="status"></p>'+
'<h3>الطلبات الواردة والجاري تحضيرها</h3><div id="ffBurgerKitchenActive" class="ff-burger-list"></div>'+
'<details id="ffBurgerFinishedDetails"><summary>✅ الطلبات المنتهية · قسم البرجر</summary><div id="ffBurgerKitchenFinished" class="ff-burger-list"></div></details>';
main.prepend(kitchen);
const cashier=$('cashierView');const panel=make('section');panel.id='ffBurgerCashierPanel';panel.className='card hidden';
panel.innerHTML='<div class="ff-burger-head"><h3>🍔 أوامر قسم البرجر</h3><button id="ffBurgerNew" type="button" class="primary">🍔 إعلام قسم البرجر</button></div>'+
'<p class="muted">اختر البرجر والكمية والفرع، ثم اكتب رقم فاتورة الكاشير والملاحظات. هذا لا يغير فاتورة MicroPOS أو حالة التوصيل.</p>'+
'<p id="ffBurgerKitchenOnline" class="ff-burger-online offline" role="status">🔴 قسم البرجر غير متصل حاليًا</p><p id="ffBurgerCashierStatus" role="status"></p>'+
'<h3>🔔 جاهز للاستلام · اضغط تخطي بعد الإشعار</h3><div id="ffBurgerCashierReady" class="ff-burger-list"></div>'+
'<details><summary>🕓 الطلبات الجارية</summary><div id="ffBurgerCashierActive" class="ff-burger-list"></div></details>'+
'<details><summary>✅ الطلبات المنتهية · قسم البرجر</summary><div id="ffBurgerCashierFinished" class="ff-burger-list"></div></details>';
cashier?.prepend(panel);
const dialog=make('dialog');dialog.id='ffBurgerDialog';
dialog.innerHTML='<h2>🍔 إعلام قسم البرجر</h2><form id="ffBurgerForm">'+
'<label>الفرع<select name="branch" required></select></label>'+
'<label>نوع الطلب<select name="kind" required><option value="local">محلي</option><option value="delivery">توصيل</option></select></label>'+
'<label id="ffBurgerOrderLabel">طلب التوصيل المرتبط<select name="order"></select></label>'+
'<label>رقم فاتورة الكاشير (اختياري)<input name="invoice" maxlength="80" placeholder="يمكن تركه فارغًا إذا لم توجد فاتورة"></label>'+
'<h3>أصناف البرجر</h3><div id="ffBurgerMenuFields"></div>'+
'<label>الملاحظات (إن وجدت)<textarea name="notes" rows="3" maxlength="1000"></textarea></label>'+
'<p id="ffBurgerDialogStatus" role="status"></p><div class="actions">'+
'<button id="ffBurgerSubmit" class="primary" type="submit">✅ اعتماد وإرسال الطلب</button><button id="ffBurgerCancel" class="outline" type="button">إلغاء</button></div></form>';
document.body.append(dialog);
const form=$('ffBurgerForm'),f=name=>form.elements.namedItem(name);
let isKitchenMode=false,profile=null,items=[],rows=[],channel=null,interval=null,loading=false,fetchAt=0,seq=0,owner='',initial=true,lastNew=new Set(),lastReady=new Set(),busy=false,token=null,presenceAt=0;
const assemblyRole=()=>typeof ffV12AssemblyActive!=='undefined'&&ffV12AssemblyActive&&typeof user!=='undefined'&&!!user?.id;
const cashierRole=()=>typeof data!=='undefined'&&data?.role==='cashier'&&typeof user!=='undefined'&&!!user?.id;
const kitchenRole=()=>isKitchenMode&&profile?.role==='burger_kitchen'&&typeof user!=='undefined'&&!!user?.id;
const authorized=()=>cashierRole()||assemblyRole()||kitchenRole();
const identity=()=>String(typeof user!=='undefined'&&user?.id||'');
// The regular navigation relies on data.role; kitchen sessions use data=null.
 // Render the account controls independently instead of displaying "not logged in".
 const kitchenNavId='ffBurgerDrawerLogout';
 function kitchenLogout(){
   if(!isKitchenMode||!identity())return;
   const button=$('logoutBtn');
   if(!button){$('ffBurgerKitchenStatus').textContent='تعذر العثور على زر تسجيل الخروج؛ حدّث الصفحة';return}
   void rpc('ff_burger_presence_ping',{p_online:false}).catch(()=>{});button.click(); // Never wait for network to sign out.
 }
 function attachKitchenDrawer(){
   const nav=$('ffx-nav');
   if(nav&&!$(kitchenNavId)){
     const button=make('button','🚪 تسجيل الخروج');
     button.id=kitchenNavId;button.type='button';button.className='ffx-side-link';
     button.style.cssText='color:#fff!important;border:1px solid #b92b3a;background:#b21e2a2c;min-height:50px';
     button.addEventListener('click',kitchenLogout);
     nav.append(button);
   }
   const name=$('ffx-profile-name'),role=$('ffx-profile-role');
   if(name)name.textContent=user?.email||user?.phone||'موظف قسم البرجر';
   if(role)role.textContent='🍔 قسم البرجر · '+(profile?.branches?.[0]?.name||'الفرع');
 }

const errorText=e=>String(e?.message||e);
function reset(){
  seq++;loading=false;fetchAt=0;presenceAt=0;owner='';isKitchenMode=false;profile=null;items=[];rows=[];initial=true;lastNew.clear();lastReady.clear();busy=false;token=null;
  panel.classList.add('hidden');kitchen.classList.add('hidden');document.body.classList.remove('ff-burger-kitchen-mode');
  $(kitchenNavId)?.remove();
  if(dialog.open)dialog.close();
  if(channel){try{client?.removeChannel(channel)}catch(_){}channel=null}
  if(interval){clearInterval(interval);interval=null}
  for(const id of ['ffBurgerKitchenActive','ffBurgerKitchenFinished','ffBurgerCashierReady','ffBurgerCashierActive','ffBurgerCashierFinished'])$(id)?.replaceChildren();
}
window.ffBurgerReset=reset;window.addEventListener('ff-luxe-session-reset',reset);
function seconds(ticket){
  if(!ticket.accepted_at)return 'لم يبدأ';
  const begin=Date.parse(ticket.accepted_at),end=ticket.ready_at?Date.parse(ticket.ready_at):Date.now();
  return clock((end-begin)/1000);
}
function createTicket(t,view){
 const card=make('article',undefined,'ff-burger-card'+(t.status==='ready'?' ready':''));
 card.append(make('h4',(t.invoice_ref?.trim()?'🧾 فاتورة '+t.invoice_ref:'🍔 طلب برجر بدون رقم فاتورة')+' · '+(t.order_kind==='local'?'محلي':'توصيل')));
 card.append(make('span',({sent:'🆕 وارد',preparing:'⏳ تحت التحضير',ready:'✅ جاهز للاستلام',acknowledged:'✅ تم التخطي'})[t.status]||t.status,'ff-burger-chip'));
 const line=v=>card.append(make('p',v));
 line('📍 '+t.branch_name+' · أُرسل '+time(t.sent_at));
 line('👤 الكاشير المرسل: '+t.cashier_name);
 line('👨‍🍳 موظف البرجر المستلم: '+(t.kitchen_name||'بانتظار الاستلام'));
 const products=make('section',undefined,'ff-burger-ticket-products');
 products.append(make('h5','🍔 أصناف الطلب'));
 const productList=make('div',undefined,'ff-burger-ticket-product-list');
 for(const item of t.items||[]){
   const row=make('div',undefined,'ff-burger-ticket-product-row');
   row.append(make('span',String(item.qty)+' ×','ff-burger-ticket-product-qty'));
   row.append(make('span',item.name||'صنف غير محدد','ff-burger-ticket-product-name'));
   productList.append(row);
 }
 if(!productList.children.length)productList.append(make('p','لا توجد أصناف مسجلة','muted'));
 products.append(productList);card.append(products);
 if(t.notes?.trim()){
   const notice=make('div','🚨 تعليمات خاصة يجب تنفيذها قبل التسليم:\n'+t.notes.trim(),'ff-burger-urgent-note');
   notice.setAttribute('role','alert');card.append(notice);
   if(t.notes_confirmed_at)line('✅ تأكيد تنفيذ الملاحظات: '+time(t.notes_confirmed_at));
 }
 const meter=make('p','⏱️ زمن التحضير: ');
 const duration=make('strong',seconds(t),'ff-burger-clock');
 duration.dataset.ffBurgerStart=t.accepted_at||'';duration.dataset.ffBurgerEnd=t.ready_at||'';
 meter.append(duration);card.append(meter);
 let action=null,label='';
 if(view==='kitchen'&&t.status==='sent'){action='receive';label='📥 استلمت الطلب'}
 else if(view==='kitchen'&&t.status==='preparing'&&String(t.kitchen_id||'')===identity()){action='ready';label='✅ الطلب جاهز للاستلام'}
 else if(view==='cashier'&&t.status==='ready'){action='skip';label='⏭ تخطي'}
 if(action){
   const b=make('button',label,'primary');b.type='button';
   if(action==='ready' && t.notes?.trim() && !t.notes_confirmed_at){
     const wrap=make('label',undefined,'ff-burger-note-confirm');
     const checked=make('input');checked.type='checkbox';
     checked.setAttribute('aria-label','أؤكد تنفيذ جميع الملاحظات');
     wrap.append(checked,make('span','أؤكد أنني قرأت جميع الملاحظات ونفذتها قبل إنهاء التحضير'));
     card.append(wrap);b.disabled=true;
     checked.addEventListener('change',()=>{b.disabled=!checked.checked});
     b.onclick=async()=>{
       if(!checked.checked)return toast('يجب تأكيد تنفيذ الملاحظات');
       b.disabled=true;
       try{await rpc('ff_burger_confirm_notes',{p_ticket:t.id});await transition(t.id,action,b,true)}
       catch(error){toast('تعذر اعتماد الملاحظة: '+errorText(error));b.disabled=false}
     };
   }else b.onclick=()=>transition(t.id,action,b);
   card.append(b);
 }else if(view==='kitchen'&&t.status==='preparing')line('قيد التحضير لدى الموظف المستلم');
 return card;
}
function fill(id,list,view){
 const root=$(id);root.replaceChildren();
 if(!list.length)root.append(make('p','لا توجد طلبات في هذه القائمة.','muted'));
 for(const t of list)root.append(createTicket(t,view));
}
function render(){
 if(!authorized()||identity()!==owner)return;
 if(kitchenRole()){
   kitchen.classList.remove('hidden');panel.classList.add('hidden');
   $('ffBurgerKitchenBranch').textContent='الفرع: '+(profile.branches?.[0]?.name||'—');
   const ongoing=rows.filter(t=>t.status==='sent'||t.status==='preparing');
   $('ffBurgerKitchenStatus').textContent='الوارد: '+ongoing.filter(t=>t.status==='sent').length+' · تحضير: '+ongoing.filter(t=>t.status==='preparing').length;
   fill('ffBurgerKitchenActive',ongoing,'kitchen');
   const finished=rows.filter(t=>t.status==='ready'||t.status==='acknowledged');
   $('ffBurgerDoneCount').textContent=String(finished.length);
   fill('ffBurgerKitchenFinished',finished,'kitchen');
 }else if(cashierRole()||assemblyRole()){
   const host=assemblyRole()?$('ffV12AssemblyWorkspace'):cashier;
   if(host&&panel.parentElement!==host)host.prepend(panel);
   panel.classList.remove('hidden');kitchen.classList.add('hidden');
   const ready=rows.filter(t=>t.status==='ready'),active=rows.filter(t=>t.status==='sent'||t.status==='preparing');
   $('ffBurgerCashierStatus').textContent='جاهز للاستلام: '+ready.length+' · تحت التحضير: '+active.length;
   fill('ffBurgerCashierReady',ready,'cashier');
   fill('ffBurgerCashierActive',active,'cashier');
   fill('ffBurgerCashierFinished',rows.filter(t=>t.status==='acknowledged'),'cashier');
 }
}
async function transition(id,action,b,confirmed=false){
 if(!authorized()||(!confirmed&&b.disabled))return;
 b.disabled=true;
 try{
   const r=await rpc('ff_burger_transition',{p_ticket:id,p_action:action});
   if(r?.saved!==true)throw Error('لم يؤكد الخادم تغيير الحالة');
   toast(({'receive':'بدأ عداد التحضير','ready':'تم إشعار الكاشير بجاهزية البرجر','skip':'تم نقل الإشعار إلى الطلبات المنتهية'})[action]);
   await refresh(true);
 }catch(e){toast('تعذر تحديث حالة البرجر: '+errorText(e))}finally{b.disabled=false}
}
function notify(title,body){
 try{if(typeof ding==='function')ding()}catch(_){}
 try{toast(title+' — '+body)}catch(_){}
 if('Notification'in window&&Notification.permission==='granted')
 try{new Notification(title,{body,tag:'ff-burger-'+title})}catch(_){}
}
async function updateOnline(force=false){
 if(!authorized()||!identity()||(!force&&Date.now()-presenceAt<15000))return;
 presenceAt=Date.now();
 try{
  if(kitchenRole())await rpc('ff_burger_presence_ping',{p_online:true});
  if(cashierRole()||assemblyRole()){
   const status=await rpc('ff_burger_online_status');
   const on=(Array.isArray(status)?status:[]).filter(x=>Number(x.online_count)>0);
   const badge=$('ffBurgerKitchenOnline');const live=on.length>0;
   badge.textContent=live?'🟢 قسم البرجر متصل ويستقبل الطلبات — '+on.map(x=>x.branch_name).join('، '):
    '🔴 قسم البرجر غير متصل الآن؛ يمكنك إرسال الطلب وسيظهر عند اتصال الموظف';
   badge.classList.toggle('live',live);badge.classList.toggle('offline',!live);
  }
 }catch(e){if(cashierRole()||assemblyRole())$('ffBurgerKitchenOnline').textContent='⚠️ تعذر التحقق من اتصال قسم البرجر'}
}
async function refresh(force=false){
 if(!authorized()||!identity()||loading||(!force&&Date.now()-fetchAt<5000))return;
 const previous=identity(),request=++seq;fetchAt=Date.now();loading=true;
 try{
   if(!profile){profile=await rpc('ff_burger_my_branch');items=await rpc('ff_burger_menu')}
   const fetched=await rpc('ff_burger_list',{p_limit:150});
   if(request!==seq||previous!==identity()||!authorized())return;
   const list=Array.isArray(fetched)?fetched:[];
   const newer=new Set(list.filter(t=>t.status==='sent').map(t=>t.id));
   const ready=new Set(list.filter(t=>t.status==='ready').map(t=>t.id));
   if(!initial){
    if(kitchenRole())for(const t of list.filter(t=>t.status==='sent'&&!lastNew.has(t.id)))notify('🍔 طلب برجر جديد',t.invoice_ref?.trim()?'فاتورة '+t.invoice_ref:'طلب بدون رقم فاتورة');
    if((cashierRole()||assemblyRole()))for(const t of list.filter(t=>t.status==='ready'&&!lastReady.has(t.id)))notify('✅ البرجر جاهز',t.invoice_ref?.trim()?'فاتورة '+t.invoice_ref:'طلب بدون رقم فاتورة');
   }
   lastNew=newer;lastReady=ready;initial=false;owner=identity();rows=list;render();
   void updateOnline(force);
 }catch(e){
   const element=$(kitchenRole()?'ffBurgerKitchenStatus':'ffBurgerCashierStatus');
   if(element)element.textContent='تعذر تحديث قسم البرجر: '+errorText(e);
 }finally{loading=false}
}
function heartbeat(){
 if(interval)return;
 interval=setInterval(()=>{if(authorized()&&!document.hidden){void refresh();void updateOnline()}},6000);
}
function subscribe(){
 if(channel||!client)return;
 channel=client.channel('ff-burger-live-'+identity())
  .on('postgres_changes',{event:'*',schema:'public',table:'ff_burger_tickets'},()=>void refresh(true))
  .subscribe();
}
window.ffBurgerActive=()=>isKitchenMode;
window.ffBurgerRefresh=()=>refresh(true);
window.ffBurgerStart=async()=>{
 reset();isKitchenMode=true;owner=identity();
 document.body.classList.add('ff-burger-kitchen-mode');
 kitchen.classList.remove('hidden');$('logoutBtn')?.classList.remove('hidden');
 $('identity').textContent='🍔 موظف قسم البرجر · '+(user?.email||'');
 attachKitchenDrawer(); // Logout must remain available even if a network/RPC request fails.
 profile=await rpc('ff_burger_my_branch');
 if(profile?.role!=='burger_kitchen'||profile.branches?.length!==1)throw Error('لا يوجد فرع محدد لموظف قسم البرجر');
 items=await rpc('ff_burger_menu');attachKitchenDrawer();subscribe();heartbeat();await updateOnline(true);await refresh(true);
};
window.ffBurgerOnCashierDraw=()=>{
 if(!cashierRole()&&!assemblyRole())return;
 if(owner!==identity()){owner=identity();profile=null;initial=true;}
 panel.classList.remove('hidden');subscribe();heartbeat();void refresh();
};
window.ffBurgerOnAssemblyStart=()=>{if(!assemblyRole())return;window.ffBurgerOnCashierDraw();};
window.ffBurgerOnAssemblyStop=()=>{reset();if(cashier&&panel.parentElement!==cashier)cashier.prepend(panel);};
window.addEventListener('ff-assembly-snapshot-success',()=>{if(cashierRole())window.ffBurgerOnCashierDraw()});
document.addEventListener('visibilitychange',()=>{if(!document.hidden&&authorized())void refresh(true)});
window.addEventListener('focus',()=>{if(authorized())void refresh(true)});
setInterval(()=>document.querySelectorAll('[data-ff-burger-start]').forEach(el=>{
 const start=Date.parse(el.dataset.ffBurgerStart||'');
 if(!Number.isFinite(start))return;
 const end=Date.parse(el.dataset.ffBurgerEnd||'');
 el.textContent=clock(((Number.isFinite(end)?end:Date.now())-start)/1000);
}),1000);
async function open(initialKind='local',linkedOrder=''){
 if(!cashierRole()&&!assemblyRole())return;
 try{if(!profile)profile=await rpc('ff_burger_my_branch');if(!items.length)items=await rpc('ff_burger_menu')}
 catch(e){toast('تعذر جلب أصناف البرجر: '+errorText(e));return}
 if(!items.length){toast('لا توجد أصناف برجر نشطة بالمنيو');return}
 form.reset();token=crypto.randomUUID();$('ffBurgerDialogStatus').textContent='';
 const branch=f('branch');branch.replaceChildren();
 for(const b of profile.branches||[])branch.add(new Option(b.name,b.id));
 f('kind').value=initialKind;
 const order=f('order');
 function refreshOrders(){
  const old=order.value;order.replaceChildren(new Option('اختر طلب التوصيل',''));
  const candidates=assemblyRole()?(ffV12AssemblyPayload?.orders||[]):(data?.orders||[]);
  for(const o of candidates.filter(x=>(assemblyRole()?ffV12AssemblyPayload?.branch?.id:x.branch_id)===branch.value&&
     !['cancelled','canceled','closed','delivered'].includes(x.status)))
   order.add(new Option('طلب #'+o.number+' · '+(o.area||'توصيل'),o.id));
  if([...order.options].some(x=>x.value===old))order.value=old;
 }
 refreshOrders();
 if(linkedOrder&&[...order.options].some(x=>x.value===linkedOrder)){
  order.value=linkedOrder;
  f('invoice').value=(assemblyRole()?ffV12AssemblyPayload?.orders:data?.orders)?.find(x=>x.id===linkedOrder)?.external_invoice_ref||'';
 }
 const box=$('ffBurgerMenuFields');box.replaceChildren();
 for(const item of items){
  const line=make('div',undefined,'ff-burger-item');
  const product=make('button',item.name,'ff-burger-product');product.type='button';
  product.setAttribute('aria-label','إضافة قطعة واحدة من '+item.name);product.setAttribute('aria-pressed','false');
  const count=make('div',undefined,'ff-burger-qty');
  const qty=make('input');
  qty.type='number';qty.min='0';qty.max='99';qty.step='1';qty.value='0';qty.inputMode='numeric';
  qty.dataset.burgerItem=item.id;qty.setAttribute('aria-label','كمية '+item.name);
  const controls=make('div',undefined,'ff-burger-stepper');
  const minus=make('button','−','ff-burger-minus'),plus=make('button','+','ff-burger-plus');
  minus.type=plus.type='button';
  minus.setAttribute('aria-label','إنقاص '+item.name+' بواحد');
  plus.setAttribute('aria-label','زيادة '+item.name+' بواحد');
  function sync(){
    const value=Number(qty.value);
    const valid=Number.isInteger(value)&&value>=0&&value<=99;
    line.classList.toggle('selected',valid&&value>0);
    product.setAttribute('aria-pressed',String(valid&&value>0));
    minus.disabled=!valid||value===0;plus.disabled=!valid||value===99;
  }
  function setQuantity(value){
    qty.value=String(Math.max(0,Math.min(99,value)));
    sync();
  }
  function shift(delta){
    const value=Number(qty.value);
    setQuantity((Number.isInteger(value)&&value>=0&&value<=99?value:0)+delta);
  }
  product.addEventListener('click',()=>shift(1));
  plus.addEventListener('click',()=>shift(1));
  minus.addEventListener('click',()=>shift(-1));
  qty.addEventListener('input',sync);
  qty.addEventListener('change',()=>{
    const raw=qty.value.trim(),value=Number(raw);
    setQuantity(raw!==''&&Number.isFinite(value)?Math.trunc(value):0);
  });
  controls.append(minus,plus);count.append(qty,controls);line.append(product,count);box.append(line);
  sync();
 }
 function toggle(){const delivery=f('kind').value==='delivery';$('ffBurgerOrderLabel').hidden=!delivery;order.required=delivery}
 f('kind').onchange=toggle;branch.onchange=refreshOrders;toggle();dialog.showModal();
}
$('ffBurgerNew').onclick=()=>void open('local');
document.addEventListener('click',e=>{
 const b=e.target.closest('button[data-ff-burger-notify]');if(!b)return;
 e.preventDefault();e.stopImmediatePropagation();void open('delivery',b.dataset.ffBurgerNotify);
},true);
$('ffBurgerCancel').onclick=()=>{if(!busy)dialog.close()};
form.addEventListener('submit',async e=>{
 e.preventDefault();if(busy||(!cashierRole()&&!assemblyRole()))return;
 const selected=[...form.querySelectorAll('[data-burger-item]')]
  .map(x=>({id:x.dataset.burgerItem,qty:Number(x.value)})).filter(x=>x.qty>0);
 if(!selected.length||selected.some(x=>!Number.isInteger(x.qty)||x.qty>99)){
   $('ffBurgerDialogStatus').textContent='حدد صنف برجر واحدًا على الأقل بكمية صحيحة';return
 }
 if(f('kind').value==='delivery'&&!f('order').value){$('ffBurgerDialogStatus').textContent='حدد طلب التوصيل المرتبط';return}
 busy=true;$('ffBurgerSubmit').disabled=true;$('ffBurgerDialogStatus').textContent='جارٍ إرسال أمر البرجر...';
 try{
  const saved=await rpc('ff_burger_send',{p_branch:f('branch').value,p_order_kind:f('kind').value,
    p_delivery_order:f('kind').value==='delivery'?f('order').value:null,
    p_invoice:f('invoice').value.trim(),p_items:selected,p_notes:f('notes').value.trim(),p_token:token});
  if(saved?.saved!==true)throw Error('لم يؤكد الخادم استلام الطلب');
  dialog.close();token=null;toast('✅ تم إرسال طلب البرجر إلى المطبخ');await refresh(true);
 }catch(err){$('ffBurgerDialogStatus').textContent='تعذر الإرسال: '+errorText(err)}
 finally{busy=false;$('ffBurgerSubmit').disabled=false}
});
$('ffBurgerViewFinished').onclick=()=>{const details=$('ffBurgerFinishedDetails');details.open=true;details.scrollIntoView({block:'start',behavior:'smooth'})};
$('ffBurgerKitchenRefresh').onclick=()=>void refresh(true);
$('ffBurgerKitchenLogout').onclick=kitchenLogout;
$('ffBurgerKitchenNotifications').onclick=()=>void window.ffLuxeSubscribePush?.();
})();
