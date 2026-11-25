/* Fresh Fries LUXE 2026-11-21: protected reset preview, menu visibility, manager assembly preview. */
(function(){
'use strict';
const byId=id=>document.getElementById(id);
const style=document.createElement('style');
style.id='ff-luxe-ops-fixes-style';
style.textContent=[
 '#ffx-menu{display:inline-flex!important;align-items:center!important;justify-content:center!important;min-width:47px!important;min-height:47px!important;background:#b91825!important;color:white!important;border:2px solid #fff4!important}',
 '#ffx-drawer-close{display:grid!important;place-items:center!important;min-width:44px!important;min-height:44px!important}',
 'body.ffx-menu-open .ffx-screen-dimmer{display:block!important;position:fixed!important;inset:0!important;z-index:880!important}',
 '#ffLuxeResetOptions .ff-luxe-preview-report{border:2px solid #b51725;border-radius:12px;padding:12px;margin:12px 0;background:var(--ffb-surface,#fff);line-height:1.8}',
 '#ffLuxeResetOptions .ff-luxe-preview-report ul{margin:6px 0;padding-inline-start:25px}',
 '#ffLuxeResetOptions .ff-luxe-backup-check{display:flex;align-items:center;gap:10px;margin:10px 0;font-weight:800}',
 '#ffLuxeResetOptions [data-reset-run]:disabled{opacity:.45}',
 '#cashierOrders>.item:not(.ff-luxe-cancelled){border:4px solid #ba1423!important;margin:0 0 20px!important;border-radius:16px!important;box-shadow:0 5px 18px #34000024!important}',
 '#cashierOrders .ff-cashier-status{font-size:clamp(19px,3.8vw,25px)!important;font-weight:950!important;color:#a40000!important;border:2px solid #bb1721!important;padding:8px 13px!important}',
 '#ffLuxeCancelledAlerts{margin:12px 0;display:grid;gap:12px}',
 '#ffLuxeCancelledAlerts .ff-luxe-cancelled{padding:18px!important;border:5px solid #b90000!important}',
 '#ffLuxeAssemblyPreview{max-width:min(94vw,850px);max-height:88dvh;overflow:auto;border:3px solid #a81520;border-radius:17px;padding:18px;background:var(--ffb-surface,#fff);color:var(--ffb-ink,#222)}',
 '#ffLuxeAssemblyPreview::backdrop{background:#000a}',
 '#ffLuxeAssemblyPreview .ff-luxe-preview-card{border:2px solid #c1c3c7;border-radius:12px;padding:12px;margin:10px 0}',
 '#ffLuxeAssemblyPreview [data-exit]{font-size:20px;font-weight:950;background:#be1626;color:white;width:100%;padding:17px;position:sticky;top:0;z-index:1}',
 'body.ff-luxe-preview #ffLuxeCancelledAlerts:has(.ff-luxe-cancelled){display:grid!important}'
].join('\n');
document.head.appendChild(style);

// A12 uses the dedicated test-only recovery controller; no global reset RPC remains.


// Separate optional assembly preview, with a prominent exit button. No driver impersonation.
const views=byId('ffLuxeManagerViews');
if(views){
 const actions=views.querySelector('.actions');
 if(actions){
  const btn=document.createElement('button');btn.type='button';
  btn.textContent='🏭 نقطة التجميع (معاينة)';
  actions.append(btn);
  const dialog=document.createElement('dialog');dialog.id='ffLuxeAssemblyPreview';
  const exit=document.createElement('button');exit.type='button';exit.dataset.exit='';
  exit.textContent='⬅ الخروج من الواجهة والعودة للإدارة';
  const title=document.createElement('h2');title.textContent='🏭 نقطة التجميع — عرض المدير';
  const branch=document.createElement('select');branch.setAttribute('aria-label','اختر الفرع');
  const list=document.createElement('div');
  dialog.append(exit,title,branch,list);document.body.append(dialog);
  exit.onclick=()=>dialog.close();
  dialog.addEventListener('cancel',()=>dialog.close());
  function render(){
   list.replaceChildren();
   const orders=(data?.orders||[]).filter(o=>o.branch_id===branch.value&&o.status!=='cancelled'&&o.status!=='delivered');
   for(const o of orders){
    const card=document.createElement('article');card.className='ff-luxe-preview-card';
    const b=document.createElement('b');b.textContent='طلب #'+o.number+' — '+String(o.customer_name||'عميل');
    const state=document.createElement('p');state.textContent='الحالة: '+String(o.cashier_stage||'بانتظار الكاشير')+' | الموصل: '+String(o.driver_name||'—');
    card.append(b,state);
    const nextStage=o.cashier_stage==='printed'?'preparing':o.cashier_stage==='preparing'?'ready':null;
    if(nextStage){
      const action=document.createElement('button');action.type='button';action.className='primary';
      action.textContent=nextStage==='preparing'?'👑 بدء التحضير بإذن المدير':'👑 اعتماد جاهزية الطلب';
      action.onclick=async()=>{
        if(data?.role!=='manager')return;
        if(!confirm('اعتماد مرحلة '+action.textContent+' للطلب #'+o.number+'؟'))return;
        action.disabled=true;
        try{
          await rpc('ff38_cashier_set_stage',{p_order:o.id,p_stage:nextStage});
          toast('تم تحديث حالة التجميع بصلاحية المدير');
          await reload(true);render();
        }catch(err){toast('تعذر تعديل المرحلة: '+(err.message||err))}
        finally{action.disabled=false}
      };
      card.append(action);
    }
    if(o.cashier_stage==='ready'){
      const info=document.createElement('p');info.className='muted';
      info.textContent='تأكيد التسليم النهائي للموصل يتم من واجهة الكاشير حتى لا تُتخطى خطوة التسليم الفعلي.';
      card.append(info);
    }
    list.append(card);
   }
   if(!orders.length)list.textContent='لا توجد طلبات حالية لهذا الفرع.';
  }
  branch.onchange=render;
  btn.onclick=()=>{
   if(data?.role!=='manager')return;
   branch.replaceChildren();
   for(const br of data.branches||[]){const opt=document.createElement('option');opt.value=br.id;opt.textContent=br.name;branch.append(opt)}
   render();dialog.showModal();
  };
  window.addEventListener('ff-assembly-snapshot-success',()=>{if(dialog.open)render()});
 }
}
})();