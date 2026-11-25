/* Centrally published dashboard layouts. Preview uses synthetic cards only. */
(()=>{
 'use strict';
 const packs=["Fresh Classic", "Midnight Command", "Executive Carbon", "White Studio", "Graphite Pro", "Crimson Edge", "Soft Ivory", "Contrast Plus", "Touch Flow", "Compact Operations", "Control Grid", "Studio Cards", "Mission Control", "Kiosk Focus", "Minimal Black & White", "LUXE Editorial"].map((name,i)=>({code:'D'+String(i+1).padStart(2,'0'),name}));
 const roles={all:'كل الأدوار',manager:'المدير العام',supervisor:'المشرف',customer_service:'خدمة العملاء',cashier:'الكاشير',driver:'الموصل',assembly:'نقطة التجميع',burger_kitchen:'مطبخ البرجر'};
 const dlg=document.createElement('dialog');
 dlg.id='ffStudio';dlg.dir='rtl';dlg.setAttribute('aria-labelledby','ffStudioTitle');
 dlg.innerHTML=`<form><div class="sectionbar"><h2 id="ffStudioTitle">شاشة تحكم المدير العام</h2><button type="button" data-close>إغلاق</button></div>
 <h3>تصميم لوحة التشغيل</h3><div class="ff-studio-fields">
 <label>الدور<select name="role"></select></label><label>الفرع<select name="branch"></select></label>
 <label>الجهاز<select name="device"><option value="all">كل الأجهزة</option><option value="mobile">الجوال</option><option value="desktop">الكمبيوتر</option></select></label>
 <label>حزمة التصميم<select name="pack"></select></label><label>شريط الجوال<select name="bar"><option value="labels">أيقونات وتسميات</option><option value="icons">أيقونات فقط</option><option value="wide">أزرار عريضة</option><option value="floating">شريط عائم</option><option value="compact">مختصر مع المزيد</option></select></label>
 <label>وصف الرئيسية<input name="caption" maxlength="180" placeholder="استخدام الوصف الأصلي"></label></div>
 <details id="ffCardEditor"><summary>تحرير البطاقات التشغيلية</summary><p>البطاقات تستخدم مؤشرات النظام الفعلية فقط، وتطبق صلاحيات الحساب. تعديل البطاقة لا يغير مصدر البيانات أو يمنح صلاحيات إضافية.</p><div class="actions"><button type="button" data-card-add>إضافة بطاقة</button><button type="button" data-card-default>البطاقات الافتراضية</button><button type="button" data-card-undo>تراجع</button><button type="button" data-card-redo>إعادة</button></div><div data-card-list></div><p data-card-count></p><div data-card-preview aria-label="معاينة البطاقات غير التفاعلية"></div></details><h3>معاينة بتفاصيل تجريبية</h3><label>عرض المعاينة بالبكسل<select name="viewport"></select></label><div class="ff-preview-scroll" tabindex="0" aria-label="معاينة قابلة للتمرير"><div class="ff-studio-preview"><div class="ff-design-layout"><h3 class="ffx-section-head">لوحة التحكم</h3><div data-slot="hero">الرئيسية</div><div data-slot="stats">مؤشرات · ٤ طلبات</div><div data-slot="work">الطلبات والإجراءات السريعة</div><div data-slot="late">المتابعة · طلب متأخر</div></div><div class="ff-studio-bar" aria-label="معاينة شريط الهاتف — غير تفاعلية"></div></div></div><section class="ff-studio-impact" aria-label="تقرير أثر المسودة"><h3>تقرير التأثير قبل النشر</h3><p data-impact-scope></p><p data-impact-contrast></p><p data-impact-nav></p><p data-release-impact aria-live="polite"></p><button type="button" data-release-check>تحقق من أثر الإصدار المحدد</button><section aria-label="مصدر القيمة الفعالة"><h4>مصدر التصميم المنشور الفعّال</h4><p data-source-status aria-live="polite"></p><dl data-source-details hidden><dt>الحزمة</dt><dd data-source-pack></dd><dt>شريط الهاتف</dt><dd data-source-bar></dd><dt>وصف الواجهة</dt><dd data-source-caption></dd><dt>مصادر الخصائص الفعّالة</dt><dd data-source-layers></dd></dl><p>المصدر للنطاق المحدد من الإصدارات المنشورة فقط؛ لا يشمل تجارب حسابات معينة.</p></section><p>معاينة اصطناعية لا تنفذ طلبات أو تغيّر صلاحيات. فحص التباين هنا خاص بخلفية الحزمة ونصها؛ لا يغني عن اختبار الشاشات الفعلية.</p></section>
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
 const appearance=window.ffA07Design;
 appearance.selectFields(form);
 const redrawGallery=appearance.gallery(form,packs);
 const a08=window.ffA08Dashboard;
 const a08Panels=a08.editor(form,dlg.querySelector('#ffCardEditor'));
 const inheritance=document.createElement('label');inheritance.innerHTML='<input type="checkbox" data-a08-inherit-cards> وراثة البطاقات من النطاق الأعم (بدلاً من حفظ ترتيب مستقل)';
 dlg.querySelector('[data-card-list]').before(inheritance);
 const inherit=inheritance.querySelector('input');
 const readStyle=()=>({...appearance.readStyle(form),...a08.read(form)});
 const scopeCompare=document.createElement('details');scopeCompare.id='ffStep03ScopeCompare';
 scopeCompare.innerHTML='<summary>معاينة متوازية لنطاقين قبل النشر</summary><p>تحسب قاعدة البيانات القيم الفعلية قبل وبعد المسودة وفق الأولوية. المقارنة لا تحفظ أو تنشر شيئًا، وتعرض بيانات اصطناعية فقط.</p><div class="ff-a07-compare-grid" data-scope-targets></div><button type="button" data-step03-compare>معاينة النطاقين</button><p data-step03-compare-status aria-live="polite"></p><div data-step03-compare-results></div>';
 dlg.querySelector('#ffA07Gallery').after(scopeCompare);
 const scopeTargets=[];
 for(let i=0;i<2;i++){
  const box=document.createElement('section'),h=document.createElement('h4');h.textContent='النطاق '+(i+1);box.append(h);const fields={};
  for(const [key,label,options] of [['screen','الشاشة',Object.entries(appearance.screens).filter(([k])=>k!=='all')],['role','الدور',Object.entries(roles)],['branch','الفرع',[]],['device','الجهاز',[['mobile','الجوال'],['desktop','الكمبيوتر']]]]){
   const wrap=document.createElement('label');wrap.textContent=label;const select=document.createElement('select');select.dataset.scopeTarget=String(i)+'-'+key;select.replaceChildren(...options.map(([k,v])=>new Option(v,k)));wrap.append(select);box.append(wrap);fields[key]=select;
  }const constrain=()=>{const pub=appearance.publicScreen(fields.screen.value);fields.role.options[0].disabled=!pub;if(pub){fields.role.value='all';fields.branch.value=''}else if(fields.role.value==='all')fields.role.value='manager';fields.role.disabled=pub;fields.branch.disabled=pub};fields.screen.addEventListener('change',constrain);fields.constrain=constrain;scopeCompare.querySelector('[data-scope-targets]').append(box);scopeTargets.push(fields);
 }
 const scopeStatus=scopeCompare.querySelector('[data-step03-compare-status]'),scopeResults=scopeCompare.querySelector('[data-step03-compare-results]');
 let scopeSnapshot='';
 function clearScopeComparison(){scopeSnapshot='';scopeStatus.textContent='';scopeResults.replaceChildren()}
 const scopeDraft=()=>({p_screen_scope:field('screen').value,p_role_scope:field('role').value,p_branch_scope:field('branch').value||null,p_device_scope:field('device').value,p_pack:field('pack').value,p_style:readStyle()});
 const scopeSelection=()=>scopeTargets.map(t=>({p_target_screen:t.screen.value,p_target_role:t.role.value,p_target_branch:t.branch.value||null,p_target_device:t.device.value}));
 const scopeSignature=()=>JSON.stringify([scopeDraft(),scopeSelection()]);
 function invalidateScopeComparison(){if(scopeSnapshot&&scopeSnapshot!==scopeSignature()){clearScopeComparison();scopeStatus.textContent='تغيّرت المسودة أو النطاقات؛ أعد المعاينة قبل الاعتماد.'}}
 function initScopeComparison(){clearScopeComparison();scopeCompare.open=false;for(const [i,t] of scopeTargets.entries()){t.branch.replaceChildren(...Array.from(field('branch').options,o=>o.cloneNode(true)));t.screen.value=field('screen').value==='all'?'dashboard':field('screen').value;t.role.value=field('role').value==='all'?'manager':field('role').value;t.branch.value=field('branch').value;t.device.value=i?'desktop':'mobile';t.constrain()}}
 scopeCompare.querySelector('[data-step03-compare]').onclick=()=>void run(async(token,who)=>{
  clearScopeComparison();scopeStatus.textContent='جاري حساب طبقات التصميم…';
  const draft=scopeDraft(),targets=scopeSelection(),snapshot=scopeSignature();scopeSnapshot=snapshot;
  try{
   const rows=await Promise.all(targets.map(t=>rpc('ff_a07_preview_scope',{...draft,...t})));
   if(!valid(token,who)||scopeSnapshot!==snapshot)return;
   if(scopeSignature()!==snapshot){invalidateScopeComparison();return}
   for(const [i,row] of rows.entries()){
    if(!row?.before||!row?.after)throw Error('لم تصل نتيجة المعاينة');
    const target=targets[i],box=document.createElement('section'),heading=document.createElement('h4');heading.textContent='النطاق '+(i+1)+' · '+screenLabel(target.p_target_screen)+' · '+roles[target.p_target_role]+' · '+(target.p_target_branch?(data.branches?.find(b=>b.id===target.p_target_branch)?.name||'فرع محدد'):'دون تخصيص فرع')+' · '+(target.p_target_device==='mobile'?'جوال':'كمبيوتر');box.append(heading);
    const state=document.createElement('p');state.textContent=row.applies?'النطاق مشمول بالمسودة؛ تبقى الأولويات الأكثر تخصيصًا فعالة.':'خارج نطاق المسودة — لا تغيير.';box.append(state);
    const grid=document.createElement('div');grid.className='ff-a07-compare-grid';
    for(const [label,value] of [['قبل',row.before],['بعد',row.after]]){const col=document.createElement('div'),h=document.createElement('b');h.textContent=label;col.append(h,appearance.demoCard(target.p_target_screen,value.pack,value.style_config));grid.append(col)}
    box.append(grid);const source=document.createElement('details'),summary=document.createElement('summary');summary.textContent='قيمة ومصدر كل خاصية قبل وبعد المسودة';source.append(summary);const table=document.createElement('table'),header=table.createTHead().insertRow();for(const label of ['الخاصية','القيمة قبل','المصدر قبل','القيمة بعد','المصدر بعد']){const th=document.createElement('th');th.textContent=label;header.append(th)}const body=table.createTBody(),before=row.before_sources||{},after=row.after_sources||{};for(const key of [...new Set([...Object.keys(before),...Object.keys(after)])].sort()){const tr=body.insertRow(),label=window.ffA07Elements?.sourceLabel(key)||appearance.tokens[key]?.[0]||key;for(const value of [label,sourceValue(row.before.style_config,key),sourceRevision(before[key]),sourceValue(row.after.style_config,key),sourceRevision(after[key])])tr.insertCell().textContent=value}if(!body.rows.length){const cell=body.insertRow().insertCell();cell.colSpan=5;cell.textContent='الخصائص الأساسية للحزمة'}source.append(table);box.append(source);scopeResults.append(box);
   }
   scopeStatus.textContent='تم حساب النطاقين دون حفظ أي تعديل.';
  }catch(e){if(valid(token,who)&&scopeSnapshot===snapshot){clearScopeComparison();scopeStatus.textContent='تعذرت المعاينة الفعلية: '+e.message}}
 });
 const setStyle=v=>{appearance.setStyle(form,v);a08.set(form,v)};
 const dashboard=document.getElementById('ffx-dashboard'),caption=document.getElementById('ffx-hero-sub'),original=caption.textContent;
 const actor=()=>typeof user!=='undefined'&&user?.id&&typeof data!=='undefined'&&data?.role?user.id:'';
 const manager=()=>actor()&&data.role==='manager';
 const screenLabel=k=>appearance.screens[k]||appearance.screens.dashboard;
 const operationalIdentity=()=>{
  const who=typeof user!=='undefined'&&user?.id;if(!who)return null;
  const role=typeof ffV12AssemblyActive!=='undefined'&&ffV12AssemblyActive?'assembly':window.ffBurgerActive?.()?'burger_kitchen':data?.role;
  if(!role)return null;
  const branch=role==='assembly'?ffV12AssemblyPayload?.branch?.id||null:role==='burger_kitchen'?null:scope();
  const device=matchMedia('(max-width:850px)').matches?'mobile':'desktop';
  return {who,role,branch,device,key:[who,role,branch,device].join('|')};
 };
 let records=[],context='',last=0,serial=0,session=0,busy=false,sourceSerial=0,sourceTimer,sourceKey='';
 const metricNames={orders_today:'طلبات اليوم التشغيلي',late_today:'طلبات اليوم المتأخرة (60 دقيقة)',completed_today:'طلبات اليوم المنجزة',available_drivers:'الموصلون المتاحون الآن'};
 const sizes={normal:'عادي',wide:'عريض',full:'عرض كامل'},tones={default:'افتراضي',red:'أحمر',black:'أسود',neutral:'محايد'};
 const defaults=()=>Object.entries(metricNames).map(([metric,label])=>({metric,label,size:'normal',tone:'default'}));
 let cards=defaults(),undoCards=[],redoCards=[],editorActor='';
 const copyCards=items=>JSON.parse(JSON.stringify(items));
 const cardSnapshot=()=>({cards:copyCards(cards),inherit:inherit.checked});
 const restoreCardSnapshot=s=>{cards=s.cards;inherit.checked=s.inherit;renderCardEditor()};
 function rememberCards(){undoCards.push(cardSnapshot());redoCards=[]}
 function changeCards(action){if(busy||!manager())return;rememberCards();inherit.checked=false;action();renderCardEditor();}
 function renderCardPreview(){
  const preview=dlg.querySelector('[data-card-preview]');preview.replaceChildren();
  const width=Number(field('viewport').value)||390;preview.style.setProperty('--ff-card-columns',width<430?'2':width<768?'3':'4');
  for(const [i,card] of cards.entries()){
   const role=field('role').value;if(role!=='all'&&!a08.cardVisible(card,role,()=>true))continue;
   const box=document.createElement('div');box.className='ff-card-sample';box.dataset.cardIndex=String(i);box.dataset.cardSize=card.size;box.dataset.cardTone=card.tone;
   const name=document.createElement('b');name.textContent=card.label+(card.icon?' · '+(a08.icons[card.icon]||''):'');
   const value=document.createElement('span');value.textContent=card.permission?'تتطلب صلاحية':card.metric==='available_drivers'&&!['all','manager','supervisor','customer_service'].includes(field('role').value)?'غير متاح':'—';
   box.append(name,value);preview.append(box);
  }
  dlg.querySelector('[data-card-count]').textContent=(inherit.checked?'الوراثة مفعّلة · البطاقات المعروضة نموذج للترتيب فقط · ':'')+cards.length+' بطاقة — معاينة تخطيطية دون أرقام افتراضية';
 }
 function renderCardEditor(){
  const list=dlg.querySelector('[data-card-list]');const expanded=[...list.querySelectorAll('.ff-a08-card-access')].map(n=>n.open);list.replaceChildren();
  for(let i=0;i<cards.length;i++){
   const card=cards[i],row=document.createElement('section');row.className='ff-card-edit-row';row.draggable=true;
   row.addEventListener('dragstart',e=>{e.dataTransfer.setData('text/plain',String(i));e.dataTransfer.effectAllowed='move'});
   row.addEventListener('dragover',e=>e.preventDefault());
   row.addEventListener('drop',e=>{e.preventDefault();const raw=e.dataTransfer.getData('text/plain'),from=Number(raw);if(/^\d+$/.test(raw)&&Number.isInteger(from)&&from>=0&&from<cards.length&&from!==i)changeCards(()=>cards.splice(i,0,...cards.splice(from,1)))});
   const input=document.createElement('input');input.maxLength=100;input.required=true;input.value=card.label;input.setAttribute('aria-label','عنوان البطاقة '+(i+1));input.addEventListener('change',()=>{if(busy||!manager())return;rememberCards();inherit.checked=false;card.label=input.value.trim();renderCardPreview();dlg.querySelector('[data-card-undo]').disabled=false;dlg.querySelector('[data-card-redo]').disabled=true});input.addEventListener('input',()=>{const box=dlg.querySelector('[data-card-preview] [data-card-index="'+i+'"] b');if(box)box.textContent=input.value});
   row.append(input);
   for(const [key,options] of Object.entries({metric:metricNames,size:sizes,tone:tones})){
    const select=document.createElement('select');select.setAttribute('aria-label',({metric:'مصدر المؤشر',size:'مقاس البطاقة',tone:'لون البطاقة'})[key]+' '+(i+1));select.replaceChildren(...Object.entries(options).map(([k,label])=>new Option(label,k)));select.value=card[key];select.onchange=()=>changeCards(()=>{card[key]=select.value;if(key==='metric')card.label=metricNames[select.value]});row.append(select);
   }
   const actions=document.createElement('div');actions.className='actions';
   for(const [label,disabled,action] of [['تقديم',i===0,()=>cards.splice(i-1,0,...cards.splice(i,1))],['تأخير',i===cards.length-1,()=>cards.splice(i+1,0,...cards.splice(i,1))],['نسخ',false,()=>cards.splice(i+1,0,...copyCards([card]))],['حذف',false,()=>cards.splice(i,1)]]){
    const btn=document.createElement('button');btn.type='button';btn.textContent=label;btn.disabled=disabled;btn.onclick=()=>changeCards(action);actions.append(btn);
   }
   const access=a08.cardFields(card,i,changeCards);access.open=!!expanded[i];row.append(access);row.append(actions);list.append(row);
  }
  dlg.querySelector('[data-card-undo]').disabled=busy||!undoCards.length;dlg.querySelector('[data-card-redo]').disabled=busy||!redoCards.length;
  renderCardPreview();
 }
 function resetCards(layout,inheritLayout=false){inherit.checked=inheritLayout;cards=Array.isArray(layout)?copyCards(layout):defaults();undoCards=[];redoCards=[];renderCardEditor()}
 inherit.onchange=()=>{if(busy||!manager())return;undoCards.push({cards:copyCards(cards),inherit:!inherit.checked});redoCards=[];renderCardEditor()};
 dlg.querySelector('[data-card-add]').onclick=()=>changeCards(()=>cards.push(defaults()[0]));
 dlg.querySelector('[data-card-default]').onclick=()=>changeCards(()=>{cards=defaults()});
 dlg.querySelector('[data-card-undo]').onclick=()=>{if(!busy&&manager()&&undoCards.length){redoCards.push(cardSnapshot());restoreCardSnapshot(undoCards.pop())}};

 dlg.querySelector('[data-card-redo]').onclick=()=>{if(!busy&&manager()&&redoCards.length){undoCards.push(cardSnapshot());restoreCardSnapshot(redoCards.pop())}};
 const revisionLabel=document.createElement('small');
 caption.after(revisionLabel);
 function apply(version,cardLayout=null,barVersion=version){
  window.ffApplyCardLayout?.(cardLayout,version?.style_config||{},version?.card_layout_source??null);
  revisionLabel.hidden=!version;
  revisionLabel.textContent=version?'إصدار التصميم '+version.id:'';
  dashboard.classList.toggle('ff-design-layout',!!version);
  if(version)dashboard.dataset.pack=version.pack;else delete dashboard.dataset.pack;
  if(barVersion?.bar)document.body.dataset.ffBar=barVersion.bar;else delete document.body.dataset.ffBar;
  caption.textContent=version?.layout_text||original;
 }
 function scope(){const branches=data?.branches||[];return document.getElementById('ffx-branch')?.value||(branches.length===1?branches[0].id:null)}
 async function sync(force=false){
  const ident=operationalIdentity();
  if(!ident){if(context||dlg.open)reset();return}
  if(dlg.open&&(!manager()||editorActor!==ident.who))reset();
  if(ident.key!==context){serial++;appearance.clear();apply(null);context=ident.key;last=0}
  if(!force&&Date.now()-last<3000){appearance.refresh();return}
  last=Date.now();const request=++serial;
  try{
   let rows;
   try{rows=await rpc('ff_a07_effective_designs',{p_branch:ident.branch,p_device:ident.device})}
   catch(e){if(e.code!=='PGRST202')throw e;rows=null}
   // Compatibility with pre-migration clients/fixtures only, never on permission errors.
   if(!rows||Array.isArray(rows)){const legacy=await rpc('ff81_effective_design',{p_branch:ident.branch,p_device:ident.device});rows=legacy?.pack?{dashboard:legacy}:{}}
   if(request!==serial||operationalIdentity()?.key!==ident.key)return;
   const version=rows.dashboard||null;
   const roleVersion=rows[appearance.roleScreens[ident.role]]||version;
   apply(version,version?.card_layout??null,roleVersion);appearance.apply(rows);
  }catch{/* Keep the last confirmed design only for the same account and scope. */}
 }
 function reset(){editorActor='';clearScopeComparison();clearSource();appearance.clear();serial++;session++;context='';last=0;busy=false;records=[];field('version').replaceChildren();field('baseline').replaceChildren();field('accounts').replaceChildren();dlg.querySelector('[data-release-impact]').textContent='';compare();form.reset();setStyle({});resetCards(null);status.textContent='';if(dlg.open)dlg.close();apply(null)}
 const sampleNav={all:['الرئيسية','الطلبات','المزيد'],manager:['الرئيسية','طلب جديد','الطلبات','تحكم المدير','المزيد'],supervisor:['الرئيسية','الطلبات','المزيد'],customer_service:['الرئيسية','طلب جديد','الطلبات','المزيد'],cashier:['الرئيسية','شاشة الكاشير','المزيد'],driver:['الرئيسية','مهامي','المزيد'],assembly:['الرئيسية','المزيد'],burger_kitchen:['الرئيسية','المزيد']};
 function luminance(hex){
  const parts=/^#([0-9a-f]{6})$/i.exec(hex.trim());if(!parts)return null;
  const v=parts[1].match(/../g).map(x=>parseInt(x,16)/255).map(x=>x<=0.04045?x/12.92:((x+0.055)/1.055)**2.4);
  return v[0]*0.2126+v[1]*0.7152+v[2]*0.0722;
 }
 function sourceEl(name){return dlg.querySelector('[data-source-'+name+']')}
 function sourceRevision(id){return id===-1?'المسودة':id==null?'الأساسي / الحزمة':'#'+id}
 function sourceValue(style,key){const v=window.ffA07Elements?.effectiveValue(style,key);if(v==null)return 'حسب الحزمة';if(typeof v==='boolean')return v?'نعم':'لا';return appearance.tokens[key]?.slice(1).find(x=>x[0]===v)?.[1]||String(v)}
 function clearSource(){
  clearTimeout(sourceTimer);sourceSerial++;sourceKey='';
  sourceEl('status').textContent='';sourceEl('details').hidden=true;
  for(const name of ['pack','bar','caption','layers'])sourceEl(name).textContent='';
  window.ffA07Elements?.setSources(form,null);
 }
 function sourceRefresh(force=false){
  if(!dlg.open||!manager())return;
  const who=actor(),token=session,role=field('role').value,b=field('branch').value||null,screen=field('screen').value;
  const d=field('device').value==='all'?(Number(field('viewport').value)<=850?'mobile':'desktop'):field('device').value;
  const key=[who,role,b,d,screen].join('|');
  if(!force&&key===sourceKey)return;
  clearSource();sourceKey=key;
  if(role==='all'&&!appearance.publicScreen(screen)){sourceEl('status').textContent='اختر دوراً محدداً لمقارنة التصميم المنشور الفعّال؛ خيار كل الأدوار هو نطاق المسودة لا حساب معاينة محدد.';return}
  const request=++sourceSerial;
  sourceEl('status').textContent='جاري التحقق من مصدر التصميم…';
  sourceTimer=setTimeout(async()=>{
   try{
    let rows;try{rows=await rpc('ff_a07_manager_source',{p_screen:screen,p_role:role,p_branch:b,p_device:d})}catch(e){if(e.code!=='PGRST202'||screen!=='dashboard')throw e;rows=await rpc('ff_ui_manager_source',{p_role:role,p_branch:b,p_device:d})}
    if(request!==sourceSerial||token!==session||who!==actor()||!manager()||!dlg.open)return;
    const row=rows?.[0],deviceLabel={all:'كل الأجهزة',mobile:'الجوال',desktop:'الكمبيوتر'};
    const branchLabel=id=>data.branches?.find(item=>item.id===id)?.name||(id?'فرع محدد':'دون تخصيص فرع');
    if(!row){sourceEl('status').textContent='التصميم الأساسي للنظام — لا يوجد إصدار منشور مطابق لهذا النطاق ('+roles[role]+' · '+branchLabel(b)+' · '+deviceLabel[d]+').';window.ffA07Elements?.setSources(form,{});return}
    sourceEl('status').textContent='الإصدار #'+row.id+' · '+screenLabel(row.screen_scope)+' · '+roles[row.role_scope]+' · '+branchLabel(row.branch_id)+' · '+deviceLabel[row.device];
    sourceEl('pack').textContent=row.pack;sourceEl('bar').textContent=Array.from(field('bar').options).find(o=>o.value===row.bar)?.textContent||row.bar;
    sourceEl('caption').textContent=row.layout_text||original;sourceEl('details').hidden=false;
    try{const layers=await rpc('ff_a07_manager_style_layers',{p_screen:screen,p_role:role,p_branch:b,p_device:d});if(request!==sourceSerial||token!==session||who!==actor()||!manager()||!dlg.open)return;const api=window.ffA07Elements;api?.setSources(form,layers?.sources||{},layers?.style||{});const lines=Object.entries(layers?.sources||{}).map(([k,id])=>{const parts=k.split('.');if(parts[0]==='elements'){const [,group,key,property]=parts;if(key&&property){const rows=layers.style?.elements?.[group]||[],index=rows.findIndex(e=>e.key===key),value=property==='order'?index+1:rows[index]?.[property];const shown=api?.properties[property]?.[value]||({shape:api?.shapes,size:api?.sizes}[property]?.[value])||value;return (api?.labels[group]||group)+' / '+(api?.itemLabels[key]||key)+' / '+(api?.propertyLabels[property]||({shape:'الشكل',size:'الحجم',order:'الترتيب'}[property])||property)+' = '+(shown??'—')+' ← #'+id;}return (api?.labels[group]||group)+' ← #'+id}return (appearance.tokens[k]?.[0]||k)+' = '+(appearance.tokens[k]?.slice(1).find(x=>x[0]===layers.style?.[k])?.[1]||layers.style?.[k]||'—')+' ← #'+id});sourceEl('layers').textContent=lines.join(' · ')||'الخصائص الأساسية للحزمة';
     if(['all','dashboard'].includes(screen)){try{const cs=await rpc('ff_a08_manager_card_source',{p_role:role,p_branch:b,p_device:d});if(request!==sourceSerial||token!==session||who!==actor()||!manager()||!dlg.open)return;sourceEl('layers').textContent+=' · البطاقات ← '+(cs?.[0]?.revision?'#'+cs[0].revision:'الافتراضي')}catch{/* Other source details remain valid. */}}}catch{if(request===sourceSerial)sourceEl('layers').textContent='تعذر التحقق من طبقات الخصائص'}
   }catch(e){if(request===sourceSerial&&token===session&&who===actor()&&manager()&&dlg.open){sourceEl('status').textContent='تعذر التحقق من المصدر المنشور. لا تعتبر القيمة المعروضة اعتماداً.';sourceKey=''}}
  },180);
 }
 function constrainPublicScope(){const pub=appearance.publicScreen(field('screen').value);if(pub){field('role').value='all';field('branch').value=''}field('role').disabled=busy||pub;field('branch').disabled=busy||pub;for(const t of scopeTargets)t.constrain()}
 function redraw(){
  constrainPublicScope();invalidateScopeComparison();
  const width=Number(field('viewport').value),role=field('role').value,bar=field('bar').value;
  preview.parentElement.style.width=width+'px';
  preview.dataset.pack=field('pack').value;appearance.decorate(preview,{pack:field('pack').value,style_config:appearance.readStyle(form),id:'preview'});
  const selectedScreen=field('screen').value==='all'?(appearance.roleScreens[role]||'dashboard'):field('screen').value;
  preview.querySelector('[data-slot=hero]').textContent=field('caption').value||screenLabel(selectedScreen);
  preview.querySelector('[data-slot=work]').replaceChildren(appearance.demoCard(selectedScreen,field('pack').value,appearance.readStyle(form),true));
  preview.querySelector('[data-slot=stats]').textContent=selectedScreen==='dashboard'?'مؤشرات · بيانات تجريبية':'عناصر '+screenLabel(selectedScreen)+' · مثال';
  const nav=dlg.querySelector('.ff-studio-bar');nav.dataset.bar=bar;nav.hidden=width>850||appearance.publicScreen(selectedScreen);nav.replaceChildren();
  const labels=sampleNav[role]||sampleNav.all;
  for(const [i,label] of labels.entries()){
   const item=document.createElement('span');item.className='ff-studio-bar-item';item.title=label;
   const mark=document.createElement('span');mark.setAttribute('aria-hidden','true');mark.textContent=i===0?'⌂':i===labels.length-1?'☰':'◇';
   const name=document.createElement('span');name.className='ff-studio-bar-label';name.textContent=label;
   item.append(mark,name);nav.append(item);
  }
  const targets=['screen','role','branch','device'].map(name=>field(name).selectedOptions[0]?.textContent||'—');
  dlg.querySelector('[data-impact-scope]').textContent='النطاق: '+targets.join(' · ')+' · '+width+'px';
  const style=getComputedStyle(preview),bg=luminance(style.getPropertyValue('--a07-bg')||style.getPropertyValue('--pack-bg')),ink=luminance(style.getPropertyValue('--a07-ink')||style.getPropertyValue('--pack-ink'));
  const ratio=bg===null||ink===null?null:(Math.max(bg,ink)+0.05)/(Math.min(bg,ink)+0.05);
  dlg.querySelector('[data-impact-contrast]').textContent=ratio===null?'تباين الحزمة: يحتاج تحقق':'تباين النص والخلفية: '+ratio.toFixed(2)+':1 — '+(ratio>=4.5?'يتوافق مع حد النص العادي 4.5:1':'يحتاج تعديل');
  dlg.querySelector('[data-impact-nav]').textContent=width>850?'شريط الهاتف لا يظهر في هذا العرض.':bar==='compact'?'الشريط المختصر: الرئيسية والمزيد والإجراء النشط؛ الاختصارات الأخرى عبر قائمة المزيد.':bar==='icons'?'الأيقونات فقط؛ أسماء العناصر تبقى لقارئ الشاشة.':'معاينة شكل الشريط؛ لا تخفي الإجراءات.';
  renderCardPreview();sourceRefresh();redrawGallery();
  dlg.querySelector('#ffCardEditor').hidden=!['all','dashboard'].includes(field('screen').value);
  a08Panels.hidden=dlg.querySelector('#ffCardEditor').hidden;
  a08.preview(form);
 }

 function selectRecord(row){
  for(const [name,value] of Object.entries({draftName:row.draft_name||'',description:row.draft_description||'',screen:row.screen_scope||'dashboard',role:row.role_scope,branch:row.branch_id||'',device:row.device,caption:row.layout_text,pack:row.pack,bar:row.bar}))field(name).value=value;
  setStyle(row.style_config);resetCards(row.card_layout,row.card_layout==null);redraw();
 }
 function compare(){
  const left=records.find(row=>String(row.id)===field('baseline').value);
  const right=records.find(row=>String(row.id)===field('version').value);
  const body=dlg.querySelector('[data-diff]');
  body.replaceChildren();
  if(!left||!right)return;
  const branch=id=>data.branches?.find(item=>item.id===id)?.name||(id?'فرع محدد':'كل الفروع');
  const properties=[
   ['اسم المسودة',row=>row.draft_name||'—'],['وصف التعديل',row=>row.draft_description||'—'],['الشاشة',row=>screenLabel(row.screen_scope)],['الدور',row=>roles[row.role_scope]],['الفرع',row=>branch(row.branch_id)],
   ['الجهاز',row=>row.device],['الحزمة',row=>row.pack],['شريط الجوال',row=>row.bar],
   ['وصف الواجهة',row=>row.layout_text||original],['خصائص المظهر',row=>Object.entries(row.style_config||{}).sort().map(([k,v])=>(appearance.tokens[k]?.[0]||(k==='elements'?'ترتيب العناصر وأشكالها':k))+': '+(typeof v==='object'?JSON.stringify(v):appearance.tokens[k]?.slice(1).find(x=>x[0]===v)?.[1]||v)).join('\n')||'حسب الحزمة'],['عدد البطاقات',row=>row.card_layout==null?'وراثة / الافتراضي':String(row.card_layout.length)],['ترتيب البطاقات ومصادرها وأحجامها وألوانها',row=>(row.card_layout??defaults()).map((card,i)=>(i+1)+'. '+card.label+' ['+(metricNames[card.metric]||card.metric)+' · '+(sizes[card.size]||card.size)+' · '+(tones[card.tone]||card.tone)+' · '+(card.roles?.join('/')||'كل الأدوار')+' · '+(card.permission||'الصلاحيات الأصلية')+' · '+(card.icon||'أيقونة المؤشر')+']').join('\n')||'لا توجد بطاقات']
  ];
  for(const [label,value] of properties){
   if(value(left)===value(right))continue;
   const tr=body.insertRow();
   for(const item of [label,value(left),value(right)]){const cell=tr.insertCell();cell.textContent=item;cell.style.whiteSpace='pre-wrap'}
  }
  if(!body.rows.length){
   const cell=body.insertRow().insertCell();
   cell.colSpan=3;cell.textContent='إعدادات الإصدارين متطابقة';
  }
 }
 function releaseSummary(info){
 return (info.valid?'صالح للنشر وفق النطاق':'مسودة غير صالحة أو قديمة')+' · '+(info.public?'نطاق عام دون حسابات محددة':'الحسابات المؤهلة: '+info.target_count)+' · الإصدار السابق: '+(info.previous?'#'+info.previous:'الأساسي');
}
 async function releaseImpact(row,token,who){
  const info=await rpc('ff_step08_release_impact',{p_kind:'design',p_id:row.id});
  if(!valid(token,who)||selected()?.id!==row.id)return null;
  if(!info||Number(info.id)!==Number(row.id))throw Error('تعذر التحقق من تقرير التأثير');
  dlg.querySelector('[data-release-impact]').textContent=releaseSummary(info);
  return info;
 }
 function buttons(){const row=records.find(r=>String(r.id)===field('version').value);
  for(const b of form.querySelectorAll('button:not([data-close])'))b.disabled=busy;
  for(const el of form.querySelectorAll('input,select,textarea'))el.disabled=busy;
  a08.setBusy(form,busy);
  dlg.querySelector('[data-card-undo]').disabled=busy||!undoCards.length;dlg.querySelector('[data-card-redo]').disabled=busy||!redoCards.length;
  for(const row of dlg.querySelectorAll('.ff-card-edit-row')){row.draggable=!busy;const b=row.querySelectorAll('button');if(b.length){b[0].disabled=busy||row===row.parentElement.firstElementChild;b[1].disabled=busy||row===row.parentElement.lastElementChild}}
  dlg.querySelector('[data-publish]').disabled=busy||!row||!!row.published_at;
  dlg.querySelector('[data-restore]').disabled=busy||!row?.published_at;
  dlg.querySelector('[data-rollback]').disabled=busy||!row?.published_at||!row.previous_id||records.some(
   other=>other.published_at&&other.previous_id===row.id
  );
  for(const action of ['accounts','stop','trial'])dlg.querySelector('[data-'+action+']').disabled=busy||!row||!!row.published_at||appearance.publicScreen(row?.screen_scope);constrainPublicScope();
  dlg.querySelector('[data-load]').disabled=busy||!row;dlg.querySelector('[data-release-check]').disabled=busy||!row;
 }
 async function refreshCatalog(token){
  const who=actor();let rows;try{rows=await rpc('ff_a07_design_catalog')}catch{return}
  if(!valid(token,who)||!Array.isArray(rows)||!rows.length)return;
  const safe=rows.filter(p=>/^D[0-9]{2,}$/.test(p.code)&&typeof p.name==='string');if(!safe.length)return;
  const previous=field('pack').value;packs.splice(0,packs.length,...safe);field('pack').replaceChildren(...packs.map(({code,name})=>new Option(code+' · '+name,code)));if(safe.some(p=>p.code===previous))field('pack').value=previous;redraw();
 }
 async function history(token,selected){
  const who=actor(),rows=await rpc('ff_ui_manager_history');
  if(token!==session||who!==actor()||!manager()||!dlg.open||editorActor!==who)return;
  field('accounts').replaceChildren();dlg.querySelector('[data-release-impact]').textContent='';records=rows||[];field('version').replaceChildren(...records.map(r=>new Option('#'+r.id+' · '+(r.draft_name||'تصميم')+' · '+new Date(r.created_at).toLocaleDateString('ar-YE')+' · '+(r.published_at?'منشور':'مسودة')+' · '+r.pack+' · '+screenLabel(r.screen_scope)+' · '+roles[r.role_scope]+' · '+(data.branches?.find(b=>b.id===r.branch_id)?.name||(r.branch_id?'فرع محدد':'كل الفروع'))+' · '+r.device,r.id)));
  if(selected)field('version').value=selected;
  field('baseline').replaceChildren(...Array.from(field('version').options,option=>option.cloneNode(true)));
  const prior=records.find(row=>String(row.id)===field('version').value)?.previous_id;
  if(prior&&records.some(row=>row.id===prior))field('baseline').value=prior;
  compare();
  buttons();
 }
 function valid(token,who){return token===session&&who===actor()&&manager()&&dlg.open&&editorActor===who}
 async function run(action){
  if(!manager()||busy)return;
  const who=actor(),token=session;busy=true;buttons();
  try{await action(token,who)}catch(e){if(valid(token,who))status.textContent=e.message}
  finally{if(valid(token,who)){busy=false;buttons()}}
 }
 function open(){
  if(!manager()||dlg.open)return;editorActor=actor();session++;form.reset();setStyle({});resetCards(null);records=[];field('version').replaceChildren();field('baseline').replaceChildren();field('accounts').replaceChildren();compare();status.textContent='';field('branch').replaceChildren(new Option('كل الفروع',''),...(data.branches||[]).map(b=>new Option(b.name,b.id)));initScopeComparison();redraw();dlg.showModal();redraw();void run(async token=>{await refreshCatalog(token);await history(token)});
 }
 for(const width of [320,360,390,430,768,1024,1440]){
  field('viewport').add(new Option(String(width),String(width),width===390,width===390));
 }
 for(const [k,label] of Object.entries(roles))field('role').add(new Option(label,k));
 packs.forEach(({code,name})=>field('pack').add(new Option(code+' · '+name,code)));
 form.oninput=redraw;form.addEventListener('change',redraw);field('baseline').onchange=compare;field('version').onchange=()=>{field('accounts').replaceChildren();dlg.querySelector('[data-release-impact]').textContent='';buttons();compare()};
 form.onsubmit=e=>{e.preventDefault();void run(async(token,who)=>{
  const id=await rpc('ff_a07_named_design',{p_screen:field('screen').value,p_style:readStyle(),p_cards:['all','dashboard'].includes(field('screen').value)&&!inherit.checked?copyCards(cards):null,p_name:field('draftName').value,p_description:field('description').value,p_role:field('role').value,p_branch:field('branch').value||null,p_device:field('device').value,p_pack:field('pack').value,p_text:field('caption').value,p_bar:field('bar').value});
  if(valid(token,who)){await history(token,id);if(valid(token,who))status.textContent='حُفظت المسودة رقم '+id}
 })};
 const selected=()=>records.find(r=>String(r.id)===field('version').value);
 dlg.querySelector('[data-release-check]').onclick=()=>void run(async(token,who)=>{const row=selected();if(row)await releaseImpact(row,token,who)});
 dlg.querySelector('[data-accounts]').onclick=()=>void run(async(token,who)=>{
  const row=selected();if(!row||row.published_at)return;
  const info=await releaseImpact(row,token,who);if(!info||!info.trial_allowed)return;
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
   if(hours){const info=await releaseImpact(row,token,who);if(!info)return;if(!info.trial_allowed)throw Error('المسودة غير صالحة للتجربة');if(!accounts.every(id=>info.targets.some(a=>a.account_id===id)))throw Error('تغيرت قائمة الحسابات المؤهلة');}
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
  const scopeLabel=['screen','role','branch','device'].map(name=>field(name).selectedOptions[0]?.textContent).join(' · ');
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
  const info=await releaseImpact(row,token,who);if(!info)return;if(!info.valid)throw Error('راجع المسودة؛ تعذر اعتماد النشر');
   if(!confirm(releaseSummary(info)+'\n'+'نشر الإصدار '+row.id+' للحزمة '+row.pack+'؟\n'+[field('screen'),field('role'),field('branch'),field('device')].map(s=>s.selectedOptions[0]?.textContent).join(' · ')))return;
  await rpc('ff_ui_publish',{p_id:row.id});
  if(valid(token,who)){await history(token,row.id);if(valid(token,who)){if(!records.some(v=>v.id===row.id&&v.published_at))throw Error('لم يثبت نشر الإصدار في السجل');status.textContent='نُشر الإصدار رقم '+row.id;sourceRefresh(true);void sync(true)}}
 });
 dlg.querySelector('[data-close]').onclick=()=>dlg.close();dlg.onclose=()=>{if(dlg.open)return;editorActor='';session++;busy=false;records=[];field('version').replaceChildren();field('baseline').replaceChildren();field('accounts').replaceChildren();dlg.querySelector('[data-release-impact]').textContent='';compare();form.reset();setStyle({});resetCards(null);status.textContent='';clearScopeComparison();clearSource()};
 window.addEventListener('ff-luxe-session-reset',reset);
 document.getElementById('ffx-branch').addEventListener('change',()=>sync(true));
 matchMedia('(max-width:850px)').addEventListener('change',()=>sync(true));
 window.ffDashboardStudio={open,sync};
 setInterval(()=>{void sync()},3000);
})();
