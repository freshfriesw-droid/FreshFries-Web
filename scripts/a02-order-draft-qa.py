"""A02 regression on actual application, offline Chrome. No real orders or accounts."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright

root=Path(__file__).resolve().parents[1]
out=root/"a02-evidence";out.mkdir(exist_ok=True)
server=ThreadingHTTPServer(("127.0.0.1",0),partial(SimpleHTTPRequestHandler,directory=root))
Thread(target=server.serve_forever,daemon=True).start()
origin=f"http://127.0.0.1:{server.server_port}/"
fixture="""async () => {
 document.body.dataset.access='staff';
 document.body.classList.remove('ff-booting');
 document.getElementById('loginOverlay').classList.add('hidden');
 user={id:'a02-fixture'};
 const branches=[{id:'fixture-cairo',name:'القاهرة',code:'cairo'}];
 const menu=[{id:'chicken',name:'تشكن فرايز',price:1500,active:true,parser_aliases:['تشكن']},{id:'burger',name:'سماش برجر دبل أسمر',price:2000,active:true,parser_aliases:['برجر اسمر دبل']}];
 data={role:'customer_service',branches,orders:[],drivers:[],offers:[]};
 selfPermissions={create_order:true,edit_order:true};
 rpc=async name=>name==='ff49_catalog'?menu:name==='ff_luxe_dispatch_preview'?{state:'waiting'}:[];
 ff49Catalog=menu;ff49CatalogActor=user.id;ff49CatalogAt=Date.now();
 draw();
 document.getElementById('staffView').classList.remove('hidden');
 document.getElementById('serviceOnly').classList.remove('hidden');
 document.getElementById('ffx-hero-new').click();
}"""
with sync_playwright() as pw:
 browser=pw.chromium.launch(channel="chrome")
 for width in (390,1280):
  ctx=browser.new_context(viewport={"width":width,"height":900},is_mobile=width<850,service_workers="block")
  ctx.route("**/*",lambda route:route.continue_() if route.request.url.startswith(origin) else route.abort())
  page=ctx.new_page()
  page.on("pageerror",lambda error:print("PAGE ERROR:",error,flush=True))
  page.goto(origin)
  page.wait_for_function("typeof window.ffLuxeOrderText?.appendText==='function'")
  page.evaluate(fixture)
  # Activate actual menu action rather than duplicating its implementation.
  page.locator("#ffbTabMenu").evaluate("""b=>{
    const parents=[];for(let n=b;n;n=n.parentElement)parents.push(n);
    for(const n of parents.reverse()){
      if(n.matches("details"))n.open=true;
      if(n.matches(".ff-menu-closed,.ffl-collapsed"))n.querySelector(":scope > .ff-menu-toggle[aria-expanded=false],:scope > .ffl-fold-toggle[aria-expanded=false]")?.click();
    }b.click();
  }""")
  page.wait_for_function("document.querySelectorAll('#ffbMenuGrid .ffb-v2-item').length===2")
  draft=page.locator("#newItems")
  raw="١ تشكن بدون شطّة | 1200\n2 برجر اسمر دبل\nملاحظة: اتصل بالعميل"
  draft.evaluate("(el,raw)=>{el.value=raw;el.dispatchEvent(new Event('input',{bubbles:true}))}",raw)
  print("A02 cart diagnostics:",page.evaluate("""()=>({actor:user?.id, catalog:ff49Catalog.length, parsed:window.ffLuxeOrderText.itemRows(document.querySelector("#newItems")),cart:document.querySelector("#ffbCart").textContent,ancestors:(()=>{const a=[];for(let n=document.querySelector("#ffbCart");n;n=n.parentElement)a.push({id:n.id,cls:n.className,display:getComputedStyle(n).display,hidden:n.hidden});return a})()})"""),flush=True)
  page.locator("#ffbCart").get_by_role("button",name="زيادة تشكن فرايز",exact=True).click(timeout=10000)
  assert draft.input_value()=="2 تشكن بدون شطّة | 1200\n2 برجر اسمر دبل\nملاحظة: اتصل بالعميل"
  page.locator("#ffbMenuGrid .ffb-v2-item").filter(has_text="تشكن فرايز").click()
  assert draft.input_value().endswith("1 تشكن فرايز")
  page.locator("#ffbUndoCart").evaluate("(b)=>b.click()")
  assert not draft.input_value().endswith("1 تشكن فرايز")
  page.locator("#ffbCart").get_by_role("button",name="تقليل تشكن فرايز",exact=True).evaluate("(b)=>b.click()")
  page.locator("#ffbCart").get_by_role("button",name="تقليل تشكن فرايز",exact=True).evaluate("(b)=>b.click()")
  assert draft.input_value()=="2 برجر اسمر دبل\nملاحظة: اتصل بالعميل"
  page.locator("#ffbUndoCart").evaluate("(b)=>b.click()")
  assert "بدون شطّة | 1200" in draft.input_value()
  # Changing a separate draft invalidates the previous undo operation.
  draft.evaluate("(el)=>{el.value+='\\nملاحظة: جديدة';el.dispatchEvent(new Event('input',{bubbles:true}))}")
  assert page.locator("#ffbUndoCart").count()==0
  page.locator("#ffbCart").screenshot(path=out/f"cart-{width}.png")
  print(f"PASS A02 actual cart DOM callbacks at {width}px: notes, price, add, decrement, delete, undo, stale undo")
  ctx.close()
 browser.close()
server.shutdown()
