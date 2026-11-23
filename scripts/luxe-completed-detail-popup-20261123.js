/* Read-only popup for universal finished/completed orders; preserves all existing follow-up actions. */
(function(){
'use strict';
const dialog=document.createElement('dialog');dialog.id='ffCompletedDetailDialog';
dialog.style.cssText='direction:rtl;width:min(95vw,720px);max-height:90vh;overflow:auto;background:#fff;color:#111;border:2px solid #1f69c3;border-radius:16px;padding:15px';
dialog.innerHTML='<div style="display:flex;justify-content:space-between;align-items:center;gap:10px"><h2>📁 تفاصيل الطلب المنتهي</h2><button type="button" class="outline" id="ffCompletedDetailClose">إغلاق</button></div>'+
'<p style="color:#666">سجل للقراءة يشمل التوقيت والحالة والأصناف والملاحظات والتقييمات، ولا يعيد فتح الطلب.</p>'+
'<div id="ffCompletedDetailContent"></div><button id="ffCompletedDetailActions" type="button" class="primary">عرض الإجراءات والمتابعة</button>';
document.body.append(dialog);
const box=document.getElementById('ffCompletedDetailContent');let selected=null;
function open(card){
 const summary=card.querySelector('summary'),body=card.querySelector('.ffl-finished-details');
 if(!summary||!body)return;
 selected=card;box.replaceChildren();
 const head=summary.cloneNode(true);head.removeAttribute('tabindex');
 const content=body.cloneNode(true);
 content.querySelectorAll('form,button,input,select,textarea').forEach(e=>e.remove());
 const title=document.createElement('div');title.style.cssText='padding:12px;background:#eff6ff;border-radius:12px;margin:10px 0';
 title.append(...Array.from(head.childNodes));box.append(title,content);
 if(!dialog.open)dialog.showModal();
}
document.addEventListener('click',event=>{
 const summary=event.target.closest('.ffl-finished-card > summary');
 if(!summary)return;
 const card=summary.closest('.ffl-finished-card');
 if(!card)return;
 event.preventDefault();event.stopImmediatePropagation();open(card);
},true);
document.getElementById('ffCompletedDetailClose').onclick=()=>dialog.close();
document.getElementById('ffCompletedDetailActions').onclick=()=>{
 const target=selected;dialog.close();
 if(target?.isConnected){target.open=true;target.scrollIntoView({block:'center',behavior:'smooth'})}
};
window.addEventListener('ff-luxe-session-reset',()=>{selected=null;box.replaceChildren();if(dialog.open)dialog.close()});
})();