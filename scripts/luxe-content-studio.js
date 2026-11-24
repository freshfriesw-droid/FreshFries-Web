/* DEC-09 phase 1: fixed content keys, safe plain text, server-authorized releases. */
(()=>{
'use strict';
const targets={
 'dashboard.title':'#ffx-hero-title','dashboard.new':'#ffx-hero-new','dashboard.reserve':'#ffx-hero-reserve','dashboard.late':'#ffx-hero-overdue',
 'reports.title':'#ff76Center .r-head h2','reports.subtitle':'#ff76Center .r-head p','reports.run':'#ff76Run',
 'reports.preview':'#ff76Preview','reports.download':'#ff76Download','reports.share':'#ff76Share','reports.csv':'#ff76CSV','reports.close':'#ff76Close',
 'orders.parse':'#ffbApplyText',
 'orders.menu':'#ffbTabMenu',
 'orders.text':'#ffbTabText',
 'orders.refresh':'#ffbMenuReload',
 'orders.save':'#createBtn',
 'catalog.refresh':'#ff51CatalogRefresh',
 'customers.find':'#ff51CustomerFind',
 'customers.note':'#ff51CustomerNoteSave',
 'staff.refresh':'#staffAdminRefresh',
 'staff.permissions':'#permissionLoad',
 'cases.refresh':'#ff41Refresh',
 'messages.refresh':'#ff39Refresh',
 'archive.find':'#ff51ArchiveRefresh',
 'ratings.refresh':'#ff51RatingsRefresh',
 'assembly.refresh':'#ffV12Refresh',
 'reservations.refresh':'#ff49ReservationsRefresh'
};
const templates=new Set(['notices.delayed','notices.reminder']);
const guides={'orders.guidance':{parent:'#ffbTextPanel',original:'راجع الأصناف والكميات في المعاينة قبل الاعتماد.'},'reports.guidance':{parent:'#ff76Center .r-head',original:'اختر الفترة والأقسام المطلوبة، ثم اضغط إعداد التقرير.'}};
const known=k=>Object.hasOwn(targets,k)||templates.has(k)||Object.hasOwn(guides,k);
function isGuide(k){return Object.hasOwn(guides,k)}
function appendInline(node,line){
 for(const part of line.split(/(\*\*[^*\n]+\*\*)/g)){
  if(part.startsWith('**')&&part.endsWith('**')&&part.length>4){const strong=document.createElement('strong');strong.textContent=part.slice(2,-2);node.append(strong)}
  else node.append(document.createTextNode(part));
 }
}
function formatGuide(root,text){
 root.replaceChildren();let list=null;
 for(const line of String(text||'').split('\n')){
  if(!line.trim()){list=null;continue}
  if(line.startsWith('- ')){if(!list){list=document.createElement('ul');root.append(list)}const li=document.createElement('li');appendInline(li,line.slice(2));list.append(li)}
  else{list=null;const p=document.createElement('p');appendInline(p,line);root.append(p)}
 }
}
function renderGuide(key,value){
 const guide=guides[key],parent=document.querySelector(guide.parent);if(!parent)return;
 let node=parent.querySelector('[data-ff-guidance="'+key+'"]');
 if(!node){node=document.createElement('div');node.className='ff-safe-guidance';node.dataset.ffGuidance=key;node.setAttribute('aria-label','إرشادات إضافية');parent.append(node)}
 const body=actor()&&typeof value==='string'&&validText(value,key)?value:guide.original;
 if(node.dataset.source!==body){node.dataset.source=body;formatGuide(node,body)}
}
const screens={notices:'التنبيهات التشغيلية',dashboard:'الرئيسية',reports:'التقارير',orders:'إدخال الطلبات',catalog:'المنيو والعروض',customers:'العملاء',staff:'الموظفون والصلاحيات',cases:'الشكاوى والتظلمات',messages:'الرسائل',archive:'الأرشيف',ratings:'التقييمات',assembly:'نقطة التجميع',reservations:'الحجوزات'};
const roles={all:'كل الأدوار',manager:'المدير العام',supervisor:'المشرف',customer_service:'خدمة العملاء',cashier:'الكاشير',driver:'الموصل',assembly:'نقطة التجميع',burger_kitchen:'مطبخ البرجر'};
const originalTitles={manager:'إدارة ذكية، ورؤية أوضح لكل فرع',driver:'توصيلاتك... بوضوح وسرعة',cashier:'كل طلب في وقته الصحيح',customer_service:'خدمة سريعة، وتجربة عميل أجمل',supervisor:'متابعة دقيقة في كل لحظة'};
const actor=()=>typeof user!=='undefined'&&user?.id&&typeof data!=='undefined'&&data?.role?user.id:'';
const manager=()=>!!actor()&&data.role==='manager';
const branch=()=>document.querySelector('#ffx-branch')?.value||(data?.branches?.length===1?data.branches[0].id:null);
const originals=new WeakMap();
let values=new Map(),context='',last=0,serial=0,session=0,catalog=[],history=[],busy=false;
const dialog=document.createElement('dialog');dialog.id='ffContentStudio';dialog.dir='rtl';dialog.setAttribute('aria-labelledby','ffContentHeading');
dialog.innerHTML='<div class="sectionbar"><h2 id="ffContentHeading">استوديو المحتوى والمسميات</h2><button type="button" data-content-close>إغلاق</button></div>'+
 '<p>تعديل النصوص المحددة فقط؛ لا تتغير وظائف الأزرار أو الصلاحيات أو قواعد العمل.</p>'+
 '<label>بحث في النصوص<input data-content-search type="search" placeholder="اسم الشاشة أو العنصر"></label>'+
 '<label>العنصر<select data-content-key></select></label><label>الدور<select data-content-role></select></label><label>الفرع<select data-content-branch></select></label>'+
 '<label>النص الجديد<textarea data-content-body maxlength="180" rows="3"></textarea></label>'+
 '<div data-content-tools hidden class="actions"><button type="button" data-content-bold>خط عريض</button><button type="button" data-content-bullet>نقطة قائمة</button><small>تنسيق موثوق فقط؛ لا يسمح بالروابط أو HTML.</small></div>'+
 '<p data-content-vars hidden>المتغير المتاح: {order_number} — المعاينة تستخدم رقمًا تجريبيًا فقط.</p>'+
 '<section class="ff-content-preview"><h3>معاينة قبل / بعد</h3><p>الأصل: <b data-content-original></b></p><p>المسودة: <b data-content-preview></b></p><div data-content-rich-preview hidden></div></section>'+
 '<div class="actions"><button type="button" data-content-save>حفظ مسودة</button><button type="button" data-content-restore>استعادة الأصل كمسودة</button></div>'+
 '<label>الإصدارات<select data-content-history></select></label><p data-content-audit></p>'+
 '<div class="actions"><button type="button" data-content-load>معاينة الإصدار</button><button type="button" data-content-publish>نشر الإصدار المحدد</button></div>'+
 '<p data-content-status role="status" aria-live="polite"></p>';
document.body.append(dialog);
const q=s=>dialog.querySelector('[data-content-'+s+']');
const labelFor=k=>catalog.find(x=>x.key===k);
const selected=()=>history.find(x=>String(x.id)===q('history').value);
function originalText(key,role=data?.role){return key==='dashboard.title'?(originalTitles[role]||(role==='all'?'العنوان الأصلي بحسب الدور':'مساحة العمل الذكية')):(labelFor(key)?.original||'');}
function write(key,value){
 const node=document.querySelector(targets[key]);if(!node)return;
 if(key==='dashboard.title'){
  // paintStatus regenerates the title each cycle, so restore the role-specific source text.
  const fallback=actor()?originalText(key,data.role):'التحكم في كل التفاصيل، من شاشة واحدة';
  if(node.textContent!==(value??fallback))node.textContent=value??fallback;
  return;
 }
 // Apply only to live text nodes; never rewrite an operational label that has no override.
 const current=Array.from(node.childNodes).filter(n=>n.nodeType===Node.TEXT_NODE);
 let saved=originals.get(node);
 if(saved&&(!saved.every(([n])=>n.parentNode===node)||current.length!==saved.length)){
  originals.delete(node);saved=undefined;
 }
 if(value==null){
  if(saved){for(const [text,original,applied] of saved){if(text.data===applied)text.data=original}originals.delete(node)}
  return;
 }
 if(!current.length)return;
 if(!saved){saved=current.map(n=>[n,n.data,null]);originals.set(node,saved)}
 for(let i=0;i<saved.length;i++){
  const item=saved[i],text=item[0];
  if(item[2]!==null&&text.data!==item[2])item[1]=text.data;
  const next=i===0?' '+value:'';
  if(text.data!==next)text.data=next;
  item[2]=next;
 }
}
function render(){for(const key of Object.keys(targets))write(key,values.get(key)?.body??null);for(const key of Object.keys(guides))renderGuide(key,values.get(key)?.body??null)}
function reset(){
 serial++;session++;context='';last=0;values.clear();catalog=[];history=[];busy=false;
 if(dialog.open)dialog.close();for(const name of ['key','history','branch'])q(name).replaceChildren();
 for(const name of ['search','body'])q(name).value='';for(const name of ['status','audit','original','preview','rich-preview'])q(name).textContent='';
 render();
}
async function sync(force=false){
 const who=actor();if(!who){if(context||dialog.open)reset();return}
 const b=branch(),role=data.role,key=[who,role,b].join('|');
 if(key!==context){serial++;values.clear();if(dialog.open&&(!manager()||(context&&context.split('|')[0]!==who)))reset();context=key;last=0}
 render();
 if(!force&&Date.now()-last<30000)return;
 last=Date.now();const request=++serial;
 try{
  const rows=await rpc('ff_content_effective',{p_branch:b});
  if(request!==serial||actor()!==who||branch()!==b||data?.role!==role)return;
  values=new Map((rows||[]).filter(r=>known(r.content_key)).map(r=>[r.content_key,r]));render();
 }catch{/* Old database or network loss: keep confirmed values within the same account/scope only. */}
}
function validText(s,key){const clean=templates.has(key)?s.replaceAll('{order_number}',''):isGuide(key)?s.replaceAll('\n',''):s;return !!clean.trim()&&s.length<=(isGuide(key)?1000:180)&&!/[<>{}\u0000-\u001f\u007f-\u009f\u061c\u200e\u200f\u202a-\u202e\u2066-\u2069]/u.test(clean)&&!/(https?:\/\/|www\.|javascript:|data:|vbscript:|\/\/)/i.test(s)}
function preview(){
 const key=q('key').value,original=originalText(key,q('role').value);
 const rich=isGuide(key);q('body').maxLength=rich?1000:180;q('tools').hidden=!rich;q('rich-preview').hidden=!rich;q('preview').parentElement.hidden=rich;
 if(rich)formatGuide(q('rich-preview'),q('body').value||'—');else q('rich-preview').replaceChildren();
 q('vars').hidden=!templates.has(key);
 q('original').textContent=original;
 q('preview').textContent=(templates.has(key)?q('body').value.replaceAll('{order_number}','990001 (تجريبي)'):q('body').value)||'—';
}
function audit(){
 const row=selected();
 q('audit').textContent=row?('الإصدار #'+row.id+' · '+(row.published_at?'منشور':'مسودة')+' · '+new Date(row.created_at).toLocaleString('ar-YE')+' · محرر: '+row.actor_id+(row.published_by?' · نشر: '+row.published_by:'')):'لا يوجد إصدار محدد';
 q('publish').disabled=busy||!row||!!row.published_at;q('load').disabled=busy||!row;
}
function controls(){
 for(const name of ['search','key','role','branch','body','history','bold','bullet'])q(name).disabled=busy;
 for(const name of ['save','restore'])q(name).disabled=busy||!q('key').value;
 audit();
}
function setKeys(){
 const term=q('search').value.trim().toLocaleLowerCase('ar'),old=q('key').value;
 const rows=catalog.filter(x=>[x.key,x.screen,x.label,x.original,screens[x.screen]||x.screen].join(' ').toLocaleLowerCase('ar').includes(term));
 q('key').replaceChildren(...rows.map(x=>new Option(x.label+' — '+(screens[x.screen]||x.screen),x.key)));
 if(rows.some(x=>x.key===old))q('key').value=old;
}
async function getHistory(token,selectId){
 const key=q('key').value;history=[];q('history').replaceChildren();controls();
 if(!key)return;
 const rows=await rpc('ff_content_history',{p_key:key});
 if(token!==session||!manager()||q('key').value!==key)return;
 history=rows||[];
 q('history').replaceChildren(...history.map(r=>new Option('#'+r.id+' · '+(r.published_at?'منشور':'مسودة')+' · '+roles[r.role_scope]+' · '+(r.branch_id?(data.branches||[]).find(b=>b.id===r.branch_id)?.name||'فرع محدد':'كل الفروع'),String(r.id))));
 if(selectId)q('history').value=String(selectId);controls();
}
async function run(action){
 if(!manager()||busy)return;const token=session,who=actor();busy=true;controls();
 try{await action(token,who)}catch(e){if(token===session&&who===actor())q('status').textContent=e.message||'تعذر تنفيذ الإجراء'}
 finally{if(token===session&&who===actor()){busy=false;controls()}}
}
async function open(){
 if(!manager()||dialog.open)return;
 session++;busy=false;catalog=[];history=[];q('search').value='';q('body').value='';q('status').textContent='';q('key').replaceChildren();q('history').replaceChildren();
 q('role').replaceChildren(...Object.entries(roles).map(([k,v])=>new Option(v,k)));
 q('branch').replaceChildren(new Option('كل الفروع',''),...(data.branches||[]).map(b=>new Option(b.name,b.id)));
 dialog.showModal();controls();
 await run(async(token,who)=>{
  const rows=await rpc('ff_content_catalog_list');
  if(token!==session||who!==actor()||!manager())return;
  catalog=(rows||[]).filter(r=>known(r.key));setKeys();preview();await getHistory(token);
 });
}
function selectKey(){q('body').value='';preview();void run(token=>getHistory(token))}
let searchTimer;q('search').oninput=()=>{clearTimeout(searchTimer);const token=session;searchTimer=setTimeout(()=>{if(token!==session||!dialog.open||busy)return;const old=q('key').value;setKeys();if(old!==q('key').value)selectKey();else controls()},220)};
function insertFormat(prefix,suffix){
 const area=q('body');if(busy||!isGuide(q('key').value))return;
 const from=area.selectionStart,to=area.selectionEnd,chosen=area.value.slice(from,to)||'نص';
 const before=area.value.slice(0,from),after=area.value.slice(to);
 const next=before+prefix+chosen+suffix+after;if(next.length>1000)return;
 area.value=next;area.focus();area.setSelectionRange(from+prefix.length,from+prefix.length+chosen.length);preview()
}
q('bold').onclick=()=>insertFormat('**','**');
q('bullet').onclick=()=>insertFormat(q('body').selectionStart===0||q('body').value[q('body').selectionStart-1]==='\n'?'- ':'\n- ','');
q('key').onchange=selectKey;q('role').onchange=preview;q('body').oninput=preview;q('history').onchange=audit;
q('load').onclick=()=>{const row=selected();if(!row)return;q('role').value=row.role_scope;q('branch').value=row.branch_id||'';q('body').value=row.body??originalText(row.content_key,row.role_scope);preview()};
async function draft(restore){
 const key=q('key').value,role=q('role').value,b=q('branch').value||null,body=restore?null:q('body').value.trim();
 if(!key||(!restore&&!validText(body,key))){q('status').textContent='أدخل نصاً عادياً آمناً دون روابط أو رموز برمجية';return}
 await run(async(token,who)=>{
  const id=await rpc('ff_content_create_draft',{p_key:key,p_role:role,p_branch:b,p_body:body});
  if(token!==session||who!==actor())return;
  await getHistory(token,id);if(token===session)q('status').textContent='حُفظت المسودة #'+id+'؛ لم تُنشر بعد.';
 });
}
q('save').onclick=()=>void draft(false);q('restore').onclick=()=>void draft(true);
q('publish').onclick=()=>void run(async(token,who)=>{
 const row=selected();if(!row||row.published_at)return;
 const scope=roles[row.role_scope]+' · '+(row.branch_id?(data.branches||[]).find(b=>b.id===row.branch_id)?.name||'فرع محدد':'كل الفروع');
 if(!confirm('نشر النص المحدد #'+row.id+'؟\n'+scope+'\n'+(row.body??'استعادة النص الأصلي')))return;
 await rpc('ff_content_publish',{p_id:row.id});
 if(token!==session||who!==actor()||!manager())return;
 await getHistory(token,row.id);if(token===session){q('status').textContent='تم نشر النص #'+row.id;void sync(true)}
});
q('close').onclick=()=>dialog.close();dialog.onclose=()=>{session++;busy=false;q('rich-preview').replaceChildren();q('body').value=''};
const studio=document.querySelector('#ffStudio form');
if(studio){
 const button=document.createElement('button');button.type='button';button.textContent='استوديو المحتوى والمسميات';button.id='ffContentOpen';
 button.onclick=()=>{if(!manager())return;document.getElementById('ffStudio').close();void open()};studio.prepend(button);
}
window.addEventListener('ff-luxe-session-reset',reset);
function notice(key,fallback,number,orderBranch){
 if(!templates.has(key)||!actor()||context!==[actor(),data.role,branch()].join('|'))return fallback;
 // Only a number from the already-authorized alert response may be substituted.
 // A branch-selected template must not be used for a notice from another branch.
 if(branch()&&orderBranch!==branch())return fallback;
 const body=values.get(key)?.body;
 if(typeof body!=='string'||!validText(body,key))return fallback;
 const safe=/^\d{1,20}$/.test(String(number??''))?String(number):'—';
 return body.replaceAll('{order_number}',safe);
}
window.ffContentStudio={sync,open,notice};
})();
