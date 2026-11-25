/* A09: explicit stable content keys, bounded safe formatting and authorized templates. */
(()=>{
'use strict';
const targets={
 "orders.field.branch":"#serviceOnly label[for=\"newBranch\"]",
 "orders.field.phone":"#serviceOnly label[for=\"newPhone\"]",
 "orders.field.area":"#serviceOnly label[for=\"newArea\"]",
 "orders.field.fee":"#serviceOnly label[for=\"newFee\"]",
 "orders.field.notes":"#serviceOnly label[for=\"newNotes\"]",
 "orders.field.customer":"#serviceOnly label[for=\"newCustomerName\"]",
 "orders.field.channel":"#serviceOnly label[for=\"newChannel\"]",
 "orders.field.address":"#serviceOnly label[for=\"newFullAddress\"]",
 "orders.field.items":"#serviceOnly label[for=\"newItems\"]",
 "orders.field.quick":"#serviceOnly label[for=\"ffbQuickInput\"]",
 "orders.title":"#serviceOnly .ff-neworder-workspace > h2",
 "orders.analyzer.title":"#ffbTextPanel > h3",
 "orders.cart.title":"#ffbMenuPanel .ffb-v2-cart > h3",
 "cashier.title":"#cashierView .card > h2",
 "driver.title":"#driverView .card .sectionbar > h2",
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
Object.assign(targets,{
 'catalog.title':"#ff51CatalogPanel .sectionbar h2",
 'customers.title':"#ff51CustomersPanel .sectionbar h2",
 'staff.title':"#staffAdminCard .sectionbar h2",
 'archive.title':"#ff51ArchivePanel .sectionbar h2",
 'ratings.title':"#ff51RatingsPanel .sectionbar h2",
 'cases.title':"#ff41Panel .ff41-header h2",
 'messages.title':"#ff39Panel .sectionbar h2",
 'reservations.title':"#ff49ReservationsPanel .sectionbar h2",
 'system.title':"#ff48DiagnosticsPanel .sectionbar h2",
 'assembly.title':"#ffV12AssemblyWorkspace .sectionbar h2",
 'burger_kitchen.title':"#ffBurgerKitchenWorkspace .ff-burger-head h2",
 'orders.cancel':'[data-cancel-order]','orders.add':'[data-open-addition]','orders.add_late':'[data-ff52-late]',
 'driver.attend':'#clockInBtn','driver.leave':'#clockOutBtn','driver.break':'#ff51BreakBtn',
 'assembly.open':'#ffV12Toggle','assembly.burger':'#ffV12BurgerOpen',
 'burger_kitchen.refresh':'#ffBurgerKitchenRefresh','burger_kitchen.finished':'#ffBurgerViewFinished','burger_kitchen.notifications':'#ffBurgerKitchenNotifications',
 'catalog.item_save':'#ff51ItemSave','catalog.offer_save':'#ff51OfferSave','archive.export':'#ff51ArchiveExport',
 'system.refresh':'#ff48Refresh','system.export':'#ff48Export','dashboard.shortcuts':'#ffA08ShortcutsHeading h3',
 'dashboard.branches':'#ffA08Branches h3','dashboard.activity':'#ffA08Activity h3'
});
const navKeys=['home','new','orders','late','drivers','driver','cashier','reservations','transfer','routes','messages','cases','offers','attendance','burger','cashier_finished','reports','archive','ratings','catalog','customers','changes','team','assembly_admin','applications','application_alerts','branch_policy','staff_link','studio','data_center','security','integrity','access','readiness','qa','diagnostics'];
for(const key of navKeys)targets['nav.'+key]='#ffx-nav button[data-key="'+key+'"] > span:first-of-type,#ffx-mobile-nav button[data-key="'+key+'"] > span:first-of-type,#ffx-shortcuts button[data-a08-action="'+key+'"] > span:first-of-type';
const extraText=new Set(['reports.pdf_title','reports.pdf_note','orders.success','orders.error','notices.new_order']);
const hintTargets={"orders.hint.phone":"#newPhone","orders.hint.area":"#newArea","orders.hint.fee":"#newFee","orders.hint.notes":"#newNotes","orders.hint.menu":"#ffbMenuSearch","orders.hint.search":"#orderSearch"};
const hintOriginals=new WeakMap();
const templates=new Set(['notices.delayed','notices.reminder','notices.order_summary']);
const variableKeys=['order_number','customer_name','driver_name','delivery_fee'];
const officialLink='[فتح النظام](https://delivery.freshfriesz.com/)';
const guides={'orders.guidance':{parent:'#ffbTextPanel',original:'راجع الأصناف والكميات في المعاينة قبل الاعتماد.'},'reports.guidance':{parent:'#ff76Center .r-head',original:'اختر الفترة والأقسام المطلوبة، ثم اضغط إعداد التقرير.'}};
const known=k=>Object.hasOwn(targets,k)||Object.hasOwn(hintTargets,k)||templates.has(k)||Object.hasOwn(guides,k)||extraText.has(k);
function isGuide(k){return Object.hasOwn(guides,k)}
function appendInline(node,line){
 for(const part of line.split(/(\*\*[^*\n]+\*\*|\[فتح النظام\]\(https:\/\/delivery\.freshfriesz\.com\/\))/g)){
  if(part===officialLink){const link=document.createElement('a');link.href='https://delivery.freshfriesz.com/';link.target='_blank';link.rel='noopener noreferrer';link.textContent='فتح النظام';node.append(link);continue}
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
const screens={burger_kitchen:'مطبخ البرجر',system:'النظام والأمان',cashier:'واجهة الكاشير',driver:'واجهة الموصل',notices:'التنبيهات التشغيلية',dashboard:'الرئيسية',reports:'التقارير',orders:'إدخال الطلبات',catalog:'المنيو والعروض',customers:'العملاء',staff:'الموظفون والصلاحيات',cases:'الشكاوى والتظلمات',messages:'الرسائل',archive:'الأرشيف',ratings:'التقييمات',assembly:'نقطة التجميع',reservations:'الحجوزات'};
const roles={all:'كل الأدوار',manager:'المدير العام',supervisor:'المشرف',customer_service:'خدمة العملاء',cashier:'الكاشير',driver:'الموصل',assembly:'نقطة التجميع',burger_kitchen:'مطبخ البرجر'};
const originalTitles={manager:'إدارة ذكية، ورؤية أوضح لكل فرع',driver:'توصيلاتك... بوضوح وسرعة',cashier:'كل طلب في وقته الصحيح',customer_service:'خدمة سريعة، وتجربة عميل أجمل',supervisor:'متابعة دقيقة في كل لحظة'};
const currentRole=()=>typeof ffV12AssemblyActive!=='undefined'&&ffV12AssemblyActive?'assembly':window.ffBurgerActive?.()?'burger_kitchen':typeof data!=='undefined'?data?.role:null;
const actor=()=>typeof user!=='undefined'&&user?.id&&currentRole()?user.id:'';
const manager=()=>!!actor()&&currentRole()==='manager';
const branch=()=>currentRole()==='assembly'?(typeof ffV12AssemblyPayload!=='undefined'?ffV12AssemblyPayload?.branch?.id||null:null):currentRole()==='burger_kitchen'?(window.ffBurgerContentBranch?.()||null):document.querySelector('#ffx-branch')?.value||(data?.branches?.length===1?data.branches[0].id:null);
const originals=new WeakMap();
let values=new Map(),context='',last=0,serial=0,session=0,catalog=[],history=[],busy=false;
const dialog=document.createElement('dialog');dialog.id='ffContentStudio';dialog.dir='rtl';dialog.setAttribute('aria-labelledby','ffContentHeading');
dialog.innerHTML='<div class="sectionbar"><h2 id="ffContentHeading">استوديو المحتوى والمسميات</h2><button type="button" data-content-close>إغلاق</button></div>'+
 '<p>تعديل النصوص المحددة فقط؛ لا تتغير وظائف الأزرار أو الصلاحيات أو قواعد العمل.</p>'+
 '<label>بحث في النصوص<input data-content-search type="search" placeholder="اسم الشاشة أو العنصر"></label><label>تصفية الواجهة<select data-content-screen></select></label>'+
 '<label>العنصر<select data-content-key></select></label><label>الدور<select data-content-role></select></label><label>الفرع<select data-content-branch></select></label>'+
 '<label>النص الجديد<textarea data-content-body maxlength="180" rows="3"></textarea></label>'+
 '<div data-content-tools hidden class="actions"><button type="button" data-content-bold>خط عريض</button><button type="button" data-content-bullet>نقطة قائمة</button><small>تنسيق موثوق فقط؛ الرابط الوحيد المسموح: [فتح النظام](https://delivery.freshfriesz.com/)؛ دون HTML.</small></div>'+
 '<p data-content-vars hidden>المتغيرات المتاحة: {order_number}، {customer_name}، {driver_name}، {delivery_fee} — المعاينة اصطناعية فقط.</p>'+
 '<section class="ff-content-preview"><h3>معاينة قبل / بعد</h3><p>الأصل: <b data-content-original></b></p><p>المسودة: <b data-content-preview></b></p><div data-content-rich-preview hidden></div></section>'+
 '<div class="actions"><button type="button" data-content-save>حفظ مسودة</button><button type="button" data-content-restore>استعادة الأصل كمسودة</button></div>'+
 '<div class="actions"><label>دور الإصدارات<select data-content-history-role></select></label><label>فرع الإصدارات<select data-content-history-branch></select></label></div><label>الإصدارات (أحدث 200 نتيجة في النطاق)<select data-content-history></select></label><p data-content-audit></p>'+
 '<div class="actions"><button type="button" data-content-load>معاينة الإصدار</button><button type="button" data-content-publish>نشر الإصدار المحدد</button></div>'+
 '<p data-content-status role="status" aria-live="polite"></p>';
document.body.append(dialog);
const q=s=>dialog.querySelector('[data-content-'+s+']');
const labelFor=k=>catalog.find(x=>x.key===k);
const selected=()=>history.find(x=>String(x.id)===q('history').value);
function originalText(key,role=data?.role){return key==='dashboard.title'?(originalTitles[role]||(role==='all'?'العنوان الأصلي بحسب الدور':'مساحة العمل الذكية')):(labelFor(key)?.original||'');}
function write(key,value){for(const node of document.querySelectorAll(targets[key]))writeNode(key,node,value)}
const preserveState=new Set(['driver.break','assembly.open','burger_kitchen.finished']);
function writeNode(key,node,value){
 if(value!=null&&!validText(value,key))value=null;
 if(key==='dashboard.title'){
  // paintStatus regenerates the title each cycle, so restore the role-specific source text.
  const fallback=actor()?originalText(key,currentRole()):'التحكم في كل التفاصيل، من شاشة واحدة';
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
  const next=i===0?(preserveState.has(key)?item[1]+' — '+value:' '+value+(key==='assembly.title'?' · ':'')):preserveState.has(key)?item[1]:'';
  if(text.data!==next)text.data=next;
  item[2]=next;
 }
}
function writeHint(key,body){
 const node=document.querySelector(hintTargets[key]);if(!node)return;
 const prior=hintOriginals.get(node),current=node.getAttribute('placeholder');
 if(body==null){if(prior){if(current===prior.applied){if(prior.original===null)node.removeAttribute('placeholder');else node.setAttribute('placeholder',prior.original)}hintOriginals.delete(node)}return}
 if(!validText(body,key))return;
 const original=prior&&current===prior.applied?prior.original:current;
 node.setAttribute('placeholder',body);hintOriginals.set(node,{original,applied:body});
}
function render(){for(const key of Object.keys(targets))write(key,values.get(key)?.body??null);for(const key of navKeys){const b=document.querySelector('#ffx-mobile-nav button[data-key="'+key+'"]');if(b){const label=b.querySelector('span')?.textContent?.trim();if(label){b.setAttribute('aria-label',label);b.title=label}}}for(const key of Object.keys(hintTargets))writeHint(key,values.get(key)?.body??null);for(const key of Object.keys(guides))renderGuide(key,values.get(key)?.body??null)}
function reset(){
 serial++;session++;context='';last=0;values.clear();catalog=[];history=[];busy=false;
 if(dialog.open)dialog.close();for(const name of ['key','history','branch'])q(name).replaceChildren();
 for(const name of ['search','body'])q(name).value='';for(const name of ['status','audit','original','preview','rich-preview'])q(name).textContent='';
 render();
}
async function sync(force=false){
 const who=actor();if(!who){if(context||dialog.open)reset();return}
 const b=branch(),role=currentRole(),key=[who,role,b].join('|');
 if(key!==context){serial++;values.clear();if(dialog.open&&(!manager()||(context&&context.split('|')[0]!==who)))reset();context=key;last=0}
 render();
 if(!force&&Date.now()-last<30000)return;
 last=Date.now();const request=++serial;
 try{
  const rows=await rpc('ff_content_effective',{p_branch:b});
  if(request!==serial||actor()!==who||branch()!==b||currentRole()!==role)return;
  values=new Map((rows||[]).filter(r=>known(r.content_key)&&(r.body===null||typeof r.body==='string'&&validText(r.body,r.content_key))).map(r=>[r.content_key,r]));render();
 }catch{/* Old database or network loss: keep confirmed values within the same account/scope only. */}
}
function validText(s,key){
 if(typeof s!=='string')return false;
 let clean=s;
 if(templates.has(key))for(const variable of variableKeys)clean=clean.replaceAll('{'+variable+'}','');
 else if(isGuide(key))clean=clean.replaceAll('\n','').replaceAll(officialLink,'');
 return !!clean.trim()&&s.length<=(isGuide(key)?1000:180)&&!/[<>{}\u0000-\u001f\u007f-\u009f\u061c\u200e\u200f\u202a-\u202e\u2066-\u2069]/u.test(clean)&&!/(https?:\/\/|www\.|javascript:|data:|vbscript:|\/\/)/i.test(clean);
}
const sampleVars={order_number:'990001 (تجريبي)',customer_name:'عميل تجريبي',driver_name:'موصل تجريبي',delivery_fee:'500'};
function substitute(body,vars){return body.replace(/\{([a-z_]+)\}/g,(_,key)=>Object.hasOwn(vars,key)?String(vars[key]??'—'):'—')}
function preview(){
 const key=q('key').value,original=originalText(key,q('role').value);
 const rich=isGuide(key);q('body').maxLength=rich?1000:180;q('tools').hidden=!rich;q('rich-preview').hidden=!rich;q('preview').parentElement.hidden=rich;
 if(rich){const draft=q('body').value;formatGuide(q('rich-preview'),draft?(validText(draft,key)?draft:'النص غير صالح للمعاينة — أزل الرموز أو الروابط غير المسموح بها.'):'—')}else q('rich-preview').replaceChildren();
 q('vars').hidden=!templates.has(key);
 q('original').textContent=original;
 q('preview').textContent=(templates.has(key)?substitute(q('body').value,sampleVars):q('body').value)||'—';
}
function audit(){
 const row=selected();
 q('audit').textContent=row?('الإصدار #'+row.id+' · '+(row.published_at?'منشور':'مسودة')+' · '+new Date(row.created_at).toLocaleString('ar-YE')+' · محرر: '+row.actor_id+(row.published_by?' · نشر: '+row.published_by:'')):'لا يوجد إصدار محدد';
 q('publish').disabled=busy||!row||!!row.published_at;q('load').disabled=busy||!row;
}
function controls(){
 for(const name of ['search','screen','key','role','branch','body','history','history-role','history-branch','bold','bullet'])q(name).disabled=busy;
 for(const name of ['save','restore'])q(name).disabled=busy||!q('key').value;
 audit();
}
function setKeys(){
 const normalize=s=>String(s).normalize('NFKC').replace(/[َ-ْـ]/g,'').replace(/[أإآ]/g,'ا').trim().toLocaleLowerCase('ar');
 const term=normalize(q('search').value),old=q('key').value,screen=q('screen').value;
 const rows=catalog.filter(x=>(!screen||x.screen===screen)&&normalize([x.key,x.screen,x.label,x.original,screens[x.screen]||x.screen].join(' ')).includes(term));
 q('key').replaceChildren(...rows.map(x=>new Option(x.label+' — '+(screens[x.screen]||x.screen),x.key)));
 if(rows.some(x=>x.key===old))q('key').value=old;
}
async function getHistory(token,selectId){
 const key=q('key').value,who=actor(),role=q('history-role').value,branchFilter=q('history-branch').value;history=[];q('history').replaceChildren();controls();
 if(!key)return;
 const rows=role||branchFilter?await rpc('ff86_content_history_scoped',{p_key:key,p_role:role||null,p_branch:branchFilter==='__global__'?null:branchFilter||null,p_global_branch:branchFilter==='__global__'}):await rpc('ff_content_history',{p_key:key});
 if(token!==session||who!==actor()||!manager()||q('key').value!==key||q('history-role').value!==role||q('history-branch').value!==branchFilter)return;
 history=rows||[];
 q('history').replaceChildren(...history.map(r=>new Option('#'+r.id+' · '+(r.published_at?'منشور':'مسودة')+' · '+roles[r.role_scope]+' · '+(r.branch_id?(data.branches||[]).find(b=>b.id===r.branch_id)?.name||'فرع محدد':'كل الفروع'),String(r.id))));
 if(selectId&&history.some(r=>String(r.id)===String(selectId)))q('history').value=String(selectId);controls();
}
async function run(action){
 if(!manager()||busy)return;const token=session,who=actor();busy=true;controls();
 try{await action(token,who)}catch(e){if(token===session&&who===actor())q('status').textContent=e.message||'تعذر تنفيذ الإجراء'}
 finally{if(token===session&&who===actor()){busy=false;controls()}}
}
async function open(selection={}){
 if(!manager()||dialog.open)return;
 session++;busy=false;catalog=[];history=[];q('search').value='';q('body').value='';q('status').textContent='';q('key').replaceChildren();q('history').replaceChildren();
 q('role').replaceChildren(...Object.entries(roles).map(([k,v])=>new Option(v,k)));
 q('branch').replaceChildren(new Option('كل الفروع',''),...(data.branches||[]).map(b=>new Option(b.name,b.id)));
 q('screen').replaceChildren(new Option('كل الواجهات',''));
 q('history-role').replaceChildren(new Option('جميع نطاقات الأدوار',''),...Object.entries(roles).map(([k,v])=>new Option(v,k)));
 q('history-branch').replaceChildren(new Option('جميع نطاقات الفروع',''),new Option('عام دون فرع','__global__'),...(data.branches||[]).map(b=>new Option(b.name,b.id)));
 dialog.showModal();controls();
 await run(async(token,who)=>{
  const rows=await rpc('ff_content_catalog_list');
  if(token!==session||who!==actor()||!manager())return;
  catalog=(rows||[]).filter(r=>known(r.key));q('screen').replaceChildren(new Option('كل الواجهات',''),...[...new Set(catalog.map(r=>r.screen))].map(k=>new Option(screens[k]||k,k)));setKeys();const chosen=catalog.find(r=>r.key===selection?.key);if(chosen){q('screen').value=chosen.screen;setKeys();q('key').value=chosen.key;if(Object.hasOwn(roles,selection.role))q('role').value=selection.role;if([...q('branch').options].some(o=>o.value===selection.branch))q('branch').value=selection.branch;q('history-role').value=q('role').value;q('history-branch').value=q('branch').value||'__global__'}preview();await getHistory(token);
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
q('screen').onchange=()=>{setKeys();selectKey()};q('history-role').onchange=q('history-branch').onchange=()=>void run(token=>getHistory(token));
q('key').onchange=selectKey;q('role').onchange=preview;q('body').oninput=preview;q('history').onchange=audit;
q('load').onclick=()=>{const row=selected();if(!row)return;q('role').value=row.role_scope;q('branch').value=row.branch_id||'';q('body').value=row.body??originalText(row.content_key,row.role_scope);preview()};
async function draft(restore){
 const key=q('key').value,role=q('role').value,b=q('branch').value||null,body=restore?null:q('body').value.trim();
 if(!key||(!restore&&!validText(body,key))){q('status').textContent='أدخل نصاً آمناً دون رموز برمجية أو روابط غير معتمدة';return}
 await run(async(token,who)=>{
  const id=await rpc('ff_content_create_draft',{p_key:key,p_role:role,p_branch:b,p_body:body});
  if(token!==session||who!==actor())return;
  q('history-role').value=role;q('history-branch').value=b||'__global__';
  await getHistory(token,id);if(token===session&&who===actor())q('status').textContent='حُفظت المسودة #'+id+'؛ لم تُنشر بعد.';
 });
}
q('save').onclick=()=>void draft(false);q('restore').onclick=()=>void draft(true);
q('publish').onclick=()=>void run(async(token,who)=>{
 const row=selected();if(!row||row.published_at)return;
 const scope=roles[row.role_scope]+' · '+(row.branch_id?(data.branches||[]).find(b=>b.id===row.branch_id)?.name||'فرع محدد':'كل الفروع');
 if(!confirm('نشر النص المحدد #'+row.id+'؟\n'+scope+'\n'+(row.body??'استعادة النص الأصلي')))return;
 await rpc('ff_content_publish',{p_id:row.id});
 if(token!==session||who!==actor()||!manager())return;
 await getHistory(token,row.id);if(token===session&&who===actor()){q('status').textContent='تم نشر النص #'+row.id;void sync(true)}
});
q('close').onclick=()=>dialog.close();dialog.onclose=()=>{session++;busy=false;q('rich-preview').replaceChildren();q('body').value=''};
const studio=document.querySelector('#ffStudio form');
if(studio){
 const button=document.createElement('button');button.type='button';button.textContent='استوديو المحتوى والمسميات';button.id='ffContentOpen';
 button.onclick=()=>{if(!manager())return;document.getElementById('ffStudio').close();void open()};studio.prepend(button);
}
window.addEventListener('ff-luxe-session-reset',reset);
function safeValue(v){
 if(v==null)return '—';
 return String(v).replace(/[\u0000-\u001f\u007f-\u009f\u061c\u200e\u200f\u202a-\u202e\u2066-\u2069<>]/gu,'').slice(0,120)||'—';
}
function currentText(key,fallback,orderBranch=branch()){
 if(!actor()||context!==[actor(),currentRole(),branch()].join('|')||(branch()&&orderBranch!==branch()))return fallback;
 const body=values.get(key)?.body;return typeof body==='string'&&validText(body,key)?body:fallback;
}
function notice(key,fallback,number,orderBranch){
 if(!templates.has(key)||!actor()||context!==[actor(),currentRole(),branch()].join('|'))return fallback;
 if(branch()&&orderBranch!==branch())return fallback;
 const body=values.get(key)?.body;if(typeof body!=='string'||!validText(body,key))return fallback;
 const safe=/^\d{1,20}$/.test(String(number??''))?String(number):'—';
 const vars={order_number:safe};
 // Customer/driver/fee values are read only from the already-authorized account snapshot.
 // Only the on-screen summary may include them; notification bodies never include private names or fees.
 if(key==='notices.order_summary'&&safe!=='—'&&orderBranch&&['manager','supervisor','customer_service','cashier','driver'].includes(currentRole())){
  const matches=(Array.isArray(data?.orders)?data.orders:[]).filter(o=>String(o.number)===safe&&o.branch_id===orderBranch);
  if(matches.length===1){
   const o=matches[0];vars.driver_name=safeValue(o.driver_name);
   if(['manager','supervisor','customer_service','cashier'].includes(currentRole()))vars.customer_name=safeValue(o.customer_name);
   if(o.delivery_fee!=null&&Number.isFinite(Number(o.delivery_fee))&&Number(o.delivery_fee)>=0)vars.delivery_fee=String(Number(o.delivery_fee));
  }
 }
 return substitute(body,vars);
}
async function reportText(reportBranch){
 const who=actor(),role=currentRole();if(!who)return {};
 try{
  const rows=await rpc('ff_content_effective',{p_branch:reportBranch||null});
  if(actor()!==who||currentRole()!==role)return {};
  return Object.fromEntries((rows||[]).filter(r=>['reports.pdf_title','reports.pdf_note'].includes(r.content_key)&&typeof r.body==='string'&&validText(r.body,r.content_key)).map(r=>[r.content_key,r.body]));
 }catch{return {}}
}
window.ffContentStudio={sync,open,notice,text:currentText,reportText};
setInterval(()=>{if(actor())void sync()},3000);
})();
