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
  signatures=set()
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
