"""FIX-07: exercise the actual shipped contact editor and alert handler in
two isolated Chromium contexts sharing a synthetic RPC fixture. No live auth,
SMS, network mutations, or real orders. Actual database proof is separate.
"""
from pathlib import Path
from playwright.sync_api import sync_playwright
root = Path(__file__).resolve().parents[1]
script = (root / "scripts/luxe-order-customer-edit-20261123.js").read_text(encoding="utf-8")
order = {"id":"fixture-order","number":990001,"status":"sent","phase":"assigned","name":"QA customer","phone":"700000000","area":"QA area","address":"QA address","customer_update":None}
calls = []
def rpc(name, args=None):
    args = args or {}
    calls.append((name,args.copy()))
    if name == "ff_order_customer_read":
        return order.copy()
    if name in ("ff_order_customer_edit", "ff_order_customer_edit_with_note"):
        assert args["p_order"] == order["id"]
        assert args["p_reason"]
        order.update({k:args["p_"+k] for k in ("name","phone","area","address")})
        order["customer_update"]={"at":f"2026-11-24T20:00:0{sum(n.startswith('ff_order_customer_edit') for n,_ in calls)}Z","fields":["phone","address"]}
        return {"saved":True,"note_saved":bool(args.get("p_note"))}
    raise AssertionError(name)
with sync_playwright() as pw:
    browser = pw.chromium.launch(channel="chrome")
    for width in (390,1280):
        order.update(phone="700000000",address="QA address",customer_update=None)
        calls.clear()
        contexts=[]
        pages=[]
        for role in ("customer_service","driver"):
            ctx=browser.new_context(viewport={"width":width,"height":800},service_workers="block")
            contexts.append(ctx)
            ctx.route("**/*",lambda route:route.abort())
            p=ctx.new_page()
            p.set_content('<button data-ff-customer-edit="fixture-order">تعديل</button>')
            p.expose_function("fixtureRpc",rpc)
            p.add_script_tag(content="""window.user={id:'fixture-'+ROLE};
              window.data={role:ROLE,orders:[]};window.canAction=()=>true;
              window.rpc=(n,a)=>window.fixtureRpc(n,a);
              window.__sounds=0;window.__toasts=[];window.__reloads=0;
              window.ding=()=>{window.__sounds++};
              window.toast=m=>window.__toasts.push(m);
              window.reload=()=>{window.__reloads++};
            """.replace("ROLE",repr(role)))
            p.add_script_tag(content=script)
            pages.append(p)
        cs,driver=pages
        def snapshot():
            driver.evaluate("(o)=>{data.orders=[o];window.dispatchEvent(new Event('ff-assembly-snapshot-success'))}",order.copy())
        snapshot()
        assert driver.evaluate("__sounds")==0
        # Use actual click handler and form submit in CS context.
        cs.locator("[data-ff-customer-edit]").click()
        cs.wait_for_function("!document.querySelector('#ffCustomerEditSave').disabled")
        cs.locator("[name=phone]").fill("700000001")
        cs.locator("[name=address]").fill("QA corrected address")
        cs.locator("[name=reason]").fill("QA correction")
        cs.locator("[name=customer_note]").fill("QA private note")
        cs.locator("#ffCustomerEditSave").click()
        cs.wait_for_function("window.__reloads===1")
        assert calls[-1][0]=="ff_order_customer_edit_with_note"
        assert order["phone"]=="700000001" and order["address"]=="QA corrected address"
        snapshot()
        assert driver.evaluate("__sounds")==1, "first edit notification missing"
        assert driver.evaluate("__toasts").pop().endswith("#990001")
        snapshot()
        assert driver.evaluate("__sounds")==1, "duplicate polling alert"
        order["customer_update"]={"at":"2026-11-24T20:00:09Z","fields":["phone"]}
        snapshot()
        assert driver.evaluate("__sounds")==2, "second edit notification missing"
        driver.evaluate("window.dispatchEvent(new Event('ff-luxe-session-reset')); user={id:'another-driver'}")
        snapshot()
        assert driver.evaluate("__sounds")==2, "historical alert leaked across sessions"
        driver.evaluate("window.ffCustomerEdit('fixture-order')")
        assert not driver.locator("#ffCustomerEditDialog").is_visible()
        assert not any("p_note" in a for n,a in calls if n=="ff_order_customer_read")
        for ctx in contexts:ctx.close()
        print(f"PASS FIX-07 {width}px: CS editor submit, first and second driver alerts, duplicate polling, session reset and role denial",flush=True)
    browser.close()
