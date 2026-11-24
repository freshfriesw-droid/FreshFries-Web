"""P0 evidence: actual browser DOM control-to-handler inventory.
No external requests, account credentials, writes, or real customer/order data.
Empty role fixtures expose baseline shell and static controls, not all data-dependent paths.
"""
import json
import subprocess
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[1]
out = root / "a01-evidence"
out.mkdir(exist_ok=True)
server = ThreadingHTTPServer(("127.0.0.1", 0), partial(SimpleHTTPRequestHandler, directory=root))
Thread(target=server.serve_forever, daemon=True).start()
origin = f"http://127.0.0.1:{server.server_port}/"
p0 = json.loads((root / "docs/implementation/A01-p0-inventory-20261124.json").read_text())
route_map = {row["key"]:row for row in p0["routes"]}
permissions = {}
for row in p0["default_permissions"]:
    permissions.setdefault(row["role"], {})[row["permission_key"]] = row["allowed"]
# Keep actual native event dispatch unchanged. Record listener sources as registered,
# including delegated click handlers on ancestor nodes and form submit handlers.
init = """(() => {
  const registrations = new WeakMap(), original = EventTarget.prototype.addEventListener;
  EventTarget.prototype.addEventListener = function(type, fn, options) {
    const result = original.call(this, type, fn, options);
    if (fn && ['click','submit','change','keydown','pointerup'].includes(type)) {
      const rows = registrations.get(this) || [];
      const source = typeof fn === 'function' ? Function.prototype.toString.call(fn) : String(fn.handleEvent || '');
      rows.push({event:type,source:source.slice(0,1600)});
      registrations.set(this, rows);
    }
    return result;
  };
  window.__p0Bindings = el => {
    const rows = [], form = el.form || el.closest('form');
    const seen = new Set();
    const path = n => n === window ? 'window' : n === document ? 'document' : n.tagName.toLowerCase() + (n.id ? '#' + n.id : '');
    for(let node=el; node; node=node.parentNode){
      seen.add(node);
      for(const r of registrations.get(node) || []) rows.push({...r,target:path(node),relation:node===el?'direct':'ancestor candidate'});
      if(typeof node.onclick==='function') rows.push({event:'click',target:path(node),relation:node===el?'direct property':'ancestor property',source:String(node.onclick).slice(0,1600)});
      if(node===form && typeof node.onsubmit==='function') rows.push({event:'submit',target:path(node),relation:'form property',source:String(node.onsubmit).slice(0,1600)});
    }
    if(form && !seen.has(form)) {
      for(const r of registrations.get(form)||[]) rows.push({...r,target:path(form),relation:'associated form'});
      if(typeof form.onsubmit==='function') rows.push({event:'submit',target:path(form),relation:'associated form property',source:String(form.onsubmit).slice(0,1600)});
    }
    return rows;
  };
})();"""
collect = """() => {
  const selector = 'button,input[type=submit],input[type=button],a[href],[role=button],summary';
  const nodes = Array.from(document.querySelectorAll(selector));
  return nodes.map((el,index)=>{
    const css = getComputedStyle(el), rect = el.getBoundingClientRect();
    const visible = rect.width>0 && rect.height>0 && css.visibility!=='hidden' && css.display!=='none' &&
                    !el.closest('[hidden],.hidden,[inert],[aria-hidden=true]');
    const key = el.dataset.key || el.dataset.ffxNav || el.dataset.ffxKpi || null;
    const parent = el.parentElement?.closest('[id]');
    const label = (el.getAttribute('aria-label') || el.textContent || el.value || el.getAttribute('title') || '').trim().replace(/\\s+/g,' ').slice(0,180);
    const links = window.__p0Bindings(el);
    const native = el.matches('summary') ? 'native details toggle' : el.matches('a[href]') ? 'native link (destination not exported)' : el.matches('button[type=reset]') ? 'native reset' : null;
    const form = el.form || el.closest('form');
    return {index,id:el.id||null,key,label,tag:el.tagName,container:parent?.id||null,form:form?.id||null,
      data_attribute_names:Object.keys(el.dataset),visible,disabled:!!el.disabled,bindings:links,native,
      direct_binding:links.some(x=>x.relation.startsWith('direct') && x.event==='click'),
      form_binding:!!form && (el.type==='submit') && links.some(x=>x.event==='submit'),
      delegated_candidate:links.some(x=>x.event==='click' && x.relation.includes('ancestor'))};
  });
}"""
fixture = """async ({role,permissions,branches}) => {
  document.body.dataset.access='staff';
  document.getElementById('loginOverlay').classList.add('hidden');
  user={id:'p0-fixture-'+role,email:'p0-'+role+'@example.invalid'};
  selfPermissions=permissions;
  rpc=async(name,args={})=>{
    if(name==='ff_burger_my_branch')return {role,branches};
    if(name==='ff_v12_assembly_snapshot')return {role:'assembly',branch:branches[0],orders:[]};
    if(name==='ff80_dashboard_metrics')return {role,business_day:'2026-11-24',orders_today:0,late_today:0,completed_today:0,available_drivers:null};
    if(name==='ff81_effective_design')return null;
    if(name==='ff28_application')return null;
    return [];
  };
  data={role,branches,orders:[],drivers:[],offers:[],driver_id:'fixture-driver',my_presence:'offline'};
  if(role==='burger_kitchen'){data=null;await window.ffBurgerStart();return}
  if(role==='assembly'){await ffV12Start();return}
  if(role==='customer'||role==='applicant'){
    data=null;document.body.dataset.access=role;
    await ff28PortalLoad();return;
  }
  draw();
}"""
branch_catalog = [{"id":"fixture-cairo","code":"cairo","name":"القاهرة"},
                  {"id":"fixture-sam","code":"sam_mall","name":"سام مول"},
                  {"id":"fixture-khamseen","code":"khamseen","name":"الخمسين"}]
roles = ("login","manager","supervisor","customer_service","cashier","driver","assembly","burger_kitchen","customer","applicant")
report = []
with sync_playwright() as pw:
    browser = pw.chromium.launch(channel="chrome")
    for width in (390,1280):
        for role in roles:
            context = browser.new_context(viewport={"width":width,"height":800},is_mobile=width<850,service_workers="block")
            context.route("**/*",lambda route: route.continue_() if route.request.url.startswith(origin) else route.abort())
            context.add_init_script(init)
            page = context.new_page()
            page.goto(origin)
            branches = branch_catalog if role in ("manager","customer_service") else branch_catalog[:1]
            result = {"role":role,"width":width,"branches":[b["code"] for b in branches] if role!="login" else [],"scope":"synthetic role, empty orders, offline RPC fixture"}
            try:
                if role!="login":
                    page.evaluate(fixture,{"role":role,"permissions":permissions.get(role,{}),"branches":branches})
                else:
                    page.locator("#ff61ApplyToggle").click()
                # Take an actual empty-state screenshot; no real accounts or orders.
                page.screenshot(path=out/f"p0-{role}-{width}.png",animations="disabled",timeout=10000)
                result["controls"] = page.evaluate(collect)
                if role in ("manager","supervisor","customer_service","cashier","driver"):
                    page.locator("#ffx-menu").click()
                    page.wait_for_function("document.querySelector('#ffx-sidebar').getAttribute('aria-hidden')===null")
                    result["drawer_controls"] = page.evaluate(collect)
                result["status"] = "CAPTURED"
            except Exception as error:
                # A fixture setup problem is not a proven operational failure.
                # Keep any accessible controls and exact issue as an explicit P0 gap.
                result["status"] = "FIXTURE_ERROR"
                result["error"] = str(error)[:1800]
                result["controls"] = page.evaluate(collect)
            report.append(result)
            context.close()
    browser.close()
server.shutdown()
for snapshot in report:
    controls = snapshot.get("controls",[]) + snapshot.get("drawer_controls",[])
    for c in controls:
        route = route_map.get(c["key"])
        if route:
            c["navigation"] = {"target":route["target"],"visibility_rule":route["visibility"],"alternative":route["alternative"]}
        if c["native"] or c["direct_binding"] or c["form_binding"]:
            c["mapping_status"] = "direct/native/form"
        elif c["delegated_candidate"]:
            c["mapping_status"] = "ancestor candidate; action not proven"
        else:
            c["mapping_status"] = "no captured handler; review required"
commit = subprocess.check_output(["git","rev-parse","HEAD"],cwd=root,text=True).strip()
summary = [{"role":s["role"],"width":s["width"],"status":s["status"],
            "visible":sum(c["visible"] for c in s["controls"]),
            "visible_without_direct_or_native":sum(c["visible"] and c["mapping_status"]!="direct/native/form" for c in s["controls"]),
            "error":s.get("error")} for s in report]
(out/"runtime-button-map.json").write_text(json.dumps({"commit":commit,"scope":"P0 DOM capture and handler evidence; not authorization or execution acceptance. Delegated candidates and data-dependent controls remain distinct gaps.","summary":summary,"snapshots":report},ensure_ascii=False,indent=2)+"\n")
print(json.dumps(summary,ensure_ascii=False))
assert len(report)==20 and all(s["controls"] for s in report), "Incomplete baseline inventory"
assert all(s["status"]=="CAPTURED" for s in report), "One or more baseline role fixtures failed; inspect evidence"
print("PASS P0 baseline role shell inventory on both viewport sizes; no live data accessed")
