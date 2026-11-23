/* Fresh Fries LUXE: one photo-based interactive picker for all order workflows. */
(()=>{'use strict';
const style=document.createElement('style');style.id='ffl-shared-photo-menu-style';
style.textContent=[
'.ffl-picker-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:10px;margin:12px 0}',
'.ffl-picker-tile{min-width:0;border:1px solid var(--ffb-line,#ddd);border-radius:15px;padding:8px;background:var(--ffb-surface,#fff);display:flex;flex-direction:column;gap:7px}',
'.ffl-picker-tile.ffl-picker-selected{border-color:var(--ffb-red,#d51e2c);box-shadow:0 4px 14px #d51e2c22}',
'.ffl-picker-product{border:0!important;background:transparent!important;color:var(--ffb-ink,#222)!important;padding:5px!important;min-height:125px!important;height:auto!important;width:100%;display:flex!important;flex-direction:column;align-items:stretch;gap:7px;text-align:center;position:relative}',
'.ffl-picker-product img,.ffl-picker-product .ffb-placeholder{height:80px;width:100%;object-fit:cover;border-radius:9px;background:var(--ffb-soft,#f4f4f4)}',
'.ffl-picker-product .ffb-placeholder{display:grid;place-items:center;font-size:32px}',
'.ffl-picker-product .ffb-v2-name{font-size:12px;font-weight:900;line-height:1.4;overflow-wrap:anywhere}',
'.ffl-picker-product .ffb-v2-price{font-size:11px}',
'.ffl-picker-product .ffb-v2-count{position:absolute;top:3px;left:3px}',
'.ffl-picker-controls{display:flex;align-items:center;justify-content:space-between;gap:6px;direction:ltr}',
'.ffl-picker-controls button{flex:1;min-width:37px;min-height:40px!important;border-radius:9px;padding:4px 9px;font-size:19px;font-weight:900;background:var(--ffb-red,#d51e2c);color:white}',
'.ffl-picker-controls button.ffl-picker-minus{background:var(--ffb-soft2,#eee);color:var(--ffb-ink,#222);border:1px solid var(--ffb-line,#ddd)}',
'.ffl-picker-controls .ffl-picker-qty{flex:1;text-align:center;font-size:17px;font-weight:900;font-variant-numeric:tabular-nums}',
'.ffl-picker-controls input.ffl-picker-qty{min-width:0;width:62px;max-width:85px;min-height:40px;border:1px solid var(--ffb-line,#ddd);border-radius:8px;background:var(--ffb-surface,#fff);color:var(--ffb-ink,#222)}',
'.ffl-picker-categories{display:flex;gap:7px;overflow-x:auto;padding:7px 0 10px;scrollbar-width:thin}',
'.ffl-picker-categories button{flex:none;border:1px solid var(--ffb-line,#ddd);border-radius:24px;padding:8px 14px;min-height:40px;background:var(--ffb-soft2,#eee);color:var(--ffb-ink,#222)}',
'.ffl-picker-categories button.selected{background:var(--ffb-red,#d51e2c);color:white}',
'#ffUnifiedMenuDialog{background:var(--ffb-surface,#fff)!important;color:var(--ffb-ink,#111)!important}',
'#ffUnifiedMenuDialog .ffl-picker-summary{font-weight:900;margin:8px 0;color:var(--ffb-redink,#bb2133)}',
'#ffBurgerMenuFields{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:9px;align-items:start}',
'#ffBurgerMenuFields>.ffl-picker-tile{margin:0;min-height:0}',
'@media(max-width:540px){.ffl-picker-grid,#ffBurgerMenuFields{grid-template-columns:repeat(2,minmax(0,1fr));gap:7px}.ffl-picker-product img,.ffl-picker-product .ffb-placeholder{height:66px}.ffl-picker-tile{padding:6px}.ffl-picker-controls input.ffl-picker-qty{width:52px;max-width:65px}}'
].join('\n');document.head.append(style);
const norm=s=>String(s||'').toLocaleLowerCase('ar').replace(/[أإآ]/g,'ا').replace(/ة/g,'ه').replace(/ى/g,'ي').replace(/\s+/g,' ').trim();
const fallbackCategory=n=>{const s=norm(n);if(/عرض|باقة/.test(s))return 'العروض';if(/برجر|برغر/.test(s))return 'البرجر';if(/سمبوس|هالبينو|هلبينو|ذره/.test(s))return 'السمبوسة';if(/اكسترا|اضاف|شريحه|كاتشب|صوص|خبز/.test(s))return 'الإضافات';if(/مشروب|كولا|مياه|مويه|عصير/.test(s))return 'المشروبات';return 'الأصناف الرئيسية'};
const category=item=>{const c=norm(item?.category);if(item?.kind==='offer'||item?.type==='offer'||/عروض/.test(c))return 'العروض';if(/برجر|برغر/.test(c))return 'البرجر';if(/سمبوس/.test(c))return 'السمبوسة';if(/اضاف/.test(c))return 'الإضافات';if(/مشروب/.test(c))return 'المشروبات';if(/رئيس|وجبات|مقبلات/.test(c))return 'الأصناف الرئيسية';return fallbackCategory(item?.name)};
function imageUrl(item){const path=String(item?.image_path||'');if(!/^(menu|offer)\/[0-9a-f-]{36}\.(png|jpg|jpeg|webp)$/i.test(path))return '';try{if(typeof client==='undefined'||!client?.storage)return '';const uri=client.storage.from('ff_menu_media').getPublicUrl(path)?.data?.publicUrl;return uri+(item?.image_version?'?v='+encodeURIComponent(item.image_version):'')}catch{return ''}}
function placeholder(){const s=document.createElement('span');s.className='ffb-placeholder';s.textContent='🍟';s.setAttribute('aria-hidden','true');return s}
function createTile(item,opts={}){
 const root=document.createElement('div');root.className='ffl-picker-tile';
 const product=document.createElement('button');product.type='button';product.className='ffl-picker-product';product.setAttribute('aria-label','إضافة '+String(item.name||'صنف'));
 const pic=imageUrl(item);let media;
 if(pic){media=document.createElement('img');media.src=pic;media.loading='lazy';media.alt='صورة '+String(item.name||'صنف');media.onerror=()=>media.replaceWith(placeholder())}
 else media=placeholder();
 const name=document.createElement('span');name.className='ffb-v2-name';name.textContent=String(item.name||'صنف');
 const price=document.createElement('span');price.className='ffb-v2-price';
 if(opts.showPrice!==false&&item.price!==undefined&&item.price!==null&&Number.isFinite(Number(item.price)))price.textContent=Number(item.price).toLocaleString('ar-YE')+' ريال';
 const badge=document.createElement('span');badge.className='ffb-v2-count';badge.hidden=true;
 product.append(media,name);if(price.textContent)product.append(price);product.append(badge);
 const controls=document.createElement('div');controls.className='ffl-picker-controls';
 const less=document.createElement('button');less.type='button';less.className='ffl-picker-minus';less.textContent='−';less.setAttribute('aria-label','إنقاص '+item.name);
 const plus=document.createElement('button');plus.type='button';plus.textContent='+';plus.setAttribute('aria-label','زيادة '+item.name);
 const qty=opts.quantityInput||document.createElement('span');qty.classList.add('ffl-picker-qty');if(!opts.quantityInput)qty.textContent='0';
 const refresh=n=>{const v=Number.isInteger(Number(n))&&Number(n)>0?Number(n):0;badge.hidden=!v;badge.textContent=String(v);root.classList.toggle('ffl-picker-selected',!!v);if(!opts.quantityInput)qty.textContent=String(v);less.disabled=v<=0;plus.disabled=v>=99};
 product.addEventListener('click',()=>opts.onAdd?.());plus.addEventListener('click',()=>opts.onAdd?.());less.addEventListener('click',()=>opts.onRemove?.());
 controls.append(less,qty,plus);root.append(product,controls);refresh(opts.quantity||0);
 return {element:root,refresh,quantityNode:qty};
}
function categories(box,items,selected,change){
 box.replaceChildren();const set=new Set(items.map(category));
 for(const value of ['الكل','الأصناف الرئيسية','البرجر','السمبوسة','الإضافات','المشروبات','العروض']){
 if(value!=='الكل'&&!set.has(value))continue;
 const button=document.createElement('button');button.type='button';button.textContent=value;button.className=value===selected?'selected':'';button.setAttribute('aria-pressed',String(value===selected));button.onclick=()=>change(value);box.append(button);
 }
}
window.ffLuxePhotoMenu=Object.freeze({normalize:norm,category,imageUrl,createTile,categories});
})();