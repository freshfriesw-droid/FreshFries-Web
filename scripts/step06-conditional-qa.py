"""STEP06: verify the 27 conditional content bindings not exercised by A07/STEP06 prior evidence.
Use actual production renderers and synthetic responses only, never live operations.
"""
import ast,json
from pathlib import Path
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from functools import partial
from threading import Thread
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
out=root/'step06-conditional-evidence';out.mkdir(exist_ok=True)
def literal(path,name):
 return next(ast.literal_eval(n.value) for n in ast.parse((root/path).read_text()).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id==name for t in n.targets))
fixture=literal('scripts/a07-design-qa.py','fixture')
keys=set("""cashier.action.cashier_cancel_ack cashier.control.cashier_cancel_banner dashboard.action.lifecycle_action dashboard.action.watch_find dashboard.action.watch_tab dashboard.control.lifecycle_invoice dashboard.control.lifecycle_reoffer_driver dashboard.control.lifecycle_reoffer_reason driver.action.driver_grievance_open driver.control.driver_feedback_open driver.control.driver_grievance_close driver.control.driver_grievance_details driver.control.driver_grievance_kind driver.control.driver_grievance_save driver.control.driver_rating_close driver.control.driver_rating_note driver.control.driver_rating_star driver.control.driver_rating_submit orders.action.order_auto orders.action.order_manual orders.action.order_toggle_reject orders.action.orders_rate_driver_open ratings.control.orders_rate_note ratings.control.orders_rate_save ratings.control.orders_rate_skip ratings.control.orders_rate_star reports.control.ffa10ratingescalate""".split())
assert len(keys)==27
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=root));Thread(target=server.serve_forever,daemon=True).start()
origin=f'http://127.0.0.1:{server.server_port}/'
setup="""async role=>{
 const now=new Date().toISOString(),mk=(id,n,extra={})=>({id,number:n,branch_id:'b1',driver_id:'qa-driver',driver_name:'QA',phase:'assigned',status:'sent',cashier_stage:'waiting',created_at:now,customer_name:'QA',phone:'000',area:'QA',total:1000,delivery_fee:500,items:[{qty:1,name:'تشكن',price:500}],...extra});
 const pending=mk('qa-unassigned',501,{driver_id:null,driver_name:null,phase:null,status:'new'}),assigned=mk('qa-assigned',502,{cashier_received:true,cashier_received_at:now}),onway=mk('qa-road',503,{phase:'on_way',cashier_stage:'handed_over'});
 const prior=rpc;window.__qaContent=[];window.__qaWrites=[];
 rpc=async(name,args={})=>{
  if(name==='ff_content_effective')return window.__qaContent;
  if(name==='ff60_health')return {stage:6};
  if(name==='ff60_operational_queue')return [pending,assigned];
  if(name==='ff60_read_policy')return {fast_seconds:180,slow_seconds:600};
  if(name==='ff_a10_driver_rating_queue')return [{order_number:504,order_id:'qa-delivered'}];
  if(name==='ff_luxe_cashier_cancel_alerts')return [{order_id:'qa-cancel',number:505,branch_id:'b1',driver_name:'QA',customer_name:'QA',area:'QA',phone:'000',cashier_stage:'printed',invoice_ref:'QA-INVOICE',reason:'QA',items:[],total:500,delivery_fee:0}];
  if(name==='ff_a10_reporting_center')return {from:args.p_from,to:args.p_to,role,scope:'QA',access_key:'qa',generated_at:now,available_sections:['summary','ratings'],branches:[{id:'b1',name:'القاهرة'}],driver_options:[],filter_options:{},totals:{orders:1},internal_low_ratings:[{rating_id:'qa-rate',order_number:502,rater_role:'cashier',stars:2,note:'QA-PRIVATE'}]};
  if(name==='ff_a10_report_grants')return {accounts:[],grants:[]};
  if(/(_save|_publish|_ack_cashier_cancel|_rate_driver_cs|_driver_grievance|_set_stage|_manual_reoffer|_escalate_rating)$/.test(name)){window.__qaWrites.push(name);throw Error('unexpected write '+name)}
  return prior(name,args);
 };
 data.orders=role==='driver'?[onway]:[pending,assigned];
 data.drivers=[{id:'qa-driver',name:'QA',branch_id:'b1',presence:'ready'}];
 additionReady=true;selfPermissions={...selfPermissions,manage_drivers:true,assign_driver:true,edit_order:true,cancel_order:true};draw();
 await ffContentStudio.sync(true);
}"""
audit="""async keys=>{
 const registry=ffContentStudio.registry().filter(r=>keys.includes(r.key));
 const direct=n=>Array.from(n.childNodes).filter(c=>c.nodeType===Node.TEXT_NODE).map(c=>c.data).join('');
 const read=(r,n)=>r.mode==='accessible'?n.getAttribute('aria-label'):r.mode==='hint'?n.getAttribute('placeholder'):direct(n);
 const nodes=registry.flatMap((r,i)=>[...document.querySelectorAll(r.selector)].map(n=>({r,n,marker:'توضيح آمن '+i,before:read(r,n),value:n.value,id:n.id,type:n.type,disabled:n.disabled,required:n.required,handler:n.onclick})));
 window.__qaContent=registry.map((r,i)=>({content_key:r.key,body:'توضيح آمن '+i,revision:1}));await ffContentStudio.sync(true);
 const failures=[],covered=new Set();
 for(const x of nodes){const n=x.n,after=read(x.r,n);
  if(!n.isConnected){failures.push([x.r.key,'replaced']);continue}
  if(!String(after||'').includes(x.marker)){failures.push([x.r.key,'missing',x.before]);continue}
  if(['protected','protected_label','accessible'].includes(x.r.mode)&&x.before&&!String(after).includes(x.before.trim()))failures.push([x.r.key,'official text lost']);
  if(n.value!==x.value||n.id!==x.id||n.type!==x.type||n.disabled!==x.disabled||n.required!==x.required||n.onclick!==x.handler)failures.push([x.r.key,'state mutated']);
  covered.add(x.r.key);
 }
 window.__qaContent=[];await ffContentStudio.sync(true);
 for(const x of nodes)if(!x.n.isConnected||read(x.r,x.n)!==x.before)failures.push([x.r.key,'restore',x.before,read(x.r,x.n)]);
 return {covered:[...covered],failures,matched:nodes.length};
}"""
records=[]
with sync_playwright() as pw:
 browser=pw.chromium.launch(channel='chrome')
 for width in (390,1440):
  covered=set()
  for role in ('manager','cashier','driver'):
   ctx=browser.new_context(viewport={'width':width,'height':850},service_workers='block',reduced_motion='reduce')
   ctx.route('**/*',lambda r:r.continue_() if r.request.url.startswith(origin) else r.abort())
   page=ctx.new_page();page.goto(origin,wait_until='load');page.evaluate(fixture,role);page.evaluate(setup,role)
   def check(label):
    row=page.evaluate(audit,sorted(keys));records.append(dict(width=width,role=role,stage=label,**row));covered.update(row['covered'])
    (out/'conditional.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
    print('STEP06 conditional',width,role,label,row,flush=True)
    assert not row['failures'],row
   if role=='manager':
    page.locator('#staffOrders button[data-auto]').first.wait_for(state='attached');check('orders')
    page.locator('#staffOrders button[data-ff-luxe-csrate]').first.evaluate('n=>n.click()')
    page.locator('dialog.ff-luxe-rate-dialog[open] button[data-skip]').wait_for(state='attached');check('rating dialog')
    page.locator('dialog.ff-luxe-rate-dialog[open] button[data-skip]').evaluate('n=>n.click()')
    page.locator('#ff5-launch').evaluate('n=>n.click()');page.locator('#ff5-queue button[data-ff5-find]').first.wait_for(state='attached');check('watch')
    page.locator('#ff5-close').evaluate('n=>n.click()')
    page.locator('#ff60-launch').evaluate('n=>n.click()');page.locator('button[data-ff60-action=show-invoice]').wait_for(state='attached')
    page.locator('button[data-ff60-action=show-invoice]').evaluate('n=>n.click()');page.locator('input[data-ff60-invoice]').wait_for(state='attached');check('invoice')
    page.locator('button[data-ff60-action=show-reoffer]').evaluate('n=>n.click()');page.locator('input[data-ff60-reoffer-reason]').wait_for(state='attached');check('reoffer')
    page.locator('#ff60-close').evaluate('n=>n.click()')
    page.evaluate('()=>window.ff76OpenReports()');page.locator('#ffA10RatingEscalate').wait_for(state='attached');check('report escalation')
   elif role=='cashier':
    page.evaluate("()=>window.dispatchEvent(new Event('focus'))");page.locator('#cashierOrders button[data-ff-luxe-ack]').wait_for(state='attached');check('cancel acknowledgement')
   else:
    page.locator('#driverTasks button[data-a10-appeal]').wait_for(state='attached');check('driver tasks')
    page.locator('#driverTasks button[data-a10-appeal]').first.evaluate('n=>n.click()')
    page.locator('dialog.ff-luxe-rate-dialog[open] select').wait_for(state='attached');check('grievance')
    page.locator('dialog.ff-luxe-rate-dialog[open] button[data-close]').evaluate('n=>n.click()')
    page.locator('#ffA10DriverFeedback [data-refresh]').evaluate('n=>n.click()');page.locator('#ffA10DriverFeedback [data-rows] button').first.wait_for(state='attached');check('rating queue')
    page.locator('#ffA10DriverFeedback [data-rows] button').first.evaluate('n=>n.click()');page.locator('#ffLuxeFourScores').wait_for(state='attached');check('driver rating dialog')
    page.locator('dialog.ff-luxe-rate-dialog[open] button[data-close]').evaluate('n=>n.click()')
   assert page.evaluate('window.__qaWrites.length')==0
   ctx.close()
  assert covered==keys,sorted(keys-covered)
  print('PASS STEP06 27/27 previously unmounted conditional bindings at width',width,flush=True)

 # Exact public portal and full report content integration, using original renderers.
 ctx=browser.new_context(viewport={'width':390,'height':850},service_workers='block',reduced_motion='reduce')
 ctx.route('**/*',lambda r:r.continue_() if r.request.url.startswith(origin) else r.abort())
 page=ctx.new_page();page.goto(origin,wait_until='load');page.evaluate(fixture,'manager')
 portal=page.evaluate("""async()=>{
  const prior=rpc,entries=ffContentStudio.registry().filter(r=>r.publicScreen==='customer_portal'),rows=entries.map((r,i)=>({content_key:r.key,body:'بوابة تجريبية '+i}));
  window.__portalQA=rows;let current='applicant';
  rpc=async(name,args={})=>name==='ff49_snapshot'?null:name==='ff28_my_role'?current:name==='ff28_application'?null:name==='ff28_customer'?[]:name==='ff_step06_public_content'?(args.p_screen==='customer_portal'?window.__portalQA:[]):prior(name,args);
  // Real applicant and customer session render paths; all RPCs synthetic.
  window.__portalQA=[];await setSession({user:{id:'qa-applicant'}});await ffContentStudio.syncPublic(true);
  if(document.body.dataset.access!=='applicant'||document.getElementById('ff28Apply').hidden)throw Error('applicant renderer unavailable');
  const before=entries.map(r=>{const n=document.querySelector(r.selector);return {r,n,txt:[...n.childNodes].filter(c=>c.nodeType===Node.TEXT_NODE).map(c=>c.data).join(''),value:n.value,handler:n.onclick}});
  window.__portalQA=rows;await ffContentStudio.syncPublic(true);
  for(const [i,c] of before.entries()){
   const after=[...c.n.childNodes].filter(n=>n.nodeType===Node.TEXT_NODE).map(n=>n.data).join('');
   if(!after.includes('بوابة تجريبية '+i)||c.r.mode.startsWith('protected')&&!after.includes(c.txt.trim())||c.n.value!==c.value||c.n.onclick!==c.handler)throw Error('portal binding '+c.r.key);
  }
  window.__portalQA=[];await ffContentStudio.syncPublic(true);
  for(const c of before)if([...c.n.childNodes].filter(n=>n.nodeType===Node.TEXT_NODE).map(n=>n.data).join('')!==c.txt)throw Error('portal restore '+c.r.key);
  current='customer';window.__portalQA=rows;await setSession({user:{id:'qa-customer'}});await ffContentStudio.syncPublic(true);
  if(!document.getElementById('ff28Title').textContent.includes('طلباتي')||!document.getElementById('ff28Title').textContent.includes('بوابة تجريبية'))throw Error('customer title');
  window.__portalQA=[];await ffContentStudio.syncPublic(true);
  if(document.getElementById('ff28Title').textContent!=='طلباتي')throw Error('customer title restore');
  return entries.map(r=>r.key)
 }""")
 assert len(portal)==5,portal
 print('PASS STEP06 all 5 customer portal keys, applicant/customer role, original retained/restored',flush=True)
 ctx.close()

 ctx=browser.new_context(viewport={'width':1440,'height':850},service_workers='block',reduced_motion='reduce')
 ctx.route('**/*',lambda r:r.continue_() if r.request.url.startswith(origin) else r.abort())
 page=ctx.new_page();page.goto(origin,wait_until='load')
 a10tree=ast.parse((root/'scripts/a10-report-qa.py').read_text())
 page.evaluate(literal('scripts/a10-report-qa.py','fixture'),'manager')
 init=next(n.args[0].value for n in ast.walk(a10tree) if isinstance(n,ast.Call) and n.args and isinstance(n.func,ast.Attribute) and n.func.attr=='evaluate' and isinstance(n.args[0],ast.Constant) and isinstance(n.args[0].value,str) and 'window.a10Revoked=false;window.a10Escalated=false' in n.args[0].value)
 init=init.replace('()=>{','async()=>{',1).replace("if(name==='ff_a10_reporting_center'){","if(name==='ff76_report_approval_save'){if(window.qaApprovalError)throw Error('QA approval failure');return {manager_name:args.p_manager_name,notes:args.p_notes,approved_at:new Date().toISOString()}}\n if(name==='ff_a10_reporting_center'){if(window.qaReportError)throw Error('QA report failure');")
 init=init.replace("window.ff76OpenReports();","window.__a09Content=ffContentStudio.registry().filter(r=>r.mode==='report'||r.mode==='runtime'&&r.key.startsWith('reports.')).map((r,i)=>({content_key:r.key,body:'تقرير تجريبي '+i})); await ffContentStudio.sync(true); window.ff76OpenReports();")
 page.evaluate(init)
 page.locator('#ff76Body [data-report-section=finance]').wait_for()
 report=page.evaluate("""()=>{
  const rows=window.__a09Content;const checks=rows.filter(r=>r.content_key.startsWith('reports.section.')).map(r=>({key:r.content_key,expected:r.body,actual:document.querySelector('[data-report-section="'+r.content_key.split('.').at(-1)+'"] h3')?.textContent}));
  return {checks,success:document.getElementById('ff76Status').textContent,expected:rows.find(r=>r.content_key==='reports.success').body,footer:document.querySelector('[data-report-section=finance]').textContent};
 }""")
 assert len(report['checks'])==14 and all(x['expected'] in (x['actual'] or '') for x in report['checks']),report['checks']
 assert report['expected'] in report['success'] and 'المبالغ المسجلة ورسوم التوصيل' in report['footer']
 page.locator('#ff76ManagerName').fill('QA manager')
 page.locator('#ff76ManagerNotes').fill('QA note')
 page.locator('#ff76SaveApproval').evaluate('n=>n.click()')
 page.wait_for_function("()=>document.querySelector('#ff76ApprovalStatus').textContent.includes(window.__a09Content.find(x=>x.content_key==='reports.approval_success').body)")
 page.evaluate('window.qaApprovalError=true')
 page.locator('#ff76SaveApproval').evaluate('n=>n.click()')
 page.wait_for_function("()=>document.querySelector('#ff76ApprovalStatus').textContent.includes(window.__a09Content.find(x=>x.content_key==='reports.approval_error').body)")
 page.evaluate('window.qaReportError=true')
 page.locator('#ff76Run').evaluate('n=>n.click()')
 page.wait_for_function("()=>document.querySelector('#ff76Status').textContent.includes(window.__a09Content.find(x=>x.content_key==='reports.error').body)")
 page.evaluate("async()=>{window.qaReportError=false;window.__a09Content=[];await ffContentStudio.sync(true);document.getElementById('ff76Run').click()}")
 page.locator('#ff76Body [data-report-section=finance]').wait_for()
 assert 'تقرير تجريبي' not in page.locator('#ff76Body').inner_text()
 assert 'المبالغ المسجلة ورسوم التوصيل' in page.locator('#ff76Body [data-report-section=finance] h3').inner_text()
 print('PASS STEP06 all 14 report section titles and 4 report outcome messages, restore, no real writes',flush=True)
 (out/'public-report.json').write_text(json.dumps({'public_portal':portal,'report':report,'report_outcomes':4},ensure_ascii=False,indent=2))
 ctx.close()

 browser.close()
server.shutdown()
