/* DEC-10 phase 1: text delegation only. No permission changes to operational actions. */
(()=>{
'use strict';
const actor=()=>typeof user!=='undefined'&&user?.id&&typeof data!=='undefined'&&data?.role?user.id:'';
const manager=()=>!!actor()&&data.role==='manager';
const capLabels={view:'مشاهدة',edit:'تحرير المسودة',preview:'معاينة',review:'مراجعة'};
const screens={notices:'التنبيهات التشغيلية',dashboard:'الرئيسية',reports:'التقارير',orders:'إدخال الطلبات',catalog:'المنيو والعروض',customers:'العملاء',staff:'الموظفون والصلاحيات',cases:'الشكاوى والتظلمات',messages:'الرسائل',archive:'الأرشيف',ratings:'التقييمات',assembly:'نقطة التجميع',reservations:'الحجوزات'};
const roles={manager:'المدير العام',supervisor:'المشرف',customer_service:'خدمة العملاء',cashier:'الكاشير',driver:'الموصل',assembly:'نقطة التجميع',burger_kitchen:'مطبخ البرجر'};
const dialog=document.createElement('dialog');dialog.id='ff82Delegation';dialog.dir='rtl';dialog.setAttribute('aria-labelledby','ff82Title');
dialog.innerHTML='<div class="sectionbar"><h2 id="ff82Title">التفويض المتدرج للمحتوى</h2><button type="button" data-d-close>إغلاق</button></div><p>هذا التفويض يخص النصوص فقط، ولا يمنح أي صلاحية تشغيلية أو نشر نهائي.</p>'+
 '<section data-d-manager hidden><label>الحساب والفرع<select data-d-account></select></label><label>الواجهة<select data-d-screen></select></label><fieldset><legend>صلاحيات التفويض</legend><div data-d-caps></div></fieldset>'+
 '<label>وقت البدء<input type="datetime-local" data-d-start></label><label>وقت الانتهاء<input type="datetime-local" data-d-end></label>'+
 '<p>إنشاء تفويض جديد للحساب يلغي التفويض السابق؛ لا تتراكم الصلاحيات.</p><button type="button" data-d-grant>اعتماد التفويض</button>'+
 '<label>سجل التفويضات<select data-d-grants></select></label><button type="button" data-d-revoke>إلغاء التفويض المحدد</button>'+
 '<details><summary>سجل التدقيق</summary><div data-d-audit></div></details><details><summary>مراجعات مسودة محتوى</summary><label>رقم المسودة<input type="number" min="1" data-d-revision></label><button type="button" data-d-read-reviews>عرض المراجعات</button><div data-d-reviews></div></details></section>'+
 '<section data-d-worker hidden><p data-d-scope></p><label>العنصر<select data-d-key></select></label><label>الإصدارات<select data-d-history></select></label><p data-d-body></p>'+
 '<section data-d-preview hidden><h3>معاينة النص</h3><p data-d-original></p><p data-d-sample></p></section>'+
 '<section data-d-edit hidden><label>مسودة نص جديد<textarea data-d-text maxlength="180" rows="3"></textarea></label><p data-d-format-help hidden></p><button type="button" data-d-save>حفظ مسودة للمدير</button></section>'+
 '<section data-d-review hidden><label>ملاحظة المراجعة<textarea data-d-note maxlength="500" rows="3"></textarea></label><button type="button" data-d-send-review>رفع المراجعة إلى المدير</button></section></section>'+
 '<p data-d-status role="status" aria-live="polite"></p>';
document.body.append(dialog);
const q=n=>dialog.querySelector('[data-d-'+n+']');
const button=document.createElement('button');button.type='button';button.id='ff82Open';button.className='ffx-outline-light';button.textContent='التفويض المتدرج';button.hidden=true;
document.querySelector('.ffx-hero-actions')?.append(button);
let grant=null,context='',last=0,request=0,session=0,busy=false,accounts=[],grants=[],catalog=[],history=[];
function enabled(cap){return !!grant&&grant.capabilities.includes(cap)&&Date.parse(grant.starts_at)<=Date.now()&&Date.parse(grant.ends_at)>Date.now()}
function status(s){q('status').textContent=s}
function lines(node,items){node.replaceChildren(...items.map(s=>{const p=document.createElement('p');p.textContent=s;return p}))}
function grantWindow(g){
 const now=Date.now();
 const state=g.revoked_at?'ملغى':now<Date.parse(g.starts_at)?'مجدول':now>=Date.parse(g.ends_at)?'منتهي':'ضمن المدة';
 const format=t=>new Date(t).toLocaleString('ar-YE');
 return state+' · من '+format(g.starts_at)+' إلى '+format(g.ends_at);
}
function localDate(t){const d=new Date(t);d.setMinutes(d.getMinutes()-d.getTimezoneOffset());return d.toISOString().slice(0,16)}
function options(el,items){el.replaceChildren(...items.map(([value,label])=>new Option(label,String(value))))}
function clear(){request++;session++;grant=null;context='';last=0;busy=false;accounts=[];grants=[];catalog=[];history=[];button.hidden=true;if(dialog.open)dialog.close();for(const n of ['account','grants','key','history'])q(n).replaceChildren();for(const n of ['audit','reviews','body','scope','original','sample','status'])q(n).textContent='';for(const n of ['text','note','revision'])q(n).value=''}
function key(){return actor()+'|'+(data?.role||'')}
async function sync(force=false){
 const who=actor();if(!who){if(context)clear();return}
 const k=key();if(k!==context){clear();context=k}
 if(manager()){button.hidden=false;return}
 if(grant&&!enabled(grant.capabilities[0])){grant=null;button.hidden=true;invalidateDialog()}
 if(!force&&Date.now()-last<15000)return;
 last=Date.now();const seq=++request;
 try{const rows=await rpc('ff82_my_grant');if(seq!==request||key()!==k)return;const next=rows?.[0]||null;const changed=grant?.id!==next?.id;grant=next&&next.role_scope===data.role?next:null;button.hidden=!grant;if(dialog.open&&(!grant||changed))invalidateDialog()}
 catch{if(seq===request&&key()===k){grant=null;button.hidden=true;invalidateDialog()}}
}
function guard(token,who){return dialog.open&&token===session&&who===actor()&&context===key()}
function controls(){for(const el of dialog.querySelectorAll('button:not([data-d-close]),input,select,textarea'))el.disabled=busy}
async function run(fn){if(busy||!actor())return;const token=session,who=actor();busy=true;controls();try{await fn(token,who)}catch(e){if(guard(token,who))status(e.message||'تعذر تنفيذ الإجراء')}finally{if(guard(token,who)){busy=false;controls()}}}
for(const [cap,label] of Object.entries(capLabels)){const box=document.createElement('label'),input=document.createElement('input');input.type='checkbox';input.value=cap;input.checked=cap==='view';box.append(input,document.createTextNode(label));q('caps').append(box)}
options(q('screen'),Object.entries(screens));
async function managerRefresh(token,who){
 const [a,g,audit]=await Promise.all([rpc('ff82_manager_accounts'),rpc('ff82_manager_grants'),rpc('ff82_manager_audit')]);
 if(!guard(token,who)||!manager())return;
 accounts=a||[];grants=g||[];
 options(q('account'),accounts.map((x,i)=>[i,x.display_name+' · '+(roles[x.role]||x.role)+' · '+x.branch_name]));
 options(q('grants'),grants.map(x=>[x.id,'#'+x.id+' · '+(accounts.find(a=>a.user_id===x.recipient&&a.branch_id===x.branch_id)?.display_name||x.recipient)+' · '+(screens[x.screen]||x.screen)+' · '+grantWindow(x)]));
 lines(q('audit'),(audit||[]).map(x=>'#'+x.id+' · '+new Date(x.created_at).toLocaleString('ar-YE')+' · '+x.action+' · '+x.outcome+' · '+x.reason+' · '+x.actor_id));
}
function selection(){return history.find(x=>String(x.id)===q('history').value)}
function preview(){
 const row=selection(),c=catalog.find(x=>x.key===q('key').value),rich=['orders.guidance','reports.guidance'].includes(c?.key),notice=['notices.delayed','notices.reminder'].includes(c?.key);
 q('text').maxLength=rich?1000:180;
 q('format-help').hidden=!(rich||notice);
 q('format-help').textContent=rich?'يمكن استخدام **خط عريض** وسطور قائمة تبدأ بشرطة. تُراجع المسودة قبل النشر.':notice?'المتغير المسموح به: {order_number}. تستخدم المعاينة رقمًا تجريبيًا فقط.':'';
 q('body').textContent=row?'#'+row.id+' · '+(row.published_at?'منشور':'مسودة')+' · '+(row.body??'النص الأصلي'):'لا توجد إصدارات ضمن نطاقك';
 q('original').textContent=c?.original||'';
 const sample=q('text').value||row?.body||c?.original||'—';
 q('sample').textContent=notice?sample.replaceAll('{order_number}','990001 (تجريبي)'):sample;
}
async function loadHistory(token,who){const k=q('key').value;history=[];options(q('history'),[]);if(k){const rows=await rpc('ff82_delegate_history',{p_key:k});if(!guard(token,who)||q('key').value!==k)return;history=rows||[];options(q('history'),history.map(r=>[r.id,'#'+r.id+' · '+(r.published_at?'منشور':'مسودة')]))}preview()}
async function workerRefresh(token,who){
 const rows=await rpc('ff82_my_grant');if(!guard(token,who))return;grant=rows?.[0]?.role_scope===data.role?rows[0]:null;
 if(!grant){button.hidden=true;invalidateDialog();return}
 q('scope').textContent=(roles[grant.role_scope]||grant.role_scope)+' · '+(data.branches?.find(b=>b.id===grant.branch_id)?.name||grant.branch_id)+' · '+(screens[grant.screen]||grant.screen)+' · ينتهي '+new Date(grant.ends_at).toLocaleString('ar-YE');
 q('edit').hidden=!enabled('edit');q('review').hidden=!enabled('review');q('preview').hidden=!enabled('preview');
 const items=await rpc('ff82_delegate_catalog');if(!guard(token,who))return;catalog=items||[];options(q('key'),catalog.map(c=>[c.key,c.label]));await loadHistory(token,who)
}
button.onclick=()=>{if(!actor()||context!==key()||(!manager()&&(!grant||!enabled(grant.capabilities[0]))))return;session++;status('');q('manager').hidden=!manager();q('worker').hidden=manager();q('start').value=localDate(Date.now());q('end').value=localDate(Date.now()+3600000);dialog.showModal();void run(manager()?managerRefresh:workerRefresh)};
q('grant').onclick=()=>void run(async(token,who)=>{if(!manager())return;const a=accounts[Number(q('account').value)],caps=Array.from(q('caps').querySelectorAll('input:checked'),x=>x.value),start=new Date(q('start').value),end=new Date(q('end').value);if(!q('account').value||!a||!caps.length||!Number.isFinite(+start)||!Number.isFinite(+end)||end<=start||end<=new Date()){status('تحقق من الحساب والصلاحيات ووقت البدء والانتهاء');return}if(!confirm('اعتماد التفويض لهذا الحساب وإلغاء تفويضه السابق؟'))return;const id=await rpc('ff82_set_grant',{p_recipient:a.user_id,p_branch:a.branch_id,p_screen:q('screen').value,p_capabilities:caps,p_start:start.toISOString(),p_end:end.toISOString()});if(guard(token,who)){await managerRefresh(token,who);status('تم اعتماد التفويض #'+id)}});
q('revoke').onclick=()=>void run(async(token,who)=>{if(!manager()||!q('grants').value)return;if(!confirm('إلغاء التفويض المحدد؟'))return;const ok=await rpc('ff82_revoke_grant',{p_id:Number(q('grants').value)});if(guard(token,who)){await managerRefresh(token,who);status(ok?'أُلغي التفويض':'التفويض غير نشط')}});
q('read-reviews').onclick=()=>void run(async(token,who)=>{if(!manager()||!q('revision').value)return;const rows=await rpc('ff82_manager_reviews',{p_revision:Number(q('revision').value)});if(guard(token,who))lines(q('reviews'),(rows||[]).map(x=>x.note+' · '+x.reviewer+' · '+new Date(x.created_at).toLocaleString('ar-YE')))});
q('key').onchange=()=>{q('text').value='';q('note').value='';void run(loadHistory)};q('history').onchange=preview;q('text').oninput=preview;
q('save').onclick=()=>void run(async(token,who)=>{if(!enabled('edit')){status('التفويض غير نشط');return}const result=await rpc('ff82_delegate_draft',{p_key:q('key').value,p_body:q('text').value});if(guard(token,who)){if(result?.ok){q('text').value='';await loadHistory(token,who);status('حُفظت المسودة #'+result.revision+'؛ النشر للمدير فقط')}else status('رفض الخادم التعديل: '+(result?.reason||'غير مصرح'))}});
q('send-review').onclick=()=>void run(async(token,who)=>{if(!enabled('review')||!selection())return;const result=await rpc('ff82_delegate_review',{p_revision:Number(q('history').value),p_note:q('note').value});if(guard(token,who)){if(result?.ok)q('note').value='';status(result?.ok?'تم إرسال المراجعة':'رفض الخادم المراجعة')}});
function invalidateDialog(){session++;busy=false;history=[];catalog=[];accounts=[];grants=[];for(const n of ['account','grants','key','history'])q(n).replaceChildren();for(const n of ['audit','reviews','body','scope','original','sample','status'])q(n).textContent='';for(const n of ['text','note','revision'])q(n).value='';controls();if(dialog.open)dialog.close()}
q('close').onclick=invalidateDialog;dialog.onclose=()=>{if(!dialog.open)invalidateDialog()};
window.addEventListener('ff-luxe-session-reset',clear);
window.ffContentDelegation={sync};
})();
