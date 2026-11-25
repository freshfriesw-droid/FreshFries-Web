/* A09: narrow content/design delegation. No permission changes to operational actions. */
(()=>{
'use strict';
const role=()=>typeof ffV12AssemblyActive!=='undefined'&&ffV12AssemblyActive?'assembly':window.ffBurgerActive?.()?'burger_kitchen':typeof data!=='undefined'?data?.role:null;
const actor=()=>typeof user!=='undefined'&&user?.id&&role()?user.id:'';
const manager=()=>!!actor()&&role()==='manager';
const capLabels={view:'مشاهدة',edit:'تحرير المسودة',preview:'معاينة',review:'مراجعة'};
const screens={cashier:'الكاشير',driver:'الموصل',burger_kitchen:'مطبخ البرجر',system:'النظام والأمان',notices:'التنبيهات التشغيلية',dashboard:'الرئيسية',reports:'التقارير',orders:'إدخال الطلبات',catalog:'المنيو والعروض',customers:'العملاء',staff:'الموظفون والصلاحيات',cases:'الشكاوى والتظلمات',messages:'الرسائل',archive:'الأرشيف',ratings:'التقييمات',assembly:'نقطة التجميع',reservations:'الحجوزات'};
const kinds={text:'النصوص',colors:'الألوان والحدود',buttons:'الأزرار والأيقونات',layout:'التخطيط والكثافة'};
const tokenKinds={colors:['accent','surface','border','shadow'],buttons:['button','iconSize'],layout:['layout','density','radius','scale','font','weight','logoSize','logoAlign']};
const roles={manager:'المدير العام',supervisor:'المشرف',customer_service:'خدمة العملاء',cashier:'الكاشير',driver:'الموصل',assembly:'نقطة التجميع',burger_kitchen:'مطبخ البرجر'};
const dialog=document.createElement('dialog');dialog.id='ff82Delegation';dialog.dir='rtl';dialog.setAttribute('aria-labelledby','ff82Title');
dialog.innerHTML='<div class="sectionbar"><h2 id="ff82Title">التفويض المتدرج للمحتوى</h2><button type="button" data-d-close>إغلاق</button></div><p>تفويض محدود بالنطاق ونوع التعديل والمدة؛ لا يمنح صلاحية تشغيلية أو نشر نهائي.</p>'+
 '<section data-d-manager hidden><label>الحساب والفرع<select data-d-account></select></label><label>الواجهة<select data-d-screen></select></label><fieldset><legend>صلاحيات التفويض</legend><div data-d-caps></div></fieldset><fieldset><legend>أنواع التعديل</legend><div data-d-kinds></div></fieldset>'+
 '<label>وقت البدء<input type="datetime-local" data-d-start></label><label>وقت الانتهاء<input type="datetime-local" data-d-end></label>'+
 '<p>إنشاء تفويض جديد للحساب يلغي التفويض السابق؛ لا تتراكم الصلاحيات.</p><button type="button" data-d-grant>اعتماد التفويض</button>'+
 '<label>سجل التفويضات<select data-d-grants></select></label><button type="button" data-d-revoke>إلغاء التفويض المحدد</button>'+
 '<details><summary>سجل التدقيق</summary><div data-d-audit></div></details><details><summary>مراجعات مسودة محتوى</summary><label>رقم المسودة<input type="number" min="1" data-d-revision></label><button type="button" data-d-read-reviews>عرض المراجعات</button><div data-d-reviews></div></details></section>'+
 '<section data-d-worker hidden><p data-d-scope></p><section data-d-text-section><label>العنصر<select data-d-key></select></label><label>الإصدارات<select data-d-history></select></label><p data-d-body></p>'+
 '<section data-d-preview hidden><h3>معاينة النص</h3><p data-d-original></p><p data-d-sample></p></section>'+
 '<section data-d-edit hidden><label>مسودة نص جديد<textarea data-d-text maxlength="180" rows="3"></textarea></label><p data-d-format-help hidden></p><button type="button" data-d-save>حفظ مسودة للمدير</button></section>'+
 '<section data-d-review hidden><label>ملاحظة المراجعة<textarea data-d-note maxlength="500" rows="3"></textarea></label><button type="button" data-d-send-review>رفع المراجعة إلى المدير</button></section></section><section data-d-design hidden><h3>مسودات التصميم المفوضة</h3><label>الجهاز<select data-d-device><option value="mobile">الجوال</option><option value="desktop">الكمبيوتر</option><option value="all">كل الأجهزة</option></select></label><label>الإصدار<select data-d-design-history></select></label><p data-d-design-info></p><p data-d-design-diff></p><section data-d-design-edit hidden><label>اسم المسودة<input data-d-design-name maxlength="80"></label><div data-d-style-fields></div><div data-d-element-fields></div><label><input type="checkbox" data-d-design-base> متابعة تعديل مسودة محددة أنشأتها ضمن التفويض الحالي</label><button type="button" data-d-design-save>حفظ مسودة التصميم للمدير</button></section><section data-d-design-preview hidden><h4>معاينة اصطناعية قبل / بعد</h4><div class="ff-a07-compare-grid"><div data-d-design-before></div><div data-d-design-after></div></div></section><section data-d-design-review hidden><label>ملاحظة مراجعة التصميم<textarea data-d-design-note maxlength="500"></textarea></label><button type="button" data-d-design-send>رفع المراجعة إلى المدير</button></section></section></section>'+
 '<p data-d-status role="status" aria-live="polite"></p>';
document.body.append(dialog);
const q=n=>dialog.querySelector('[data-d-'+n+']');
const button=document.createElement('button');button.type='button';button.id='ff82Open';button.className='ffx-outline-light';button.textContent='التفويض المتدرج';button.hidden=true;
function mountButton(){const host=role()==='assembly'?document.getElementById('ffV12AssemblyWorkspace'):role()==='burger_kitchen'?document.getElementById('ffBurgerKitchenWorkspace'):document.querySelector('.ffx-hero-actions');if(host&&!host.contains(button))host.append(button)}
mountButton();
let grantChannel=null,grantChannelActor='';
function stopGrantWatch(){if(grantChannel){try{void client?.removeChannel(grantChannel)}catch{}grantChannel=null}grantChannelActor=''}
function watchGrant(who){if(grantChannelActor===who||typeof client==='undefined'||!client?.channel)return;stopGrantWatch();grantChannelActor=who;const invalidate=()=>{if(actor()!==who||manager())return;grant=null;button.hidden=true;invalidateDialog();void sync(true)};try{const cfg={schema:'public',table:'ff_a09_grant_events',filter:'recipient=eq.'+who};grantChannel=client.channel('ff-a09-grant-'+who).on('postgres_changes',{...cfg,event:'INSERT'},invalidate).on('postgres_changes',{...cfg,event:'UPDATE'},invalidate).subscribe()}catch{stopGrantWatch()}}
let grant=null,context='',last=0,request=0,session=0,busy=false,accounts=[],grants=[],catalog=[],history=[],designHistory=[],designContext=null,elementPatch={};
const hasKind=k=>!!grant&&(grant.edit_kinds||['text']).includes(k);
const hasDesign=()=>Object.keys(tokenKinds).some(hasKind);
function enabled(cap){return !!grant&&grant.capabilities.includes(cap)&&Date.parse(grant.starts_at)<=Date.now()&&Date.parse(grant.ends_at)>Date.now()}
function status(s){q('status').textContent=s}
function lines(node,items){node.replaceChildren(...items.map(s=>{const p=document.createElement('p');p.textContent=s;return p}))}
function grantWindow(g){
 const now=Date.now();
 const state=g.revoked_at?'ملغى':now<Date.parse(g.starts_at)?'مجدول':now>=Date.parse(g.ends_at)?'منتهي':'ضمن المدة';
 const format=t=>new Date(t).toLocaleString('ar-YE');
 return state+' · من '+format(g.starts_at)+' إلى '+format(g.ends_at);
}
function localDate(t){const d=new Date(t);d.setMinutes(d.getMinutes()-d.getTimezoneOffset());return d.toISOString().slice(0,16)}
function options(el,items){el.replaceChildren(...items.map(([value,label])=>new Option(label,String(value))))}
function clear(){stopGrantWatch();clearDesign();request++;session++;grant=null;context='';last=0;busy=false;accounts=[];grants=[];catalog=[];history=[];button.hidden=true;if(dialog.open)dialog.close();for(const n of ['account','grants','key','history'])q(n).replaceChildren();for(const n of ['audit','reviews','body','scope','original','sample','status'])q(n).textContent='';for(const n of ['text','note','revision'])q(n).value=''}
function key(){return actor()+'|'+(role()||'')}
async function sync(force=false){
 const who=actor();if(!who){if(context)clear();return}
 const k=key();if(k!==context){clear();context=k}mountButton();
 if(manager()){stopGrantWatch();button.hidden=false;return}
 watchGrant(who);
 if(grant&&!enabled(grant.capabilities[0])){grant=null;button.hidden=true;invalidateDialog()}
 if(!force&&Date.now()-last<5000)return;
 last=Date.now();const seq=++request;
 try{const rows=await rpc('ff82_my_grant');if(seq!==request||key()!==k)return;const next=rows?.[0]||null;const changed=grant?.id!==next?.id;grant=next&&next.role_scope===role()?next:null;button.hidden=!grant;if(dialog.open&&(!grant||changed))invalidateDialog()}
 catch{if(seq===request&&key()===k){grant=null;button.hidden=true;invalidateDialog()}}
}
function guard(token,who){return dialog.open&&token===session&&who===actor()&&context===key()}
function controls(){for(const el of dialog.querySelectorAll('button:not([data-d-close]),input,select,textarea'))el.disabled=busy;if(!busy&&hasDesign()&&dialog.open&&!q('design').hidden){const row=designSelected();q('design-base').disabled=!row||!!row.published_at||row.actor_id!==actor();renderElements()}}
async function run(fn){if(busy||!actor())return;const token=session,who=actor();busy=true;controls();try{await fn(token,who)}catch(e){if(guard(token,who))status(e.message||'تعذر تنفيذ الإجراء')}finally{if(guard(token,who)){busy=false;controls()}}}
for(const [kind,label] of Object.entries(kinds)){const box=document.createElement('label'),input=document.createElement('input');input.type='checkbox';input.value=kind;input.checked=kind==='text';box.append(input,document.createTextNode(label));q('kinds').append(box)}
for(const [cap,label] of Object.entries(capLabels)){const box=document.createElement('label'),input=document.createElement('input');input.type='checkbox';input.value=cap;input.checked=cap==='view';box.append(input,document.createTextNode(label));q('caps').append(box)}
options(q('screen'),Object.entries(screens));
async function managerRefresh(token,who){
 const [a,g,audit]=await Promise.all([rpc('ff82_manager_accounts'),rpc('ff82_manager_grants'),rpc('ff82_manager_audit')]);
 if(!guard(token,who)||!manager())return;
 accounts=a||[];grants=g||[];
 options(q('account'),accounts.map((x,i)=>[i,x.display_name+' · '+(roles[x.role]||x.role)+' · '+x.branch_name]));
 options(q('grants'),grants.map(x=>[x.id,'#'+x.id+' · '+(accounts.find(a=>a.user_id===x.recipient&&a.branch_id===x.branch_id)?.display_name||x.recipient)+' · '+(screens[x.screen]||x.screen)+' · '+(x.edit_kinds||['text']).map(k=>kinds[k]||k).join('/')+' · '+grantWindow(x)]));
 lines(q('audit'),(audit||[]).map(x=>'#'+x.id+' · '+new Date(x.created_at).toLocaleString('ar-YE')+' · '+x.action+' · '+x.outcome+' · '+x.reason+(x.design_revision?' · تصميم #'+x.design_revision:'')+(x.attempted_revision!=null?' · الإصدار المطلوب #'+x.attempted_revision:'')+(x.effect==='no_change'?' · الأثر: لم يتغير أي إصدار أو تفويض':x.effect?' · الأثر: '+x.effect:'')+' · '+x.actor_id));
}
function selection(){return history.find(x=>String(x.id)===q('history').value)}
function preview(){
 const row=selection(),c=catalog.find(x=>x.key===q('key').value),rich=['orders.guidance','reports.guidance'].includes(c?.key),notice=['notices.delayed','notices.reminder','notices.order_summary'].includes(c?.key);
 q('text').maxLength=rich?1000:180;
 q('format-help').hidden=!(rich||notice);
 q('format-help').textContent=rich?'يمكن استخدام **خط عريض** وسطور قائمة تبدأ بشرطة. تُراجع المسودة قبل النشر.':notice?'المتغيرات: {order_number}، {customer_name}، {driver_name}، {delivery_fee}. المعاينة اصطناعية.':'';
 q('body').textContent=row?'#'+row.id+' · '+(row.published_at?'منشور':'مسودة')+' · '+(row.body??'النص الأصلي'):'لا توجد إصدارات ضمن نطاقك';
 q('original').textContent=c?.original||'';
 const sample=q('text').value||row?.body||c?.original||'—';
 q('sample').textContent=notice?sample.replaceAll('{order_number}','990001 (تجريبي)').replaceAll('{customer_name}','عميل تجريبي').replaceAll('{driver_name}','موصل تجريبي').replaceAll('{delivery_fee}','500'):sample;
}
async function loadHistory(token,who){const k=q('key').value;history=[];options(q('history'),[]);if(k){const rows=await rpc('ff82_delegate_history',{p_key:k});if(!guard(token,who)||q('key').value!==k)return;history=rows||[];options(q('history'),history.map(r=>[r.id,'#'+r.id+' · '+(r.published_at?'منشور':'مسودة')]))}preview()}
async function workerRefresh(token,who){
 const rows=await rpc('ff82_my_grant');if(!guard(token,who))return;grant=rows?.[0]?.role_scope===role()?rows[0]:null;
 if(!grant){button.hidden=true;invalidateDialog();return}
 q('scope').textContent=(roles[grant.role_scope]||grant.role_scope)+' · '+(data?.branches?.find(b=>b.id===grant.branch_id)?.name||grant.branch_id)+' · '+(screens[grant.screen]||grant.screen)+' · ينتهي '+new Date(grant.ends_at).toLocaleString('ar-YE');
 q('edit').hidden=!enabled('edit');q('review').hidden=!enabled('review');q('preview').hidden=!enabled('preview');
 q('text-section').hidden=!hasKind('text');q('design').hidden=!hasDesign();
 if(hasDesign()){await loadDesignHistory(token,who);if(!guard(token,who))return}
 if(!hasKind('text'))return;
 const items=await rpc('ff82_delegate_catalog');if(!guard(token,who))return;catalog=items||[];options(q('key'),catalog.map(c=>[c.key,c.label]));await loadHistory(token,who)
}
button.onclick=()=>{if(!actor()||context!==key()||(!manager()&&(!grant||!enabled(grant.capabilities[0]))))return;session++;status('');q('manager').hidden=!manager();q('worker').hidden=manager();q('start').value=localDate(Date.now());q('end').value=localDate(Date.now()+3600000);dialog.showModal();void run(manager()?managerRefresh:workerRefresh)};
q('grant').onclick=()=>void run(async(token,who)=>{if(!manager())return;const a=accounts[Number(q('account').value)],caps=Array.from(q('caps').querySelectorAll('input:checked'),x=>x.value),start=new Date(q('start').value),end=new Date(q('end').value);if(!q('account').value||!a||!caps.length||!Number.isFinite(+start)||!Number.isFinite(+end)||end<=start||end<=new Date()){status('تحقق من الحساب والصلاحيات ووقت البدء والانتهاء');return}if(!confirm('اعتماد التفويض لهذا الحساب وإلغاء تفويضه السابق؟'))return;const types=Array.from(q('kinds').querySelectorAll('input:checked'),x=>x.value);if(!types.length){status('حدد نوع التعديل');return}const args={p_recipient:a.user_id,p_branch:a.branch_id,p_screen:q('screen').value,p_capabilities:caps,p_start:start.toISOString(),p_end:end.toISOString()};const id=await rpc(types.length===1&&types[0]==='text'?'ff82_set_grant':'ff_a09_set_grant',types.length===1&&types[0]==='text'?args:{...args,p_kinds:types});if(guard(token,who)){await managerRefresh(token,who);status('تم اعتماد التفويض #'+id)}});
q('revoke').onclick=()=>void run(async(token,who)=>{if(!manager()||!q('grants').value)return;if(!confirm('إلغاء التفويض المحدد؟'))return;const ok=await rpc('ff82_revoke_grant',{p_id:Number(q('grants').value)});if(guard(token,who)){await managerRefresh(token,who);status(ok?'أُلغي التفويض':'التفويض غير نشط')}});
q('read-reviews').onclick=()=>void run(async(token,who)=>{if(!manager()||!q('revision').value)return;const rows=await rpc('ff82_manager_reviews',{p_revision:Number(q('revision').value)});if(guard(token,who))lines(q('reviews'),(rows||[]).map(x=>x.note+' · '+x.reviewer+' · '+new Date(x.created_at).toLocaleString('ar-YE')))});
q('key').onchange=()=>{q('text').value='';q('note').value='';void run(loadHistory)};q('history').onchange=preview;q('text').oninput=preview;
q('save').onclick=()=>void run(async(token,who)=>{if(!enabled('edit')){status('التفويض غير نشط');return}const result=await rpc('ff82_delegate_draft',{p_key:q('key').value,p_body:q('text').value});if(guard(token,who)){if(result?.ok){q('text').value='';await loadHistory(token,who);status('حُفظت المسودة #'+result.revision+'؛ النشر للمدير فقط')}else status('رفض الخادم التعديل: '+(result?.reason||'غير مصرح'))}});
q('send-review').onclick=()=>void run(async(token,who)=>{if(!enabled('review')||!selection())return;const result=await rpc('ff82_delegate_review',{p_revision:Number(q('history').value),p_note:q('note').value});if(guard(token,who)){if(result?.ok)q('note').value='';status(result?.ok?'تم إرسال المراجعة':'رفض الخادم المراجعة')}});
function clearDesign(){designHistory=[];designContext=null;elementPatch={};q('element-fields').replaceChildren();q('design-history').replaceChildren();q('style-fields').replaceChildren();for(const n of ['design-info','design-diff','design-before','design-after'])q(n).replaceChildren();for(const n of ['design-name','design-note'])q(n).value='';q('design-base').checked=false;q('design').hidden=true}
function invalidateDialog(){clearDesign();session++;busy=false;history=[];catalog=[];accounts=[];grants=[];for(const n of ['account','grants','key','history'])q(n).replaceChildren();for(const n of ['audit','reviews','body','scope','original','sample','status'])q(n).textContent='';for(const n of ['text','note','revision'])q(n).value='';controls();if(dialog.open)dialog.close()}
function designSelected(){return designHistory.find(x=>String(x.id)===q('design-history').value)}
function designPatch(){const patch=Object.fromEntries([...q('style-fields').querySelectorAll('select')].filter(n=>n.value).map(n=>[n.dataset.token,n.value]));if(Object.keys(elementPatch).length)patch.elements=JSON.parse(JSON.stringify(elementPatch));return patch}
function designPreview(){
 const row=designSelected();q('design-info').textContent=row?'#'+row.id+' · '+(row.published_at?'منشور':'مسودة')+' · '+row.pack+' · '+row.draft_name:'لا يوجد إصدار مطابق — معاينة افتراضية';
 q('design-base').disabled=!row||!!row.published_at||row.actor_id!==actor();
 if(q('design-base').disabled)q('design-base').checked=false;
 const source=designContext?.style_config||{},target=row?.style_config||{};const diff=Object.keys({...source,...target}).filter(k=>JSON.stringify(source[k])!==JSON.stringify(target[k]));q('design-diff').textContent=row?'مقارنة الإصدار المحدد بالمظهر الفعّال: '+(diff.map(k=>window.ffA07Design.tokens[k]?.[0]||k).join('، ')||'لا اختلاف في الخصائص المحفوظة'):'';
 if(!enabled('preview'))return;
 const api=window.ffA07Design,selectedBase=q('design-base').checked&&row&&!row.published_at&&row.actor_id===actor(),pack=(selectedBase?row.pack:designContext?.pack)||'D01',base={...(designContext?.style_config||{}),...(selectedBase?row.style_config:{})};
 base.elements={...(designContext?.style_config?.elements||{}),...(selectedBase?row.style_config?.elements||{}:{})};
 q('design-before').replaceChildren(api.demoCard(grant.screen,pack,base));
 const patch=designPatch(),inspect=!Object.keys(patch).length&&row&&!selectedBase;q('design-after').replaceChildren(api.demoCard(grant.screen,inspect?row.pack:pack,inspect?{...base,...row.style_config}:{...base,...patch,elements:{...base.elements,...patch.elements}}));
}
function designFields(){
 q('style-fields').replaceChildren();
 for(const [kind,keys] of Object.entries(tokenKinds))if(hasKind(kind))for(const key of keys){
  const [label,...choices]=window.ffA07Design.tokens[key],wrap=document.createElement('label'),sel=document.createElement('select');wrap.textContent=label;sel.dataset.token=key;sel.add(new Option('دون تغيير',''));for(const [k,v]of choices)sel.add(new Option(v,k));sel.onchange=designPreview;wrap.append(sel);q('style-fields').append(wrap);
 }
}
async function loadDesignHistory(token,who,selected){
 const device=q('device').value,[rows,ctx]=await Promise.all([rpc('ff_a09_design_history',{p_device:device}),rpc('ff_a09_design_context',{p_device:device})]);if(!guard(token,who)||q('device').value!==device||!hasDesign())return;
 designHistory=rows||[];designContext=ctx||null;options(q('design-history'),designHistory.map(r=>[r.id,'#'+r.id+' · '+(r.published_at?'منشور':'مسودة')+' · '+(r.draft_name||r.pack)]));if(selected)q('design-history').value=String(selected);
 q('design-edit').hidden=!enabled('edit');q('design-preview').hidden=!enabled('preview');q('design-review').hidden=!enabled('review');
 designFields();q('design-base').checked=false;resetElements();designPreview();
}
q('device').onchange=()=>void run(loadDesignHistory);q('design-history').onchange=()=>{q('design-base').checked=false;resetElements();designPreview()};
q('design-base').onchange=()=>{resetElements();designPreview()};
function resetElements(){elementPatch={};renderElements()}
function renderElements(){
 const host=q('element-fields');host.replaceChildren();if(!hasKind('buttons')&&!hasKind('layout'))return;
 const api=window.ffA07Elements,row=designSelected(),own=q('design-base').checked&&row&&!row.published_at&&row.actor_id===actor();
 const available=Object.keys(api.groups).filter(k=>api.groups[k].screen===grant.screen);
 for(const group of available){
  const details=document.createElement('details'),title=document.createElement('summary');title.textContent=api.labels[group];details.append(title);details.open=true;
  const initial=(own?row.style_config?.elements?.[group]:null)||designContext?.style_config?.elements?.[group]||api.defaultRows(group);
  const rows=elementPatch[group]||JSON.parse(JSON.stringify(initial));
  const modify=fn=>{const next=JSON.parse(JSON.stringify(rows));fn(next);elementPatch[group]=next;renderElements();designPreview()};
  rows.forEach((e,i)=>{
   const line=document.createElement('div');line.className='ff-a07-element-row';const name=document.createElement('strong');name.textContent=api.itemLabels[e.key]||e.key;line.append(name);
   if(hasKind('buttons'))for(const [key,choices,label]of [['shape',api.shapes,'الشكل'],['size',api.sizes,'الحجم']]){
    const wrap=document.createElement('label'),sel=document.createElement('select');wrap.textContent=label;sel.setAttribute('aria-label',label+' '+name.textContent);Object.entries(choices).forEach(([k,v])=>sel.add(new Option(v,k)));sel.value=e[key];sel.onchange=()=>modify(a=>a[i][key]=sel.value);wrap.append(sel);line.append(wrap);
   }
   if(hasKind('layout'))for(const [label,d]of [['تقديم',-1],['تأخير',1]]){const btn=document.createElement('button');btn.type='button';btn.textContent=label;btn.disabled=i+d<0||i+d>=rows.length;btn.onclick=()=>{if(i+d>=0&&i+d<rows.length)modify(a=>a.splice(i+d,0,...a.splice(i,1)))};line.append(btn)}
   details.append(line);
  });host.append(details);
 }
}
q('design-save').onclick=()=>void run(async(token,who)=>{
 if(!enabled('edit')||!hasDesign())return;
 const result=await rpc('ff_a09_design_draft',{p_device:q('device').value,p_patch:designPatch(),p_name:q('design-name').value,p_base:q('design-base').checked?Number(q('design-history').value):null});
 if(!guard(token,who))return;
 if(result?.ok){await loadDesignHistory(token,who,result.revision);if(guard(token,who))status('حُفظت مسودة التصميم #'+result.revision+'؛ النشر للمدير فقط')}
 else status('رفض الخادم التعديل: '+(result?.reason||'غير مصرح'));
});
q('design-send').onclick=()=>void run(async(token,who)=>{
 if(!enabled('review')||!hasDesign()||!designSelected()||designSelected().published_at)return;
 const result=await rpc('ff_a09_design_review',{p_revision:Number(q('design-history').value),p_note:q('design-note').value});
 if(guard(token,who)){if(result?.ok)q('design-note').value='';status(result?.ok?'تم رفع مراجعة التصميم':'رفض الخادم المراجعة')}
});
q('close').onclick=invalidateDialog;dialog.onclose=()=>{if(!dialog.open)invalidateDialog()};
window.addEventListener('ff-luxe-session-reset',clear);
window.ffContentDelegation={sync};
setInterval(()=>{if(actor()&&!manager())void sync()},1000);
})();
