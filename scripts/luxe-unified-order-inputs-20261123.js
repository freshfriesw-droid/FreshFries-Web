/* Unified menu + FF75 parser preview for every manual order-items input. */
(function(){
'use strict';
const targets=[
 {id:'ffbQuickInput',label:'الطلب الجديد'},
 {id:'newItems',label:'أصناف الطلب الجديد'},
 {id:'ff49ReserveItems',label:'حجز الاستلام',save:'ff49ReserveSave'},
 {id:'ff50RequestItems',label:'طلب تعديل الأصناف',save:'ff50RequestSave'},
 {id:'ff52LateItems',label:'إضافة بعد خروج الموصل'},
 {id:'additionItemsInput',label:'إضافة أصناف الطلب'}
];
const $=id=>document.getElementById(id);
const make=(tag,value)=>{const x=document.createElement(tag);if(value!=null)x.textContent=String(value);return x;};
const mod=document.createElement('dialog');mod.id='ffUnifiedMenuDialog';mod.style.cssText='width:min(95vw,670px);max-height:90vh;overflow:auto;border:2px solid #c72439;border-radius:16px;padding:16px;direction:rtl;background:#fff;color:#111';
mod.innerHTML='<h2>🍟 المنيو التفاعلي · فريش فرايز</h2><p>اضغط الصنف لإضافة قطعة، وعدّل العدد من + و−. تُضاف الأصناف إلى نفس محلل الطلب المعتمد.</p>'+
'<input id="ffUnifiedMenuSearch" type="search" placeholder="ابحث عن صنف أو عرض" style="width:100%;padding:10px;margin:5px 0 10px">'+
'<div id="ffUnifiedMenuStatus" role="status"></div><div id="ffUnifiedMenuList" style="display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:8px"></div>'+
'<div class="actions"><button type="button" id="ffUnifiedMenuReview" class="primary">🔎 تحليل الأصناف ومعاينتها</button><button type="button" id="ffUnifiedMenuUndo" class="outline" disabled>تراجع عن آخر تعديل</button><button type="button" id="ffUnifiedMenuClose" class="outline">إغلاق</button></div>';
document.body.append(mod);
const categoryBar=make('div');categoryBar.id='ffUnifiedMenuCategories';categoryBar.className='ffl-picker-categories';
const menuList=$('ffUnifiedMenuList');menuList.removeAttribute('style');menuList.className='ffl-picker-grid';
menuList.before(categoryBar);

let catalog=[],active=null,request=0,activeCategory='الكل';
const drafts=new WeakMap();
// Resolve quantity lines with the same parser used by submission.
// Preserve original notes, aliases, whitespace and explicit prices.
function itemRows(area){
 const rows=[];
 for(const [index,raw] of area.value.split(/\r?\n/).entries()){
  if(!/^\s*[0-9٠-٩۰-۹]+(?:\.[0-9٠-٩۰-۹]+)?\s+/u.test(raw))continue;
  const parsed=ff49ParseItemsAndNotes(raw,{allowPartial:true});
  if(parsed.errors.length||parsed.items.length!==1)continue;
  const item=parsed.items[0];
  rows.push({index,name:item.name,qty:item.qty,price:Number(item.price),notes:item.item_notes||''});
 }
 return rows;
}
let undoDrafts=new WeakMap();
function clearUndo(area){undoDrafts.delete(area)}
function canUndo(area){return !!area?.isConnected&&undoDrafts.get(area)?.after===area.value}
function undo(area){if(!canUndo(area))return false;const previous=undoDrafts.get(area);clearUndo(area);area.value=previous.before;area.dispatchEvent(new Event('input',{bubbles:true}));return true}
function appendText(area,item,delta,lineIndex=null){
 if(!area?.isConnected)return;
 if(delta!==1&&delta!==-1)throw Error('تغيير كمية غير صالح');
 const name=typeof item==='string'?item:item?.name;
 if(!name)throw Error('الصنف غير متاح');
 const before=area.value;
 if(ff49ParseItemsAndNotes(before,{allowPartial:true,allowEmpty:true}).errors.length)throw Error('صحح الأسطر غير الواضحة قبل تعديل السلة');
 const lines=before.split(/\r?\n/),matches=itemRows(area).filter(row=>row.name===name);
 const total=matches.reduce((sum,row)=>sum+row.qty,0);
 const last=lineIndex!==null?matches.find(row=>row.index===lineIndex):delta>0&&typeof item==='object'?matches.find(row=>!row.notes&&row.price===Number(item.price)):matches.at(-1);
 if(lineIndex!==null&&!last)throw Error('تغيرت السلة؛ أعد المحاولة');
 if(delta>0){
  if(total>=99)return;
  if(last)lines[last.index]=lines[last.index].replace(/^(\s*)[0-9٠-٩۰-۹]+(?:\.[0-9٠-٩۰-۹]+)?/u,(_,space)=>space+String(last.qty+1));
  else if(lines.length===1&&!lines[0])lines[0]='1 '+name;
  else lines.push('1 '+name);
 }else if(last){
  if(last.qty===1)lines.splice(last.index,1);
  else lines[last.index]=lines[last.index].replace(/^(\s*)[0-9٠-٩۰-۹]+(?:\.[0-9٠-٩۰-۹]+)?/u,(_,space)=>space+String(last.qty-1));
 }else return;
 const after=lines.join('\n');
 if(after===before)return;
 area.value=after;area.dispatchEvent(new Event('input',{bubbles:true}));
 undoDrafts.set(area,{before,after});area.dispatchEvent(new Event('ff-cart-edit',{bubbles:true}));
}
window.ffLuxeOrderText=Object.freeze({itemRows,appendText,undo,canUndo,clearUndo});
async function loadMenu(){
 const token=++request,actor=typeof user!=='undefined'?user?.id:null;
 if(!actor)throw Error('سجل الدخول أولًا');
 const rows=await rpc('ff49_catalog');
 if(token!==request||actor!==user?.id)throw Error('تغيرت جلسة أو عملية تحميل المنيو');
 if(!Array.isArray(rows))throw Error('تعذر قراءة أصناف المنيو');
 ff49Catalog=rows;ff49CatalogActor=actor;ff49CatalogAt=Date.now();
 catalog=rows.filter(x=>x?.name&&x?.id&&x.active!==false);
 return catalog;
}
function render(){
 const box=$('ffUnifiedMenuList');box.replaceChildren();
 if(!active?.isConnected){if(mod.open)mod.close();return}
 const ui=window.ffLuxePhotoMenu;
 if(!ui){$('ffUnifiedMenuStatus').textContent='تعذر تحميل المنيو المصور؛ حدث الصفحة';return}
 const tabs=$('ffUnifiedMenuCategories'),oldScroll=tabs.scrollLeft;
 ui.categories(tabs,catalog,activeCategory,value=>{activeCategory=value;render()});tabs.scrollLeft=oldScroll;
 const term=ui.normalize($('ffUnifiedMenuSearch').value);
 const filtered=catalog.filter(i=>(activeCategory==='الكل'||ui.category(i)===activeCategory)&&(!term||ui.normalize(i.name+' '+(i.category||'')).includes(term)));
 $('ffUnifiedMenuUndo').disabled=!canUndo(active);
 const quantities=new Map();
 for(const row of itemRows(active))quantities.set(row.name,(quantities.get(row.name)||0)+row.qty);
 const total=catalog.reduce((sum,item)=>sum+(quantities.get(item.name)||0),0);
 $('ffUnifiedMenuStatus').textContent=filtered.length+' صنف/عرض · المختار '+total+' قطعة · '+(active.dataset.ffUnifiedLabel||'');
 if(!filtered.length){box.append(make('p','لا توجد أصناف مطابقة للبحث أو القسم'));return}
 for(const item of filtered){
  const quantity=quantities.get(item.name)||0;
  const change=delta=>{try{appendText(active,item,delta);render()}catch(e){$('ffUnifiedMenuStatus').textContent=e.message}};
  const picker=ui.createTile(item,{quantity,onAdd:()=>change(1),onRemove:()=>change(-1)});
  box.append(picker.element);
 }
}
async function show(area){
 if(!area?.isConnected)return;
 active=area;activeCategory='الكل';$('ffUnifiedMenuSearch').value='';$('ffUnifiedMenuStatus').textContent='جارٍ تحميل المنيو...';mod.showModal();
 try{await loadMenu();if(active===area)render()}catch(e){$('ffUnifiedMenuStatus').textContent='تعذر جلب المنيو: '+String(e.message||e)}
}
async function preview(area){
 if(!area?.isConnected)return false;
 if(['additionItemsInput','ff52LateItems'].includes(area.id)){
  if(typeof window.ff75ReviewAddition!=='function'){if(typeof toast==='function')toast('تعذر تحميل معاينة الإضافة؛ حدث الصفحة');return false}
  return window.ff75ReviewAddition(area);
 }
 const block=area.closest('.ff-unified-wrapper')?.querySelector('.ff-unified-review');
 if(!block)return false;
 block.hidden=false;block.textContent='جاري التحليل والمعاينة...';
 try{
  await loadMenu();
  if(typeof ff49ParseItemsAndNotes!=='function'||typeof window.ff75RenderReview!=='function')throw Error('محلل FF75 غير متاح');
  const content=area.value;
  const parsed=ff49ParseItemsAndNotes(content,{allowPartial:true});
  if(area.value!==content)return false;
  block.innerHTML=window.ff75RenderReview(parsed,area.dataset.ffUnifiedLabel||'الطلب');
  const valid=parsed.errors.length===0&&parsed.items.length>0;
  drafts.set(area,{text:content,valid});
  if(!valid){const message=make('strong','صحح السطور الغامضة أو غير الصالحة قبل الإرسال.');block.append(message)}
  return valid;
 }catch(e){block.textContent='تعذر التحليل: '+String(e.message||e);return false}
}
function attach(area,info){
 if(!area||area.dataset.ffUnified==='1')return;
 area.dataset.ffUnified='1';area.dataset.ffUnifiedLabel=info.label;
 const wrapper=make('div');wrapper.className='ff-unified-wrapper';wrapper.style.cssText='margin:8px 0;padding:10px;border:1px solid #d52a3a;border-radius:11px';
 const actions=make('div');actions.className='actions';actions.style.cssText='margin:5px 0;display:flex;flex-wrap:wrap;gap:7px';
 const menu=make('button','🍟 المنيو التفاعلي');menu.type='button';menu.className='outline';
 const analyze=make('button','🔎 تحليل ومعاينة موحدة');analyze.type='button';analyze.className='outline';
 menu.onclick=()=>void show(area);analyze.onclick=()=>void preview(area);
 actions.append(menu);if(!['additionItemsInput','ff52LateItems'].includes(info.id))actions.append(analyze);
 const review=make('div');review.className='ff-unified-review';review.setAttribute('role','status');review.hidden=true;
 wrapper.append(actions,review);
 area.insertAdjacentElement('afterend',wrapper);
 area.addEventListener('input',()=>{drafts.delete(area);clearUndo(area);review.hidden=true;review.replaceChildren();if(active===area)$('ffUnifiedMenuUndo').disabled=true});
}
function scan(){for(const info of targets)attach($(info.id),info)}
const watcher=new MutationObserver(()=>{if(!document.hidden)scan()});
watcher.observe(document.body,{childList:true,subtree:true});
scan();
$('ffUnifiedMenuSearch').addEventListener('input',render);
$('ffUnifiedMenuClose').onclick=()=>mod.close();
$('ffUnifiedMenuUndo').onclick=()=>{if(active)undo(active);render()};
$('ffUnifiedMenuReview').onclick=async()=>{const area=active;mod.close();await preview(area)};
document.addEventListener('click',event=>{
 const id=event.target?.id;
 if(id!=='ff49ReserveSave'&&id!=='ff50RequestSave')return;
 const area=$(id==='ff49ReserveSave'?'ff49ReserveItems':'ff50RequestItems');
 if(!area)return;
 const prev=drafts.get(area);
 if(!prev||prev.text!==area.value||!prev.valid){
  event.preventDefault();event.stopImmediatePropagation();
  void preview(area).then(ok=>{
   if(ok&&typeof toast==='function')toast('تم تحليل الأصناف؛ راجع المعاينة ثم اضغط حفظ مرة أخرى');
  });
 }
},true);
window.addEventListener('ff-luxe-session-reset',()=>{request++;active=null;catalog=[];undoDrafts=new WeakMap();if(mod.open)mod.close()});
})();