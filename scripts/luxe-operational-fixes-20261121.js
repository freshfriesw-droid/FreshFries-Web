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
 '#cashierOrders>.item{border:4px solid #ba1423!important;margin:0 0 20px!important;border-radius:16px!important;box-shadow:0 5px 18px #34000024!important}',
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

const center=byId('ff62DataCenter'),box=byId('ffLuxeResetOptions');
if(center&&box){
 const run=box.querySelector('[data-reset-run]');
 const choices=box.querySelector('[data-reset-choices]');
 const status=box.querySelector('[data-status]');
 const confirmBox=box.querySelector('[data-confirm]');
 const selectAll=box.querySelector('[data-select-all]');
 if(selectAll)selectAll.textContent='🔴 التصفير الشامل لجميع بيانات التشغيل (مع حفظ حسابات الموظفين والإعدادات)';
 const previewButton=document.createElement('button');previewButton.type='button';
 previewButton.className='primary';previewButton.textContent='🔍 معاينة عدد السجلات التي ستُصفّر';
 const report=document.createElement('div');report.className='ff-luxe-preview-report';report.setAttribute('role','status');
 report.textContent='اختر فئة واحدة أو التصفير الشامل ثم اضغط المعاينة. جميع الأرقام لكل الفروع.';
 const backupLabel=document.createElement('label');backupLabel.className='ff-luxe-backup-check';
 const backupCheck=document.createElement('input');backupCheck.type='checkbox';
 const backupText=document.createElement('span');backupText.textContent='أؤكد أن لدي نسخة احتياطية قابلة للاستعادة وأنني راجعتها';
 backupLabel.append(backupCheck,backupText);
 choices.after(previewButton,report,backupLabel);
 let last=null;
 const getScopes=()=>Array.from(choices.querySelectorAll('input:checked')).map(el=>el.value).sort();
 const scopeKey=()=>getScopes().join('|');
 function invalidate(){last=null;report.textContent='تم تغيير الاختيار. اضغط معاينة قبل تنفيذ الحذف.'}
 choices.addEventListener('change',invalidate);
 selectAll?.addEventListener('click',invalidate);
 box.querySelector('[data-clear]')?.addEventListener('click',invalidate);
 const descriptions=[
  ['orders','الطلبات', ['orders','order_items','order_dispatches','order_additions','audit_links']],
  ['customers','العملاء', ['customers','customer_notes']],
  ['ratings','التقييمات', ['ratings']],
  ['grievances','تظلمات الموصلين', ['grievances']],
  ['messages','الرسائل والإشعارات', ['messages']],
  ['diagnostics','التشخيص', ['diagnostics']],
  ['tests','نتائج الاختبارات', ['tests']],
  ['applications','طلبات الانضمام', ['applications','application_limits']]
 ];
 function renderSummary(payload,scopes,prefix){
  const counts=payload?.scope_counts||{};
  report.replaceChildren();
  const heading=document.createElement('strong');heading.textContent=prefix+' — جميع الفروع';report.append(heading);
  const ul=document.createElement('ul');
  for(const [key,label,parts] of descriptions){
   if(!scopes.includes(key))continue;
   const li=document.createElement('li');
   li.textContent=label+': '+parts.map(p=>p+' = '+Number(counts[p]||0).toLocaleString('ar-YE')).join('، ');
   ul.append(li);
  }
  report.append(ul);
  const warning=document.createElement('p');
  warning.style.color='#ad111e';
  warning.style.fontWeight='900';
  warning.textContent='⚠️ التصفير يشمل كل الفروع. لن تُحذف حسابات الدخول أو الفروع أو صلاحيات المدير أو سجل التدقيق الأساسي. تُحفظ سجلات تدقيق الطلبات في أرشيف محمي.';
  report.append(warning);
 }
 previewButton.onclick=async()=>{
  if(data?.role!=='manager'){status.textContent='هذه الأداة للمدير العام فقط';return}
  const scopes=getScopes();if(!scopes.length){status.textContent='حدد بيانات تريد معاينتها';return}
  last=null;previewButton.disabled=true;status.textContent='قراءة عدد السجلات من قاعدة البيانات...';
  try{
   const result=await rpc('ff_luxe_reset_preview',{p_scopes:scopes});
   if(!center.open||data?.role!=='manager')return;
   renderSummary(result,scopes,'معاينة قبل التصفير');
   last={key:scopeKey(),at:Date.now(),counts:result.scope_counts};
   status.textContent='المعاينة جاهزة. راجع الأعداد واحتفظ بنسخة احتياطية قبل التنفيذ.';
  }catch(err){status.textContent='تعذرت المعاينة: '+(err.message||err)}
  finally{previewButton.disabled=false}
 };
 run.onclick=async()=>{
  if(data?.role!=='manager'){status.textContent='التصفير حصري للمدير العام';return}
  const scopes=getScopes();if(!scopes.length){status.textContent='حدد فئة واحدة على الأقل';return}
  if(!last||last.key!==scopeKey()||Date.now()-last.at>60000){status.textContent='يجب معاينة الأعداد من جديد قبل الحذف';return}
  if(!backupCheck.checked){status.textContent='يجب التأكد من توفر نسخة احتياطية قابلة للاستعادة أولاً';return}
  if(confirmBox.value.trim()!=='تصفير فريش فرايز'){status.textContent='اكتب عبارة التأكيد المطلوبة كاملة';return}
  if(!confirm('🚫 سيتم حذف البيانات المحددة في كل الفروع. هل راجعت المعاينة والنسخة الاحتياطية وتريد المتابعة؟'))return;
  if(!confirm('التأكيد النهائي: هذا الإجراء لا يمكن التراجع عنه دون استعادة النسخة الاحتياطية. تنفيذ؟'))return;
  run.disabled=true;status.textContent='جار تنفيذ التصفير والتحقق من النتيجة...';
  try{
   const result=await rpc('ff_luxe_reset_safe',{p_scopes:scopes,p_confirmation:confirmBox.value.trim()});
   if(result?.success!==true)throw Error('الخادم لم يؤكد التصفير');
   renderSummary(result.after,scopes,'بعد التصفير');
   status.textContent='✅ تم التصفير المصرّح به. رقم عملية التتبع: '+String(result.batch_id||'')+'، سجلات التدقيق المؤرشفة: '+Number(result.audit_rows_archived||0);
   last=null;backupCheck.checked=false;confirmBox.value='';choices.querySelectorAll('input').forEach(x=>{x.checked=false});
   void reload(true);
  }catch(err){status.textContent='لم يتم تأكيد التصفير: '+(err.message||err)}
  finally{run.disabled=false}
 };
 const hint=center.querySelector('.muted');
 if(hint)hint.textContent='مراجعة وعدادات آمنة ثم تصفير انتقائي أو شامل لبيانات التشغيل فقط، مع حماية سجلات التدقيق وحسابات الإدارة. لا تنفذ أي عملية تلقائيًا.';
 center.addEventListener('close',()=>{last=null;backupCheck.checked=false;confirmBox.value=''});
}

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