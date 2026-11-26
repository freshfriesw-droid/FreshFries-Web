"""QA01/27/39 route dispatch audit in isolated Chrome, no production traffic."""
import ast,json
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
out=root/"step13-route-evidence";out.mkdir(exist_ok=True)
fixture=next(ast.literal_eval(n.value) for n in ast.parse((root/"scripts/a06-navigation-qa.py").read_text()).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=="fixture" for t in n.targets))
mapping=json.loads((root/"docs/implementation/A06-route-map-20261125.json").read_text())
keys={x["key"] for x in mapping["routes"]}-{"settings","refresh","logout"}
direct={
 "home":"home","new":"ffbTextPanel","orders":"staffOrders","late":"ffx-overdue","drivers":"driversRoster","driver":"driverView","cashier":"cashierView",
 "offers":"offers","attendance":"clockInBtn","burger":"ffBurgerCashierPanel","cashier_finished":"fflCashierFinishedToggle","branch_policy":"ffA05BranchPolicyBtn",
 "staff_link":"managerLinks","applications":"ff61ManageShortcut","application_alerts":"ff63NotificationsShortcut","studio":"studio","data_center":"ff62DataCenter","team":"staffAdminCard","assembly_admin":"staffAdminList","rewards":"ffRewardManager","reports":"reports"
}
targets={x["key"]:x["target"] for x in mapping["routes"] if x["key"] in keys and x["key"] not in direct}
direct.update(targets)
assert set(direct)==keys
server=ThreadingHTTPServer(("127.0.0.1",0),partial(SimpleHTTPRequestHandler,directory=root))
Thread(target=server.serve_forever,daemon=True).start()
origin=f"http://127.0.0.1:{server.server_port}/"
results=[];states=[];unnamed=[];legacy=[];failures=[]
try:
 with sync_playwright() as pw:
  browser=pw.chromium.launch(channel="chrome")
  for role in ("manager","supervisor","customer_service","cashier","driver"):
   for width in (390,1440):
    ctx=browser.new_context(viewport={"width":width,"height":850},service_workers="block",reduced_motion="reduce")
    ctx.route("**/*",lambda route:route.continue_() if route.request.url.startswith(origin) else route.abort())
    page=ctx.new_page();page.goto(origin,wait_until="load");page.evaluate(fixture,role)
    page.wait_for_function("document.querySelectorAll('#ffx-nav button[data-key]').length>0")
    # Spy on real dispatch boundaries while preserving original implementations.
    page.evaluate("""()=>{
      window.qaRoutes=[];
      const scroll=Element.prototype.scrollIntoView;Element.prototype.scrollIntoView=function(...a){qaRoutes.push({kind:'scroll',target:this.id});return scroll.apply(this,a)};
      const top=window.scrollTo;window.scrollTo=function(...a){qaRoutes.push({kind:'top',target:'home'});return top.apply(this,a)};
      const modal=HTMLDialogElement.prototype.showModal;HTMLDialogElement.prototype.showModal=function(...a){qaRoutes.push({kind:'modal',target:this.id});return modal.apply(this,a)};
      document.addEventListener('click',e=>{const b=e.target.closest('button');if(b?.id)qaRoutes.push({kind:'click',target:b.id})},true);
      for(const [obj,key,target] of [[window,'ff76OpenReports','reports'],[window.ffDashboardStudio,'open','studio']]){
        if(obj&&typeof obj[key]==='function'){const original=obj[key];obj[key]=function(...a){qaRoutes.push({kind:'call',target});return original.apply(this,a)}}
      }
    }""")
    def drawer():
     page.evaluate("""()=>{for(const d of document.querySelectorAll('dialog[open]'))d.close();document.getElementById('ffx-pref-close')?.click();}""")
     if page.locator("#ffx-sidebar").get_attribute("aria-hidden")=="true":
      page.locator("#ffx-menu").click(timeout=5000)
     page.locator('#ffx-nav select[aria-label="طريقة عرض القائمة"]').select_option("flat")
     page.locator('#ffx-nav-search').fill("")
    drawer()
    visible=page.locator("#ffx-nav button[data-key]").evaluate_all("es=>es.map(e=>e.dataset.key)")
    assert visible and len(visible)==len(set(visible)) and set(visible)<=keys,(role,width,visible)
    # Every authorized legacy header route must remain reachable via the drawer.
    for old in mapping["legacyHeader"]:
     path=old["path"].split(" ")[0]
     if path not in keys:continue
     permitted=page.evaluate("""id=>{const e=document.getElementById(id);return !!e&&!e.hidden&&!e.classList.contains('hidden')}""",old["id"])
     if permitted and path not in visible:failures.append({"role":role,"width":width,"legacy":old["id"],"expected":path})
     if permitted:legacy.append({"role":role,"width":width,"id":old["id"],"path":path,"reachable":path in visible})
    for key in visible:
     drawer();page.evaluate("window.qaRoutes=[]")
     b=page.locator('#ffx-nav button[data-key="'+key+'"]')
     b.click(timeout=5000)
     expected=direct[key]
     if key=="offers":expected="driverOffers" if role=="driver" else "openOffers"
     try:page.wait_for_function("(expected)=>qaRoutes.some(e=>e.target===expected)",arg=expected,timeout=1800)
     except Exception:pass
     events=page.evaluate("window.qaRoutes")
     active=page.locator('#ffx-nav button[data-key="'+key+'"]').get_attribute("aria-current")
     ok=any(e["target"]==expected for e in events) and active=="location"
     row={"role":role,"width":width,"key":key,"target":expected,"events":events,"active":active,"ok":ok};results.append(row)
     if not ok:failures.append(row)
     # Record visible form controls without an explicit or native label. This is
     # diagnostic only; the fixture does not create every data-driven dialog.
     missing=page.evaluate("""()=>[...document.querySelectorAll('input,select,textarea')].filter(e=>{
       if(e.type==='hidden'||!e.getClientRects().length||e.closest('[hidden],.hidden,[aria-hidden=true]'))return false;
       const s=getComputedStyle(e);if(s.display==='none'||s.visibility==='hidden')return false;
       return !(e.getAttribute('aria-label')?.trim()||e.getAttribute('aria-labelledby')?.trim()||[...(e.labels||[])].some(l=>l.textContent.trim())||e.title?.trim());
     }).map(e=>({id:e.id,tag:e.tagName,placeholder:e.placeholder||'',name:e.name||''}))""")
     for e in missing:
      if e not in unnamed:unnamed.append(e)
    # Route and group persistence through mode switching and actual theme redraw.
    drawer()
    key={"manager":"orders","supervisor":"orders","customer_service":"orders","cashier":"cashier","driver":"driver"}[role]
    page.locator('#ffx-nav button[data-key="'+key+'"]').click()
    drawer();mode=page.locator('#ffx-nav select[aria-label="طريقة عرض القائمة"]');mode.select_option("accordion")
    toggle=page.locator("#ffx-nav [data-ffx-group-toggle]").first;toggle.click();expanded=toggle.get_attribute("aria-expanded")
    mode.select_option("flat");mode.select_option("accordion")
    page.keyboard.press("Escape");page.locator("#ffx-theme-toggle").click();page.locator("#ffx-menu").click()
    active=page.locator('#ffx-nav button[data-key="'+key+'"]').get_attribute("aria-current")
    retained=page.locator("#ffx-nav [data-ffx-group-toggle]").first.get_attribute("aria-expanded")
    ok=active=="location" and retained==expanded
    states.append({"role":role,"width":width,"key":key,"active":active,"group":retained,"expected":expanded,"ok":ok})
    if not ok:failures.append(states[-1])
    ctx.close()
  browser.close()
finally:
 server.shutdown()
 (out/"route-audit.json").write_text(json.dumps({"routes":results,"state":states,"legacy":legacy,"unnamed_visible_controls":unnamed,"failures":failures},ensure_ascii=False,indent=2))
print("STEP13 route audit:",len(results),"actual dispatch checks;",len(states),"mode/theme route checks;",len(legacy),"legacy launcher checks;",len(unnamed),"distinct unnamed visible controls;",len(failures),"failed checks",flush=True)
print("Uncovered keys:",sorted(keys-{x["key"] for x in results}),flush=True)
print("Diagnostics:",json.dumps({"unnamed":unnamed,"failures":failures[:20]},ensure_ascii=False),flush=True)
assert len(states)==10 and not failures,"route or state verification failed"

assert not unnamed, 'Visible unlabeled controls remain: '+json.dumps(unnamed,ensure_ascii=False)
