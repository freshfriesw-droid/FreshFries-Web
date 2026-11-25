/* A07: appearance only. Never recreates operational controls or changes permissions. */
(()=>{
'use strict';
const $=id=>document.getElementById(id);
const screens={
 all:'جميع الشاشات',dashboard:'الرئيسية',orders:'الطلبات وخدمة العملاء',cashier:'الكاشير',driver:'الموصل',
 assembly:'نقطة التجميع',burger_kitchen:'مطبخ البرجر',catalog:'المنيو والعروض',customers:'العملاء',
 reports:'التقارير',staff:'الموظفون والصلاحيات',archive:'الأرشيف',ratings:'التقييمات',cases:'الشكاوى والتظلمات',
 messages:'الرسائل',reservations:'الحجوزات',system:'النظام والأمان',finance:'التسويات النقدية',branches:'الفروع وساعات العمل والأسعار',login:'الدخول وطلب الانضمام',customer_portal:'بوابة العميل'
};
const selectors={
 dashboard:'#ffx-dashboard,#ff40AlertsPanel,#ff60-panel,#ff4-panel,#ff5-modal',orders:'#serviceOnly,#staffOrders,#ff50ChangesPanel,#ff49TransferPanel,#ff49ManualPanel,#ff52LatePanel,#ffbConfirmLayer,#auditCard,#staffView .card:has(#orderSearch),#ffCustomerEditDialog,#ffUnifiedMenuDialog',cashier:'#cashierView,#ffBurgerCashierPanel',driver:'#driverView,#ff52RoutesPanel',
 assembly:'#ffV12AssemblyWorkspace',burger_kitchen:'#ffBurgerKitchenWorkspace',
 catalog:'#ff51CatalogPanel',customers:'#ff51CustomersPanel',reports:'#ff76Center,#ff40ReportsPanel,#ff76PdfDialog',staff:'#staffAdminCard,#ffEditDialog,#managerLinks',
 archive:'#ff51ArchivePanel',ratings:'#ff51RatingsPanel',cases:'#ff41Panel,#ff41Dialog',messages:'#ff39Panel,#ff39Dialog',
 finance:'#ff42Panel',branches:'#ffA05BranchCard,#ffA05BranchDialog',login:'#loginOverlay .loginbox',customer_portal:'#ff28Portal',
 reservations:'#ff49ReservationsPanel',system:'#ff48DiagnosticsPanel,#ff47QAPanel,#ff46ReadinessPanel,#ff44IntegrityPanel,#ff43SecurityPanel,#ff45AccessPanel,#ff62DataCenter'
};
// Shared controls use an element-only scope: do not restyle shell containers or add logos.
const elementSelectors={dashboard:'#ffx-topbar,#ffx-sidebar,#ff2-dialog,#ff3-guide,#ffF01Panel',system:'#ffx-preferences,#ffA12Recovery',orders:'#ffRewardManager,#ffRewardService',cashier:'#ffRewardCashier',archive:'#fflCashierFinished,#ffCompletedDetailDialog',cases:'#ffCaseAlertDialog',reports:'#ffHistoryPeriod',finance:'#ff42RangeReport'};
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
 logoAsset:['صورة الشعار',['brand','الشعار الرسمي'],['mark','أيقونة المطعم']],
 logoDarkAsset:['شعار الوضع الداكن',['brand','الشعار الرسمي'],['mark','أيقونة المطعم']],
 logoWidth:['مقاس الشعار الدقيق',['24','24 بكسل'],['32','32 بكسل'],['40','40 بكسل'],['48','48 بكسل'],['56','56 بكسل'],['64','64 بكسل'],['80','80 بكسل'],['10%','10% من المساحة'],['20%','20% من المساحة'],['30%','30% من المساحة'],['40%','40% من المساحة']],
 logoPosition:['موضع الشعار',['header','موضع العنوان الأصلي'],['cover','غلاف مستقل أعلى الشاشة'],['menu','القائمة الرئيسية / المزيد']],
 dialogRadius:['استدارة نافذة التأكيد أو التقييم',['square','مستطيلة'],['round','مستديرة']],
 dialogPadding:['مساحة نافذة التأكيد أو التقييم',['normal','عادية'],['wide','واسعة']],
 ratingScale:['حجم نجوم التقييم',['normal','عادي'],['large','كبير']],
 logoAlign:['محاذاة الشعار',['start','البداية'],['center','الوسط'],['end','النهاية']],
 layout:['شبكة البطاقات على الكمبيوتر',['pack','حسب الحزمة'],['single','عمود واحد'],['double','عمودان'],['triple','ثلاثة أعمدة']]
};
const roleScreens={manager:'dashboard',supervisor:'dashboard',customer_service:'orders',cashier:'cashier',driver:'driver',assembly:'assembly',burger_kitchen:'burger_kitchen'};
const packOK=p=>/^D[0-9]{2,}$/.test(p||'');
const cfgOf=v=>v&&typeof v==='object'&&!Array.isArray(v)?v:{};
const publicScreen=s=>s==='login'||s==='customer_portal';
const extendedScreen=s=>publicScreen(s)||s==='finance'||s==='branches';
const extendedRoot=(root,screen)=>extendedScreen(screen)||['ff40AlertsPanel','ff50ChangesPanel','ff49TransferPanel','ffEditDialog','ff45AccessPanel','ff60-panel','ff4-panel','ff5-modal','ff49ManualPanel','ff52LatePanel','ffbConfirmLayer','ff52RoutesPanel','managerLinks','auditCard','ff40ReportsPanel','ff76PdfDialog','ffCustomerEditDialog','ffUnifiedMenuDialog'].includes(root.id)||root.matches('#staffView .card:has(#orderSearch)');
const visiblePublicScreen=()=>['customer','applicant'].includes(document.body.dataset.access)?'customer_portal':document.body.dataset.access==='locked'?'login':null;
let current={},publicRows={},publicKey='',publicAt=0,publicSerial=0,owned=new Set(),ownedDialogs=new Set();
async function syncPublic(force=false){
 const screen=visiblePublicScreen(),device=innerWidth<=850?'mobile':'desktop',key=screen?screen+'|'+device:'';
 if(key!==publicKey){publicKey=key;publicRows={};publicAt=0;publicSerial++;refresh()}
 if(!screen||(!force&&Date.now()-publicAt<30000))return;
 if(typeof client==='undefined'||!client)return;
 publicAt=Date.now();const request=++publicSerial;
 try{const row=await rpc('ff_a07_public_appearance',{p_screen:screen,p_device:device});if(request!==publicSerial||visiblePublicScreen()!==screen||publicKey!==key||(innerWidth<=850?'mobile':'desktop')!==device)return;publicRows=packOK(row?.pack)?{[screen]:row}:{};refresh()}catch{/* Keep only the last published public design for this exact device and screen. */}
}
const LOGO='./assets/ff-official-logo.png',FALLBACK='./assets/ff-icon-192.png';
const logoPaths={brand:LOGO,mark:FALLBACK},logoOrigins=new WeakMap();
function imageFallback(img){
 if(img.dataset.ffA07Fallback)return;
 img.dataset.ffA07Fallback='1';
 const fallback=()=>{if(!img.dataset.ffA07Tried){img.dataset.ffA07Tried='1';img.src=FALLBACK}}; img.addEventListener('error',fallback,{once:true});if(img.complete&&!img.naturalWidth)fallback();
}
function addLogo(root,screen){
 if(screen==='dashboard'||screen==='assembly'||root.id==='ffBurgerCashierPanel'||root.id==='staffOrders')return;
 const title=root.querySelector('h1,h2,h3');
 if(!title||title.closest('button')||root.querySelector('.ff-a07-logo-inline'))return;
 const img=document.createElement('img');img.className='ff-a07-logo-inline';if(extendedRoot(root,screen))img.dataset.ffStep03ExtendedLogo='1';img.src=LOGO;img.alt='شعار فريش فرايز';img.loading='lazy';img.width=40;img.height=40;imageFallback(img);
 title.prepend(img);
}
function applyLogo(root){
 const logos=[...root.querySelectorAll('.ff-a07-logo-inline,.ffx-hero-logo,.ff-assembly-brand>img,[data-ff-a07-managed-logo]')].filter(img=>img.closest('[data-ff-a07-screen]')===root);
 const dark=root.dataset.a07Surface==='dark'||(root.dataset.a07Surface!=='light'&&(document.body.classList.contains('ffx-dark')||['D02','D08','D11','D13'].includes(root.dataset.ffA07Pack)));
 for(const img of logos){
  if(!logoOrigins.has(img))logoOrigins.set(img,{src:img.getAttribute('src'),parent:img.parentNode,next:img.nextSibling,desired:null});
  img.dataset.ffA07ManagedLogo='1';
  const o=logoOrigins.get(img),choice=dark&&root.dataset.a07LogoDarkAsset?root.dataset.a07LogoDarkAsset:root.dataset.a07LogoAsset;
  const src=logoPaths[choice]||o.src;
  if(src&&src!==o.desired){o.desired=src;delete img.dataset.ffA07Tried;if(img.getAttribute('src')!==src)img.src=src}
  let cover=root.querySelector(':scope > .ff-a07-logo-cover');
  if(root.dataset.a07LogoPosition==='cover'||((root.classList.contains('ff-a07-demo')||publicScreen(root.dataset.ffA07Screen))&&root.dataset.a07LogoPosition==='menu')){
   if(!cover){cover=document.createElement('div');cover.className='ff-a07-logo-cover';root.prepend(cover)}
   if(img.parentNode!==cover)cover.append(img);cover.dataset.logoPlacement=root.dataset.a07LogoPosition;if(root.classList.contains('ff-a07-demo')&&root.dataset.a07LogoPosition==='menu')cover.setAttribute('aria-label','معاينة موضع الشعار في القائمة');else cover.removeAttribute('aria-label')
  }else if(cover?.contains(img)&&o.parent?.isConnected){
   o.parent.insertBefore(img,o.next?.parentNode===o.parent?o.next:null);if(!cover.children.length)cover.remove()
  }
 }
}
function applyCaption(root,row,screen){
 if(screen==='dashboard'||root.id==='staffOrders')return;
 let node=root.querySelector(':scope > [data-ff-a07-caption]');
 if(!row?.layout_text){node?.remove();return}
 const title=root.querySelector('h1,h2,h3');
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

const navScreens={home:'dashboard',new:'orders',orders:'orders',late:'dashboard',cashier:'cashier',attendance:'driver',driver:'driver',offers:'driver',burger:'burger_kitchen',cashier_finished:'cashier',catalog:'catalog',customers:'customers',reports:'reports',team:'staff',staff_link:'staff',applications:'staff',application_alerts:'staff',archive:'archive',ratings:'ratings',cases:'cases',messages:'messages',reservations:'reservations',settlements:'finance',branch_policy:'branches',studio:'system',data_center:'system',security:'system',integrity:'system',access:'system',readiness:'system',qa:'system',diagnostics:'system'};
function activeScreen(){
 if(typeof ffV12AssemblyActive!=='undefined'&&ffV12AssemblyActive)return 'assembly';
 if(window.ffBurgerActive?.())return 'burger_kitchen';
 const key=document.querySelector('#ffx-nav button.active[data-key],#ffx-mobile-nav button.active[data-key]')?.dataset.key;
 return navScreens[key]||roleScreens[typeof data!=='undefined'?data?.role:null]||'dashboard';
}
function dialogStyle(){
 const next=new Set();
 for(const el of document.querySelectorAll('#ffbConfirmLayer .ffb-v2-dialog,dialog.ff-luxe-rate-dialog')){
  const screen=el.matches('.ffb-v2-dialog')?'orders':activeScreen(),style=current[screen]?.style_config||{};
  for(const key of ['dialogRadius','dialogPadding','ratingScale']){
   const attr='a07'+key[0].toUpperCase()+key.slice(1);delete el.dataset[attr];
   if(tokens[key].slice(1).some(o=>o[0]===style[key]))el.dataset[attr]=style[key];
  }
  next.add(el);
 }
 for(const el of ownedDialogs)if(!next.has(el))for(const key of ['a07DialogRadius','a07DialogPadding','a07RatingScale'])delete el.dataset[key];
 ownedDialogs=next;
}
function menuLogo(){
 const screen=activeScreen(),row=current[screen],style=row?.style_config||{};
 const special=['assembly','burger_kitchen'].includes(screen);
 const host=special?$('ffA06SpecialMore'):$('ffx-sidebar')?.querySelector('.ffx-logo');
 for(const old of document.querySelectorAll('.ff-step03-menu-brand'))if(old.parentElement!==host||style.logoPosition!=='menu')old.remove();
 for(const node of document.querySelectorAll('[data-ff-step03-menu-original]'))if(node.parentElement!==host||style.logoPosition!=='menu'){delete node.dataset.ffStep03MenuOriginal;}
 if(!host||style.logoPosition!=='menu')return;
 let box=host.querySelector(':scope > .ff-step03-menu-brand');
 if(!box){box=document.createElement('span');box.className='ff-step03-menu-brand';const img=document.createElement('img');img.alt='شعار فريش فرايز';img.src=LOGO;box.append(img);host.prepend(box);imageFallback(img)}
 const original=host.querySelector(':scope > .ffx-logo-image');if(original)original.dataset.ffStep03MenuOriginal='1';
 decorate(box,row);
 const dark=style.surface==='dark'||(style.surface!=='light'&&(document.body.classList.contains('ffx-dark')||(!special&&style.surface!=='light')||['D02','D08','D11','D13'].includes(row?.pack)));
 const img=box.querySelector('img'),src=logoPaths[dark&&style.logoDarkAsset?style.logoDarkAsset:style.logoAsset]||LOGO;
 if(img.getAttribute('src')!==src){delete img.dataset.ffA07Tried;img.src=src}
 for(const root of owned)if(root.dataset.ffA07Screen===screen&&root.dataset.a07LogoPosition==='menu')root.dataset.ffStep03LogoInMenu='1';
}
function refresh(){
 for(const root of owned)delete root.dataset.ffStep03LogoInMenu;
 const seen=new Set();
 for(const [screen,selector] of Object.entries(selectors)){
  for(const root of document.querySelectorAll(selector)){
   if(root.id==='ffBurgerCashierPanel'&&activeScreen()==='assembly'){resetNode(root);delete root.dataset.ffA07Signature;root.querySelector(':scope > [data-ff-a07-caption]')?.remove();continue;}
   if(seen.has(root))continue;seen.add(root);
   root.dataset.ffA07Screen=screen;delete root.dataset.ffA07ElementScope;
   const row=publicScreen(screen)?publicRows[screen]:current[screen];
   if(!extendedRoot(root,screen)||row)addLogo(root,screen);
   else{root.querySelectorAll('[data-ff-step03-extended-logo]').forEach(n=>n.remove());root.querySelectorAll(':scope > .ff-a07-logo-cover').forEach(n=>{if(!n.children.length)n.remove()});}
   const signature=JSON.stringify([row?.id,row?.pack,row?.style_config,row?.layout_text]);
   if(root.dataset.ffA07Signature!==signature){decorate(root,row);applyCaption(root,row,screen);root.dataset.ffA07Signature=signature}
  }
 }
 const elementOnly=new Set();
 const shared=[[$('ffBurgerDialog'),activeScreen()==='assembly'?'assembly':'cashier'],[$('ffRewardRedeemDialog'),(typeof data!=='undefined'&&data?.role==='cashier')?'cashier':'orders']];
 if(activeScreen()==='assembly'){const panel=$('ffBurgerCashierPanel');if(panel)shared.push([panel,'assembly']);}
 for(const [root,screen] of shared){if(!root||seen.has(root))continue;seen.add(root);elementOnly.add(root);root.dataset.ffA07Screen=screen;if(packOK(current[screen]?.pack))root.dataset.ffA07ElementScope='1';else delete root.dataset.ffA07ElementScope;}
 for(const [screen,selector] of Object.entries(elementSelectors))for(const root of document.querySelectorAll(selector)){
  if(seen.has(root))continue;seen.add(root);elementOnly.add(root);root.dataset.ffA07Screen=screen;
  if(packOK(current[screen]?.pack))root.dataset.ffA07ElementScope='1';else delete root.dataset.ffA07ElementScope;
 }
 for(const old of owned)if(!seen.has(old)){resetNode(old);delete old.dataset.ffA07Signature;delete old.dataset.ffA07Screen;delete old.dataset.ffA07ElementScope}
 owned=seen;
 for(const root of seen)if(!elementOnly.has(root))applyLogo(root);
 dialogStyle();menuLogo();
 window.ffA07Elements?.refresh(seen,{...current,...publicRows});
 for(const img of document.querySelectorAll('img[src$="/ff-official-logo.png"],img[src$="/ff-icon-192.png"]'))imageFallback(img);
}
function apply(rows){current=cfgOf(rows);refresh()}
function clear(){current={};publicRows={};publicKey='';publicAt=0;publicSerial++;refresh();void syncPublic()}
function selectFields(form){
 const section=document.createElement('details');section.id='ffA07StyleFields';
 const heading=document.createElement('summary');heading.textContent='تخصيص الهوية والمظهر';section.append(heading);
 const grid=document.createElement('div');grid.className='ff-studio-fields';section.append(grid);
 for(const [key,[label,...values]] of Object.entries(tokens)){
  const wrap=document.createElement('label');wrap.textContent=label;const select=document.createElement('select');select.name='a07_'+key;
  select.add(new Option('وراثة من النطاق الأعم',''));for(const [k,v]of values)select.add(new Option(v,k));wrap.append(select);grid.append(wrap);
 }
 const note=document.createElement('p');note.className='muted';note.textContent='الخطوط من الجهاز مع بدائل محلية. لا تغيّر إعدادات المظهر حالات الطلب أو تحذيرات الخطر أو صلاحيات الوصول.';section.append(note);
 form.querySelector('#ffCardEditor').before(section);
 const wrap=document.createElement('label');wrap.textContent='الشاشة';const sel=document.createElement('select');sel.name='screen';for(const [k,v]of Object.entries(screens))sel.add(new Option(v,k,k==='dashboard',k==='dashboard'));
 wrap.append(sel);form.querySelector('.ff-studio-fields').prepend(wrap);
 window.ffA07Elements?.editor(form,form.querySelector('#ffCardEditor'));
 return sel;
}
function readStyle(form){const v=Object.fromEntries(Object.keys(tokens).map(k=>[k,form.elements.namedItem('a07_'+k)?.value]).filter(([k,v])=>tokens[k].slice(1).some(o=>o[0]===v)));const elements=window.ffA07Elements?.read(form);if(elements&&Object.keys(elements).length)v.elements=elements;return v}
function setStyle(form,v){for(const [k,[,...options]] of Object.entries(tokens)){const input=form.elements.namedItem('a07_'+k);if(input)input.value=options.some(x=>x[0]===v?.[k])?v[k]:''}window.ffA07Elements?.set(form,v?.elements)}
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
 finance:['التسويات النقدية','تسوية تجريبية','المبلغ والفرق','حفظ — معاينة'],
 branches:['إعدادات الفروع','ساعات عمل تجريبية','الأسعار والرسوم','حفظ — معاينة'],
 login:['الدخول والانضمام','حساب تجريبي','طلب انضمام تجريبي','دخول — معاينة'],
 customer_portal:['بوابة العميل','طلب تجريبي','الحالة والتقييم','تحديث — معاينة'],
 system:['أمان النظام','فحص تجريبي','لا تغييرات فعلية','عرض الفحص']
};
function demoCard(screen,pack,style,compact=false,select=null){
 const row=demo[screen]||demo.dashboard;
 const root=document.createElement('section');root.className='ff-a07-demo';root.dataset.ffA07Screen=screen;
 decorate(root,{pack,style_config:style,id:'preview'});
 const head=document.createElement('header');head.className='ff-a07-demo-head';const img=document.createElement('img');img.src=LOGO;img.alt='شعار فريش فرايز';img.className='ff-a07-logo-inline';img.width=40;img.height=40;imageFallback(img);
 const h=document.createElement('strong');h.textContent=row[0];head.append(img,h);root.append(head);applyLogo(root);if(style?.logoPosition==='menu'){const note=document.createElement('small');note.textContent='موضع الشعار في القائمة';root.querySelector('.ff-a07-logo-cover')?.append(note)}
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
 if(!compact)window.ffA07Elements?.preview(root,screen,style?.elements,select);
 if(!compact&&(style?.dialogRadius||style?.dialogPadding||style?.ratingScale)){const dialog=document.createElement('section');dialog.className='ff-step03-dialog-example';for(const key of ['dialogRadius','dialogPadding','ratingScale'])if(tokens[key].slice(1).some(o=>o[0]===style[key]))dialog.dataset['a07'+key[0].toUpperCase()+key.slice(1)]=style[key];const title=document.createElement('strong');title.textContent='نافذة تأكيد / تقييم — معاينة';const stars=document.createElement('span');stars.className='ff-step03-rating-example';stars.textContent='★★★★★';dialog.append(title,stars);root.append(dialog)}
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
   const parent=compare.querySelector(selector);parent.replaceChildren();const holder=document.createElement('div');holder.className='ff-a07-preview-holder';holder.style.width=width+'px';holder.append(demoCard(previewScreen,chosen,config,false,selector==='[data-a07-after]'?(group,key)=>window.ffA07Elements?.selectPreview(form,group,key):null));parent.append(holder);
  }
 }
 details.addEventListener('toggle',redraw);select.addEventListener('change',redraw);return redraw;
}
window.ffA07Design={screens,roleScreens,tokens,selectFields,readStyle,setStyle,gallery,demoCard,decorate,apply,clear,refresh,syncPublic,publicScreen};
window.addEventListener('ff-luxe-session-reset',clear);
setInterval(refresh,1500);setInterval(()=>void syncPublic(),1500);
window.addEventListener('resize',()=>void syncPublic());
refresh();
})();
