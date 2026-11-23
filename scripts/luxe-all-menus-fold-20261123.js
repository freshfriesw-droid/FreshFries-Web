/* Fresh Fries LUXE — unified collapsible menu controls, preserving role-gated launchers. */
(()=>{'use strict';
 const css=document.createElement('style');css.id='ff-all-menu-fold-style';
 css.textContent=[
 '.ff-menu-fold{position:relative;overflow:visible!important}',
 '.ff-menu-fold.ff-menu-closed>:not(.ff-menu-toggle){display:none!important}',
 '.ff-menu-toggle{display:flex!important;width:100%;justify-content:space-between;align-items:center;gap:12px;min-height:49px;margin:0 0 10px;padding:12px 15px;border:2px solid var(--ffb-red,#d51e2c)!important;border-radius:12px;background:var(--ffb-soft2,#242124)!important;color:var(--ffb-ink,#fff)!important;text-align:right;font-size:clamp(14px,2.5vw,17px);font-weight:900;cursor:pointer}',
 '.ff-menu-toggle[aria-expanded=true]{background:var(--ffb-red,#d51e2c)!important;color:#fff!important}',
 '.ff-menu-arrow{font-size:18px;flex:none;transition:transform .2s}',
 '.ff-menu-toggle[aria-expanded=true] .ff-menu-arrow{transform:rotate(180deg)}',
 '.ff-menu-inner-close,.ff-menu-details-close{display:block;margin:14px auto 3px 0!important;border:1px solid var(--ffb-red,#d51e2c)!important;border-radius:9px;padding:9px 15px;background:var(--ffb-surface,#fff)!important;color:var(--ffb-ink,#252525)!important;font-weight:800}',
 'details.ff-menu-details>summary{cursor:pointer;border:1px solid var(--ffb-red,#d51e2c);border-radius:9px;padding:10px 13px;font-weight:800}',
 'details.ff-menu-details[open]>summary{background:var(--ffb-red,#d51e2c);color:#fff}',
 '.ff-menu-standalone-close{display:block;margin:16px auto 2px 0;padding:10px 15px;border:1px solid var(--ffb-red,#d51e2c);background:var(--ffb-surface,#fff);color:var(--ffb-ink,#222);border-radius:10px}',
 '@media(max-width:600px){.ff-menu-toggle{min-height:48px;padding:10px 12px}.ff-menu-inner-close,.ff-menu-details-close{width:100%;min-height:44px}}'
 ].join('\n');document.head.append(css);
 const roots=['#staffView','#cashierView','#driverView','#serviceOnly','#ffV12AssemblyWorkspace','#ffBurgerKitchenWorkspace'];
 const reserved=new Set(['ffBurgerCashierPanel','ffV12AssemblyWorkspace','ffBurgerKitchenWorkspace']);
 const labelFor=el=>{
  const h=el.querySelector(':scope > h2,:scope > h3,:scope > .sectionbar h2,:scope > .sectionbar h3,:scope > .ff-burger-head h3,:scope > .ff41-header h2');
  return (h?.textContent||el.getAttribute('aria-label')||'').trim().replace(/\s+/g,' ').slice(0,110);
 };
 function fold(el){
  if(!el||el.dataset.ffMenuFold||reserved.has(el.id)||el.closest('dialog,[role="dialog"],#loginOverlay'))return;
  if(el.classList.contains('ffl-folded-card'))return;
  if(el.classList.contains('hidden')&&el.parentElement?.tagName==='MAIN')return;
  const label=labelFor(el);if(!label)return;
  el.dataset.ffMenuFold='1';
  const button=document.createElement('button');button.type='button';button.className='ff-menu-toggle';
  const title=document.createElement('span');title.textContent=label;
  const arrow=document.createElement('span');arrow.className='ff-menu-arrow';arrow.textContent='⌄';arrow.setAttribute('aria-hidden','true');button.append(title,arrow);
  const setState=open=>{
   el.classList.toggle('ff-menu-closed',!open);button.setAttribute('aria-expanded',String(open));
   button.setAttribute('aria-label',label+(open?' — طي القائمة':' — فتح القائمة'));
  };
  button.addEventListener('click',()=>setState(button.getAttribute('aria-expanded')!=='true'));
  el.prepend(button);el.classList.add('ff-menu-fold');
  const close=document.createElement('button');close.type='button';close.className='ff-menu-inner-close';close.textContent='✕ إغلاق القائمة';
  close.onclick=()=>{setState(false);button.focus({preventScroll:true})};el.append(close);
  setState(false);
 }
 function existingFoldClose(el){
  if(el.dataset.ffExistingFoldClose)return;
  const toggle=el.querySelector(':scope > .ffl-fold-toggle');if(!toggle)return;
  el.dataset.ffExistingFoldClose='1';
  const close=document.createElement('button');close.type='button';close.className='ff-menu-inner-close';close.textContent='✕ إغلاق القائمة';
  close.onclick=()=>{if(toggle.getAttribute('aria-expanded')==='true')toggle.click();toggle.focus({preventScroll:true})};
  el.append(close);
 }
 function addDetailsClose(el){
  if(el.dataset.ffMenuDetails||el.closest('dialog,#loginOverlay'))return;
  const summary=el.querySelector(':scope > summary');if(!summary)return;
  el.dataset.ffMenuDetails='1';el.classList.add('ff-menu-details');
  if(!summary.hasAttribute('role'))summary.setAttribute('role','button');
  const close=document.createElement('button');close.type='button';close.className='ff-menu-details-close';close.textContent='✕ إغلاق القائمة';
  close.onclick=()=>{el.open=false;summary.focus({preventScroll:true})};el.append(close);
 }
 function addStandaloneClose(el){
  if(el.dataset.ffMenuStandalone||el.closest('dialog,#loginOverlay'))return;
  if(!el.classList.contains('card')||!el.id||!el.parentElement||el.parentElement.tagName!=='MAIN')return;
  // These panels already have guarded navigation launchers. Do not create unauthorized open controls.
  el.dataset.ffMenuStandalone='1';
  if(el.querySelector('[id$="Close"],[data-close],.ff-menu-standalone-close'))return;
  const close=document.createElement('button');close.type='button';close.className='ff-menu-standalone-close';close.textContent='✕ إغلاق '+(labelFor(el)||'القائمة');
  close.onclick=()=>el.classList.add('hidden');el.append(close);
 }
 function scan(){
  for(const selector of roots){
   const root=document.querySelector(selector);if(!root)continue;
   for(const el of root.querySelectorAll('.card')){
    if(el===root||el.classList.contains('ff-burger-card'))continue;
    fold(el);existingFoldClose(el);
   }
  }
  document.querySelectorAll('.ffl-folded-card').forEach(existingFoldClose);
  document.querySelectorAll('details').forEach(addDetailsClose);
  document.querySelectorAll('main > section.card').forEach(addStandaloneClose);
 }
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',scan,{once:true});else scan();
 let queued=false;
 const observer=new MutationObserver(()=>{if(queued)return;queued=true;requestAnimationFrame(()=>{queued=false;scan()})});
 observer.observe(document.body,{childList:true,subtree:true});
})();
