"""A05 browser acceptance, real Chrome with isolated mock RPCs. No production writes."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
server=ThreadingHTTPServer(("127.0.0.1",0),partial(SimpleHTTPRequestHandler,directory=root))
Thread(target=server.serve_forever,daemon=True).start()
origin=f"http://127.0.0.1:{server.server_port}/"
fixture="""async () => {
 document.body.dataset.access='staff';document.body.classList.remove('ff-booting');
 document.getElementById('loginOverlay').classList.add('hidden');
 user={id:'qa-manager'};selfPermissions={create_order:true,edit_order:true,manage_branches:true};
 data={role:'manager',branches:[{id:'b1',name:'القاهرة',code:'cairo'},{id:'b2',name:'سام مول',code:'sam'}],orders:[],drivers:[],offers:[]};
 window.__calls=[];rpc=async(name,args={})=>{
 window.__calls.push({name,args});
 if(name==='ff38_admin_staff_list')return [{user_id:'one',name:'أحمد محمد',role:'cashier',active:true,branches:['b1']},{user_id:'two',name:'سالم علي',role:'driver',active:false,branches:['b2']}];
 if(name==='ff_a05_branch_policy')return {can_write:true,hours:[],tariffs:[],hour_history:[],tariff_history:[]};
 if(name==='ff_a05_area_fee_hint')return {approved:{fee:500,effective_at:new Date().toISOString(),source:'QA'},history:[]};
 if(name==='ff_a05_set_area_tariff')return {saved:true};
 return [];
 };
 draw();document.getElementById('staffAdminCard').hidden=false;
 await loadStaffAdmin();
}"""
try:
 with sync_playwright() as pw:
  browser=pw.chromium.launch(channel="chrome")
  for width in (390,1280):
   ctx=browser.new_context(viewport={"width":width,"height":900},is_mobile=width<850,service_workers="block")
   ctx.route("**/*",lambda route:route.continue_() if route.request.url.startswith(origin) else route.abort())
   page=ctx.new_page();page.goto(origin,wait_until="load");page.evaluate(fixture)
   assert page.locator("[data-ff-a05-staff]").count()==2
   page.locator("#ffA05StaffSearch").evaluate("(e)=>{e.value='أحمد';e.dispatchEvent(new Event('input'))}")
   assert page.locator("[data-ff-a05-staff]:not([hidden])").count()==1
   page.locator("#ffA05StaffSearch").evaluate("(e)=>{e.value='';e.dispatchEvent(new Event('input'))}")
   page.locator("#ffA05StaffActive").evaluate("(e)=>{e.value='false';e.dispatchEvent(new Event('change'))}")
   assert "سالم" in page.locator("[data-ff-a05-staff]:not([hidden])").inner_text()
   assert page.evaluate("""()=>{const e=document.querySelector('#newBranch');e.value='b2';e.dispatchEvent(new Event('change',{bubbles:true}));const node=e.options[0];fillBranchSelects();return e.value==='b2'&&e.options[0]===node}""")
   page.evaluate("""()=>{document.querySelector('#newFee').value='321';const a=document.querySelector('#newArea');a.value='QA area';a.dispatchEvent(new Event('input'));}""")
   page.wait_for_function("document.getElementById('ffA05FeeHint').textContent.includes('500')")
   assert page.locator("#newFee").input_value()=="321"
   page.locator("#ffA05FeeHint button").evaluate("(e)=>e.click()")
   assert page.locator("#newFee").input_value()=="500"
   page.wait_for_function("!document.querySelector('#ffA05BranchCard').classList.contains('hidden')")
   page.locator("#ffA05BranchPolicyBtn").evaluate("(e)=>e.click()")
   page.wait_for_function("!document.getElementById('ffA05PolicyWrite').hidden")
   page.locator("#ffA05Area").fill("QA area");page.locator("#ffA05Tariff").fill("700");page.locator("#ffA05Reason").fill("QA reason")
   page.locator("#ffA05SaveTariff").click()
   page.wait_for_function("window.__calls.some(c=>c.name==='ff_a05_set_area_tariff'&&c.args.p_fee===700&&c.args.p_branch==='b2')")
   page.locator("#ffA05Close").click()
   page.evaluate("window.dispatchEvent(new Event('ff-luxe-session-reset'))")
   assert page.locator("#staffAdminList").inner_text()==""
   assert not page.locator("#ffA05BranchDialog").is_visible()
   print(f"PASS A05 Chrome {width}: staff filters, stable branch options, fee not overwritten, explicit tariff save, logout cleanup",flush=True)
   ctx.close()
  browser.close()
finally: server.shutdown()
