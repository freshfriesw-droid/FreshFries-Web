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
                product = page.locator(".ffl-picker-product")
                plus = page.locator(".ffl-picker-controls button").last
                minus = page.locator(".ffl-picker-minus")
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
                assert result["gridColumns"] == (1 if width <= 370 else 2 if width <= 540 else 2), (
                    width, result
                )
                assert all(x["x"] >= -1 and x["right"] <= width + 1
                           for x in result["buttons"]), (width, result)
                assert all(x["height"] >= 43 and x["width"] >= 43
                           for x in result["buttons"]), (width, result)
                print(f"PASS burger picker: {width}px, tap + / minus, bounds 0-99, ARIA, grid", flush=True)
                context.close()
        finally:
            browser.close()
finally:
    server.shutdown()
