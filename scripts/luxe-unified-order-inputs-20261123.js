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
const undoDrafts=new WeakMap();
function appendText(area,item,delta){
 if(!area?.isConnected)return;
 try{
  const before=area.value,after=ff49EditDraftQuantity(before,item,delta);
  if(before===after)return;
  area.value=after;area.dispatchEvent(new Event('input',{bubbles:true}));
  undoDrafts.set(area,{before,after});
 }catch(e){$('ffUnifiedMenuStatus').textContent=e.message;return false}
 return true;
}
async function loadMenu(){
 if(catalog.length)return catalog;
 await ff49LoadCatalog();
 const rows=ff49Catalog;
 if(!Array.isArray(rows))throw Error('تعذر قراءة أصناف المنيو');
 catalog=rows.filter(x=>x?.name&&x?.id);
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
 const parsed=ff49ParseItemsAndNotes(active.value,{allowPartial:true,allowEmpty:true});
 const counts=new Map();for(const item of parsed.items)counts.set(item.name,(counts.get(item.name)||0)+item.qty);
 const total=parsed.items.reduce((sum,item)=>sum+item.qty,0);
 $('ffUnifiedMenuUndo').disabled=undoDrafts.get(active)?.after!==active.value;
 $('ffUnifiedMenuStatus').textContent=filtered.length+' صنف/عرض · المختار '+total+' قطعة · '+(active.dataset.ffUnifiedLabel||'');
 if(!filtered.length){box.append(make('p','لا توجد أصناف مطابقة للبحث أو القسم'));return}
 for(const item of filtered){
  const quantity=counts.get(item.name)||0;
  const change=delta=>{if(appendText(active,item,delta)!==false)render()};
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
 const block=area.closest('.ff-unified-wrapper')?.querySelector('.ff-unified-review');
 if(!block)return false;
 block.hidden=false;block.textContent='جاري التحليل والمعاينة...';
 try{
  await loadMenu();
  if(typeof ff49LoadCatalog==='function')await ff49LoadCatalog();
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
 actions.append(menu,analyze);
 const review=make('div');review.className='ff-unified-review';review.setAttribute('role','status');review.hidden=true;
 wrapper.append(actions,review);
 area.insertAdjacentElement('afterend',wrapper);
 area.addEventListener('input',()=>{drafts.delete(area);undoDrafts.delete(area);review.hidden=true;review.replaceChildren()});
}
function scan(){for(const info of targets)attach($(info.id),info)}
const watcher=new MutationObserver(()=>{if(!document.hidden)scan()});
watcher.observe(document.body,{childList:true,subtree:true});
scan();
$('ffUnifiedMenuSearch').addEventListener('input',render);
$('ffUnifiedMenuClose').onclick=()=>mod.close();
$('ffUnifiedMenuUndo').onclick=()=>{const previous=active&&undoDrafts.get(active);if(!previous||active.value!==previous.after)return;active.value=previous.before;active.dispatchEvent(new Event('input',{bubbles:true}));undoDrafts.delete(active);render()};
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
window.addEventListener('ff-luxe-session-reset',()=>{active=null;catalog=[];if(mod.open)mod.close()});
})();