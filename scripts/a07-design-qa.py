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
  if(name==='ff_content_catalog_list')return [{key:'driver.attend',screen:'driver',label:'الحضور',original:'الحضور'}];
  if(name==='ff_a07_named_design')return 4321;
  if(name==='ff_a07_preview_scope')return {applies:args.p_target_device==='mobile',before:{pack:'D01',style_config:{}},after:{pack:args.p_target_device==='mobile'?'D08':'D01',style_config:{}},after_sources:args.p_target_device==='mobile'?{font:-1}:{}};
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
  if role=="assembly":
   page.evaluate("""async()=>{window.__a07Rows={assembly:{id:510,pack:'D01',bar:'labels',style_config:{logoPosition:'cover',logoAsset:'mark',logoWidth:'56'}}};await ffDashboardStudio.sync(true)}""")
   logo=page.locator("#ffV12AssemblyWorkspace > .ff-a07-logo-cover img")
   assert logo.count()==1 and logo.get_attribute("src").endswith("ff-icon-192.png")
   page.evaluate("""async()=>{window.ffA07Design.refresh();window.__a07Rows.assembly.style_config={};await ffDashboardStudio.sync(true)}""")
   assert page.locator("#ffV12AssemblyWorkspace > .ff-a07-logo-cover").count()==0
   assert page.locator("#ffV12AssemblyWorkspace .ff-assembly-brand>img").count()==1
  if role=="driver":
   page.set_viewport_size({"width":390,"height":850})
   page.locator('#ffx-mobile-nav button[data-key="attendance"]').click()
   assert page.locator("#clockInBtn").is_visible(),"pre-existing attendance workspace must be opened"
   page.evaluate("""async ()=>{window.__a07Button=document.getElementById('clockInBtn');window.__a07Rows={driver:{id:500,pack:'D09',bar:'labels',style_config:{elements:{driver_actions:[{key:'clockInBtn',shape:'pill',size:'large',weight:'strong',font:'tahoma',border:'strong',align:'center',textScale:'large'},{key:'clockOutBtn',shape:'outline',size:'normal'},{key:'ff51BreakBtn',shape:'pack',size:'normal'}]}}}};await ffDashboardStudio.sync(true)}""")
   assert page.locator("#clockInBtn").get_attribute("data-ff-a07-shape")=="pill"
   assert page.locator("#clockInBtn").evaluate("n=>n===window.__a07Button && getComputedStyle(n).order==='1'"),page.evaluate("()=>['clockInBtn','clockOutBtn','ff51BreakBtn'].map(id=>{const n=document.getElementById(id);return {id,order:getComputedStyle(n).order,attr:n.dataset.ffA07Order,parent:n.parentElement.className,display:getComputedStyle(n.parentElement).display,same:n===window.__a07Button}})")
   assert page.locator("#clockInBtn").get_attribute("data-ff-a07-el-weight")=="strong"
   assert page.locator("#clockInBtn").evaluate("n=>getComputedStyle(n).fontWeight==='700' && getComputedStyle(n).fontFamily.includes('Tahoma')")
   assert page.locator("#clockInBtn").is_visible()
   assert page.locator("#clockOutBtn").is_visible()
   assert page.locator("#clockInBtn").get_attribute("data-ff-a07-el-align")=="center"
   assert page.locator("#clockInBtn").evaluate("n=>getComputedStyle(n).textAlign==='center' && Math.abs(parseFloat(getComputedStyle(n).fontSize)-1.125*parseFloat(getComputedStyle(n.parentElement).fontSize))<0.1")
   assert page.locator("#clockOutBtn").get_attribute("data-ff-a07-el-align") is None
   assert page.locator("#clockInBtn").evaluate("n=>n===window.__a07Button")
   page.evaluate("""async()=>{window.__a07Rows.driver.style_config.elements.driver_actions[0].font='noto';await ffDashboardStudio.sync(true)}""")
   assert page.locator("#clockInBtn").evaluate("n=>getComputedStyle(n).fontFamily.includes('Noto Sans Arabic')")
   for w in (320,1440):
    page.set_viewport_size({"width":w,"height":850})
    assert page.locator("#clockInBtn").is_visible()
    assert page.locator("#clockOutBtn").is_visible()
    assert page.evaluate("()=>document.documentElement.scrollWidth<=innerWidth+1")
   page.set_viewport_size({"width":390,"height":850})
   page.evaluate("""async()=>{window.__a07Rows.driver.style_config.logoAsset='mark';window.__a07Rows.driver.style_config.logoWidth='48';window.__a07Rows.driver.style_config.logoPosition='cover';await ffDashboardStudio.sync(true)}""")
   logo=page.locator("#driverView > .ff-a07-logo-cover img")
   assert logo.count()==1 and logo.get_attribute("src").endswith("ff-icon-192.png")
   assert logo.evaluate("n=>getComputedStyle(n).width")=="48px"
   page.evaluate("""async()=>{delete window.__a07Rows.driver.style_config.logoAsset;delete window.__a07Rows.driver.style_config.logoWidth;delete window.__a07Rows.driver.style_config.logoPosition;await ffDashboardStudio.sync(true)}""")
   assert page.locator("#driverView > .ff-a07-logo-cover").count()==0
   assert page.locator("#driverView .ff-a07-logo-inline").get_attribute("src").endswith("ff-official-logo.png")
   assert page.locator("#cashierView").get_attribute("data-ff-a07-pack") is None
   page.evaluate("""async()=>{window.__a07Rows.driver.style_config={logoPosition:'menu',logoAsset:'mark',logoWidth:'30%',dialogRadius:'square',dialogPadding:'wide',ratingScale:'large'};await ffDashboardStudio.sync(true)}""")
   assert page.locator('#ffx-sidebar .ff-step03-menu-brand img').get_attribute('src').endswith('ff-icon-192.png')
   assert page.locator('#ffx-sidebar .ff-step03-menu-brand').get_attribute('data-a07-logo-width')=='30%'
   page.evaluate("""()=>{const d=document.createElement('dialog');d.className='ff-luxe-rate-dialog';d.id='qa-rate';d.innerHTML='<div class=ff-luxe-stars><button>★</button></div>';document.body.append(d);ffA07Design.refresh()}""")
   assert page.locator('#qa-rate').get_attribute('data-a07-dialog-radius')=='square'
   assert page.locator('#qa-rate .ff-luxe-stars button').evaluate('n=>getComputedStyle(n).fontSize')=='40px'
   page.evaluate("""async()=>{window.__a07Rows.driver.style_config={};await ffDashboardStudio.sync(true)}""")
   assert page.locator('#ffx-sidebar .ff-step03-menu-brand').count()==0
   assert page.locator('#qa-rate').get_attribute('data-a07-rating-scale') is None
   assert page.locator("#clockInBtn").get_attribute("data-ff-a07-el-align") is None
   assert page.locator("#clockInBtn").get_attribute("data-ff-a07-el-text-scale") is None
   assert page.locator("#clockInBtn").get_attribute("data-ff-a07-el-font") is None
  if role in ("manager","customer_service"):
   page.set_viewport_size({"width":390,"height":850})
   page.evaluate("""async ()=>{document.getElementById('newItems').value='1 تشكن بدون شطة';document.getElementById('ffbQuickInput').value='نص محفوظ';window.__a07Rows={orders:{id:501,pack:'D10',bar:'labels',style_config:{density:'compact'}}};await ffDashboardStudio.sync(true)}""")
   assert page.locator("#newItems").input_value()=="1 تشكن بدون شطة"
   assert page.locator("#ffbQuickInput").input_value()=="نص محفوظ"
   assert page.locator("#cashierView").get_attribute("data-ff-a07-pack") is None
  if role=="manager":
   page.evaluate("""async(spec)=>{window.__step03Coverage=spec;window.__step03Original={};const rows={};for(const [g,c] of Object.entries(spec)){rows[c.screen]??={id:900,pack:'D01',style_config:{elements:{}}};rows[c.screen].style_config.elements[g]=c.keys.map(key=>({key,shape:'pack',size:'normal',align:'center'}));for(const key of c.keys){const n=document.getElementById(key);if(n)window.__step03Original[key]={node:n,disabled:n.disabled,value:n.value,onclick:n.onclick,hidden:n.hidden};}}window.__a07Rows=rows;await ffDashboardStudio.sync(true)}""",json.loads('''{"system_qa_controls":{"screen":"system","keys":["ff47Reload","ff47Close","ff47Version","ff47Title","ff47Create","ff47Runs","ff47Export","ff47Finish","ff47Reopen","ff47Category","ff47Filter"],"styleOnly":true},"system_readiness_controls":{"screen":"system","keys":["ff46Run","ff46Export","ff46Close"],"styleOnly":true},"system_access_controls":{"screen":"system","keys":["ff45Run","ff45Export","ff45Close"],"styleOnly":true},"system_integrity_controls":{"screen":"system","keys":["ff44Export","ff44Close","ff44From","ff44To","ff44Run"],"styleOnly":true},"system_security_controls":{"screen":"system","keys":["ff43Run","ff43Export","ff43Close"],"styleOnly":true},"case_contact_controls":{"screen":"cases","keys":["ff41Order","ff41CustomerName","ff41CustomerPhone","ff41Channel","ff41Create"],"styleOnly":true},"message_delivery_controls":{"screen":"messages","keys":["ff39Send","ff39SentRefresh"],"styleOnly":true},"dashboard_alert_controls":{"screen":"dashboard","keys":["ff40AlertRefresh","ff40AlertsClose","ff40AlertBranch"],"styleOnly":true},"staff_filter_controls":{"screen":"staff","keys":["ffEditMyAccount","staffAdminRefresh","ffA05StaffSearch","ffA05StaffRole","ffA05StaffActive","ffA05StaffSort","permissionEmployee","permissionLoad"],"styleOnly":true},"catalog_edit_controls":{"screen":"catalog","keys":["ff51CatalogRefresh","ff51CatalogClose","ffCatalogCardTarget","ffCatalogCardSort","ffCatalogCardStyle","ffCatalogCardSave","ffAliasTarget","ffAliasNames","ffAliasSave","ffAliasDefault"],"styleOnly":true},"customer_close_control":{"screen":"customers","keys":["ff51CustomersClose"],"styleOnly":true},"archive_page_controls":{"screen":"archive","keys":["ff51ArchivePrev","ff51ArchiveNext"],"styleOnly":true},"order_change_controls":{"screen":"orders","keys":["ff50Refresh","ff50Close","ff50RequestItems","ff50RequestReason","ff50RequestSave","ff50RequestCancel"],"styleOnly":true},"order_transfer_controls":{"screen":"orders","keys":["ff49TransferRefresh","ff49TransferClose"],"styleOnly":true},"reservation_save_control":{"screen":"reservations","keys":["ff49ReserveSave"],"styleOnly":true},"assembly_sound_control":{"screen":"assembly","keys":["ff66AssemblySoundSettings"],"styleOnly":true},"staff_edit_controls":{"screen":"staff","keys":["ffEditClose","ffEditSave"],"styleOnly":true}}'''))
   coverage=page.evaluate("""()=>Object.entries(window.__step03Coverage).flatMap(([g,c])=>c.keys.flatMap(key=>{const n=document.getElementById(key),o=window.__step03Original[key];return !n||!o||n!==o.node||n.dataset.ffA07ElAlign!=='center'||n.dataset.ffA07Order||n.disabled!==o.disabled||n.value!==o.value||n.onclick!==o.onclick||n.hidden!==o.hidden?[g+':'+key]:[]}))""")
   assert not coverage,coverage
   page.evaluate("""async()=>{window.__a07Rows={};await ffDashboardStudio.sync(true)}""")
   assert page.evaluate("""()=>Object.values(window.__step03Original).every(o=>!o.node.dataset.ffA07ElAlign)""")
   page.evaluate("""async({spec,dyn})=>{window.__step03Extra=spec;window.__step03Dynamic=dyn;window.__step03Nodes={};const rows={};for(const [g,c] of Object.entries(spec)){rows[c.screen]??={id:901,pack:'D01',style_config:{elements:{}}};rows[c.screen].style_config.elements[g]=c.keys.map(key=>({key,shape:'pack',size:'normal',align:'center'}));for(const key of c.keys){let ns=dyn[key]?[...document.querySelectorAll(dyn[key])]:[document.getElementById(key)].filter(Boolean);if(ns.length)window.__step03Nodes[key]=ns.map(node=>({node,hidden:node.hidden,disabled:node.disabled,value:node.value,onclick:node.onclick}));}}const holder=document.createElement('div');holder.id='qa-repeat-driver';document.getElementById('driverOffers').append(holder);for(const id of ['test-a','test-b']){const n=document.createElement('button');n.dataset.accept=id;n.disabled=id==='test-b';holder.append(n)}window.__step03Nodes.offer_accept=[...holder.children].map(node=>({node,hidden:node.hidden,disabled:node.disabled,value:node.value,onclick:node.onclick}));window.__a07Rows=rows;await ffDashboardStudio.sync(true);ffA07Design.refresh()}""",json.loads(r'''{"spec":{"order_search_controls":{"screen":"orders","keys":["orderSearch","orderBranchFilter","orderStatusFilter","auditRefreshBtn"],"styleOnly":true},"order_manual_controls":{"screen":"orders","keys":["ff49ManualClose","ff49ManualDriver","ff49ManualReason","ff49ManualConfirm"],"styleOnly":true},"order_late_controls":{"screen":"orders","keys":["ff52LateClose","ff52LateItems","ff75LatePreview","ff52LateSave"],"styleOnly":true},"order_review_controls":{"screen":"orders","keys":["ffbCloseReview","ffbConfirmSave","ffbCancelReview"],"styleOnly":true},"driver_route_controls":{"screen":"driver","keys":["ff52RoutesClose","ff52RouteBranch","ff52RouteDriver","ff52RouteAreas","ff52RouteStart","ff52RouteEnd","ff52RouteActive","ff52RouteSave"],"styleOnly":true},"staff_link_controls":{"screen":"staff","keys":["addEmail","addName","addRole","addBranch","linkUserBtn"],"styleOnly":true},"dashboard_lifecycle_controls":{"screen":"dashboard","keys":["ff60-refresh","ff60-close","ff60-search","ff60-branch","ff60-state","ff60-open-old","ff60-fast","ff60-slow","ff60-save-policy"],"styleOnly":true},"dashboard_watch_controls":{"screen":"dashboard","keys":["ff4-refresh","ff4-export","ff4-close","ff4-search","ff4-branch","ff4-state","ff4-minutes"],"styleOnly":true},"dashboard_overdue_controls":{"screen":"dashboard","keys":["ff5-refresh","ff5-export","ff5-close","ff5-search","ff5-branch","ff5-age","ff5-sort"],"styleOnly":true},"driver_offer_controls":{"screen":"driver","keys":["offer_accept","offer_reject","offer_check_reject"],"styleOnly":true},"driver_progress_controls":{"screen":"driver","keys":["driver_on_way","driver_arrived","driver_delivered"],"styleOnly":true},"order_dynamic_actions":{"screen":"orders","keys":["order_customer_edit","order_auto","order_manual","order_change","order_reassign","order_transfer","order_cancel"],"styleOnly":true},"order_addition_controls":{"screen":"orders","keys":["additionItemsInput","addition_preview","addition_save","addition_close"],"styleOnly":true},"case_detail_controls":{"screen":"cases","keys":["ff41NextStatus","ff41Resolution","ff41CommentBody","case_transition","case_comment"],"styleOnly":true},"staff_edit_fields":{"screen":"staff","keys":["employee_name","employee_username","employee_email","employee_phone","employee_qualification","employee_address","employee_age","employee_marital","employee_experience","employee_password","employee_message"],"styleOnly":true}},"dyn":{"offer_accept":"button[data-accept]","offer_reject":"button[data-reject]","offer_check_reject":"button[data-check-reject]","driver_on_way":"button[data-progress][data-phase=\"on_way\"]","driver_arrived":"button[data-progress][data-phase=\"arrived\"]","driver_delivered":"button[data-progress][data-phase=\"delivered\"]","order_customer_edit":"button[data-ff-customer-edit]","order_auto":"button[data-auto]","order_manual":"button[data-manual]","order_change":"button[data-ff50-change]","order_reassign":"button[data-ff52-reassign]","order_transfer":"button[data-ff49-transfer]","order_cancel":"button[data-cancel-order]","addition_preview":"button[data-ff75-preview-addition]","addition_save":"button[data-save-addition]","addition_close":"button[data-close-addition]","case_transition":"button[data-ff41-transition]","case_comment":"button[data-ff41-comment]","employee_name":"#ffEditForm [name=\"name\"]","employee_username":"#ffEditForm [name=\"username\"]","employee_email":"#ffEditForm [name=\"email\"]","employee_phone":"#ffEditForm [name=\"phone\"]","employee_qualification":"#ffEditForm [name=\"qualification\"]","employee_address":"#ffEditForm [name=\"address\"]","employee_age":"#ffEditForm [name=\"age_years\"]","employee_marital":"#ffEditForm [name=\"marital_status\"]","employee_experience":"#ffEditForm [name=\"experience_years\"]","employee_password":"#ffEditForm [name=\"password\"]","employee_message":"#ffEditForm [name=\"applicant_message\"]"}}'''))
   extra=page.evaluate("""()=>{const bad=[];for(const [key,ns] of Object.entries(window.__step03Nodes))for(const o of ns){const n=o.node;if(!n.isConnected||n.dataset.ffA07ElAlign!=='center'||n.dataset.ffA07Order||n.hidden!==o.hidden||n.disabled!==o.disabled||n.value!==o.value||n.onclick!==o.onclick)bad.push(key);}return {bad,count:Object.keys(window.__step03Nodes).length}}""")
   assert not extra["bad"],extra
   assert extra["count"]>=40,extra
   assert page.locator("#qa-repeat-driver button[data-accept=test-b]").is_disabled()
   page.evaluate("""()=>{const h=document.getElementById('qa-repeat-driver');const n=document.createElement('button');n.dataset.accept='test-c';h.replaceChildren(n);ffA07Design.refresh()}""")
   assert page.locator("#qa-repeat-driver button[data-accept=test-c]").get_attribute("data-ff-a07-el-align")=="center"
   page.evaluate("""async()=>{window.__a07Rows={};await ffDashboardStudio.sync(true);ffA07Design.refresh()}""")
   assert page.locator("#qa-repeat-driver button[data-accept=test-c]").get_attribute("data-ff-a07-el-align") is None
   page.locator("#qa-repeat-driver").evaluate("n=>n.remove()")
   page.evaluate("""async(spec)=>{window.__step03Shared=spec;window.__step03SharedNodes={};const rows={};for(const [g,c] of Object.entries(spec)){rows[c.screen]??={id:902,pack:'D01',style_config:{elements:{}}};rows[c.screen].style_config.elements[g]=c.keys.map(key=>({key,shape:'pack',size:'normal',align:'center',spaceBlock:'wide',outerGap:'normal'}));for(const key of c.keys){const n=document.getElementById(key);if(n)window.__step03SharedNodes[key]={node:n,value:n.value,disabled:n.disabled,hidden:n.hidden}}}window.__a07Rows=rows;await ffDashboardStudio.sync(true);ffA07Design.refresh()}""",json.loads(r'''{"dashboard_filter_controls":{"screen":"dashboard","keys":["ffx-branch","ffx-kpi-reload","ffx-open-alerts"],"styleOnly":true},"dashboard_shell_controls":{"screen":"dashboard","keys":["ffx-menu","ffx-refresh","ffx-bell","ffx-theme-toggle","ffx-options","ffx-drawer-close"],"styleOnly":true},"dashboard_quick_controls":{"screen":"dashboard","keys":["ff2-close","ff2-search","ff3-close"],"styleOnly":true},"preferences_appearance":{"screen":"system","keys":["ffx-pref-close","ffx-density","ffx-auto","ffx-motion","ffx-fast","ffx-reset"],"styleOnly":true},"preferences_alerts":{"screen":"system","keys":["ffx-audio","ffx-visual","ffx-delay","ffx-sound","ffx-delay-sound","ffx-volume","ffx-repeat","ffx-play-sound","ffx-play-delay","ffx-push-permission","ff-luxe-audio-unlock"],"styleOnly":true},"preferences_tones":{"screen":"system","keys":["ff66-tone-name","ff66-tone-file","ff66-tone-add","ff66-tone-refresh"],"styleOnly":true},"reports_legacy_controls":{"screen":"reports","keys":["ff40ExportCSV","ff40ReportsClose","ff40From","ff40To","ff40ReportBranch","ff40RunReport"],"styleOnly":true},"message_ack_control":{"screen":"messages","keys":["ff39RequireAck"],"styleOnly":true},"dashboard_watch_options":{"screen":"dashboard","keys":["ff4-overdue","ff4-hidephones"],"styleOnly":true},"staff_share_control":{"screen":"staff","keys":["ffEditShare"],"styleOnly":true}}'''))
   shared=page.evaluate("""()=>({bad:Object.entries(window.__step03SharedNodes).filter(([k,o])=>!o.node.isConnected||o.node.dataset.ffA07ElAlign!=='center'||o.node.dataset.ffA07ElSpaceBlock!=='wide'||o.node.value!==o.value||o.node.hidden!==o.hidden||o.node.disabled!==o.disabled).map(x=>x[0]),count:Object.keys(window.__step03SharedNodes).length})""")
   assert not shared["bad"],shared
   assert shared["count"]>=25,shared
   assert page.locator("#ffx-topbar").get_attribute("data-ff-a07-pack") is None
   assert page.locator("#ffx-topbar").get_attribute("data-ff-a07-element-scope")=="1"
   page.evaluate("""async()=>{window.__a07Rows={};await ffDashboardStudio.sync(true);ffA07Design.refresh()}""")
   assert page.locator("#ffx-topbar").get_attribute("data-ff-a07-element-scope") is None
   assert page.evaluate("""()=>Object.values(window.__step03SharedNodes).every(o=>!o.node.dataset.ffA07ElAlign&&!o.node.dataset.ffA07ElSpaceBlock)""")
   page.evaluate("""async({spec,dyn,roots})=>{window.__step03DynamicNodes=[];window.__step03Inserted=[];const rows={};for(const [g,c] of Object.entries(spec)){rows[c.screen]??={id:903,pack:'D01',style_config:{elements:{}}};rows[c.screen].style_config.elements[g]=c.keys.map(key=>({key,shape:'pack',size:'normal',align:'center'}));const root=document.querySelector(roots[g]);if(!root)continue;for(const key of c.keys){const selector=dyn[key];let ns=selector?[...root.querySelectorAll(selector)]:[document.getElementById(key)].filter(n=>n&&root.contains(n));if(!ns.length&&selector){const n=document.createElement(selector.startsWith('button')?'button':'span');for(const m of selector.matchAll(/\\[(data-[\\w-]+)(?:="([^"]*)")?\\]/g))n.setAttribute(m[1],m[2]||'qa-fixture');if(n.tagName==='BUTTON'){n.type='button';n.disabled=true}root.append(n);window.__step03Inserted.push(n);ns=[n]}for(const n of ns)window.__step03DynamicNodes.push({key,node:n,disabled:n.disabled,hidden:n.hidden,value:n.value,onclick:n.onclick});}}window.__a07Rows=rows;await ffDashboardStudio.sync(true);ffA07Design.refresh()}""",json.loads(r'''{"spec":{"order_repeat_addition":{"screen":"orders","keys":["order_toggle_reject","order_open_addition","order_late_addition","order_cancel_addition","order_invoice_addition","order_invoice_late"],"styleOnly":true},"driver_addition_actions":{"screen":"driver","keys":["driver_accept_addition","driver_reject_addition","driver_pickup_addition"],"styleOnly":true},"cashier_repeat_actions":{"screen":"cashier","keys":["cashier_receive","cashier_invoice","cashier_burger","cashier_invoice_addition","cashier_invoice_late"],"styleOnly":true},"assembly_filters":{"screen":"assembly","keys":["assembly_filter_all","assembly_filter_printed","assembly_filter_preparing","assembly_filter_ready","assembly_filter_late","assembly_filter_priority"],"styleOnly":true},"burger_filters":{"screen":"burger_kitchen","keys":["burger_filter_all","burger_filter_sent","burger_filter_preparing","burger_filter_late"],"styleOnly":true},"burger_timer":{"screen":"burger_kitchen","keys":["burger_order_timer"],"styleOnly":true},"staff_repeat_actions":{"screen":"staff","keys":["staff_toggle","staff_assembly_save","staff_assembly_convert","staff_edit","staff_save_access","staff_permission_save"],"styleOnly":true},"message_repeat_actions":{"screen":"messages","keys":["message_ack","message_read"],"styleOnly":true},"case_repeat_actions":{"screen":"cases","keys":["case_open"],"styleOnly":true},"finance_repeat_actions":{"screen":"finance","keys":["settlement_select"],"styleOnly":true},"system_repeat_actions":{"screen":"system","keys":["qa_case_save"],"styleOnly":true},"reservation_repeat_actions":{"screen":"reservations","keys":["reservation_next","reservation_cancel"],"styleOnly":true},"order_transfer_repeat":{"screen":"orders","keys":["transfer_confirm"],"styleOnly":true},"order_changes_repeat":{"screen":"orders","keys":["change_approve","change_reject","change_service","change_pos"],"styleOnly":true},"catalog_repeat_actions":{"screen":"catalog","keys":["catalog_item_edit","catalog_item_toggle","catalog_offer_edit","catalog_offer_toggle"],"styleOnly":true},"customer_repeat_actions":{"screen":"customers","keys":["customer_open"],"styleOnly":true},"driver_route_repeat":{"screen":"driver","keys":["route_edit"],"styleOnly":true},"dashboard_lifecycle_repeat":{"screen":"dashboard","keys":["lifecycle_action"],"styleOnly":true},"dashboard_watch_repeat":{"screen":"dashboard","keys":["watch_tab","watch_find"],"styleOnly":true},"report_more_controls":{"screen":"reports","keys":["ff76Close","ff76Today","ff76Yesterday","ff76Seven","ff76Thirty","ff76CSV","ff76SavePreset","ff76UsePreset","ffA10GrantSave","ff76SaveApproval"],"styleOnly":true},"report_preview_controls":{"screen":"reports","keys":["ff76DlgDownload","ff76DlgShare","ff76DlgClose"],"styleOnly":true},"message_template_controls":{"screen":"messages","keys":["ffA11Priority","ffA11Route","ffA11Template","ffA11TemplateName","ffA11TemplateSave","ffA11TemplateDelete","ffA11Preview","ffA11GrantUser","ffA11GrantRole","ffA11GrantBranch","ffA11GrantSave","ffA11GrantRefresh","ffA11Audit"],"styleOnly":true},"order_customer_modal":{"screen":"orders","keys":["ffCustomerEditSave","ffCustomerEditCancel"],"styleOnly":true},"order_picker_modal":{"screen":"orders","keys":["ffUnifiedMenuReview","ffUnifiedMenuUndo","ffUnifiedMenuClose"],"styleOnly":true}},"dyn":{"order_toggle_reject":"button[data-toggle-reject]","order_open_addition":"button[data-open-addition]","order_late_addition":"button[data-ff52-late]","order_cancel_addition":"button[data-cancel-addition]","order_invoice_addition":"button[data-invoice-addition]","order_invoice_late":"button[data-ff52-invoice]","driver_accept_addition":"button[data-ff52-accept]","driver_reject_addition":"button[data-ff52-reject]","driver_pickup_addition":"button[data-ff52-pickup]","cashier_receive":"button[data-ff49-receive]","cashier_invoice":"button[data-ff49-invoice]","cashier_burger":"button[data-ff-burger-notify]","cashier_invoice_addition":"button[data-invoice-addition]","cashier_invoice_late":"button[data-ff52-invoice]","assembly_filter_all":"button[data-assembly-filter=\"all\"]","assembly_filter_printed":"button[data-assembly-filter=\"printed\"]","assembly_filter_preparing":"button[data-assembly-filter=\"preparing\"]","assembly_filter_ready":"button[data-assembly-filter=\"ready\"]","assembly_filter_late":"button[data-assembly-filter=\"late\"]","assembly_filter_priority":"button[data-assembly-filter=\"priority\"]","burger_filter_all":"button[data-ff-burger-filter=\"all\"]","burger_filter_sent":"button[data-ff-burger-filter=\"sent\"]","burger_filter_preparing":"button[data-ff-burger-filter=\"preparing\"]","burger_filter_late":"button[data-ff-burger-filter=\"late\"]","burger_order_timer":"[data-ff-burger-start]","staff_toggle":"button[data-staff-toggle]","staff_assembly_save":"button[data-assembly-save]","staff_assembly_convert":"button[data-assembly-convert]","staff_edit":"button[data-ffedit]","staff_save_access":"button[data-save-access]","staff_permission_save":"button[data-permission-save]","message_ack":"button[data-ff39-ack]","message_read":"button[data-ff39-read]","case_open":"button[data-ff41-open]","settlement_select":"button[data-ff42-select]","qa_case_save":"button[data-ff47-save]","reservation_next":"button[data-ff49-reserve-next]","reservation_cancel":"button[data-ff49-reserve-cancel]","transfer_confirm":"button[data-ff49-confirm-transfer]","change_approve":"button[data-ff50-approve]","change_reject":"button[data-ff50-reject]","change_service":"button[data-ff50-service]","change_pos":"button[data-ff50-pos]","catalog_item_edit":"button[data-ff51-item-edit]","catalog_item_toggle":"button[data-ff51-item-toggle]","catalog_offer_edit":"button[data-ff51-offer-edit]","catalog_offer_toggle":"button[data-ff51-offer-toggle]","customer_open":"button[data-ff51-customer]","route_edit":"button[data-ff52-route-edit]","lifecycle_action":"button[data-ff60-action]","watch_tab":"button[data-ff5-tab]","watch_find":"button[data-ff5-find]"},"roots":{"order_repeat_addition":"#staffOrders","driver_addition_actions":"#driverTasks","cashier_repeat_actions":"#cashierOrders","assembly_filters":"#ffV12AssemblyWorkspace","burger_filters":"#ffBurgerKitchenWorkspace","burger_timer":"#ffBurgerKitchenWorkspace","staff_repeat_actions":"#staffAdminCard","message_repeat_actions":"#ff39Panel","case_repeat_actions":"#ff41Panel","finance_repeat_actions":"#ff42Panel","system_repeat_actions":"#ff47QAPanel","reservation_repeat_actions":"#ff49ReservationsPanel","order_transfer_repeat":"#ff49TransferPanel","order_changes_repeat":"#ff50ChangesPanel","catalog_repeat_actions":"#ff51CatalogPanel","customer_repeat_actions":"#ff51CustomersPanel","driver_route_repeat":"#ff52RoutesPanel","dashboard_lifecycle_repeat":"#ff60-panel","dashboard_watch_repeat":"#ff5-modal","report_more_controls":"#ff76Center","report_preview_controls":"#ff76PdfDialog","message_template_controls":"#ff39Panel","order_customer_modal":"#ffCustomerEditDialog","order_picker_modal":"#ffUnifiedMenuDialog"}}'''))
   result=page.evaluate("""()=>({count:window.__step03DynamicNodes.length,bad:window.__step03DynamicNodes.filter(o=>!o.node.isConnected||o.node.dataset.ffA07ElAlign!=='center'||o.node.dataset.ffA07Order||o.node.disabled!==o.disabled||o.node.hidden!==o.hidden||o.node.value!==o.value||o.node.onclick!==o.onclick).map(o=>o.key)})""")
   assert result["count"]>=40 and not result["bad"],result
   page.evaluate("""async()=>{window.__a07Rows={};await ffDashboardStudio.sync(true);ffA07Design.refresh()}""")
   assert page.evaluate("""()=>window.__step03DynamicNodes.every(o=>!o.node.dataset.ffA07ElAlign)""")
   page.evaluate("""()=>window.__step03Inserted.forEach(n=>n.remove())""")
   page.evaluate("""async({spec,dyn,roots})=>{const rows={};window.__extraControls=[];for(const [g,c] of Object.entries(spec)){if(g.startsWith('assembly_burger')||g==='cashier_reward_redeem')continue;rows[c.screen]??={id:905,pack:'D01',style_config:{elements:{}}};rows[c.screen].style_config.elements[g]=c.keys.map(key=>({key,shape:'round',size:'large',align:'center'}));const root=document.querySelector(roots[g]);if(!root)continue;for(const key of c.keys){const ns=dyn[key]?[...root.querySelectorAll(dyn[key])]:[document.getElementById(key)].filter(n=>n&&root.contains(n));for(const node of ns)window.__extraControls.push({key,node,disabled:node.disabled,hidden:node.hidden,value:node.value,onclick:node.onclick});}}window.__a07Rows=rows;await ffDashboardStudio.sync(true);ffA07Design.refresh()}""",json.loads(r'''{"spec":{"system_recovery_controls":{"screen":"system","keys":["ffA12Scope","ffA12Branch","ffA12Type","ffA12From","ffA12To","ffA12Preview","ffA12Confirm","ffA12Execute","ffA12List","ffA12Batch","ffA12RestoreConfirm","ffA12Restore","ffA12FixtureType","ffA12FixtureDate","ffA12FixtureConfirm","ffA12Fixture"],"styleOnly":true},"messages_grant_limits":{"screen":"messages","keys":["ffA11GrantPriority","ffA11GrantHours"],"styleOnly":true},"reports_presets_and_approval":{"screen":"reports","keys":["ff76PresetName","ff76PresetList","ffA10GrantUser","ffA10GrantSection","ffA10GrantAllowed","ff76ManagerName","ff76ManagerNotes"],"styleOnly":true},"report_rating_escalate":{"screen":"reports","keys":["ffA10RatingEscalate"],"styleOnly":true},"order_customer_edit_fields":{"screen":"orders","keys":["order_edit_name","order_edit_phone","order_edit_area","order_edit_address","order_edit_reason","order_edit_customer_note"],"styleOnly":true},"order_picker_search":{"screen":"orders","keys":["ffUnifiedMenuSearch"],"styleOnly":true},"case_alert_controls":{"screen":"cases","keys":["ffCaseAlertClose","ffCaseAlertRefresh"],"styleOnly":true},"archive_completed_controls":{"screen":"archive","keys":["fflCashierFinishedToggle","fflFinishedFrom","fflFinishedTo","fflFinishedBranch","fflFinishedToday","fflFinishedApply","fflFinishedSearch","fflFinishedRefresh","fflFinishedMore"],"styleOnly":true},"archive_completed_detail":{"screen":"archive","keys":["ffCompletedDetailClose"],"styleOnly":true},"dashboard_operational_day":{"screen":"dashboard","keys":["ffF01Date","ffF01Compare","ffF01Branch","ffF01Today","ffF01Refresh"],"styleOnly":true},"reports_history_period":{"screen":"reports","keys":["ffHistoryFrom","ffHistoryTo","ffHistoryToday","ffHistoryApply"],"styleOnly":true},"finance_range_controls":{"screen":"finance","keys":["ff42RangeFrom","ff42RangeTo","ff42RangeApply"],"styleOnly":true},"order_reward_issue":{"screen":"orders","keys":["ffRewardItemSearch","ffRewardIssue","ffRewardCodesRefresh","reward_issue_kind","reward_issue_name","reward_issue_phone","reward_issue_expiry"],"styleOnly":true},"order_reward_redeem_start":{"screen":"orders","keys":["ffRewardServiceCode","ffRewardServiceApply"],"styleOnly":true},"cashier_reward_start":{"screen":"cashier","keys":["ffRewardCashierCode","ffRewardCashierApply"],"styleOnly":true},"order_reward_redeem":{"screen":"orders","keys":["ffRewardRedeemButton","ffRewardRedeemClose","reward_redeem_branch","reward_redeem_channel","reward_redeem_area","reward_redeem_fee","reward_redeem_notes","reward_redeem_verify"],"styleOnly":true},"cashier_reward_redeem":{"screen":"cashier","keys":["ffRewardRedeemButton","ffRewardRedeemClose","reward_redeem_branch","reward_redeem_channel","reward_redeem_area","reward_redeem_fee","reward_redeem_notes","reward_redeem_verify"],"styleOnly":true},"cashier_burger_send":{"screen":"cashier","keys":["ffBurgerPanelToggle","ffBurgerNew","ffBurgerCollapse"],"styleOnly":true},"cashier_burger_send_fields":{"screen":"cashier","keys":["ffBurgerSubmit","ffBurgerCancel","burger_send_branch","burger_send_kind","burger_send_order","burger_send_invoice","burger_send_notes"],"styleOnly":true},"assembly_burger_send":{"screen":"assembly","keys":["ffBurgerPanelToggle","ffBurgerNew","ffBurgerCollapse"],"styleOnly":true},"assembly_burger_send_fields":{"screen":"assembly","keys":["ffBurgerSubmit","ffBurgerCancel","burger_send_branch","burger_send_kind","burger_send_order","burger_send_invoice","burger_send_notes"],"styleOnly":true}},"dyn":{"order_edit_name":"#ffCustomerEditDialog [name=\"name\"]","order_edit_phone":"#ffCustomerEditDialog [name=\"phone\"]","order_edit_area":"#ffCustomerEditDialog [name=\"area\"]","order_edit_address":"#ffCustomerEditDialog [name=\"address\"]","order_edit_reason":"#ffCustomerEditDialog [name=\"reason\"]","order_edit_customer_note":"#ffCustomerEditDialog [name=\"customer_note\"]","reward_issue_kind":"#ffRewardManager [name=\"kind\"]","reward_issue_name":"#ffRewardManager [name=\"name\"]","reward_issue_phone":"#ffRewardManager [name=\"phone\"]","reward_issue_expiry":"#ffRewardManager [name=\"expiry\"]","reward_redeem_branch":"#ffRewardRedeemDialog [name=\"branch\"]","reward_redeem_channel":"#ffRewardRedeemDialog [name=\"channel\"]","reward_redeem_area":"#ffRewardRedeemDialog [name=\"area\"]","reward_redeem_fee":"#ffRewardRedeemDialog [name=\"fee\"]","reward_redeem_notes":"#ffRewardRedeemDialog [name=\"notes\"]","reward_redeem_verify":"#ffRewardRedeemDialog [name=\"verify\"]","burger_send_branch":"#ffBurgerDialog [name=\"branch\"]","burger_send_kind":"#ffBurgerDialog [name=\"kind\"]","burger_send_order":"#ffBurgerDialog [name=\"order\"]","burger_send_invoice":"#ffBurgerDialog [name=\"invoice\"]","burger_send_notes":"#ffBurgerDialog [name=\"notes\"]"},"roots":{"system_recovery_controls":"#ffA12Recovery","messages_grant_limits":"#ff39Panel","reports_presets_and_approval":"#ff76Center","report_rating_escalate":"#ff76Center","order_customer_edit_fields":"#ffCustomerEditDialog","order_picker_search":"#ffUnifiedMenuDialog","case_alert_controls":"#ffCaseAlertDialog","archive_completed_controls":"#fflCashierFinished","archive_completed_detail":"#ffCompletedDetailDialog","dashboard_operational_day":"#ffF01Panel","reports_history_period":"#ffHistoryPeriod","finance_range_controls":"#ff42RangeReport","order_reward_issue":"#ffRewardManager","order_reward_redeem_start":"#ffRewardService","cashier_reward_start":"#ffRewardCashier","order_reward_redeem":"#ffRewardRedeemDialog","cashier_reward_redeem":"#ffRewardRedeemDialog","cashier_burger_send":"#ffBurgerCashierPanel","cashier_burger_send_fields":"#ffBurgerDialog","assembly_burger_send":"#ffBurgerCashierPanel","assembly_burger_send_fields":"#ffBurgerDialog"}}'''))
   extra=page.evaluate("""()=>({count:window.__extraControls.length,bad:window.__extraControls.filter(o=>!o.node.isConnected||o.node.dataset.ffA07ElAlign!=='center'||o.node.disabled!==o.disabled||o.node.hidden!==o.hidden||o.node.value!==o.value||o.node.onclick!==o.onclick).map(o=>o.key)})""")
   assert extra["count"]>=45 and not extra["bad"],extra
   page.evaluate("""async()=>{window.__a07Rows={};await ffDashboardStudio.sync(true);ffA07Design.refresh()}""")
   assert page.evaluate("()=>window.__extraControls.every(o=>!o.node.dataset.ffA07ElAlign)")
   page.evaluate("""async()=>{window.__a07Rows={finance:{id:721,pack:'D07',style_config:{density:'compact'}},branches:{id:722,pack:'D08',style_config:{radius:'round'}}};await ffDashboardStudio.sync(true)}""")
   assert page.locator("#ff42Panel").get_attribute("data-ff-a07-pack")=="D07"
   assert page.locator("#ffA05BranchCard").get_attribute("data-ff-a07-pack")=="D08"
   assert page.locator("#loginOverlay .loginbox").get_attribute("data-ff-a07-pack") is None
   page.evaluate("()=>window.ffDashboardStudio.open()")
   dlg=page.locator("#ffStudio");assert dlg.is_visible()
   dlg.locator("select[name=screen]").select_option("login")
   assert dlg.locator("select[name=role]").input_value()=="all"
   assert dlg.locator("select[name=role]").is_disabled()
   assert dlg.locator("select[name=branch]").is_disabled()
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
   dlg.locator("select[name=screen]").select_option("reports")
   assert dlg.locator("[data-a07-after] [data-step03-kind=field]").count()>0
   assert dlg.locator("[data-a07-after] [data-step03-kind=region]").count()>0
   dlg.locator("#ffA07Elements > summary").click()
   assert dlg.locator("[data-a07-group]").input_value()=="reports_actions"
   assert dlg.locator(".ff-a07-element-row").count()==4
   dlg.locator("#ffA07Elements > summary").click()
   dlg.locator("select[name=screen]").select_option("driver")
   dlg.locator("select[name=role]").select_option("driver")
   dlg.locator("#ffA07Elements > summary").click()
   dlg.locator("[data-a07-after] [data-step03-preview=clockInBtn]").first.click()
   assert dlg.locator("[data-a07-group]").input_value()=="driver_actions"
   assert dlg.locator(".ff-a07-element-row[data-element-key=clockInBtn] details").get_attribute("open") is not None
   dlg.locator('[data-step03-content="driver.attend"]').click()
   page.wait_for_function("()=>Array.from(document.querySelectorAll('dialog[open]')).length===2")
   page.wait_for_function("()=>Array.from(document.querySelectorAll('dialog[open] select')).some(s=>s.value==='driver.attend')")
   page.evaluate("()=>Array.from(document.querySelectorAll('dialog[open]')).find(d=>d.id!=='ffStudio').close()")
   assert dlg.is_visible()
   dlg.locator("[data-a07-group]").select_option("driver_actions")
   first=dlg.locator(".ff-a07-element-row").first
   assert first.get_attribute("data-element-key")=="ff51BreakBtn"
   first.get_by_role("button",name="تأخير").click()
   assert dlg.locator(".ff-a07-element-row").first.get_attribute("data-element-key")=="clockInBtn"
   dlg.locator(".ff-a07-element-row").first.locator("select").first.select_option("pill")
   first_props=dlg.locator(".ff-a07-element-row").first.locator("details")
   if first_props.get_attribute("open") is None: first_props.locator("summary").click()
   dlg.locator(".ff-a07-element-row").first.locator('[data-step03-property=weight]').select_option("strong")
   assert dlg.locator("[data-a07-after] [data-ff-a07-el-weight=strong]").count()>=1
   dlg.locator("[data-a07-undo]").click()
   assert dlg.locator("[data-a07-after] [data-ff-a07-el-weight=strong]").count()==0
   dlg.locator("[data-a07-undo]").click()
   assert dlg.locator(".ff-a07-element-row").first.locator("select").first.input_value()=="inherit"
   dlg.locator("[data-a07-redo]").click()
   assert dlg.locator(".ff-a07-element-row").first.locator("select").first.input_value()=="pill"
   assert dlg.locator("[data-a07-after] [data-ff-a07-shape=pill]").count()>=1
   dlg.locator("[data-a07-redo]").click()
   assert dlg.locator("[data-a07-after] [data-ff-a07-el-weight=strong]").count()>=1
   row=dlg.locator(".ff-a07-element-row").first
   if row.locator("details").get_attribute("open") is None: row.locator("details summary").click()
   row.locator('[data-step03-property=align]').select_option("end")
   row.locator('[data-step03-property=textScale]').select_option("large")
   row.locator('[data-step03-property=font]').select_option("cairo")
   assert dlg.locator("[data-a07-after] [data-ff-a07-el-align=end]").count()==1
   dlg.locator("[data-a07-undo]").click()
   assert dlg.locator("[data-a07-after] [data-ff-a07-el-font=cairo]").count()==0
   dlg.locator("[data-a07-redo]").click()
   assert dlg.locator("[data-a07-after] [data-ff-a07-el-font=cairo]").count()==1
   if row.locator("details").get_attribute("open") is None: row.locator("details summary").click()
   row.locator("[data-step03-reset-element]").click()
   assert row.locator("select").first.input_value()=="inherit"
   assert dlg.locator("[data-a07-after] [data-ff-a07-el-font=cairo]").count()==0
   dlg.locator("[data-a07-undo]").click()
   assert row.locator("select").first.input_value()=="pill"
   assert dlg.locator("[data-a07-after] [data-ff-a07-el-font=cairo]").count()==1
   dlg.locator("#ffStep03ScopeCompare > summary").click()
   dlg.locator("[data-step03-compare]").click()
   page.wait_for_function("()=>document.querySelector('[data-step03-compare-results]').children.length===2")
   assert dlg.locator("[data-step03-compare-results]").get_by_text("خارج نطاق المسودة — لا تغيير.").count()==1
   assert page.evaluate("()=>window.__a06Calls.filter(c=>c.name==='ff_a07_preview_scope').length")==2
   dlg.locator("input[name=draftName]").fill("مسودة اختبار آمنة")
   dlg.locator("button[type=submit]").click()
   page.wait_for_function("()=>window.__a06Calls.some(c=>c.name==='ff_a07_named_design')")
   payload=page.evaluate("()=>window.__a06Calls.filter(c=>c.name==='ff_a07_named_design').at(-1).args")
   assert payload["p_screen"]=="driver" and payload["p_style"]["elements"]["driver_actions"][0]["key"]=="clockInBtn"
   assert payload["p_style"]["elements"]["driver_actions"][0]["shape"]=="pill"
   assert len(payload["p_style"]["elements"]["driver_actions"])==3
   assert payload["p_style"]["elements"]["driver_actions"][0]["weight"]=="strong"
   assert payload["p_style"]["elements"]["driver_actions"][0]["align"]=="end"
   assert payload["p_style"]["elements"]["driver_actions"][0]["textScale"]=="large"
   assert payload["p_style"]["elements"]["driver_actions"][0]["font"]=="cairo"
   assert all("orderMode" not in e for e in payload["p_style"]["elements"]["driver_actions"])
   assert payload["p_style"]["elements"]["driver_actions"][1]["shape"]=="inherit"
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
 ctx=browser.new_context(viewport={"width":390,"height":850},service_workers="block",reduced_motion="reduce")
 ctx.route("**/*",lambda route:route.continue_() if route.request.url.startswith(origin) else route.abort())
 page=ctx.new_page();page.goto(origin,wait_until="load")
 page.wait_for_function("()=>!!window.ffA07Design")
 page.evaluate("""async()=>{client={};user=null;data=null;document.body.dataset.access='locked';document.getElementById('loginOverlay').classList.remove('hidden');rpc=async(name,args)=>name==='ff_a07_public_appearance'?{pack:'D05',layout_text:'PUBLIC QA',style_config:{logoAsset:'mark'}}:null;await ffA07Design.syncPublic(true)}""")
 assert page.locator("#loginOverlay .loginbox").get_attribute("data-ff-a07-pack")=="D05"
 assert page.locator("#loginOverlay .loginbox").get_by_text("PUBLIC QA").count()==1
 assert page.locator("#password").get_attribute("type")=="password"
 page.evaluate("""async()=>{document.body.dataset.access='customer';await ffA07Design.syncPublic(true)}""")
 assert page.locator("#loginOverlay .loginbox").get_attribute("data-ff-a07-pack") is None
 assert page.locator("#ff28Portal").get_attribute("data-ff-a07-pack")=="D05"
 ctx.close()
 print("PASS STEP03 independent finance, branch, login and customer scopes",flush=True)
 browser.close()
server.shutdown()
(out/"role-pack-matrix.json").write_text(json.dumps(results,ensure_ascii=False,indent=2))
assert len(results)==7*47
print("PASS A07",len(results),"actual role/width/pack checks, gallery and reset",flush=True)
