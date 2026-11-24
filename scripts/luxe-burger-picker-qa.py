"""FIX-02: real-browser regression for Fresh Fries' shared burger quantity picker.

No Supabase requests or production data. The official picker module is loaded
from this repository and operated with genuine DOM clicks in Chromium.
"""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[1]
server = ThreadingHTTPServer(
    ("127.0.0.1", 0),
    partial(SimpleHTTPRequestHandler, directory=root)
)
Thread(target=server.serve_forever, daemon=True).start()
origin = f"http://127.0.0.1:{server.server_port}/"

try:
    with sync_playwright() as p:
        browser = p.chromium.launch(channel="chrome")
        try:
            for width in (320, 390, 1280):
                context = browser.new_context(viewport={"width": width, "height": 800},
                                              service_workers="block")
                context.route("**/*", lambda route: route.continue_()
                              if route.request.url.startswith(origin) else route.abort())
                page = context.new_page()
                page.goto(origin + "offline.html", wait_until="domcontentloaded")
                page.add_script_tag(url=origin + "scripts/luxe-shared-photo-menu-20261123.js")
                page.evaluate("""() => {
                  const item={id:'burger-fixture',name:'سماش برجر أسمر دبل',price:1000};
                  const input=document.createElement('input');
                  input.type='number';input.min='0';input.max='99';input.value='0';
                  let picker=null;
                  const setQuantity=value=>{
                    input.value=String(Math.max(0,Math.min(99,Number(value)||0)));
                    picker.refresh(Number(input.value));
                    picker.element.querySelector('.ffl-picker-product')
                      .setAttribute('aria-pressed',String(Number(input.value)>0));
                  };
                  const shift=delta=>setQuantity(Number(input.value)+delta);
                  picker=window.ffLuxePhotoMenu.createTile(item,{
                    quantity:0,quantityInput:input,showPrice:true,
                    onAdd:()=>shift(1),onRemove:()=>shift(-1)
                  });
                  const grid=document.createElement('div');
                  grid.id='ffBurgerMenuFields';
                  grid.style.width='100%'; // Offline fixture otherwise shrink-wraps grid on desktop.
                  const secondary=window.ffLuxePhotoMenu.createTile(
                    {id:'other',name:'برجر أبيض',price:900},
                    {quantity:0,onAdd:()=>{},onRemove:()=>{}}
                  );
                  grid.append(picker.element,secondary.element);
                  document.body.replaceChildren(grid);
                  window.__secondPicker=secondary;
                  const get=()=>({
                    qty:Number(input.value),
                    badge:picker.element.querySelector('.ffb-v2-count').textContent,
                    badgeHidden:picker.element.querySelector('.ffb-v2-count').hidden,
                    selected:picker.element.classList.contains('ffl-picker-selected'),
                    aria:picker.element.querySelector('.ffl-picker-product')
                      .getAttribute('aria-pressed'),
                    minusDisabled:picker.element.querySelector('.ffl-picker-minus').disabled,
                    plusDisabled:[...picker.element.querySelectorAll('button')]
                      .find(b=>b.textContent==='+').disabled
                  });
                  window.__burgerFixture={get,setQuantity};
                }""")
                first_tile = page.locator(".ffl-picker-tile").first
                product = first_tile.locator(".ffl-picker-product")
                plus = first_tile.locator(".ffl-picker-controls button").last
                minus = first_tile.locator(".ffl-picker-minus")
                qty = lambda: page.evaluate("window.__burgerFixture.get()")
                assert qty()["qty"] == 0 and qty()["minusDisabled"]
                assert product.get_attribute("aria-label") == "إضافة سماش برجر أسمر دبل"
                # The component itself maintains semantic selection, even without
                # a screen-specific sync() function.
                assert page.evaluate("""() => {
                  const picker=window.__secondPicker;
                  picker.refresh(2);
                  const pressed=picker.element.querySelector('.ffl-picker-product').getAttribute('aria-pressed');
                  picker.refresh(0);
                  const cleared=picker.element.querySelector('.ffl-picker-product').getAttribute('aria-pressed');
                  return pressed==='true'&&cleared==='false';
                }""")
                product.click()
                assert qty()["qty"] == 1 and qty()["selected"] and qty()["aria"] == "true"
                product.click()
                assert qty()["qty"] == 2
                plus.click()
                assert qty()["qty"] == 3 and qty()["badge"] == "3"
                minus.click()
                assert qty()["qty"] == 2
                minus.click()
                minus.click()
                assert qty()["qty"] == 0 and qty()["minusDisabled"]
                assert qty()["badgeHidden"] and not qty()["selected"]
                # At 99 the plus button is disabled, and clicks cannot overflow.
                page.evaluate("window.__burgerFixture.setQuantity(98)")
                plus.click()
                assert qty()["qty"] == 99 and qty()["plusDisabled"]
                assert qty()["aria"] == "true"
                # A direct keyboard edit path reflects changes through sync.
                page.evaluate("window.__burgerFixture.setQuantity(3)")
                assert qty()["qty"] == 3 and qty()["badge"] == "3"
                assert page.locator(".ffl-picker-controls input").input_value() == "3"
                # Two real product cards reveal cramped 320px grid layouts.
                # Check both viewport overflow and tappable +/- dimensions.
                result = page.evaluate("""() => ({
                  gridColumns:getComputedStyle(document.getElementById('ffBurgerMenuFields'))
                    .gridTemplateColumns.split(' ').length,
                  buttons:[...document.querySelectorAll('.ffl-picker-tile button')]
                    .map(el=>({name:el.getAttribute('aria-label'),
                      x:el.getBoundingClientRect().left,
                      right:el.getBoundingClientRect().right,
                      height:el.getBoundingClientRect().height,
                      width:el.getBoundingClientRect().width}))
                })""")
                assert result["gridColumns"] == (1 if width <= 370 else 2) if width <= 540 else result["gridColumns"] >= 2, (
                    width, result
                )
                assert all(x["x"] >= -1 and x["right"] <= width + 1
                           for x in result["buttons"]), (width, result)
                assert all(x["height"] >= 43 and x["width"] >= 43
                           for x in result["buttons"]), (width, result)
                print(f"PASS burger picker: {width}px, tap + / minus, bounds 0-99, ARIA, grid", flush=True)
                # Exercise the actual main cart functions and shipped parser in
                # real DOM, including transfer from a text draft and quantity edits.
                source = (root / "index.html").read_text(encoding="utf-8")
                unified = (root / "scripts/luxe-unified-order-inputs-20261123.js").read_text(encoding="utf-8")
                parser = source[source.index("const ff49NormalizeInput="):source.index("// Prevent older create callback")]
                editor = unified[unified.index("function itemRows("):unified.index("window.ffLuxeOrderText=")]
                cart_source = source[source.index(" function change(item,by){"):source.index(" function fillFromParsed(parsed){")]
                fixture = """
                (() => {
                  document.body.replaceChildren();
                  const field=document.createElement('textarea');field.id='newItems';
                  const panel=document.createElement('div');panel.id='ffbCart';panel.style.width='100%';
                  document.body.append(field,panel);
                  const $=id=>document.getElementById(id);
                  const catalog=[{id:'burger',name:'سماش برجر دبل أسمر',price:1500},
                    {id:'chicken',name:'تشكن فرايز',price:1750}];
                  let ff49Catalog=catalog,cart=new Map();
                  const status=message=>{throw Error(message)};
                """ + parser + editor + """
                  window.ffLuxeOrderText={itemRows,appendText};
                """ + cart_source + """
                  field.value=['٣ برجر اسمر دبل بدون شطة | 1400','1 تشكن | 1750','ملاحظة: لا تتصل'].join('\\n');
                  field.addEventListener('input',renderCart);
                  renderCart();
                  window.__mainCartFixture=()=>({
                    items:ff49ParseItemsAndNotes(field.value).items,
                    notes:ff49ParseItemsAndNotes(field.value).notes,
                    quantity:cart.get('burger')||0
                  });
                })();
                """
                page.add_script_tag(content=fixture)
                burger_row=page.locator(".ffb-v2-cartline").first
                def cart_state(expected):
                    state=page.evaluate("window.__mainCartFixture()")
                    assert state["quantity"] == expected, state
                    if expected:
                        assert state["items"][0]["qty"] == expected, state
                        assert state["items"][0]["price"] == 1400, state
                        assert state["items"][0]["item_notes"] == "بدون شطة", state
                        assert burger_row.locator(".ffb-v2-qty").inner_text() == str(expected)
                        assert "بدون شطة" in burger_row.inner_text()
                    assert state["items"][-1]["name"] == "تشكن فرايز", state
                    assert state["items"][-1]["qty"] == 1, state
                    assert state["notes"] == "لا تتصل", state
                cart_state(3)
                for label, expected in [("تقليل", 2), ("تقليل", 1), ("زيادة", 2), ("زيادة", 3)]:
                    page.get_by_role("button", name=label+" سماش برجر دبل أسمر", exact=True).click()
                    cart_state(expected)
                for expected in (2,1,0):
                    page.get_by_role("button", name="تقليل سماش برجر دبل أسمر", exact=True).click()
                    cart_state(expected)
                assert page.locator(".ffb-v2-cartline").count() == 1
                print(f"PASS A02 main cart: {width}px, quantity rollback, notes, price, removal", flush=True)
                context.close()
        finally:
            browser.close()
finally:
    server.shutdown()
