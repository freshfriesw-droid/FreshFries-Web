/* Fresh Fries LUXE: approved security fixes 12, 13, 14 (2026-11-23).
   Keeps the existing order parser, menu shortcuts and operational workflows unchanged.
   TOTP is mandatory before manager/customer-service data loads. No TOTP secret is stored locally. */
(function () {
  'use strict';
  const privileged=new Set(['manager','customer_service']);
  const accessRoles=new Set(['manager','customer_service','supervisor','cashier','driver','assembly']);
  const legacy='freshfries-v38-pilot-session';
  const storageKey='freshfries-v38-security-session';
  // The old persistent token may belong to a privileged account. Never restore it.
  try { localStorage.removeItem(legacy); localStorage.removeItem(storageKey); } catch (_) {}
  const storage = {
    getItem:key => { try { return sessionStorage.getItem(key); } catch (_) { return null; } },
    setItem:(key,val) => { try { sessionStorage.setItem(key,val); } catch (_) {} },
    removeItem:key => { try { sessionStorage.removeItem(key); } catch (_) {} }
  };
  let currentClient=null,currentRole='',lastActivity=Date.now(),idleTimer=null,transitioning=false;
  const $=id=>document.getElementById(id);
  function safe(message){return String(message?.message||message||'تعذر إكمال العملية');}
  async function log(event,details){
    if(!currentClient)return false;
    const {error}=await currentClient.rpc('ff_security_login_event',{p_event:event,p_details:details||{}});
    if(error)throw new Error('تعذر حفظ سجل الدخول: '+safe(error));
    return true;
  }
  function element(tag,attributes,text){
    const node=document.createElement(tag);
    Object.entries(attributes||{}).forEach(([name,value])=>node.setAttribute(name,value));
    if(text!==undefined)node.textContent=text;
    return node;
  }
  function makeDialog(){
    const overlay=element('div',{id:'ff-sec-mfa-dialog',role:'dialog','aria-modal':'true','aria-labelledby':'ff-sec-mfa-title'});
    overlay.style.cssText='position:fixed;inset:0;z-index:2147483640;background:#0b0b0be9;display:flex;align-items:center;justify-content:center;padding:14px;overflow:auto;direction:rtl';
    const body=element('section',{},'');
    body.style.cssText='background:#fff;color:#171717;border-top:6px solid #d51e2c;border-radius:17px;max-width:475px;width:100%;padding:21px;box-shadow:0 12px 36px #0006;max-height:90vh;overflow:auto';
    body.append(element('h2',{id:'ff-sec-mfa-title'},'🔐 التحقق الثنائي الإلزامي'));
    body.append(element('p',{},'لحماية بيانات المطعم يجب إدخال رمز تطبيق المصادقة قبل فتح حساب المدير أو خدمة العملاء.'));
    const content=element('div');body.append(content);
    const form=element('form',{autocomplete:'off'});
    const input=element('input',{type:'text',inputmode:'numeric',autocomplete:'one-time-code',pattern:'[0-9٠-٩]{6}',maxlength:'6',placeholder:'رمز المصادقة المكون من 6 أرقام','aria-label':'رمز المصادقة'});
    input.style.cssText='width:100%;padding:12px;margin:12px 0;border:1px solid #aaa;border-radius:8px;direction:ltr;text-align:center;letter-spacing:3px';
    const result=element('p',{role:'status','aria-live':'polite'},'');
    const submit=element('button',{type:'submit'},'تحقق وفتح الحساب');
    submit.style.cssText='width:100%;padding:12px;background:#d51e2c;color:white;border:0;border-radius:8px;font-weight:bold';
    const cancel=element('button',{type:'button'},'إلغاء وتسجيل الخروج');
    cancel.style.cssText='width:100%;padding:9px;margin-top:9px;border:1px solid #bbb;border-radius:8px;background:white';
    form.append(input,submit,result,cancel);body.append(form);overlay.append(body);document.body.append(overlay);
    input.focus();
    return {overlay,content,form,input,result,submit,cancel};
  }
  async function ensureMfa(client,role){
    if(!privileged.has(role))return;
    currentClient=client;
    const assurance=await client.auth.mfa.getAuthenticatorAssuranceLevel();
    if(assurance.error)throw assurance.error;
    if(assurance.data?.currentLevel==='aal2')return;
    const factors=await client.auth.mfa.listFactors();
    if(factors.error)throw factors.error;
    const verified=(factors.data?.totp||[]).filter(f=>f.status==='verified');
    const isEnrollment=verified.length===0;
    let factorId=verified[0]?.id;
    let enrollment=null;
    if(isEnrollment){
      const enroll=await client.auth.mfa.enroll({factorType:'totp',friendlyName:'Fresh Fries LUXE'});
      if(enroll.error)throw enroll.error;
      enrollment=enroll.data;factorId=enrollment?.id;
    }
    if(!factorId)throw new Error('تعذر تجهيز عامل التحقق الثنائي');
    const ui=makeDialog();
    if(isEnrollment){
      ui.content.append(element('p',{},'افتح تطبيق مصادقة مثل Google Authenticator، وامسح الرمز التالي مرة واحدة. احتفظ برموز الاسترداد وفق سياسة الإدارة.'));
      if(enrollment?.totp?.qr_code){
        const img=element('img',{src:enrollment.totp.qr_code,alt:'رمز QR لإعداد تطبيق المصادقة'});
        img.style.cssText='display:block;width:190px;height:190px;max-width:100%;margin:12px auto';ui.content.append(img);
      }
      if(enrollment?.totp?.secret){
        ui.content.append(element('p',{},'المفتاح اليدوي عند تعذر المسح:'));
        const code=element('code',{},enrollment.totp.secret);code.style.cssText='direction:ltr;display:block;user-select:all;overflow-wrap:anywhere;background:#eee;padding:9px;border-radius:7px';ui.content.append(code);
      }
    }else{
      ui.content.append(element('p',{},'أدخل الرمز المتجدد من تطبيق المصادقة المسجل لهذا الحساب.'));
    }
    try{
      await new Promise((resolve,reject)=>{
        let running=false;
        ui.form.addEventListener('submit',async e=>{
          e.preventDefault();if(running)return;
          const digits=ui.input.value.replace(/[٠-٩]/g,c=>String(c.charCodeAt(0)-1632)).trim();
          if(!/^[0-9]{6}$/.test(digits)){ui.result.textContent='أدخل 6 أرقام صحيحة.';return;}
          running=true;ui.submit.disabled=true;ui.result.textContent='جارٍ التحقق من الرمز...';
          try {
            const check=await client.auth.mfa.challengeAndVerify({factorId,code:digits});
            if(check.error)throw check.error;
            const aal=await client.auth.mfa.getAuthenticatorAssuranceLevel();
            if(aal.error||aal.data?.currentLevel!=='aal2')throw new Error('لم تُرفع درجة حماية الحساب إلى المستوى المطلوب');
            await log(isEnrollment?'mfa_enrolled':'mfa_verified');
            resolve(true);
          }catch(error){
            ui.result.textContent='لم ينجح التحقق: '+safe(error);
            ui.input.value='';ui.input.focus();
          }finally{running=false;ui.submit.disabled=false;}
        });
        ui.cancel.addEventListener('click',async()=>{
          try{await client.auth.signOut({scope:'local'});}catch(_){}
          reject(new Error('تم إلغاء التحقق الثنائي وتسجيل الخروج.'));
        });
      });
    }finally{ui.overlay.remove();}
  }
  function clearProtected(){
    currentRole='';currentClient=null;transitioning=false;
    if(idleTimer){clearInterval(idleTimer);idleTimer=null;}
    for(const id of ['ff-sec-access-badge','ff-sec-audit-button','ff-sec-audit-panel']){
      const node=$(id);if(node)node.remove();
    }
  }
  async function secureLogout(reason){
    if(transitioning||!currentClient)return;
    transitioning=true;
    try{await log(reason);}catch(err){console.warn('Fresh Fries audit:',safe(err));}
    try{await currentClient.auth.signOut({scope:'local'});}catch(err){console.warn('Fresh Fries signout:',safe(err));}
    clearProtected();
    if(typeof resetUI==='function')resetUI();
    const status=$('loginStatus');if(status)status.textContent=reason==='idle_logout'?'انتهت الجلسة بعد 30 دقيقة دون نشاط. أعد تسجيل الدخول.':'تم إنهاء الوردية وتسجيل الخروج.';
  }
  function managerAudit(){
    if(currentRole!=='manager'||!currentClient)return;
    let panel=$('ff-sec-audit-panel');
    if(panel){panel.remove();return;}
    panel=element('section',{id:'ff-sec-audit-panel',class:'card','aria-label':'سجل الاطلاع على بيانات العملاء'});
    const heading=element('h2',{},'🔎 رقابة الاطلاع على العملاء');
    const description=element('p',{},'سجل القراءة والتصدير: الموظف، نوع العملية، رقم العميل إن وجد، والتاريخ. متاح للمدير فقط.');
    const reload=element('button',{type:'button'},'تحديث السجل');
    const close=element('button',{type:'button'},'إغلاق');
    const rows=element('div',{role:'status','aria-live':'polite'});
    panel.append(heading,description,reload,close,rows);
    const main=document.querySelector('main');if(!main)return;
    main.prepend(panel);panel.scrollIntoView({block:'start',behavior:'smooth'});
    close.addEventListener('click',()=>panel.remove());
    async function render(){
      rows.replaceChildren();rows.textContent='جارٍ تحميل عمليات الاطلاع...';
      try{
        const {data,error}=await currentClient.rpc('ff_customer_views_manager',{p_limit:100});
        if(error)throw error;
        rows.replaceChildren();
        if(!data?.length){rows.textContent='لا توجد سجلات اطلاع بعد.';return;}
        const labels={directory_search:'بحث في دليل العملاء',customer_notes:'فتح ملاحظات العميل',customer_profile:'فتح ملف العميل',archive_view:'عرض أرشيف الطلبات',csv_export:'تصدير CSV'};
        for(const record of data){
          const line=element('article',{class:'item'},'');
          const title=element('strong',{},labels[record.action]||record.action);
          const info=element('p',{class:'muted'},(record.actor_name||record.actor_role)+' · '+new Date(record.created_at).toLocaleString('ar-YE')+(record.phone?' · '+record.phone:''));
          line.append(title,info);rows.append(line);
        }
      }catch(err){rows.textContent='تعذر جلب السجل: '+safe(err);}
    }
    reload.addEventListener('click',render);void render();
  }
  function afterLogin(client,role){
    if(!accessRoles.has(role))return;
    currentClient=client;currentRole=role;lastActivity=Date.now();
    const header=document.querySelector('header')||document.querySelector('.head');
    if(header&&privileged.has(role)){
      const badge=element('span',{id:'ff-sec-access-badge',role:'status'},role==='manager'?'🔐 وصول مركزي · المدير':'🔐 وصول مركزي · خدمة العملاء');
      badge.style.cssText='display:inline-block;padding:7px;border:1px solid #fff6;border-radius:9px;color:white;background:#831620;font-size:12px';
      header.append(badge);
      if(role==='manager'){
        const btn=element('button',{id:'ff-sec-audit-button',type:'button'},'🔎 سجل الاطلاع');
        btn.addEventListener('click',managerAudit);
        header.append(btn);
      }
    }
    if(privileged.has(role)){
      const logout=$('logoutBtn');if(logout)logout.textContent='إنهاء الوردية والخروج';
      idleTimer=setInterval(()=>{
        if(currentRole&&privileged.has(currentRole)&&Date.now()-lastActivity>=30*60*1000)void secureLogout('idle_logout');
      },15000);
    }
    void log('sign_in').catch(err=>console.warn('Fresh Fries login log:',safe(err)));
  }
  for(const type of ['pointerdown','keydown','touchstart']){
    document.addEventListener(type,()=>{if(currentRole)lastActivity=Date.now();},{capture:true,passive:true});
  }
  document.addEventListener('visibilitychange',()=>{
    if(!document.hidden&&privileged.has(currentRole)&&Date.now()-lastActivity>=30*60*1000)void secureLogout('idle_logout');
  });
  document.addEventListener('click',e=>{
    if(!currentRole||!currentClient||transitioning)return;
    const logout=e.target.closest('#logoutBtn');
    if(logout&&privileged.has(currentRole)){
      e.preventDefault();e.stopImmediatePropagation();
      void secureLogout('shift_logout');return;
    }
    const target=e.target.closest('button');
    if(!target||!/(CSV|تصدير)/i.test(target.textContent||''))return;
    if(target.dataset.ffSecValidated==='yes'){delete target.dataset.ffSecValidated;return;}
    if(target.disabled)return;
    e.preventDefault();e.stopImmediatePropagation();
    if(!confirm('تنبيه أمني: سيخرج هذا الملف من نظام المطعم. تأكد من إرساله إلى جهة مخولة فقط. هل تريد المتابعة؟'))return;
    const c=currentClient,r=currentRole;
    void (async()=>{
      try{
        const {error}=await c.rpc('ff_log_customer_view',{
          p_action:'csv_export',p_details:{section:String(target.id||'export').slice(0,80)}
        });
        if(error)throw error;
        if(currentClient!==c||currentRole!==r||!target.isConnected)return;
        target.dataset.ffSecValidated='yes';target.click();
      }catch(err){alert('تعذر توثيق عملية التصدير، لم يتم تنزيل البيانات: '+safe(err));}
    })();
  },true);
  window.addEventListener('ff-luxe-session-reset',clearProtected);
  window.ffSec={storage,storageKey,ensureMfa,afterLogin,secureLogout};
})();