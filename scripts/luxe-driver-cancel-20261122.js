/* Per-driver cancellation alert; only the driver can skip their own notification. */
'use strict';
(()=>{
 let busy=false,lastFetch=0,cached=[],generation=0;
 const skippedHere=new Set();
 const allowed=()=>typeof data!=='undefined'&&data?.role==='driver'&&typeof user!=='undefined'&&!!user?.id;
 const host=()=>document.getElementById('driverTasks');
 const clean=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const sum=x=>Number(x||0).toLocaleString('ar-YE');
 const style=document.createElement('style');
 style.id='ff-luxe-driver-cancel-styles-20261122';
 style.textContent=[
 '#driverTasks>.ff-luxe-cancelled{border:4px solid #b91c1c!important;border-radius:20px!important;padding:clamp(16px,2.7vw,28px)!important;margin:0 0 20px!important;background:var(--ffb-surface,#fff)!important;box-shadow:0 0 0 3px #f0445544,0 7px 24px #b91c1c2b!important;opacity:1!important;overflow-wrap:anywhere}',
 '#driverTasks .ff-luxe-cancel-banner{background:#ffe1e4;border:2px solid #d31329;border-radius:12px;padding:12px;color:#9a0010;font-size:clamp(19px,3vw,25px);font-weight:950;line-height:1.5}',
 '#driverTasks .ff-luxe-cancel-meta{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin:13px 0}',
 '#driverTasks .ff-luxe-cancel-meta>div{background:var(--ffb-soft,#f7f7f7);padding:11px;border-radius:10px;overflow-wrap:anywhere}',
 '#driverTasks .ff-luxe-cancel-detail{line-height:1.9}',
 '#driverTasks .ff-luxe-cancel-note{background:#fff0f2;color:#9a0010;border-inline-start:5px solid #d31329;border-radius:10px;padding:12px;margin:12px 0;line-height:1.85;overflow-wrap:anywhere}',
 '#driverTasks .ff-luxe-cancelled button.primary{background:#b9081d!important;color:#fff!important;min-height:52px;font-size:16px}',
 '@media(max-width:480px){#driverTasks .ff-luxe-cancel-meta{grid-template-columns:1fr}}'
 ].join('\n');
 document.head.append(style);
 function renderCancelled(){
  const parent=host();if(!parent)return;
  parent.querySelectorAll('[data-ff-luxe-driver-cancel]').forEach(x=>x.remove());
  if(!allowed())return;
  const pending=cached.filter(o=>o&&!o.skipped&&!skippedHere.has(String(o.order_id)));
  if(pending.length)parent.querySelectorAll(':scope>.empty').forEach(x=>x.remove());
  for(let n=pending.length-1;n>=0;n--){
   const o=pending[n],el=document.createElement('article');
   el.className='item ff-luxe-cancelled';el.dataset.ffLuxeDriverCancel=String(o.order_id);
   el.setAttribute('role','group');el.setAttribute('aria-label','طلب ملغي رقم '+String(o.number||''));
   const items=(Array.isArray(o.items)?o.items:[]).map(v=>clean(v.qty||0)+' × '+clean(v.name||'صنف')+
    (v.notes?' <span class="ff75-item-note">ملاحظة: '+clean(v.notes)+'</span>':'')).join('<br>')||'لا توجد أصناف';
   const cancelledAt=o.cancelled_at?new Date(o.cancelled_at).toLocaleString('ar-YE',{timeZone:'Asia/Aden'}):'';
   el.innerHTML=
    '<div class="ff-luxe-cancel-banner">🚫 تنبيه إلغاء الطلب #'+clean(o.number||'—')+'</div>'+
    '<div class="ff-luxe-cancel-meta">'+
    '<div><b>🛵 الموصل:</b> '+clean(o.driver_name||'لم يُحدد')+'</div>'+
    '<div><b>👤 العميل:</b> '+clean(o.customer_name||'عميل')+'</div>'+
    '<div><b>📍 المنطقة:</b> '+clean(o.area||'—')+'</div>'+
    '<div><b>📞 الهاتف:</b> '+clean(o.phone||'—')+'</div></div>'+
    (cancelledAt?'<p class="muted">🕒 وقت الإلغاء: '+clean(cancelledAt)+'</p>':'')+
    '<b>تفاصيل الأصناف:</b><div class="note ff-luxe-cancel-detail">'+items+'</div>'+
    (o.notes?'<p class="ff-luxe-cancel-detail">📝 '+clean(o.notes)+'</p>':'')+
    '<p>الإجمالي: <b>'+sum(o.total)+' ريال</b> · التوصيل: '+sum(o.delivery_fee)+' ريال</p>'+
    (o.invoice_ref?'<p>🧾 فاتورة MicroPOS: <b>'+clean(o.invoice_ref)+'</b></p>':'')+
    '<div class="ff-luxe-cancel-note"><b>سبب الإلغاء:</b> '+clean(o.reason||'لم يُذكر سبب')+
    '<div>⚠️ الطلب ملغي؛ لا تستلمه ولا توصلّه. «تخطي» يخفي الإشعار من حسابك فقط.</div></div>'+
    '<div class="actions"><button type="button" class="primary" data-ff-luxe-driver-skip>✅ تخطي</button></div>';
   const button=el.querySelector('[data-ff-luxe-driver-skip]');
   button.onclick=async()=>{
    if(!allowed())return;
    button.disabled=true;button.textContent='جارٍ إخفاء التنبيه...';
    try{
     const result=await rpc('ff_luxe_skip_driver_cancel',{p_order:o.order_id});
     if(result?.skipped!==true)throw Error('لم يؤكد الخادم تخطي الإشعار');
     skippedHere.add(String(o.order_id));
     cached=cached.filter(x=>String(x.order_id)!==String(o.order_id));
     renderCancelled();
     if(typeof window.ffLuxeRefreshForegroundRinging==='function')window.ffLuxeRefreshForegroundRinging();
     toast('✅ تم تخطي إشعار الطلب الملغي #'+String(o.number||''));
     void refreshCancelled(true);
    }catch(e){
     toast('تعذر تخطي إشعار الإلغاء: '+(e.message||e));
     button.disabled=false;button.textContent='✅ تخطي';
    }
   };
   parent.prepend(el);
  }
  if(typeof window.ffLuxeRefreshForegroundRinging==='function')window.ffLuxeRefreshForegroundRinging();
 }
 async function refreshCancelled(force=false){
  if(!allowed()||busy||(!force&&Date.now()-lastFetch<9000))return;
  busy=true;lastFetch=Date.now();const id=++generation,viewer=String(user.id);
  try{
   const result=await rpc('ff_luxe_driver_cancel_alerts');
   if(id!==generation||!allowed()||viewer!==String(user?.id||''))return;
   cached=(Array.isArray(result)?result:[]).filter(o=>!o.skipped&&!skippedHere.has(String(o.order_id)));
   renderCancelled();
  }catch(e){console.warn('تعذر تحميل إشعارات إلغاء الموصل',e?.message||e)}
  finally{busy=false}
 }
 const originalDrawDriver=drawDriver;
 drawDriver=function(){originalDrawDriver();renderCancelled();void refreshCancelled()};
 document.addEventListener('visibilitychange',()=>{if(!document.hidden)void refreshCancelled(true)});
 window.addEventListener('focus',()=>void refreshCancelled(true));
 setInterval(()=>{if(!document.hidden)void refreshCancelled()},10000);
 const originalReset=resetUI;
 resetUI=function(){generation++;cached=[];lastFetch=0;skippedHere.clear();originalReset()};
})();
