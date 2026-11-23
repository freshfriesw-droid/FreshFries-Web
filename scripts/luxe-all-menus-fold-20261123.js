/* Fresh Fries LUXE — consistent open/close controls for operational menus. */
(()=>{'use strict';
 const css=document.createElement('style');css.id='ff-all-menu-fold-style';
 css.textContent=`
 .ff-menu-fold{position:relative;overflow:visible!important}
 .ff-menu-fold.ff-menu-closed>:not(.ff-menu-toggle){display:none!important}
 .ff-menu-toggle{display:flex!important;width:100%;align-items:center;justify-content:space-between;gap:12px;min-height:49px;margin:0 0 10px;padding:12px 15px;border:2px solid #c82239!important;border-radius:12px;background:linear-gradient(115deg,#242124,#121114)!important;color:#fff!important;text-align:right;font-size:clamp(14px,2.5vw,17px);font-weight:800;cursor:pointer}
 .ff-menu-toggle[aria-expanded=true]{background:linear-gradient(115deg,#a81329,#db263d)!important}
 .ff-menu-arrow{font-size:18px;flex:none;transition:transform .2s}
 .ff-menu-toggle[aria-expanded=true] .ff-menu-arrow{transform:rotate(180deg)}
 .ff-menu-inner-close{display:block;margin:12px auto 2px 0;border:1px solid #ba2436!important;border-radius:9px;padding:9px 15px;background:transparent!important;color:var(--ffb-ink,#252525)!important;font-weight:700}
 details.ff-menu-details>summary{cursor:pointer;border:1px solid #c82239;border-radius:9px;padding:10px 13px;font-weight:800}
 details.ff-menu-details[open]>summary{background:#bd1e33;color:#fff}
 `;
 document.head.append(css);
 const containers=['#staffView','#cashierView','#driverView','#serviceOnly','#ffV12AssemblyWorkspace','#ffBurgerKitchenWorkspace'];
 const skip=new Set(['ffBurgerCashierPanel','ffV12AssemblyWorkspace','ffBurgerKitchenWorkspace']);
 const labelFor=el=>{
  const h=el.querySelector(':scope > h2,:scope > h3,:scope > .sectionbar h2,:scope > .sectionbar h3,:scope > .ff-burger-head h3,:scope > .ff41-header h2');
  return (h?.textContent||el.getAttribute('aria-label')||'').trim().replace(/\\s+/g,' ').slice(0,100);
 };
 function fold(el){
  if(!el||el.dataset.ffMenuFold||el.querySelector(':scope > .ffl-fold-toggle')||el.classList.contains('ffl-folded-card')||skip.has(el.id))return;
  if(el.classList.contains('hidden')&&el.parentElement?.tagName==='MAIN')return; // Opened via existing navigation.
  if(el.closest('dialog,[role=dialog],#loginOverlay'))return;
  const label=labelFor(el);if(!label)return;
  el.dataset.ffMenuFold='1';
  const btn=document.createElement('button');btn.type='button';btn.className='ff-menu-toggle';
  const title=document.createElement('span');title.textContent=label;
  const arrow=document.createElement('span');arrow.className='ff-menu-arrow';arrow.textContent='⌄';arrow.setAttribute('aria-hidden','true');
  btn.append(title,arrow);
  el.prepend(btn);el.classList.add('ff-menu-fold','ff-menu-closed');
  const set=open=>{
   el.classList.toggle('ff-menu-closed',!open);
   btn.setAttribute('aria-expanded',String(open));
   btn.setAttribute('aria-label',label+(open?' — طي القائمة':' — فتح القائمة'));
  };
  btn.addEventListener('click',()=>set(btn.getAttribute('aria-expanded')!=='true'));
  const close=document.createElement('button');close.type='button';close.className='ff-menu-inner-close';close.textContent='✕ إغلاق القائمة';
  close.addEventListener('click',()=>{set(false);btn.focus({preventScroll:true})});
  el.append(close);set(false);
 }
 function scan(){
  for(const rootSelector of containers){
   const root=document.querySelector(rootSelector);if(!root)continue;
   // Keep main workspace, login, individual order cards and popups functional.
   for(const el of root.querySelectorAll('.card')){
    if(el===root||el.closest('dialog')||el.classList.contains('ff-burger-card'))continue;
    if(el.closest('.ff-menu-fold')&&el.parentElement?.closest('.ff-menu-fold'))continue;
    fold(el);
   }
  }
  document.querySelectorAll('details:not(.ff-menu-details)').forEach(el=>{
   if(el.closest('dialog,#loginOverlay')||!el.querySelector(':scope > summary'))return;
   el.classList.add('ff-menu-details');
  });
 }
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',scan,{once:true});else scan();
 // Other modules insert menus after login or when opening role-specific screens.
 let queued=false;
 const observer=new MutationObserver(()=>{if(queued)return;queued=true;requestAnimationFrame(()=>{queued=false;scan()})});
 observer.observe(document.body,{childList:true,subtree:true});
})();