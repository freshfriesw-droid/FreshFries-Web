/* Fresh Fries LUXE: unified historical date filters, read-only settlement range. */
'use strict';
(()=>{
 const $=id=>document.getElementById(id);
 const today=()=>{const p=new Intl.DateTimeFormat('en-US',{timeZone:'Asia/Aden',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date()),g=x=>p.find(v=>v.type===x)?.value||'';return g('year')+'-'+g('month')+'-'+g('day')};
 const valid=(a,b)=>{if(!a||!b||a>b||b>today()||a<'2020-01-01')return false;const days=(new Date(b+'T12:00:00Z')-new Date(a+'T12:00:00Z'))/86400000;return Number.isFinite(days)&&days<=366};
 const money=n=>Number(n||0).toLocaleString('ar-YE',{maximumFractionDigits:2});
 const style=document.createElement('style');
 style.textContent=[
 '#ffHistoryPeriod{border:1px solid #da3651;border-radius:14px;margin:10px 0;padding:12px;background:var(--ffb-surface,#fff)}',
 '#ffHistoryPeriod[hidden]{display:none!important}',
 '#ffHistoryPeriod>summary{cursor:pointer;font-size:16px;font-weight:900;color:var(--ffb-redink,#b31532)}',
 '.ff-history-range{display:flex;flex-wrap:wrap;align-items:end;gap:9px;margin:10px 0}',
 '.ff-history-range label{display:flex;flex-direction:column;gap:4px;flex:1 1 140px;font-size:13px;font-weight:800}',
 '.ff-history-range input{width:100%;max-width:100%;min-height:43px}',
 '.ff-history-range button{min-height:44px}',
 '#ff42RangeReport{border:2px solid #2873d6;border-radius:14px;margin:12px 0;padding:13px}',
 '#ff42RangeReport table{width:100%;border-collapse:collapse;font-size:12px}',
 '#ff42RangeReport td,#ff42RangeReport th{border:1px solid #ddd;padding:8px 6px;text-align:right}',
 '#ff42RangeTable{overflow-x:auto}'
 ].join('\n');document.head.append(style);
 const target=$('connection');if(!target)return;
 const root=document.createElement('details');root.id='ffHistoryPeriod';root.hidden=true;
 root.innerHTML='<summary id="ffHistoryLabel">📅 التقارير والبيانات التاريخية: اليوم</summary>'+
 '<div class="ff-history-range"><label>من تاريخ<input id="ffHistoryFrom" type="date"></label>'+
 '<label>إلى تاريخ<input id="ffHistoryTo" type="date"></label>'+
 '<button type="button" class="outline" id="ffHistoryToday">اليوم</button>'+
 '<button type="button" class="primary" id="ffHistoryApply">اعتماد الفترة</button></div>'+
 '<p class="muted">تتغير فترة الأرشيف والتقارير؛ لا تُخفى الطلبات النشطة ولا إشعاراتها المباشرة.</p>'+
 '<p id="ffHistoryMessage" role="status" class="muted"></p>';
 target.after(root);
 const from=$('ffHistoryFrom'),to=$('ffHistoryTo'),label=$('ffHistoryLabel'),msg=$('ffHistoryMessage');
 from.value=to.value=today();from.max=to.max=today();
 window.ffLuxeHistoryPeriod={from:from.value,to:to.value};
 function reflect(a,b){
  for(const [left,right] of [['ff40From','ff40To'],['ff51ArchiveFrom','ff51ArchiveTo'],['ff42RangeFrom','ff42RangeTo']]){
   if($(left))$(left).value=a;if($(right))$(right).value=b;
  }
  if(a===b&&$('ff42Day'))$('ff42Day').value=a;
  if($('ff40ReportStatus'))$('ff40ReportStatus').textContent='تم تغيير الفترة؛ اضغط إعداد التقرير.';
  if($('ff51ArchiveCount'))$('ff51ArchiveCount').textContent='تم تغيير الفترة؛ اضغط تحديث الأرشيف.';
 }
 function applyRange(a,b,emit){
  if(!valid(a,b)){msg.textContent='⚠️ اختر تاريخين صحيحين، بفترة لا تتجاوز 366 يومًا.';return}
  from.value=a;to.value=b;window.ffLuxeHistoryPeriod={from:a,to:b};
  label.textContent='📅 التقارير والبيانات: '+(a===b?(a===today()?'اليوم':a):a+' إلى '+b);
  reflect(a,b);msg.textContent='الفترة المعتمدة: '+a+' — '+b;
  if(emit)window.dispatchEvent(new CustomEvent('ff-luxe-history-range',{detail:{from:a,to:b}}));
 }
 $('ffHistoryToday').onclick=()=>applyRange(today(),today(),true);
 $('ffHistoryApply').onclick=()=>applyRange(from.value,to.value,true);
 window.addEventListener('ff-luxe-history-range',e=>{if(e.detail?.from&&e.detail?.to)applyRange(e.detail.from,e.detail.to,false)});
 window.addEventListener('ff-assembly-snapshot-success',()=>{root.hidden=!(typeof data!=='undefined'&&data?.role&&user?.id)});
 const settle=$('ff42Panel');if(!settle)return;
 const section=document.createElement('section');section.id='ff42RangeReport';
 section.innerHTML='<h3>📆 ملخص التسويات لفترة — قراءة فقط</h3>'+
 '<p class="muted">العرض للفترة المحددة؛ تحرير أو إقفال تسوية يظل خاصًا بيوم واحد.</p>'+
 '<div class="ff-history-range"><label>من تاريخ<input type="date" id="ff42RangeFrom"></label>'+
 '<label>إلى تاريخ<input type="date" id="ff42RangeTo"></label>'+
 '<button type="button" class="primary" id="ff42RangeApply">عرض الفترة</button></div>'+
 '<p id="ff42RangeStatus" class="muted" role="status"></p><div id="ff42RangeTable"></div>';
 settle.append(section);
 const a=$('ff42RangeFrom'),b=$('ff42RangeTo'),run=$('ff42RangeApply'),state=$('ff42RangeStatus'),list=$('ff42RangeTable');
 a.value=from.value;b.value=to.value;a.max=b.max=today();
 run.onclick=async()=>{
  if(typeof data==='undefined'||data?.role!=='manager')return;
  if(!valid(a.value,b.value)){state.textContent='اختر فترة صحيحة بحد أقصى 366 يومًا';return}
  run.disabled=true;state.textContent='جارٍ إعداد ملخص التسويات...';list.replaceChildren();
  try{
   const result=await rpc('ff_luxe_settlement_period',{p_from:a.value,p_to:b.value,p_branch:$('ff42Branch')?.value||null});
   if(!Array.isArray(result?.rows))throw Error('استجابة الخادم غير صحيحة');
   const totals=result.totals||{};
   state.textContent='الفترة '+result.from+' — '+result.to+' · المسلّمة '+money(totals.delivered_orders)+
    ' · قيمة الطلبات '+money(totals.delivered_value)+' ريال · النقد المطلوب '+money(totals.cash_due)+
    ' ريال · النقد المستلم '+money(totals.cash_received)+' ريال';
   const table=document.createElement('table');
   table.innerHTML='<thead><tr><th>التاريخ</th><th>الفرع</th><th>المسلّمة</th><th>قيمة الطلبات</th><th>التسويات</th><th>المطلوب</th><th>المستلم</th></tr></thead>';
   const body=document.createElement('tbody');
   for(const row of result.rows){
    const tr=body.insertRow();
    for(const v of [row.day,row.branch,row.delivered_orders,money(row.delivered_value),row.settlements,
      money(row.cash_due),money(row.cash_received)])tr.insertCell().textContent=String(v??'—');
   }
   table.append(body);list.append(table);
   if(!result.rows.length)list.textContent='لا توجد نتائج لهذه الفترة.';
  }catch(e){state.textContent='تعذر عرض التقرير: '+(e?.message||e)}
  finally{run.disabled=false}
 };
})();