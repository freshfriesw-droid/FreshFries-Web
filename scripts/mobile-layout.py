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


def check_width(page, width, selector):
    box = page.locator(selector).first.bounding_box()
    assert box and box["x"] >= -1 and box["x"] + box["width"] <= width + 1, (width, selector, box)


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
        for selector in ("main", "#ffx-topbar", "#ff61ManageShortcut", "#ff63NotificationsShortcut", "#ffx-options"):
            check_width(page, width, selector)
        if width <= 850:
            assert page.evaluate("document.documentElement.scrollWidth") == width, width
            assert page.locator("#ffx-sidebar").is_hidden()
            check_width(page, width, "#ffx-mobile-nav")
            for trigger, close in (("#ffx-menu", "#ffx-drawer-close"), ("button[data-key=more]", None)):
                page.locator(trigger).click()
                check_width(page, width, "#ffx-sidebar")
                if close:
                    page.locator(close).click()
                else:
                    page.keyboard.press("Escape")
                assert page.locator("#ffx-sidebar").is_hidden()
            page.locator("#ffx-options").click()
            check_width(page, width, "#ffx-preferences")
            page.locator("#ffx-pref-close").click()
            assert page.locator("#ffx-preferences").is_hidden()
            page.locator("#ffx-menu").click()
            page.set_viewport_size({"width":1100, "height":700})
            page.wait_for_function("!document.body.classList.contains('ffx-menu-open')")
            assert page.locator("#ffx-dimmer").is_hidden()
        else:
            assert page.locator("#ffx-sidebar").is_visible()
        print(f"PASS {width}px", flush=True)
        context.close()
    browser.close()
server.shutdown()
