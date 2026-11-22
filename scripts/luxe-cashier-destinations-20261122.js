/* Fresh Fries LUXE — four logical cashier destinations, three delivery branches.
   Multiple cashier accounts can be mapped to the same destination.
   Delivery dispatch and courier branch IDs remain unchanged. */
'use strict';
(()=>{
 const destinations=[
  {code:'cairo_first',label:'القاهرة — الفترة الأولى',branch:'cairo'},
  {code:'cairo_second',label:'القاهرة — الفترة الثانية',branch:'cairo'},
  {code:'sam_mall',label:'سام مول',branch:'sam_mall'},
  {code:'khamseen',label:'الخمسين',branch:'khamseen'}
 ];
 const byId=id=>document.getElementById(id);
 const readKey=()=>typeof user!=='undefined'&&user?.id?'ff_luxe_cashier_desk_choice:'+user.id:'';
 const deskCode=()=>{
  const s=byId('newBranch'),o=s?.selectedOptions?.[0],code=o?.dataset?.ffCashierDesk;
  if(code)return code;
  const branch=(typeof data!=='undefined'?data?.branches:[])?.find(b=>b.id===s?.value);
  return branch?.code==='cairo'?'cairo_first':branch?.code||'';
 };
 window.ffLuxeChosenCashierDesk=deskCode;
 function displayDestinations(selectedCode){
  if(typeof data==='undefined'||!data||!['manager','customer_service'].includes(data.role))return;
  const select=byId('newBranch');if(!select||!data.branches?.length)return;
  const prev=selectedCode||select.selectedOptions?.[0]?.dataset?.ffCashierDesk||'';
  let stored='';try{stored=localStorage.getItem(readKey())||''}catch{}
  const allowed=destinations.map(d=>({...d,base:data.branches.find(b=>b.code===d.branch)})).filter(d=>d.base);
  if(!allowed.length)return;
  const chosen=allowed.find(d=>d.code===prev)||allowed.find(d=>d.code===stored)
      ||allowed.find(d=>d.base.id===select.value)||allowed[0];
  const frag=document.createDocumentFragment();
  for(const d of allowed){
   const option=new Option(d.label,d.base.id);
   option.dataset.ffCashierDesk=d.code;option.selected=d.code===chosen.code;frag.append(option);
  }
  select.replaceChildren(frag);
 }
 if(typeof fillBranchSelects==='function'){
  const original=fillBranchSelects;
  fillBranchSelects=function(){
   const selected=byId('newBranch')?.selectedOptions?.[0]?.dataset?.ffCashierDesk||'';
   original();
   displayDestinations(selected);
  };
 }
 byId('newBranch')?.addEventListener('change',()=>{
  const k=readKey();if(!k)return;
  try{localStorage.setItem(k,deskCode())}catch{}
 });
 const host=byId('staffAdminCard');
 if(host){
  const card=document.createElement('section');card.id='ffLuxeCashierDesksAdmin';
  card.className='card';card.style.cssText='margin:16px 0;border:2px solid #2563eb;border-radius:14px;padding:15px';
  const h=document.createElement('h3');h.textContent='🧾 وجهات الكاشير الأربع — عدد غير محدود من الموظفين';
  const p=document.createElement('p');p.className='muted';
  p.textContent='القاهرة الفترة الأولى والثانية تتبعان فرع القاهرة للتوصيل. كل الكواشير المرتبطين بوجهة واحدة يستقبلون طلباتها. حدّد وجهة لكل كاشير؛ الحسابات القديمة غير المحددة تظل ترى فرعها حتى تعيين وجهتها.';
  const button=document.createElement('button');button.className='outline';button.type='button';
  button.textContent='🔄 تحديث توزيع الكواشير';
  const status=document.createElement('p');status.className='muted';status.setAttribute('role','status');
  const list=document.createElement('div');
  card.append(h,p,button,status,list);
  const entry=host.querySelector('.ff61-management-entry');
  if(entry)entry.before(card);else host.append(card);
  let busy=false,last=0;
  async function load(force=false){
   if(typeof data==='undefined'||data?.role!=='manager'||busy||(!force&&Date.now()-last<45000))return;
   busy=true;status.textContent='جارٍ جلب حسابات الكاشير...';
   try{
    const rows=await rpc('ff_luxe_cashier_desks_roster');
    if(!Array.isArray(rows))throw Error('لم تصل قائمة الكواشير');
    list.replaceChildren();
    for(const userRow of rows){
     const item=document.createElement('div');item.className='item';
     item.style.cssText='padding:12px;margin:9px 0;border:1px solid #dbe5f8;border-radius:12px';
     const name=document.createElement('strong');name.textContent=userRow.name||'كاشير';
     const caption=document.createElement('p');caption.className='muted';
     caption.textContent=(userRow.active?'نشط':'غير نشط')+' · وجهته: '+(userRow.desk_name||'غير محددة');
     const select=document.createElement('select');select.setAttribute('aria-label','وجهة '+name.textContent);
     select.style.cssText='width:100%;min-height:45px;margin:8px 0';
     const defaultOption=new Option('اختر وجهة الكاشير', '');defaultOption.disabled=true;select.add(defaultOption);
     const allowed=destinations.filter(d=>(userRow.branches||[]).includes(d.branch));
     for(const dest of allowed)select.add(new Option(dest.label,dest.code));
     select.value=userRow.desk||'';
     const save=document.createElement('button');save.type='button';save.className='primary';
     save.textContent='💾 حفظ وجهة الكاشير';save.disabled=!userRow.active||!allowed.length;
     save.onclick=async()=>{
      if(!select.value)return toast('اختر وجهة للكاشير أولًا');
      save.disabled=true;
      try{
       const r=await rpc('ff_luxe_set_cashier_desk',{p_user:userRow.user_id,p_desk:select.value});
       if(r?.ok!==true)throw Error('لم يؤكد الخادم حفظ الوجهة');
       toast('✅ تم ربط '+name.textContent+' بـ'+r.label);
       last=0;await load(true);
      }catch(e){toast('تعذر تعيين وجهة الكاشير: '+(e.message||e))}
      finally{save.disabled=false}
     };
     item.append(name,caption,select,save);list.append(item);
    }
    if(!rows.length)list.textContent='لا يوجد حساب كاشير بعد.';
    const counts=new Map(destinations.map(d=>[d.code,0]));
    for(const row of rows)if(row.active&&counts.has(row.desk))counts.set(row.desk,counts.get(row.desk)+1);
    status.textContent=destinations.map(d=>d.label+': '+counts.get(d.code)+' كاشير').join(' · ');
    last=Date.now();
   }catch(e){status.textContent='تعذر تحميل وجهات الكاشير: '+(e?.message||e)}
   finally{busy=false}
  }
  button.onclick=()=>void load(true);
  byId('staffAdminRefresh')?.addEventListener('click',()=>{last=0;setTimeout(()=>void load(true),100)});
  window.addEventListener('ff-assembly-snapshot-success',()=>{if(data?.role==='manager')void load()});
  window.ffLuxeReloadCashierDesks=()=>load(true);
 }
 const title=byId('cashierView')?.querySelector('h2');
 if(title&&typeof drawCashier==='function'){
  const render=drawCashier;
  drawCashier=function(){
   render();
   const desk=typeof data!=='undefined'?data?.cashier_desk:null;
   title.textContent='🧾 شاشة الكاشير — '+(desk?.label||'طلبات التوصيل للفرع المرتبط');
  };
 }
})();
