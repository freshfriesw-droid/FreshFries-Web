"""A09 browser acceptance: real rendered controls, mocked RPC, no operational writes."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
out=root/"a09-evidence";out.mkdir(exist_ok=True)
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
 window.__a06Calls=[];window.__a09Grant=null;window.__a09DesignRows=[];window.__a09Content=[];
 client={channel:()=>{const ch={on:()=>ch,subscribe:()=>ch};return ch},removeChannel:async()=>true};
 rpc=async(name,args={})=>{
  window.__a06Calls.push({name,args});
  if(name==='ff_content_effective')return window.__a09Content||[];
  if(name==='ff82_my_grant')return window.__a09Grant?[window.__a09Grant]:[];
  if(name==='ff82_manager_accounts')return [{user_id:'qa-cashier',display_name:'موظف اختباري',role:'cashier',branch_id:'b1',branch_name:'القاهرة'}];
  if(name==='ff82_manager_grants')return window.__a09Grant?[window.__a09Grant]:[];
  if(name==='ff82_manager_audit')return [];
  if(name==='ff_a09_set_grant'){
   window.__a09Grant={id:901,recipient:args.p_recipient,role_scope:'cashier',branch_id:args.p_branch,screen:args.p_screen,capabilities:args.p_capabilities,edit_kinds:args.p_kinds,starts_at:args.p_start,ends_at:args.p_end};return 901;
  }
  if(name==='ff82_delegate_catalog')return [];
  if(name==='ff_a09_design_context')return {pack:'D01',style_config:{accent:'red'},screen:'cashier'};
  if(name==='ff_a09_design_history')return window.__a09DesignRows||[];
  if(name==='ff_a09_design_draft'){
   const id=902+window.__a09DesignRows.length;window.__a09DesignRows.unshift({id,actor_id:user.id,role_scope:role,branch_id:'b1',screen_scope:'cashier',device:args.p_device,pack:'D01',draft_name:args.p_name,style_config:args.p_patch,published_at:null});return {ok:true,revision:id};
  }
  if(name==='ff_a09_design_review')return {ok:true};
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
with sync_playwright() as pw:
 browser=pw.chromium.launch(channel="chrome")
 ctx=browser.new_context(viewport={"width":390,"height":850},service_workers="block",reduced_motion="reduce")
 ctx.route("**/*",lambda r:r.continue_() if r.request.url.startswith(origin) else r.abort())
 page=ctx.new_page();page.goto(origin,wait_until="load");page.evaluate(fixture,"manager")
 page.on("dialog",lambda d:d.accept())
 page.evaluate("""async ()=>{await ffContentDelegation.sync(true);window.__a09OriginalCancel=document.createElement('button');window.__a09OriginalCancel.dataset.cancelOrder='qa-order';window.__a09OriginalCancel.textContent='إلغاء الطلب';document.getElementById('staffOrders').append(window.__a09OriginalCancel);
 data.orders=[{id:'qa-order',number:123,branch_id:'b1',customer_name:'عميل مأذون',driver_name:'موصل مأذون',delivery_fee:500}];
 window.__a09Content=[{content_key:'nav.orders',body:'متابعة اختبارية',revision:1},{content_key:'orders.cancel',body:'إلغاء تجريبي',revision:2},{content_key:'orders.guidance',body:'**راجع**\\n- [فتح النظام](https://delivery.freshfriesz.com/)',revision:3},{content_key:'notices.order_summary',body:'طلب {order_number} {customer_name} {driver_name} {delivery_fee}',revision:4},{content_key:'notices.delayed',body:'طلب {order_number} {customer_name}',revision:5},{content_key:'reports.pdf_title',body:'عنوان تقرير اختباري',revision:6},{content_key:'reports.pdf_note',body:'<script>unsafe</script>',revision:7}];await ffContentStudio.sync(true)}""")
 assert page.locator("#staffOrders [data-cancel-order=qa-order]").inner_text().strip()=="إلغاء تجريبي"
 assert page.evaluate("()=>document.querySelector('[data-cancel-order=qa-order]')===window.__a09OriginalCancel")
 assert page.locator('#ffx-mobile-nav button[data-key=orders]').get_attribute('aria-label')=="متابعة اختبارية"
 assert page.locator('[data-ff-guidance="orders.guidance"] a').get_attribute("href")=="https://delivery.freshfriesz.com/"
 assert page.locator('[data-ff-guidance="orders.guidance"] strong').text_content()=="راجع"
 assert page.evaluate("()=>ffContentStudio.notice('notices.order_summary','fallback',123,'b1')")=="طلب 123 عميل مأذون موصل مأذون 500"
 assert page.evaluate("()=>ffContentStudio.notice('notices.order_summary','fallback',123,'b2')")=="طلب 123 — — —"
 assert page.evaluate("()=>ffContentStudio.notice('notices.delayed','fallback',123,'b1')")=="طلب 123 —"
 assert page.evaluate("async ()=>await ffContentStudio.reportText('b1')")=={"reports.pdf_title":"عنوان تقرير اختباري"}
 page.evaluate("""async ()=>{window.__a09Content=[];await ffContentStudio.sync(true)}""")
 assert page.locator("#staffOrders [data-cancel-order=qa-order]").inner_text().strip()=="إلغاء الطلب"
 assert page.locator('[data-ff-guidance="orders.guidance"] a').count()==0
 page.locator("#ff82Open").click()
 dlg=page.locator("#ff82Delegation")
 dlg.locator("[data-d-account] option").wait_for(state="attached")
 dlg.locator("[data-d-screen]").select_option("cashier")
 dlg.locator("[data-d-kinds] input[value=text]").uncheck()
 for k in ("colors","buttons","layout"):dlg.locator(f"[data-d-kinds] input[value={k}]").check()
 for k in ("edit","preview","review"):dlg.locator(f"[data-d-caps] input[value={k}]").check()
 dlg.locator("[data-d-grant]").click()
 page.wait_for_function("()=>window.__a09Grant?.id===901")
 assert page.evaluate("()=>window.__a09Grant.edit_kinds")==["colors","buttons","layout"]
 page.screenshot(path=out/"manager-grant.png",animations="disabled")
 dlg.locator("[data-d-close]").click()
 page.evaluate("""async ()=>{user={id:'qa-cashier',email:'qa@example.invalid'};data.role='cashier';data.branches=[{id:'b1',name:'القاهرة'}];data.orders=[];await ffContentDelegation.sync(true)}""")
 page.locator("#ff82Open").click()
 dlg.locator("[data-d-style-fields] select[data-token=accent]").wait_for()
 assert dlg.locator("[data-d-manager]").is_hidden()
 assert dlg.locator("[data-d-text-section]").is_hidden()
 assert dlg.locator("[data-d-design-preview]").is_visible()
 dlg.locator("[data-d-style-fields] select[data-token=accent]").select_option("navy")
 dlg.locator("[data-d-style-fields] select[data-token=button]").select_option("pill")
 dlg.locator("[data-d-style-fields] select[data-token=layout]").select_option("single")
 dlg.locator("[data-d-element-fields] select").first.select_option("outline")
 dlg.locator("[data-d-design-name]").fill("مسودة اختبار")
 assert dlg.locator("[data-d-design-after] [data-ff-a07-pack]").count()>0
 dlg.locator("[data-d-design-save]").click()
 page.wait_for_function("()=>window.__a09DesignRows.length===1")
 page.wait_for_function("()=>document.querySelector('[data-d-status]').textContent.includes('#902')")
 p=page.evaluate("()=>window.__a06Calls.filter(x=>x.name==='ff_a09_design_draft').at(-1).args")
 assert p["p_patch"]["accent"]=="navy" and p["p_patch"]["button"]=="pill" and p["p_patch"]["layout"]=="single"
 assert p["p_patch"]["elements"]["cashier_stage"][0]["shape"]=="outline"
 assert p["p_base"] is None
 dlg.locator("[data-d-design-note]").fill("مراجعة اختبارية")
 dlg.locator("[data-d-design-send]").click()
 page.wait_for_function("()=>document.querySelector('[data-d-status]').textContent.includes('تم رفع مراجعة التصميم')")
 assert not page.evaluate("()=>window.__a06Calls.some(x=>['ff_ui_publish','ff_ui_rollback','ff_ui_control_trial'].includes(x.name))")
 for width in (320,360,390,430,768,1024,1440):
  page.set_viewport_size({"width":width,"height":850})
  assert dlg.evaluate("e=>e.scrollWidth<=e.clientWidth+2"),width
  if width in (390,1440):page.screenshot(path=out/f"delegated-editor-{width}.png",animations="disabled")
 page.evaluate("""async ()=>{window.__a09Grant=null;await ffContentDelegation.sync(true)}""")
 assert dlg.is_hidden() and page.locator("#ff82Open").is_hidden()
 assert dlg.locator("[data-d-design-history] option").count()==0
 print("PASS A09: labels, control identity, safe links, variables, report content, manager grant, delegated draft/review, 7 widths and revocation",flush=True)
 ctx.close();browser.close()
server.shutdown()
