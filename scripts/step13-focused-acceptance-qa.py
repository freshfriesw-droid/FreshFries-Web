"""Step 13 QA31/32: actual Chromium UI with isolated RPC fixtures, no real orders."""
import ast,json
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright

root=Path(__file__).resolve().parents[1]
out=root/"step13-evidence";out.mkdir(exist_ok=True)
fixture=next(ast.literal_eval(n.value) for n in ast.parse((root/"scripts/a02-order-draft-qa.py").read_text()).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=="fixture" for t in n.targets))
server=ThreadingHTTPServer(("127.0.0.1",0),partial(SimpleHTTPRequestHandler,directory=root))
Thread(target=server.serve_forever,daemon=True).start()
origin=f"http://127.0.0.1:{server.server_port}/"
modes=("labels","icons","wide","floating","compact")
widths=(320,360,390,430)
results=[]
raw="1 تشكن بدون شطة\n2 برجر اسمر دبل\nملاحظة: اتصل"
def setup(page):
 page.goto(origin,wait_until="load")
 page.wait_for_function("typeof window.ffA07Design?.apply==='function' && typeof window.ffLuxeOrderText?.appendText==='function'")
 page.evaluate(fixture)
 page.locator("#ffbTabMenu").evaluate("""b=>{
   const parents=[];for(let n=b;n;n=n.parentElement)parents.push(n);
   for(const n of parents.reverse()){
    if(n.matches("details"))n.open=true;
    if(n.matches(".ff-menu-closed,.ffl-collapsed"))n.querySelector(":scope > .ff-menu-toggle[aria-expanded=false],:scope > .ffl-fold-toggle[aria-expanded=false]")?.click();
   }b.click();
 }""")
 page.wait_for_function("document.querySelectorAll('#ffbMenuGrid .ffb-v2-item').length===2")
 page.evaluate("""raw=>{
  for(const [id,value] of Object.entries({newItems:raw,ffbQuickInput:raw,newPhone:'700000001',newArea:'QA area',newFee:'500'})){
   const e=document.getElementById(id);e.value=value;e.dispatchEvent(new Event('input',{bubbles:true}));
  }
 }""",raw)
def draft_state(page):
 return page.evaluate("""()=>({raw:document.querySelector('#ffbQuickInput').value,items:document.querySelector('#newItems').value,fee:document.querySelector('#newFee').value,branch:document.querySelector('#newBranch').value,cart:document.querySelector('#ffbCart').textContent,selection:[document.querySelector('#newItems').selectionStart,document.querySelector('#newItems').selectionEnd],focus:document.activeElement.id,identical:document.querySelector('#newItems')===window.qaDraft})""")
try:
 with sync_playwright() as pw:
  browser=pw.chromium.launch(channel="chrome")
  for width in widths+(1440,):
   ctx=browser.new_context(viewport={"width":width,"height":850},reduced_motion="reduce",service_workers="block")
   ctx.route("**/*",lambda route:route.continue_() if route.request.url.startswith(origin) else route.abort())
   page=ctx.new_page();setup(page)
   if width in widths:
    for mode in modes:
     page.evaluate("(m)=>document.body.dataset.ffA06Bar=m",mode)
     save=page.locator("#createBtn");save.scroll_into_view_if_needed()
     # Real hit-testing without clicking or changing any operational state.
     save.click(trial=True,timeout=5000)
     box=save.bounding_box();assert box and box["width"]>0 and box["height"]>0,(width,mode)
     hit=page.evaluate("""()=>{const e=document.querySelector('#createBtn'),r=e.getBoundingClientRect(),top=document.elementFromPoint(r.x+r.width/2,r.y+r.height/2);return !!top&&(top===e||e.contains(top))}""")
     assert hit,(width,mode,"save obscured")
     results.append({"criterion":"QA-32","width":width,"mode":mode,"result":"PASS"})
   # Exercise production design-receipt renderer with two synthetic published rows.
   page.locator("#newItems").focus()
   page.evaluate("""()=>{window.qaDraft=document.querySelector('#newItems');qaDraft.setSelectionRange(2,7)}""")
   before=draft_state(page);assert before["focus"]=="newItems" and before["identical"] and before["items"]==raw and before["cart"].strip(),before
   for rev,pack in [(101,"D03"),(102,"D08")]:
    page.evaluate("""([id,pack])=>window.ffA07Design.apply({orders:{id,pack,style_config:{density:'compact'}}})""",[rev,pack])
    page.wait_for_function("(pack)=>document.querySelector('#serviceOnly').dataset.ffA07Pack===pack",arg=pack)
    assert draft_state(page)==before,(width,pack,draft_state(page),before)
   results.append({"criterion":"QA-31","width":width,"result":"PASS","scope":"receipt renderer during entry; no actual network publication"})
   # Review, not commit: preserve the actual review layer and its active control.
   page.locator("#createBtn").click(timeout=5000)
   page.locator("#ffbConfirmLayer").wait_for(state="visible",timeout=5000)
   review=page.locator("#ffbReviewBody").inner_text()
   assert review.strip()
   page.locator("#ffbConfirmSave").focus()
   page.evaluate("()=>window.ffA07Design.apply({orders:{id:103,pack:'D04',style_config:{dialogRadius:'round',dialogPadding:'wide'}}})")
   assert page.locator("#ffbConfirmLayer").is_visible()
   assert page.locator("#ffbReviewBody").inner_text()==review
   assert page.evaluate("document.activeElement.id")=="ffbConfirmSave"
   assert page.locator("#newItems").input_value()==raw
   assert page.locator("#ffbQuickInput").input_value()==raw
   results.append({"criterion":"QA-31","width":width,"result":"PASS","scope":"receipt renderer during confirmation preview"})
   ctx.close()
  browser.close()
 assert sum(x["criterion"]=="QA-32" for x in results)==20
 assert sum(x["criterion"]=="QA-31" for x in results)==10
finally:
 (out/"focused-results.json").write_text(json.dumps(results,ensure_ascii=False,indent=2))
 server.shutdown()
print("PASS QA-32 20 real browser save hit-tests; QA-31 10 draft/preview cases with isolated design receipts")
