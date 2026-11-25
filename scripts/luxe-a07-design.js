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
const elementSelectors={dashboard:'#ffx-topbar,#ffx-sidebar,#ff2-dialog,#ff3-guide,#ffF01Panel',system:'#ffx-preferences,#ffA12Recovery',driver:'dialog.ff-luxe-rate-dialog:has(#ffLuxeFourScores),dialog.ff-luxe-rate-dialog:has(option[value="delivery_fee"])',orders:'#ffRewardManager,#ffRewardService',cashier:'#ffRewardCashier',archive:'#fflCashierFinished,#ffCompletedDetailDialog',cases:'#ffCaseAlertDialog',reports:'#ffHistoryPeriod',finance:'#ff42RangeReport'};
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
// STEP05: last-resort copy of the existing official PWA mark, not a replacement logo.
// The embedded copy works even when both image requests fail.
const OFFLINE_MARK='data:image/png;base64,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';
function imageFallback(img){
 if(img.dataset.ffA07Fallback)return;
 img.dataset.ffA07Fallback='1';
 const fallback=()=>{
  const src=img.getAttribute('src')||'';
  if(src===OFFLINE_MARK)return;
  if(!img.dataset.ffA07Tried&&src!==FALLBACK){img.dataset.ffA07Tried='1';img.src=FALLBACK;return}
  img.dataset.ffA07Tried='2';img.src=OFFLINE_MARK;
 };img.addEventListener('error',fallback);if(img.complete&&!img.naturalWidth)fallback();
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
  const screen=el.matches('.ffb-v2-dialog')?'orders':(el.closest('[data-ff-a07-screen]')?.dataset.ffA07Screen||activeScreen()),style=current[screen]?.style_config||{};
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
 if(img.dataset.ffA07DesiredMenuAsset!==src){img.dataset.ffA07DesiredMenuAsset=src;delete img.dataset.ffA07Tried;if(img.getAttribute('src')!==src)img.src=src}
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
 const ratingDialogs=[...document.querySelectorAll('dialog.ff-luxe-rate-dialog:has(button[data-skip])')].map(root=>[root,activeScreen()==='cashier'?'cashier':'orders']);
 const shared=[...ratingDialogs,[$('ffBurgerDialog'),activeScreen()==='assembly'?'assembly':'cashier'],[$('ffRewardRedeemDialog'),(typeof data!=='undefined'&&data?.role==='cashier')?'cashier':'orders']];
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
