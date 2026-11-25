"""A11 isolated Chromium QA; all RPCs mocked, never write production data."""
import ast
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright,expect
root=Path(__file__).resolve().parents[1]
fixture=next(ast.literal_eval(n.value) for n in ast.parse((root/'scripts/a10-report-qa.py').read_text()).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='fixture' for t in n.targets))
fixture=fixture.replace("window.__a06Calls.push({name,args});", """window.__a06Calls.push({name,args});
 if(name==='ff_a11_message_access')return {manager:role==='manager'&&!window.a11Revoked,can_send:role==='manager'&&!window.a11Revoked,branches:[b,b2]};
 if(name==='ff_a11_message_preview')return {ok:true,count:2,people:[{user_id:'u1',display_name:'QA one',role:'cashier'},{user_id:'u2',display_name:'QA two',role:'cashier'}]};
 if(name==='ff_a11_message_send'){window.a11Sent=args;return {ok:true,recipients:args.p_expected.length,message_id:'m1'}}
 if(name==='ff_a11_message_templates')return [{id:'t1',name:'QA template',title:'QA saved',body:'saved body',priority:'urgent',requires_ack:true,internal_route:'messages'}];
 if(name==='ff_a11_message_template_save'){window.a11Template=args;return {ok:true}}
 if(name==='ff_a11_message_history')return [{id:'m1',title:'QA proof',sender:'QA',created_at:new Date().toISOString(),role:'cashier',priority:'urgent',recipients:3,push_accepted_count:1,push_unverified_count:1,push_unavailable_count:1,read_count:0,ack_count:0}];
 if(name==='ff_a11_message_grants')return {staff:[{id:'u1',name:'QA cashier',role:'cashier'}],grants:[]};
 if(name==='ff_a11_message_grant'){window.a11Grant=args;return {ok:true}}
 if(name==='ff39_inbox')return {items:window.a11Inbox||[],unread_count:(window.a11Inbox||[]).length,pending_ack_count:0};
 """)
server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory=root));Thread(target=server.serve_forever,daemon=True).start()
origin=f'http://127.0.0.1:{server.server_port}/'
with sync_playwright() as pw:
 browser=pw.chromium.launch(channel='chrome')
 ctx=browser.new_context(viewport={'width':390,'height':850},service_workers='block')
 ctx.route('**/*',lambda r:r.continue_() if r.request.url.startswith(origin) else r.abort())
 page=ctx.new_page();page.goto(origin,wait_until='load');page.evaluate(fixture,'manager')
 page.wait_for_function("()=>window.__a06Calls.some(x=>x.name==='ff_a11_message_access')")
 page.evaluate("()=>{document.getElementById('ff39Panel').classList.remove('hidden');document.getElementById('ff39InboxBtn').click();document.getElementById('ff39Panel').classList.remove('hidden')}")
 expect(page.locator('#ffA11Preview')).to_be_visible()
 page.locator('#ff39Role').select_option('cashier');page.locator('#ff39Branch').select_option('b1')
 page.locator('#ff39Title').fill('QA test');page.locator('#ff39Body').fill('<img src=x onerror=alert(1)>')
 expect(page.locator('#ffA11MobilePreview')).to_contain_text('<img src=x onerror=alert(1)>')
 assert page.locator('#ffA11MobilePreview img').count()==0
 expect(page.locator('#ff39Send')).to_be_disabled()
 page.locator('#ffA11Preview').click();expect(page.locator('#ffA11Audience input')).to_have_count(2)
 page.locator('#ffA11Audience input').nth(1).uncheck();page.locator('#ff39Send').click()
 page.wait_for_function('()=>!!window.a11Sent')
 assert page.evaluate('window.a11Sent.p_people')==['u1'] and page.evaluate('window.a11Sent.p_expected')==['u1']
 expect(page.locator('#ff39Send')).to_be_disabled()
 expect(page.locator('#ff39SentLog')).to_contain_text('قبول مزود Push المثبت (ليس مشاهدة): 1')
 expect(page.locator('#ff39SentLog')).to_contain_text('سجل Push قديم غير مؤكد: 1')
 expect(page.locator('#ff39SentLog')).to_contain_text('لا جهاز مؤهل: 1')
 page.locator('#ffA11Template').select_option('t1');expect(page.locator('#ff39Title')).to_have_value('QA saved')
 page.locator('#ffA11TemplateSave').click();page.wait_for_function('()=>!!window.a11Template')
 assert page.evaluate('window.a11Template.p_priority')=='urgent'
 page.locator('#ffA11GrantBox summary').click();page.locator('#ffA11GrantUser').select_option('u1');page.locator('#ffA11GrantRole').select_option('cashier');page.locator('#ffA11GrantBranch').select_option('b1');page.locator('#ffA11GrantPriority').select_option('operational');page.locator('#ffA11GrantSave').click();page.wait_for_function('()=>!!window.a11Grant')
 assert page.evaluate('window.a11Grant.p_branch')=='b1'
 # Real offline browser context: neither recipient data nor audio is synthesized while disconnected.
 ctx.set_offline(True)
 page.evaluate("()=>localStorage.setItem('freshfries_luxe_prefs_'+user.id,JSON.stringify({visual:false,audio:false}))")
 page.evaluate("""()=>{window.a11Inbox=[{id:'m2',title:'QA incoming',body:'Stored on server',sender:'QA',created_at:new Date().toISOString(),priority:'urgent',requires_ack:true}];window.dispatchEvent(new Event('offline'))}""")
 expect(page.locator('#ff39InboxStatus')).to_contain_text('غير متصل')
 assert 'QA incoming' not in page.locator('#ff39InboxList').text_content()
 ctx.set_offline(False)
 expect(page.locator('#ff39InboxList')).to_contain_text('QA incoming',timeout=15000)
 expect(page.locator('#ffA11Visual')).to_be_hidden()
 # Revocation clears delegated controls and stale local history.
 page.evaluate("()=>{window.a11Revoked=true;window.dispatchEvent(new Event('online'))}")
 expect(page.locator('#ffA11Preview')).to_be_hidden(timeout=15000)
 assert 'QA proof' not in page.locator('#ff39SentLog').text_content()
 print('PASS STEP11 offline/online recovery, Push proof labels, visual preference and revocation',flush=True)
 page.evaluate("()=>{window.dispatchEvent(new Event('ff-luxe-session-reset'));user=null;data=null;}")
 expect(page.locator('#ff39Title')).to_have_value('')
 assert 'QA incoming' not in page.locator('#ff39InboxList').text_content()
 for role in ('assembly','burger_kitchen'):
  p=ctx.new_page();p.goto(origin,wait_until='load');p.evaluate(fixture,role)
  expect(p.locator('#ffA11SpecialInbox')).to_be_visible(timeout=15000)
  p.locator('#ffA11SpecialInbox').click();expect(p.locator('#ff39Panel')).to_be_visible()
  expect(p.locator('#ffA11Preview')).to_be_hidden();p.close()
 print('PASS A11 isolated mobile composition, preview, recipient selection, templates, delegation, inbox reconnect, session reset and special roles')
 ctx.close();browser.close()
server.shutdown()
