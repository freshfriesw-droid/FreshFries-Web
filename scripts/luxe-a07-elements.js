/* A07 safe element editor. Only known elements may be restyled/reordered; no hide/remove or replacement of actions. */
(()=>{
'use strict';
const groups={"reports_actions":{"screen":"reports","keys":["ff76Run","ff76Preview","ff76Download","ff76Share"]},"dashboard_actions":{"screen":"dashboard","keys":["ffx-hero-new","ffx-hero-reserve","ffx-hero-overdue"]},"orders_actions":{"screen":"orders","keys":["createBtn","ffA06DiscardDraft","ffReserveBottom"]},"driver_actions":{"screen":"driver","keys":["ff51BreakBtn","clockInBtn","clockOutBtn"]},"assembly_actions":{"screen":"assembly","keys":["ffV12Toggle","ffV12Refresh","ffV12BurgerOpen","ffV12Logout"]},"burger_actions":{"screen":"burger_kitchen","keys":["ffBurgerKitchenNotifications","ffBurgerViewFinished","ffBurgerKitchenRefresh","ffBurgerKitchenLogout"]},"catalog_actions":{"screen":"catalog","keys":["ff51ItemSave","ff51ItemReset"]},"catalog_offers":{"screen":"catalog","keys":["ff51OfferSave","ff51OfferReset"]},"archive_actions":{"screen":"archive","keys":["ff51ArchiveRefresh","ff51ArchiveExport","ff51ArchiveClose"]},"ratings_actions":{"screen":"ratings","keys":["ff51RatingsRefresh","ff51RatingsClose"]},"reservations_actions":{"screen":"reservations","keys":["ff49ReservationsRefresh","ff49ReservationsClose"]},"cases_actions":{"screen":"cases","keys":["ff41Refresh","ff41Close"]},"messages_actions":{"screen":"messages","keys":["ff39Refresh","ff39Close"]},"system_actions":{"screen":"system","keys":["ff48Refresh","ff48Export","ff48Close"]},"driver_regions":{"screen":"driver","keys":["clockInBtn","driverOffers","driverTasks"]},"assembly_stats":{"screen":"assembly","keys":["ffV12CountAll","ffV12CountPrinted","ffV12CountPreparing","ffV12CountReady"]},"cashier_stage":{"screen":"cashier","keys":["cashier_stage"]},"staff_actions":{"screen":"staff","keys":["staffAuditRefresh"]},"customers_actions":{"screen":"customers","keys":["ff51CustomerFind","ff51CustomerNoteSave"]}};
Object.assign(groups,{"dashboard_regions":{"screen":"dashboard","keys":["ffx-hero-title","ffx-hero-sub","ffx-kpis","ffx-shortcuts","ffx-order-list","ffx-overdue"],"styleOnly":true},"order_fields":{"screen":"orders","keys":["newBranch","ffbQuickInput","newPhone","newArea","newFee","newNotes","newCustomerName","newChannel","newFullAddress","ffbMenuSearch","newItems"],"styleOnly":true},"order_tabs":{"screen":"orders","keys":["ffbTabMenu","ffbTabText"],"styleOnly":false},"order_tools":{"screen":"orders","keys":["ffbApplyText","ffbMenuReload"],"styleOnly":true},"cashier_regions":{"screen":"cashier","keys":["cashierOrders"],"styleOnly":true},"assembly_regions":{"screen":"assembly","keys":["ffV12BranchTitle","ffV12AssemblyStatus","ffV12AssemblySummary","ffV12AssemblyOrders"],"styleOnly":true},"catalog_fields":{"screen":"catalog","keys":["ff51CatName","ff51ItemName","ff51ItemPrice","ff51OfferName","ff51OfferPrice"],"styleOnly":true},"catalog_regions":{"screen":"catalog","keys":["ff51CatalogItems","ff51OffersList"],"styleOnly":true},"customer_fields":{"screen":"customers","keys":["ff51CustomerSearch","ff51CustomerNoteText"],"styleOnly":true},"customer_regions":{"screen":"customers","keys":["ff51CustomersList","ff51CustomerHistory","ff51CustomerNotesList"],"styleOnly":true},"report_fields":{"screen":"reports","keys":["ff76From","ff76To","ff76Branch","ff76Driver","ffA10Staff","ffA10Area","ffA10Item","ffA10Status","ff76Mode","ff76Trend"],"styleOnly":true},"report_regions":{"screen":"reports","keys":["ff76Status","ff76Body","ff76ApprovalBox"],"styleOnly":true},"staff_regions":{"screen":"staff","keys":["staffAdminList","staffAuditList"],"styleOnly":true},"archive_fields":{"screen":"archive","keys":["ff51ArchiveFrom","ff51ArchiveTo","ff51ArchiveStatus","ff51ArchiveBranch"],"styleOnly":true},"archive_regions":{"screen":"archive","keys":["ff51ArchiveCount","ff51ArchiveList"],"styleOnly":true},"ratings_regions":{"screen":"ratings","keys":["ff51RatingBranch","ff51RatingsList"],"styleOnly":true},"reservation_fields":{"screen":"reservations","keys":["ff49ReserveBranch","ff49ReserveName","ff49ReservePhone","ff49ReserveNotes","ff49ReservePickup","ff49ReserveItems"],"styleOnly":true},"reservation_regions":{"screen":"reservations","keys":["ff49ReservationsList"],"styleOnly":true},"case_fields":{"screen":"cases","keys":["ff41Kind","ff41Branch","ff41Priority","ff41Subject","ff41Description","ff41FilterKind","ff41FilterStatus"],"styleOnly":true},"case_regions":{"screen":"cases","keys":["ff41CaseList","ff41Detail"],"styleOnly":true},"message_fields":{"screen":"messages","keys":["ff39Title","ff39Role","ff39Branch","ff39Body"],"styleOnly":true},"message_regions":{"screen":"messages","keys":["ff39InboxList","ff39SentLog"],"styleOnly":true},"system_regions":{"screen":"system","keys":["ff48Summary","ff48Rows","ff47Stats","ff47Cases","ff46Summary","ff44Results","ff43Findings"],"styleOnly":true}});
const labels={"reports_actions":"إجراءات مركز التقارير","dashboard_actions":"إجراءات الغلاف","orders_actions":"اعتماد الطلب","driver_actions":"الحضور والاستراحة","assembly_actions":"أزرار التجميع","burger_actions":"أزرار المطبخ","catalog_actions":"إدارة الأصناف","catalog_offers":"إدارة العروض","archive_actions":"إدارة الأرشيف","ratings_actions":"إدارة التقييمات","reservations_actions":"إدارة الحجوزات","cases_actions":"الشكاوى والتظلمات","messages_actions":"الرسائل","system_actions":"التشخيص","driver_regions":"مناطق واجهة الموصل","assembly_stats":"بطاقات مؤشرات التجميع","cashier_stage":"مظهر إجراء المرحلة","staff_actions":"إدارة الموظفين","customers_actions":"أدوات العملاء"};
Object.assign(labels,{"dashboard_regions":"مناطق الرئيسية","order_fields":"حقول الطلب","order_tabs":"تبويبات الإدخال","order_tools":"أدوات الطلب","cashier_regions":"منطقة الطلبات","assembly_regions":"مناطق التجميع","catalog_fields":"حقول المنيو والعروض","catalog_regions":"مناطق المنيو","customer_fields":"حقول العميل","customer_regions":"مناطق العميل","report_fields":"حقول التقرير","report_regions":"مناطق التقرير","staff_regions":"مناطق الموظفين","archive_fields":"مرشحات الأرشيف","archive_regions":"مناطق الأرشيف","ratings_regions":"مناطق التقييمات","reservation_fields":"حقول الحجز","reservation_regions":"مناطق الحجز","case_fields":"حقول البلاغ","case_regions":"مناطق البلاغات","message_fields":"حقول الرسائل","message_regions":"مناطق الرسائل","system_regions":"مناطق الفحص"});
const itemLabels={"ff76Run":"إعداد التقرير","ff76Preview":"معاينة PDF","ff76Download":"تصدير PDF","ff76Share":"مشاركة التقرير","ffx-hero-new":"طلب جديد","ffx-hero-reserve":"حجز للاستلام","ffx-hero-overdue":"الطلبات المتأخرة","createBtn":"اعتماد الطلب","ffA06DiscardDraft":"مسودة فارغة","ffReserveBottom":"حجز للاستلام","ff51BreakBtn":"الاستراحة","clockInBtn":"الحضور","clockOutBtn":"إنهاء الدوام","ffV12Toggle":"فتح التجميع","ffV12Refresh":"تحديث","ffV12BurgerOpen":"أوامر البرجر","ffV12Logout":"تسجيل الخروج","ffBurgerKitchenNotifications":"الإشعارات","ffBurgerViewFinished":"الطلبات المنتهية","ffBurgerKitchenRefresh":"تحديث","ffBurgerKitchenLogout":"تسجيل الخروج","ff51ItemSave":"حفظ الصنف","ff51ItemReset":"إلغاء التعديل","ff51OfferSave":"حفظ العرض","ff51OfferReset":"إلغاء التعديل","ff51ArchiveRefresh":"تحديث","ff51ArchiveExport":"تصدير","ff51ArchiveClose":"إغلاق","ff51RatingsRefresh":"تحديث","ff51RatingsClose":"إغلاق","ff49ReservationsRefresh":"تحديث","ff49ReservationsClose":"إغلاق","ff41Refresh":"تحديث","ff41Close":"إغلاق","ff39Refresh":"تحديث","ff39Close":"إغلاق","ff48Refresh":"تحديث","ff48Export":"تصدير","ff48Close":"إغلاق","driverOffers":"العروض","driverTasks":"الطلبات","ffV12CountAll":"قيد المتابعة","ffV12CountPrinted":"قطع الفاتورة","ffV12CountPreparing":"التحضير","ffV12CountReady":"جاهزة للتسليم","cashier_stage":"إجراء المرحلة الحالية","staffAuditRefresh":"عرض السجل","ff51CustomerFind":"بحث","ff51CustomerNoteSave":"حفظ الملاحظة"};
Object.assign(itemLabels,{"ffx-hero-title":"عنوان الغلاف","ffx-hero-sub":"وصف الغلاف","ffx-kpis":"المؤشرات","ffx-shortcuts":"الاختصارات","ffx-order-list":"ملخص الطلبات","ffx-overdue":"الطلبات المتأخرة","newBranch":"الفرع","ffbQuickInput":"محلل الطلب","newPhone":"هاتف العميل","newArea":"المنطقة","newFee":"أجرة التوصيل","newNotes":"الملاحظات","newCustomerName":"اسم العميل","newChannel":"قناة الطلب","newFullAddress":"العنوان","ffbMenuSearch":"بحث المنيو","newItems":"الأصناف","ffbTabMenu":"المنيو","ffbTabText":"الإدخال النصي","ffbApplyText":"تحليل النص","ffbMenuReload":"تحديث المنيو","cashierOrders":"طلبات الكاشير","ffV12BranchTitle":"عنوان الفرع","ffV12AssemblyStatus":"حالة التجميع","ffV12AssemblySummary":"ملخص التجميع","ffV12AssemblyOrders":"طلبات التجميع","ff51CatName":"الفئة","ff51ItemName":"اسم الصنف","ff51ItemPrice":"سعر الصنف","ff51OfferName":"اسم العرض","ff51OfferPrice":"سعر العرض","ff51CatalogItems":"الأصناف","ff51OffersList":"العروض","ff51CustomerSearch":"بحث","ff51CustomerNoteText":"الملاحظة","ff51CustomersList":"النتائج","ff51CustomerHistory":"السجل","ff51CustomerNotesList":"الملاحظات","ff76From":"من","ff76To":"إلى","ff76Branch":"الفرع","ff76Driver":"الموصل","ffA10Staff":"الموظف","ffA10Area":"المنطقة","ffA10Item":"الصنف","ffA10Status":"الحالة","ff76Mode":"نوع التقرير","ff76Trend":"التجميع","ff76Status":"حالة التقرير","ff76Body":"نتائج التقرير","ff76ApprovalBox":"اعتماد التقرير","staffAdminList":"الموظفون","staffAuditList":"سجل التدقيق","ff51ArchiveFrom":"من","ff51ArchiveTo":"إلى","ff51ArchiveStatus":"الحالة","ff51ArchiveBranch":"الفرع","ff51ArchiveCount":"عدد النتائج","ff51ArchiveList":"النتائج","ff51RatingBranch":"الفرع","ff51RatingsList":"التقييمات","ff49ReserveBranch":"الفرع","ff49ReserveName":"الاسم","ff49ReservePhone":"الهاتف","ff49ReserveNotes":"الملاحظات","ff49ReservePickup":"موعد الاستلام","ff49ReserveItems":"الأصناف","ff49ReservationsList":"الحجوزات","ff41Kind":"النوع","ff41Branch":"الفرع","ff41Priority":"الأولوية","ff41Subject":"الموضوع","ff41Description":"التفاصيل","ff41FilterKind":"مرشح النوع","ff41FilterStatus":"مرشح الحالة","ff41CaseList":"البلاغات","ff41Detail":"التفاصيل","ff39Title":"العنوان","ff39Role":"الدور","ff39Branch":"الفرع","ff39Body":"النص","ff39InboxList":"الوارد","ff39SentLog":"المرسل","ff48Summary":"التشخيص","ff48Rows":"نتائج التشخيص","ff47Stats":"إحصاءات الاختبارات","ff47Cases":"حالات الاختبارات","ff46Summary":"ملخص الجاهزية","ff44Results":"نتائج سلامة البيانات","ff43Findings":"نتائج الأمان"});
const shapes={inherit:'وراثة من النطاق الأعم',pack:'حسب التصميم',square:'مستطيل',round:'مستدير',pill:'كبسولة',outline:'إطار',icon_label:'أيقونة مع النص'};
const sizes={inherit:'وراثة من النطاق الأعم',normal:'عادي',large:'كبير'};
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
   const reorder=sameParent&&!groups[g].styleOnly;
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
   const row=document.createElement('div');row.className='ff-a07-element-row';row.draggable=!groups[g].styleOnly;row.dataset.elementKey=e.key;
   const name=document.createElement('strong');name.textContent=itemLabels[e.key]||e.key;row.append(name);
   row.addEventListener('dragstart',ev=>{ev.dataTransfer.setData('text/plain',String(i));ev.dataTransfer.effectAllowed='move'});
   row.addEventListener('dragover',ev=>ev.preventDefault());
   row.addEventListener('drop',ev=>{ev.preventDefault();const n=Number(ev.dataTransfer.getData('text/plain'));if(!groups[g].styleOnly&&Number.isInteger(n)&&n>=0&&n<rows.length&&n!==i)modify(i,a=>a.splice(i,0,...a.splice(n,1)))});
   for(const [key,opts,label] of [['shape',shapes,'الشكل'],['size',sizes,'الحجم']]){
    const wrap=document.createElement('label');wrap.textContent=label;const input=document.createElement('select');input.setAttribute('aria-label',label+' '+name.textContent);input.replaceChildren(...Object.entries(opts).map(([k,v])=>new Option(v,k)));input.value=e[key];input.onchange=()=>modify(i,a=>a[i][key]=input.value);wrap.append(input);row.append(wrap)
   }
   const advanced=document.createElement('details');advanced.className='ff-step03-properties';const title=document.createElement('summary');title.textContent='خصائص العنصر';advanced.append(title);const info=document.createElement('p');info.className='muted';info.textContent='معرّف ثابت: '+e.key+' · '+(groups[g].styleOnly?'مظهر فقط؛ لا يغيّر موقع الحقل أو صلاحياته.':'عنصر موجود؛ لا يغيّر التخصيص وظيفته.');advanced.append(info);
   for(const [key,options] of Object.entries(properties)){if(key==='tone'&&!toneAllowed.has(e.key))continue;const wrap=document.createElement('label');wrap.textContent=propertyLabels[key];const input=document.createElement('select');input.dataset.step03Property=key;input.setAttribute('aria-label',propertyLabels[key]+' '+name.textContent);input.add(new Option('وراثة من التصميم',''));for(const [k,v] of Object.entries(options))input.add(new Option(v,k));input.value=e[key]||'';input.onchange=()=>{modify(i,a=>{if(input.value)a[i][key]=input.value;else delete a[i][key]});list.querySelectorAll('.ff-step03-properties')[i]?.setAttribute('open','')};wrap.append(input);advanced.append(wrap)}row.append(advanced);
   if(!groups[g].styleOnly)for(const [label,d] of [['تقديم',-1],['تأخير',1]]){const b=document.createElement('button');b.type='button';b.textContent=label;b.disabled=i+d<0||i+d>=rows.length;b.onclick=()=>modify(i,a=>a.splice(i+d,0,...a.splice(i,1)));row.append(b)}
   list.append(row);
  })
 }
 select.onchange=render;form.elements.screen.addEventListener('change',options);
 section.querySelector('[data-a07-undo]').onclick=()=>{if(state.undo.length){state.redo.push(copy(state.values));state.values=state.undo.pop();render();notify()}};
 section.querySelector('[data-a07-redo]').onclick=()=>{if(state.redo.length){state.undo.push(copy(state.values));state.values=state.redo.pop();render();notify()}};
 section.querySelector('[data-a07-reset]').onclick=()=>change(()=>delete state.values[select.value]);
 state.options=options;state.selectPreview=(g,key)=>{if(!applicable().some(([k])=>k===g))return;section.open=true;select.value=g;render();const row=[...list.children].find(n=>n.dataset.elementKey===key);if(row){const d=row.querySelector('.ff-step03-properties');d.open=true;d.querySelector('summary').focus();row.scrollIntoView({block:'nearest'})}};options();
}
function read(form){const state=states.get(form),screen=form.elements.screen.value;return Object.fromEntries(Object.entries(state?.values||{}).filter(([g])=>screen==='all'||groups[g]?.screen===screen))}
function set(form,v){const state=states.get(form);if(!state)return;state.values=copy(v);state.undo=[];state.redo=[];state.options()}
function preview(root,screen,v,select){
 for(const group of Object.keys(groups).filter(g=>groups[g].screen===screen)){
  const box=document.createElement('section');box.className='ff-step03-preview-group';
  const heading=document.createElement('h4');heading.textContent=labels[group];box.append(heading);
  const items=document.createElement('div');items.className='ff-a07-preview-actions';box.append(items);
  for(const e of v?.[group]||defaultRows(group)){const n=document.createElement(select?'button':'span');if(select){n.type='button';n.dataset.step03Preview=e.key;n.setAttribute('aria-label','تحرير '+(itemLabels[e.key]||e.key));n.onclick=()=>select(group,e.key)}n.className='ff-a07-demo-action';n.textContent=itemLabels[e.key]||e.key;shape(n,e);items.append(n)}
  root.append(box);
 }
}
function selectPreview(form,group,key){states.get(form)?.selectPreview(group,key)}
window.ffA07Elements={editor,read,set,refresh,preview,selectPreview,groups,labels,itemLabels,shapes,sizes,properties,propertyLabels,toneAllowed,defaultRows};
})();
