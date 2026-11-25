/* A07: appearance only. Never recreates operational controls or changes permissions. */
(()=>{
'use strict';
const $=id=>document.getElementById(id);
const screens={
 all:'جميع الشاشات',dashboard:'الرئيسية',orders:'الطلبات وخدمة العملاء',cashier:'الكاشير',driver:'الموصل',
 assembly:'نقطة التجميع',burger_kitchen:'مطبخ البرجر',catalog:'المنيو والعروض',customers:'العملاء',
 reports:'التقارير',staff:'الموظفون والصلاحيات',archive:'الأرشيف',ratings:'التقييمات',cases:'الشكاوى والتظلمات',
 messages:'الرسائل',reservations:'الحجوزات',system:'النظام والأمان'
};
const selectors={
 dashboard:'#ffx-dashboard',orders:'#serviceOnly,#staffOrders',cashier:'#cashierView,#ffBurgerCashierPanel',driver:'#driverView',
 assembly:'#ffV12AssemblyWorkspace',burger_kitchen:'#ffBurgerKitchenWorkspace',
 catalog:'#ff51CatalogPanel',customers:'#ff51CustomersPanel',reports:'#ff76Center',staff:'#staffAdminCard',
 archive:'#ff51ArchivePanel',ratings:'#ff51RatingsPanel',cases:'#ff41Panel,#ff41Dialog',messages:'#ff39Panel,#ff39Dialog',
 reservations:'#ff49ReservationsPanel',system:'#ff48DiagnosticsPanel,#ff47QAPanel,#ff46ReadinessPanel,#ff44IntegrityPanel,#ff43SecurityPanel,#ff62DataCenter'
};
const tokens={
 font:['الخط',['system','الخط المحلي الافتراضي'],['tahoma','Tahoma / Arial'],['cairo','Cairo إن كان مثبتًا'],['noto','Noto Sans Arabic إن كان مثبتًا'],['serif','خط عربي تقليدي']],
 scale:['حجم النص',['normal','عادي'],['large','كبير'],['xlarge','أكبر']],
 weight:['وزن النص',['normal','عادي'],['strong','بارز']],
 density:['كثافة العرض',['normal','عادية'],['compact','مضغوطة'],['spacious','واسعة']],
 radius:['استدارة البطاقات',['pack','حسب الحزمة'],['square','مستطيلة'],['round','دائرية الحواف']],
 button:['شكل الأزرار',['pack','حسب الحزمة'],['square','مستطيل'],['round','مستدير'],['pill','كبسولة']],
 shadow:['ظل البطاقات',['pack','حسب الحزمة'],['none','بدون ظل'],['soft','خفيف']],
 accent:['لون الهوية المساعد',['pack','حسب الحزمة'],['red','أحمر'],['black','أسود'],['navy','كحلي']],
 surface:['لون السطح والتباين',['pack','حسب الحزمة'],['light','فاتح مقروء'],['dark','داكن مقروء']],
 border:['الحدود',['pack','حسب الحزمة'],['thin','رفيعة'],['strong','بارزة']],
 iconSize:['مقاس الأيقونات',['normal','عادي'],['large','كبير']],
 logoSize:['مقاس الشعار',['normal','عادي'],['small','صغير'],['large','كبير']],
 logoAlign:['محاذاة الشعار',['start','البداية'],['center','الوسط'],['end','النهاية']],
 layout:['شبكة البطاقات على الكمبيوتر',['pack','حسب الحزمة'],['single','عمود واحد'],['double','عمودان'],['triple','ثلاثة أعمدة']]
};
const roleScreens={manager:'dashboard',supervisor:'dashboard',customer_service:'orders',cashier:'cashier',driver:'driver',assembly:'assembly',burger_kitchen:'burger_kitchen'};
const packOK=p=>/^D[0-9]{2,}$/.test(p||'');
const cfgOf=v=>v&&typeof v==='object'&&!Array.isArray(v)?v:{};
let current={},owned=new Set();
const LOGO='./assets/ff-official-logo.png',FALLBACK='./assets/ff-icon-192.png';
function imageFallback(img){
 if(img.dataset.ffA07Fallback)return;
 img.dataset.ffA07Fallback='1';
 const fallback=()=>{if(!img.dataset.ffA07Tried){img.dataset.ffA07Tried='1';img.src=FALLBACK}}; img.addEventListener('error',fallback,{once:true});if(img.complete&&!img.naturalWidth)fallback();
}
function addLogo(root,screen){
 if(screen==='dashboard'||screen==='assembly'||root.id==='ffBurgerCashierPanel'||root.id==='staffOrders')return;
 const title=root.querySelector('h2,h3');
 if(!title||title.closest('button')||title.querySelector('.ff-a07-logo-inline'))return;
 const img=document.createElement('img');img.className='ff-a07-logo-inline';img.src=LOGO;img.alt='شعار فريش فرايز';img.loading='lazy';img.width=40;img.height=40;imageFallback(img);
 title.prepend(img);
}
function applyCaption(root,row,screen){
 if(screen==='dashboard'||root.id==='staffOrders')return;
 let node=root.querySelector(':scope > [data-ff-a07-caption]');
 if(!row?.layout_text){node?.remove();return}
 const title=root.querySelector('h2,h3');
 if(!title||title.closest('button'))return;
 if(!node){node=document.createElement('p');node.dataset.ffA07Caption='1';node.className='ff-a07-caption';root.prepend(node)}
 node.textContent=row.layout_text;
}
function resetNode(root){
 for(const k of Object.keys(tokens))delete root.dataset['a07'+k[0].toUpperCase()+k.slice(1)];
 delete root.dataset.ffA07Pack;delete root.dataset.ffA07Revision;
}
function decorate(root,row){
 resetNode(root);if(!row||!packOK(row.pack))return;
 root.dataset.ffA07Pack=row.pack;root.dataset.ffA07Revision=String(row.id??'preview');
 const style=cfgOf(row.style_config);
 for(const [k,[, ...options]] of Object.entries(tokens)){
  if(options.some(o=>o[0]===style[k]))root.dataset['a07'+k[0].toUpperCase()+k.slice(1)]=style[k];
 }
}
function refresh(){
 const seen=new Set();
 for(const [screen,selector] of Object.entries(selectors)){
  for(const root of document.querySelectorAll(selector)){
   if(seen.has(root))continue;seen.add(root);
   root.dataset.ffA07Screen=screen;
   addLogo(root,screen);
   const row=current[screen], signature=JSON.stringify([row?.id,row?.pack,row?.style_config,row?.layout_text]);
   if(root.dataset.ffA07Signature!==signature){decorate(root,row);applyCaption(root,row,screen);root.dataset.ffA07Signature=signature}
  }
 }
 for(const old of owned)if(!seen.has(old)){resetNode(old);delete old.dataset.ffA07Signature;delete old.dataset.ffA07Screen}
 owned=seen;
 window.ffA07Elements?.refresh(seen,current);
 for(const img of document.querySelectorAll('img[src$="/ff-official-logo.png"],img[src$="/ff-icon-192.png"]'))imageFallback(img);
}
function apply(rows){current=cfgOf(rows);refresh()}
function clear(){current={};refresh()}
function selectFields(form){
 const section=document.createElement('details');section.id='ffA07StyleFields';
 const heading=document.createElement('summary');heading.textContent='تخصيص الهوية والمظهر';section.append(heading);
 const grid=document.createElement('div');grid.className='ff-studio-fields';section.append(grid);
 for(const [key,[label,...values]] of Object.entries(tokens)){
  const wrap=document.createElement('label');wrap.textContent=label;const select=document.createElement('select');select.name='a07_'+key;
  for(const [k,v]of values)select.add(new Option(v,k));wrap.append(select);grid.append(wrap);
 }
 const note=document.createElement('p');note.className='muted';note.textContent='الخطوط من الجهاز مع بدائل محلية. لا تغيّر إعدادات المظهر حالات الطلب أو تحذيرات الخطر أو صلاحيات الوصول.';section.append(note);
 form.querySelector('#ffCardEditor').before(section);
 const wrap=document.createElement('label');wrap.textContent='الشاشة';const sel=document.createElement('select');sel.name='screen';for(const [k,v]of Object.entries(screens))sel.add(new Option(v,k,k==='dashboard',k==='dashboard'));
 wrap.append(sel);form.querySelector('.ff-studio-fields').prepend(wrap);
 window.ffA07Elements?.editor(form,form.querySelector('#ffCardEditor'));
 return sel;
}
function readStyle(form){const v=Object.fromEntries(Object.keys(tokens).map(k=>[k,form.elements.namedItem('a07_'+k)?.value]).filter(([k,v])=>tokens[k].slice(1).some(o=>o[0]===v)));const elements=window.ffA07Elements?.read(form);if(elements&&Object.keys(elements).length)v.elements=elements;return v}
function setStyle(form,v){for(const [k,[,...options]] of Object.entries(tokens)){const input=form.elements.namedItem('a07_'+k);if(input)input.value=options.some(x=>x[0]===v?.[k])?v[k]:options[0][0]}window.ffA07Elements?.set(form,v?.elements)}
const demo={
 dashboard:['نظرة عامة','الطلبات اليومية','مؤشرات الفروع','إجراءات سريعة'],
 orders:['طلب جديد','1 تشكن فرايز — ملاحظة تجريبية','معاينة قبل الحفظ','حفظ الطلب'],
 cashier:['الطلبات الواردة','طلب تجريبي 990001','جاهز للتحضير','استلام الطلب'],
 driver:['مهامي الآن','طلب تجريبي 990001','في الطريق','أنا في الموقع'],
 assembly:['طلبات الفرع','طلب تجريبي 990001','قيد التحضير','جاهز للتسليم'],
 burger_kitchen:['أوامر البرجر','طلب تجريبي 990001','قيد التحضير','جاهز'],
 catalog:['المنيو والعروض','تشكن فرايز — مثال','متوفر','إضافة إلى السلة'],
 customers:['العملاء','عميل تجريبي','معلومات مقيدة','عرض السجل'],
 reports:['التقارير','تقرير تجريبي','الفترة والفرع','معاينة التقرير'],
 staff:['الموظفون','حساب تجريبي','طلب انضمام','مراجعة'],
 archive:['الأرشيف','طلب تجريبي منتهٍ','مكتمل','عرض التفاصيل'],
 ratings:['التقييمات','تقييم تجريبي','مراجعة','عرض الملاحظة'],
 cases:['الشكاوى','بلاغ تجريبي','قيد المراجعة','متابعة'],
 messages:['الرسائل','رسالة تجريبية','غير مقروءة','فتح الرسالة'],
 reservations:['الحجوزات','حجز تجريبي','استلام لاحق','مراجعة'],
 system:['أمان النظام','فحص تجريبي','لا تغييرات فعلية','عرض الفحص']
};
function demoCard(screen,pack,style,compact=false){
 const row=demo[screen]||demo.dashboard;
 const root=document.createElement('section');root.className='ff-a07-demo';root.dataset.ffA07Screen=screen;
 decorate(root,{pack,style_config:style,id:'preview'});
 const head=document.createElement('header');head.className='ff-a07-demo-head';const img=document.createElement('img');img.src=LOGO;img.alt='شعار فريش فرايز';img.className='ff-a07-logo-inline';img.width=40;img.height=40;imageFallback(img);
 const h=document.createElement('strong');h.textContent=row[0];head.append(img,h);root.append(head);
 const cards=document.createElement('div');cards.className='ff-a07-demo-grid';
 for(let i=0;i<(compact?2:3);i++){
  const card=document.createElement('article');card.className='ff-a07-demo-card';
  const title=document.createElement('b');title.textContent=i===0?row[1]:i===1?row[2]:'طلب تجريبي 990002';
  const state=document.createElement('span');state.className=i===1?'ff-a07-demo-warning':'ff-a07-demo-state';state.textContent=i===1?'⚠ يحتاج متابعة':'● حالة تجريبية';
  card.append(title,state);
  if(!compact){const action=document.createElement('span');action.className='ff-a07-demo-action';action.textContent=row[3];card.append(action)}
  cards.append(card);
 }
 root.append(cards);
 if(!compact)window.ffA07Elements?.preview(root,screen,style?.elements);
 if(!compact){const danger=document.createElement('span');danger.className='ff-a07-demo-danger';danger.textContent='إلغاء — معاينة فقط';root.append(danger)}
 return root;
}
function gallery(form,packs){
 const details=document.createElement('details');details.id='ffA07Gallery';
 const title=document.createElement('summary');title.textContent='معرض مكتبة التصاميم — اختر للمقارنة';details.append(title);
 const p=document.createElement('p');p.textContent='بيانات اصطناعية فقط. اختر واجهة ودورًا ومقاسًا ثم قارن الحزم؛ لا توجد إجراءات تشغيلية في المعاينة.';details.append(p);
 const grid=document.createElement('div');grid.className='ff-a07-gallery';details.append(grid);
 const compare=document.createElement('section');compare.className='ff-a07-compare';compare.innerHTML='<label>حزمة المقارنة<select name="comparePack"></select></label><div class="ff-a07-compare-grid"><div><h4>الحزمة المرجعية</h4><div data-a07-before></div></div><div><h4>المسودة</h4><div data-a07-after></div></div></div>';details.append(compare);
 const select=compare.querySelector('select');let catalogKey='';
 form.querySelector('#ffCardEditor').before(details);
 let key='';
 function redraw(){
  if(!details.open)return;
  const screen=form.elements.screen.value,role=form.elements.role.value,previewScreen=screen==='all'?(roleScreens[role]||'dashboard'):screen;
  const pack=form.elements.pack.value,style=readStyle(form),width=Number(form.elements.viewport.value)||390;
  const catalog=JSON.stringify(packs);if(catalog!==catalogKey){const previous=select.value;select.replaceChildren(...packs.map(({code,name})=>new Option(code+' · '+name,code)));if(packs.some(p=>p.code===previous))select.value=previous;catalogKey=catalog;}
  const next=JSON.stringify([previewScreen,pack,style,select.value,width,catalogKey]);
  if(next===key)return;key=next;
  grid.replaceChildren();
  packs.forEach(({code,name})=>{const button=document.createElement('button');button.type='button';button.className='ff-a07-gallery-choice';button.setAttribute('aria-pressed',String(code===pack));button.setAttribute('aria-label',name);const label=document.createElement('b');label.textContent=code+' · '+name;button.append(label,demoCard(previewScreen,code,{},true));button.onclick=()=>{form.elements.pack.value=code;form.elements.pack.dispatchEvent(new Event('change',{bubbles:true}))};grid.append(button)});
  for(const [selector,chosen,config]of [['[data-a07-before]',select.value,{}],['[data-a07-after]',pack,style]]){
   const parent=compare.querySelector(selector);parent.replaceChildren();const holder=document.createElement('div');holder.className='ff-a07-preview-holder';holder.style.width=width+'px';holder.append(demoCard(previewScreen,chosen,config));parent.append(holder);
  }
 }
 details.addEventListener('toggle',redraw);select.addEventListener('change',redraw);return redraw;
}
window.ffA07Design={screens,roleScreens,tokens,selectFields,readStyle,setStyle,gallery,demoCard,decorate,apply,clear,refresh};
window.addEventListener('ff-luxe-session-reset',clear);
setInterval(refresh,1500);
refresh();
})();
