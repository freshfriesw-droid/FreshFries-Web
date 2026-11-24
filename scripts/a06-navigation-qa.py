"""A06: actual browser navigation on synthetic role fixtures, no production requests.
Runs the required seven widths and all five mobile bar shapes for every staff role.
Records real screenshots and CSS cascade inventory; never submits a real order.
"""
import json
import re
import os
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
out=root/"a06-evidence";out.mkdir(exist_ok=True)
server=ThreadingHTTPServer(("127.0.0.1",0),partial(SimpleHTTPRequestHandler,directory=root))
Thread(target=server.serve_forever,daemon=True).start()
origin=f"http://127.0.0.1:{server.server_port}/"
roles=("manager","supervisor","customer_service","cashier","driver","assembly","burger_kitchen")
widths=(320,360,390,430,768,1024,1440)
modes=("labels","icons","wide","floating","compact")
fixture="""async role=>{
 document.body.dataset.access='staff';document.body.classList.remove('ff-booting');
 document.getElementById('loginOverlay').classList.add('hidden');
 user={id:'qa-'+role,email:'qa@example.invalid'};
 const b={id:'b1',code:'cairo',name:'القاهرة'};
 const b2={id:'b2',code:'sam_mall',name:'سام مول'};
 const b3={id:'b3',code:'khamseen',name:'الخمسين'};
 const branches=['manager','customer_service','supervisor'].includes(role)?[b,b2,b3]:[b];
 selfPermissions={create_order:['manager','customer_service'].includes(role),view_reports:['manager','supervisor','customer_service'].includes(role),edit_order:true,assign_driver:true};
 const orders=[{id:'qa-order',number:123,branch_id:b.id,area:'منطقة تجريبية',status:'sent',phase:'assigned',cashier_stage:'waiting',driver_name:'موصل تجريبي',created_at:new Date().toISOString(),items:[]}];
 window.__a06Calls=[];
 client={channel:()=>{const ch={on:()=>ch,subscribe:()=>ch};return ch},removeChannel:async()=>true};
 rpc=async(name,args={})=>{
  window.__a06Calls.push({name,args});
  if(name==='ff_a06_nav_scope')return {role,revision:null,mode:'accordion',drawer_width:280,bar:null};
  if(name==='ff_burger_my_branch')return {role,branches:[b]};
  if(name==='ff_v12_assembly_snapshot')return {role:'assembly',branch:b,orders:[]};
  if(name==='ff_burger_menu'||name==='ff_burger_list')return [];
  if(name==='ff_burger_online_status')return [];
  if(name==='ff80_dashboard_metrics')return {role,business_day:'2026-11-25',orders_today:1,late_today:0,completed_today:0,available_drivers:0};
  if(name==='ff49_catalog')return [{id:'qa-item',name:'تشكن فرايز',price:1500,active:true,parser_aliases:['تشكن']}];
  if(name==='ff81_effective_design')return null;
  return [];
 };
 data={role,branches,orders:role==='manager'||role==='customer_service'||role==='supervisor'?orders:[],drivers:[],offers:[],driver_id:'qa-driver',my_presence:'offline'};
 if(role==='assembly'){await ffV12Start();return}
 if(role==='burger_kitchen'){data=null;await window.ffBurgerStart();return}
 draw();
}"""
collect_css="""()=>{
 const sheetRows=[],rules=[];
 function walk(list,source,scope=''){
  for(const r of list){if(r.selectorText&&r.style){for(const p of r.style)rules.push({source,scope,selector:r.selectorText,property:p,value:r.style.getPropertyValue(p),priority:r.style.getPropertyPriority(p)})}
   else if(r.cssRules)walk(r.cssRules,source,scope+' / '+(r.conditionText||r.name||r.constructor.name));}
 }
 for(const [i,s]of [...document.styleSheets].entries()){
  const source=s.ownerNode?.id||s.ownerNode?.getAttribute('href')||'inline-'+i;
  try{sheetRows.push({order:i,source,topRules:s.cssRules.length});walk(s.cssRules,source)}catch(e){sheetRows.push({order:i,source,error:e.message})}
 }
 const seen=new Map(),duplicates=[],conflicts=[];
 for(const r of rules){const key=[r.scope,r.selector,r.property].join('|'),prev=seen.get(key);if(prev){(prev.value===r.value&&prev.priority===r.priority?duplicates:conflicts).push({previous:prev,current:r})}seen.set(key,r)}
 return {sheets:sheetRows,declarations:rules.length,important:rules.filter(r=>r.priority==='important').length,duplicates,conflicts};
}"""
results=[]
baseline_path=os.getenv("A06_BASELINE")
baseline_server=None
if baseline_path:
 baseline_server=ThreadingHTTPServer(("127.0.0.1",0),partial(SimpleHTTPRequestHandler,directory=baseline_path))
 Thread(target=baseline_server.serve_forever,daemon=True).start()
 baseline_origin=f"http://127.0.0.1:{baseline_server.server_port}/"
with sync_playwright() as pw:
 browser=pw.chromium.launch(channel="chrome")
 for role in roles:
  ctx=browser.new_context(viewport={"width":390,"height":850},service_workers="block",reduced_motion="reduce")
  ctx.route("**/*",lambda route:route.continue_() if route.request.url.startswith(origin) else route.abort())
  page=ctx.new_page();page.goto(origin,wait_until="load");page.evaluate(fixture,role)
  special=role in ("assembly","burger_kitchen")
  nav="#ffA06SpecialNav" if special else "#ffx-mobile-nav"
  page.wait_for_function("(sel)=>document.querySelectorAll(sel+' button').length>=2",arg=nav)
  if role=="manager":
   report=page.evaluate(collect_css)
   (out/"css-cascade.json").write_text(json.dumps(report,ensure_ascii=False,indent=2))
   print("CSS cascade:",len(report["sheets"]),"sheets",len(report["duplicates"]),"exact duplicate property pairs",len(report["conflicts"]),"ordered override pairs",flush=True)
   if baseline_server:
    old=browser.new_context(viewport={"width":390,"height":850},service_workers="block",reduced_motion="reduce")
    old.route("**/*",lambda route:route.continue_() if route.request.url.startswith(baseline_origin) else route.abort())
    before=old.new_page();before.goto(baseline_origin,wait_until="load");before.evaluate(fixture,"manager")
    old_report=before.evaluate(collect_css)
    (out/"css-cascade-before.json").write_text(json.dumps(old_report,ensure_ascii=False,indent=2))
    before.screenshot(path=out/"manager-before-390.png",animations="disabled")
    before.set_viewport_size({"width":1440,"height":850});before.screenshot(path=out/"manager-before-1440.png",animations="disabled")
    print("CSS before/after duplicate pairs:",len(old_report["duplicates"]),len(report["duplicates"]),"ordered overrides:",len(old_report["conflicts"]),len(report["conflicts"]),flush=True)
    # Compare actual computed operational card/status styles, excluding intended new navigation treatment.
    probe="""()=>{const values={};for(const id of ['cashierOrders','driverTasks','staffOrders']){const p=document.getElementById(id);const n=document.createElement('article');n.className='item';p.append(n);const a=getComputedStyle(n);const normal=[a.borderTopColor,a.borderTopWidth,a.borderRadius];n.classList.add('ff-luxe-cancelled');const b=getComputedStyle(n);values[id]={normal,cancelled:[b.borderTopColor,b.borderTopWidth,b.borderRadius]};n.remove()}return values}"""
    before.set_viewport_size({"width":390,"height":850})
    old_cards=before.evaluate(probe);new_cards=page.evaluate(probe)
    for role_id in ["cashierOrders","driverTasks"]:
     assert old_cards[role_id]==new_cards[role_id],(role_id,old_cards,new_cards)
    (out/"card-cascade-parity.json").write_text(json.dumps({"before":old_cards,"after":new_cards},indent=2))
    old.close()
  for width in widths:
   page.set_viewport_size({"width":width,"height":850})
   page.wait_for_timeout(100)
   if width<=850:
    for mode in modes:
     page.evaluate("(m)=>document.body.dataset.ffA06Bar=m",mode)
     result=page.evaluate("""sel=>{
      const bar=document.querySelector(sel),r=bar.getBoundingClientRect(),buttons=[...bar.querySelectorAll('button')].filter(b=>b.getClientRects().length);
      return {bar:[r.x,r.right,r.height],items:buttons.map(b=>({key:b.dataset.key,label:b.getAttribute('aria-label'),h:b.getBoundingClientRect().height,w:b.getBoundingClientRect().width})),overflow:document.documentElement.scrollWidth>innerWidth+1}
     }""",nav)
     assert result["bar"][0]>=-1 and result["bar"][1]<=width+1 and result["bar"][2]>0,(role,width,mode,result)
     assert all(x["label"] and x["h"]>=44 and x["w"]>=44 for x in result["items"]),(role,width,mode,result)
     assert any(x["key"]=="more" for x in result["items"]),(role,width,mode)
     if result["overflow"]:
      print("OVERFLOW",role,width,mode,page.evaluate("""()=>({viewport:innerWidth,document:document.documentElement.scrollWidth,nodes:[...document.querySelectorAll('body *')].filter(e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e);return r.width>0&&r.height>0&&s.visibility!=='hidden'&&(r.left< -2||r.right>innerWidth+2)&&!e.closest('[aria-hidden="true"]')}).map(e=>({tag:e.tagName,id:e.id,cls:String(e.className).slice(0,100),left:Math.round(e.getBoundingClientRect().left),right:Math.round(e.getBoundingClientRect().right),width:e.scrollWidth,display:getComputedStyle(e).display})).slice(0,45)})"""),flush=True)
     assert not result["overflow"],(role,width,mode,"page horizontal overflow")
     results.append({"role":role,"width":width,"bar":mode,"visible":len(result["items"]),"page_overflow":result["overflow"]})
    page.evaluate("document.body.dataset.ffA06Bar='labels'")
    if width==390:page.screenshot(path=out/f"{role}-390.png",animations="disabled")
   else:
    assert page.locator(nav).is_hidden(),(role,width)
    if width==1440:page.screenshot(path=out/f"{role}-1440.png",animations="disabled")
  page.set_viewport_size({"width":390,"height":850});page.evaluate("document.body.dataset.ffA06Bar='labels'")
  if special:
   page.locator(nav+' button[data-key="more"]').click()
   assert page.locator("#ffA06SpecialMore").is_visible()
   page.locator("#ffA06MoreClose").click()
   key="preparing"
   page.locator(nav+' button[data-key="'+key+'"]').click()
   if role=="assembly":
    assert page.locator('#ffV12Toggle').get_attribute("aria-expanded")=="true"
    assert page.locator('[data-assembly-filter="preparing"]').get_attribute("aria-pressed")=="true"
   else:assert page.locator('[data-ff-burger-filter="preparing"]').get_attribute("aria-pressed")=="true"
  else:
   page.locator(nav+' button[data-key="more"]').click()
   page.wait_for_function("document.querySelector('#ffx-sidebar').getAttribute('aria-hidden')===null")
   links=page.locator('#ffx-nav button[data-key]')
   assert links.count()>0
   if role!="manager":assert page.locator('#ffx-nav button[data-key="studio"]').count()==0
   mode=page.locator('#ffx-nav select[aria-label="طريقة عرض القائمة"]')
   mode.select_option("flat")
   assert page.locator('#ffx-nav .ffx-nav-group-links[hidden]').count()==0
   mode.select_option("accordion")
   toggle=page.locator('#ffx-nav [data-ffx-group-toggle]').first
   toggle.click();expanded=toggle.get_attribute("aria-expanded")
   page.keyboard.press("Escape")
   page.locator("#ffx-theme-toggle").click()
   page.locator("#ffx-menu").click()
   assert page.locator('#ffx-nav [data-ffx-group-toggle]').first.get_attribute("aria-expanded")==expanded
   search=page.locator("#ffx-nav-search");search.fill("قيمة غير موجودة");assert page.locator('#ffx-nav .ffx-nav-group:not([hidden])').count()==0
   search.fill("");page.keyboard.press("Escape")
   if role in ("manager","customer_service","supervisor"):
    page.locator("#ffx-menu").click();page.locator("#ffx-nav-search").fill("123");assert page.locator('#ffA06OrderSearchResults button[data-ff-a06-result="123"]').count()==1
    page.locator('#ffA06OrderSearchResults button[data-ff-a06-result="123"]').click();assert page.locator("#orderSearch").input_value()=="123"
    page.locator("#ffx-menu").click();page.locator("#ffx-nav-search").fill("");page.keyboard.press("Escape")
   if role in ("manager","customer_service"):
    page.evaluate("""()=>{document.querySelector('#newItems').value='1 تشكن بدون شطة';document.querySelector('#newFee').value='500';document.querySelector('#ffbQuickInput').value='مسودة محفوظة'}""")
    page.locator("#ffx-menu").click();page.locator("#ffx-nav-search").fill("طلب جديد")
    page.locator('#ffx-nav button[data-key="new"]').click()
    assert page.locator("#newItems").input_value()=="1 تشكن بدون شطة"
    assert page.locator("#newFee").input_value()=="500"
    assert page.locator("#ffbQuickInput").input_value()=="مسودة محفوظة"
   elif role=="driver":
    page.locator(nav+' button[data-key="attendance"]').click()
    assert page.locator("#clockInBtn").is_visible()
  print("PASS A06 role",role,"7 widths, 5 bar modes, navigation and role scope",flush=True)
  ctx.close()
 browser.close()
server.shutdown()
if baseline_server:baseline_server.shutdown()
(out/"role-width-bar.json").write_text(json.dumps(results,ensure_ascii=False,indent=2))
assert len(results)==7*5*5
print("PASS A06",len(results),"mobile role/width/bar combinations; 14 desktop role/width checks")
