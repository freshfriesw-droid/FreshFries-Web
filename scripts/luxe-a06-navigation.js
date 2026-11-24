/* A06 — navigation presentation only. Existing authorized RPC and operational controls remain the single action source. */
(()=>{"use strict";
const $=id=>document.getElementById(id),body=document.body,media=matchMedia("(max-width:850px)");
const barModes=new Set(["labels","icons","wide","floating","compact"]);
const specialRole=()=>typeof ffV12AssemblyActive!=="undefined"&&ffV12AssemblyActive?"assembly":window.ffBurgerActive?.()?"burger_kitchen":null;
const identity=()=>{const actor=typeof user!=="undefined"&&user?.id;if(!actor)return null;const role=specialRole()||(typeof data!=="undefined"?data?.role:null);if(!role)return null;
 const branches=typeof data!=="undefined"&&Array.isArray(data?.branches)?data.branches:[];
 const branch=role==="assembly"?ffV12AssemblyPayload?.branch?.id||null:role==="burger_kitchen"?null:$("ffx-branch")?.value||(branches.length===1?branches[0].id:null);
 return {actor,role,branch,branches,device:media.matches?"mobile":"desktop",key:[actor,role,branch||"",media.matches?"mobile":"desktop"].join("|")};
};
const labels={manager:"المدير العام",supervisor:"المشرف",customer_service:"خدمة العملاء",cashier:"الكاشير",driver:"الموصل",assembly:"نقطة التجميع",burger_kitchen:"مطبخ البرجر"};
const node=(tag,text)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;return e};
const special=node("nav");special.id="ffA06SpecialNav";special.setAttribute("aria-label","تنقل واجهة العمل");special.hidden=true;body.append(special);
const more=node("dialog");more.id="ffA06SpecialMore";more.setAttribute("aria-label","المزيد من الإجراءات");more.innerHTML='<div class="sectionbar"><h3>المزيد</h3><button type="button" id="ffA06MoreClose" class="outline">إغلاق</button></div><div id="ffA06MoreItems" class="actions"></div>';body.append(more);
$("ffA06MoreClose").onclick=()=>more.close();
let opener=null,epoch=0,last=0,scope="",config=null,pending=false,specialSig="",specialActive="";
const defaultConfig=()=>({revision:null,mode:"accordion",drawer_width:280,bar:null});
function scrollTo(el){if(!el)return;for(let p=el;p;p=p.parentElement){if(p.matches("details"))p.open=true;if(p.matches(".ff-menu-closed,.ffl-collapsed"))p.querySelector(':scope > .ff-menu-toggle[aria-expanded="false"],:scope > .ffl-fold-toggle[aria-expanded="false"]')?.click()}el.scrollIntoView({block:"start",behavior:matchMedia("(prefers-reduced-motion: reduce)").matches?"auto":"smooth"})}
function runTarget(selector){const el=document.querySelector(selector);if(!el||el.disabled||el.closest("[hidden],.hidden"))return false;scrollTo(el);el.click();return true}
const actions={
 assembly:[
 ["all","الجارية","▤",()=>assemblyFilter("all")],["preparing","التحضير","◷",()=>assemblyFilter("preparing")],["ready","جاهزة","✓",()=>assemblyFilter("ready")],["delivery","التسليم","⇥",()=>assemblyFilter("ready")]],
 burger_kitchen:[
 ["sent","جديدة","▤",()=>runTarget('[data-ff-burger-filter="sent"]')],["preparing","التحضير","◷",()=>runTarget('[data-ff-burger-filter="preparing"]')],["finished","جاهزة","✓",()=>runTarget("#ffBurgerViewFinished")],["late","التنبيهات","!",()=>runTarget('[data-ff-burger-filter="late"]')]]
};
function assemblyFilter(key){if(typeof ffV12AssemblyActive==="undefined"||!ffV12AssemblyActive)return;if(!ffV12AssemblyOpened)$("ffV12Toggle")?.click();const b=document.querySelector('[data-assembly-filter="'+key+'"]');if(b){b.click();scrollTo(b)}}
function renderSpecial(s){
 const role=s?.role,rows=actions[role];
 special.hidden=!rows;if(!rows){specialSig="";special.replaceChildren();if(more.open)more.close();return}
 const signature=s.actor+":"+role;
 if(signature!==specialSig){
 specialSig=signature;specialActive=rows[0][0];special.replaceChildren();
 for(const [key,label,ico,action] of [...rows,["more","المزيد","⋯",()=>openMore(s)]]){
 const b=node("button");b.type="button";b.dataset.key=key;b.setAttribute("aria-label",label);b.title=label;
 const icon=node("span",ico);icon.className="ff-a06-symbol";icon.setAttribute("aria-hidden","true");const name=node("span",label);name.className="ff-a06-label";b.append(icon,name);
 b.onclick=()=>{if(identity()?.actor!==s.actor||identity()?.role!==role)return;if(key!=="more")specialActive=key;action();markSpecial()};special.append(b);
 }}
 markSpecial();
}
function markSpecial(){for(const b of special.querySelectorAll("button")){const on=b.dataset.key===specialActive;b.classList.toggle("active",on);if(on)b.setAttribute("aria-current","location");else b.removeAttribute("aria-current")}}
function openMore(s){if(identity()?.actor!==s.actor||identity()?.role!==s.role)return;opener=document.activeElement;const box=$("ffA06MoreItems");box.replaceChildren();
 const list=s.role==="assembly"?[["فتح أو إغلاق نقطة التجميع","#ffV12Toggle"],["تحديث الطلبات","#ffV12Refresh"],["أوامر البرجر","#ffV12BurgerOpen"],["النغمات","#ff66AssemblySoundSettings"],["تسجيل الخروج","#ffV12Logout"]]:[["جميع الطلبات",'[data-ff-burger-filter="all"]'],["تحديث الطلبات","#ffBurgerKitchenRefresh"],["الإشعارات","#ffBurgerKitchenNotifications"],["تسجيل الخروج","#ffBurgerKitchenLogout"]];
 for(const [label,selector]of list){const b=node("button",label);b.type="button";b.className="outline";b.onclick=()=>{more.close();if(s.role==="assembly"&&["#ffV12Refresh","#ffV12BurgerOpen","#ff66AssemblySoundSettings"].includes(selector)&&!ffV12AssemblyOpened)$("ffV12Toggle").click();runTarget(selector)};box.append(b)}
 more.showModal();
}
more.addEventListener("close",()=>{if(opener?.isConnected)opener.focus({preventScroll:true});opener=null;$("ffA06MoreItems").replaceChildren()});
function apply(s,next){const previous=config;config=next||defaultConfig();window.ffA06NavConfig=config;
 const width=Math.min(300,Math.max(260,Number(config.drawer_width)||280));body.style.setProperty("--ff-a06-drawer-width",width+"px");
 if(config.bar&&barModes.has(config.bar))body.dataset.ffA06Bar=config.bar;else delete body.dataset.ffA06Bar;
 if(JSON.stringify(previous)!==JSON.stringify(config)&&s)window.dispatchEvent(new Event("ff-a06-navigation-config"));
}
function clear(){epoch++;pending=false;scope="";last=0;config=null;delete window.ffA06NavConfig;delete body.dataset.ffA06Bar;body.style.removeProperty("--ff-a06-drawer-width");special.hidden=true;special.replaceChildren();specialSig="";if(more.open)more.close();if(admin.open)admin.close();$("ffA06ScopeLabel").textContent=""}
async function sync(force=false){
 const s=identity();if(!s){if(scope)clear();return}
 if(s.key!==scope){scope=s.key;epoch++;pending=false;last=0;apply(s,defaultConfig());if(admin.open&&s.role!=="manager")admin.close()}
 renderSpecial(s);
 const b=s.branches.find(x=>x.id===s.branch);$("ffA06ScopeLabel").textContent=(labels[s.role]||s.role)+" · "+(b?.name||(s.role==="assembly"?$("ffV12BranchTitle")?.textContent:s.role==="burger_kitchen"?$("ffBurgerKitchenBranch")?.textContent:"الفروع المسموحة")||"");
 $("ffA06CentralNavBtn").hidden=s.role!=="manager";
 if(pending||(!force&&Date.now()-last<30000))return;pending=true;last=Date.now();const e=epoch;
 try{const r=await rpc("ff_a06_nav_scope",{p_branch:s.branch,p_device:s.device});if(e!==epoch||identity()?.key!==s.key)return;if(r?.role===s.role&&["accordion","flat"].includes(r.mode))apply(s,r)}catch{/* Existing local/default navigation remains available if settings cannot load. */}finally{if(e===epoch)pending=false}
}
// Central policy editor is independent of operational records and role permissions.
const admin=node("dialog");admin.id="ffA06CentralNav";admin.setAttribute("aria-label","الإعداد المركزي للتنقل");admin.innerHTML='<div class="sectionbar"><h3>إعداد التنقل المركزي</h3><button id="ffA06CentralClose" type="button" class="outline">إغلاق</button></div><p class="muted">الأكثر تحديدًا للدور والفرع والجهاز يفوز، ثم الأحدث. وضع القائمة الشخصي يمكن استعادته إلى الإعداد المركزي. الإعداد لا يمنح أي صلاحية.</p><form id="ffA06NavForm"><label>الدور<select name="role"></select></label><label>الفرع<select name="branch"></select></label><label>الجهاز<select name="device"><option value="all">جميع الأجهزة</option><option value="mobile">الهاتف</option><option value="desktop">الكمبيوتر</option></select></label><label>القائمة<select name="mode"><option value="accordion">قابلة للطي</option><option value="flat">مفتوحة</option></select></label><label>عرض الدرج (بكسل)<input name="width" type="number" value="280" min="260" max="300" required></label><label>شريط الهاتف<select name="bar"><option value="">من التصميم المنشور</option><option value="labels">أيقونات وتسميات</option><option value="icons">أيقونات فقط</option><option value="wide">عريض</option><option value="floating">عائم</option><option value="compact">مختصر</option></select></label><label>سبب التغيير<input name="reason" minlength="5" maxlength="500" required></label><button type="submit" class="primary">حفظ الإعداد المركزي</button></form><p id="ffA06NavStatus" role="status"></p>';body.append(admin);
const form=$("ffA06NavForm");form.elements.role.append(new Option("جميع الأدوار","all"));for(const [k,v]of Object.entries(labels))form.elements.role.add(new Option(v,k));
const centralBtn=node("button","إعداد التنقل المركزي");centralBtn.type="button";centralBtn.className="outline";centralBtn.id="ffA06CentralNavBtn";centralBtn.hidden=true;$("ffx-preferences").querySelector(".ffx-pref-scroll").append(centralBtn);
centralBtn.onclick=()=>{const s=identity();if(s?.role!=="manager")return;form.elements.branch.replaceChildren(new Option("كل الفروع",""),...s.branches.map(b=>new Option(b.name,b.id)));$("ffA06NavStatus").textContent="";admin.showModal()};
$("ffA06CentralClose").onclick=()=>admin.close();
form.onsubmit=async e=>{e.preventDefault();const s=identity();if(s?.role!=="manager")return;const v=Object.fromEntries(new FormData(form)),button=form.querySelector("button[type=submit]");button.disabled=true;const token=epoch;try{await rpc("ff_a06_nav_save",{p_role:v.role,p_branch:v.branch||null,p_device:v.device,p_mode:v.mode,p_width:Number(v.width),p_bar:v.bar||null,p_reason:v.reason.trim()});if(token!==epoch||identity()?.actor!==s.actor)return;$("ffA06NavStatus").textContent="تم حفظ الإعداد المركزي.";form.elements.reason.value="";await sync(true)}catch(err){if(token===epoch)$("ffA06NavStatus").textContent="تعذر الحفظ: "+err.message}finally{button.disabled=false}};
const scopeLabel=node("span");scopeLabel.id="ffA06ScopeLabel";$("ffx-topbar").querySelector(".ffx-top-intro").append(scopeLabel);
const search=node("button","بحث");search.id="ffA06GlobalSearch";search.type="button";search.className="ffx-top-icon";search.setAttribute("aria-label","بحث في الأقسام المصرح بها");search.onclick=()=>{if(!body.classList.contains("ffx-menu-open"))$("ffx-menu").click();$("ffx-nav-search")?.focus()};$("ffx-topbar").querySelector(".ffx-top-right").prepend(search);
const skip=node("a","تخطي إلى محتوى العمل");skip.href="#ffA06Main";skip.className="ff-a06-skip";const main=document.querySelector("main");main.id=main.id||"ffA06Main";skip.href="#"+main.id;main.tabIndex=-1;body.prepend(skip);skip.onclick=()=>main.focus({preventScroll:true});
// Link only unambiguous adjacent labels. Preserve explicit and wrapping labels.
let scheduled=false,counter=0;
function enhance(){scheduled=false;for(const label of document.querySelectorAll("label:not([for])")){if(label.querySelector("input,select,textarea,button"))continue;const input=label.nextElementSibling;if(!input?.matches('input:not([type=hidden]),textarea,select')||input.labels?.length||input.hasAttribute("aria-label"))continue;if(!input.id)input.id="ff-a06-field-"+(++counter);label.htmlFor=input.id}
 for(const e of document.querySelectorAll('button[title]:not([aria-label])'))if(!e.textContent.trim())e.setAttribute("aria-label",e.title);
 for(const e of document.querySelectorAll('[data-cancel-order],[data-reset-run],[data-staff-active="false"],[data-cancel-addition]'))e.classList.add("ff-a06-danger");
}
new MutationObserver(()=>{if(!scheduled){scheduled=true;requestAnimationFrame(enhance)}}).observe(body,{childList:true,subtree:true});enhance();
const measure=()=>{const bar=!special.hidden?special:$("ffx-mobile-nav");const height=bar?.getBoundingClientRect().height||0;body.style.setProperty("--ff-a06-nav-height",Math.ceil(height)+"px")};
if(window.ResizeObserver){const ro=new ResizeObserver(measure);ro.observe(special);ro.observe($("ffx-mobile-nav"))}
window.addEventListener("resize",measure);window.addEventListener("ff-luxe-session-reset",clear);window.addEventListener("ff-assembly-snapshot-success",()=>void sync());$("ffx-branch").addEventListener("change",()=>void sync(true));media.addEventListener("change",()=>void sync(true));setInterval(()=>{void sync();measure()},1500);void sync();measure();
})();