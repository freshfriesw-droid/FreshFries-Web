"""STEP06 real DOM, content manager workflow and public-scope tests.
Uses synthetic in-browser RPC fixtures only. No live operational writes.
"""
import ast,json
from pathlib import Path
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from functools import partial
from threading import Thread
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
out=root/'step06-evidence';out.mkdir(exist_ok=True)
inventory=json.loads((root/'docs/implementation/STEP06-content-inventory-20261125.json').read_text())
fixture=next(ast.literal_eval(n.value) for n in ast.parse((root/'scripts/a07-design-qa.py').read_text()).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='fixture' for t in n.targets))
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=root));Thread(target=server.serve_forever,daemon=True).start()
origin=f'http://127.0.0.1:{server.server_port}/'
observations=[]
audit="""async ()=>{
 const registry=ffContentStudio.registry().filter(r=>!r.publicScreen&&r.selector);
 const direct=n=>Array.from(n.childNodes).filter(c=>c.nodeType===Node.TEXT_NODE).map(c=>c.data).join('');
 const snapshots=registry.map((r,index)=>({r,marker:'تخصيص اختباري '+index,nodes:Array.from(document.querySelectorAll(r.selector)).map(n=>({n,before:r.mode==='hint'?n.getAttribute('placeholder'):r.mode==='accessible'?n.getAttribute('aria-label'):direct(n),disabled:n.disabled,value:n.value,id:n.id,type:n.type,required:n.required,onclick:n.onclick}))}));
 const official=document.querySelector('#ff43SecurityPanel .warning')?.textContent;
 window.__step06Rows=snapshots.map(x=>({content_key:x.r.key,body:x.marker,revision:1}));
 await ffContentStudio.sync(true);
 const results=snapshots.map(x=>{
  const failures=[];
  for(const o of x.nodes){
   const n=o.n,after=x.r.mode==='hint'?n.getAttribute('placeholder'):x.r.mode==='accessible'?n.getAttribute('aria-label'):x.r.mode==='guide'?n.querySelector('[data-ff-guidance="'+x.r.key+'"]')?.textContent:direct(n);
   if(!n.isConnected){failures.push('node-replaced');continue}
   if(!String(after||'').includes(x.marker))failures.push('not-applied:'+String(o.before||'').slice(0,100));
   if(['protected','protected_label'].includes(x.r.mode)&&!String(after||'').includes(o.before.trim()))failures.push('original-hidden');
   if(n.id!==o.id||n.disabled!==o.disabled||n.value!==o.value||n.type!==o.type||n.required!==o.required||n.onclick!==o.onclick)failures.push('control-mutated');
  }
  return {key:x.r.key,matched:x.nodes.length,failures};
 });
 if(document.querySelector('#ff43SecurityPanel .warning')?.textContent!==official)throw Error('official security warning changed');
 window.__step06Rows=[];await ffContentStudio.sync(true);
 for(const [index,x] of snapshots.entries())for(const o of x.nodes){
  if(!o.n.isConnected)continue;
  const after=x.r.mode==='hint'?o.n.getAttribute('placeholder'):x.r.mode==='accessible'?o.n.getAttribute('aria-label'):direct(o.n);
  if(x.r.mode==='guide'){if(o.n.querySelector('[data-ff-guidance="'+x.r.key+'"]'))results[index].failures.push('guide-not-restored')}
  else if(after!==o.before)results[index].failures.push('restore:'+String(after||'').slice(0,100));
 }
 return results;
}"""
with sync_playwright() as pw:
 browser=pw.chromium.launch(channel='chrome')
 for role in ['manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen']:
  ctx=browser.new_context(viewport={'width':390,'height':850},service_workers='block',reduced_motion='reduce')
  ctx.route('**/*',lambda r:r.continue_() if r.request.url.startswith(origin) else r.abort())
  page=ctx.new_page();page.goto(origin,wait_until='load');page.evaluate(fixture,role)
  page.evaluate("""()=>{const prior=rpc;window.__step06Rows=[];rpc=async(name,args={})=>name==='ff_content_effective'?window.__step06Rows:prior(name,args)}""")
  if role=='assembly':page.locator("#ffV12Toggle").click()
  if role in ('driver','cashier','customer_service'):
   key={'driver':'attendance','cashier':'cashier','customer_service':'new'}[role]
   page.locator('#ffx-mobile-nav button[data-key="'+key+'"]').click()
  results=page.evaluate(audit)
  observations.extend(dict(role=role,**r) for r in results)
  (out/'binding-audit.json').write_text(json.dumps(observations,ensure_ascii=False,indent=2))
  bad=[r for r in results if r['failures']]
  print('STEP06 actual mounted content',role,'matched',sum(r['matched']>0 for r in results),'failures',len(bad),flush=True)
  if bad:print('STEP06_BINDING_FAILURES',json.dumps(bad,ensure_ascii=False),flush=True)

  # Additional actual renderers: cover conditional order stages, additions, offers, and kitchen cards.
  if role in ('manager','cashier','driver','assembly','burger_kitchen'):
   page.evaluate("""async role=>{
    const now=new Date().toISOString(),br={id:'b1',name:'القاهرة',code:'cairo'},me=user.id;
    const mk=(id,stage,phase='assigned',more={})=>({id,number:123,branch_id:'b1',driver_id:'qa-driver',driver_name:'QA',phase,status:'sent',cashier_stage:stage,created_at:now,customer_name:'QA',phone:'000',area:'QA',total:1000,delivery_fee:500,items:[{qty:1,name:'برجر',price:500}],...more});
    const orders=[mk('recv','waiting'),mk('inv','waiting','assigned',{cashier_received_at:now}),mk('print','printed'),mk('prep','preparing'),mk('ready','ready'),mk('road','handed_over'),mk('arrive','handed_over','on_way'),mk('pending','printed'),mk('late','printed'),mk('warning','printed'),mk('await','handed_over','on_way')];
    const adds=[{id:'add-pending',order_id:'pending',status:'pending',amount:100,items:[]},{id:'add-late',order_id:'late',status:'pending',late_state:'driver_accepted',amount:100,items:[]},{id:'add-warning',order_id:'warning',status:'invoiced',late_state:'invoiced',amount:100,items:[]},{id:'add-await',order_id:'await',status:'pending',late_state:'awaiting_driver',amount:100,items:[]}];
    const tickets=[{id:'qa-ready',branch_id:'b1',branch_name:'القاهرة',order_kind:'local',status:'ready',invoice_ref:'QA',sent_at:now,accepted_at:now,ready_at:now,items:[]},{id:'qa-prep',branch_id:'b1',branch_name:'القاهرة',order_kind:'local',status:'preparing',invoice_ref:'QA2',sent_at:now,accepted_at:now,kitchen_id:me,items:[{name:'برجر',qty:1,item_notes:'بدون بصل'}]}];
    const prior=rpc;rpc=async(name,args={})=>name==='ff_v12_assembly_snapshot'?{role:'assembly',branch:br,orders}:name==='ff_burger_list'?tickets:prior(name,args);
    if(role==='assembly'){await ffV12Refresh(true);window.ffBurgerToggleAssembly();}
    else if(role==='burger_kitchen'){document.getElementById('ffBurgerKitchenRefresh').click();}
    else{data.orders=orders;additionReady=true;additionData=adds;selfPermissions={...selfPermissions,edit_order:true,assign_driver:true,cancel_order:true};
     if(role==='manager'){activeAdditionForm='print';drawOrders()}
     if(role==='cashier'){drawCashier();document.getElementById('ffBurgerRefresh')?.click();window.ffBurgerOnCashierDraw()}
     if(role==='driver'){data.offers=[{id:'offer-yes',order_id:'yes',order_number:124,branch_id:'b1',expires_at:new Date(Date.now()+300000).toISOString()},{id:'offer-no',order_id:'no',order_number:125,branch_id:'b1',expires_at:new Date(Date.now()+300000).toISOString()}];rejectPermissionReady=true;rejectPermissions={yes:true,no:false};drawDriver()}
    }
   }""",role)
   if role=='cashier':
    page.locator('#ffBurgerPanelToggle').click()
    page.locator('#ffBurgerCashierReady').wait_for(state='attached')
    # Wait for the synthetic list to refresh, then audit actual cards.
    page.wait_for_timeout(5300)
    page.locator('#ffBurgerPanelToggle').evaluate("n=>{if(n.getAttribute('aria-expanded')!=='true')n.click()}")
    page.evaluate("()=>{document.getElementById('ffBurgerRefresh')?.click();window.ffBurgerOnCashierDraw()}")
   if role in ('assembly','burger_kitchen','cashier'):
    page.wait_for_timeout(500)
   conditional=page.evaluate(audit)
   observations.extend(dict(role=role+'-conditional',**r) for r in conditional)
   (out/'binding-audit.json').write_text(json.dumps(observations,ensure_ascii=False,indent=2))
   bad=[r for r in conditional if r['failures']]
   print('STEP06 order-state content',role,'matched',sum(r['matched']>0 for r in conditional),'failures',len(bad),flush=True)
   if bad:print('STEP06_BINDING_FAILURES',json.dumps(bad,ensure_ascii=False),flush=True)

  if role=='manager':
   page.evaluate("""async()=>{
    const rules=ffContentStudio.registry().filter(r=>r.message);
    window.__step06Rows=rules.map((r,i)=>({content_key:r.key,body:'رسالة اختبار '+i}));
    await ffContentStudio.sync(true);
    for(const [i,r] of rules.entries()){
     const message=r.message+(r.match==='prefix'?'تفصيل تجريبي':'');
     const actual=ffContentStudio.decorateMessage(message);
     if(!actual.startsWith(message+' — ')||!actual.includes('رسالة اختبار '+i))throw Error('unbound message '+r.key);
    }
    const target=rules.find(r=>r.original==='تم تسجيل الحضور');toast(target.message);
    if(!document.getElementById('ffx-toast').textContent.includes(' — '))throw Error('actual toast hook missing');
    window.__step06Rows=[];await ffContentStudio.sync(true);
    if(ffContentStudio.decorateMessage(target.message)!==target.message)throw Error('message restore');
   }""")
   print('PASS STEP06 all fixed message keys, actual toast, original retention and restore',flush=True)
   page.evaluate("""rows=>{window.__step06Catalog=rows;window.__step06History=[];window.__step06Writes=[];const prior=rpc;rpc=async(name,args={})=>{
    if(name==='ff_content_catalog_list')return window.__step06Catalog;
    if(['ff_content_history','ff86_content_history_scoped'].includes(name))return window.__step06History.filter(r=>r.content_key===args.p_key&&(!args.p_role||r.role_scope===args.p_role)&&(!args.p_branch||r.branch_id===args.p_branch)&&(!args.p_global_branch||r.branch_id===null));
    if(name==='ff_content_create_draft'){window.__step06Writes.push(args);if(window.__denyDraft)return null;const id=window.__step06History.length+1;window.__step06History.unshift({id,content_key:args.p_key,role_scope:args.p_role,branch_id:args.p_branch,body:args.p_body,actor_id:user.id,created_at:'2026-11-25T01:00:00Z',published_at:null});return id}
    if(name==='ff_content_publish'){if(!window.__denyPublish){const row=window.__step06History.find(r=>r.id===args.p_id);row.published_at='2026-11-25T02:00:00Z';row.published_by=user.id;window.__step06Rows=[{content_key:row.content_key,body:row.body,revision:row.id}]}return null}
    return prior(name,args)};
   }""",[{k:r[k] for k in ('key','screen','label','original')} for r in inventory['registered']])
   page.on('dialog',lambda d:d.accept())
   page.evaluate("()=>ffContentStudio.open({key:'finance.title',role:'manager',branch:'b1'})")
   dlg=page.locator('#ffContentStudio')
   dlg.locator('[data-content-key]').wait_for()
   assert dlg.locator('[data-content-key]').input_value()=='finance.title'
   assert 'تسويات' in dlg.locator('[data-content-original]').inner_text()
   dlg.locator('[data-content-search]').fill('تسويات')
   page.wait_for_timeout(300)
   assert dlg.locator('[data-content-key] option').count()>=1
   dlg.locator('[data-content-search]').fill('')
   page.wait_for_timeout(300)
   dlg.locator('[data-content-key]').select_option('finance.title')
   dlg.locator('[data-content-body]').fill('متابعة نقدية اختبارية')
   dlg.locator('[data-content-save]').click()
   page.wait_for_function("()=>document.querySelector('[data-content-status]').textContent.includes('حُفظت المسودة')")
   assert page.evaluate("window.__step06Writes.at(-1).p_branch")=='b1'
   page.evaluate("window.__denyPublish=true")
   dlg.locator('[data-content-publish]').click()
   page.wait_for_function("()=>document.querySelector('[data-content-status]').textContent.includes('لم يثبت نشر')")
   page.evaluate("window.__denyPublish=false")
   dlg.locator('[data-content-publish]').click()
   page.wait_for_function("()=>document.querySelector('[data-content-status]').textContent.includes('تم نشر النص')")
   dlg.locator('[data-content-restore]').click()
   page.wait_for_function("()=>window.__step06Writes.at(-1).p_body===null")
   dlg.locator('[data-content-publish]').click()
   page.wait_for_function("()=>document.querySelector('[data-content-status]').textContent.includes('تم نشر النص #2')")
   dlg.locator('[data-content-screen]').select_option('login')
   assert dlg.locator('[data-content-role]').is_disabled() and dlg.locator('[data-content-branch]').is_disabled()
   dlg.locator('[data-content-key]').select_option('login.title')
   dlg.locator('[data-content-body]').fill('عنوان عام تجريبي')
   page.evaluate("window.__denyDraft=true")
   dlg.locator('[data-content-save]').click()
   page.wait_for_function("()=>document.querySelector('[data-content-status]').textContent.includes('لم يحفظ الخادم')")
   page.evaluate("window.__denyDraft=false")
   dlg.locator('[data-content-screen]').select_option('system')
   dlg.locator('[data-content-key]').select_option('system.security_guidance')
   dlg.locator('[data-content-body]').fill('**راجع**\n- [فتح النظام](https://delivery.freshfriesz.com/)')
   assert dlg.locator('[data-content-rich-preview] strong').inner_text()=='راجع'
   assert dlg.locator('[data-content-rich-preview] a').get_attribute('href')=='https://delivery.freshfriesz.com/'
   for width in (320,360,390,430,768,1024,1440):
    page.set_viewport_size({'width':width,'height':850})
    assert dlg.evaluate('e=>e.scrollWidth<=e.clientWidth+2'),width
    if width in (390,1440):page.screenshot(path=out/f'editor-{width}.png',animations='disabled')
   dlg.locator('[data-content-close]').click()
   # Public surface uses only exact whitelist; stale responses are discarded.
   page.evaluate("""async()=>{
    user=null;data=null;document.body.dataset.access='locked';window.dispatchEvent(new Event('ff-luxe-session-reset'));
    const prior=rpc;rpc=async(name,args={})=>name==='ff_step06_public_content'?[{content_key:'login.title',body:'عنوان دخول تجريبي'},{content_key:'cashier.title',body:'PRIVATE-QA'},{content_key:'customer_portal.control.refresh',body:'غير مناسب'}]:prior(name,args);
    await ffContentStudio.syncPublic(true);
   }""")
   assert 'عنوان دخول تجريبي' in page.locator('#loginOverlay .loginbox > h2').text_content()
   assert 'PRIVATE-QA' not in page.locator('#cashierView .card > h2').text_content()
   assert 'غير مناسب' not in page.locator('#ff28Refresh').text_content()
   count=page.evaluate("""async()=>{
    const rows=ffContentStudio.registry().filter(r=>r.publicScreen==='login'&&r.selector);
    const prior=rpc;rpc=async(name,args={})=>name==='ff_step06_public_content'?rows.map((r,i)=>({content_key:r.key,body:'اختبار عام '+i})):prior(name,args);
    await ffContentStudio.syncPublic(true);
    let count=0;
    for(const [i,r] of rows.entries())for(const n of document.querySelectorAll(r.selector)){
     const actual=r.mode==='hint'?n.placeholder:n.textContent;
     if(!actual.includes('اختبار عام '+i))throw Error('public label '+r.key+' '+actual);
     count++;
    }
    return count;
   }""")
   assert count>=30,count
   print('PASS STEP06 public form bindings',count,flush=True)
   page.evaluate("""async()=>{document.body.dataset.access='customer';const prior=rpc;rpc=async(name,args={})=>name==='ff_step06_public_content'?[{content_key:'customer_portal.control.refresh',body:'تحديث تجريبي'}]:prior(name,args);await ffContentStudio.syncPublic(true)}""")
   assert page.locator('#ff28Refresh').text_content().strip()=='تحديث تجريبي'
   assert 'عنوان دخول تجريبي' not in page.locator('#loginOverlay .loginbox > h2').text_content()
   print('PASS STEP06 manager editor workflow, denial evidence, Arabic rich preview, 7 widths and public scope',flush=True)
  ctx.close()
 browser.close()
covered={r['key'] for r in observations if r['matched'] and not r['failures']}
failed=[r for r in observations if r['failures']]
expected={r['key'] for r in inventory['registered'] if r['selector'] and not r.get('publicScreen')}
(out/'coverage.json').write_text(json.dumps({'expected':len(expected),'covered':len(covered),'unmounted':sorted(expected-covered),'failed':failed},ensure_ascii=False,indent=2))
assert not failed,failed[:20]
print('PASS STEP06',len(covered),'distinct mounted additional keys; remaining unmounted keys recorded separately',flush=True)
server.shutdown()
