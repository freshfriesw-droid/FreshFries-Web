"""A04: real Chrome interactions using production pages and offline RPC fixtures.
No production network, accounts, or records. Actual devices and push delivery are field acceptance.
"""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[1]
out = root / "a04-evidence"
out.mkdir(exist_ok=True)
server = ThreadingHTTPServer(("127.0.0.1",0),partial(SimpleHTTPRequestHandler,directory=root))
Thread(target=server.serve_forever,daemon=True).start()
origin=f"http://127.0.0.1:{server.server_port}/"
fixture="""async ({role})=>{
  document.body.dataset.access='staff';
  document.getElementById('loginOverlay').classList.add('hidden');
  user={id:'qa-'+role,email:'qa@example.invalid'};
  data=null; selfPermissions={};
  const branch={id:'qa-cairo',name:'فرع تجريبي',code:'cairo'};
  const ago=n=>new Date(Date.now()-n*60000).toISOString();
  const orders=[
   {id:'order-old',number:1,cashier_stage:'preparing',driver_id:'d1',driver_name:'QA',area:'QA',created_at:ago(45),items:[{name:'برجر',qty:1,item_notes:'بدون بصل'}]},
   {id:'order-ready',number:2,cashier_stage:'ready',driver_id:'d2',driver_name:'QA',area:'QA',created_at:ago(4),items:[]},
   {id:'order-new',number:3,cashier_stage:'printed',driver_id:'d3',driver_name:'QA',area:'QA',created_at:ago(2),items:[]}
  ];
  const tickets=[
   {id:'new',branch_id:branch.id,branch_name:branch.name,order_kind:'local',status:'sent',invoice_ref:'NEW',sent_at:ago(3),items:[{name:'برجر',qty:1}]},
   {id:'prep',branch_id:branch.id,branch_name:branch.name,order_kind:'local',status:'preparing',invoice_ref:'PREP',sent_at:ago(30),accepted_at:ago(29),kitchen_id:user.id,items:[{name:'برجر',qty:1,item_notes:'بدون بصل'}]},
   {id:'done',branch_id:branch.id,branch_name:branch.name,order_kind:'local',status:'ready',invoice_ref:'DONE',sent_at:ago(90),accepted_at:ago(89),ready_at:ago(80),items:[{name:'برجر',qty:1}]}
  ];
  window.__a04Calls=[];window.__a04Revoked=false;
  client={channel:()=>{const ch={on:()=>ch,subscribe:()=>ch};return ch},removeChannel:async()=>true};
  rpc=async(name,args={})=>{
   window.__a04Calls.push({name,args});
   if(window.__a04Revoked&&name==='ff_burger_my_branch')throw Error('QA revoked');
   if(name==='ff_v12_assembly_snapshot')return {role:'assembly',branch,orders};
   if(name==='ff_burger_my_branch')return {role,branches:[branch]};
   if(name==='ff_burger_menu')return [{id:'qa-item',name:'سماش برجر',price:1000,category:'البرجر'}];
   if(name==='ff_burger_list')return role==='burger_kitchen'?structuredClone(tickets):[];
   if(name==='ff_burger_online_status')return [{branch_id:branch.id,branch_name:branch.name,online_count:1}];
   if(name==='ff_burger_confirm_notes'){tickets.find(t=>t.id===args.p_ticket).notes_confirmed_at=new Date().toISOString();return true;}
   if(name==='ff_burger_transition'){const t=tickets.find(t=>t.id===args.p_ticket);t.status=args.p_action==='ready'?'ready':'preparing';t.ready_at=new Date().toISOString();return {saved:true};}
   if(name==='ff_burger_send')return {saved:true,id:'qa-created'};
   return [];
  };
  if(role==='assembly')await ffV12Start();
  else await window.ffBurgerStart();
}"""
try:
    with sync_playwright() as pw:
        browser=pw.chromium.launch(channel="chrome")
        for width in (390,1280):
            for role in ("assembly","burger_kitchen"):
                ctx=browser.new_context(viewport={"width":width,"height":850},is_mobile=width<850,service_workers="block")
                ctx.route("**/*",lambda route:route.continue_() if route.request.url.startswith(origin) else route.abort())
                page=ctx.new_page()
                page.goto(origin,wait_until="load")
                page.evaluate(fixture,{"role":role})
                if role=="assembly":
                    toggle=page.locator("#ffV12Toggle")
                    assert toggle.get_attribute("aria-expanded")=="false"
                    assert not page.locator("#ffV12Refresh").is_visible()
                    assert page.evaluate("window.__a04Calls.filter(c=>c.name==='ff_v12_assembly_snapshot').length")==0
                    toggle.click()
                    page.wait_for_function("document.getElementById('ffV12CountAll').textContent==='3'")
                    assert page.locator("#ffV12AssemblyOrders article").count()==3
                    page.locator('[data-assembly-filter="late"]').click()
                    assert page.locator("#ffV12AssemblyOrders article").count()==1
                    assert "بدون بصل" in page.locator("#ffV12AssemblyOrders").inner_text()
                    page.locator('[data-assembly-filter="priority"]').click()
                    assert page.locator("#ffV12AssemblyOrders article").count()==2
                    page.screenshot(path=out/f"assembly-{width}.png",animations="disabled")
                    page.locator("#ffV12BurgerOpen").click()
                    page.locator("#ffBurgerNew").click()
                    page.locator('[data-burger-item="qa-item"]').fill("2")
                    page.locator('[data-burger-item-note="qa-item"]').fill("بدون بصل")
                    page.locator("#ffBurgerSubmit").click()
                    page.wait_for_function("window.__a04Calls.some(c=>c.name==='ff_burger_send')")
                    sent=page.evaluate("window.__a04Calls.find(c=>c.name==='ff_burger_send').args")
                    assert sent["p_items"]==[{"id":"qa-item","qty":2,"item_notes":"بدون بصل"}]
                    page.wait_for_function("!document.getElementById('ffBurgerDialog').open")
                    toggle.click()
                    assert toggle.get_attribute("aria-expanded")=="false"
                    assert page.locator("#ffV12AssemblyOrders article").count()==0
                    assert "فرعك" in page.locator("#ffV12BranchTitle").inner_text()
                    print(f"PASS A04 assembly {width}px: explicit activation, live filters, line notes, send and close",flush=True)
                else:
                    page.wait_for_function("document.getElementById('ffBurgerPendingCount').textContent==='2'")
                    assert page.locator("#ffBurgerNewCount").inner_text()=="1"
                    assert page.locator("#ffBurgerPrepCount").inner_text()=="1"
                    assert page.locator("#ffBurgerLateCount").inner_text()=="1"
                    page.locator('[data-ff-burger-filter="sent"]').click()
                    assert page.locator("#ffBurgerKitchenActive article").count()==1
                    assert "NEW" in page.locator("#ffBurgerKitchenActive").inner_text()
                    page.locator('[data-ff-burger-filter="late"]').click()
                    card=page.locator("#ffBurgerKitchenActive article")
                    assert card.count()==1 and "بدون بصل" in card.inner_text()
                    ready=card.get_by_role("button",name="✅ الطلب جاهز للاستلام")
                    assert ready.is_disabled()
                    page.screenshot(path=out/f"kitchen-{width}.png",animations="disabled")
                    card.get_by_role("checkbox").check()
                    assert ready.is_enabled()
                    ready.click()
                    page.wait_for_function("document.getElementById('ffBurgerPendingCount').textContent==='1'")
                    calls=page.evaluate("window.__a04Calls.filter(c=>['ff_burger_confirm_notes','ff_burger_transition'].includes(c.name)).map(c=>c.name)")
                    assert calls==["ff_burger_confirm_notes","ff_burger_transition"],calls
                    page.evaluate("window.__a04Revoked=true")
                    page.locator("#ffBurgerKitchenRefresh").click()
                    page.wait_for_function("document.getElementById('ffBurgerPendingCount').textContent==='0'")
                    assert page.locator("#ffBurgerKitchenActive article").count()==0
                    print(f"PASS A04 kitchen {width}px: queues, late counts, note confirmation, ready and revoked-scope clear",flush=True)
                ctx.close()
        browser.close()
finally:
    server.shutdown()
