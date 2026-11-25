"""A07 offline Chromium regression: all 16 packs on the seven actual role workspaces."""
import json
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
out=root/"a07-evidence";out.mkdir(exist_ok=True)
server=ThreadingHTTPServer(("127.0.0.1",0),partial(SimpleHTTPRequestHandler,directory=root))
Thread(target=server.serve_forever,daemon=True).start()
origin=f"http://127.0.0.1:{server.server_port}/"
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
  if(name==='ff_a07_effective_designs')return window.__a07Rows||{};
  if(name==='ff_a07_design_catalog')return window.__a07Catalog||[];
  if(name==='ff_a07_named_design')return 4321;
  if(name==='ff81_effective_design')return null;
  return [];
 };
 data={role,branches,orders:role==='manager'||role==='customer_service'||role==='supervisor'?orders:[],drivers:[],offers:[],driver_id:'qa-driver',my_presence:'offline'};
 if(role==='assembly'){await ffV12Start();return}
 if(role==='burger_kitchen'){data=null;await window.ffBurgerStart();return}
 draw();
}"""
roles={"manager":("dashboard","#ffx-dashboard"),"supervisor":("dashboard","#ffx-dashboard"),"customer_service":("orders","#serviceOnly"),"cashier":("cashier","#cashierView"),"driver":("driver","#driverView"),"assembly":("assembly","#ffV12AssemblyWorkspace"),"burger_kitchen":("burger_kitchen","#ffBurgerKitchenWorkspace")}
results=[]
with sync_playwright() as pw:
 browser=pw.chromium.launch(channel="chrome")
 for role,(screen,selector) in roles.items():
  ctx=browser.new_context(viewport={"width":390,"height":850},service_workers="block",reduced_motion="reduce")
  ctx.route("**/*",lambda route:route.continue_() if route.request.url.startswith(origin) else route.abort())
  page=ctx.new_page();page.goto(origin,wait_until="load");page.evaluate(fixture,role)
  page.wait_for_function("()=>!!window.ffA07Design&&!!window.ffDashboardStudio")
  if role=="assembly":page.locator("#ffV12Toggle").click()
  if role in ("driver","cashier","customer_service"):
   key={"driver":"attendance","cashier":"cashier","customer_service":"new"}[role]
   page.locator('#ffx-mobile-nav button[data-key="'+key+'"]').click()
  signatures=set()
  if role in ('cashier','driver'):
   holder='#cashierOrders' if role=='cashier' else '#driverTasks'
   status_probe=page.locator(holder).evaluate('e=>{const n=document.createElement("article");n.className="item ff-luxe-cancelled";n.id="a07-status-probe";e.append(n);return getComputedStyle(n).borderTopColor}')
  for width in (320,360,390,430,768,1024,1440):
   page.set_viewport_size({"width":width,"height":850})
   for i in (range(1,17) if width in (390,1440) else (1,8,16)):
    pack=f"D{i:02d}"
    row={"id":i,"pack":pack,"bar":"labels","layout_text":"وصف تجريبي","style_config":{}}
    page.evaluate("""async ([screen,row])=>{window.__a07Rows={[screen]:row};await window.ffDashboardStudio.sync(true)}""",[screen,row])
    result=page.locator(selector).evaluate("""e=>{const s=getComputedStyle(e);return {pack:e.dataset.ffA07Pack,signature:['bg','ink','radius','gap','cols','pad','font','shadow','scale'].map(k=>s.getPropertyValue('--a07-'+k)).join('|'),overflow:document.documentElement.scrollWidth>innerWidth+1}}""")
    assert result["pack"]==pack,(role,width,pack,result)
    assert not result["overflow"],(role,width,pack,"page overflow")
    signatures.add(result["signature"]);results.append({"role":role,"width":width,"pack":pack})
    if i in (1,16) and width in (390,1440):page.screenshot(path=out/f"{role}-{width}-{pack}.png",animations="disabled")
  assert len(signatures)==16,(role,"distinct packs",len(signatures))
  if role in ("cashier","driver"):
   assert page.locator("#a07-status-probe").evaluate("n=>getComputedStyle(n).borderTopColor")==status_probe
  if role=="driver":
   page.set_viewport_size({"width":390,"height":850})
   page.locator('#ffx-mobile-nav button[data-key="attendance"]').click()
   assert page.locator("#clockInBtn").is_visible(),"pre-existing attendance workspace must be opened"
   page.evaluate("""async ()=>{window.__a07Button=document.getElementById('clockInBtn');window.__a07Rows={driver:{id:500,pack:'D09',bar:'labels',style_config:{elements:{driver_actions:[{key:'clockInBtn',shape:'pill',size:'large'},{key:'clockOutBtn',shape:'outline',size:'normal'},{key:'ff51BreakBtn',shape:'pack',size:'normal'}]}}}};await ffDashboardStudio.sync(true)}""")
   assert page.locator("#clockInBtn").get_attribute("data-ff-a07-shape")=="pill"
   assert page.locator("#clockInBtn").evaluate("n=>n===window.__a07Button && getComputedStyle(n).order==='1'"),page.evaluate("()=>['clockInBtn','clockOutBtn','ff51BreakBtn'].map(id=>{const n=document.getElementById(id);return {id,order:getComputedStyle(n).order,attr:n.dataset.ffA07Order,parent:n.parentElement.className,display:getComputedStyle(n.parentElement).display,same:n===window.__a07Button}})")
   assert page.locator("#clockInBtn").is_visible()
   assert page.locator("#clockOutBtn").is_visible()
   assert page.locator("#cashierView").get_attribute("data-ff-a07-pack") is None
  if role in ("manager","customer_service"):
   page.set_viewport_size({"width":390,"height":850})
   page.evaluate("""async ()=>{document.getElementById('newItems').value='1 تشكن بدون شطة';document.getElementById('ffbQuickInput').value='نص محفوظ';window.__a07Rows={orders:{id:501,pack:'D10',bar:'labels',style_config:{density:'compact'}}};await ffDashboardStudio.sync(true)}""")
   assert page.locator("#newItems").input_value()=="1 تشكن بدون شطة"
   assert page.locator("#ffbQuickInput").input_value()=="نص محفوظ"
   assert page.locator("#cashierView").get_attribute("data-ff-a07-pack") is None
  if role=="manager":
   page.evaluate("()=>window.ffDashboardStudio.open()")
   dlg=page.locator("#ffStudio");assert dlg.is_visible()
   dlg.locator("select[name=screen]").select_option("cashier")
   dlg.locator("select[name=role]").select_option("cashier")
   dlg.locator("#ffA07Gallery summary").click()
   assert dlg.locator(".ff-a07-gallery-choice").count()==16
   dlg.locator(".ff-a07-gallery-choice").nth(7).click()
   assert dlg.locator("select[name=pack]").input_value()=="D08"
   assert dlg.locator("[data-a07-after] [data-ff-a07-pack=D08]").count()==1
   dlg.locator("#ffA07StyleFields summary").click()
   dlg.locator("select[name=a07_surface]").select_option("dark")
   assert dlg.locator("[data-a07-after] [data-a07-surface=dark]").count()==1
   dlg.locator("select[name=viewport]").select_option("390")
   page.screenshot(path=out/"manager-gallery.png",animations="disabled")
   dlg.locator("select[name=screen]").select_option("driver")
   dlg.locator("select[name=role]").select_option("driver")
   dlg.locator("#ffA07Elements summary").click()
   dlg.locator("[data-a07-group]").select_option("driver_actions")
   first=dlg.locator(".ff-a07-element-row").first
   assert first.get_attribute("data-element-key")=="ff51BreakBtn"
   first.get_by_role("button",name="تأخير").click()
   assert dlg.locator(".ff-a07-element-row").first.get_attribute("data-element-key")=="clockInBtn"
   dlg.locator(".ff-a07-element-row").first.locator("select").first.select_option("pill")
   dlg.locator("[data-a07-undo]").click()
   assert dlg.locator(".ff-a07-element-row").first.locator("select").first.input_value()=="pack"
   dlg.locator("[data-a07-redo]").click()
   assert dlg.locator(".ff-a07-element-row").first.locator("select").first.input_value()=="pill"
   assert dlg.locator("[data-a07-after] [data-ff-a07-shape=pill]").count()>=1
   dlg.locator("input[name=draftName]").fill("مسودة اختبار آمنة")
   dlg.locator("button[type=submit]").click()
   page.wait_for_function("()=>window.__a06Calls.some(c=>c.name==='ff_a07_named_design')")
   payload=page.evaluate("()=>window.__a06Calls.filter(c=>c.name==='ff_a07_named_design').at(-1).args")
   assert payload["p_screen"]=="driver" and payload["p_style"]["elements"]["driver_actions"][0]["key"]=="clockInBtn"
   assert payload["p_style"]["elements"]["driver_actions"][0]["shape"]=="pill"
   assert len(payload["p_style"]["elements"]["driver_actions"])==3
   assert not page.evaluate("()=>window.__a06Calls.some(c=>['ff_ui_publish','ff_ui_control_trial'].includes(c.name))")
   dlg.locator("[data-close]").click()
   page.evaluate("""()=>{window.__a07Catalog=Array.from({length:17},(_,i)=>({code:'D'+String(i+1).padStart(2,'0'),name:'QA '+(i+1)}));ffDashboardStudio.open()}""")
   page.wait_for_function("()=>document.querySelector('#ffStudio select[name=pack]').options.length===17")
   assert dlg.locator("select[name=pack] option[value=D17]").count()==1
   dlg.locator("[data-close]").click()
  page.evaluate("()=>window.dispatchEvent(new Event('ff-luxe-session-reset'))")
  assert page.locator(selector).get_attribute("data-ff-a07-pack") is None
  print("PASS A07",role,47,"role/width/pack checks",flush=True)
  ctx.close()
 browser.close()
server.shutdown()
(out/"role-pack-matrix.json").write_text(json.dumps(results,ensure_ascii=False,indent=2))
assert len(results)==7*47
print("PASS A07",len(results),"actual role/width/pack checks, gallery and reset",flush=True)
