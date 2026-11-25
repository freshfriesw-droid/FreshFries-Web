/* Test-only: exercise the existing resolver on real mounted elements, not synthetic controls. */
(()=>{
 const el=()=>window.ffA07Elements;
 const restricted={tone:new Set(["ff76Run","ff76Preview","ff76Download","ff76Share","ffx-hero-new","ffx-hero-reserve","ff51ArchiveRefresh","ff51ArchiveExport","ff51CustomerFind","newBranch","newPhone","newArea","newFee","newNotes","newCustomerName","newChannel","newFullAddress","ffbMenuSearch","ffbQuickInput","newItems","orderSearch","orderBranchFilter","orderStatusFilter","ff51CustomerSearch","ff51CustomerNoteText","ff76From","ff76To","ff76Branch","ff76Driver","ffA10Staff","ffA10Area","ffA10Item","ffA10Status","ff76Mode","ff76Trend","ff51ArchiveFrom","ff51ArchiveTo","ff51ArchiveStatus","ff51ArchiveBranch","ffA05StaffSearch","ffA05StaffRole","ffA05StaffActive","ffA05StaffSort","ff49ReserveName","ff49ReservePhone","ff49ReserveNotes","ff49ReservePickup","ff49ReserveItems","ff41Subject","ff41Description","ff39Title","ff39Body","ffx-branch","ff2-search","ff40From","ff40To","ff40ReportBranch"]),placement:new Set(["ffx-kpis","ffx-shortcuts","ffx-order-list","ffx-overdue","ff76Body","ff51CustomersList","ff51CustomerHistory","ff51CustomerNotesList","ff51ArchiveList","ff51RatingsList","ff51CatalogItems","ff51OffersList","ff49ReservationsList","ff41CaseList","ff39InboxList"])};
 const permitted=(p,key)=>restricted[p]?restricted[p].has(key):['icon','hover','press'].includes(p)?el().toneAllowed.has(key):true;
 const close=(n,v)=>Math.abs(parseFloat(n)-v)<.12;
 const native=n=>n.matches('input,select,textarea');
 function verify(n,p,v){
  const s=getComputedStyle(n),attr=p==='shape'||p==='size'?'ffA07'+p[0].toUpperCase()+p.slice(1):'ffA07El'+p[0].toUpperCase()+p.slice(1);
  if(n.dataset[attr]!==v)return ['binding',n.dataset[attr]??null];
  if(p==='shape'){
   if(v==='pack')return null;
   if(v==='square')return close(s.borderTopLeftRadius,0)?null:['radius',s.borderTopLeftRadius];
   if(v==='round')return parseFloat(s.borderTopLeftRadius)>0?null:['radius',s.borderTopLeftRadius];
   if(v==='pill')return close(s.borderTopLeftRadius,999)?null:['radius',s.borderTopLeftRadius];
   if(v==='outline')return s.outlineStyle==='solid'&&(close(s.outlineWidth,2)||n.matches(':focus-visible')&&close(s.outlineWidth,3))?null:['outline',s.outline];
   if(v==='icon_label')return native(n)?null:getComputedStyle(n,'::before').content.includes('◆')?null:['pseudo',getComputedStyle(n,'::before').content];
  }
  if(p==='size')return v==='normal'||close(s.paddingInlineStart,14)&&close(s.paddingBlockStart,14)?null:['size',s.paddingInlineStart+'/'+s.paddingBlockStart];
  if(p==='font'){const expected={system:'system-ui',tahoma:'tahoma',serif:'serif',cairo:'cairo',noto:'noto sans arabic'}[v];return s.fontFamily.toLowerCase().split(',')[0].replaceAll('"','').trim()===expected?null:['font',s.fontFamily]}
  if(p==='align')return s.textAlign===v?null:['align',s.textAlign];
  if(p==='textScale')return close(s.fontSize,parseFloat(getComputedStyle(n.parentElement).fontSize)*(v==='large'?1.125:1))?null:['font-size',s.fontSize+'/'+getComputedStyle(n.parentElement).fontSize];
  if(p==='weight')return Number(s.fontWeight)===(v==='strong'?700:400)?null:['weight',s.fontWeight];
  if(p==='spacing')return close(s.paddingInlineStart,v==='wide'?18:12)&&close(s.paddingInlineEnd,v==='wide'?18:12)?null:['spacing',s.paddingInlineStart+'/'+s.paddingInlineEnd];
  if(p==='spaceBlock')return n.matches('[type=checkbox],[type=radio],[type=range]')||close(s.paddingBlockStart,v==='wide'?12:8)&&close(s.paddingBlockEnd,v==='wide'?12:8)?null:['block',s.paddingBlockStart+'/'+s.paddingBlockEnd];
  if(p==='outerGap')return close(s.marginBlockStart,v==='wide'?8:4)&&close(s.marginBlockEnd,v==='wide'?8:4)?null:['outerGap',s.marginBlockStart+'/'+s.marginBlockEnd];
  if(p==='border')return s.borderTopStyle==='solid'&&close(s.borderTopWidth,v==='strong'?3:1)?null:['border',s.borderTopStyle+'/'+s.borderTopWidth];
  if(p==='shadow')return (s.boxShadow==='none')===(v==='none')?null:['shadow',s.boxShadow];
  if(p==='tone'){if(n.matches(':disabled'))return null;const expected={navy:'rgb(30, 58, 95)',red:'rgb(167, 25, 39)',light:'rgb(255, 255, 255)',dark:'rgb(34, 34, 34)'}[v];return s.backgroundColor===expected&&s.color===(v==='light'?'rgb(34, 34, 34)':'rgb(255, 255, 255)')?null:['tone',s.backgroundColor+'/'+s.color]}
  if(p==='placement')return s.justifySelf===v&&s.alignSelf===v?null:['placement',s.justifySelf+'/'+s.alignSelf];
  if(p==='icon'){const c=getComputedStyle(n,'::before').content;return v==='none'?c==='none'?null:['icon',c]:c.includes({check:'✓',arrow:'←',star:'★',search:'⌕',file:'▤'}[v])?null:['icon',c]}
  return null;
 }
 window.__step03Matrix=[];
 window.step03Probe=(label,config,dyn)=>{
  const roots=[...document.querySelectorAll('[data-ff-a07-screen]')],records=[];
  for(const [screen,row] of Object.entries(config))for(const [group,items] of Object.entries(row.style_config?.elements||{}))for(const item of items){
   const key=item.key;
   for(const root of roots.filter(r=>r.dataset.ffA07Screen===screen)){
    let nodes=dyn[key]?[...root.querySelectorAll(dyn[key])]:key==='cashier_stage'?[...root.querySelectorAll('[data-cashier]')]:[document.getElementById(key)].filter(n=>n&&root.contains(n));
    nodes=nodes.filter(n=>n.closest('[data-ff-a07-screen]')?.dataset.ffA07Screen===screen);
    for(const original of nodes){let target=group==='driver_regions'?original.closest('.card'):group==='assembly_stats'?original.parentElement:original;if(!target)continue;target=el().visualTarget(target);
     if(records.some(o=>o.group===group&&o.key===key&&o.target===target))continue;
     records.push({screen,group,key,original,target,disabled:original.disabled,checked:original.checked,value:original.value,required:original.required,hidden:original.hidden,handler:original.onclick,role:original.getAttribute('role')});
    }
   }
  }
  const values={shape:Object.keys(el().shapes).filter(x=>x!=='inherit'),size:Object.keys(el().sizes).filter(x=>x!=='inherit'),...Object.fromEntries(Object.entries(el().properties).map(([p,v])=>[p,Object.keys(v)]))};
  const result={label,width:innerWidth,entries:[...new Set(records.map(o=>o.screen+'/'+o.group+'/'+o.key))],nodes:records.length,computed:0,bindingOnly:0,failures:[],counts:{}};
  const stable=document.createElement('style');stable.textContent='[data-ff-a07-screen] *{transition:none!important}';document.head.append(stable);
  try{
   for(const [p,opts] of Object.entries(values))for(const v of opts){
    const cfg={};
    for(const [screen,row] of Object.entries(config)){cfg[screen]={...row,style_config:{elements:{}}};for(const [g,items] of Object.entries(row.style_config?.elements||{}))cfg[screen].style_config.elements[g]=items.map(({key})=>({key,shape:'pack',size:'normal',...(permitted(p,key)?{[p]:v}:{})}))}
    el().refresh(roots,cfg);
    for(const o of records){if(!permitted(p,o.key))continue;
     const n=o.target,why=verify(n,p,v),only=p==='hover'||p==='press'||p==='shape'&&(v==='pack'||v==='icon_label'&&native(n))||p==='size'&&v==='normal'||p==='tone'&&n.matches(':disabled')||p==='spaceBlock'&&n.matches('[type=checkbox],[type=radio],[type=range]');
     result[only?'bindingOnly':'computed']++;
     const id=p+'='+v;result.counts[id]=(result.counts[id]||0)+1;
     if(why)result.failures.push({screen:o.screen,group:o.group,key:o.key,tag:n.tagName,p,v,why});
     if(!o.original.isConnected||o.original.disabled!==o.disabled||o.original.checked!==o.checked||o.original.value!==o.value||o.original.required!==o.required||o.original.hidden!==o.hidden||o.original.onclick!==o.handler||o.original.getAttribute('role')!==o.role)result.failures.push({screen:o.screen,group:o.group,key:o.key,p,v,why:['operational-state']});
    }
   }
  }finally{el().refresh(roots,config);stable.remove()}
  window.__step03Matrix.push(result);
  return result.failures.length;
 };
})();
