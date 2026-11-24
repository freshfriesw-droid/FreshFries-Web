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
 <h3>معاينة بتفاصيل تجريبية</h3><div class="ff-studio-preview"><div class="ff-design-layout"><div data-slot="hero">الرئيسية</div><div data-slot="stats">مؤشرات · ٤ طلبات</div><div data-slot="work">الطلبات والإجراءات السريعة</div><div data-slot="late">المتابعة · طلب متأخر</div></div></div>
 <div class="actions"><button type="submit" class="primary">حفظ مسودة جديدة</button></div>
 <label>سجل الإصدارات<select name="version"></select></label><div class="actions"><button type="button" data-load>معاينة الإصدار</button><button type="button" data-publish>نشر الآن</button><button type="button" data-restore>استعادة كمسودة</button></div><p role="status" aria-live="polite"></p></form>`;
 document.body.append(dlg);
 const form=dlg.querySelector('form'),fields=form.elements,status=dlg.querySelector('[role=status]'),preview=dlg.querySelector('.ff-design-layout');
 const field=name=>fields.namedItem(name);
 const dashboard=document.getElementById('ffx-dashboard'),caption=document.getElementById('ffx-hero-sub'),original=caption.textContent;
 const actor=()=>typeof user!=='undefined'&&user?.id&&typeof data!=='undefined'&&data?.role?user.id:'';
 const manager=()=>actor()&&data.role==='manager';
 let records=[],context='',last=0,serial=0,session=0,busy=false;
 function apply(version){
  dashboard.classList.toggle('ff-design-layout',!!version);
  if(version){dashboard.dataset.pack=version.pack;document.body.dataset.ffBar=version.bar}
  else{delete dashboard.dataset.pack;delete document.body.dataset.ffBar}
  caption.textContent=version?.layout_text||original;
 }
 function scope(){const branches=data?.branches||[];return document.getElementById('ffx-branch')?.value||(branches.length===1?branches[0].id:null)}
 async function sync(force=false){
  const who=actor();
  if(!who){if(context)reset();return}
  const branch=scope(),device=matchMedia('(max-width:850px)').matches?'mobile':'desktop';
  const key=[who,data.role,branch,device].join('|');
  if(key!==context){apply(null);context=key;last=0}
  if(!force&&Date.now()-last<30000)return;
  last=Date.now();const request=++serial;
  try{const rows=await rpc('ff_ui_effective',{p_branch:branch,p_device:device});
   if(request===serial&&who===actor()&&branch===scope()&&device===(matchMedia('(max-width:850px)').matches?'mobile':'desktop'))apply(rows?.[0])
  }catch{ /* Keep last confirmed version for this context during network loss. */ }
 }
 function reset(){serial++;session++;context='';last=0;busy=false;records=[];field('version').replaceChildren();form.reset();status.textContent='';if(dlg.open)dlg.close();apply(null)}
 function redraw(){preview.dataset.pack=field('pack').value;preview.querySelector('[data-slot=hero]').textContent=field('caption').value||'الرئيسية'}
 function selectRecord(row){
  for(const [name,value] of Object.entries({role:row.role_scope,branch:row.branch_id||'',device:row.device,caption:row.layout_text,pack:row.pack,bar:row.bar}))field(name).value=value;
  redraw();
 }
 function buttons(){const row=records.find(r=>String(r.id)===field('version').value);
  for(const b of form.querySelectorAll('button:not([data-close])'))b.disabled=busy;
  dlg.querySelector('[data-publish]').disabled=busy||!row||!!row.published_at;
  dlg.querySelector('[data-restore]').disabled=busy||!row?.published_at;
  dlg.querySelector('[data-load]').disabled=busy||!row;
 }
 async function history(token,selected){
  const rows=await rpc('ff_ui_manager_history');
  if(token!==session||!manager())return;
  records=rows||[];field('version').replaceChildren(...records.map(r=>new Option('#'+r.id+' · '+(r.published_at?'منشور':'مسودة')+' · '+r.pack+' · '+roles[r.role_scope]+' · '+(data.branches?.find(b=>b.id===r.branch_id)?.name||(r.branch_id?'فرع محدد':'كل الفروع'))+' · '+r.device,r.id)));
  if(selected)field('version').value=selected;
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
  if(!manager()||dlg.open)return;session++;form.reset();records=[];field('version').replaceChildren();status.textContent='';field('branch').replaceChildren(new Option('كل الفروع',''),...(data.branches||[]).map(b=>new Option(b.name,b.id)));redraw();dlg.showModal();void run(token=>history(token));
 }
 for(const [k,label] of Object.entries(roles))field('role').add(new Option(label,k));
 packs.forEach((name,i)=>{const code='D'+String(i+1).padStart(2,'0');field('pack').add(new Option(code+' · '+name,code))});
 form.oninput=redraw;field('version').onchange=buttons;
 form.onsubmit=e=>{e.preventDefault();void run(async(token,who)=>{
  const id=await rpc('ff_ui_save_draft',{p_role:field('role').value,p_branch:field('branch').value||null,p_device:field('device').value,p_pack:field('pack').value,p_text:field('caption').value,p_bar:field('bar').value});
  if(valid(token,who)){await history(token,id);if(valid(token,who))status.textContent='حُفظت المسودة رقم '+id}
 })};
 const selected=()=>records.find(r=>String(r.id)===field('version').value);
 dlg.querySelector('[data-load]').onclick=()=>{if(selected())selectRecord(selected())};
 dlg.querySelector('[data-restore]').onclick=()=>void run(async(token,who)=>{
  const row=selected();if(!row?.published_at)return;
  const id=await rpc('ff_ui_save_draft',{p_role:row.role_scope,p_branch:row.branch_id,p_device:row.device,p_pack:row.pack,p_text:row.layout_text,p_bar:row.bar,p_restore:row.id});
  if(valid(token,who)){await history(token,id);if(valid(token,who)){selectRecord(row);status.textContent='حُفظ إصدار الاستعادة كمسودة رقم '+id}}
 });
 dlg.querySelector('[data-publish]').onclick=()=>void run(async(token,who)=>{
  const row=selected();if(!row||row.published_at)return;
  selectRecord(row);
  if(!confirm('نشر الإصدار '+row.id+' للحزمة '+row.pack+'؟\n'+[field('role'),field('branch'),field('device')].map(s=>s.selectedOptions[0]?.textContent).join(' · ')))return;
  await rpc('ff_ui_publish',{p_id:row.id});
  if(valid(token,who)){await history(token,row.id);if(valid(token,who)){status.textContent='نُشر الإصدار رقم '+row.id;void sync(true)}}
 });
 dlg.querySelector('[data-close]').onclick=()=>dlg.close();dlg.onclose=()=>{session++;busy=false};
 window.addEventListener('ff-luxe-session-reset',reset);
 document.getElementById('ffx-branch').addEventListener('change',()=>sync(true));
 matchMedia('(max-width:850px)').addEventListener('change',()=>sync(true));
 window.ffDashboardStudio={open,sync};
})();
