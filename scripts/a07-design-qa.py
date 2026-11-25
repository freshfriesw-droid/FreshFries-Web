"""A07 offline Chromium regression: all 16 packs on the seven actual role workspaces."""
import json
import re
import sys
import subprocess
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
alternate="--alternate" in sys.argv
out=root/"a07-evidence"
if alternate: out=out/"alternate"
out.mkdir(parents=True,exist_ok=True)
# Audit the current registry rather than an old hard-coded snapshot.
_registry_source=(root/"scripts/luxe-a07-elements.js").read_text()
def registry_dict(name):
 rows={}
 for raw in re.findall(r"(?:const "+name+r"=|Object\.assign\("+name+r",)(\{[^\n]+\})(?:;|\);)",_registry_source):
  rows.update(json.loads(raw))
 assert rows,name
 return rows
registry={"groups":registry_dict("groups"),"dyn":registry_dict("dynamicSelectors")}
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
  if(name==='ff_a07_preview_scope')return {applies:args.p_target_device==='mobile',before:{pack:'D01',style_config:{elements:{driver_actions:[{key:'clockInBtn',font:'tahoma'}]}}},after:{pack:args.p_target_device==='mobile'?'D08':'D01',style_config:{elements:{driver_actions:[{key:'clockInBtn',font:args.p_target_device==='mobile'?'cairo':'tahoma'}]}}},before_sources:{'elements.driver_actions.clockInBtn.font':17},after_sources:{'elements.driver_actions.clockInBtn.font':args.p_target_device==='mobile'?-1:17}};
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
step05_design_metrics=[]
visual_matrix=[]
def collect_visual(page):
 visual_matrix.extend(page.evaluate("()=>window.__step03Matrix||[]"))
 (out/"step03-computed-property-matrix.json").write_text(json.dumps(visual_matrix,ensure_ascii=False,indent=2))
 print("STEP03 computed matrix",sum(x["computed"] for x in visual_matrix),"binding-only",sum(x["bindingOnly"] for x in visual_matrix),"failures",sum(len(x["failures"]) for x in visual_matrix),flush=True)
with sync_playwright() as pw:
 browser=pw.chromium.launch(channel="chrome")
 for role,(screen,selector) in roles.items():
  ctx=browser.new_context(viewport={"width":390,"height":850},service_workers="block",reduced_motion="reduce")
  ctx.route("**/*",lambda route:route.continue_() if route.request.url.startswith(origin) else route.abort())
  ctx.add_init_script(path=root/'scripts/step03-visual-matrix-probe.js');page=ctx.new_page();page.goto(origin,wait_until="load");page.evaluate(fixture,role)
  page.wait_for_function("()=>!!window.ffA07Design&&!!window.ffDashboardStudio")
  if role=="assembly":page.locator("#ffV12Toggle").click()
  if role in ("driver","cashier","customer_service"):
   key={"driver":"attendance","cashier":"cashier","customer_service":"new"}[role]
   page.locator('#ffx-mobile-nav button[data-key="'+key+'"]').click()
  signatures=set();noncolor_signatures=set();actual_signatures=set()
  if role in ('cashier','driver'):
   holder='#cashierOrders' if role=='cashier' else '#driverTasks'
   status_probe=page.locator(holder).evaluate('e=>{const n=document.createElement("article");n.className="item ff-luxe-cancelled";n.id="a07-status-probe";e.append(n);return getComputedStyle(n).borderTopColor}')
  for width in (320,360,390,430,768,1024,1440):
   page.set_viewport_size({"width":width,"height":850})
   for i in (range(1,17) if width in (390,1440) else (1,8,16)):
    pack=f"D{i:02d}"
    row={"id":i,"pack":pack,"bar":"labels","layout_text":"وصف تجريبي","style_config":{}}
    render_ms=page.evaluate("""async ([screen,row])=>{const t=performance.now();window.__a07Rows={[screen]:row};await window.ffDashboardStudio.sync(true);return performance.now()-t}""",[screen,row])
    if role in ('manager','cashier') and width in (390,1440):
     metrics=page.locator(selector).evaluate("""e=>{
      const rgb=v=>{const m=v.match(/\\d+(?:\\.\\d+)?/g);return m?m.slice(0,3).map(Number):null};
      const lum=a=>a.map(v=>v/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4).reduce((n,v,i)=>n+v*[.2126,.7152,.0722][i],0);
      const card=e.querySelector('.ffx-hero,.card'),title=card.querySelector('h1,h2,h3');const fg=rgb(getComputedStyle(title).color),bg=rgb(getComputedStyle(card).backgroundColor);
      const root=getComputedStyle(e),hex=v=>{v=v.trim();if(!/^#[0-9a-f]{3}([0-9a-f]{3})?$/i.test(v))return null;if(v.length===4)v='#'+v.slice(1).split('').map(c=>c+c).join('');return [1,3,5].map(i=>parseInt(v.slice(i,i+2),16))};
      const ratio=(a,b)=>a&&b?(Math.max(lum(a),lum(b))+.05)/(Math.min(lum(a),lum(b))+.05):null;
      return {actualContrast:ratio(fg,bg),packContrast:ratio(hex(root.getPropertyValue('--a07-bg')),hex(root.getPropertyValue('--a07-ink'))),title: title.getBoundingClientRect().width,card:card.getBoundingClientRect().width}
     }""")
     assert metrics["packContrast"] is not None and metrics["packContrast"]>=4.5,(role,width,pack,metrics)
     assert metrics["actualContrast"] is not None and metrics["actualContrast"]>=4.5,(role,width,pack,metrics)
     assert metrics["title"]>0 and metrics["card"]>0,(role,width,pack,"unmounted component")
     step05_design_metrics.append(dict(role=role,width=width,pack=pack,render_ms=round(render_ms,2),**metrics))
    result=page.locator(selector).evaluate("""e=>{const s=getComputedStyle(e);return {pack:e.dataset.ffA07Pack,signature:['bg','ink','radius','gap','cols','pad','font','shadow','scale'].map(k=>s.getPropertyValue('--a07-'+k)).join('|'),overflow:document.documentElement.scrollWidth>innerWidth+1}}""")
    assert result["pack"]==pack,(role,width,pack,result)
    assert not result["overflow"],(role,width,pack,"page overflow")
    signatures.add(result["signature"]);results.append({"role":role,"width":width,"pack":pack})
    if width==1440:
     noncolor=page.locator(selector).evaluate("""e=>{const s=getComputedStyle(e);return ['radius','gap','cols','pad','font','shadow','scale','border','button-radius'].map(k=>s.getPropertyValue('--a07-'+k).trim()).join('|')}""")
     noncolor_signatures.add(noncolor)
     if role in ('manager','cashier'):
      actual=page.locator(selector).evaluate("""e=>{const main=getComputedStyle(e),card=e.querySelector('.ffx-hero,.card'),s=getComputedStyle(card),grid=e.querySelector('#cashierOrders,#ffx-kpis'),g=grid?getComputedStyle(grid):null;return [main.fontSize,main.fontFamily,s.borderTopLeftRadius,s.borderTopWidth,s.paddingTop,s.gap,s.boxShadow,g?.gridTemplateColumns,g?.gap].join('|')}""")
      actual_signatures.add(actual)
    if width in (390,1440) and (i in (1,16) or (role in ('manager','cashier') and not alternate)):
     page.screenshot(path=out/f"{role}-{width}-{pack}.png",animations="disabled")
  assert len(signatures)==16,(role,"distinct packs",len(signatures))
  assert len(noncolor_signatures)==16,(role,"non-color design distinction",len(noncolor_signatures))
  if role in ('manager','cashier'):
   assert len(actual_signatures)==16,(role,"actual computed component geometries",len(actual_signatures))
   print("PASS STEP05 16 distinct actual component geometries",role,flush=True)
  if role in ("cashier","driver"):
   assert page.locator("#a07-status-probe").evaluate("n=>getComputedStyle(n).borderTopColor")==status_probe
  if alternate: page.set_viewport_size({"width":390,"height":850})
  # Audit actual mounted controls, not just registered keys or synthetic stand-ins.
  # The full output explicitly distinguishes unavailable and computed mismatches.
  # No operational click, data modification or real backend request occurs.
  audit=page.evaluate("""async({groups,dyn})=>{
   const roots=[...document.querySelectorAll('[data-ff-a07-screen]')];
   const rows={};const observations=[];const native=[...document.querySelectorAll('[data-ff-a07-screen] input[type=checkbox],[data-ff-a07-screen] input[type=file]')].map(n=>({node:n,checked:n.checked,disabled:n.disabled,required:n.required,value:n.value,type:n.type}));
   for(const [g,c] of Object.entries(groups)){
    if(['login','customer_portal'].includes(c.screen))continue;
    rows[c.screen]??={id:990,pack:'D01',style_config:{elements:{}}};
    rows[c.screen].style_config.elements[g]=c.keys.map(key=>({key,shape:'round',size:'normal',align:'center',weight:'strong',textScale:'large',shadow:'soft'}));
   }
   window.__a07Rows=rows;await ffDashboardStudio.sync(true);ffA07Design.refresh();
   for(const [g,c] of Object.entries(groups)){
    if(['login','customer_portal'].includes(c.screen))continue;
    for(const key of c.keys){
     let ns=[];
     for(const r of roots.filter(r=>r.dataset.ffA07Screen===c.screen)){
      let found=dyn[key]?[...r.querySelectorAll(dyn[key])]:key==='cashier_stage'?[...r.querySelectorAll('[data-cashier]')]:[document.getElementById(key)].filter(n=>n&&r.contains(n));
      if(g==='driver_regions')found=found.map(n=>n.closest('.card')).filter(Boolean);
      if(g==='assembly_stats')found=found.map(n=>n.parentElement).filter(Boolean);
      ns.push(...found.filter(n=>n.closest('[data-ff-a07-screen]')?.dataset.ffA07Screen===c.screen));
     }
     ns=[...new Set(ns)];
     const failures=[];
     for(const original of ns){
      const n=ffA07Elements.visualTarget(original),s=getComputedStyle(n);
      if(n!==original&&(original.dataset.ffA07Shape||original.dataset.ffA07ElAlign))failures.push('native-input-styled');
      if(n.dataset.ffA07ElAlign!=='center'||s.textAlign!=='center')failures.push('align');
      if(n.dataset.ffA07ElWeight!=='strong'||Number(s.fontWeight)<700)failures.push('weight');
      if(n.dataset.ffA07ElTextScale!=='large')failures.push('scale-attribute');
      if(n.dataset.ffA07ElShadow!=='soft'||s.boxShadow==='none')failures.push('shadow');
      if(n.dataset.ffA07Shape!=='round'||parseFloat(s.borderTopLeftRadius)<=0)failures.push('shape');
     }
     observations.push({screen:c.screen,group:g,key,matched:ns.length,visible:ns.filter(n=>n.getClientRects().length>0).length,failures:[...new Set(failures)]});
    }
   }
   window.step03Probe('mounted-'+data?.role,rows,dyn);
   window.__a07Rows={};await ffDashboardStudio.sync(true);ffA07Design.refresh();
   for(const o of native)if(o.node.isConnected&&(o.node.checked!==o.checked||o.node.disabled!==o.disabled||o.node.required!==o.required||o.node.value!==o.value||o.node.type!==o.type||ffA07Elements.visualTarget(o.node).dataset.ffA07ElAlign))throw Error('native state/reset changed '+o.node.id);
   return observations;
  }""",registry)
  (out/f"step03-actual-element-audit-{role}.json").write_text(json.dumps(audit,ensure_ascii=False,indent=2))
  assert any(x["matched"] for x in audit),(role,"no actual matches")
  assert not [x for x in audit if x["failures"]],(role,[x for x in audit if x["failures"]])
  print("STEP03 actual mounted audit",role,"matched",sum(x["matched"]>0 for x in audit),"computed mismatches",sum(bool(x["failures"]) for x in audit),flush=True)
  if role=="manager":
   # Force genuine Chromium pseudo states without dispatching operational clicks.
   interaction=page.evaluate("""async()=>{
    const keys=[...ffA07Elements.toneAllowed],rows={};
    for(const [group,c] of Object.entries(ffA07Elements.groups)){
     if(!c.keys.some(k=>keys.includes(k)))continue;
     rows[c.screen]??={id:996,pack:'D01',style_config:{elements:{}}};
     rows[c.screen].style_config.elements[group]=c.keys.map(key=>({key,shape:'pack',size:'normal',...(keys.includes(key)?{hover:'outline',press:'inset'}:{})}));
    }
    window.__a07Rows=rows;await ffDashboardStudio.sync(true);ffA07Design.refresh();
    const style=document.createElement('style');style.id='qa-no-transitions';style.textContent='[data-ff-a07-screen] *{transition:none!important}';document.head.append(style);
    return keys.map(key=>{const n=document.getElementById(key);return {key,exists:!!n,disabled:n?.disabled,scope:n?.closest('[data-ff-a07-screen]')?.dataset.ffA07Screen,hover:n?.dataset.ffA07ElHover,press:n?.dataset.ffA07ElPress}});
   }""")
   assert all(x["exists"] and x.get("hover")=="outline" and x.get("press")=="inset" for x in interaction),interaction
   cdp=ctx.new_cdp_session(page);cdp.send("DOM.enable");cdp.send("CSS.enable")
   root_id=cdp.send("DOM.getDocument")["root"]["nodeId"]
   pseudo_results=[]
   for item in interaction:
    key=item["key"];node_id=cdp.send("DOM.querySelector",{"nodeId":root_id,"selector":"#"+key})["nodeId"]
    assert node_id,key
    locator=page.locator("#"+key)
    saved=locator.evaluate("n=>({disabled:n.disabled,html:n.innerHTML,onclick:n.getAttribute('onclick'),type:n.getAttribute('type')})")
    def pseudo(*states):
     cdp.send("CSS.forcePseudoState",{"nodeId":node_id,"forcedPseudoClasses":list(states)})
     return locator.evaluate("n=>({outline:getComputedStyle(n).outline,style:getComputedStyle(n).outlineStyle,width:getComputedStyle(n).outlineWidth,shadow:getComputedStyle(n).boxShadow,bg:getComputedStyle(n).backgroundColor,fg:getComputedStyle(n).color})")
    def effects(hover=None,press=None,tone=None):
     page.evaluate("""async ([key,hover,press,tone])=>{for(const row of Object.values(window.__a07Rows))for(const rows of Object.values(row.style_config.elements))for(const e of rows)if(e.key===key){for(const [p,v] of Object.entries({hover,press,tone}))if(v===null)delete e[p];else e[p]=v;}await ffDashboardStudio.sync(true);ffA07Design.refresh()}""",[key,hover,press,tone])
    try:
     # Test both native states of the actual button in the offline fixture.
     # No click or RPC action; the real disabled state is restored in finally.
     for disabled in (False,True):
      locator.evaluate("(n,v)=>{n.disabled=v}",disabled)
      effects()
      baseline_hover=pseudo("hover");baseline_press=pseudo("active");pseudo()
      effects("none","none")
      assert pseudo("hover")==baseline_hover,(key,disabled,"hover none")
      assert pseudo("active")==baseline_press,(key,disabled,"press none")
      pseudo()
      effects("outline","inset")
      hover=pseudo("hover")
      if not disabled: assert hover["style"]=="solid" and hover["width"]=="2px",(key,disabled,hover)
      else: assert hover==baseline_hover,(key,disabled,hover)
      press=pseudo("active")
      if not disabled: assert "inset" in press["shadow"],(key,disabled,press)
      else: assert press==baseline_press,(key,disabled,press)
      pseudo()
      effects("shadow","inset","dark")
      shadow=pseudo("hover")
      if not disabled:
       assert "7px" in shadow["shadow"] and shadow["bg"]=="rgb(34, 34, 34)" and shadow["fg"]=="rgb(255, 255, 255)",(key,shadow)
      else: assert shadow==baseline_hover,(key,disabled,shadow)
      assert locator.evaluate("n=>n.disabled")==disabled
      pseudo_results.append({"key":key,"width":page.viewport_size["width"],"disabled":disabled,"hover_outline":hover,"hover_shadow":shadow,"press":press,"no_effect_matches_native":True})
      pseudo()
    finally:
     locator.evaluate("(n,v)=>{n.disabled=v}",saved["disabled"])
     pseudo()
     effects()
    assert locator.evaluate("n=>({disabled:n.disabled,html:n.innerHTML,onclick:n.getAttribute('onclick'),type:n.getAttribute('type')})")==saved,key
   cdp.detach()
   page.evaluate("""async()=>{document.getElementById('qa-no-transitions')?.remove();window.__a07Rows={};await ffDashboardStudio.sync(true);ffA07Design.refresh()}""")
   (out/"step03-interaction-pseudo-states.json").write_text(json.dumps(pseudo_results,ensure_ascii=False,indent=2))
   assert len(pseudo_results)==18 and len({(x["key"],x["disabled"]) for x in pseudo_results})==18
   print("PASS STEP03 hover, press and disabled-state protection",len(pseudo_results),"actual action/state cases",flush=True)
   # Reproduce nested independent screen using real registered selectors.
   # One test-only fixture in each workspace: disabled buttons must stay disabled.
   isolation=page.evaluate("""()=>{
    const outer=document.createElement('section'),inner=document.createElement('section');
    outer.dataset.ffA07Screen='cashier';inner.dataset.ffA07Screen='archive';
    outer.dataset.ffA07Pack='D01';inner.dataset.ffA07ElementScope='1';
    const own=document.createElement('button'),foreign=document.createElement('button');
    for(const b of [own,foreign]){b.type='button';b.dataset.invoiceAddition='qa';b.disabled=true}
    outer.append(own,inner);inner.append(foreign);document.body.append(outer);
    const c=window.ffA07Elements,g='cashier_repeat_actions';
    const elements={[g]:c.defaultRows(g).map(e=>({...e,align:'center',shape:'round'}))};
    c.refresh(new Set([outer,inner]),{cashier:{style_config:{elements}}});
    const result={own:own.dataset.ffA07ElAlign,foreign:foreign.dataset.ffA07ElAlign??null,disabled:own.disabled&&foreign.disabled,computed:getComputedStyle(own).textAlign};
    c.refresh(new Set([outer,inner]),{});
    result.cleaned=!own.dataset.ffA07ElAlign&&!foreign.dataset.ffA07ElAlign;
    outer.remove();ffA07Design.refresh();return result;
   }""")
   assert isolation=={"own":"center","foreign":None,"disabled":True,"computed":"center","cleaned":True},isolation

  if role in ("manager","cashier","driver","assembly"):
   actual=page.evaluate("""async ({role,selectors})=>{
    const stamp=new Date().toISOString(),b={id:'b1',name:'القاهرة'};
    const mk=(id,phase,stage,extra={})=>({id,number:1000+id.length,branch_id:'b1',driver_id:phase?'qa-driver':null,driver_name:'موصل QA',phase,status:'sent',cashier_stage:stage,created_at:stamp,customer_name:'QA',phone:'000',area:'QA',items:[{qty:1,name:'برجر',price:1000}],...extra});
    const original={orders:data?.orders,offers:data?.offers,additionData,additionReady,activeAdditionForm,additionDraft,rejectPermissions,rejectPermissionReady,lastOfferKey,payload:ffV12AssemblyPayload,filter:ffV12Filter};
    const ids={manager:['order_auto','order_manual','order_transfer','order_toggle_reject','order_open_addition','order_late_addition','additionItemsInput','addition_preview','addition_save','addition_close','order_invoice_addition','order_cancel_addition','order_invoice_late','orders_addition_warning'],cashier:['cashier_receive','cashier_invoice','cashier_stage','cashier_burger','cashier_customer_edit','cashier_invoice_addition','cashier_invoice_late','cashier_status_tag','cashier_addition_warning'],driver:['offer_accept','offer_reject','offer_check_reject','driver_on_way','driver_arrived','driver_delivered','driver_accept_addition','driver_reject_addition','driver_pickup_addition','driver_offer_countdown','driver_addition_notice','driver_addition_invoice_notice'],assembly:['assembly_stage_action','assembly_stage_state','assembly_order_age','assembly_order_note']}[role];
    const screen=role==='manager'?'orders':role;
    const defs=ffA07Elements.groups,selected=Object.fromEntries(Object.entries(defs).filter(([g,c])=>c.screen===screen&&c.keys.some(k=>ids.includes(k))).map(([g,c])=>[g,ffA07Elements.defaultRows(g).map(e=>({...e,align:'center',weight:'strong',shape:'round',shadow:'soft'}))]));
    const ad=(id,order,status,late_state='')=>({id,order_id:order,status,late_state,items:[],amount:100});
    const prior=window.__a07Rows;
    try{
     if(role==='assembly'){
      ffV12AssemblyPayload={role:'assembly',branch:b,orders:[mk('qa-a','assigned','printed',{notes:'QA required note'}),mk('qa-b','assigned','preparing'),mk('qa-c','assigned','ready')]};ffV12Filter='all';ffV12Render();
     }else{
      additionReady=true;additionData=[];
      if(role==='manager'){
       data.orders=[mk('qa-unassigned',null,'waiting'),mk('qa-assigned','assigned','waiting'),mk('qa-printed','assigned','printed'),mk('qa-enroute','on_way','handed_over')];
       activeAdditionForm='qa-assigned';additionDraft='1 تشكن';additionData=[ad('qa-p','qa-assigned','pending'),ad('qa-w','qa-assigned','pending','awaiting_driver'),ad('qa-l','qa-printed','pending','driver_accepted'),ad('qa-i','qa-enroute','invoiced','invoiced')];drawOrders();
      }else if(role==='cashier'){
       data.orders=[mk('qa-wait','assigned','waiting'),mk('qa-receive','assigned','waiting',{cashier_received_at:stamp}),mk('qa-printed','assigned','printed')];
       additionData=[ad('qa-p','qa-wait','pending'),ad('qa-l','qa-receive','pending','driver_accepted'),ad('qa-i','qa-printed','invoiced','invoiced')];drawCashier();
      }else{
       data.orders=[mk('qa-go','assigned','handed_over'),mk('qa-arrive','on_way','handed_over'),mk('qa-add','on_way','handed_over'),mk('qa-pick','on_way','handed_over')];
       additionData=[ad('qa-a','qa-add','pending','awaiting_driver'),ad('qa-i','qa-pick','invoiced','invoiced')];
       data.offers=[{id:'qa-offer1',order_id:'qa-ord1',order_number:1,branch_id:'b1',area:'QA',expires_at:new Date(Date.now()+120000).toISOString()},{id:'qa-offer2',order_id:'qa-ord2',order_number:2,branch_id:'b1',area:'QA',expires_at:new Date(Date.now()+120000).toISOString()}];rejectPermissionReady=true;rejectPermissions={'qa-ord1':true,'qa-ord2':false};lastOfferKey='qa-offer1/qa-offer2';drawDriver();
      }
     }
     ffA07Design.refresh();
     const roots=[...document.querySelectorAll('[data-ff-a07-screen]')].filter(n=>n.dataset.ffA07Screen===screen);
     const records=ids.map(key=>{
      const selector=key==='cashier_stage'?'button[data-cashier]':selectors[key];
      const nodes=[...new Set(roots.flatMap(root=>selector?[...root.querySelectorAll(selector)]:[document.getElementById(key)].filter(n=>n&&root.contains(n))))];
      return {key,nodes:nodes.filter(n=>n.closest('[data-ff-a07-screen]')?.dataset.ffA07Screen===screen).map(n=>({node:n,value:n.value,disabled:n.disabled,hidden:n.hidden,onclick:n.onclick,role:n.getAttribute('role')}))};
     });
     window.__a07Rows={[screen]:{id:999,pack:'D01',bar:'labels',style_config:{elements:selected}}};await ffDashboardStudio.sync(true);ffA07Design.refresh();
     const missing=records.filter(r=>!r.nodes.length).map(r=>r.key),bad=[];
     for(const r of records)for(const o of r.nodes){const n=o.node,target=ffA07Elements.visualTarget(n);if(!n.isConnected||target.dataset.ffA07ElAlign!=='center'||getComputedStyle(target).textAlign!=='center'||n.value!==o.value||n.disabled!==o.disabled||n.hidden!==o.hidden||n.onclick!==o.onclick||n.getAttribute('role')!==o.role)bad.push(r.key)}
     window.step03Probe('operational-'+role,window.__a07Rows,selectors);
     window.__a07Rows={};await ffDashboardStudio.sync(true);ffA07Design.refresh();
     const cleanup=records.every(r=>r.nodes.every(o=>!ffA07Elements.visualTarget(o.node).dataset.ffA07ElAlign));
     return {missing,bad,cleanup,count:records.length};
    }finally{
     if(data){data.orders=original.orders;data.offers=original.offers}
     additionData=original.additionData;additionReady=original.additionReady;activeAdditionForm=original.activeAdditionForm;additionDraft=original.additionDraft;rejectPermissions=original.rejectPermissions;rejectPermissionReady=original.rejectPermissionReady;lastOfferKey=original.lastOfferKey;ffV12AssemblyPayload=original.payload;ffV12Filter=original.filter;
     if(role==='assembly')ffV12Render();else if(role==='manager')drawOrders();else if(role==='cashier')drawCashier();else drawDriver();
     window.__a07Rows=prior;await ffDashboardStudio.sync(true);ffA07Design.refresh();
    }
   }""",{"role":role,"selectors":registry["dyn"]})
   (out/f"step03-real-renderer-{role}.json").write_text(json.dumps(actual,ensure_ascii=False,indent=2))
   assert not actual["missing"] and not actual["bad"] and actual["cleanup"],(role,actual)
   print("PASS STEP03 actual renderer",role,actual["count"],flush=True)

  if role in ("burger_kitchen","cashier","assembly"):
   # The real burger ticket renderer, including mandatory note confirmation,
   # in each workspace. Read-only fixtures, no transition RPC invoked.
   burger=page.evaluate("""async role=>{
    const baseRPC=rpc,now=Date.now(),stamp=n=>new Date(now-n*60000).toISOString();
    const make=(id,status,extra={})=>({id,branch_id:'b1',branch_name:'QA',cashier_name:'QA',kitchen_name:'QA',kitchen_id:user.id,status,order_kind:'delivery',invoice_ref:'QA',sent_at:stamp(30),accepted_at:status==='sent'?null:stamp(10),ready_at:status==='ready'?stamp(1):null,notes:'QA mandatory notes',items:[{qty:1,name:'QA burger',item_notes:'QA item note'}],...extra});
    rpc=async(name,args={})=>name==='ff_burger_list'?[make('qa-burger1','sent'),make('qa-burger2','preparing'),make('qa-burger3','ready')]:name==='ff_burger_my_branch'?{role,branches:[{id:'b1',name:'QA'}]}:baseRPC(name,args);
    try{
     if(role==='burger_kitchen')await ffBurgerStart();
     else{if(role==='assembly'){if(document.getElementById('ffV12BurgerOpen').getAttribute('aria-expanded')!=='true')ffBurgerToggleAssembly()}else ffBurgerOnCashierDraw();await ffBurgerRefresh()}
     await new Promise(r=>setTimeout(r,100));await ffBurgerRefresh();ffA07Design.refresh();
     const screen=role,selectors=role==='burger_kitchen'?{burger_stage_action:'.ff-burger-card > button',burger_stage_state:'.ff-burger-chip',burger_required_note:'.ff-burger-urgent-note',burger_confirm_note:'.ff-burger-note-confirm input',burger_order_timer:'[data-ff-burger-start]'}:role==='cashier'?{cashier_burger_skip:'.ff-burger-card > button',cashier_burger_state:'.ff-burger-chip',cashier_burger_timer:'[data-ff-burger-start]'}:{assembly_burger_skip:'.ff-burger-card > button',assembly_burger_state:'.ff-burger-chip',assembly_burger_timer:'[data-ff-burger-start]'};
     const defs=ffA07Elements.groups,groups=Object.fromEntries(Object.entries(defs).filter(([g,c])=>c.screen===screen&&c.keys.some(k=>Object.hasOwn(selectors,k))).map(([g,c])=>[g,c.keys.map(key=>({key,shape:'round',size:'normal',align:'center',font:'tahoma',border:'strong',shadow:'soft'}))]));
     const records=Object.entries(selectors).map(([key,sel])=>({key,nodes:[...document.querySelectorAll(sel)].filter(n=>n.closest('[data-ff-a07-screen]')?.dataset.ffA07Screen===screen).map(n=>({n,disabled:n.disabled,checked:n.checked,handler:n.onclick,text:n.matches('[data-ff-burger-start]')?null:n.textContent,role:n.getAttribute('role')}))}));
     const note=role==='burger_kitchen'?document.querySelector('.ff-burger-note-confirm input'):null,ready=note?.closest('.ff-burger-card')?.querySelector(':scope > button');
     window.__a07Rows={[screen]:{id:995,pack:'D05',style_config:{elements:groups}}};await ffDashboardStudio.sync(true);ffA07Design.refresh();
     const missing=records.filter(r=>!r.nodes.length).map(r=>r.key),bad=[];
     for(const r of records)for(const o of r.nodes){const t=ffA07Elements.visualTarget(o.n),s=getComputedStyle(t);if(!o.n.isConnected||o.n.disabled!==o.disabled||o.n.checked!==o.checked||o.n.onclick!==o.handler||o.n.getAttribute('role')!==o.role||(o.text!==null&&o.n.textContent!==o.text)||s.textAlign!=='center'||!s.fontFamily.toLowerCase().includes('tahoma')||s.borderTopWidth!=='3px')bad.push(r.key)}
     const protectedNote=role!=='burger_kitchen'||!!(note&&ready&&!note.checked&&ready.disabled&&note.getAttribute('aria-label'));
     window.step03Probe('burger-'+role,window.__a07Rows,selectors);
     window.__a07Rows={};await ffDashboardStudio.sync(true);ffA07Design.refresh();
     return {missing,bad,count:records.length,protectedNote,cleanup:records.every(r=>r.nodes.every(o=>!ffA07Elements.visualTarget(o.n).dataset.ffA07ElAlign))};
    }finally{rpc=baseRPC;await ffBurgerRefresh();}
   }""",role)
   (out/f"step03-burger-renderer-{role}.json").write_text(json.dumps(burger,ensure_ascii=False,indent=2))
   assert not burger["missing"] and not burger["bad"] and burger["protectedNote"] and burger["cleanup"],(role,burger)
   print("PASS STEP03 actual burger renderer",role,burger["count"],flush=True)

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
   # Actual menu logo: repeated failed brand selections must fall back once per
   # selection; periodic refresh must not continuously retry the failed asset.
   recovery=page.evaluate("""async()=>{const style=window.__a07Rows.driver.style_config;const img=()=>document.querySelector('#ffx-sidebar .ff-step03-menu-brand img');const checks=[];for(let i=0;i<2;i++){style.logoAsset='brand';await ffDashboardStudio.sync(true);const n=img();const before=n.getAttribute('src');n.dispatchEvent(new Event('error'));ffA07Design.refresh();checks.push({before,after:n.getAttribute('src'),tried:n.dataset.ffA07Tried});style.logoAsset='mark';await ffDashboardStudio.sync(true)}return checks}""")
   assert len(recovery)==2 and all(c["before"].endswith("ff-official-logo.png") and c["after"].endswith("ff-icon-192.png") and c["tried"]=="1" for c in recovery),recovery
   # A driver feedback dialog retains its own appearance while another tab is
   # active. Navigation state is not its scope. No operational RPC is invoked.
   scoped_dialog=page.evaluate("""async()=>{const d=document.createElement('dialog');d.className='ff-luxe-rate-dialog';d.id='qa-scoped-rate';d.innerHTML='<div id=ffLuxeFourScores><button>★</button></div>';document.body.append(d);window.__a07Rows.dashboard={id:999,pack:'D01',style_config:{dialogRadius:'round',ratingScale:'normal'}};await ffDashboardStudio.sync(true);const selector='#ffx-nav button.active[data-key],#ffx-mobile-nav button.active[data-key]';const prev=[...document.querySelectorAll(selector)];for(const n of prev)n.classList.remove('active');const home=document.querySelector('#ffx-nav button[data-key=home],#ffx-mobile-nav button[data-key=home]');if(!home)throw Error('missing home navigation');home.classList.add('active');ffA07Design.refresh();const result={scope:d.dataset.ffA07Screen,radius:d.dataset.a07DialogRadius,scale:d.dataset.a07RatingScale};home.classList.remove('active');for(const n of prev)n.classList.add('active');d.remove();delete window.__a07Rows.dashboard;await ffDashboardStudio.sync(true);return result}""")
   assert scoped_dialog=={"scope":"driver","radius":"square","scale":"large"},scoped_dialog
   print("PASS STEP03 scoped rating dialog and repeat logo fallback",flush=True)
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
   coverage=page.evaluate("""()=>Object.entries(window.__step03Coverage).flatMap(([g,c])=>c.keys.flatMap(key=>{const n=document.getElementById(key),o=window.__step03Original[key];return !n||!o||n!==o.node||ffA07Elements.visualTarget(n).dataset.ffA07ElAlign!=='center'||ffA07Elements.visualTarget(n).dataset.ffA07Order||n.disabled!==o.disabled||n.value!==o.value||n.onclick!==o.onclick||n.hidden!==o.hidden?[g+':'+key]:[]}))""")
   assert not coverage,coverage
   page.evaluate("""async()=>{window.__a07Rows={};await ffDashboardStudio.sync(true)}""")
   assert page.evaluate("""()=>Object.values(window.__step03Original).every(o=>!ffA07Elements.visualTarget(o.node).dataset.ffA07ElAlign)""")
   page.evaluate("""async({spec,dyn})=>{window.__step03Extra=spec;window.__step03Dynamic=dyn;window.__step03Nodes={};const rows={};for(const [g,c] of Object.entries(spec)){rows[c.screen]??={id:901,pack:'D01',style_config:{elements:{}}};rows[c.screen].style_config.elements[g]=c.keys.map(key=>({key,shape:'pack',size:'normal',align:'center'}));for(const key of c.keys){let ns=dyn[key]?[...document.querySelectorAll(dyn[key])]:[document.getElementById(key)].filter(Boolean);if(ns.length)window.__step03Nodes[key]=ns.map(node=>({node,hidden:node.hidden,disabled:node.disabled,value:node.value,onclick:node.onclick}));}}const holder=document.createElement('div');holder.id='qa-repeat-driver';document.getElementById('driverOffers').append(holder);for(const id of ['test-a','test-b']){const n=document.createElement('button');n.dataset.accept=id;n.disabled=id==='test-b';holder.append(n)}window.__step03Nodes.offer_accept=[...holder.children].map(node=>({node,hidden:node.hidden,disabled:node.disabled,value:node.value,onclick:node.onclick}));window.__a07Rows=rows;await ffDashboardStudio.sync(true);ffA07Design.refresh()}""",json.loads(r'''{"spec":{"order_search_controls":{"screen":"orders","keys":["orderSearch","orderBranchFilter","orderStatusFilter","auditRefreshBtn"],"styleOnly":true},"order_manual_controls":{"screen":"orders","keys":["ff49ManualClose","ff49ManualDriver","ff49ManualReason","ff49ManualConfirm"],"styleOnly":true},"order_late_controls":{"screen":"orders","keys":["ff52LateClose","ff52LateItems","ff75LatePreview","ff52LateSave"],"styleOnly":true},"order_review_controls":{"screen":"orders","keys":["ffbCloseReview","ffbConfirmSave","ffbCancelReview"],"styleOnly":true},"driver_route_controls":{"screen":"driver","keys":["ff52RoutesClose","ff52RouteBranch","ff52RouteDriver","ff52RouteAreas","ff52RouteStart","ff52RouteEnd","ff52RouteActive","ff52RouteSave"],"styleOnly":true},"staff_link_controls":{"screen":"staff","keys":["addEmail","addName","addRole","addBranch","linkUserBtn"],"styleOnly":true},"dashboard_lifecycle_controls":{"screen":"dashboard","keys":["ff60-refresh","ff60-close","ff60-search","ff60-branch","ff60-state","ff60-open-old","ff60-fast","ff60-slow","ff60-save-policy"],"styleOnly":true},"dashboard_watch_controls":{"screen":"dashboard","keys":["ff4-refresh","ff4-export","ff4-close","ff4-search","ff4-branch","ff4-state","ff4-minutes"],"styleOnly":true},"dashboard_overdue_controls":{"screen":"dashboard","keys":["ff5-refresh","ff5-export","ff5-close","ff5-search","ff5-branch","ff5-age","ff5-sort"],"styleOnly":true},"driver_offer_controls":{"screen":"driver","keys":["offer_accept","offer_reject","offer_check_reject"],"styleOnly":true},"driver_progress_controls":{"screen":"driver","keys":["driver_on_way","driver_arrived","driver_delivered"],"styleOnly":true},"order_dynamic_actions":{"screen":"orders","keys":["order_customer_edit","order_auto","order_manual","order_change","order_reassign","order_transfer","order_cancel"],"styleOnly":true},"order_addition_controls":{"screen":"orders","keys":["additionItemsInput","addition_preview","addition_save","addition_close"],"styleOnly":true},"case_detail_controls":{"screen":"cases","keys":["ff41NextStatus","ff41Resolution","ff41CommentBody","case_transition","case_comment"],"styleOnly":true},"staff_edit_fields":{"screen":"staff","keys":["employee_name","employee_username","employee_email","employee_phone","employee_qualification","employee_address","employee_age","employee_marital","employee_experience","employee_password","employee_message"],"styleOnly":true}},"dyn":{"offer_accept":"button[data-accept]","offer_reject":"button[data-reject]","offer_check_reject":"button[data-check-reject]","driver_on_way":"button[data-progress][data-phase=\"on_way\"]","driver_arrived":"button[data-progress][data-phase=\"arrived\"]","driver_delivered":"button[data-progress][data-phase=\"delivered\"]","order_customer_edit":"button[data-ff-customer-edit]","order_auto":"button[data-auto]","order_manual":"button[data-manual]","order_change":"button[data-ff50-change]","order_reassign":"button[data-ff52-reassign]","order_transfer":"button[data-ff49-transfer]","order_cancel":"button[data-cancel-order]","addition_preview":"button[data-ff75-preview-addition]","addition_save":"button[data-save-addition]","addition_close":"button[data-close-addition]","case_transition":"button[data-ff41-transition]","case_comment":"button[data-ff41-comment]","employee_name":"#ffEditForm [name=\"name\"]","employee_username":"#ffEditForm [name=\"username\"]","employee_email":"#ffEditForm [name=\"email\"]","employee_phone":"#ffEditForm [name=\"phone\"]","employee_qualification":"#ffEditForm [name=\"qualification\"]","employee_address":"#ffEditForm [name=\"address\"]","employee_age":"#ffEditForm [name=\"age_years\"]","employee_marital":"#ffEditForm [name=\"marital_status\"]","employee_experience":"#ffEditForm [name=\"experience_years\"]","employee_password":"#ffEditForm [name=\"password\"]","employee_message":"#ffEditForm [name=\"applicant_message\"]"}}'''))
   extra=page.evaluate("""()=>{const bad=[];for(const [key,ns] of Object.entries(window.__step03Nodes))for(const o of ns){const n=o.node;if(!n.isConnected||ffA07Elements.visualTarget(n).dataset.ffA07ElAlign!=='center'||ffA07Elements.visualTarget(n).dataset.ffA07Order||n.hidden!==o.hidden||n.disabled!==o.disabled||n.value!==o.value||n.onclick!==o.onclick)bad.push(key);}return {bad,count:Object.keys(window.__step03Nodes).length}}""")
   assert not extra["bad"],extra
   assert extra["count"]>=40,extra
   assert page.locator("#qa-repeat-driver button[data-accept=test-b]").is_disabled()
   page.evaluate("""()=>{const h=document.getElementById('qa-repeat-driver');const n=document.createElement('button');n.dataset.accept='test-c';h.replaceChildren(n);ffA07Design.refresh()}""")
   assert page.locator("#qa-repeat-driver button[data-accept=test-c]").get_attribute("data-ff-a07-el-align")=="center"
   page.evaluate("""async()=>{window.__a07Rows={};await ffDashboardStudio.sync(true);ffA07Design.refresh()}""")
   assert page.locator("#qa-repeat-driver button[data-accept=test-c]").get_attribute("data-ff-a07-el-align") is None
   page.locator("#qa-repeat-driver").evaluate("n=>n.remove()")
   page.evaluate("""async(spec)=>{window.__step03Shared=spec;window.__step03SharedNodes={};const rows={};for(const [g,c] of Object.entries(spec)){rows[c.screen]??={id:902,pack:'D01',style_config:{elements:{}}};rows[c.screen].style_config.elements[g]=c.keys.map(key=>({key,shape:'pack',size:'normal',align:'center',spaceBlock:'wide',outerGap:'normal'}));for(const key of c.keys){const n=document.getElementById(key);if(n)window.__step03SharedNodes[key]={node:n,value:n.value,disabled:n.disabled,hidden:n.hidden}}}window.__a07Rows=rows;await ffDashboardStudio.sync(true);ffA07Design.refresh()}""",json.loads(r'''{"dashboard_filter_controls":{"screen":"dashboard","keys":["ffx-branch","ffx-kpi-reload","ffx-open-alerts"],"styleOnly":true},"dashboard_shell_controls":{"screen":"dashboard","keys":["ffx-menu","ffx-refresh","ffx-bell","ffx-theme-toggle","ffx-options","ffx-drawer-close"],"styleOnly":true},"dashboard_quick_controls":{"screen":"dashboard","keys":["ff2-close","ff2-search","ff3-close"],"styleOnly":true},"preferences_appearance":{"screen":"system","keys":["ffx-pref-close","ffx-density","ffx-auto","ffx-motion","ffx-fast","ffx-reset"],"styleOnly":true},"preferences_alerts":{"screen":"system","keys":["ffx-audio","ffx-visual","ffx-delay","ffx-sound","ffx-delay-sound","ffx-volume","ffx-repeat","ffx-play-sound","ffx-play-delay","ffx-push-permission","ff-luxe-audio-unlock"],"styleOnly":true},"preferences_tones":{"screen":"system","keys":["ff66-tone-name","ff66-tone-file","ff66-tone-add","ff66-tone-refresh"],"styleOnly":true},"reports_legacy_controls":{"screen":"reports","keys":["ff40ExportCSV","ff40ReportsClose","ff40From","ff40To","ff40ReportBranch","ff40RunReport"],"styleOnly":true},"message_ack_control":{"screen":"messages","keys":["ff39RequireAck"],"styleOnly":true},"dashboard_watch_options":{"screen":"dashboard","keys":["ff4-overdue","ff4-hidephones"],"styleOnly":true},"staff_share_control":{"screen":"staff","keys":["ffEditShare"],"styleOnly":true}}'''))
   shared=page.evaluate("""()=>({bad:Object.entries(window.__step03SharedNodes).filter(([k,o])=>!o.node.isConnected||ffA07Elements.visualTarget(o.node).dataset.ffA07ElAlign!=='center'||ffA07Elements.visualTarget(o.node).dataset.ffA07ElSpaceBlock!=='wide'||o.node.value!==o.value||o.node.hidden!==o.hidden||o.node.disabled!==o.disabled).map(x=>x[0]),count:Object.keys(window.__step03SharedNodes).length})""")
   assert not shared["bad"],shared
   assert shared["count"]>=25,shared
   assert page.locator("#ffx-topbar").get_attribute("data-ff-a07-pack") is None
   assert page.locator("#ffx-topbar").get_attribute("data-ff-a07-element-scope")=="1"
   page.evaluate("""async()=>{window.__a07Rows={};await ffDashboardStudio.sync(true);ffA07Design.refresh()}""")
   assert page.locator("#ffx-topbar").get_attribute("data-ff-a07-element-scope") is None
   assert page.evaluate("""()=>Object.values(window.__step03SharedNodes).every(o=>!ffA07Elements.visualTarget(o.node).dataset.ffA07ElAlign&&!ffA07Elements.visualTarget(o.node).dataset.ffA07ElSpaceBlock)""")
   page.evaluate("""async({spec,dyn,roots})=>{window.__step03DynamicNodes=[];window.__step03Inserted=[];const rows={};for(const [g,c] of Object.entries(spec)){rows[c.screen]??={id:903,pack:'D01',style_config:{elements:{}}};rows[c.screen].style_config.elements[g]=c.keys.map(key=>({key,shape:'pack',size:'normal',align:'center'}));const root=document.querySelector(roots[g]);if(!root)continue;for(const key of c.keys){const selector=dyn[key];let ns=selector?[...root.querySelectorAll(selector)]:[document.getElementById(key)].filter(n=>n&&root.contains(n));if(!ns.length&&selector){const n=document.createElement(selector.startsWith('button')?'button':'span');for(const m of selector.matchAll(/\\[(data-[\\w-]+)(?:="([^"]*)")?\\]/g))n.setAttribute(m[1],m[2]||'qa-fixture');if(n.tagName==='BUTTON'){n.type='button';n.disabled=true}root.append(n);window.__step03Inserted.push(n);ns=[n]}for(const n of ns)window.__step03DynamicNodes.push({key,node:n,disabled:n.disabled,hidden:n.hidden,value:n.value,onclick:n.onclick});}}window.__a07Rows=rows;await ffDashboardStudio.sync(true);ffA07Design.refresh()}""",json.loads(r'''{"spec":{"order_repeat_addition":{"screen":"orders","keys":["order_toggle_reject","order_open_addition","order_late_addition","order_cancel_addition","order_invoice_addition","order_invoice_late"],"styleOnly":true},"driver_addition_actions":{"screen":"driver","keys":["driver_accept_addition","driver_reject_addition","driver_pickup_addition"],"styleOnly":true},"cashier_repeat_actions":{"screen":"cashier","keys":["cashier_receive","cashier_invoice","cashier_burger","cashier_invoice_addition","cashier_invoice_late"],"styleOnly":true},"assembly_filters":{"screen":"assembly","keys":["assembly_filter_all","assembly_filter_printed","assembly_filter_preparing","assembly_filter_ready","assembly_filter_late","assembly_filter_priority"],"styleOnly":true},"burger_filters":{"screen":"burger_kitchen","keys":["burger_filter_all","burger_filter_sent","burger_filter_preparing","burger_filter_late"],"styleOnly":true},"burger_timer":{"screen":"burger_kitchen","keys":["burger_order_timer"],"styleOnly":true},"staff_repeat_actions":{"screen":"staff","keys":["staff_toggle","staff_assembly_save","staff_assembly_convert","staff_edit","staff_save_access","staff_permission_save"],"styleOnly":true},"message_repeat_actions":{"screen":"messages","keys":["message_ack","message_read"],"styleOnly":true},"case_repeat_actions":{"screen":"cases","keys":["case_open"],"styleOnly":true},"finance_repeat_actions":{"screen":"finance","keys":["settlement_select"],"styleOnly":true},"system_repeat_actions":{"screen":"system","keys":["qa_case_save"],"styleOnly":true},"reservation_repeat_actions":{"screen":"reservations","keys":["reservation_next","reservation_cancel"],"styleOnly":true},"order_transfer_repeat":{"screen":"orders","keys":["transfer_confirm"],"styleOnly":true},"order_changes_repeat":{"screen":"orders","keys":["change_approve","change_reject","change_service","change_pos"],"styleOnly":true},"catalog_repeat_actions":{"screen":"catalog","keys":["catalog_item_edit","catalog_item_toggle","catalog_offer_edit","catalog_offer_toggle"],"styleOnly":true},"customer_repeat_actions":{"screen":"customers","keys":["customer_open"],"styleOnly":true},"driver_route_repeat":{"screen":"driver","keys":["route_edit"],"styleOnly":true},"dashboard_lifecycle_repeat":{"screen":"dashboard","keys":["lifecycle_action"],"styleOnly":true},"dashboard_watch_repeat":{"screen":"dashboard","keys":["watch_tab","watch_find"],"styleOnly":true},"report_more_controls":{"screen":"reports","keys":["ff76Close","ff76Today","ff76Yesterday","ff76Seven","ff76Thirty","ff76CSV","ff76SavePreset","ff76UsePreset","ffA10GrantSave","ff76SaveApproval"],"styleOnly":true},"report_preview_controls":{"screen":"reports","keys":["ff76DlgDownload","ff76DlgShare","ff76DlgClose"],"styleOnly":true},"message_template_controls":{"screen":"messages","keys":["ffA11Priority","ffA11Route","ffA11Template","ffA11TemplateName","ffA11TemplateSave","ffA11TemplateDelete","ffA11Preview","ffA11GrantUser","ffA11GrantRole","ffA11GrantBranch","ffA11GrantSave","ffA11GrantRefresh","ffA11Audit"],"styleOnly":true},"order_customer_modal":{"screen":"orders","keys":["ffCustomerEditSave","ffCustomerEditCancel"],"styleOnly":true},"order_picker_modal":{"screen":"orders","keys":["ffUnifiedMenuReview","ffUnifiedMenuUndo","ffUnifiedMenuClose"],"styleOnly":true}},"dyn":{"order_toggle_reject":"button[data-toggle-reject]","order_open_addition":"button[data-open-addition]","order_late_addition":"button[data-ff52-late]","order_cancel_addition":"button[data-cancel-addition]","order_invoice_addition":"button[data-invoice-addition]","order_invoice_late":"button[data-ff52-invoice]","driver_accept_addition":"button[data-ff52-accept]","driver_reject_addition":"button[data-ff52-reject]","driver_pickup_addition":"button[data-ff52-pickup]","cashier_receive":"button[data-ff49-receive]","cashier_invoice":"button[data-ff49-invoice]","cashier_burger":"button[data-ff-burger-notify]","cashier_invoice_addition":"button[data-invoice-addition]","cashier_invoice_late":"button[data-ff52-invoice]","assembly_filter_all":"button[data-assembly-filter=\"all\"]","assembly_filter_printed":"button[data-assembly-filter=\"printed\"]","assembly_filter_preparing":"button[data-assembly-filter=\"preparing\"]","assembly_filter_ready":"button[data-assembly-filter=\"ready\"]","assembly_filter_late":"button[data-assembly-filter=\"late\"]","assembly_filter_priority":"button[data-assembly-filter=\"priority\"]","burger_filter_all":"button[data-ff-burger-filter=\"all\"]","burger_filter_sent":"button[data-ff-burger-filter=\"sent\"]","burger_filter_preparing":"button[data-ff-burger-filter=\"preparing\"]","burger_filter_late":"button[data-ff-burger-filter=\"late\"]","burger_order_timer":"[data-ff-burger-start]","staff_toggle":"button[data-staff-toggle]","staff_assembly_save":"button[data-assembly-save]","staff_assembly_convert":"button[data-assembly-convert]","staff_edit":"button[data-ffedit]","staff_save_access":"button[data-save-access]","staff_permission_save":"button[data-permission-save]","message_ack":"button[data-ff39-ack]","message_read":"button[data-ff39-read]","case_open":"button[data-ff41-open]","settlement_select":"button[data-ff42-select]","qa_case_save":"button[data-ff47-save]","reservation_next":"button[data-ff49-reserve-next]","reservation_cancel":"button[data-ff49-reserve-cancel]","transfer_confirm":"button[data-ff49-confirm-transfer]","change_approve":"button[data-ff50-approve]","change_reject":"button[data-ff50-reject]","change_service":"button[data-ff50-service]","change_pos":"button[data-ff50-pos]","catalog_item_edit":"button[data-ff51-item-edit]","catalog_item_toggle":"button[data-ff51-item-toggle]","catalog_offer_edit":"button[data-ff51-offer-edit]","catalog_offer_toggle":"button[data-ff51-offer-toggle]","customer_open":"button[data-ff51-customer]","route_edit":"button[data-ff52-route-edit]","lifecycle_action":"button[data-ff60-action]","watch_tab":"button[data-ff5-tab]","watch_find":"button[data-ff5-find]"},"roots":{"order_repeat_addition":"#staffOrders","driver_addition_actions":"#driverTasks","cashier_repeat_actions":"#cashierOrders","assembly_filters":"#ffV12AssemblyWorkspace","burger_filters":"#ffBurgerKitchenWorkspace","burger_timer":"#ffBurgerKitchenWorkspace","staff_repeat_actions":"#staffAdminCard","message_repeat_actions":"#ff39Panel","case_repeat_actions":"#ff41Panel","finance_repeat_actions":"#ff42Panel","system_repeat_actions":"#ff47QAPanel","reservation_repeat_actions":"#ff49ReservationsPanel","order_transfer_repeat":"#ff49TransferPanel","order_changes_repeat":"#ff50ChangesPanel","catalog_repeat_actions":"#ff51CatalogPanel","customer_repeat_actions":"#ff51CustomersPanel","driver_route_repeat":"#ff52RoutesPanel","dashboard_lifecycle_repeat":"#ff60-panel","dashboard_watch_repeat":"#ff5-modal","report_more_controls":"#ff76Center","report_preview_controls":"#ff76PdfDialog","message_template_controls":"#ff39Panel","order_customer_modal":"#ffCustomerEditDialog","order_picker_modal":"#ffUnifiedMenuDialog"}}'''))
   result=page.evaluate("""()=>({count:window.__step03DynamicNodes.length,bad:window.__step03DynamicNodes.filter(o=>!o.node.isConnected||ffA07Elements.visualTarget(o.node).dataset.ffA07ElAlign!=='center'||ffA07Elements.visualTarget(o.node).dataset.ffA07Order||o.node.disabled!==o.disabled||o.node.hidden!==o.hidden||o.node.value!==o.value||o.node.onclick!==o.onclick).map(o=>o.key)})""")
   assert result["count"]>=40 and not result["bad"],result
   page.evaluate("""async()=>{window.__a07Rows={};await ffDashboardStudio.sync(true);ffA07Design.refresh()}""")
   assert page.evaluate("""()=>window.__step03DynamicNodes.every(o=>!ffA07Elements.visualTarget(o.node).dataset.ffA07ElAlign)""")
   page.evaluate("""()=>window.__step03Inserted.forEach(n=>n.remove())""")
   page.evaluate("""async({spec,dyn,roots})=>{const rows={};window.__extraControls=[];for(const [g,c] of Object.entries(spec)){if(g.startsWith('assembly_burger')||g==='cashier_reward_redeem')continue;rows[c.screen]??={id:905,pack:'D01',style_config:{elements:{}}};rows[c.screen].style_config.elements[g]=c.keys.map(key=>({key,shape:'round',size:'large',align:'center'}));const root=document.querySelector(roots[g]);if(!root)continue;for(const key of c.keys){const ns=dyn[key]?[...root.querySelectorAll(dyn[key])]:[document.getElementById(key)].filter(n=>n&&root.contains(n));for(const node of ns)window.__extraControls.push({key,node,disabled:node.disabled,hidden:node.hidden,value:node.value,onclick:node.onclick});}}window.__a07Rows=rows;await ffDashboardStudio.sync(true);ffA07Design.refresh()}""",json.loads(r'''{"spec":{"system_recovery_controls":{"screen":"system","keys":["ffA12Scope","ffA12Branch","ffA12Type","ffA12From","ffA12To","ffA12Preview","ffA12Confirm","ffA12Execute","ffA12List","ffA12Batch","ffA12RestoreConfirm","ffA12Restore","ffA12FixtureType","ffA12FixtureDate","ffA12FixtureConfirm","ffA12Fixture"],"styleOnly":true},"messages_grant_limits":{"screen":"messages","keys":["ffA11GrantPriority","ffA11GrantHours"],"styleOnly":true},"reports_presets_and_approval":{"screen":"reports","keys":["ff76PresetName","ff76PresetList","ffA10GrantUser","ffA10GrantSection","ffA10GrantAllowed","ff76ManagerName","ff76ManagerNotes"],"styleOnly":true},"report_rating_escalate":{"screen":"reports","keys":["ffA10RatingEscalate"],"styleOnly":true},"order_customer_edit_fields":{"screen":"orders","keys":["order_edit_name","order_edit_phone","order_edit_area","order_edit_address","order_edit_reason","order_edit_customer_note"],"styleOnly":true},"order_picker_search":{"screen":"orders","keys":["ffUnifiedMenuSearch"],"styleOnly":true},"case_alert_controls":{"screen":"cases","keys":["ffCaseAlertClose","ffCaseAlertRefresh"],"styleOnly":true},"archive_completed_controls":{"screen":"archive","keys":["fflCashierFinishedToggle","fflFinishedFrom","fflFinishedTo","fflFinishedBranch","fflFinishedToday","fflFinishedApply","fflFinishedSearch","fflFinishedRefresh","fflFinishedMore"],"styleOnly":true},"archive_completed_detail":{"screen":"archive","keys":["ffCompletedDetailClose"],"styleOnly":true},"dashboard_operational_day":{"screen":"dashboard","keys":["ffF01Date","ffF01Compare","ffF01Branch","ffF01Today","ffF01Refresh"],"styleOnly":true},"reports_history_period":{"screen":"reports","keys":["ffHistoryFrom","ffHistoryTo","ffHistoryToday","ffHistoryApply"],"styleOnly":true},"finance_range_controls":{"screen":"finance","keys":["ff42RangeFrom","ff42RangeTo","ff42RangeApply"],"styleOnly":true},"order_reward_issue":{"screen":"orders","keys":["ffRewardItemSearch","ffRewardIssue","ffRewardCodesRefresh","reward_issue_kind","reward_issue_name","reward_issue_phone","reward_issue_expiry"],"styleOnly":true},"order_reward_redeem_start":{"screen":"orders","keys":["ffRewardServiceCode","ffRewardServiceApply"],"styleOnly":true},"cashier_reward_start":{"screen":"cashier","keys":["ffRewardCashierCode","ffRewardCashierApply"],"styleOnly":true},"order_reward_redeem":{"screen":"orders","keys":["ffRewardRedeemButton","ffRewardRedeemClose","reward_redeem_branch","reward_redeem_channel","reward_redeem_area","reward_redeem_fee","reward_redeem_notes","reward_redeem_verify"],"styleOnly":true},"cashier_reward_redeem":{"screen":"cashier","keys":["ffRewardRedeemButton","ffRewardRedeemClose","reward_redeem_branch","reward_redeem_channel","reward_redeem_area","reward_redeem_fee","reward_redeem_notes","reward_redeem_verify"],"styleOnly":true},"cashier_burger_send":{"screen":"cashier","keys":["ffBurgerPanelToggle","ffBurgerNew","ffBurgerCollapse"],"styleOnly":true},"cashier_burger_send_fields":{"screen":"cashier","keys":["ffBurgerSubmit","ffBurgerCancel","burger_send_branch","burger_send_kind","burger_send_order","burger_send_invoice","burger_send_notes"],"styleOnly":true},"assembly_burger_send":{"screen":"assembly","keys":["ffBurgerPanelToggle","ffBurgerNew","ffBurgerCollapse"],"styleOnly":true},"assembly_burger_send_fields":{"screen":"assembly","keys":["ffBurgerSubmit","ffBurgerCancel","burger_send_branch","burger_send_kind","burger_send_order","burger_send_invoice","burger_send_notes"],"styleOnly":true}},"dyn":{"order_edit_name":"#ffCustomerEditDialog [name=\"name\"]","order_edit_phone":"#ffCustomerEditDialog [name=\"phone\"]","order_edit_area":"#ffCustomerEditDialog [name=\"area\"]","order_edit_address":"#ffCustomerEditDialog [name=\"address\"]","order_edit_reason":"#ffCustomerEditDialog [name=\"reason\"]","order_edit_customer_note":"#ffCustomerEditDialog [name=\"customer_note\"]","reward_issue_kind":"#ffRewardManager [name=\"kind\"]","reward_issue_name":"#ffRewardManager [name=\"name\"]","reward_issue_phone":"#ffRewardManager [name=\"phone\"]","reward_issue_expiry":"#ffRewardManager [name=\"expiry\"]","reward_redeem_branch":"#ffRewardRedeemDialog [name=\"branch\"]","reward_redeem_channel":"#ffRewardRedeemDialog [name=\"channel\"]","reward_redeem_area":"#ffRewardRedeemDialog [name=\"area\"]","reward_redeem_fee":"#ffRewardRedeemDialog [name=\"fee\"]","reward_redeem_notes":"#ffRewardRedeemDialog [name=\"notes\"]","reward_redeem_verify":"#ffRewardRedeemDialog [name=\"verify\"]","burger_send_branch":"#ffBurgerDialog [name=\"branch\"]","burger_send_kind":"#ffBurgerDialog [name=\"kind\"]","burger_send_order":"#ffBurgerDialog [name=\"order\"]","burger_send_invoice":"#ffBurgerDialog [name=\"invoice\"]","burger_send_notes":"#ffBurgerDialog [name=\"notes\"]"},"roots":{"system_recovery_controls":"#ffA12Recovery","messages_grant_limits":"#ff39Panel","reports_presets_and_approval":"#ff76Center","report_rating_escalate":"#ff76Center","order_customer_edit_fields":"#ffCustomerEditDialog","order_picker_search":"#ffUnifiedMenuDialog","case_alert_controls":"#ffCaseAlertDialog","archive_completed_controls":"#fflCashierFinished","archive_completed_detail":"#ffCompletedDetailDialog","dashboard_operational_day":"#ffF01Panel","reports_history_period":"#ffHistoryPeriod","finance_range_controls":"#ff42RangeReport","order_reward_issue":"#ffRewardManager","order_reward_redeem_start":"#ffRewardService","cashier_reward_start":"#ffRewardCashier","order_reward_redeem":"#ffRewardRedeemDialog","cashier_reward_redeem":"#ffRewardRedeemDialog","cashier_burger_send":"#ffBurgerCashierPanel","cashier_burger_send_fields":"#ffBurgerDialog","assembly_burger_send":"#ffBurgerCashierPanel","assembly_burger_send_fields":"#ffBurgerDialog"}}'''))
   extra=page.evaluate("""()=>({count:window.__extraControls.length,bad:window.__extraControls.filter(o=>!o.node.isConnected||ffA07Elements.visualTarget(o.node).dataset.ffA07ElAlign!=='center'||o.node.disabled!==o.disabled||o.node.hidden!==o.hidden||o.node.value!==o.value||o.node.onclick!==o.onclick).map(o=>o.key)})""")
   assert extra["count"]>=45 and not extra["bad"],extra
   page.evaluate("""async()=>{window.__a07Rows={};await ffDashboardStudio.sync(true);ffA07Design.refresh()}""")
   assert page.evaluate("()=>window.__extraControls.every(o=>!ffA07Elements.visualTarget(o.node).dataset.ffA07ElAlign)")
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
   assert dlg.locator('[data-step03-compare-results] table').count()==2
   assert dlg.locator('[data-step03-compare-results] table').first.get_by_text('المسودة',exact=True).count()==1
   assert dlg.locator('[data-step03-compare-results] table').first.locator('tbody tr').first.locator('td').all_text_contents()==['إجراءات الموصل / تسجيل الحضور / الخط','Tahoma','#17','Cairo','المسودة'] or dlg.locator('[data-step03-compare-results] table').first.locator('tbody tr').first.locator('td').all_text_contents()[1:]==['Tahoma','#17','Cairo','المسودة']
   assert dlg.locator('[data-step03-compare-results] table').nth(1).locator('tbody tr').first.locator('td').all_text_contents()[1:]==['Tahoma','#17','Tahoma','#17']
   dlg.locator('[data-scope-target="0-device"]').select_option('desktop')
   assert dlg.locator('[data-step03-compare-results]').locator(':scope > section').count()==0
   assert 'تغيّرت' in dlg.locator('[data-step03-compare-status]').inner_text()
   dlg.locator('[data-scope-target="0-device"]').select_option('mobile')
   dlg.locator('[data-step03-compare]').click()
   page.wait_for_function("()=>document.querySelector('[data-step03-compare-results]').children.length===2")
   dlg.locator('select[name=pack]').select_option('D09')
   assert dlg.locator('[data-step03-compare-results]').locator(':scope > section').count()==0
   # Exercise the published-source RPC path; do not race the debounced loader
   # by manually writing the editor's source state.
   page.evaluate("""()=>{const original=rpc;rpc=async(name,args={})=>{if(name==='ff_a07_manager_source'&&args.p_screen==='driver'&&args.p_device==='mobile')return [{id:17,pack:'D01',screen_scope:'driver',role_scope:'driver',device:'mobile',bar:'labels'}];if(name==='ff_a07_manager_style_layers'&&args.p_screen==='driver'&&args.p_device==='mobile')return {style:{elements:{driver_actions:[{key:'clockInBtn',font:'cairo'}]}},sources:{'elements.driver_actions.clockInBtn.font':17}};return original(name,args)}}""")
   dlg.locator('select[name=device]').select_option('desktop')
   dlg.locator('select[name=device]').select_option('mobile')
   source=dlg.locator('[data-step03-element-source="driver_actions|clockInBtn"]')
   page.wait_for_function("""()=>document.querySelector('[data-step03-element-source="driver_actions|clockInBtn"]')?.textContent.includes('#17')""")
   assert 'Cairo' in source.text_content() and '#17' in source.text_content()
   dlg.locator('select[name=device]').select_option('desktop')
   assert '#17' not in source.text_content()
   print('PASS STEP03 per-element source and invalidation of stale scope comparison',flush=True)
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
  page.evaluate("()=>{user=null;data=null;window.dispatchEvent(new Event('ff-luxe-session-reset'))}")
  assert page.locator(selector).get_attribute("data-ff-a07-pack") is None
  page.evaluate("()=>ffDashboardStudio.sync(true)")
  assert page.locator(selector).get_attribute("data-ff-a07-pack") is None
  print("PASS A07",role,47,"role/width/pack checks",flush=True)
  collect_visual(page);ctx.close()
 ctx=browser.new_context(viewport={"width":390,"height":850},service_workers="block",reduced_motion="reduce")
 ctx.route("**/*",lambda route:route.continue_() if route.request.url.startswith(origin) else route.abort())
 ctx.add_init_script(path=root/'scripts/step03-visual-matrix-probe.js');page=ctx.new_page();page.goto(origin,wait_until="load")
 page.wait_for_function("()=>!!window.ffA07Design")
 page.evaluate("""async()=>{client={};user=null;data=null;document.body.dataset.access='locked';document.getElementById('loginOverlay').classList.remove('hidden');rpc=async(name,args)=>name==='ff_a07_public_appearance'?{pack:'D05',layout_text:'PUBLIC QA',style_config:{logoAsset:'mark'}}:null;await ffA07Design.syncPublic(true)}""")
 assert page.locator("#loginOverlay .loginbox").get_attribute("data-ff-a07-pack")=="D05"
 assert page.locator("#loginOverlay .loginbox").get_by_text("PUBLIC QA").count()==1
 assert page.locator("#password").get_attribute("type")=="password"
 page.evaluate("""async()=>{document.body.dataset.access='customer';await ffA07Design.syncPublic(true)}""")
 assert page.locator("#loginOverlay .loginbox").get_attribute("data-ff-a07-pack") is None
 assert page.locator("#ff28Portal").get_attribute("data-ff-a07-pack")=="D05"

 # Public scopes: actual existing login, join and customer portal controls, all
 # registered entries, no backend writes. Test independently at both breakpoints.
 page.evaluate("""()=>{window.__step03PublicRows={};window.__step03PublicCalls=[];rpc=async(name,args={})=>{window.__step03PublicCalls.push({name,args});return name==='ff_a07_public_appearance'?window.__step03PublicRows[args.p_screen+'|'+args.p_device]||null:null}}""")
 public_results=[]
 for public_screen,access in (("login","locked"),("customer_portal","customer")):
  for width in (390,1440):
   page.set_viewport_size({"width":width,"height":850})
   audit=page.evaluate("""async({screen,access})=>{
    const device=innerWidth<=850?'mobile':'desktop',defs=ffA07Elements.groups;
    const dyn={join_name:'full_name',join_email:'email',join_phone:'phone',join_qualification:'qualification',join_address:'address',join_age:'age_years',join_marital:'marital_status',join_role:'requested_role',join_experience:'experience_years',join_message:'applicant_message'};
    const entries=Object.entries(defs).filter(([g,c])=>c.screen===screen);
    const keys=entries.flatMap(([g,c])=>c.keys);
    const original=keys.map(key=>{
     const n=dyn[key]?document.querySelector('#ff61ApplyForm [name="'+dyn[key]+'"]'):document.getElementById(key);
     if(!n)return {key};
     return {key,n,target:ffA07Elements.visualTarget(n),value:n.value,type:n.type,required:n.required,disabled:n.disabled,checked:n.checked,hidden:n.hidden,handler:n.onclick,role:n.getAttribute('role'),name:n.getAttribute('name')};
    });
    document.body.dataset.access=access;
    window.__step03PublicRows={[screen+'|'+device]:{id:990,pack:'D05',style_config:{elements:Object.fromEntries(entries.map(([g,c])=>[g,c.keys.map(key=>({key,shape:'round',size:'normal',align:'center',font:'tahoma',weight:'strong',spacing:'wide',spaceBlock:'wide',outerGap:'wide',border:'strong',shadow:'soft',textScale:'large'}))]))}}};
    await ffA07Design.syncPublic(true);
    const missing=original.filter(o=>!o.n).map(o=>o.key),bad=[];
    for(const o of original.filter(o=>o.n)){
     const n=o.n,t=ffA07Elements.visualTarget(n),s=getComputedStyle(t);
     const why=[];
     if(t!==o.target||!n.isConnected||n.value!==o.value||n.type!==o.type||n.required!==o.required||n.disabled!==o.disabled||n.checked!==o.checked||n.hidden!==o.hidden||n.onclick!==o.handler||n.getAttribute('role')!==o.role||n.getAttribute('name')!==o.name)why.push('native state');
     if(t.dataset.ffA07ElAlign!=='center'||s.textAlign!=='center')why.push('align');
     if(t.dataset.ffA07ElFont!=='tahoma'||!s.fontFamily.toLowerCase().includes('tahoma'))why.push('font');
     if(t.dataset.ffA07ElSpacing!=='wide'||parseFloat(s.paddingInlineStart)!==18)why.push('spacing');
     if(t.dataset.ffA07ElOuterGap!=='wide'||parseFloat(s.marginBlockStart)!==8)why.push('outer gap');
     if(t.dataset.ffA07ElSpaceBlock!=='wide'||parseFloat(s.paddingBlockStart)!==12)why.push('block spacing');
     if(t.dataset.ffA07ElWeight!=='strong'||Number(s.fontWeight)<700)why.push('weight');
     if(t.dataset.ffA07ElShadow!=='soft'||s.boxShadow==='none')why.push('shadow');
     if(t.dataset.ffA07ElTextScale!=='large'||t.dataset.ffA07ElBorder!=='strong'||t.dataset.ffA07Shape!=='round')why.push('property binding');
     if(s.borderTopStyle!=='solid'||parseFloat(s.borderTopWidth)!==3)why.push('border');
     if(why.length)bad.push({key:o.key,why});
    }
    window.step03Probe('public-'+screen,{[screen]:window.__step03PublicRows[screen+'|'+device]},Object.fromEntries(Object.entries(dyn).map(([k,v])=>[k,'#ff61ApplyForm [name="'+v+'"]'])));
    const other=screen==='login'?'customer_portal':'login';
    const isolation=[...document.querySelectorAll('[data-ff-a07-screen="'+other+'"] [data-ff-a07-el-align]')].length===0;
    window.__step03PublicRows={};await ffA07Design.syncPublic(true);
    const cleanup=original.filter(o=>o.n).every(o=>!o.target.dataset.ffA07ElAlign&&!o.target.dataset.ffA07ElFont&&!o.target.dataset.ffA07Shape);
    return {screen,device,count:keys.length,missing,bad,isolation,cleanup};
   }""",{"screen":public_screen,"access":access})
   public_results.append(audit)
   assert not audit["missing"] and not audit["bad"] and audit["isolation"] and audit["cleanup"],audit
 (out/"step03-public-property-audit.json").write_text(json.dumps(public_results,ensure_ascii=False,indent=2))
 print("PASS STEP03 public mounted properties",sum(x["count"] for x in public_results),flush=True)
 # A slow mobile response cannot be applied after resizing to desktop.
 page.set_viewport_size({"width":390,"height":850})
 page.evaluate("""async()=>{document.body.dataset.access='locked';window.__step03PublicRows={};await ffA07Design.syncPublic(true);window.__step03SlowResolve=null;rpc=async(name,args={})=>{if(name!=='ff_a07_public_appearance')return null;if(args.p_device==='mobile')return new Promise(r=>window.__step03SlowResolve=r);return {id:991,pack:'D08',style_config:{}}};window.__step03Slow=ffA07Design.syncPublic(true)}""")
 page.wait_for_function("()=>!!window.__step03SlowResolve")
 page.set_viewport_size({"width":1440,"height":850})
 page.evaluate("""async()=>{window.__step03SlowResolve({id:992,pack:'D05',style_config:{}});await window.__step03Slow;await ffA07Design.syncPublic(true)}""")
 assert page.locator("#loginOverlay .loginbox").get_attribute("data-ff-a07-pack")=="D08"
 print("PASS STEP03 stale public mobile response rejected after resize",flush=True)

 collect_visual(page);ctx.close()

 # Separate manager session for data-dependent admin controls. Only original
 # renderer functions and read-only in-memory fixture responses are used.
 ctx=browser.new_context(viewport={"width":390 if alternate else 1440,"height":850},service_workers="block",reduced_motion="reduce")
 ctx.route("**/*",lambda route:route.continue_() if route.request.url.startswith(origin) else route.abort())
 ctx.add_init_script(path=root/'scripts/step03-visual-matrix-probe.js');page=ctx.new_page();page.goto(origin,wait_until="load");page.evaluate(fixture,"manager")
 page.wait_for_function("()=>!!window.ffA07Design&&!!window.ffDashboardStudio")
 admin=page.evaluate(r"""async()=>{
  const stamp=new Date().toISOString(),caseRow={id:'qa-case',subject:'QA',description:'QA',status:'open',kind:'customer_complaint',priority:'normal',branch_id:'b1',created_at:stamp};
  const baseRPC=rpc;
  rpc=async(name,args={})=>{
   const values={
    ff41_case_detail:{item:caseRow,events:[]},
    ff51_manager_catalog:{categories:[{id:'qa-cat',name:'QA'}],items:[{id:'qa-item',category_id:'qa-cat',name:'QA item',price:1000,active:true,parser_aliases:[]}],offers:[{id:'qa-offer',name:'QA offer',price:1000,active:true,items:[]}]},
    ff51_customer_directory:[{name:'QA',phone:'000000000',area:'QA',last_order_at:stamp,orders_count:1,notes_count:0}],
    ff52_admin_route_list:[{id:'qa-route',driver_name:'QA',driver_id:'qa-driver',branch_id:'b1',active:true,area_terms:['QA'],start_local:'09:00',end_local:'10:00'}],
    ff38_admin_staff_list:[{user_id:'qa-assembly',role:'assembly',name:'QA assembly',active:true,branches:['b1']},{user_id:'qa-cashier',role:'cashier',name:'QA cashier',active:true,branches:['b1']}],
    ff38_admin_permission_matrix:[{key:'create_order',default_allowed:false,effective:false,override:null}],
    ff38_admin_permission_audit:[],
    ff49_reservations_list:[{id:'qa-reservation',status:'new',customer_name:'QA',customer_phone:'000000000',branch_id:'b1',pickup_unspecified:true,items:[]}],
    ff49_visible_transfers:[{id:'qa-transfer',order_id:'qa-order',original_driver_id:'qa-a',new_driver_id:'qa-b',reason:'QA'}],
    ff50_visible_order_changes:['requested','approved','service_confirmed'].map((status,i)=>({id:'qa-change-'+i,order_id:'qa-order',status,reason:'QA',requested_at:stamp,old_items:[],new_items:[]}))
   };
   return Object.hasOwn(values,name)?values[name]:baseRPC(name,args);
  };
  for(const id of ['ff41Panel','ff51CatalogPanel','ff51CustomersPanel','ff52RoutesPanel','ff49ReservationsPanel','ff49TransferPanel','ff50ChangesPanel','ff39Panel','ff42Panel','ff47QAPanel','staffAdminCard'])document.getElementById(id)?.classList.remove('hidden');
  ff41Cases=[caseRow];await ff41ShowDetail(caseRow.id);
  await ff51LoadCatalog();await ff51LoadCustomers();await ff52LoadRoutes();
  await loadStaffAdmin();
  const select=document.getElementById('permissionEmployee');if(![...select.options].some(o=>o.value==='qa-cashier'))select.add(new Option('QA','qa-cashier'));select.value='qa-cashier';await ffLoadPermissions();
  ff39Mailbox=[{id:'qa-msg1',title:'QA',body:'QA',created_at:stamp,requires_ack:true},{id:'qa-msg2',title:'QA',body:'QA',created_at:stamp,requires_ack:false}];ff39DrawInbox();
  ff42Rows=[{driver_id:'qa-driver',driver_name:'QA',branch_id:'b1',branch_name:'QA',delivered_orders:1,delivered_order_value:1000,settlement_id:'qa-settlement',settlement_status:'closed',cash_received:1000,delivered_delivery_fees:500}];ff42Selected=0;ff42Render();await ffA10FeeEvidence(ff42Rows[0]);
  ff47Detail={run:{state:'open'},cases:[{key:'qa-case',title:'QA',category:'QA',priority:'normal',expected:'QA',state:'pending',notes:''}]};document.getElementById('ff47Category').value='';document.getElementById('ff47Filter').value='';ff47RenderCases();
  await ff49RefreshReservations();await ff49LoadTransfers();await ff50Refresh();
  ffA07Design.refresh();
  const selectors={ff41NextStatus:'#ff41NextStatus',ff41Resolution:'#ff41Resolution',ff41CommentBody:'#ff41CommentBody',case_transition:'button[data-ff41-transition]',case_comment:'button[data-ff41-comment]',case_open:'button[data-ff41-open]',staff_toggle:'button[data-staff-toggle]',staff_assembly_save:'button[data-assembly-save]',staff_assembly_convert:'button[data-assembly-convert]',staff_edit:'button[data-ffedit]',staff_save_access:'button[data-save-access]',staff_permission_save:'button[data-permission-save]',message_ack:'button[data-ff39-ack]',message_read:'button[data-ff39-read]',settlement_select:'button[data-ff42-select]',qa_case_save:'button[data-ff47-save]',reservation_next:'button[data-ff49-reserve-next]',reservation_cancel:'button[data-ff49-reserve-cancel]',transfer_confirm:'button[data-ff49-confirm-transfer]',change_approve:'button[data-ff50-approve]',change_reject:'button[data-ff50-reject]',change_service:'button[data-ff50-service]',change_pos:'button[data-ff50-pos]',catalog_item_edit:'button[data-ff51-item-edit]',catalog_item_toggle:'button[data-ff51-item-toggle]',catalog_offer_edit:'button[data-ff51-offer-edit]',catalog_offer_toggle:'button[data-ff51-offer-toggle]',customer_open:'button[data-ff51-customer]',route_edit:'button[data-ff52-route-edit]'};
  Object.assign(selectors,{"staff_assembly_branch":"select[data-assembly-branch]","staff_assembly_target":"select[data-assembly-target]","staff_access_role":"select[data-access-role]","staff_access_branch":"input[data-access-branch]","staff_permission_value":"select[data-permission-key]","system_qa_result":"select[id^=\"ff47State_\"]","system_qa_note":"textarea[id^=\"ff47Notes_\"]","finance_fee_amount":"#ffA10FeeEvidence input[data-fee]","finance_fee_reference":"#ffA10FeeEvidence textarea[data-note]","finance_fee_save":"#ffA10FeeEvidence button[data-save]","finance_fee_status":"#ffA10FeeEvidence [data-status]","finance_fee_history":"#ffA10FeeEvidence [data-history]","dashboard_order_follow":"button[data-ffx-order]","system_theme_choice":"#ffx-themes button[data-ffx-theme]"});
  const rows={},records=[];
  for(const [g,c] of Object.entries(ffA07Elements.groups)){
   if(!c.keys.some(k=>Object.hasOwn(selectors,k)))continue;
   rows[c.screen]??={id:993,pack:'D05',style_config:{elements:{}}};
   rows[c.screen].style_config.elements[g]=c.keys.map(key=>({key,shape:'round',size:'normal',align:'center',font:'tahoma',weight:'strong',spacing:'wide',spaceBlock:'wide',outerGap:'wide',border:'strong',shadow:'soft',textScale:'large'}));
   for(const key of c.keys.filter(k=>Object.hasOwn(selectors,k))){
    const all=[...document.querySelectorAll(selectors[key])],ns=all.filter(n=>n.closest('[data-ff-a07-screen]')?.dataset.ffA07Screen===c.screen);
    records.push({key,screen:c.screen,unscoped:all.length-ns.length,nodes:ns.map(n=>({n,value:n.value,type:n.type,hidden:n.hidden,disabled:n.disabled,handler:n.onclick,html:n.outerHTML}))});
   }
  }
  window.__a07Rows=rows;await ffDashboardStudio.sync(true);ffA07Design.refresh();
  const missing=records.filter(r=>!r.nodes.length).map(r=>({key:r.key,unscoped:r.unscoped})),bad=[];
  for(const r of records)for(const o of r.nodes){
   const n=o.n,t=ffA07Elements.visualTarget(n),s=getComputedStyle(t),why=[];
   if(!n.isConnected||n.value!==o.value||n.type!==o.type||n.hidden!==o.hidden||n.disabled!==o.disabled||n.onclick!==o.handler)why.push('state');
   if(t.dataset.ffA07ElAlign!=='center'||s.textAlign!=='center')why.push('align');
   if(!s.fontFamily.toLowerCase().includes('tahoma'))why.push('font');
   if(parseFloat(s.paddingInlineStart)!==18||parseFloat(s.paddingBlockStart)!==12||parseFloat(s.marginBlockStart)!==8)why.push('spacing');
   if(Number(s.fontWeight)<700||s.boxShadow==='none')why.push('weight/shadow');
   if(s.borderTopStyle!=='solid'||parseFloat(s.borderTopWidth)!==3)why.push('border');
   if(why.length)bad.push({key:r.key,why});
  }
  window.step03Probe('admin-renderers',rows,selectors);
  window.__a07Rows={};await ffDashboardStudio.sync(true);ffA07Design.refresh();
  const cleanup=records.every(r=>r.nodes.every(o=>!ffA07Elements.visualTarget(o.n).dataset.ffA07ElAlign&&!ffA07Elements.visualTarget(o.n).dataset.ffA07ElFont));
  return {count:records.length,missing,bad,cleanup,matched:records.map(r=>({key:r.key,screen:r.screen,nodes:r.nodes.length,unscoped:r.unscoped}))};
 }""")
 (out/"step03-real-admin-renderers.json").write_text(json.dumps(admin,ensure_ascii=False,indent=2))
 assert not admin["missing"] and not admin["bad"] and admin["cleanup"],admin
 print("PASS STEP03 actual administrative renderers",admin["count"],flush=True)
 collect_visual(page);ctx.close()

 # Remaining actual dynamic dialogs and lifecycle fields: exercise only original renderers;
 # opening, typing and skipping are local, and every RPC remains intercepted.
 for role in ("manager","cashier","driver"):
  ctx=browser.new_context(viewport={"width":390,"height":850},service_workers="block",reduced_motion="reduce")
  ctx.route("**/*",lambda route:route.continue_() if route.request.url.startswith(origin) else route.abort())
  ctx.add_init_script(path=root/'scripts/step03-visual-matrix-probe.js');page=ctx.new_page();page.goto(origin,wait_until="load");page.evaluate(fixture,role)
  page.wait_for_function("()=>!!window.ffA07Design&&!!window.ffDashboardStudio")
  if alternate: page.set_viewport_size({"width":1440,"height":850})
  extra=page.evaluate(r"""async({role,dyn})=>{
   const base=rpc,stamp=new Date().toISOString(),writes=[];
   const mk=(id,num,extra={})=>({id,number:num,order_number:num,branch_id:'b1',driver_id:'qa-driver',driver_name:'QA',phase:'assigned',status:'sent',cashier_stage:'waiting',created_at:stamp,customer_name:'QA',phone:'000',area:'QA',items:[{qty:1,name:'QA item',price:1000}],...extra});
   const queue=[mk('qa-invoice',101,{cashier_received:true}),mk('qa-reoffer',102,{driver_id:null,phase:null}),mk('qa-offer',103,{driver_id:null,phase:null,offer_id:'qa-offer-id',offer_expires_at:new Date(Date.now()+300000).toISOString()})];
   rpc=async(name,args={})=>{
    if(name==='ff60_health')return {stage:6};
    if(name==='ff60_operational_queue')return queue;
    if(name==='ff60_read_policy')return {fast_seconds:180,slow_seconds:600};
    if(name==='ff_a10_reporting_center')return {from:args.p_from,to:args.p_to,role:'manager',scope:'QA',access_key:'qa',generated_at:stamp,available_sections:['ratings'],branches:[{id:'b1',name:'القاهرة'}],driver_options:[],filter_options:{},totals:{orders:1,rating_avg:2,low_ratings:1},internal_low_ratings:[{rating_id:'qa-rating',order_number:108,rater_role:'cashier',stars:2,note:'QA'}]};
    if(name==='ff_luxe_cashier_cancel_alerts')return [{order_id:'qa-cancel',number:104,invoice_ref:'QA',cancel_reason:'QA',items:[]}];
    if(name==='ff_a10_driver_rating_queue')return [{order_id:'qa-done',order_number:105}];
    if(['ff_luxe_ack_cancel','ff49_cashier_invoice','ff_luxe_driver_grievance','ff_luxe_driver_rate_order','ff_luxe_rate_driver_cs','ff_luxe_rate_driver_cashier','ff38_cashier_set_stage','ff_a10_escalate_rating'].includes(name))writes.push(name);
    return base(name,args);
   };
   const tick=()=>new Promise(r=>setTimeout(r,50));
   async function wait(sel){for(let i=0;i<40;i++){const n=document.querySelector(sel);if(n)return n;await tick()}throw Error('real renderer missing '+sel)}
   const checks=[];
   async function audit(screen,keys){
    ffA07Design.refresh();
    const selected=Object.fromEntries(Object.entries(ffA07Elements.groups).filter(([g,c])=>c.screen===screen&&c.keys.some(k=>keys.includes(k))).map(([g,c])=>[g,c.keys.map(key=>({key,shape:'round',size:'normal',align:'center',font:'tahoma',weight:'strong',border:'strong',shadow:'soft'}))]));
    const records=keys.map(key=>({key,nodes:[...document.querySelectorAll(dyn[key]||'#'+CSS.escape(key))].filter(n=>n.closest('[data-ff-a07-screen]')?.dataset.ffA07Screen===screen).map(n=>({n,value:n.value,disabled:n.disabled,hidden:n.hidden,onclick:n.onclick,pressed:n.getAttribute('aria-pressed')}))}));
    window.__a07Rows={[screen]:{id:994,pack:'D01',style_config:{elements:selected}}};await ffDashboardStudio.sync(true);ffA07Design.refresh();
    const missing=records.filter(x=>!x.nodes.length).map(x=>x.key),bad=[];
    for(const r of records)for(const o of r.nodes){const n=o.n,t=ffA07Elements.visualTarget(n),s=getComputedStyle(t);if(!n.isConnected||t.dataset.ffA07ElAlign!=='center'||s.textAlign!=='center'||!s.fontFamily.toLowerCase().includes('tahoma')||Number(s.fontWeight)<700||s.borderTopWidth!=='3px'||s.boxShadow==='none'||n.value!==o.value||n.disabled!==o.disabled||n.hidden!==o.hidden||n.onclick!==o.onclick||n.getAttribute('aria-pressed')!==o.pressed)bad.push(r.key)}
    window.step03Probe('remaining-'+role+'-'+keys.join(','),window.__a07Rows,dyn);
    window.__a07Rows={};await ffDashboardStudio.sync(true);ffA07Design.refresh();
    const cleanup=records.every(r=>r.nodes.every(o=>!ffA07Elements.visualTarget(o.n).dataset.ffA07ElAlign));
    checks.push({screen,keys,missing,bad,cleanup});
   }
   if(role==='manager'){
    document.getElementById('ff60-launch').click();await wait(dyn.lifecycle_action);await audit('dashboard',['lifecycle_action']);(await wait('[data-ff60-action="show-invoice"]')).click();
    await wait(dyn.lifecycle_invoice);await audit('dashboard',['lifecycle_invoice','lifecycle_countdown','lifecycle_state']);
    (await wait('[data-ff60-action="show-reoffer"]')).click();await wait(dyn.lifecycle_reoffer_reason);
    await audit('dashboard',['lifecycle_reoffer_driver','lifecycle_reoffer_reason']);
    document.getElementById('ff60-close')?.click();
    data.orders=[mk('qa-watch',108,{driver_id:null,phase:null})];draw();
    document.getElementById('ff5-launch').click();await wait(dyn.watch_tab);await wait(dyn.watch_find);await audit('dashboard',['watch_tab','watch_find']);
    document.getElementById('ff5-close').click();
    window.ff76OpenReports();await wait('#ffA10RatingEscalate');await audit('reports',['ffA10RatingEscalate']);
    if(document.getElementById('ffA10RatingEscalate').value!=='qa-rating')throw Error('report selector value changed');
    document.getElementById('ff76Close').click();
    data.orders=[mk('qa-rate',106)];draw();
    await wait(dyn.orders_rate_driver_open);await audit('orders',['orders_rate_driver_open']);
    const btn=document.querySelector(dyn.orders_rate_driver_open);btn.click();
    await wait(dyn.orders_rate_star);await audit('orders',['orders_rate_star','orders_rate_note','orders_rate_save','orders_rate_skip']);
    document.querySelector(dyn.orders_rate_skip).click();
   }else if(role==='cashier'){
    document.querySelector('#ffx-mobile-nav button[data-key="cashier"]')?.click();
    window.dispatchEvent(new Event('focus'));await wait(dyn.cashier_cancel_ack);
    await audit('cashier',['cashier_cancel_ack','cashier_cancel_banner','cashier_cancel_note']);
    const p=window.ffLuxeStarPrompt('QA');await wait(dyn.cashier_rate_star);
    await audit('cashier',['cashier_rate_star','cashier_rate_note','cashier_rate_save','cashier_rate_skip']);
    document.querySelector(dyn.cashier_rate_skip).click();if(await p!==null)throw Error('skip changed');
   }else{
    data.orders=[mk('qa-appeal',107,{phase:'on_way',cashier_stage:'handed_over'})];draw();
    await wait(dyn.driver_grievance_open);
    document.querySelector('#ffA10DriverFeedback button[data-refresh]').click();await wait(dyn.driver_feedback_open);
    await audit('driver',['driver_feedback_refresh','driver_feedback_open','driver_grievance_open']);
    document.querySelector(dyn.driver_feedback_open).click();await wait(dyn.driver_rating_star);
    await audit('driver',['driver_rating_note','driver_rating_star','driver_rating_submit','driver_rating_close']);
    document.querySelector(dyn.driver_rating_close).click();await tick();
    document.querySelector(dyn.driver_grievance_open).click();await wait(dyn.driver_grievance_kind);
    await audit('driver',['driver_grievance_kind','driver_grievance_details','driver_grievance_save','driver_grievance_close']);
    document.querySelector(dyn.driver_grievance_close).click();
   }
   return {role,checks,writes};
  }""",{"role":role,"dyn":registry["dyn"]})
  (out/f"step03-remaining-renderers-{role}.json").write_text(json.dumps(extra,ensure_ascii=False,indent=2))
  assert not extra["writes"] and all(not c["missing"] and not c["bad"] and c["cleanup"] for c in extra["checks"]),extra
  print("PASS STEP03 remaining original renderers",role,sum(len(c["keys"]) for c in extra["checks"]),flush=True)
  collect_visual(page);ctx.close()

 print("PASS STEP03 independent finance, branch, login and customer scopes",flush=True)
 browser.close()
server.shutdown()
(out/"role-pack-matrix.json").write_text(json.dumps(results,ensure_ascii=False,indent=2))
assert len(results)==7*47
assert len(set(k for x in visual_matrix for k in x['entries']))==662, 'visual matrix registry coverage'
failures=[f for x in visual_matrix for f in x['failures']]
assert not failures, ('STEP03 computed property mismatch',len(failures),failures[:25])
(out/"step05-design-performance-contrast.json").write_text(json.dumps(step05_design_metrics,ensure_ascii=False,indent=2))
assert len(step05_design_metrics)==64,len(step05_design_metrics)
print("PASS STEP05 measured 64 real screen/pack/viewport samples; min actual contrast",round(min(x["actualContrast"] for x in step05_design_metrics),2),"min pack contrast",round(min(x["packContrast"] for x in step05_design_metrics),2),"max sync ms",max(x["render_ms"] for x in step05_design_metrics),flush=True)
print("PASS A07",len(results),"actual role/width/pack checks, gallery and reset",flush=True)
if not alternate:
 subprocess.run([sys.executable,__file__,"--alternate"],check=True)
 second=json.loads((out/"alternate"/"step03-computed-property-matrix.json").read_text())
 widths={}
 for entry in visual_matrix+second:
  for key in entry["entries"]: widths.setdefault(key,set()).add(entry["width"])
 assert len(widths)==662 and all({390,1440}<=v for v in widths.values()), [(k,sorted(v)) for k,v in widths.items() if not {390,1440}<=v]
 states=json.loads((out/"step03-interaction-pseudo-states.json").read_text())+json.loads((out/"alternate"/"step03-interaction-pseudo-states.json").read_text())
 assert len(states)==36 and len({(x["key"],x["width"],x["disabled"]) for x in states})==36
 evidence={"interactive_cases":len(states),"entries":len(widths),"both_widths":sum({390,1440}<=v for v in widths.values()),"computed":sum(x["computed"] for x in visual_matrix+second),"binding_only":sum(x["bindingOnly"] for x in visual_matrix+second),"combined":sum(x.get("combined",0) for x in visual_matrix+second),"failures":sum(len(x["failures"]) for x in visual_matrix+second)}
 (out/"step03-cross-viewport-summary.json").write_text(json.dumps(evidence,indent=2))
 print("PASS STEP03 every registered entry at both widths",evidence,flush=True)
