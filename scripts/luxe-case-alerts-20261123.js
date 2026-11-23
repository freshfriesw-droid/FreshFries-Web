/* Fresh Fries LUXE: manager, supervisor and CS notifications for order-linked cases. */
(function(){
'use strict';
const $=id=>document.getElementById(id);
const allowed=new Set(['manager','supervisor','customer_service']);
const identity=()=>typeof user!=='undefined'&&user?.id||'';
const canView=()=>!!identity()&&typeof data!=='undefined'&&allowed.has(data?.role);
const bell=$('ffx-bell');if(!bell)return;
const badge=document.createElement('span');badge.id='ffCaseAlertBadge';badge.hidden=true;
badge.style.cssText='background:#d32037;color:#fff;border-radius:99px;position:absolute;top:1px;right:0;min-width:19px;padding:1px 3px;font-size:11px;font-weight:bold;box-shadow:0 0 0 2px #fff';
bell.style.position='relative';bell.append(badge);
const modal=document.createElement('dialog');modal.id='ffCaseAlertDialog';
modal.style.cssText='width:min(94vw,560px);max-height:86vh;overflow:auto;border:2px solid #d32037;border-radius:16px;padding:16px;direction:rtl;background:#fff;color:#111';
modal.innerHTML='<div style="display:flex;justify-content:space-between;align-items:center;gap:12px"><h3>🚨 بلاغات الطلبات</h3><button type="button" id="ffCaseAlertClose" class="outline">إغلاق</button></div>'+
'<p>التنبيهات المرتبطة بطلبات العملاء حسب الصلاحيات والفروع.</p>'+
'<div id="ffCaseAlertStatus" role="status"></div><div id="ffCaseAlertRows"></div>'+
'<div class="actions"><button id="ffCaseAlertRefresh" class="outline">تحديث</button><button id="ffCaseOtherAlerts" class="outline">التنبيهات التشغيلية الأخرى</button></div>';
document.body.append(modal);
let current='',items=[],unread=0,first=true,seenInSession=new Set(),activeReq=0,fetchAt=0,busy=false;
const status=$('ffCaseAlertStatus'),rows=$('ffCaseAlertRows');
function reset(){activeReq++;current='';items=[];unread=0;first=true;seenInSession.clear();fetchAt=0;busy=false;badge.hidden=true;if(modal.open)modal.close();rows.replaceChildren()}
window.addEventListener('ff-luxe-session-reset',reset);
function text(node,tag,value){const el=document.createElement(tag);el.textContent=String(value??'');node.append(el);return el}
function notify(c){
 try{if(typeof ding==='function')ding()}catch(_){}
 try{if(typeof toast==='function')toast('🚨 شكوى على طلب #'+c.order_number+' — '+c.subject)}catch(_){}
 if('Notification'in window&&Notification.permission==='granted'){
  try{new Notification('🚨 بلاغ مرتبط بطلب',{body:'طلب #'+c.order_number+' · '+c.subject,tag:'ff-case-'+c.id})}catch(_){}
 }
}
function draw(){
 badge.hidden=unread<1;badge.textContent=unread>99?'99+':String(unread);
 status.textContent='بلاغات غير مقروءة: '+unread;
 rows.replaceChildren();
 if(!items.length){text(rows,'p','لا توجد بلاغات مرتبطة بالطلبات.');return}
 for(const c of items){
  const card=document.createElement('article');card.style.cssText='border:1px solid #ccc;border-inline-start:4px solid '+(c.seen?'#888':'#d32037')+';border-radius:10px;padding:12px;margin:10px 0';
  text(card,'strong','طلب #'+c.order_number+' · '+c.subject);
  text(card,'p',(c.branch_name||'')+' · '+new Date(c.created_at).toLocaleString('ar-YE',{timeZone:'Asia/Aden'}));
  text(card,'p',c.seen?'مقروء':'🔴 جديد · '+(c.priority==='high'?'أولوية عالية':'بانتظار المراجعة'));
  const button=document.createElement('button');button.className='primary';button.type='button';button.textContent='فتح البلاغ والردود';
  button.onclick=async()=>{
   const previous=identity();button.disabled=true;
   try{
    await rpc('ff_case_alert_read',{p_case:c.id});
    if(identity()!==previous)return;
    c.seen=true;unread=Math.max(0,unread-1);draw();modal.close();
    const parent=$('ff41Panel');
    if(parent?.classList.contains('hidden'))$('ff41CasesBtn')?.click();
    if(typeof ff41ShowDetail==='function')await ff41ShowDetail(c.id);
    parent?.scrollIntoView({block:'start',behavior:'smooth'});
   }catch(e){status.textContent='تعذر فتح البلاغ: '+String(e.message||e)}
   finally{button.disabled=false}
  };
  card.append(button);rows.append(card);
 }
}
async function refresh(force=false){
 if(!canView()){
   if(current)reset();
   return;
 }
 const actor=identity();if(!force&&Date.now()-fetchAt<12000)return;
 if(busy)return;busy=true;fetchAt=Date.now();const token=++activeReq;
 try{
  const result=await rpc('ff_case_alerts',{p_limit:50});
  if(token!==activeReq||identity()!==actor||!canView())return;
  if(current!==actor){current=actor;first=true;seenInSession.clear()}
  const previous=seenInSession;
  items=Array.isArray(result?.items)?result.items:[];
  unread=Number(result?.unread_count||0);
  for(const c of items){
   if(!c.seen&&!previous.has(c.id)){
    if(!first)notify(c);
    previous.add(c.id);
   }
  }
  first=false;draw();
 }catch(e){if(modal.open)status.textContent='تعذر تحديث الإشعارات: '+String(e.message||e)}
 finally{busy=false}
}
const otherAlerts=bell.onclick;
bell.addEventListener('click',e=>{
 if(!canView())return;
 e.preventDefault();e.stopImmediatePropagation();
 if(!modal.open)modal.showModal();draw();void refresh(true);
},true);
$('ffCaseAlertClose').onclick=()=>modal.close();
$('ffCaseAlertRefresh').onclick=()=>void refresh(true);
$('ffCaseOtherAlerts').onclick=()=>{modal.close();if(typeof otherAlerts==='function')otherAlerts()};
window.ffCaseAlertRefresh=()=>refresh(true);
setInterval(()=>{if(canView()&&!document.hidden)void refresh()},13000);
document.addEventListener('visibilitychange',()=>{if(!document.hidden)void refresh(true)});
window.addEventListener('focus',()=>void refresh(true));
void refresh();
})();