/* A07 safe element editor. Only known elements may be restyled/reordered; no hide/remove or replacement of actions. */
(()=>{
'use strict';
const groups={"reports_actions":{"screen":"reports","keys":["ff76Run","ff76Preview","ff76Download","ff76Share"]},"dashboard_actions":{"screen":"dashboard","keys":["ffx-hero-new","ffx-hero-reserve","ffx-hero-overdue"]},"orders_actions":{"screen":"orders","keys":["createBtn","ffA06DiscardDraft","ffReserveBottom"]},"driver_actions":{"screen":"driver","keys":["ff51BreakBtn","clockInBtn","clockOutBtn"]},"assembly_actions":{"screen":"assembly","keys":["ffV12Toggle","ffV12Refresh","ffV12BurgerOpen","ffV12Logout"]},"burger_actions":{"screen":"burger_kitchen","keys":["ffBurgerKitchenNotifications","ffBurgerViewFinished","ffBurgerKitchenRefresh","ffBurgerKitchenLogout"]},"catalog_actions":{"screen":"catalog","keys":["ff51ItemSave","ff51ItemReset"]},"catalog_offers":{"screen":"catalog","keys":["ff51OfferSave","ff51OfferReset"]},"archive_actions":{"screen":"archive","keys":["ff51ArchiveRefresh","ff51ArchiveExport","ff51ArchiveClose"]},"ratings_actions":{"screen":"ratings","keys":["ff51RatingsRefresh","ff51RatingsClose"]},"reservations_actions":{"screen":"reservations","keys":["ff49ReservationsRefresh","ff49ReservationsClose"]},"cases_actions":{"screen":"cases","keys":["ff41Refresh","ff41Close"]},"messages_actions":{"screen":"messages","keys":["ff39Refresh","ff39Close"]},"system_actions":{"screen":"system","keys":["ff48Refresh","ff48Export","ff48Close"]},"driver_regions":{"screen":"driver","keys":["clockInBtn","driverOffers","driverTasks"]},"assembly_stats":{"screen":"assembly","keys":["ffV12CountAll","ffV12CountPrinted","ffV12CountPreparing","ffV12CountReady"]},"cashier_stage":{"screen":"cashier","keys":["cashier_stage"]},"staff_actions":{"screen":"staff","keys":["staffAuditRefresh"]},"customers_actions":{"screen":"customers","keys":["ff51CustomerFind","ff51CustomerNoteSave"]}};
const labels={"reports_actions":"إجراءات مركز التقارير","dashboard_actions":"إجراءات الغلاف","orders_actions":"اعتماد الطلب","driver_actions":"الحضور والاستراحة","assembly_actions":"أزرار التجميع","burger_actions":"أزرار المطبخ","catalog_actions":"إدارة الأصناف","catalog_offers":"إدارة العروض","archive_actions":"إدارة الأرشيف","ratings_actions":"إدارة التقييمات","reservations_actions":"إدارة الحجوزات","cases_actions":"الشكاوى والتظلمات","messages_actions":"الرسائل","system_actions":"التشخيص","driver_regions":"مناطق واجهة الموصل","assembly_stats":"بطاقات مؤشرات التجميع","cashier_stage":"مظهر إجراء المرحلة","staff_actions":"إدارة الموظفين","customers_actions":"أدوات العملاء"};
const itemLabels={"ff76Run":"إعداد التقرير","ff76Preview":"معاينة PDF","ff76Download":"تصدير PDF","ff76Share":"مشاركة التقرير","ffx-hero-new":"طلب جديد","ffx-hero-reserve":"حجز للاستلام","ffx-hero-overdue":"الطلبات المتأخرة","createBtn":"اعتماد الطلب","ffA06DiscardDraft":"مسودة فارغة","ffReserveBottom":"حجز للاستلام","ff51BreakBtn":"الاستراحة","clockInBtn":"الحضور","clockOutBtn":"إنهاء الدوام","ffV12Toggle":"فتح التجميع","ffV12Refresh":"تحديث","ffV12BurgerOpen":"أوامر البرجر","ffV12Logout":"تسجيل الخروج","ffBurgerKitchenNotifications":"الإشعارات","ffBurgerViewFinished":"الطلبات المنتهية","ffBurgerKitchenRefresh":"تحديث","ffBurgerKitchenLogout":"تسجيل الخروج","ff51ItemSave":"حفظ الصنف","ff51ItemReset":"إلغاء التعديل","ff51OfferSave":"حفظ العرض","ff51OfferReset":"إلغاء التعديل","ff51ArchiveRefresh":"تحديث","ff51ArchiveExport":"تصدير","ff51ArchiveClose":"إغلاق","ff51RatingsRefresh":"تحديث","ff51RatingsClose":"إغلاق","ff49ReservationsRefresh":"تحديث","ff49ReservationsClose":"إغلاق","ff41Refresh":"تحديث","ff41Close":"إغلاق","ff39Refresh":"تحديث","ff39Close":"إغلاق","ff48Refresh":"تحديث","ff48Export":"تصدير","ff48Close":"إغلاق","driverOffers":"العروض","driverTasks":"الطلبات","ffV12CountAll":"قيد المتابعة","ffV12CountPrinted":"قطع الفاتورة","ffV12CountPreparing":"التحضير","ffV12CountReady":"جاهزة للتسليم","cashier_stage":"إجراء المرحلة الحالية","staffAuditRefresh":"عرض السجل","ff51CustomerFind":"بحث","ff51CustomerNoteSave":"حفظ الملاحظة"};
const shapes={pack:'حسب التصميم',square:'مستطيل',round:'مستدير',pill:'كبسولة',outline:'إطار',icon_label:'أيقونة مع النص'};
const sizes={normal:'عادي',large:'كبير'};
const properties={"font":{"system":"افتراضي الجهاز","tahoma":"Tahoma","serif":"تقليدي"},"weight":{"normal":"عادي","strong":"بارز"},"spacing":{"normal":"عادي","wide":"واسع"},"border":{"thin":"رفيعة","strong":"بارزة"},"shadow":{"none":"بدون","soft":"خفيف"},"tone":{"navy":"كحلي","red":"أحمر","light":"فاتح","dark":"داكن"}},propertyLabels={"font":"الخط","weight":"وزن الخط","spacing":"التباعد","border":"سمك الحدود","shadow":"الظل","tone":"الألوان"},toneAllowed=new Set(["ff76Run","ff76Preview","ff76Download","ff76Share","ffx-hero-new","ffx-hero-reserve","ff51ArchiveRefresh","ff51ArchiveExport","ff51CustomerFind"]);
const copy=v=>JSON.parse(JSON.stringify(v||{}));
const defaultRows=g=>groups[g].keys.map(key=>({key,shape:'pack',size:'normal'}));
const states=new WeakMap();
let owned=new Set(),ownedParents=new Set();
function clearProperties(node){for(const k of Object.keys(properties))delete node.dataset['ffA07El'+k[0].toUpperCase()+k.slice(1)]}
function shape(node,e){node.dataset.ffA07Shape=e.shape;node.dataset.ffA07Size=e.size;clearProperties(node);for(const [k,options] of Object.entries(properties))if(Object.hasOwn(options,e[k]??'')&&(k!=='tone'||toneAllowed.has(e.key)))node.dataset['ffA07El'+k[0].toUpperCase()+k.slice(1)]=e[k]}
function resolve(root,g,key){
 if(key==='cashier_stage')return [...root.querySelectorAll('[data-cashier]')];
 const n=document.getElementById(key);if(!n||!root.contains(n))return [];
 if(g==='driver_regions')return [n.closest('.card')].filter(Boolean);
 if(g==='assembly_stats')return [n.parentElement].filter(Boolean);
 return [n];
}
function refresh(roots,configs){
 const desired=new Map(),parents=new Set();
 for(const root of roots){
  const screen=root.dataset.ffA07Screen,v=configs[screen]?.style_config?.elements||{};
  for(const [g,rows] of Object.entries(v)){
   if(groups[g]?.screen!==screen||!Array.isArray(rows))continue;
   const resolved=rows.map(e=>({e,nodes:resolve(root,g,e.key)}));
   const nodes=resolved.flatMap(x=>x.nodes);
   const parent=nodes[0]?.parentElement;
   const sameParent=!!parent&&nodes.length===rows.length&&nodes.every(n=>n.parentElement===parent);
   const region=g==='driver_regions';
   const reorder=sameParent;
   if(reorder&&region)parents.add(parent);
   resolved.forEach(({e,nodes},i)=>nodes.forEach(n=>{
    const before=desired.get(n)||{};desired.set(n,{...before,...e,order:reorder?i+1:before.order});
   }));
  }
 }
 for(const n of owned)if(!desired.has(n)){delete n.dataset.ffA07Shape;delete n.dataset.ffA07Size;delete n.dataset.ffA07Order;clearProperties(n)}
 for(const n of ownedParents)if(!parents.has(n))delete n.dataset.ffA07RegionGrid;
 for(const n of parents)n.dataset.ffA07RegionGrid='1';
 for(const [n,e] of desired){shape(n,e);if(e.order) n.dataset.ffA07Order=String(e.order);else delete n.dataset.ffA07Order}
 owned=new Set(desired.keys());ownedParents=parents;
}
function editor(form,anchor){
 const section=document.createElement('details');section.id='ffA07Elements';
 section.innerHTML='<summary>ترتيب المناطق والأزرار وخصائص العناصر</summary><p>تغيير مرئي فقط. جميع إجراءات العمل والتحذيرات ثابتة، ولا يمكن حذفها أو إخفاؤها من المحرر.</p><label>مجموعة العناصر<select data-a07-group></select></label><div class="actions"><button type="button" data-a07-undo>تراجع</button><button type="button" data-a07-redo>إعادة</button><button type="button" data-a07-reset>استعادة المجموعة الأصلية</button></div><div data-a07-elements></div>';
 anchor.before(section);
 const select=section.querySelector('[data-a07-group]'),list=section.querySelector('[data-a07-elements]');
 const state={values:{},undo:[],redo:[]};states.set(form,state);
 const applicable=()=>Object.entries(groups).filter(([g,v])=>form.elements.screen.value==='all'||form.elements.screen.value===v.screen);
 function notify(){form.dispatchEvent(new Event('input',{bubbles:true}))}
 function options(){const old=select.value;select.replaceChildren(...applicable().map(([g])=>new Option(labels[g],g)));if([...select.options].some(o=>o.value===old))select.value=old;render()}
 function change(fn){state.undo.push(copy(state.values));state.redo=[];fn();render();notify()}
 function render(){
  list.replaceChildren();const g=select.value;
  section.querySelector('[data-a07-undo]').disabled=!state.undo.length;
  section.querySelector('[data-a07-redo]').disabled=!state.redo.length;
  section.querySelector('[data-a07-reset]').disabled=!g||!state.values[g];
  if(!g){list.textContent='لا توجد مجموعة قابلة لإعادة الترتيب لهذه الشاشة.';return}
  const rows=state.values[g]||defaultRows(g);
  const modify=(i,fn)=>change(()=>{const next=copy(state.values[g]||defaultRows(g));fn(next,i);state.values[g]=next});
  rows.forEach((e,i)=>{
   const row=document.createElement('div');row.className='ff-a07-element-row';row.draggable=true;row.dataset.elementKey=e.key;
   const name=document.createElement('strong');name.textContent=itemLabels[e.key]||e.key;row.append(name);
   row.addEventListener('dragstart',ev=>{ev.dataTransfer.setData('text/plain',String(i));ev.dataTransfer.effectAllowed='move'});
   row.addEventListener('dragover',ev=>ev.preventDefault());
   row.addEventListener('drop',ev=>{ev.preventDefault();const n=Number(ev.dataTransfer.getData('text/plain'));if(Number.isInteger(n)&&n>=0&&n<rows.length&&n!==i)modify(i,a=>a.splice(i,0,...a.splice(n,1)))});
   for(const [key,opts,label] of [['shape',shapes,'الشكل'],['size',sizes,'الحجم']]){
    const wrap=document.createElement('label');wrap.textContent=label;const input=document.createElement('select');input.setAttribute('aria-label',label+' '+name.textContent);input.replaceChildren(...Object.entries(opts).map(([k,v])=>new Option(v,k)));input.value=e[key];input.onchange=()=>modify(i,a=>a[i][key]=input.value);wrap.append(input);row.append(wrap)
   }
   const advanced=document.createElement('details');advanced.className='ff-step03-properties';const title=document.createElement('summary');title.textContent='خصائص العنصر';advanced.append(title);
   for(const [key,options] of Object.entries(properties)){if(key==='tone'&&!toneAllowed.has(e.key))continue;const wrap=document.createElement('label');wrap.textContent=propertyLabels[key];const input=document.createElement('select');input.dataset.step03Property=key;input.setAttribute('aria-label',propertyLabels[key]+' '+name.textContent);input.add(new Option('وراثة من التصميم',''));for(const [k,v] of Object.entries(options))input.add(new Option(v,k));input.value=e[key]||'';input.onchange=()=>{modify(i,a=>{if(input.value)a[i][key]=input.value;else delete a[i][key]});list.querySelectorAll('.ff-step03-properties')[i]?.setAttribute('open','')};wrap.append(input);advanced.append(wrap)}row.append(advanced);
   for(const [label,d] of [['تقديم',-1],['تأخير',1]]){const b=document.createElement('button');b.type='button';b.textContent=label;b.disabled=i+d<0||i+d>=rows.length;b.onclick=()=>modify(i,a=>a.splice(i+d,0,...a.splice(i,1)));row.append(b)}
   list.append(row);
  })
 }
 select.onchange=render;form.elements.screen.addEventListener('change',options);
 section.querySelector('[data-a07-undo]').onclick=()=>{if(state.undo.length){state.redo.push(copy(state.values));state.values=state.undo.pop();render();notify()}};
 section.querySelector('[data-a07-redo]').onclick=()=>{if(state.redo.length){state.undo.push(copy(state.values));state.values=state.redo.pop();render();notify()}};
 section.querySelector('[data-a07-reset]').onclick=()=>change(()=>delete state.values[select.value]);
 state.options=options;options();
}
function read(form){const state=states.get(form),screen=form.elements.screen.value;return Object.fromEntries(Object.entries(state?.values||{}).filter(([g])=>screen==='all'||groups[g]?.screen===screen))}
function set(form,v){const state=states.get(form);if(!state)return;state.values=copy(v);state.undo=[];state.redo=[];state.options()}
function preview(root,screen,v){
 const group=Object.keys(groups).find(g=>groups[g].screen===screen&&!['driver_regions','assembly_stats'].includes(g));if(!group)return;
 const box=document.createElement('div');box.className='ff-a07-preview-actions';
 for(const e of v?.[group]||defaultRows(group)){const n=document.createElement('span');n.className='ff-a07-demo-action';n.textContent=itemLabels[e.key]||e.key;shape(n,e);box.append(n)}
 root.append(box);
}
window.ffA07Elements={editor,read,set,refresh,preview,groups,labels,itemLabels,shapes,sizes,properties,propertyLabels,toneAllowed,defaultRows};
})();
