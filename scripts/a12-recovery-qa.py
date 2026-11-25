"""A12 Chromium isolated test: branch/date/type, stale/blocked preview, exact server-confirmed recovery, role isolation."""
import ast
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright,expect
root=Path(__file__).resolve().parents[1]
out=root/'a12-evidence';out.mkdir(exist_ok=True)
fixture=next(ast.literal_eval(n.value) for n in ast.parse((root/'scripts/a10-report-qa.py').read_text()).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='fixture' for t in n.targets))
fixture=fixture.replace("window.__a06Calls.push({name,args});", """window.__a06Calls.push({name,args});
 if(name==='ff_a12_reset_batches')return window.a12Batches||[];
 if(name==='ff_a12_reset_preview')return {counts:{orders:1,items:1,events:1,desks:1},total_orders:82,protected_orders:81,orders:[{id:'test1',number:-1,type:'delivery',date:args.p_from}],blockers:window.a12Blocked?{'public.ff_push_jobs':1}:{},token:'token-'+args.p_branch+'-'+args.p_from};
 if(name==='ff_a12_reset_execute'){
  window.a12Reset=args;window.a12Batches=[{id:'batch1',branch_id:args.p_branch,order_type:args.p_type,date_from:args.p_from,date_to:args.p_to,counts:{orders:1,items:1,events:1,desks:1},restored_at:null}];
  return {ok:true,backup_saved:true,batch_id:'batch1',removed:{orders:1,items:1,events:1,desks:1},remaining_selected:{orders:0,items:0,events:0,desks:0},total_before:82,total_after:81};
 }
 if(name==='ff_a12_restore'){window.a12Restored=args;window.a12Batches[0].restored_at='2026-11-25';return {ok:true,exact_match:true,restored:{orders:1,items:1,events:1,desks:1}}}
 if(name==='ff_a12_create_fixture'){window.a12Fixture=args;return {test_only:true,number:-2}}
 """)
server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory=root));Thread(target=server.serve_forever,daemon=True).start()
origin=f'http://127.0.0.1:{server.server_port}/'
with sync_playwright() as pw:
 browser=pw.chromium.launch(channel='chrome')
 ctx=browser.new_context(viewport={'width':390,'height':850},service_workers='block',reduced_motion='reduce')
 ctx.route('**/*',lambda r:r.continue_() if r.request.url.startswith(origin) else r.abort())
 page=ctx.new_page();page.on('dialog',lambda d:d.accept());page.goto(origin,wait_until='load');page.evaluate(fixture,'manager')
 page.evaluate("document.getElementById('ff62DataCenter').showModal()")
 expect(page.locator('#ffA12Recovery')).to_be_visible()
 expect(page.locator('#ffA12List')).to_be_enabled()
 expect(page.locator('#ffA12Execute')).to_be_disabled()
 page.locator('#ffA12Branch').select_option('b1');page.locator('#ffA12Type').select_option('delivery')
 page.locator('#ffA12Preview').click();expect(page.locator('#ffA12PreviewResult')).to_contain_text('81')
 page.locator('#ffA12Confirm').fill('تصفير طلبات الاختبار فقط');expect(page.locator('#ffA12Execute')).to_be_enabled()
 page.locator('#ffA12Branch').select_option('b2');expect(page.locator('#ffA12Execute')).to_be_disabled()
 page.evaluate('window.a12Blocked=true')
 page.locator('#ffA12Preview').click();expect(page.locator('#ffA12PreviewResult')).to_contain_text('ff_push_jobs')
 page.locator('#ffA12Confirm').fill('تصفير طلبات الاختبار فقط');expect(page.locator('#ffA12Execute')).to_be_disabled()
 page.evaluate('window.a12Blocked=false')
 page.locator('#ffA12Preview').click();expect(page.locator('#ffA12PreviewResult')).to_contain_text('سيحفظ الخادم')
 page.locator('#ffA12Confirm').fill('تصفير طلبات الاختبار فقط');page.locator('#ffA12Execute').click()
 expect(page.locator('#ffA12PreviewResult')).to_contain_text('batch1')
 assert page.evaluate("window.a12Reset.p_branch")=='b2' and page.evaluate("window.a12Reset.p_type")=='delivery'
 expect(page.locator('#ffA12Batch')).to_have_value('batch1')
 expect(page.locator('#ffA12Restore')).to_be_disabled()
 page.locator('#ffA12RestoreConfirm').fill('استرجاع نسخة الاختبار');page.locator('#ffA12Restore').click()
 expect(page.locator('#ffA12PreviewResult')).to_contain_text('التطابق الكامل')
 expect(page.locator('#ffA12BatchInfo')).to_contain_text('سبق استرجاعها')
 expect(page.locator('#ffA12Restore')).to_be_disabled()
 page.locator('#ffA12Recovery summary').click()
 page.locator('#ffA12FixtureConfirm').fill('إنشاء طلب اختبار');page.locator('#ffA12Fixture').click()
 expect(page.locator('#ffA12PreviewResult')).to_contain_text('#-2')
 for width in (320,390,768,1440):
  page.set_viewport_size({'width':width,'height':850});page.screenshot(path=out/f'recovery-{width}.png',animations='disabled')
 page.evaluate("()=>{window.dispatchEvent(new Event('ff-luxe-session-reset'));user=null;data=null}")
 expect(page.locator('#ffA12Recovery')).to_be_hidden()
 assert page.locator('#ffA12Batch').input_value()=='' and page.locator('#ffA12PreviewResult').text_content()==''
 p=ctx.new_page();p.goto(origin,wait_until='load');p.evaluate(fixture,'cashier')
 p.evaluate("document.getElementById('ff62DataCenter').showModal()")
 expect(p.locator('#ffA12Recovery')).to_be_hidden()
 assert not p.evaluate("window.__a06Calls.some(x=>x.name.startsWith('ff_a12_'))")
 print('PASS A12 isolated responsive manager recovery, blocked/stale preview, confirmation, exact restore, session clearing and nonmanager isolation')
 ctx.close();browser.close()
server.shutdown()
