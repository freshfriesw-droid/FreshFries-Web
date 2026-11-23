/* Fresh Fries LUXE: collapsed operational panels and manager-only employee creation. */
'use strict';
(()=>{
 const id=x=>document.getElementById(x);
 const style=document.createElement('style');style.id='ffl-fold-manager-add-20261123';
 style.textContent=[
 '.ffl-folded-card{position:relative;overflow:visible}',
 '.ffl-folded-card.ffl-collapsed>:not(.ffl-fold-toggle):not(.ffl-staff-quickactions){display:none!important}',
 '.ffl-fold-toggle{width:100%;border:2px solid #c8243b!important;background:linear-gradient(125deg,#222025,#161316)!important;color:#fff!important;display:flex!important;justify-content:space-between;align-items:center;text-align:right;font-weight:900!important;font-size:clamp(15px,2.7vw,18px)!important;padding:13px 16px!important;min-height:51px;border-radius:12px;margin:0 0 9px}',
 '.ffl-fold-toggle:hover,.ffl-fold-toggle[aria-expanded=true]{background:linear-gradient(120deg,#9e1126,#d7223e)!important;border-color:#f1465d!important}',
 '.ffl-fold-arrow{font-size:17px;font-weight:900;transition:transform .2s}',
 '.ffl-fold-toggle[aria-expanded=true] .ffl-fold-arrow{transform:rotate(180deg)}',
 '.ffl-staff-quickactions{display:flex;align-items:center;flex-wrap:wrap;gap:9px;margin:8px 0 14px}',
 '.ffl-add-staff-btn{background:linear-gradient(115deg,#c30c28,#e91b42)!important;color:#fff!important;border:2px solid #ff6a77!important;min-height:49px!important;padding:10px 16px!important;font-weight:900!important;box-shadow:0 5px 18px #cc19343a}',
 '#fflStaffDialog{border:1px solid #d2d2d2;border-radius:19px;width:min(94vw,590px);max-height:88dvh;overflow-y:auto;padding:0;color:var(--ffb-ink,#1c1c1c);background:var(--ffb-surface,#fff);box-shadow:0 18px 70px #0006}',
 '#fflStaffDialog::backdrop{background:#080609ba}',
 '#fflStaffDialog .ffl-dialog-inner{padding:clamp(15px,3vw,25px);direction:rtl}',
 '#fflStaffDialog .ffl-dialog-head{display:flex;justify-content:space-between;align-items:center;gap:10px}',
 '#fflStaffDialog h2{margin:0 0 10px;font-size:20px}',
 '#fflStaffDialog .ffl-staff-grid{display:grid;grid-template-columns:1fr 1fr;gap:10px}',
 '#fflStaffDialog label{font-weight:800;font-size:13px;display:block}',
 '#fflStaffDialog input:not([type=checkbox]),#fflStaffDialog select{width:100%;min-width:0;min-height:43px;margin-top:5px;margin-bottom:8px;border-radius:9px}',
 '#fflStaffDialog .ffl-staff-full{grid-column:1/-1}',
 '#fflStaffDialog .ffl-staff-actions{display:flex;gap:9px;flex-wrap:wrap;margin-top:13px}',
 '#fflStaffDialog .ffl-staff-actions button{min-height:49px;flex:1 1 130px}',
 '#fflStaffDialog .ffl-check-row{display:flex;align-items:flex-start;gap:8px;font-weight:700;line-height:1.6}',
 '#fflStaffDialog .ffl-check-row input{flex:none;min-width:20px;min-height:20px;margin:2px 0}',
 '#fflStaffDialog [hidden]{display:none!important}',
 '@media(max-width:540px){#fflStaffDialog .ffl-staff-grid{grid-template-columns:1fr}#fflStaffDialog{width:96vw}}'
 ].join('\n');
 document.head.append(style);

 const panels=[
  [id('managerLinks'),'🔗 ربط حسابات الموظفين القديمة'],
  [id('staffAdminCard'),'👥 إدارة الموظفين والحسابات'],
  [id('auditCard'),'📚 سجل صلاحيات رفض الموصل'],
  ...[...document.querySelectorAll('#serviceOnly .split > .card')].map(el=>[el,
   el.querySelector('h2')?.textContent?.trim()||'قائمة التشغيل']),
  ...[...document.querySelectorAll('#serviceOnly > .card')].filter(el=>
   !!el.querySelector('h2')&&/البحث في الطلبات/.test(el.querySelector('h2').textContent)
  ).map(el=>[el,'🔎 البحث في الطلبات'])
 ];
 function fold(el,label){
  if(!el||el.querySelector(':scope > .ffl-fold-toggle'))return;
  const btn=document.createElement('button');btn.type='button';btn.className='ffl-fold-toggle';
  btn.setAttribute('aria-expanded','false');btn.setAttribute('aria-label',label+' — إظهار القائمة');
  const title=document.createElement('span');title.textContent=label;
  const arrow=document.createElement('span');arrow.className='ffl-fold-arrow';
  arrow.setAttribute('aria-hidden','true');arrow.textContent='⌄';
  btn.append(title,arrow);
  el.prepend(btn);el.classList.add('ffl-folded-card','ffl-collapsed');
  btn.onclick=()=>{
   const expanded=btn.getAttribute('aria-expanded')==='true';
   btn.setAttribute('aria-expanded',String(!expanded));
   btn.setAttribute('aria-label',label+(!expanded?' — إخفاء القائمة':' — إظهار القائمة'));
   el.classList.toggle('ffl-collapsed',expanded);
  };
 }
 for(const [el,label] of panels)fold(el,label);

 const admin=id('staffAdminCard');if(!admin)return;
 const controls=document.createElement('div');controls.className='ffl-staff-quickactions';
 const add=document.createElement('button');add.type='button';add.id='fflAddStaffBtn';
 add.className='ffl-add-staff-btn';add.textContent='➕ إضافة موظف جديد';
 controls.append(add);
 admin.querySelector(':scope > .ffl-fold-toggle')?.after(controls);

 const dialog=document.createElement('dialog');dialog.id='fflStaffDialog';
 dialog.innerHTML='<div class="ffl-dialog-inner"><div class="ffl-dialog-head"><h2>➕ إضافة موظف جديد</h2><button type="button" class="outline" id="fflStaffClose">✕ إغلاق</button></div>'+
 '<p class="muted">للمدير العام فقط. إنشاء حساب دخول مستقل وربط الموظف بدوره وفرعه. كلمة المرور 8 خانات وفق آلية النظام الحالية.</p>'+
 '<form id="fflStaffForm" autocomplete="off"><div class="ffl-staff-grid">'+
 '<label class="ffl-staff-full">الاسم الثنائي أو أكثر<input name="name" required minlength="3" maxlength="150" placeholder="الاسم الكامل"></label>'+
 '<label>رقم الهاتف<input name="phone" required inputmode="tel" maxlength="20" placeholder="77xxxxxxx"></label>'+
 '<label>البريد الإلكتروني (اختياري)<input name="email" type="email" maxlength="254" placeholder="name@example.com"></label>'+
 '<label>الدور الوظيفي<select name="role" required><option value="cashier">كاشير</option><option value="driver">موصل</option><option value="customer_service">خدمة العملاء</option><option value="supervisor">مشرف</option><option value="assembly">نقطة التجميع</option><option value="burger_kitchen">🍔 قسم البرجر</option></select></label>'+
 '<label id="fflStaffBranchWrap">الفرع<select name="branch"></select></label>'+
 '<label id="fflStaffDeskWrap" hidden>وجهة الكاشير<select name="desk"><option value="cairo_first">القاهرة — الفترة الأولى</option><option value="cairo_second">القاهرة — الفترة الثانية</option><option value="sam_mall">سام مول</option><option value="khamseen">الخمسين</option></select></label>'+
 '<label>المؤهل العلمي<input name="qualification" minlength="2" maxlength="150" required placeholder="المؤهل"></label>'+
 '<label class="ffl-staff-full">عنوان الموظف<input name="address" minlength="5" maxlength="240" required placeholder="العنوان التفصيلي"></label>'+
 '<label>العمر<input name="age" type="number" min="16" max="90" required></label>'+
 '<label>الحالة الاجتماعية<select name="marital" required><option value="prefer_not_say">لا أرغب في التحديد</option><option value="single">أعزب/عزباء</option><option value="married">متزوج/متزوجة</option><option value="other">أخرى</option></select></label>'+
 '<label>سنوات الخبرة (اختياري)<input name="experience" type="number" min="0" max="60"></label>'+
 '<label>كلمة المرور الأولية<input name="password" type="password" required minlength="8" maxlength="8" autocomplete="new-password" placeholder="8 خانات"></label>'+
 '<label class="ffl-staff-full ffl-check-row"><input name="verified" type="checkbox" required><span>تحققتُ من أن رقم الهاتف يخص الموظف، وسأُسلّم بيانات الدخول له بشكل آمن.</span></label>'+
 '</div><p id="fflStaffStatus" role="status" aria-live="polite" class="muted"></p>'+
 '<div class="ffl-staff-actions"><button type="submit" class="primary" id="fflStaffSubmit">✓ إنشاء وحفظ الموظف</button><button type="button" class="outline" id="fflStaffCancel">إلغاء</button></div></form></div>';
 document.body.append(dialog);
 const form=id('fflStaffForm'),parts=name=>form.elements.namedItem(name),role=parts('role'),branch=parts('branch'),desk=parts('desk');
 const branchWrap=id('fflStaffBranchWrap'),deskWrap=id('fflStaffDeskWrap'),status=id('fflStaffStatus'),submit=id('fflStaffSubmit');
 const destinations={cairo_first:'cairo',cairo_second:'cairo',sam_mall:'sam_mall',khamseen:'khamseen'};
 function setRole(){
  const r=role.value, needsBranch=['cashier','driver','assembly','burger_kitchen'].includes(r);
  branchWrap.hidden=!needsBranch||r==='cashier';deskWrap.hidden=r!=='cashier';
  branch.required=needsBranch&&r!=='cashier';desk.required=r==='cashier';
 }
 function loadBranches(){
  branch.replaceChildren();
  for(const b of (typeof data!=='undefined'?data?.branches:[])||[])branch.add(new Option(b.name,b.id));
 }
 role.onchange=setRole;
 let submitting=false;
 function close(){if(!submitting)dialog.close()}
 id('fflStaffClose').onclick=close;id('fflStaffCancel').onclick=close;
 add.onclick=()=>{
  if(typeof data==='undefined'||data?.role!=='manager')return toast('هذه العملية للمدير العام فقط');
  loadBranches();form.reset();role.value='cashier';setRole();status.textContent='';
  dialog.showModal();parts('name').focus();
 };
 async function approveApplication(applicationId,employee){
  const session=await client.auth.getSession();
  const token=session?.data?.session?.access_token;
  if(!token)throw Error('انتهت جلسة المدير؛ سجّل الدخول مجددًا');
  const response=await fetch(CONFIG.url.replace(/\/$/,'')+'/functions/v1/ff61-employees',{
   method:'POST',headers:{'Content-Type':'application/json','apikey':CONFIG.key,'Authorization':'Bearer '+token},
   body:JSON.stringify({
    action:'approve',application_id:applicationId,role:employee.role,
    branch_id:employee.branch_id,password:employee.password,phone_ownership_verified:true
   }),cache:'no-store'
  });
  const result=await response.json().catch(()=>({}));
  if(!response.ok||result.ok!==true||!result.user_id)
    throw Error(result.error||'تعذر إنشاء حساب الدخول واعتماد الموظف');
  return result;
 }
 form.onsubmit=async event=>{
  event.preventDefault();
  if(submitting||!form.reportValidity())return;
  if(typeof data==='undefined'||data?.role!=='manager')return toast('إنشاء الموظفين للمدير العام فقط');
  const fullName=String(parts('name').value||'').trim().replace(/\s+/g,' ');
  if(fullName.split(' ').length<2){status.textContent='اكتب الاسم الثنائي على الأقل';return}
  const r=role.value,code=desk.value;
  const b=(typeof data!=='undefined'?data?.branches:[])?.find(x=>
    r==='cashier'?x.code===destinations[code]:x.id===branch.value);
  const needsBranch=['cashier','driver','assembly','burger_kitchen'].includes(r);
  if(needsBranch&&!b){status.textContent='حدد فرعًا صالحًا';return}
  const password=parts('password').value;
  if([...password].length!==8){status.textContent='كلمة المرور يجب أن تكون 8 خانات بالضبط';return}
  if(!parts('verified').checked){status.textContent='أكد التحقق من ملكية رقم الهاتف';return}
  if(!confirm('إنشاء حساب جديد للموظف '+fullName+' بدور '+role.selectedOptions[0].textContent+'؟'))return;
  submitting=true;submit.disabled=true;status.textContent='جاري تجهيز حساب الموظف...';
  let appId=null;
  try{
   const request={
    p_name:fullName,p_phone:parts('phone').value,p_email:parts('email').value,
    p_role:r,p_qualification:parts('qualification').value,p_address:parts('address').value,
    p_age:Number(parts('age').value),p_marital:parts('marital').value,
    p_experience:parts('experience').value===''?null:Number(parts('experience').value)
   };
   const prepared=await rpc('ff_luxe_manager_prepare_staff',request);
   if(!prepared?.ok||!prepared.application_id)throw Error('تعذر تجهيز ملف الموظف');
   appId=prepared.application_id;
   status.textContent='جارٍ إنشاء حساب الدخول وتحديد الصلاحيات...';
   const created=await approveApplication(appId,{role:r,branch_id:needsBranch?b.id:null,password});
   // The existing join approval has already created the Auth user and all role-linked data.
   // Cashier destination assignment uses the existing secure RPC.
   let warning='';
   if(r==='cashier'){
    try{
     const assigned=await rpc('ff_luxe_set_cashier_desk',{p_user:created.user_id,p_desk:code});
     if(assigned?.ok!==true)throw Error('لم يؤكد الخادم ربط الوجهة');
    }catch(error){warning='؛ تنبيه: اربط وجهة الكاشير يدويًا من وجهات الكاشير. '+String(error?.message||error)}
   }
   status.textContent='✅ تم إنشاء حساب الموظف وتفعيل دوره'+warning;
   toast('✅ تم إنشاء حساب '+fullName+(warning?' — تحقق من وجهة الكاشير':''));
   parts('password').value='';
   if(typeof window.ffLuxeReloadCashierDesks==='function')void window.ffLuxeReloadCashierDesks();
   if(typeof loadStaffAdmin==='function')void loadStaffAdmin();
   if(!warning){form.reset();setRole()}
  }catch(error){
   status.textContent='⚠️ '+String(error?.message||error)+
    (appId?' — إذا تعذّر الاعتماد، راجع «طلبات الانضمام» لاستخدام الطلب الذي جهزته الإدارة.':'');
  }finally{submitting=false;submit.disabled=false}
 };
})();