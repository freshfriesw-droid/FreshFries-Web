/* F-01 Fresh Fries LUXE: daily operational window in Asia/Aden.
   08:00 starts a new business day; 00:00–07:59 belong to the preceding day.
   Date-only dashboard reset: no deletion or modification of persisted orders.
   Under no circumstances filter unfinished / live operational orders by this date.
*/
(function () {
  'use strict';
  const tz='Asia/Aden';
  const fmt=new Intl.DateTimeFormat('en-US',{
    timeZone:tz,year:'numeric',month:'2-digit',day:'2-digit',
    hour:'2-digit',hourCycle:'h23'
  });
  function parts(when){
    const date=when instanceof Date?when:new Date(when??Date.now());
    if(Number.isNaN(date.valueOf()))throw new TypeError('Invalid date');
    const p=Object.fromEntries(fmt.formatToParts(date).filter(x=>x.type!=='literal')
      .map(x=>[x.type,x.value]));
    return {year:+p.year,month:+p.month,day:+p.day,hour:+p.hour};
  }
  function businessDate(when){
    const p=parts(when);
    const utc=new Date(Date.UTC(p.year,p.month-1,p.day-(p.hour<8?1:0)));
    return utc.toISOString().slice(0,10);
  }
  function closedHours(when){const h=parts(when).hour;return h>=2&&h<8;}
  window.ffF01BusinessDate=businessDate;
  window.ffF01IsClosedHours=closedHours;
  const $=id=>document.getElementById(id);
  const allowed=new Set(['manager','customer_service','supervisor']);
  const aria=(tag,txt)=>{const x=document.createElement(tag);if(txt!==undefined)x.textContent=txt;return x;};
  const meter=$('metrics');
  if(!meter)return;
  const panel=aria('section');
  panel.id='ffF01Panel';panel.hidden=true;panel.setAttribute('aria-label','اليوم التشغيلي');
  panel.style.cssText='margin:10px 0;padding:14px;border:1px solid #dc5660;border-radius:14px;background:var(--ffb-surface,#fff);direction:rtl;';
  panel.innerHTML='<h3 style="margin:0 0 9px">📆 اليوم التشغيلي · 8:00 ص – 2:00 ص</h3>'+
    '<p id="ffF01Window" class="muted">تبدأ عدادات اليوم تلقائياً في الثامنة صباحاً، ولا تُحذف الطلبات السابقة.</p>'+
    '<div class="row" style="flex-wrap:wrap;align-items:end;gap:9px">'+
    '<label>اليوم المطلوب<input type="date" id="ffF01Date"></label>'+
    '<label>مقارنة مع<input type="date" id="ffF01Compare"></label>'+
    '<label>الفرع<select id="ffF01Branch"><option value="">كل الفروع المسموح بها</option></select></label>'+
    '<button type="button" class="outline" id="ffF01Today">اليوم</button>'+
    '<button type="button" class="primary" id="ffF01Refresh">عرض</button></div>'+
    '<p id="ffF01Message" class="muted" role="status" aria-live="polite"></p>'+
    '<div id="ffF01Stats" class="ff-f01-stats" style="display:flex;flex-wrap:wrap;gap:12px"></div>';
  meter.after(panel);
  const day=$('ffF01Date'),compare=$('ffF01Compare'),branch=$('ffF01Branch');
  const info=$('ffF01Window'),message=$('ffF01Message'),stats=$('ffF01Stats');
  let displayedDay=businessDate(),viewer='',sequence=0,busy=false,followToday=true;
  function prevDay(d,days=1){
    const x=new Date(d+'T12:00:00Z');x.setUTCDate(x.getUTCDate()-days);
    return x.toISOString().slice(0,10);
  }
  function id(){return (typeof user!=='undefined'&&user?.id)?String(user.id):'';}
  function role(){return (typeof data!=='undefined'&&data?.role)||'';}
  function authorized(){return Boolean(id())&&allowed.has(role());}
  function zero(){stats.replaceChildren();message.textContent='';}
  function chooseBranch(){
    const chosen=branch.value;
    const options=(typeof data!=='undefined'&&Array.isArray(data?.branches))?data.branches:[];
    const current=new Set(options.map(x=>String(x.id)));
    branch.replaceChildren(new Option('كل الفروع المسموح بها',''));
    for(const b of options)branch.add(new Option(b.name||b.code||'فرع',b.id));
    branch.value=current.has(chosen)?chosen:'';
  }
  function clear(){
    sequence++;viewer='';busy=false;panel.hidden=true;zero();chooseBranch();
  }
  window.addEventListener('ff-luxe-session-reset',clear);
  $('logoutBtn')?.addEventListener('click',clear);
  function money(n){return Number(n||0).toLocaleString('ar-YE',{maximumFractionDigits:2});}
  function card(label,value){
    const c=aria('div');c.style.cssText='flex:1 1 125px;background:var(--ffb-bg,#f8f8f8);border:1px solid #ddd;border-radius:11px;padding:10px;';
    const name=aria('p',label);name.style.cssText='font-size:12px;margin:0 0 6px;';
    const val=aria('strong',String(value));val.style.cssText='font-size:18px;';
    c.append(name,val);return c;
  }
  function render(result){
    const arr=Array.isArray(result?.days)?result.days:[];
    const a=arr.find(x=>x.day===day.value);
    const b=arr.find(x=>x.day===compare.value);
    if(!a||!b)throw new Error('استجابة غير مكتملة من قاعدة البيانات');
    stats.replaceChildren();
    const first=aria('div');first.style.cssText='flex:1 1 250px;';
    first.append(aria('h4','📅 '+day.value));
    const tiles=aria('div');tiles.style.cssText='display:flex;flex-wrap:wrap;gap:8px;';
    for(const [label,value] of [['الطلبات',a.orders],['المُسلّمة',a.delivered],
      ['الملغاة',a.cancelled],['طلبات خارج الدوام',a.anomalies],
      ['قيمة الطلبات (ليست تحصيلاً)',money(a.value)+' ريال']])tiles.append(card(label,value));
    first.append(tiles);
    const second=aria('div');second.style.cssText='flex:1 1 230px;border-inline-start:1px solid #ddd;padding-inline-start:12px;';
    second.append(aria('h4','📊 مقارنة '+compare.value));
    const tiles2=aria('div');tiles2.style.cssText='display:flex;flex-wrap:wrap;gap:8px;';
    for(const [label,value] of [['الطلبات',b.orders],['المُسلّمة',b.delivered],
      ['الملغاة',b.cancelled],['قيمة الطلبات',money(b.value)+' ريال']])tiles2.append(card(label,value));
    second.append(tiles2);stats.append(first,second);
    message.textContent='تاريخ تشغيلي موحد بتوقيت صنعاء. الطلبات الجارية من الأيام السابقة لا تُخفى.';
  }
  async function load(){
    if(!authorized()){clear();return;}
    if(busy||!day.value||!compare.value)return;
    const me=id(),asRole=role(),request=++sequence,filter=branch.value;
    const valid=()=>request===sequence&&id()===me&&role()===asRole&&authorized()
      &&branch.value===filter;
    busy=true;$('ffF01Refresh').disabled=true;
    try{
      const today=businessDate();
      if(day.value>today||compare.value>today)throw new Error('لا يجوز اختيار تاريخ تشغيلي مستقبلي');
      message.textContent='جارٍ جلب الإحصائيات…';stats.replaceChildren();
      const result=await rpc('ff_f01_daily_summary',{
        p_date:day.value,p_compare_date:compare.value,p_branch:filter||null
      });
      if(!valid())return;
      render(result);
    }catch(error){if(valid())message.textContent='تعذر عرض التقرير: '+(error?.message||error);}
    finally{if(request===sequence){busy=false;$('ffF01Refresh').disabled=false;}}
  }
  function sync(withRefresh=false){
    const today=businessDate(),changed=displayedDay!==today;
    displayedDay=today;day.max=compare.max=today;
    const closed=closedHours();
    info.textContent='الفترة: 8:00 صباحاً – 2:00 صباحاً بتوقيت صنعاء'+
      (closed?' · ⏸️ المطعم خارج وقت الدوام، والطلبات تُنسب لليوم السابق.':'')+
      ' · لا توجد عملية حذف أو تصفير لقاعدة البيانات.';
    if(changed&&followToday){day.value=today;compare.value=prevDay(today);if(authorized())void load();}
    if(withRefresh&&authorized())void load();
  }
  function show(){
    if(!authorized()){clear();return;}
    const me=id();
    if(me!==viewer){viewer=me;followToday=true;day.value=businessDate();compare.value=prevDay(day.value);chooseBranch();}
    panel.hidden=false;sync(true);
  }
  day.addEventListener('change',()=>{followToday=day.value===businessDate();});
  compare.addEventListener('change',()=>{});
  $('ffF01Today').onclick=()=>{followToday=true;day.value=businessDate();compare.value=prevDay(day.value);void load();};
  $('ffF01Refresh').onclick=()=>{followToday=day.value===businessDate();void load();};
  branch.addEventListener('change',()=>void load());
  window.addEventListener('ff-assembly-snapshot-success',show);
  document.addEventListener('visibilitychange',()=>{if(!document.hidden)sync(true);});
  window.addEventListener('online',()=>sync(true));
  sync();
  setInterval(()=>sync(),15000);
})();
