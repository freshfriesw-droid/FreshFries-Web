"""A08 browser QA with synthetic role data, real UI interactions and no live data writes."""
import json
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
out=root/"a08-evidence";out.mkdir(exist_ok=True)
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
 selfPermissions={create_order:['manager','customer_service'].includes(role),view_reports:['manager','supervisor','customer_service'].includes(role),edit_order:true,assign_driver:true,manage_drivers:role==='customer_service'};
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
  if(name==='ff80_dashboard_metrics'){
    const b2=args.p_branch==='b2',orders=b2?7:35,branch=b2?{id:'b2',name:'سام مول'}:b;
    return {role,business_day:'2026-11-25',orders_today:orders,late_today:2,completed_today:3,available_drivers:['cashier','driver'].includes(role)?9999:4,
      recent_activity:[{order_number:b2?2222:1111,branch_name:branch.name,branch_id:branch.id,status:'sent',updated_at:'2026-11-25T10:00:00Z'}],
      branch_status:[{branch_id:branch.id,branch_name:branch.name,active:true,orders_today:orders,late_today:2,completed_today:3,available_drivers:['cashier','driver'].includes(role)?9999:4}]};
  }
  if(name==='ff_a08_metric_detail'){
    const total=args.p_branch==='b2'?7:35;
    const result={role,metric:args.p_metric,business_day:'2026-11-25',offset:args.p_offset,limit:30,total,rows:Array.from({length:Math.min(30,total-args.p_offset)},(_,i)=>({order_number:10000+args.p_offset+i,branch_name:'القاهرة',status:'sent',updated_at:'2026-11-25T10:00:00Z'}))};
    if(window.__a08HoldDetail){window.__a08HoldDetail=false;return new Promise(resolve=>window.__a08Release=()=>resolve(result))}
    return result;
  }
  if(name==='ff_a08_manager_card_source')return [];
  if(name==='ff_a07_manager_style_layers')return {sources:{}};
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
roles=("manager","supervisor","customer_service","cashier","driver")
cards=[
 {"metric":"orders_today","label":"طلبات اليوم","size":"wide","tone":"red","icon":"clock"},
 {"metric":"late_today","label":"متأخرة","size":"normal","tone":"neutral"},
 {"metric":"completed_today","label":"منجزة","size":"full","tone":"black"},
 {"metric":"available_drivers","label":"الجاهزون","size":"normal","tone":"default"},
 {"metric":"orders_today","label":"حصري للمدير","size":"normal","tone":"default","roles":["manager"]},
 {"metric":"orders_today","label":"صلاحية إضافية","size":"normal","tone":"default","permission":"manage_drivers"}]
widths=(320,360,390,430,768,1024,1440)
results=[]
with sync_playwright() as pw:
 browser=pw.chromium.launch(channel="chrome")
 for role in roles:
  ctx=browser.new_context(viewport={"width":390,"height":850},service_workers="block",reduced_motion="reduce")
  ctx.route("**/*",lambda route:route.continue_() if route.request.url.startswith(origin) else route.abort())
  page=ctx.new_page();page.goto(origin,wait_until="load");page.evaluate(fixture,role)
  page.wait_for_function("()=>!!window.ffA08Dashboard&&!!window.ffDashboardStudio")
  page.wait_for_function("()=>document.querySelector('#ffx-kpis [data-ffx-metric=orders_today] .ffx-kpi-value')?.textContent==='35'")
  assert page.locator("#ffx-kpis .ffx-kpi").count()==4
  ready=page.locator("#ffx-kpis [data-ffx-metric=available_drivers] .ffx-kpi-value")
  assert ready.inner_text()==("—" if role in ("cashier","driver") else "4")
  for width in widths:
   page.set_viewport_size({"width":width,"height":850})
   page.evaluate("""async cards=>{window.__a07Rows={dashboard:{id:601,pack:'D01',bar:'labels',style_config:{layout:'single',dashboardPanels:{activity:false,branches:true,shortcuts:true},quickActions:['orders','settings','new']},card_layout:cards,card_layout_source:600}};await ffDashboardStudio.sync(true)}""",cards)
   expected=6 if role=="manager" else 5 if role=="customer_service" else 4
   assert page.locator("#ffx-kpis .ffx-kpi").count()==expected,(role,width,expected)
   assert page.locator("#ffx-kpis").get_attribute("data-a08-source")=="600"
   assert page.locator("#ffx-kpis").evaluate("e=>getComputedStyle(e).gridTemplateColumns.split(' ').length===1")
   assert page.locator("#ffA08Activity").is_hidden()
   assert page.locator("#ffA08Branches").get_attribute("hidden") is None
   assert ("9999" not in page.locator("#ffA08Branches").inner_text())
   actual=page.locator("#ffx-shortcuts [data-a08-action]").evaluate_all("els=>els.map(x=>x.dataset.a08Action)")
   expected_actions=(["orders","settings","new"] if role in ("manager","customer_service") else ["orders","settings"] if role=="supervisor" else ["settings"])
   assert actual==expected_actions,(role,actual)
   assert page.evaluate("document.documentElement.scrollWidth<=innerWidth+1"),(role,width,"overflow")
   page.evaluate("""async ()=>{window.__a07Rows.dashboard.style_config.quickActions=[{key:'settings',label:'إعداد مخصص',icon:'star',size:'full',tone:'red'},{key:'settings',label:'نسخة إعداد',icon:'clock',size:'normal',tone:'neutral'},'studio','new'];await ffDashboardStudio.sync(true)}""")
   action_nodes=page.locator("#ffx-shortcuts [data-a08-action]")
   assert action_nodes.evaluate_all("els=>els.map(e=>e.dataset.a08Action)")==(["settings","settings","studio","new"] if role=="manager" else ["settings","settings","new"] if role=="customer_service" else ["settings","settings"])
   assert action_nodes.first.inner_text()=="إعداد مخصص"
   assert action_nodes.first.get_attribute("data-a08-size")=="full" and action_nodes.first.get_attribute("data-a08-tone")=="red"
   assert action_nodes.first.evaluate("e=>getComputedStyle(e).backgroundColor")=="rgb(173, 23, 38)"
   assert page.evaluate("document.documentElement.scrollWidth<=innerWidth+1"),(role,width,"STEP04 overflow")
   page.evaluate("""async ()=>{window.__a07Rows.dashboard.style_config.quickActions=['orders','settings','new'];await ffDashboardStudio.sync(true)}""")
   results.append({"role":role,"width":width,"cards":expected,"actions":actual})
   if width in (390,1440):page.screenshot(path=out/f"{role}-{width}.png",animations="disabled")
  if role=="customer_service":
   page.evaluate("()=>{selfPermissions.manage_drivers=false;draw()}")
   assert page.locator("#ffx-kpis .ffx-kpi").count()==4
   page.evaluate("()=>{selfPermissions.view_reports=false;draw()}")
   assert page.locator("#ffx-kpis .ffx-kpi-value").evaluate_all("els=>els.every(e=>e.textContent==='—')")
  if role=="manager":
   page.set_viewport_size({"width":390,"height":850})
   page.evaluate("""async ()=>{window.__a07Rows={};await ffDashboardStudio.sync(true)}""")
   page.wait_for_function("()=>document.querySelector('#ffx-kpis [data-ffx-metric=orders_today] .ffx-kpi-value')?.textContent==='35'")
   page.locator("#ffx-kpis button[data-ffx-metric=orders_today]").click()
   dlg=page.locator("#ffA08Detail")
   assert dlg.is_visible()
   dlg.locator(".ff-a08-data-row").nth(29).wait_for()
   assert dlg.locator(".ff-a08-data-row").count()==30
   dlg.locator("[data-a08-next]").click()
   dlg.get_by_text("طلب #10030",exact=True).wait_for()
   assert dlg.locator(".ff-a08-data-row").count()==5
   assert dlg.locator("[data-a08-next]").is_disabled()
   dlg.locator("[data-a08-prev]").click()
   dlg.get_by_text("طلب #10000",exact=True).wait_for()
   assert dlg.locator(".ff-a08-data-row").count()==30
   page.screenshot(path=out/"metric-detail.png",animations="disabled")
   dlg.locator("[data-a08-close]").click()
   page.evaluate("()=>{window.__a08HoldDetail=true;window.__a08Release=null}")
   page.locator("#ffx-kpis button[data-ffx-metric=orders_today]").click()
   page.wait_for_function("typeof window.__a08Release==='function'")
   page.evaluate("""()=>{const b=document.getElementById('ffx-branch');b.value='b2';b.dispatchEvent(new Event('change',{bubbles:true}));window.__a08Release()}""")
   assert dlg.is_hidden()
   assert dlg.locator(".ff-a08-data-row").count()==0
   page.wait_for_function("()=>document.querySelector('#ffx-kpis [data-ffx-metric=orders_today] .ffx-kpi-value')?.textContent==='7'")
   assert "2222" in page.locator("#ffA08Activity").inner_text()
   assert "1111" not in page.locator("#ffA08Activity").inner_text()
   page.evaluate("()=>window.ffDashboardStudio.open()")
   studio=page.locator("#ffStudio")
   studio.locator("#ffCardEditor > summary").click()
   studio.locator("[data-card-add]").click()
   rows=studio.locator(".ff-card-edit-row")
   assert rows.count()==5
   rows.first.locator(".ff-a08-card-access summary").click()
   rows.first.locator(".ff-a08-card-access input[type=checkbox]").last.uncheck()
   rows.first.locator(".ff-a08-card-access select").first.select_option("view_reports")
   rows.first.locator(".ff-a08-card-access select").last.select_option("clock")
   assert rows.first.locator(".ff-a08-card-access").evaluate("n=>n.open")
   studio.locator("#ffA08Panels summary").click()
   studio.get_by_role("combobox",name="الأنشطة الحديثة",exact=True).select_option("false")
   studio.get_by_role("combobox",name="حالة الفروع",exact=True).select_option("true")
   studio.locator("[data-a08-custom-actions]").check()
   studio.locator("[data-a08-actions] select").select_option("reservations")
   assert studio.locator("[data-a08-preview]").inner_text().find("الحجوزات")>=0

   # STEP04: real navigation library, structured copies, history and drag.
   library=page.evaluate("()=>window.ffStep04ActionLibrary.map(x=>x.key)")
   assert len(library)==40 and len(set(library))==40
   assert {"catalog","archive","ratings","settlements","team","branch_policy","studio","refresh"}<=set(library)
   editor=studio.locator("#ffA08Panels")
   editor.get_by_role("combobox",name="إجراء سريع من المكتبة").select_option("archive")
   action_rows=editor.locator(".ff-a08-action-row")
   count=action_rows.count()
   action_rows.last.get_by_role("button",name="نسخ",exact=True).click()
   assert action_rows.count()==count+1
   action_rows.last.locator("input").fill("أرشيف مخصص")
   action_rows.last.locator("input").press("Tab")
   action_rows.last.get_by_role("combobox",name=f"أيقونة الاختصار {count+1}").select_option("star")
   action_rows.last.get_by_role("combobox",name=f"مقاس الاختصار {count+1}").select_option("full")
   action_rows.last.get_by_role("combobox",name=f"لون الاختصار {count+1}").select_option("red")
   editor.locator("[data-a08-undo]").click()
   assert action_rows.last.locator("select").last.input_value()=="default"
   editor.locator("[data-a08-redo]").click()
   assert action_rows.last.locator("select").last.input_value()=="red"
   action_rows.last.get_by_role("button",name="تقديم",exact=True).click()
   assert action_rows.nth(count-1).locator("input").input_value()=="أرشيف مخصص"
   page.evaluate("""()=>{const rows=document.querySelectorAll('#ffA08Panels .ff-a08-action-row');const dt=new DataTransfer();dt.setData('application/x-ff-step04-index',String(rows.length-2));rows[0].dispatchEvent(new DragEvent('drop',{bubbles:true,dataTransfer:dt}))}""")
   assert action_rows.first.locator("input").input_value()=="أرشيف مخصص"
   action_rows.last.get_by_role("button",name="حذف",exact=True).click()
   editor.locator("[data-a08-undo]").click()
   assert action_rows.count()==count+1
   assert editor.locator("[data-a08-action-preview]").get_by_text("أرشيف مخصص",exact=True).count()==1
   # Restore old test's expected legacy array before its existing submission.
   editor.locator("[data-a08-custom-actions]").uncheck()
   editor.locator("[data-a08-custom-actions]").check()
   editor.get_by_role("combobox",name="إجراء سريع من المكتبة").select_option("reservations")
   studio.locator("input[name=draftName]").fill("مسودة بطاقات اختبار")
   studio.locator("button[type=submit]").click()
   page.wait_for_function("()=>window.__a06Calls.some(c=>c.name==='ff_a07_named_design')")
   payload=page.evaluate("()=>window.__a06Calls.filter(c=>c.name==='ff_a07_named_design').at(-1).args")
   assert len(payload["p_cards"])==5 and payload["p_cards"][0]["permission"]=="view_reports"
   assert "burger_kitchen" not in payload["p_cards"][0]["roles"] and payload["p_cards"][0]["icon"]=="clock"
   assert payload["p_style"]["dashboardPanels"]=={"activity":False,"branches":True}
   assert payload["p_style"]["quickActions"][-1]=="reservations"
   studio.locator("button[type=submit]").wait_for(state="visible")
   page.wait_for_function("()=>!document.querySelector('#ffStudio button[type=submit]').disabled")
   studio.locator("[data-a08-inherit-cards]").check()
   studio.locator("button[type=submit]").click()
   page.wait_for_function("()=>window.__a06Calls.filter(c=>c.name==='ff_a07_named_design').length===2")
   assert page.evaluate("()=>window.__a06Calls.filter(c=>c.name==='ff_a07_named_design').at(-1).args.p_cards") is None
   page.wait_for_function("()=>!document.querySelector('#ffStudio button[type=submit]').disabled")
   studio.locator("[data-card-default]").click()
   assert rows.count()==4
   assert not studio.locator("[data-a08-inherit-cards]").is_checked()
   for _ in range(4):rows.first.get_by_role("button",name="حذف",exact=True).click()
   assert rows.count()==0
   studio.locator("[data-card-undo]").click();assert rows.count()==1
   studio.locator("[data-card-redo]").click();assert rows.count()==0
   studio.locator("button[type=submit]").click()
   page.wait_for_function("()=>window.__a06Calls.filter(c=>c.name==='ff_a07_named_design').length===3")
   assert page.evaluate("()=>window.__a06Calls.filter(c=>c.name==='ff_a07_named_design').at(-1).args.p_cards")==[]
   assert not page.evaluate("()=>window.__a06Calls.some(c=>['ff_ui_publish','ff_ui_control_trial'].includes(c.name))")
   page.screenshot(path=out/"manager-card-editor.png",animations="disabled")
   studio.locator("[data-close]").click()
  page.evaluate("()=>window.dispatchEvent(new Event('ff-luxe-session-reset'))")
  assert page.locator("#ffA08Detail").is_hidden()
  assert page.locator("#ffA08Detail .ff-a08-data-row").count()==0
  print("PASS A08",role,len(widths),"responsive permission-scoped layouts",flush=True)
  ctx.close()
 browser.close()
server.shutdown()
(out/"role-width-matrix.json").write_text(json.dumps(results,ensure_ascii=False,indent=2))
assert len(results)==35
print("PASS A08 35 role/width layouts plus detail pagination, stale-response rejection, permission revocation, draft, inheritance, explicit empty and undo/redo",flush=True)
