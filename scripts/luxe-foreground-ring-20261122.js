/* Fresh Fries LUXE: foreground ringing until confirmed receipt. */
'use strict';
(()=>{
 const css='@keyframes ffOrderRingPulse{0%,100%{box-shadow:0 0 0 2px #dc262655}50%{box-shadow:0 0 0 6px #dc262633}}'+
  '#driverOffers .ff-live-ringing,#cashierOrders .ff-live-ringing{border:4px solid #2563eb!important;outline:2px solid #dc2626;border-radius:18px;animation:ffOrderRingPulse 1.6s ease-in-out infinite}'+
  '.ff-live-ring-note{display:block;background:#fee2e2;color:#991b1b;border:2px solid #dc2626;border-radius:11px;margin:0 0 12px;padding:10px 12px;font-size:clamp(14px,2.4vw,18px);line-height:1.6;font-weight:900}'+
  '@media(prefers-reduced-motion:reduce){#driverOffers .ff-live-ringing,#cashierOrders .ff-live-ringing{animation:none}}';
 const style=document.createElement('style');style.id='ff-luxe-foreground-ring';style.textContent=css;document.head.append(style);
 let lastPlay=0,ringing=false,actor='';
 let suppressFirst=(()=>{try{return new URL(location.href).searchParams.get('ff_push_opened')==='1'}catch{return false}})();
 const mutedKeys=new Set();
 if(suppressFirst)try{const url=new URL(location.href);url.searchParams.delete('ff_push_opened');history.replaceState(history.state,'',url.pathname+url.search+url.hash)}catch{}
 const activeRole=()=>{
  try{return document.hidden||!user?.id||!data?.role?null:data.role}catch{return null}
 };
 function stop(){
  if(ringing&&typeof window.ffLuxeStopAlertAudio==='function')window.ffLuxeStopAlertAudio();
  ringing=false;lastPlay=0;
 }
 function clearIndicators(){
  document.querySelectorAll('.ff-live-ring-note').forEach(el=>el.remove());
  document.querySelectorAll('.ff-live-ringing').forEach(el=>el.classList.remove('ff-live-ringing'));
 }
 function pending(){
  const role=activeRole(),result=[];
  if(role==='driver')for(const offer of data.offers||[]){
   const card=[...document.querySelectorAll('#driverOffers .offer[data-ff-ring-offer]')].find(el=>el.dataset.ffRingOffer===String(offer.id));
   if(card)result.push({key:'offer:'+offer.id,card,tip:'🔔 طلب توصيل جديد — اضغط «قبول الطلب» لإيقاف الرنين'});
  }
  if(role==='cashier'){
   for(const o of data.orders||[]){
    if(!o?.id||!o.phase||o.cashier_stage!=='waiting'||o.cashier_received_at)continue;
    if(['cancelled','canceled','delivered','closed'].includes(String(o.status||'').toLowerCase()))continue;
    const card=[...document.querySelectorAll('#cashierOrders .item[data-ff-ring-order]')].find(el=>el.dataset.ffRingOrder===String(o.id));
    if(card)result.push({key:'cashier:'+o.id,card,tip:'🔔 طلب جديد — اضغط «استلمت الطلب» لإيقاف الرنين'});
   }
   for(const card of document.querySelectorAll('#cashierOrders .ff-luxe-cancelled[data-ff-luxe-cancel]'))
    result.push({key:'cancel:'+card.dataset.ffLuxeCancel,card,tip:'🚫 طلب ملغي — راجع الفاتورة وسجّل الإقرار لإيقاف التنبيه'});
  }
  return result;
 }
 function reconcile(){
  const role=activeRole(),who=role?String(user.id)+':'+role:'';
  if(actor!==who){stop();clearIndicators();actor=who;mutedKeys.clear()}
  if(!who)return;
  const all=pending();
  if(suppressFirst&&who){for(const item of all)mutedKeys.add(item.key);suppressFirst=false}
  const liveKeys=new Set(all.map(item=>item.key));for(const key of mutedKeys)if(!liveKeys.has(key))mutedKeys.delete(key);
  const active=all.filter(item=>!mutedKeys.has(item.key)),cards=new Set(active.map(item=>item.card));
  for(const card of document.querySelectorAll('.ff-live-ringing'))if(!cards.has(card)){
   card.classList.remove('ff-live-ringing');card.querySelector('.ff-live-ring-note')?.remove();
  }
  for(const item of active){
   const card=item.card;card.classList.add('ff-live-ringing');
   let note=card.querySelector('.ff-live-ring-note');
   if(!note){note=document.createElement('div');note.className='ff-live-ring-note';card.prepend(note)}
   if(note.textContent!==item.tip)note.textContent=item.tip;
  }
  if(!active.length){stop();return}
  ringing=true;
  if(Date.now()-lastPlay>=3500){
   lastPlay=Date.now();
   if(typeof window.ffLuxePlayAlert==='function')
    window.ffLuxePlayAlert(active.some(item=>item.key.startsWith('cancel:'))?'late':'new');
  }
 }
 window.ffLuxeRefreshForegroundRinging=reconcile;
 navigator.serviceWorker?.addEventListener('message',event=>{
  if(event.data?.type!=='FF_LUXE_NOTIFICATION_OPENED')return;
  const all=pending();
  if(all.length){for(const item of all)mutedKeys.add(item.key)}else suppressFirst=true;
  stop();clearIndicators();
 });
 document.addEventListener('visibilitychange',()=>{if(document.hidden){stop();clearIndicators()}else reconcile()});
 window.addEventListener('pagehide',()=>{stop();clearIndicators()});
 window.addEventListener('focus',reconcile);
 window.addEventListener('ff-assembly-snapshot-success',()=>requestAnimationFrame(reconcile));
 document.addEventListener('click',e=>{
  if(e.target.closest('[data-accept],[data-ff49-receive],[data-ff-luxe-ack]'))setTimeout(reconcile,1200);
 });
 setInterval(reconcile,1200);
 reconcile();
})();