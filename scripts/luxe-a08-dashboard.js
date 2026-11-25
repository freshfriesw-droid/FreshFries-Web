/* A08 — scoped dashboard cards and read-only details. No operational mutations. */
(()=>{
'use strict';
const $=id=>document.getElementById(id),make=(tag,txt)=>{const n=document.createElement(tag);if(txt!==undefined)n.textContent=txt;return n};
const roles={manager:'المدير العام',supervisor:'المشرف',customer_service:'خدمة العملاء',cashier:'الكاشير',driver:'الموصل',assembly:'نقطة التجميع',burger_kitchen:'مطبخ البرجر'};
const permissions={view_reports:'عرض التقارير',manage_drivers:'إدارة الموصلين',create_order:'إنشاء الطلب',assign_driver:'إسناد الطلب',edit_order:'تعديل الطلب',cancel_order:'إلغاء الطلب'};
const icons={orders:'طلبات',clock:'ساعة',users:'مستخدمون',alert:'تنبيه',star:'نجمة',grid:'شبكة',bike:'دراجة',report:'تقرير'};
const actions={new:'طلب جديد',orders:'متابعة الطلبات',drivers:'الموصلون',late:'المتأخرة',reports:'التقارير',assembly_admin:'حسابات التجميع',rewards:'الأكواد',messages:'الرسائل',driver:'بوابة الموصل',cashier:'الكاشير',settings:'الإعدادات',reservations:'الحجوزات',attendance:'الدوام',offers:'العروض',cases:'الشكاوى والتظلمات',customers:'العملاء',burger:'البرجر',cashier_finished:'المنتهية للكاشير'};
const standard=['new','orders','drivers','late','reports','assembly_admin','rewards','messages','driver','cashier','settings'];
const statusNames={new:'جديد',sent:'مسند',delivered:'منجز',cancelled:'ملغى',assigned:'مسند',preparing:'قيد التحضير',ready:'جاهز',on_way:'في الطريق',arrived:'وصل'};
const number=v=>typeof v==='number'&&Number.isFinite(v)&&v>=0?String(v):'—';
const date=v=>{const d=new Date(v);return Number.isFinite(d.getTime())?d.toLocaleString('ar-YE',{timeZone:'Asia/Aden',hour:'2-digit',minute:'2-digit',day:'numeric',month:'numeric'}):'—'};
const copy=o=>JSON.parse(JSON.stringify(o??{}));
function cardVisible(card,role,can){
 return (!Array.isArray(card.roles)||card.roles.includes(role))&&(!card.permission||can(card.permission));
}
function cardFields(card,i,change){
 const box=make('details');box.className='ff-a08-card-access';
 box.append(make('summary','الصلاحيات والأيقونة'));
 const roleGroup=make('fieldset');roleGroup.append(make('legend','أدوار عرض البطاقة — لا تمنح صلاحية جديدة'));
 const checks=[];
 for(const [key,label] of Object.entries(roles)){
  const wrap=make('label'),input=make('input');input.type='checkbox';input.checked=!Array.isArray(card.roles)||card.roles.includes(key);input.setAttribute('aria-label',label+' — بطاقة '+(i+1));checks.push([key,input]);wrap.append(input,document.createTextNode(label));roleGroup.append(wrap);
  input.onchange=()=>change(()=>{const selected=checks.filter(([,c])=>c.checked).map(([k])=>k);if(selected.length===Object.keys(roles).length)delete card.roles;else card.roles=selected});
 }
 box.append(roleGroup);
 for(const [prop,label,options,empty] of [['permission','صلاحية إضافية مطلوبة',permissions,'حسب الصلاحيات الأصلية'],['icon','أيقونة البطاقة',icons,'حسب المؤشر']]){
  const wrap=make('label',label),select=make('select');select.setAttribute('aria-label',label+' '+(i+1));select.add(new Option(empty,''));Object.entries(options).forEach(([k,v])=>select.add(new Option(v,k)));select.value=card[prop]||'';
  select.onchange=()=>change(()=>{if(select.value)card[prop]=select.value;else delete card[prop]});wrap.append(select);box.append(wrap);
 }
 return box;
}
const editorState=new WeakMap();
function editor(form,anchor){
 const root=make('details');root.id='ffA08Panels';
 root.innerHTML='<summary>الأقسام الثانوية والاختصارات</summary><p>تخصيص الرئيسية فقط؛ لا يمكن إخفاء التحذيرات أو حالة اتصال النظام أو إضافة إجراء غير معرّف.</p><div data-a08-panels></div><label><input type="checkbox" data-a08-custom-actions> تخصيص مكتبة الاختصارات وترتيبها</label><div data-a08-actions></div>';
 anchor.after(root);
 const panels=root.querySelector('[data-a08-panels]'),custom=root.querySelector('[data-a08-custom-actions]'),list=root.querySelector('[data-a08-actions]');
 const st={panels:{},quick:undefined};editorState.set(form,st);
 const notify=()=>form.dispatchEvent(new Event('input',{bubbles:true}));
 const fields={activity:'الأنشطة الحديثة',shortcuts:'الإجراءات السريعة',branches:'حالة الفروع'};
 function render(){
  panels.replaceChildren();
  for(const [key,label] of Object.entries(fields)){
   const wrap=make('label',label),sel=make('select');sel.setAttribute('aria-label',label);sel.add(new Option('وراثة الإعداد',''));sel.add(new Option('إظهار','true'));sel.add(new Option('إخفاء','false'));sel.value=key in st.panels?String(st.panels[key]):'';
   sel.onchange=()=>{if(sel.value==='')delete st.panels[key];else st.panels[key]=sel.value==='true';notify()};wrap.append(sel);panels.append(wrap);
  }
  custom.checked=Array.isArray(st.quick);list.hidden=!custom.checked;list.replaceChildren();
  if(!custom.checked)return;
  const add=make('select');add.setAttribute('aria-label','إجراء سريع من المكتبة');add.add(new Option('إضافة إجراء…',''));for(const [k,v] of Object.entries(actions))if(!st.quick.includes(k))add.add(new Option(v,k));add.onchange=()=>{if(add.value){st.quick.push(add.value);render();notify()}};list.append(add);
  st.quick.forEach((key,i)=>{
   const row=make('div');row.className='ff-a08-action-row';row.append(make('b',actions[key]||key));
   for(const [label,disabled,fn] of [['تقديم',i===0,()=>st.quick.splice(i-1,0,...st.quick.splice(i,1))],['تأخير',i===st.quick.length-1,()=>st.quick.splice(i+1,0,...st.quick.splice(i,1))],['حذف',false,()=>st.quick.splice(i,1)]]){
    const btn=make('button',label);btn.type='button';btn.disabled=disabled;btn.onclick=()=>{fn();render();notify()};row.append(btn);
   }
   list.append(row);
  });
 }
 custom.onchange=()=>{st.quick=custom.checked?[...standard]:undefined;render();notify()};
 st.render=render;render();
 return root;
}
function read(form){const s=editorState.get(form);if(!s||!['all','dashboard'].includes(form.elements.screen.value))return {};const out={};if(Object.keys(s.panels).length)out.dashboardPanels=copy(s.panels);if(Array.isArray(s.quick))out.quickActions=[...s.quick];return out}
function set(form,style){const s=editorState.get(form);if(!s)return;s.panels=copy(style?.dashboardPanels);s.quick=Array.isArray(style?.quickActions)?[...style.quickActions]:undefined;s.render()}
const dash=$('ffx-dashboard');if(!dash)return;
function panel(id,title){
 const n=make('section');n.id=id;n.className='ffx-panel ff-a08-panel';n.hidden=true;n.append(make('h3',title));const body=make('div');body.className='ff-a08-panel-body';n.append(body);dash.append(n);return {n,body};
}
const activity=panel('ffA08Activity','الأنشطة الحديثة — اليوم التشغيلي'),branches=panel('ffA08Branches','حالة الفروع ضمن نطاقك');
const dlg=make('dialog');dlg.id='ffA08Detail';dlg.dir='rtl';dlg.setAttribute('aria-labelledby','ffA08DetailTitle');
dlg.innerHTML='<div class="sectionbar"><h2 id="ffA08DetailTitle">تفاصيل المؤشر</h2><button type="button" data-a08-close>إغلاق</button></div><p data-a08-context></p><p role="status" data-a08-status aria-live="polite"></p><div data-a08-rows></div><div class="actions"><button type="button" data-a08-prev>السابق</button><button type="button" data-a08-next>التالي</button><button type="button" data-a08-refresh>تحديث</button><button type="button" data-a08-go>فتح قسم العمل</button></div>';
document.body.append(dlg);
let context=null,selection=null,epoch=0,busy=false,offset=0,total=0,lastTrigger=null,panelSig='';
const part=k=>dlg.querySelector('[data-a08-'+k+']');
function close(){epoch++;busy=false;selection=null;offset=0;total=0;part('rows').replaceChildren();part('status').textContent='';part('context').textContent='';if(dlg.open)dlg.close()}
dlg.onclose=()=>{epoch++;busy=false;selection=null;part('rows').replaceChildren();part('status').textContent='';part('context').textContent='';if(lastTrigger?.isConnected)lastTrigger.focus({preventScroll:true});lastTrigger=null};
part('close').onclick=close;
function state(){part('prev').disabled=busy||offset===0;part('next').disabled=busy||offset+30>=total;part('refresh').disabled=busy;part('go').hidden=!selection?.go;part('go').disabled=busy}
async function load(){
 const s=selection,c=context;if(!s||!c||busy)return;
 const seq=++epoch;busy=true;part('rows').replaceChildren();part('status').textContent='جاري تحميل التفاصيل المصرح بها…';state();
 const valid=()=>seq===epoch&&dlg.open&&selection===s&&context?.key===c.key&&context.allowed.has(s.metric);
 try{
  const box=await rpc('ff_a08_metric_detail',{p_branch:c.branch||null,p_metric:s.metric,p_offset:offset,p_limit:30});
  if(!valid())return;
  if(box?.role!==c.role||box?.metric!==s.metric||!Array.isArray(box.rows)||!Number.isInteger(box.total)||box.total<0||box.offset!==offset)throw Error('استجابة غير صالحة');
  total=box.total;part('status').textContent='إجمالي النتائج: '+total+' · اليوم التشغيلي '+box.business_day+(total?' · '+(offset+1)+'–'+Math.min(total,offset+box.rows.length):'');
  for(const item of box.rows){
   const row=make('article');row.className='ff-a08-data-row';
   if(s.metric==='available_drivers'){row.append(make('b',String(item.driver_name||'—')),make('span',String(item.branch_name||'—')+' · جاهز ومتصل'))}
   else{row.append(make('b','طلب #'+String(item.order_number)),make('span',String(item.branch_name||'—')+' · '+(statusNames[item.status]||'حالة الطلب')+' · '+date(item.updated_at)))}
   part('rows').append(row);
  }
  if(!box.rows.length)part('rows').append(make('p','لا توجد نتائج في هذه الصفحة.'));
 }catch{if(valid()){total=0;part('status').textContent='تعذر تحميل التفاصيل أو لم تعد مصرحاً بها.';part('rows').replaceChildren()}}
 finally{if(valid()){busy=false;state()}}
}
part('prev').onclick=()=>{if(!busy&&offset>0){offset=Math.max(0,offset-30);void load()}};
part('next').onclick=()=>{if(!busy&&offset+30<total){offset+=30;void load()}};
part('refresh').onclick=()=>{offset=0;void load()};
part('go').onclick=()=>{const go=selection?.go;close();go?.()};
function open(metric,label,go,trigger){
 if(!context?.allowed.has(metric))return;
 close();selection={metric,go};offset=0;total=0;lastTrigger=trigger;dlg.querySelector('h2').textContent=label;part('context').textContent=context.branchName||'جميع الفروع المصرح بها';dlg.showModal();void load();
}
function sync(snapshot,config){
 if(!config.key){context=null;close()}
 else{
  if(context?.key!==config.key||(selection&&!config.allowed.has(selection.metric)))close();
  context=config;
 }
 const style=config.style||{},p=style.dashboardPanels||{};
 const showActivity=!!config.key&&p.activity!==false,showBranches=!!config.key&&(p.branches??['manager','supervisor'].includes(config.role));
 const sig=JSON.stringify([config.key,showActivity,showBranches,snapshot?.recent_activity,snapshot?.branch_status]);
 if(sig!==panelSig){
  panelSig=sig;activity.n.hidden=!showActivity;branches.n.hidden=!showBranches;activity.body.replaceChildren();branches.body.replaceChildren();
  if(showActivity){
   const rows=snapshot?.recent_activity;
   if(!Array.isArray(rows))activity.body.append(make('p','البيانات غير متاحة أو بانتظار الاتصال.'));
   else if(!rows.length)activity.body.append(make('p','لا توجد أنشطة ضمن هذا النطاق.'));
   else for(const x of rows){const n=make('article');n.className='ff-a08-data-row';n.append(make('b','طلب #'+String(x.order_number)),make('span',String(x.branch_name||'—')+' · '+(statusNames[x.status]||'حالة الطلب')+' · '+date(x.updated_at)));activity.body.append(n)}
  }
  if(showBranches){
   const rows=snapshot?.branch_status;
   if(!Array.isArray(rows))branches.body.append(make('p','البيانات غير متاحة أو بانتظار الاتصال.'));
   else if(!rows.length)branches.body.append(make('p','لا توجد فروع ضمن النطاق.'));
   else for(const x of rows){const n=make('article');n.className='ff-a08-data-row';n.append(make('b',String(x.branch_name||'—')),make('span',x.active===true?'فرع مفعّل':x.active===false?'فرع غير مفعّل':'حالة الفرع غير متاحة'),make('span','الطلبات: '+number(x.orders_today)+' · المنجزة: '+number(x.completed_today)+' · المتأخرة: '+number(x.late_today)+' · الجاهزون: '+number(x.available_drivers)));branches.body.append(n)}
  }
 }
}
window.addEventListener('ff-luxe-session-reset',()=>{context=null;close();panelSig='';activity.n.hidden=true;branches.n.hidden=true;activity.body.replaceChildren();branches.body.replaceChildren()});
window.ffA08Dashboard={cardVisible,cardFields,editor,read,set,sync,open,icons};
})();
