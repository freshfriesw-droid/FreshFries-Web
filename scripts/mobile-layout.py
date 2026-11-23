"""Exercise the real RTL shell with local display fixtures and no remote traffic."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread
from pathlib import Path
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[1]
server = ThreadingHTTPServer(("127.0.0.1", 0), partial(SimpleHTTPRequestHandler, directory=root))
Thread(target=server.serve_forever, daemon=True).start()
origin = f"http://127.0.0.1:{server.server_port}/"


def check_order_status_colors(page):
    # Real browser computed styles: cancellation red must not inherit the ordinary blue card rule.
    result = page.evaluate("""() => {
      const output = {};
      for (const id of ['cashierOrders','driverTasks']) {
        const parent = document.getElementById(id);
        if (!parent) throw Error('Missing order list: ' + id);
        const normal = document.createElement('article');
        normal.className = 'item';
        const canceled = document.createElement('article');
        canceled.className = 'item ff-luxe-cancelled';
        parent.append(normal, canceled);
        output[id] = {
          normal: getComputedStyle(normal).borderTopColor,
          canceled: getComputedStyle(canceled).borderTopColor,
          cancelledWidth: getComputedStyle(canceled).borderTopWidth
        };
        normal.remove();
        canceled.remove();
      }
      return output;
    }""")
    for id in ('cashierOrders', 'driverTasks'):
        expected_normal = 'rgb(183, 14, 28)' if id == 'cashierOrders' else 'rgb(37, 99, 235)'
        assert result[id]['normal'] == expected_normal, (id, result)
        assert result[id]['canceled'] == 'rgb(185, 28, 28)', (id, result)
        assert result[id]['cancelledWidth'] == '4px', (id, result)


def check_legacy_status_feedback(page, width):
    # Simulate ordinary operational success/error feedback without touching Supabase.
    toast = page.locator("#toast")
    assert toast.get_attribute("role") == "status"
    assert toast.get_attribute("aria-live") == "polite"
    assert toast.is_hidden()
    toast.evaluate("""el => { el.textContent = 'تعذر التحديث: تحقق من الاتصال'; el.classList.remove('hidden'); }""")
    assert toast.is_visible(), f"Legacy status feedback hidden at {width}px"
    check_width(page, width, "#toast")
    status_box = toast.bounding_box()
    assert status_box and status_box["y"] >= -1, (width, status_box)
    if width <= 850:
        mobile_nav = page.locator("#ffx-mobile-nav").bounding_box()
        assert mobile_nav and status_box["y"] + status_box["height"] <= mobile_nav["y"] + 2, (
            width, status_box, mobile_nav
        )
    # The legacy message must not cover LUXE's separate modern toast surface.
    modern = page.locator("#ffx-toast")
    modern.evaluate("""el => { el.textContent = 'إشعار النظام'; el.classList.add('show'); }""")
    toast.evaluate("""el => { el.textContent = 'تعذر التحديث: تحقق من الاتصال'; el.classList.remove('hidden'); }""")
    bounds = (toast.bounding_box(), modern.bounding_box())
    assert all(bounds), (width, bounds)
    legacy, current = bounds
    intersects = (legacy["x"] < current["x"] + current["width"] and
                  current["x"] < legacy["x"] + legacy["width"] and
                  legacy["y"] < current["y"] + current["height"] and
                  current["y"] < legacy["y"] + legacy["height"])
    assert not intersects, ("Overlapping notifications", width, bounds)
    modern.evaluate("""el => { el.textContent = ''; el.classList.remove('show'); }""")
    toast.evaluate("""el => { el.classList.add('hidden'); el.textContent = ''; }""")
    assert toast.is_hidden()


def check_width(page, width, selector):
    box = page.locator(selector).first.bounding_box()
    assert box and box["x"] >= -1 and box["x"] + box["width"] <= width + 1, (width, selector, box)


def wait_for_open_drawer(page, width):
    # Measure after the slide animation, including the 851px desktop breakpoint.
    page.wait_for_function("""w => {
      const el = document.querySelector('#ffx-sidebar');
      const box = el?.getBoundingClientRect();
      return box && getComputedStyle(el).visibility === 'visible'
             && box.x >= -1 && box.right <= w + 1;
    }""", arg=width)


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(channel="chrome")
    for width in (320, 344, 360, 390, 430, 768, 850, 851, 1280):
        context = browser.new_context(viewport={"width": width, "height": 800},
                                      is_mobile=width <= 850, service_workers="block")
        context.route("**/*", lambda route: route.continue_() if route.request.url.startswith(origin) else route.abort())
        page = context.new_page()
        page.goto(origin)
        page.locator("#ff61ApplyToggle").click()
        check_width(page, width, "#ff61ApplyForm")
        # Render the staff shell without credentials or customer/order fixtures.
        page.evaluate("""() => {
          document.body.dataset.access='staff';
          document.querySelector('#loginOverlay').classList.add('hidden');
          for (const id of ['ff61ManageShortcut','ff63NotificationsShortcut'])
            document.getElementById(id).hidden=false;
        }""")
        check_order_status_colors(page)
        check_legacy_status_feedback(page, width)
        for selector in ("main", "#ffx-topbar", "#ff61ManageShortcut", "#ff63NotificationsShortcut", "#ffx-options"):
            check_width(page, width, selector)
        assert page.locator("#ffx-sidebar").get_attribute("aria-hidden") == "true"
        assert page.evaluate("document.querySelector('#ffx-sidebar').inert") is True
        assert page.evaluate("getComputedStyle(document.querySelector('#ffx-sidebar')).visibility") == "hidden"
        assert page.evaluate("""() => {
          document.querySelector('#ffx-drawer-close').focus();
          return document.activeElement.id !== 'ffx-drawer-close';
        }""")
        assert page.locator("#ffx-menu").get_attribute("aria-expanded") == "false"
        if width <= 850:
            assert page.evaluate("document.documentElement.scrollWidth") == width, width
            assert page.locator("#ffx-sidebar").is_hidden()
            check_width(page, width, "#ffx-mobile-nav")
            for trigger, close in (("#ffx-menu", "#ffx-drawer-close"), ("button[data-key=more]", None)):
                page.locator(trigger).click()
                wait_for_open_drawer(page, width)
                check_width(page, width, "#ffx-sidebar")
                assert page.locator("#ffx-sidebar").get_attribute("aria-hidden") is None
                assert page.evaluate("document.querySelector('#ffx-sidebar').inert") is False
                assert page.locator("#ffx-menu").get_attribute("aria-expanded") == "true"
                if close:
                    page.locator(close).click()
                else:
                    page.keyboard.press("Escape")
                assert page.locator("#ffx-sidebar").is_hidden()
                assert page.locator("#ffx-sidebar").get_attribute("aria-hidden") == "true"
                assert page.evaluate("document.querySelector('#ffx-sidebar').inert") is True
            page.locator("#ffx-options").click()
            check_width(page, width, "#ffx-preferences")
            page.locator("#ffx-pref-close").click()
            assert page.locator("#ffx-preferences").is_hidden()
            if width == 390:
                page.evaluate("""() => {
                  user={id:'fixture-manager'};
                  data={role:'manager', orders:[], branches:[], drivers:[], offers:[]};
                  rpc=async name=>{
                    if(name==='ff62_manager_data_overview')return {mode:'read_only',orders:7};
                    throw Error('Unconfigured test fixture');
                  };
                }""")
                page.locator("#ffx-menu").click()
                entry = page.locator("#ffx-nav [data-key=data_center]")
                entry.click()
                dialog = page.locator("#ff62DataCenter")
                check_width(page, width, "#ff62DataCenter")
                dialog.get_by_role("button", name="عرض ملخص البيانات", exact=False).click()
                dialog.get_by_text("تمت قراءة الملخص", exact=False).wait_for()
                dialog.get_by_role("button", name="إغلاق", exact=True).click()
                # A manager's in-flight settlement report must never appear after session reset.
                page.evaluate("""() => {
                  rpc=(name,args)=>{
                    if(name==='ff_luxe_settlement_period')
                      return new Promise(resolve=>{ window.__fixtureSettlementResolve=resolve; });
                    throw Error('Unexpected test RPC: '+name);
                  };
                  const button=document.getElementById('ff42RangeApply');
                  if (!button) throw Error('Missing settlement range report');
                  button.click();
                }""")
                page.wait_for_function("typeof window.__fixtureSettlementResolve==='function'")
                assert page.locator("#ff42RangeApply").is_disabled()
                page.evaluate("""() => {
                  window.dispatchEvent(new Event('ff-luxe-session-reset'));
                  data.role='cashier';
                  window.__fixtureSettlementResolve({
                    from:'2026-11-01',to:'2026-11-23',
                    totals:{delivered_orders:7,delivered_value:8000,cash_due:5000,cash_received:4500},
                    rows:[{day:'2026-11-21',branch:'SENSITIVE-OLD-MANAGER-REPORT',
                           delivered_orders:7,delivered_value:8000,settlements:1,cash_due:5000,cash_received:4500}]
                  });
                }""")
                page.wait_for_function("!document.getElementById('ff42RangeApply').disabled")
                assert page.locator("#ff42RangeTable").inner_text() == ''
                assert page.locator("#ff42RangeStatus").inner_text() == ''
                assert "SENSITIVE-OLD-MANAGER-REPORT" not in page.locator("body").inner_text()
                # Finished orders: an in-flight response must not survive logout or account switch.
                page.evaluate("""() => {
                  user={id:'fixture-manager'};
                  data={role:'manager',orders:[],branches:[],drivers:[],offers:[]};
                  rpc=(name,args)=>{
                    if(name==='ff_luxe_completed_universal')return new Promise(resolve=>{
                      window.__finishedDeferred=resolve;
                    });
                    return Promise.resolve({});
                  };
                  window.dispatchEvent(new Event('ff-assembly-snapshot-success'));
                }""")
                page.locator("#fflCashierFinishedToggle").click()
                page.wait_for_function("typeof window.__finishedDeferred==='function'")
                assert page.locator("#fflFinishedRefresh").is_disabled()
                page.evaluate("""() => {
                  window.dispatchEvent(new Event('ff-luxe-session-reset'));
                  user=null;data=null;
                  window.__finishedDeferred({items:[
                    {id:'old-secret',number:'SENSITIVE-OLD-ORDER',customer_name:'PRIVATE-OLD-CUSTOMER',
                     phone:'777777777',status:'delivered'}
                  ],branches:[{id:'old-branch',name:'PRIVATE-OLD-BRANCH'}],has_more:false});
                }""")
                page.wait_for_timeout(120)
                assert page.locator("#fflFinishedList").inner_text() == ''
                assert page.locator("#fflFinishedStatus").inner_text() == ''
                assert page.locator("#fflFinishedBranch").locator("option").count() == 1
                assert page.locator("#fflCashierFinished").is_hidden()
                # A newer filter request must take precedence over a slower prior request.
                page.evaluate("""() => {
                  user={id:'fixture-manager'};
                  data={role:'manager',orders:[],branches:[],drivers:[],offers:[]};
                  window.__finishedResolvers=[];
                  rpc=(name,args)=>{
                    if(name==='ff_luxe_completed_universal')
                      return new Promise(resolve=>window.__finishedResolvers.push(resolve));
                    return Promise.resolve({});
                  };
                  window.dispatchEvent(new Event('ff-assembly-snapshot-success'));
                }""")
                page.locator("#fflCashierFinishedToggle").click()
                page.wait_for_function("window.__finishedResolvers.length===1")
                page.evaluate("""() => {
                  window.dispatchEvent(new CustomEvent('ff-luxe-history-range',{
                    detail:{from:'2026-11-20',to:'2026-11-21'}
                  }));
                }""")
                page.wait_for_function("window.__finishedResolvers.length===2")
                page.evaluate("""() => window.__finishedResolvers[1]({
                  items:[{id:'new-record',number:'LATEST-FINISHED-ORDER',status:'delivered'}],
                  branches:[],has_more:false
                })""")
                page.get_by_text("LATEST-FINISHED-ORDER").wait_for()
                page.evaluate("""() => window.__finishedResolvers[0]({
                  items:[{id:'old-record',number:'STALE-FINISHED-ORDER',status:'delivered'}],
                  branches:[{id:'obsolete',name:'STALE-PRIVATE-BRANCH'}],has_more:false
                })""")
                page.wait_for_timeout(100)
                assert "LATEST-FINISHED-ORDER" in page.locator("#fflFinishedList").inner_text()
                assert "STALE-FINISHED-ORDER" not in page.locator("#fflFinishedList").inner_text()
                assert "STALE-PRIVATE-BRANCH" not in page.locator("#fflFinishedBranch").inner_text()
                page.evaluate("""() => {window.dispatchEvent(new Event('ff-luxe-session-reset')); user=null;data=null;}""")
                assert page.locator("#fflFinishedList").inner_text() == ''
                page.evaluate("""() => {user={id:'fixture-manager'};data={role:'manager',orders:[],branches:[],drivers:[],offers:[]};}""")
                page.evaluate("data.role='cashier'")
                entry.wait_for(state="detached")
                assert dialog.is_hidden()
            page.locator("#ffx-menu").click()
            page.set_viewport_size({"width":1100, "height":700})
            page.wait_for_function("!document.body.classList.contains('ffx-menu-open')")
            assert page.locator("#ffx-dimmer").is_hidden()
        else:
            # User-facing requirement: the sidebar is collapsed on desktop too.
            assert page.locator("#ffx-sidebar").is_hidden()
            page.locator("#ffx-menu").click()
            wait_for_open_drawer(page, width)
            check_width(page, width, "#ffx-sidebar")
            assert page.locator("#ffx-sidebar").get_attribute("aria-hidden") is None
            assert page.evaluate("document.querySelector('#ffx-sidebar').inert") is False
            page.locator("#ffx-drawer-close").click()
            assert page.locator("#ffx-sidebar").is_hidden()
            assert page.locator("#ffx-sidebar").get_attribute("aria-hidden") == "true"
            assert page.locator("#ffx-menu").get_attribute("aria-expanded") == "false"
        print(f"PASS {width}px", flush=True)
        context.close()
    browser.close()
server.shutdown()
