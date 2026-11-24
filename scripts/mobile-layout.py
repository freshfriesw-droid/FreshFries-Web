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


def check_version_badge_styles(page):
    """Compare all three badges against the cascade preceding FIX-04."""
    page.evaluate("""() => {
      const panel = document.createElement('div');
      panel.id = 'fixture-version-badges';
      panel.style.cssText = 'position:fixed;top:0;left:0;z-index:2147483647;background:white';
      for (const state of ['good', 'bad', 'unknown']) {
        const badge = document.createElement('span');
        badge.className = 'ff48-version ' + state;
        badge.textContent = state;
        panel.append(badge);
      }
      document.body.append(panel);
    }""")
    panel = page.locator('#fixture-version-badges')
    current = panel.screenshot(animations='disabled')
    page.evaluate("""() => {
      const previous = document.createElement('style');
      previous.id = 'fixture-previous-badge-rules';
      previous.textContent = [
        '.ff48-version.good{background:var(--ffb-soft2);color:var(--ffb-ink)}',
        '.ff48-version.bad,.ff48-version.unknown{background:var(--ffb-redwash);color:var(--ffb-redink)}'
      ].join('');
      document.querySelector('#ffx-luxe-style').before(previous);
    }""")
    assert current == panel.screenshot(animations='disabled'), 'FIX-04 changed badge appearance'
    page.locator('#fixture-previous-badge-rules').evaluate('el => el.remove()')
    panel.evaluate('el => el.remove()')


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
        if width in (390, 1280):
            check_version_badge_styles(page)
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
                # FIX-03: administrative links live in a six-group, keyboard-accessible
                # accordion. Verify opening, not just existence of a hidden DOM node.
                nav_groups = page.locator("#ffx-nav [data-ffx-group-toggle]")
                nav_groups.first.wait_for(state="attached", timeout=20000)
                assert nav_groups.count() == 6, nav_groups.count()
                system_group = page.locator("#ffx-nav [data-ffx-group-toggle=system]")
                assert system_group.get_attribute("aria-expanded") == "false"
                search = page.locator("#ffx-nav-search")
                mode = page.get_by_role("combobox", name="طريقة عرض القائمة")
                mode.select_option("flat")
                assert page.locator("#ffx-group-links-system").is_visible()
                mode.select_option("accordion")
                assert page.locator("#ffx-group-links-system").is_hidden()
                search.fill("التصفير")
                assert page.locator("#ffx-nav [data-key=data_center]").is_visible()
                assert page.locator("#ffx-nav [data-key=home]").is_hidden()
                search.fill("xyz123")
                assert page.get_by_text("لا توجد أقسام مطابقة").is_visible()
                search.fill("")
                assert system_group.get_attribute("aria-expanded") == "false"
                system_group.focus()
                page.keyboard.press("Enter")
                assert system_group.get_attribute("aria-expanded") == "true"
                assert page.locator("#ffx-group-links-system").is_visible()
                entry = page.locator("#ffx-nav [data-key=data_center]")
                entry.click()
                dialog = page.locator("#ff62DataCenter")
                check_width(page, width, "#ff62DataCenter")
                dialog.get_by_role("button", name="عرض ملخص البيانات", exact=False).click()
                dialog.get_by_text("تمت قراءة الملخص", exact=False).wait_for()
                dialog.get_by_role("button", name="إغلاق", exact=True).click()
                # Editing a quick-order draft must invalidate its previous transfer button.
                page.evaluate("""() => {
                  ff49Catalog=[{id:'fixture-chicken',name:'تشكن فرايز',price:2000,active:true}];
                  ff49CatalogAt=Date.now();
                  document.querySelector('#ffbQuickInput').value='1 تشكن بدون شطة';
                  document.querySelector('#ffbApplyText').click();
                }""")
                page.locator("#ffbQuickCommit").wait_for(state="attached")
                page.evaluate("""() => {
                  const old=document.querySelector('#ffbQuickCommit');
                  const input=document.querySelector('#ffbQuickInput');
                  input.value='2 تشكن';
                  input.dispatchEvent(new Event('input',{bubbles:true}));
                  old.click();
                }""")
                assert page.locator("#ffbQuickCommit").count() == 0
                assert page.locator("#newItems").input_value() == ''
                assert page.locator("#ffbQuickInput").input_value() == '2 تشكن'
                # Use the existing assignment controls and capture the mocked submit RPC.
                page.evaluate("""() => {
                  const select=document.querySelector('#newBranch');
                  select.replaceChildren(new Option('فرع القاهرة','qa-cairo',true,true));
                  rpc=async(name,args)=>{
                    if(name==='ff62_get_pinned')return {driver_id:'qa-driver',branch_id:'qa-cairo',driver_name:'موصل اختبار'};
                    if(name==='ff62_cairo_drivers')return [{id:'qa-driver',name:'موصل اختبار'}];
                    if(name==='ff_special_courier_status')return {active:5,capacity:5,can_manage:true};
                    if(name==='ff_confirm_pinned_order'){
                      window.__pinnedPayload=args;
                      throw Error('اختبار معاينة فقط');
                    }
                    return {};
                  };
                  select.dispatchEvent(new Event('change'));
                  document.querySelector('#newPhone').value='777777777';
                  document.querySelector('#newArea').value='منطقة تجريبية';
                  document.querySelector('#newItems').value='1 تشكن';
                }""")
                page.wait_for_function("document.querySelector('#ffpcCapacity').textContent.includes('5 من 5')")
                page.locator('#ffpcDirect').evaluate('b=>b.click()')
                page.locator('#ffPinnedPreview').wait_for(state='visible')
                page.locator('#ffpcConfirm').click()
                assert page.evaluate('window.__pinnedPayload') is None
                page.locator('#ffpcOverrideReason').fill('اعتماد اختبار')
                page.locator('#ffpcConfirm').click()
                page.wait_for_function('!!window.__pinnedPayload')
                payload = page.evaluate('window.__pinnedPayload')
                assert (payload['p_driver'], payload['p_branch'], payload['p_override_reason']) == (
                    'qa-driver', 'qa-cairo', 'اعتماد اختبار')
                page.locator('#ffpcCancel').click()
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
                page.locator("#fflCashierFinishedToggle").evaluate("(el) => el.click()")
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
                page.locator("#fflCashierFinishedToggle").evaluate("(el) => el.click()")
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
                page.wait_for_function("document.getElementById('fflFinishedList')?.textContent.includes('LATEST-FINISHED-ORDER')")
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
                # FF51 legacy archive: reject late results after logout, including branch options.
                page.evaluate("""() => {
                  window.__ff51ArchiveResolvers=[];
                  rpc=(name,args)=>{
                    if(name==='ff51_order_archive')
                      return new Promise(resolve=>window.__ff51ArchiveResolvers.push(resolve));
                    return Promise.resolve([]);
                  };
                  document.getElementById('ff51ArchiveBtn').click();
                }""")
                page.wait_for_function("window.__ff51ArchiveResolvers.length===1")
                page.evaluate("""() => {
                  window.dispatchEvent(new Event('ff-luxe-session-reset'));
                  user=null;data=null;
                  window.__ff51ArchiveResolvers[0]({rows:[{
                    number:'PRIVATE-ARCHIVE-OLD-USER',customer_name:'PRIVATE CUSTOMER',
                    phone:'777888999',status:'delivered',created_at:'2026-11-23T00:00:00Z',
                    total:1250,items:[],changes:[],additions:[],events:[]
                  }],total:1});
                }""")
                page.wait_for_timeout(100)
                assert page.locator("#ff51ArchiveList").inner_text() == ""
                assert page.locator("#ff51ArchiveCount").inner_text() == ""
                assert page.locator("#ff51ArchiveExport").is_disabled()
                # Two overlapping archive searches: the latest filter must win.
                page.evaluate("""() => {
                  user={id:'fixture-new-manager'};data={role:'manager',branches:[],orders:[],drivers:[],offers:[]};
                  window.__ff51ArchiveResolvers=[];
                  document.getElementById('ff51ArchiveBtn').click();
                }""")
                page.wait_for_function("window.__ff51ArchiveResolvers.length===1")
                page.evaluate("""() => {
                  const select=document.getElementById('ff51ArchiveStatus');
                  select.value='delivered';select.dispatchEvent(new Event('change',{bubbles:true}));
                }""")
                page.wait_for_function("window.__ff51ArchiveResolvers.length===2")
                page.evaluate("""() => window.__ff51ArchiveResolvers[1]({
                  rows:[{number:'LATEST-ARCHIVE-RECORD',customer_name:'CURRENT CUSTOMER',
                         phone:'777000000',status:'delivered',created_at:'2026-11-23T00:00:00Z',
                         total:2000,items:[],changes:[],additions:[],events:[]}],total:1
                })""")
                page.wait_for_function("document.getElementById('ff51ArchiveList').textContent.includes('LATEST-ARCHIVE-RECORD')")
                page.evaluate("""() => window.__ff51ArchiveResolvers[0]({
                  rows:[{number:'STALE-ARCHIVE-RECORD',customer_name:'STALE PRIVATE',
                         phone:'777111222',status:'delivered',created_at:'2026-11-23T00:00:00Z',
                         total:2000,items:[],changes:[],additions:[],events:[]}],total:1
                })""")
                page.wait_for_timeout(100)
                assert "LATEST-ARCHIVE-RECORD" in page.locator("#ff51ArchiveList").inner_text()
                assert "STALE-ARCHIVE-RECORD" not in page.locator("#ff51ArchiveList").inner_text()
                page.locator("#ff51ArchiveClose").evaluate("(el) => el.click()")
                assert page.locator("#ff51ArchiveList").inner_text() == ""
                # Customer directory: a delayed response must not repopulate after logout.
                page.evaluate("""() => {
                  window.__ff51CustomerResolvers=[];
                  rpc=name=>name==='ff51_customer_directory'
                    ?new Promise(resolve=>window.__ff51CustomerResolvers.push(resolve))
                    :Promise.resolve([]);
                  document.getElementById('ff51CustomersBtn').click();
                }""")
                page.wait_for_function("window.__ff51CustomerResolvers.length===1")
                page.evaluate("""() => {
                  window.dispatchEvent(new Event('ff-luxe-session-reset'));user=null;data=null;
                  window.__ff51CustomerResolvers[0]([{name:'STALE PRIVATE CUSTOMER',phone:'777123456'}]);
                }""")
                page.wait_for_timeout(100)
                assert page.locator("#ff51CustomersList").inner_text() == ""
                # Customer notes and manager ratings must also reject late responses.
                page.evaluate("""() => {
                  user={id:'fixture-new-manager'};data={role:'manager',branches:[],orders:[],drivers:[],offers:[]};
                  window.__ff51NoteResolve=null;window.__ff51RatingResolve=null;
                  rpc=name=>{
                    if(name==='ff51_customer_notes_list')
                      return new Promise(resolve=>window.__ff51NoteResolve=resolve);
                    if(name==='ff_luxe_rating_summary_period')
                      return new Promise(resolve=>window.__ff51RatingResolve=resolve);
                    return Promise.resolve([]);
                  };
                  document.getElementById('ff51CustomersBtn').click();
                  ff51CustomerNotes('777123456');
                  document.getElementById('ff51RatingsBtn').click();
                }""")
                page.wait_for_function("typeof window.__ff51NoteResolve==='function' && typeof window.__ff51RatingResolve==='function'")
                page.evaluate("""() => {
                  window.dispatchEvent(new Event('ff-luxe-session-reset'));user=null;data=null;
                  window.__ff51NoteResolve([{note:'STALE PRIVATE CUSTOMER NOTE',added_at:'2026-11-23T00:00:00Z'}]);
                  window.__ff51RatingResolve([{name:'STALE PRIVATE RATING',average:4,count:9}]);
                }""")
                page.wait_for_timeout(100)
                assert page.locator("#ff51CustomerNotesList").inner_text() == ""
                assert page.locator("#ff51RatingsList").inner_text() == ""
                assert page.locator("#ff51CustomerNotesSection").is_hidden()
                page.evaluate("""() => {user={id:'fixture-manager'};data={role:'manager',orders:[],branches:[],drivers:[],offers:[]};}""")
                # FF61 delegated permissions must not survive logout or late capability/notification RPCs.
                page.evaluate("""() => {
                  window.dispatchEvent(new Event('ff-luxe-session-reset'));
                  user={id:'fixture-ff61-admin-a'};
                  data={role:'manager',branches:[],orders:[],drivers:[],offers:[]};
                  client={auth:{getSession:async()=>({data:{session:{access_token:'fixture-only'}},error:null})}};
                  window.__ff61CapRequests=[];window.__ff61NotificationRequests=[];
                  const originalFetch=window.fetch;
                  window.__ff61FetchRestored=originalFetch;
                  window.fetch=(url,opts)=>{
                    if(!String(url).includes('/functions/v1/ff61-employees'))return originalFetch(url,opts);
                    const action=JSON.parse(opts.body).action;
                    if(action==='capabilities')return new Promise(resolve=>window.__ff61CapRequests.push(resolve));
                    if(action==='notifications_count')return new Promise(resolve=>window.__ff61NotificationRequests.push(resolve));
                    return Promise.resolve({ok:true,status:200,json:async()=>({ok:true,pending_count:0,ids:[]})});
                  };
                  window.__ff61Respond=(resolve,value)=>resolve({ok:true,status:200,json:async()=>({ok:true,...value})});
                  window.dispatchEvent(new Event('ff-assembly-snapshot-success'));
                }""")
                page.wait_for_function("window.__ff61CapRequests?.length===1")
                page.evaluate("""() => {
                  window.dispatchEvent(new Event('ff-luxe-session-reset'));user=null;data=null;
                  window.__ff61Respond(window.__ff61CapRequests[0],{view:true,approve:true,reject:true,notify:true});
                }""")
                page.wait_for_timeout(100)
                assert page.locator("#ff61ManageShortcut").is_hidden()
                assert page.locator("#ff63NotificationsShortcut").is_hidden()
                assert page.locator("#ff61AdminDialog").is_hidden()
                page.evaluate("""() => {
                  user={id:'fixture-ff61-admin-b'};
                  data={role:'manager',branches:[],orders:[],drivers:[],offers:[]};
                  window.dispatchEvent(new Event('ff-assembly-snapshot-success'));
                }""")
                page.wait_for_function("window.__ff61CapRequests.length===2")
                page.evaluate("""() => window.__ff61Respond(window.__ff61CapRequests[1],
                  {view:true,approve:true,reject:true,notify:true})""")
                page.wait_for_function("!document.getElementById('ff61ManageShortcut').hidden")
                page.wait_for_function("window.__ff61NotificationRequests.length===1")
                page.evaluate("""() => {
                  window.dispatchEvent(new Event('ff-luxe-session-reset'));user=null;data=null;
                  window.__ff61Respond(window.__ff61NotificationRequests[0],{unread_count:99});
                }""")
                page.wait_for_timeout(100)
                assert page.locator("#ff61ManageShortcut").is_hidden()
                assert page.locator("#ff63NotificationsShortcut").is_hidden()
                assert page.locator("#ff63UnreadBadge").inner_text() == "0"
                assert page.locator("#ff61PendingBadge").inner_text() == "0"
                page.evaluate("""() => {
                  window.fetch=window.__ff61FetchRestored||window.fetch;
                  user={id:'fixture-manager'};
                  data={role:'manager',orders:[],branches:[],drivers:[],offers:[]};
                }""")
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
