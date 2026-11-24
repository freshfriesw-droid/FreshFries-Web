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


def check_delivery_review(browser):
    context = browser.new_context(viewport={"width": 390, "height": 800}, service_workers="block")
    context.route("**/*", lambda route: route.continue_() if route.request.url.startswith(origin) else route.abort())
    page = context.new_page()
    page.goto(origin)
    page.evaluate(r"""async () => {
      const el=id=>document.getElementById(id);
      const check=(ok,message)=>{if(!ok)throw Error(message)};
      user={id:'qa-service'};
      data={role:'customer_service',branches:[{id:'branch',code:'cairo'}],orders:[],drivers:[]};
      ff49Catalog=[{id:'fixture',name:'تشكن فرايز',price:100}];
      ff49LoadCatalog=async()=>{};
      reload=async()=>{};
      const submissions=[],predictions=[];
      rpc=async(name,args)=>{
        if(name==='ff_luxe_dispatch_preview'){predictions.push(args);return {state:'waiting'}}
        if(name==='ff27_submit'){
          submissions.push(args.p_input);
          return {order_id:'fixture-order',order_number:1};
        }
        throw Error('Unexpected RPC: '+name);
      };
      const select=el('newBranch');
      select.replaceChildren();
      for(const code of ['cairo_first','cairo_second']){
        const opt=new Option(code,'branch');opt.dataset.ffCashierDesk=code;select.add(opt);
      }
      el('newItems').value='٢ تشكن بدون شطّة\nالعميل: مُحمّد علي\nالعنوان: حيّ الجامعة\nرسوم التوصيل: ٠\nالموصل: أحمد';
      el('newPhone').value='000000000';
      el('newFullAddress').value='شارع الاختبار';
      el('newChannel').value='whatsapp';
      await el('createBtn').onclick();
      check(submissions.length===0 && !el('ffbConfirmLayer').classList.contains('hidden'),'Preview must not save');
      check(el('ffbReviewBody').textContent.includes('مُحمّد علي') && el('ffbReviewBody').textContent.includes('الموصل المطلوب: أحمد'),'Mismatch in contact or notes');
      check(predictions[0].p_area==='حيّ الجامعة','Prediction must use reviewed area');
      select.selectedIndex=1; // Same branch ID, different cashier desk.
      await el('ffbConfirmSave').onclick();
      check(submissions.length===0 && el('ffbConfirmLayer').classList.contains('hidden'),'Stale destination accepted');
      await el('createBtn').onclick();
      await el('ffbConfirmSave').onclick();
      const saved=submissions[0];
      check(submissions.length===1 && saved.p_desk==='cairo_second','Wrong destination or submission count');
      check(saved.p_customer_name==='مُحمّد علي' && saved.p_items[0].item_notes==='بدون شطّة' && saved.p_delivery_fee===0,'Wrong reviewed payload');
      check(saved.p_channel==='whatsapp' && saved.p_full_address==='شارع الاختبار','Missing channel or address');
      check(el('newItems').value==='','Successful save did not clear draft');
    }""")
    context.close()


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(channel="chrome")
    check_delivery_review(browser)
    for width in (320, 344, 360, 390, 430, 768, 850, 851, 1024, 1280, 1440):
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
                  user={id:'fixture-cashier'};
                  data={role:'cashier',orders:[],branches:[],drivers:[],offers:[]};
                  const previousRpc=rpc;
                  rpc=async(name,args)=>{
                    if(name==='ff80_dashboard_metrics')return {role:data.role,business_day:'2026-11-24',orders_today:12,late_today:2,completed_today:7,available_drivers:null};
                    return previousRpc(name,args);
                  };
                }""")
                cashier_link = page.locator("#ffx-mobile-nav [data-key=cashier]")
                cashier_link.wait_for()
                cashier_link.click()
                assert cashier_link.evaluate("el => el.classList.contains('active')")
                page.wait_for_function("document.querySelectorAll(\'#ffx-kpis button[data-ffx-kpi=cashier]\').length===3")
                assert page.locator("[data-ffx-metric=orders_today] .ffx-kpi-value").inner_text() == "12"
                assert page.locator("[data-ffx-metric=late_today] .ffx-kpi-value").inner_text() == "2"
                assert page.locator("[data-ffx-metric=completed_today] .ffx-kpi-value").inner_text() == "7"
                assert page.locator("[data-ffx-metric=available_drivers] .ffx-kpi-value").inner_text() == "—"
                assert page.locator("#ffx-kpis button[data-ffx-kpi=drivers]").count() == 0
                page.evaluate("data.role='driver'")
                page.locator("#ffx-mobile-nav [data-key=driver]").wait_for()
                assert cashier_link.count() == 0
                page.wait_for_function("document.querySelectorAll(\'#ffx-kpis button[data-ffx-kpi=driver]\').length===3")
                assert page.locator("#ffx-kpis [data-ffx-metric]").count() == 4
                assert page.locator("[data-ffx-metric=available_drivers] .ffx-kpi-value").inner_text() == "—"
                page.evaluate("""() => {
                  user={id:'fixture-manager'};
                  data={role:'manager', orders:[], branches:[], drivers:[], offers:[]};
                  rpc=async name=>{
                    if(name==='ff_ui_manager_history'||name==='ff_ui_effective')return [];
                    if(name==='ff81_effective_design')return null;
                    if(name==='ff62_manager_data_overview')return {mode:'read_only',orders:7};
                    throw Error('Unconfigured test fixture');
                  };
                }""")
                page.locator("#ffx-menu").click()
                # FIX-03: administrative links live in a six-group, keyboard-accessible
                # accordion. Verify opening, not just existence of a hidden DOM node.
                nav_groups = page.locator("#ffx-nav [data-ffx-group-toggle]")
                page.locator("#ffx-nav [data-ffx-group-toggle=system]").wait_for(state="attached", timeout=20000)
                assert nav_groups.count() == 6, nav_groups.count()
                system_group = page.locator("#ffx-nav [data-ffx-group-toggle=system]")
                assert system_group.get_attribute("aria-expanded") == "false"
                search = page.locator("#ffx-nav-search")
                mode = page.get_by_role("combobox", name="طريقة عرض القائمة")
                mode.select_option("flat")
                assert page.locator("#ffx-group-links-system").is_visible()
                # Crossing the breakpoint in the same session must load each device's preference.
                for viewport_width, expected_mode in [(1024, "accordion"), (390, "flat")]:
                    page.set_viewport_size({"width": viewport_width, "height": 800})
                    page.wait_for_function(
                        "expected => document.querySelector('#ffx-nav select')?.value === expected",
                        arg=expected_mode,
                    )
                    if page.locator("#ffx-sidebar").is_hidden():
                        page.locator("#ffx-menu").click()
                mode.select_option("accordion")
                assert page.locator("#ffx-group-links-system").is_hidden()
                page.evaluate("""() => {
                  document.getElementById('staffView').classList.remove('hidden');
                  document.getElementById('staffAdminCard').hidden=false;
                }""")
                search.fill("شاشة تحكم المدير العام")
                page.locator("#ffx-nav [data-key=studio]").click()
                studio = page.locator("#ffStudio")
                assert studio.is_visible()
                # DEC-06: edit, duplicate, order, remove, undo, and reset the four real metric types.
                studio.locator("#ffCardEditor summary").click()
                editor = studio.locator("#ffCardEditor")
                rows = editor.locator(".ff-card-edit-row")
                assert rows.count() == 4
                editor.locator("[data-card-add]").click()
                assert rows.count() == 5
                rows.nth(4).locator("select").nth(0).select_option("completed_today")
                rows.nth(4).locator("select").nth(1).select_option("full")
                rows.nth(4).locator("select").nth(2).select_option("black")
                assert editor.locator("[data-card-preview] .ff-card-sample").nth(4).get_attribute("data-card-size") == "full"
                rows.nth(4).get_by_role("button", name="نسخ", exact=True).click()
                assert rows.count() == 6
                rows.nth(5).get_by_role("button", name="تقديم", exact=True).click()
                rows.nth(4).get_by_role("button", name="حذف", exact=True).click()
                assert rows.count() == 5
                editor.locator("[data-card-undo]").click()
                assert rows.count() == 6
                editor.locator("[data-card-default]").click()
                assert rows.count() == 4
                studio.locator("#ffCardEditor summary").click()
                # DEC-03: verify effective published source against concrete role/device scopes.
                page.evaluate("""() => {
                  const before=rpc;
                  rpc=async(name,args)=>{
                    if(name==='ff_ui_manager_source'){
                      if(args.p_role==='cashier'&&args.p_device==='mobile')
                        return [{id:73,role_scope:'cashier',branch_id:null,device:'mobile',pack:'D05',bar:'icons',layout_text:'وصف منشور'}];
                      if(args.p_role==='driver')
                        return new Promise(resolve=>window.__sourceLate=resolve);
                      return [];
                    }
                    return before(name,args);
                  };
                }""")
                studio.locator("select[name=role]").select_option("cashier")
                studio.locator("select[name=device]").select_option("mobile")
                page.wait_for_function("document.querySelector(\'[data-source-pack]\').textContent === \'D05\'")
                assert studio.locator("[data-source-caption]").inner_text() == "وصف منشور"
                assert "#73" in studio.locator("[data-source-status]").inner_text()
                studio.locator("select[name=role]").select_option("driver")
                page.wait_for_function("typeof window.__sourceLate==='function'")
                studio.locator("select[name=role]").select_option("supervisor")
                page.wait_for_function("document.querySelector(\'[data-source-status]\').textContent.includes(\'التصميم الأساسي للنظام\')")
                page.evaluate("window.__sourceLate([{id:999,role_scope:'driver',device:'mobile',pack:'D16',bar:'wide',layout_text:'STALE'}])")
                page.wait_for_timeout(100)
                assert "999" not in studio.locator("[data-source-status]").inner_text()
                assert studio.locator("[data-source-details]").is_hidden()
                studio.locator("select[name=role]").select_option("all")
                studio.locator("select[name=device]").select_option("all")
                # Exercise all approved preview widths, including desktop in a mobile browser.
                for preview_width in (320, 360, 390, 430, 768, 1024, 1440):
                    studio.locator("select[name=viewport]").select_option(str(preview_width))
                    previews = set()
                    for number in range(1, 17):
                        studio.locator("select[name=pack]").select_option(f"D{number:02d}")
                        layout = studio.locator(".ff-design-layout")
                        previews.add(layout.evaluate("el => getComputedStyle(el).gridTemplateAreas"))
                    assert len(previews) == 16, (preview_width, previews)
                studio.locator("select[name=viewport]").select_option("390")
                # DEC-07: all five non-interactive bar previews at each approved phone width.
                for preview_width in (320, 360, 390, 430):
                    studio.locator("select[name=viewport]").select_option(str(preview_width))
                    for bar in ("labels", "icons", "wide", "floating", "compact"):
                        studio.locator("select[name=bar]").select_option(bar)
                        nav = studio.locator(".ff-studio-bar")
                        assert nav.is_visible()
                        assert nav.get_attribute("data-bar") == bar
                        assert nav.locator("button,a,input").count() == 0
                        assert nav.locator(".ff-studio-bar-item:visible").count() >= 2
                        assert nav.locator(".ff-studio-bar-item:visible").evaluate_all(
                            "items => items.every(item => item.getBoundingClientRect().height >= 44)"
                        )
                        assert studio.locator("[data-impact-scope]").is_visible()
                        assert f"{preview_width}px" in studio.locator("[data-impact-scope]").inner_text()
                studio.locator("select[name=bar]").select_option("labels")
                studio.locator("select[name=viewport]").select_option("1440")
                assert studio.locator(".ff-studio-bar").is_hidden()
                studio.locator("select[name=viewport]").select_option("390")
                # DEC-09 phase 1: manager edits a fixed text key without replacing the operational button.
                page.evaluate("""() => {
                  window.__contentOriginalRpc=rpc;
                  window.__contentCalls=[];
                  window.__contentHistory=[];
                  window.__contentEffective=[];
                  window.__contentOriginalNode=document.querySelector('#ffx-hero-new');
                  rpc=async(name,args)=>{
                    if(name==='ff_content_catalog_list')return [{key:'dashboard.new',screen:'dashboard',label:'زر طلب جديد',original:'طلب جديد'}];
                    if(name==='ff_content_history')return window.__contentHistory;
                    if(name==='ff_content_effective')return window.__contentEffective;
                    if(name==='ff_content_create_draft'){
                      window.__contentCalls.push(args);
                      window.__contentHistory=[{id:1,content_key:args.p_key,role_scope:args.p_role,branch_id:args.p_branch,body:args.p_body,actor_id:'manager-fixture',created_at:'2026-11-24T12:00:00Z'}];
                      return 1;
                    }
                    if(name==='ff_content_publish'){
                      window.__contentHistory[0].published_at='2026-11-24T12:01:00Z';
                      window.__contentEffective=[{content_key:'dashboard.new',body:window.__contentHistory[0].body,revision:1}];
                      return null;
                    }
                    return window.__contentOriginalRpc(name,args);
                  };
                }""")
                studio.locator("#ffContentOpen").click()
                content = page.locator("#ffContentStudio")
                assert content.is_visible()
                content.locator("[data-content-key] option").wait_for(state="attached")
                assert content.locator("[data-content-key]").is_visible()
                check_width(page, width, "#ffContentStudio")
                content.locator("[data-content-body]").fill("<script>مرفوض</script>")
                content.locator("[data-content-save]").click()
                assert page.evaluate("window.__contentCalls.length") == 0
                content.locator("[data-content-body]").fill("طلب جديد تجريبي")
                content.locator("[data-content-save]").click()
                content.locator("[data-content-history] option").wait_for(state="attached")
                assert content.locator("[data-content-history]").is_visible()
                assert content.locator("[data-content-preview]").inner_text() == "طلب جديد تجريبي"
                assert "طلب جديد تجريبي" not in page.locator("#ffx-hero-new").text_content()
                page.once("dialog", lambda prompt: prompt.accept())
                content.locator("[data-content-publish]").click()
                page.wait_for_function("document.querySelector('#ffx-hero-new').textContent.includes('طلب جديد تجريبي')")
                assert page.evaluate("window.__contentOriginalNode===document.querySelector('#ffx-hero-new')")
                assert page.locator("#ffx-hero-new svg").count() == 1
                content.locator("[data-content-close]").click()
                page.evaluate("""() => {
                  rpc=window.__contentOriginalRpc;
                  window.dispatchEvent(new Event('ff-luxe-session-reset'));
                  data.role='cashier';
                  window.ffContentStudio.open();
                }""")
                assert content.is_hidden()
                assert "طلب جديد تجريبي" not in page.locator("#ffx-hero-new").text_content()
                # DEC-10: manager grant/revoke and staff draft/review; revoked UI closes.
                page.evaluate("""() => {
                  const old=rpc;window.__qaDelegation=null;window.__qaDelegationCalls=[];
                  rpc=async(name,args)=>{
                    if(name==='ff82_manager_accounts')return [{user_id:'fixture-delegate',role:'cashier',display_name:'موظف اختبار',branch_id:'qa-branch',branch_name:'القاهرة'}];
                    if(name==='ff82_manager_grants')return window.__qaDelegation?[window.__qaDelegation]:[];
                    if(name==='ff82_manager_audit')return [];
                    if(name==='ff82_set_grant'){
                      window.__qaDelegationCalls.push(args);
                      window.__qaDelegation={id:82,recipient:args.p_recipient,role_scope:'cashier',branch_id:args.p_branch,screen:args.p_screen,capabilities:args.p_capabilities,starts_at:args.p_start,ends_at:args.p_end};
                      return 82;
                    }
                    if(name==='ff82_revoke_grant'){window.__qaDelegation=null;return true}
                    if(name==='ff82_my_grant')return window.__qaDelegation?[window.__qaDelegation]:[];
                    if(name==='ff82_delegate_catalog')return [{key:'dashboard.new',label:'طلب جديد',original:'طلب جديد',screen:'dashboard'}];
                    if(name==='ff82_delegate_history')return [{id:83,body:'مسودة مراجعة',published_at:null}];
                    if(name==='ff82_delegate_draft'){window.__qaDelegationCalls.push(args);return {ok:true,revision:84}}
                    if(name==='ff82_delegate_review'){window.__qaDelegationCalls.push(args);return {ok:true}}
                    return old(name,args);
                  };
                  data.role='manager';window.ffContentDelegation.sync(true);
                }""")
                page.locator("#ff82Open").click()
                delegation=page.locator("#ff82Delegation")
                delegation.locator("[data-d-account] option").wait_for(state="attached")
                check_width(page,width,"#ff82Delegation")
                for capability in ("edit","preview","review"):
                    delegation.locator(f"[data-d-caps] input[value={capability}]").check()
                page.once("dialog",lambda prompt:prompt.accept())
                delegation.locator("[data-d-grant]").click()
                page.wait_for_function("document.querySelector('[data-d-status]').textContent.includes('#82')")
                assert page.evaluate("window.__qaDelegationCalls[0].p_capabilities.length") == 4
                assert delegation.locator("[data-d-screen] option[value=notices]").count() == 1
                delegation.locator("[data-d-close]").click()
                page.evaluate("""async () => {
                  user={id:'fixture-delegate'};data.role='cashier';
                  await window.ffContentDelegation.sync(true);
                }""")
                page.locator("#ff82Open").click()
                delegation.locator("[data-d-key] option").wait_for(state="attached")
                assert delegation.locator("[data-d-manager]").is_hidden()
                assert delegation.locator("[data-d-edit]").is_visible()
                assert delegation.locator("[data-d-text]").get_attribute("maxlength") == "180"
                assert delegation.locator("[data-d-format-help]").is_hidden()
                delegation.locator("[data-d-text]").fill("مسودة موظف")
                delegation.locator("[data-d-save]").click()
                page.wait_for_function("document.querySelector('[data-d-status]').textContent.includes('#84')")
                delegation.locator("[data-d-note]").fill("مراجعة اختبارية")
                delegation.locator("[data-d-send-review]").click()
                page.wait_for_function("document.querySelector('[data-d-status]').textContent.includes('تم إرسال المراجعة')")
                page.evaluate("""async () => {window.__qaDelegation=null;await window.ffContentDelegation.sync(true)}""")
                assert delegation.is_hidden()
                assert page.locator("#ff82Open").is_hidden()
                page.evaluate("""() => {user={id:'fixture-manager'};data.role='manager';window.ffContentDelegation.sync(true)}""")
                page.evaluate("data.role='manager'")
                page.evaluate("""async () => {
                  window.__noticeOriginalRpc=rpc;
                  rpc=async(name,args)=>{
                    if(name==='ff_content_effective')return [{content_key:'notices.delayed',body:'تنبيه #{order_number}',revision:88}];
                    return window.__noticeOriginalRpc(name,args);
                  };
                  await window.ffContentStudio.sync(true);
                }""")
                assert page.evaluate("window.ffContentStudio.notice('notices.delayed','fallback',990001,null)") == "تنبيه #990001"
                assert page.evaluate("window.ffContentStudio.notice('notices.delayed','fallback','<script>',null)") == "تنبيه #—"
                assert page.evaluate("window.ffContentStudio.notice('notices.unknown','fallback',990001,null)") == "fallback"
                page.evaluate("window.dispatchEvent(new Event('ff-luxe-session-reset'))")
                assert page.evaluate("window.ffContentStudio.notice('notices.delayed','fallback',990001,null)") == "fallback"
                page.evaluate("() => {rpc=window.__noticeOriginalRpc;}")
                # DEC-10: manager grant/revoke and staff draft/review; revoked UI closes.
                page.evaluate("""() => {
                  const old=rpc;window.__qaDelegation=null;window.__qaDelegationCalls=[];
                  rpc=async(name,args)=>{
                    if(name==='ff82_manager_accounts')return [{user_id:'fixture-delegate',role:'cashier',display_name:'موظف اختبار',branch_id:'qa-branch',branch_name:'القاهرة'}];
                    if(name==='ff82_manager_grants')return window.__qaDelegation?[window.__qaDelegation]:[];
                    if(name==='ff82_manager_audit')return [];
                    if(name==='ff82_set_grant'){
                      window.__qaDelegationCalls.push(args);
                      window.__qaDelegation={id:82,recipient:args.p_recipient,role_scope:'cashier',branch_id:args.p_branch,screen:args.p_screen,capabilities:args.p_capabilities,starts_at:args.p_start,ends_at:args.p_end};
                      return 82;
                    }
                    if(name==='ff82_revoke_grant'){window.__qaDelegation=null;return true}
                    if(name==='ff82_my_grant')return window.__qaDelegation?[window.__qaDelegation]:[];
                    if(name==='ff82_delegate_catalog')return [{key:'dashboard.new',label:'طلب جديد',original:'طلب جديد',screen:'dashboard'}];
                    if(name==='ff82_delegate_history')return [{id:83,body:'مسودة مراجعة',published_at:null}];
                    if(name==='ff82_delegate_draft'){window.__qaDelegationCalls.push(args);return {ok:true,revision:84}}
                    if(name==='ff82_delegate_review'){window.__qaDelegationCalls.push(args);return {ok:true}}
                    return old(name,args);
                  };
                  data.role='manager';window.ffContentDelegation.sync(true);
                }""")
                page.locator("#ff82Open").click()
                delegation=page.locator("#ff82Delegation")
                delegation.locator("[data-d-account] option").wait_for(state="attached")
                check_width(page,width,"#ff82Delegation")
                for capability in ("edit","preview","review"):
                    delegation.locator(f"[data-d-caps] input[value={capability}]").check()
                page.once("dialog",lambda prompt:prompt.accept())
                delegation.locator("[data-d-grant]").click()
                page.wait_for_function("document.querySelector('[data-d-status]').textContent.includes('#82')")
                assert page.evaluate("window.__qaDelegationCalls[0].p_capabilities.length") == 4
                delegation.locator("[data-d-close]").click()
                page.evaluate("""async () => {
                  user={id:'fixture-delegate'};data.role='cashier';
                  await window.ffContentDelegation.sync(true);
                }""")
                page.locator("#ff82Open").click()
                delegation.locator("[data-d-key] option").wait_for(state="attached")
                assert delegation.locator("[data-d-manager]").is_hidden()
                assert delegation.locator("[data-d-edit]").is_visible()
                delegation.locator("[data-d-text]").fill("مسودة موظف")
                delegation.locator("[data-d-save]").click()
                page.wait_for_function("document.querySelector('[data-d-status]').textContent.includes('#84')")
                delegation.locator("[data-d-note]").fill("مراجعة اختبارية")
                delegation.locator("[data-d-send-review]").click()
                page.wait_for_function("document.querySelector('[data-d-status]').textContent.includes('تم إرسال المراجعة')")
                page.evaluate("""async () => {window.__qaDelegation=null;await window.ffContentDelegation.sync(true)}""")
                assert delegation.is_hidden()
                assert page.locator("#ff82Open").is_hidden()
                page.evaluate("""() => {user={id:'fixture-manager'};data.role='manager';window.ffContentDelegation.sync(true)}""")
                page.evaluate("data.role='manager'")
                page.locator("#ffx-menu").click()
                search.fill("إدارة نقطة التجميع")
                page.locator("#ffx-nav [data-key=assembly_admin]").click()
                assert page.locator("#staffAdminCard > .ffl-fold-toggle").get_attribute("aria-expanded") == "true"
                assert page.locator("#staffAdminList").is_visible()
                page.locator("#ffx-menu").click()
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
                # FIX-18: preserve deliberate section choices and reject old approvals for the same filter.
                page.evaluate("""() => {
                  user={id:'fixture-manager'};
                  data={role:'manager',orders:[],branches:[],drivers:[],offers:[]};
                  const snapshot={role:'manager',from:'2026-11-24',to:'2026-11-24',scope:'اختبار',
                    available_sections:['summary','finance','approval'],branches:[],driver_options:[],
                    totals:{orders:7,delivered:4,item_sales:900,delivery_fees:100,net:1000}};
                  rpc=(name,args)=>{
                    if(name==='ff76_reporting_center')return Promise.resolve({...snapshot,from:args.p_from,to:args.p_to});
                    if(name==='ff_report_preset_list')return Promise.resolve([]);
                    if(name==='ff76_report_approval_save')return new Promise(resolve=>{window.__oldApproval=resolve});
                    return Promise.resolve([]);
                  };
                  window.ff76OpenReports();
                }""")
                page.wait_for_function("!document.getElementById('ff76Run').disabled && !!document.querySelector('#ff76Body section')")
                page.locator("#ff76Mode").select_option("custom")
                for box in page.locator("#ff76Choices input").all():
                    box.uncheck()
                page.locator("#ff76Mode").select_option("full")
                page.locator("#ff76Mode").select_option("custom")
                assert page.locator("#ff76Choices input:checked").count() == 0
                assert page.locator("#ff76CSV").is_disabled()
                page.locator("#ff76Choices input[value=finance]").check()
                assert page.locator("#ff76Body section").count() == 1
                assert "رسوم التوصيل المستحقة" in page.locator("#ff76Body").inner_text()
                page.locator("#ff76ManagerName").fill("مدير تجريبي")
                page.locator("#ff76ManagerNotes").fill("ملاحظة لم تحفظ")
                page.locator("#ff76Trend").select_option("weekly")
                assert page.locator("#ff76ManagerNotes").input_value() == "ملاحظة لم تحفظ"
                page.locator("#ff76SaveApproval").click()
                page.wait_for_function("typeof window.__oldApproval==='function'")
                page.locator("#ff76Run").click()
                page.wait_for_function("!document.getElementById('ff76Run').disabled && !!document.querySelector('#ff76Body section')")
                page.evaluate("""() => window.__oldApproval({manager_name:'STALE-APPROVAL',
                    notes:'STALE-APPROVAL-NOTES',approved_at:'2026-11-24T10:00:00Z'})""")
                page.wait_for_timeout(100)
                assert page.locator("#ff76ManagerName").input_value() == ""
                assert page.locator("#ff76ManagerNotes").input_value() == ""
                assert page.locator("#ff76ApprovalStatus").inner_text() == ""
                page.locator("#ff76Close").click()
                assert page.locator("#ff76Body").inner_text() == ""
                assert page.locator("#ff76CSV").is_disabled()
                # Operational alerts: a slower response from another branch must never appear.
                page.evaluate("""() => {
                  user={id:'fixture-manager'};
                  data={role:'manager',orders:[],drivers:[],offers:[],branches:[{id:'qa-cairo',name:'القاهرة'},{id:'qa-sam',name:'سام مول'}]};
                  document.querySelector('#ff40AlertsBtn').classList.remove('hidden');
                  const select=document.querySelector('#ffx-branch');
                  select.replaceChildren(new Option('القاهرة','qa-cairo'),new Option('سام مول','qa-sam'));
                  rpc=(name,args)=>{
                    if(name==='ff40_operations_alerts'){
                      if(args.p_branch==='qa-cairo')return new Promise(resolve=>window.__oldAlerts=resolve);
                      return Promise.resolve({items:[{kind:'late',order_id:'new-alert',order_number:'NEW-BRANCH-ALERT',title:'تنبيه',description:'اختبار',severity:1,age_minutes:65}]});
                    }
                    return Promise.resolve([]);
                  };
                  select.value='qa-cairo';select.dispatchEvent(new Event('change'));
                }""")
                page.wait_for_function("typeof window.__oldAlerts==='function'")
                page.evaluate("""() => {
                  const select=document.querySelector('#ffx-branch');
                  select.value='qa-sam';select.dispatchEvent(new Event('change'));
                }""")
                page.wait_for_function("document.querySelector('#ffx-overdue-list').textContent.includes('NEW-BRANCH-ALERT')")
                page.evaluate("""() => window.__oldAlerts({items:[{kind:'late',order_id:'old-alert',order_number:'PRIVATE-OLD-BRANCH-ALERT',title:'تنبيه',description:'اختبار',severity:3}]})""")
                page.wait_for_timeout(100)
                assert "PRIVATE-OLD-BRANCH-ALERT" not in page.locator("#ffx-overdue-list").inner_text()
                assert "NEW-BRANCH-ALERT" in page.locator("#ffx-overdue-list").inner_text()
                page.evaluate("window.dispatchEvent(new Event('ff-luxe-session-reset'))")
                assert "NEW-BRANCH-ALERT" not in page.locator("#ffx-overdue-list").inner_text()
                assert page.locator("#ffx-overdue-count").inner_text() == "—"
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
