"""A02 customer UI regression using shipped script in real Chromium.
All auth and order responses are synthetic; no network, SMS or real accounts.
"""
from pathlib import Path
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
html=(root/"index.html").read_text(encoding="utf-8")
start=html.index('<script id="ff71-customer-phone-otp">')+len('<script id="ff71-customer-phone-otp">')
otp=html[start:html.index("</script>",start)]
portal=html[html.index("let ff28Epoch=0,"):html.index("function ff28Credentials(")]
with sync_playwright() as pw:
    browser=pw.chromium.launch(channel="chrome")
    for width in (390,1280):
        context=browser.new_context(viewport={"width":width,"height":800},service_workers="block")
        context.route("**/*",lambda route:route.abort())
        page=context.new_page()
        page.set_content("""<button id="ff71CustomerToggle">فتح</button>
          <div id="ff71CustomerPanel" class="hidden">
            <input id="ff71CustomerPhone"><input id="ff71CustomerCode">
            <button id="ff71CustomerSend">إرسال</button><button id="ff71CustomerVerify">تأكيد</button>
            <p id="ff71CustomerMessage"></p>
          </div><style>.hidden{display:none}</style>
          <div id="ff28Rows"></div><div id="ff28State"></div><input id="ff28Name"><form id="ff28Apply"></form>""")
        page.add_script_tag(content="""window.__now=Date.now();Date.now=()=>window.__now;
          window.__sent=[];window.__verified=[];window.__sessions=[];
          window.client={auth:{
            signInWithOtp:async a=>{window.__sent.push(a);if(window.__delaySend)return await new Promise(resolve=>window.__resolveSend=resolve);return {error:null}},
            verifyOtp:async a=>{window.__verified.push(a);return {data:{session:{user:{id:'fixture'}}},error:null}}
          }};
          window.setSession=async session=>{window.__sessions.push(session);window.dispatchEvent(new Event('ff-luxe-session-reset'))};
          window.$=id=>document.getElementById(id);
        """)
        page.add_script_tag(content=otp)
        page.locator("#ff71CustomerToggle").click()
        phone=page.locator("#ff71CustomerPhone")
        code=page.locator("#ff71CustomerCode")
        send=page.locator("#ff71CustomerSend")
        verify=page.locator("#ff71CustomerVerify")
        phone.fill("٧٧٧١٢٣٤٥٦")
        send.click()
        page.wait_for_function("window.__sent.length===1")
        assert page.evaluate("window.__sent[0].phone")=="+967777123456"
        code.fill("123456")
        phone.fill("٧٧٧١٢٣٤٥٧")
        assert code.input_value()==""
        code.fill("123456")
        verify.click()
        assert page.evaluate("window.__verified.length")==0
        page.evaluate("window.__now+=91000")
        send.click()
        page.wait_for_function("window.__sent.length===2")
        code.fill("۱۲۳۴۵۶")
        verify.click()
        page.wait_for_function("window.__sessions.length===1")
        assert page.evaluate("window.__verified[0]")=={"phone":"+967777123457","token":"123456","type":"sms"}
        assert phone.input_value()=="" and code.input_value()==""
        assert page.locator("#ff71CustomerPanel").is_hidden()
        page.locator("#ff71CustomerToggle").click()
        phone.fill("777123458")
        page.evaluate("window.__now+=91000;window.__delaySend=true")
        send.click()
        page.wait_for_function("typeof window.__resolveSend==='function'")
        assert phone.is_disabled() and verify.is_disabled()
        page.evaluate("window.dispatchEvent(new Event('ff-luxe-session-reset'));window.__resolveSend({error:null})")
        page.wait_for_function("!document.getElementById('ff71CustomerSend').disabled")
        page.locator("#ff71CustomerToggle").click()
        code.fill("123456")
        verify.click()
        assert page.evaluate("window.__verified.length")==1
        # Shipped customer portal renderer: verify rating binding and stale
        # account response suppression, not server authorization.
        page.add_script_tag(content="""window.__account='A';window.__ratings=[];
          window.__delayPortal=false;
          window.rpc=async(name,args)=>{
            if(name!=='ff28_customer')throw Error('unexpected RPC');
            if(args?.p_order){window.__ratings.push(args);window.__rated=true}
            if(window.__delayPortal){window.__delayPortal=false;return await new Promise(resolve=>window.__resolvePortal=resolve)}
            return window.__account==='A'?[{id:'A-only',order_number:111,status:'delivered',total:1000,rating:window.__rated?4:null}]:
              [{id:'B-only',order_number:222,status:'new',total:500,rating:null}];
          };
        """)
        page.add_script_tag(content=portal)
        page.evaluate("document.body.dataset.access='customer';ff28PortalLoad()")
        assert "111" in page.locator("#ff28Rows").inner_text()
        page.get_by_label("تقييم الطلب").select_option("4")
        page.get_by_role("button",name="إرسال التقييم").click()
        page.wait_for_function("document.getElementById('ff28Rows').textContent.includes('تقييمك 4')")
        assert page.evaluate("window.__ratings")==[{"p_order":"A-only","p_stars":4}]
        assert page.get_by_role("button",name="إرسال التقييم").count()==0
        page.evaluate("window.__delayPortal=true;void ff28PortalLoad()")
        page.wait_for_function("typeof window.__resolvePortal==='function'")
        page.evaluate("ff28Lock();window.__account='B';document.body.dataset.access='customer';ff28PortalLoad()")
        page.evaluate("window.__resolvePortal([{id:'A-old',order_number:999,status:'new',total:1}])")
        page.wait_for_function("document.getElementById('ff28Rows').textContent.includes('222')")
        assert "999" not in page.locator("#ff28Rows").inner_text()
        assert "111" not in page.locator("#ff28Rows").inner_text()
        page.evaluate("ff28Lock()")
        assert page.locator("#ff28Rows").inner_text()==""
        print(f"PASS {width}px: OTP phone binding, Arabic digits, session reset, rating, stale-account privacy",flush=True)
        context.close()
    browser.close()
