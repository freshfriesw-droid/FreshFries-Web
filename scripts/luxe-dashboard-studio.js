/* Centrally published dashboard layouts. Preview uses synthetic cards only. */
(()=>{
 'use strict';
 const packs=["Fresh Classic", "Midnight Command", "Executive Carbon", "White Studio", "Graphite Pro", "Crimson Edge", "Soft Ivory", "Contrast Plus", "Touch Flow", "Compact Operations", "Control Grid", "Studio Cards", "Mission Control", "Kiosk Focus", "Minimal Black & White", "LUXE Editorial"];
 const roles={all:'كل الأدوار',manager:'المدير العام',supervisor:'المشرف',customer_service:'خدمة العملاء',cashier:'الكاشير',driver:'الموصل',assembly:'نقطة التجميع',burger_kitchen:'مطبخ البرجر'};
 const dlg=document.createElement('dialog');
 dlg.id='ffStudio';dlg.dir='rtl';dlg.setAttribute('aria-labelledby','ffStudioTitle');
 dlg.innerHTML=`<form><div class="sectionbar"><h2 id="ffStudioTitle">شاشة تحكم المدير العام</h2><button type="button" data-close>إغلاق</button></div>
 <h3>تصميم لوحة التشغيل</h3><div class="ff-studio-fields">
 <label>الدور<select name="role"></select></label><label>الفرع<select name="branch"></select></label>
 <label>الجهاز<select name="device"><option value="all">كل الأجهزة</option><option value="mobile">الجوال</option><option value="desktop">الكمبيوتر</option></select></label>
 <label>حزمة التصميم<select name="pack"></select></label><label>شريط الجوال<select name="bar"><option value="labels">أيقونات وتسميات</option><option value="icons">أيقونات فقط</option><option value="wide">أزرار عريضة</option><option value="floating">شريط عائم</option><option value="compact">مختصر مع المزيد</option></select></label>
 <label>وصف الرئيسية<input name="caption" maxlength="180" placeholder="استخدام الوصف الأصلي"></label></div>
 <h3>معاينة بتفاصيل تجريبية</h3><label>عرض المعاينة بالبكسل<select name="viewport"></select></label><div class="ff-preview-scroll" tabindex="0" aria-label="معاينة قابلة للتمرير"><div class="ff-studio-preview"><div class="ff-design-layout"><h3 class="ffx-section-head">لوحة التحكم</h3><div data-slot="hero">الرئيسية</div><div data-slot="stats">مؤشرات · ٤ طلبات</div><div data-slot="work">الطلبات والإجراءات السريعة</div><div data-slot="late">المتابعة · طلب متأخر</div></div><div class="ff-studio-bar" aria-label="معاينة شريط الهاتف — غير تفاعلية"></div></div></div><section class="ff-studio-impact" aria-label="تقرير أثر المسودة"><h3>تقرير التأثير قبل النشر</h3><p data-impact-scope></p><p data-impact-contrast></p><p data-impact-nav></p><section aria-label="مصدر القيمة الفعالة"><h4>مصدر التصميم المنشور الفعّال</h4><p data-source-status aria-live="polite"></p><dl data-source-details hidden><dt>الحزمة</dt><dd data-source-pack></dd><dt>شريط الهاتف</dt><dd data-source-bar></dd><dt>وصف الرئيسية</dt><dd data-source-caption></dd></dl><p>المصدر للنطاق المحدد من الإصدارات المنشورة فقط؛ لا يشمل تجارب حسابات معينة.</p></section><p>معاينة اصطناعية لا تنفذ طلبات أو تغيّر صلاحيات. فحص التباين هنا خاص بخلفية الحزمة ونصها؛ لا يغني عن اختبار الشاشات الفعلية.</p></section>
 <div class="ff-studio-fields"><label>اسم المسودة<input name="draftName" maxlength="80" required></label>
 <label>وصف التعديل<textarea name="description" maxlength="400"></textarea></label></div>
 <div class="actions"><button type="submit" class="primary">حفظ مسودة جديدة</button></div>
 <label>سجل الإصدارات<select name="version"></select></label><div class="actions"><button type="button" data-load>معاينة الإصدار</button><button type="button" data-publish>نشر الآن</button><button type="button" data-restore>استعادة كمسودة</button><button type="button" data-rollback>استعادة الإصدار السابق الآن</button></div><details><summary>تجربة محدودة لمسودة</summary>
 <button type="button" data-accounts>عرض الحسابات المؤهلة</button>
 <label>الحسابات المستهدفة<select name="accounts" multiple></select></label>
 <label>مدة التجربة<select name="hours"><option value="1">ساعة</option><option value="8">٨ ساعات</option><option value="24">٢٤ ساعة</option></select></label>
 <button type="button" data-trial>بدء تجربة للحسابات المحددة</button>
 <button type="button" data-stop>إنهاء تجربة هذه المسودة</button></details>
 <details><summary>مقارنة إصدارين</summary>
 <label>الإصدار المرجعي<select name="baseline"></select></label>
 <table><thead><tr><th>الخاصية</th><th>المرجعي</th><th>المحدد</th></tr></thead><tbody data-diff></tbody></table></details>
 <p role="status" aria-live="polite"></p></form>`;
 document.body.append(dlg);
 const form=dlg.querySelector('form'),fields=form.elements,status=dlg.querySelector('[role=status]'),preview=dlg.querySelector('.ff-design-layout');
 const field=name=>fields.namedItem(name);
 const dashboard=document.getElementById('ffx-dashboard'),caption=document.getElementById('ffx-hero-sub'),original=caption.textContent;
 const actor=()=>typeof user!=='undefined'&&user?.id&&typeof data!=='undefined'&&data?.role?user.id:'';
 const manager=()=>actor()&&data.role==='manager';
 let records=[],context='',last=0,serial=0,session=0,busy=false,sourceSerial=0,sourceTimer,sourceKey='';
 const revisionLabel=document.createElement('small');
 caption.after(revisionLabel);
 function apply(version){
  revisionLabel.hidden=!version;
  revisionLabel.textContent=version?'إصدار التصميم '+version.id:'';
  dashboard.classList.toggle('ff-design-layout',!!version);
  if(version){dashboard.dataset.pack=version.pack;document.body.dataset.ffBar=version.bar}
  else{delete dashboard.dataset.pack;delete document.body.dataset.ffBar}
  caption.textContent=version?.layout_text||original;
 }
 function scope(){const branches=data?.branches||[];return document.getElementById('ffx-branch')?.value||(branches.length===1?branches[0].id:null)}
 async function sync(force=false){
  const who=actor();
  if(!who){if(context)reset();return}
  const branch=scope(),role=data.role,device=matchMedia('(max-width:850px)').matches?'mobile':'desktop';
  const key=[who,role,branch,device].join('|');
  if(key!==context){apply(null);context=key;last=0}
  if(!force&&Date.now()-last<30000)return;
  last=Date.now();const request=++serial;
  try{const rows=await rpc('ff_ui_effective',{p_branch:branch,p_device:device});
   if(request===serial&&who===actor()&&data?.role===role&&branch===scope()&&device===(matchMedia('(max-width:850px)').matches?'mobile':'desktop'))apply(rows?.[0])
  }catch{ /* Keep last confirmed version for this context during network loss. */ }
 }
 function reset(){clearSource();serial++;session++;context='';last=0;busy=false;records=[];field('version').replaceChildren();field('baseline').replaceChildren();field('accounts').replaceChildren();compare();form.reset();status.textContent='';if(dlg.open)dlg.close();apply(null)}
 const sampleNav={all:['الرئيسية','الطلبات','المزيد'],manager:['الرئيسية','طلب جديد','الطلبات','تحكم المدير','المزيد'],supervisor:['الرئيسية','الطلبات','المزيد'],customer_service:['الرئيسية','طلب جديد','الطلبات','المزيد'],cashier:['الرئيسية','شاشة الكاشير','المزيد'],driver:['الرئيسية','مهامي','المزيد'],assembly:['الرئيسية','المزيد'],burger_kitchen:['الرئيسية','المزيد']};
 function luminance(hex){
  const parts=/^#([0-9a-f]{6})$/i.exec(hex.trim());if(!parts)return null;
  const v=parts[1].match(/../g).map(x=>parseInt(x,16)/255).map(x=>x<=0.04045?x/12.92:((x+0.055)/1.055)**2.4);
  return v[0]*0.2126+v[1]*0.7152+v[2]*0.0722;
 }
 function sourceEl(name){return dlg.querySelector('[data-source-'+name+']')}
 function clearSource(){
  clearTimeout(sourceTimer);sourceSerial++;sourceKey='';
  sourceEl('status').textContent='';sourceEl('details').hidden=true;
  for(const name of ['pack','bar','caption'])sourceEl(name).textContent='';
 }
 function sourceRefresh(force=false){
  if(!dlg.open||!manager())return;
  const who=actor(),token=session,role=field('role').value,b=field('branch').value||null;
  const d=field('device').value==='all'?(Number(field('viewport').value)<=850?'mobile':'desktop'):field('device').value;
  const key=[who,role,b,d].join('|');
  if(!force&&key===sourceKey)return;
  clearSource();sourceKey=key;
  if(role==='all'){sourceEl('status').textContent='اختر دوراً محدداً لمقارنة التصميم المنشور الفعّال؛ خيار كل الأدوار هو نطاق المسودة لا حساب معاينة محدد.';return}
  const request=++sourceSerial;
  sourceEl('status').textContent='جاري التحقق من مصدر التصميم…';
  sourceTimer=setTimeout(async()=>{
   try{
    const rows=await rpc('ff_ui_manager_source',{p_role:role,p_branch:b,p_device:d});
    if(request!==sourceSerial||token!==session||who!==actor()||!manager()||!dlg.open)return;
    const row=rows?.[0],deviceLabel={all:'كل الأجهزة',mobile:'الجوال',desktop:'الكمبيوتر'};
    const branchLabel=id=>data.branches?.find(item=>item.id===id)?.name||(id?'فرع محدد':'دون تخصيص فرع');
    if(!row){sourceEl('status').textContent='التصميم الأساسي للنظام — لا يوجد إصدار منشور مطابق لهذا النطاق ('+roles[role]+' · '+branchLabel(b)+' · '+deviceLabel[d]+').';return}
    sourceEl('status').textContent='الإصدار #'+row.id+' · '+roles[row.role_scope]+' · '+branchLabel(row.branch_id)+' · '+deviceLabel[row.device];
    sourceEl('pack').textContent=row.pack;sourceEl('bar').textContent=Array.from(field('bar').options).find(o=>o.value===row.bar)?.textContent||row.bar;
    sourceEl('caption').textContent=row.layout_text||original;sourceEl('details').hidden=false;
   }catch(e){if(request===sourceSerial&&token===session&&who===actor()&&manager()&&dlg.open){sourceEl('status').textContent='تعذر التحقق من المصدر المنشور. لا تعتبر القيمة المعروضة اعتماداً.';sourceKey=''}}
  },180);
 }
 function redraw(){
  const width=Number(field('viewport').value),role=field('role').value,bar=field('bar').value;
  preview.parentElement.style.width=width+'px';
  preview.dataset.pack=field('pack').value;preview.querySelector('[data-slot=hero]').textContent=field('caption').value||'الرئيسية';
  const nav=dlg.querySelector('.ff-studio-bar');nav.dataset.bar=bar;nav.hidden=width>850;nav.replaceChildren();
  const labels=sampleNav[role]||sampleNav.all;
  for(const [i,label] of labels.entries()){
   const item=document.createElement('span');item.className='ff-studio-bar-item';item.title=label;
   const mark=document.createElement('span');mark.setAttribute('aria-hidden','true');mark.textContent=i===0?'⌂':i===labels.length-1?'☰':'◇';
   const name=document.createElement('span');name.className='ff-studio-bar-label';name.textContent=label;
   item.append(mark,name);nav.append(item);
  }
  const targets=['role','branch','device'].map(name=>field(name).selectedOptions[0]?.textContent||'—');
  dlg.querySelector('[data-impact-scope]').textContent='النطاق: '+targets.join(' · ')+' · الرئيسية فقط · '+width+'px';
  const style=getComputedStyle(preview),bg=luminance(style.getPropertyValue('--pack-bg')),ink=luminance(style.getPropertyValue('--pack-ink'));
  const ratio=bg===null||ink===null?null:(Math.max(bg,ink)+0.05)/(Math.min(bg,ink)+0.05);
  dlg.querySelector('[data-impact-contrast]').textContent=ratio===null?'تباين الحزمة: يحتاج تحقق':'تباين النص والخلفية: '+ratio.toFixed(2)+':1 — '+(ratio>=4.5?'يتوافق مع حد النص العادي 4.5:1':'يحتاج تعديل');
  dlg.querySelector('[data-impact-nav]').textContent=width>850?'شريط الهاتف لا يظهر في هذا العرض.':bar==='compact'?'الشريط المختصر: الرئيسية والمزيد والإجراء النشط؛ الاختصارات الأخرى عبر قائمة المزيد.':bar==='icons'?'الأيقونات فقط؛ أسماء العناصر تبقى لقارئ الشاشة.':'معاينة شكل الشريط؛ لا تخفي الإجراءات.';
  sourceRefresh();
 }

 function selectRecord(row){
  for(const [name,value] of Object.entries({draftName:row.draft_name||'',description:row.draft_description||'',role:row.role_scope,branch:row.branch_id||'',device:row.device,caption:row.layout_text,pack:row.pack,bar:row.bar}))field(name).value=value;
  redraw();
 }
 function compare(){
  const left=records.find(row=>String(row.id)===field('baseline').value);
  const right=records.find(row=>String(row.id)===field('version').value);
  const body=dlg.querySelector('[data-diff]');
  body.replaceChildren();
  if(!left||!right)return;
  const branch=id=>data.branches?.find(item=>item.id===id)?.name||(id?'فرع محدد':'كل الفروع');
  const properties=[
   ['اسم المسودة',row=>row.draft_name||'—'],['وصف التعديل',row=>row.draft_description||'—'],['الدور',row=>roles[row.role_scope]],['الفرع',row=>branch(row.branch_id)],
   ['الجهاز',row=>row.device],['الحزمة',row=>row.pack],['شريط الجوال',row=>row.bar],
   ['وصف الرئيسية',row=>row.layout_text||original]
  ];
  for(const [label,value] of properties){
   if(value(left)===value(right))continue;
   const tr=body.insertRow();
   for(const item of [label,value(left),value(right)])tr.insertCell().textContent=item;
  }
  if(!body.rows.length){
   const cell=body.insertRow().insertCell();
   cell.colSpan=3;cell.textContent='إعدادات الإصدارين متطابقة';
  }
 }
 function buttons(){const row=records.find(r=>String(r.id)===field('version').value);
  for(const b of form.querySelectorAll('button:not([data-close])'))b.disabled=busy;
  dlg.querySelector('[data-publish]').disabled=busy||!row||!!row.published_at;
  dlg.querySelector('[data-restore]').disabled=busy||!row?.published_at;
  dlg.querySelector('[data-rollback]').disabled=busy||!row?.published_at||!row.previous_id||records.some(
   other=>other.published_at&&other.previous_id===row.id
  );
  for(const action of ['accounts','stop','trial'])dlg.querySelector('[data-'+action+']').disabled=busy||!row||!!row.published_at;
  dlg.querySelector('[data-load]').disabled=busy||!row;
 }
 async function history(token,selected){
  const rows=await rpc('ff_ui_manager_history');
  if(token!==session||!manager())return;
  field('accounts').replaceChildren();records=rows||[];field('version').replaceChildren(...records.map(r=>new Option('#'+r.id+' · '+(r.draft_name||'تصميم')+' · '+new Date(r.created_at).toLocaleDateString('ar-YE')+' · '+(r.published_at?'منشور':'مسودة')+' · '+r.pack+' · '+roles[r.role_scope]+' · '+(data.branches?.find(b=>b.id===r.branch_id)?.name||(r.branch_id?'فرع محدد':'كل الفروع'))+' · '+r.device,r.id)));
  if(selected)field('version').value=selected;
  field('baseline').replaceChildren(...Array.from(field('version').options,option=>option.cloneNode(true)));
  const prior=records.find(row=>String(row.id)===field('version').value)?.previous_id;
  if(prior&&records.some(row=>row.id===prior))field('baseline').value=prior;
  compare();
  buttons();
 }
 function valid(token,who){return token===session&&who===actor()&&manager()}
 async function run(action){
  if(!manager()||busy)return;
  const who=actor(),token=session;busy=true;buttons();
  try{await action(token,who)}catch(e){if(valid(token,who))status.textContent=e.message}
  finally{if(valid(token,who)){busy=false;buttons()}}
 }
 function open(){
  if(!manager()||dlg.open)return;session++;form.reset();records=[];field('version').replaceChildren();field('baseline').replaceChildren();field('accounts').replaceChildren();compare();status.textContent='';field('branch').replaceChildren(new Option('كل الفروع',''),...(data.branches||[]).map(b=>new Option(b.name,b.id)));redraw();dlg.showModal();redraw();void run(token=>history(token));
 }
 for(const width of [320,360,390,430,768,1024,1440]){
  field('viewport').add(new Option(String(width),String(width),width===390,width===390));
 }
 for(const [k,label] of Object.entries(roles))field('role').add(new Option(label,k));
 packs.forEach((name,i)=>{const code='D'+String(i+1).padStart(2,'0');field('pack').add(new Option(code+' · '+name,code))});
 form.oninput=redraw;form.addEventListener('change',redraw);field('baseline').onchange=compare;field('version').onchange=()=>{field('accounts').replaceChildren();buttons();compare()};
 form.onsubmit=e=>{e.preventDefault();void run(async(token,who)=>{
  const id=await rpc('ff_ui_named_draft',{p_name:field('draftName').value,p_description:field('description').value,p_role:field('role').value,p_branch:field('branch').value||null,p_device:field('device').value,p_pack:field('pack').value,p_text:field('caption').value,p_bar:field('bar').value});
  if(valid(token,who)){await history(token,id);if(valid(token,who))status.textContent='حُفظت المسودة رقم '+id}
 })};
 const selected=()=>records.find(r=>String(r.id)===field('version').value);
 dlg.querySelector('[data-accounts]').onclick=()=>void run(async(token,who)=>{
  const row=selected();if(!row||row.published_at)return;
  const accounts=await rpc('ff_ui_trial_accounts',{p_id:row.id});
  if(valid(token,who)&&selected()?.id===row.id){
   field('accounts').replaceChildren(...accounts.map(a=>new Option(a.account_name,a.account_id)));
   status.textContent='عدد الحسابات المؤهلة '+accounts.length;
  }
 });
 for(const action of ['trial','stop']){
  dlg.querySelector('[data-'+action+']').onclick=()=>void run(async(token,who)=>{
   const row=selected();if(!row||row.published_at)return;
   const accounts=Array.from(field('accounts').selectedOptions,option=>option.value);
   const hours=action==='stop'?0:Number(field('hours').value);
   if(hours&&!accounts.length){status.textContent='اختر حساباً واحداً على الأقل';return}
   const message=hours?'تطبيق المسودة '+row.id+' على '+accounts.length+' حساب لمدة '+hours+' ساعة؟':'إنهاء التجربة لجميع مستلمي المسودة '+row.id+'؟';
   if(!confirm(message))return;
   const count=await rpc('ff_ui_control_trial',{p_id:row.id,p_accounts:accounts,p_hours:hours});
   if(valid(token,who)){status.textContent=(hours?'بدأت التجربة، عدد الحسابات ':'انتهت التجربة، عدد الحسابات ')+count;void sync(true)}
  });
 }
 dlg.querySelector('[data-load]').onclick=()=>{if(selected())selectRecord(selected())};
 dlg.querySelector('[data-restore]').onclick=()=>void run(async(token,who)=>{
  const row=selected();if(!row?.published_at)return;
  const id=await rpc('ff_ui_save_draft',{p_role:row.role_scope,p_branch:row.branch_id,p_device:row.device,p_pack:row.pack,p_text:row.layout_text,p_bar:row.bar,p_restore:row.id});
  if(valid(token,who)){await history(token,id);if(valid(token,who)){selectRecord(row);status.textContent='حُفظ إصدار الاستعادة كمسودة رقم '+id}}
 });
 dlg.querySelector('[data-rollback]').onclick=()=>void run(async(token,who)=>{
  const row=selected();
  if(!row?.previous_id||!row.published_at)return;
  selectRecord(row);
  const scopeLabel=['role','branch','device'].map(name=>field(name).selectedOptions[0]?.textContent).join(' · ');
  if(!confirm('استعادة التصميم رقم '+row.previous_id+' بدلاً من '+row.id+'؟ '+scopeLabel))return;
  const id=await rpc('ff_ui_rollback',{p_current:row.id});
  if(valid(token,who)){
   await history(token,id);
   if(valid(token,who)){status.textContent='تمت الاستعادة في الإصدار '+id;sourceRefresh(true);void sync(true)}
  }
 });
 dlg.querySelector('[data-publish]').onclick=()=>void run(async(token,who)=>{
  const row=selected();if(!row||row.published_at)return;
  selectRecord(row);
  if(!confirm('نشر الإصدار '+row.id+' للحزمة '+row.pack+'؟\n'+[field('role'),field('branch'),field('device')].map(s=>s.selectedOptions[0]?.textContent).join(' · ')))return;
  await rpc('ff_ui_publish',{p_id:row.id});
  if(valid(token,who)){await history(token,row.id);if(valid(token,who)){status.textContent='نُشر الإصدار رقم '+row.id;sourceRefresh(true);void sync(true)}}
 });
 dlg.querySelector('[data-close]').onclick=()=>dlg.close();dlg.onclose=()=>{session++;busy=false;clearSource()};
 window.addEventListener('ff-luxe-session-reset',reset);
 document.getElementById('ffx-branch').addEventListener('change',()=>sync(true));
 matchMedia('(max-width:850px)').addEventListener('change',()=>sync(true));
 window.ffDashboardStudio={open,sync};
})();
