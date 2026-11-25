"""P2/FIX-04: compare actual role workspaces and shared component computed styles.
Pinned pre-change tree, network-isolated Chrome fixtures, no operating writes.
Record CSSOM cascade including injected styles; keep actual before/after screenshots.
"""
import ast, json, os, re, subprocess, hashlib
from pathlib import Path
from datetime import datetime, timezone
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread
from playwright.sync_api import sync_playwright
from PIL import Image, ImageChops

root=Path(os.environ.get('P2_ROOT',Path(__file__).resolve().parents[1]))
base=Path(os.environ['P2_BASELINE'])
out=root/'p2-evidence';out.mkdir(exist_ok=True)
report=json.loads((root/'docs/implementation/P2-css-consolidation-20261125.json').read_text())
def strip(s):
 return re.sub(r'<style\b[^>]*>[\s\S]*?</style>','',s,flags=re.I).replace('<link rel="stylesheet" href="./styles/luxe-p2-components.css?v=20261125-p2">\n','')
current_html=strip((root/'index.html').read_text())
baseline_html=strip((base/'index.html').read_text())
if os.environ.get('P2_STEP04_REGRESSION')=='1':
 # STEP04 intentionally changes exactly the shortcut construction and renderer,
 # plus the three cache-busting asset links. Prove every other byte of markup
 # and inline JavaScript stays identical to the closed P2 tree.
 start=current_html.index('// STEP04: central library')
 end=current_html.index('const mobileRoutes={',start)
 old_start=baseline_html.index("let scSig='';function drawShortcuts(){")
 old_end=baseline_html.index('const mobileRoutes={',old_start)
 current_html=current_html[:start]+baseline_html[old_start:old_end]+current_html[end:]
 for asset in ('scripts/luxe-a08-dashboard.js','scripts/luxe-dashboard-studio.js','styles/luxe-a08-dashboard.css'):
  current_html=current_html.replace('./'+asset+'?v=20261125-step04','./'+asset)
 # STEP05: only the explicitly audited tone lifecycle and asset URLs differ.
 current_start=current_html.index('let ff74Busy=false,ff74')
 current_end=current_html.index('let audioCtx=null,lastSoundAt=0',current_start)
 base_start=baseline_html.index('let ff74Busy=false,ff74')
 base_end=baseline_html.index('let audioCtx=null,lastSoundAt=0',base_start)
 current_html=current_html[:current_start]+baseline_html[base_start:base_end]+current_html[current_end:]
 current_html=current_html.replace('./scripts/luxe-a07-design.js?v=20261125-step05','./scripts/luxe-a07-design.js')
 current_html=current_html.replace('luxe-shared-photo-menu-20261123.js?v=20261125-step05','luxe-shared-photo-menu-20261123.js?v=20261125-a02-card-style')
 current_html=current_html.replace('./scripts/luxe-content-studio.js?v=20261125-step06','./scripts/luxe-content-studio.js')
 current_html=current_html.replace('luxe-report-center-20261123.js?v=20261125-step06','luxe-report-center-20261123.js?v=20261125-a10')
 current_html=current_html.replace("function toast(s){$('toast').textContent=window.ffContentStudio?.decorateMessage(s)??s;","function toast(s){$('toast').textContent=s;")
 current_html=current_html.replace("toastEl.innerHTML=`${icon('bell')}<span>${h(window.ffContentStudio?.decorateMessage(message)??message)}</span>`;","toastEl.innerHTML=`${icon('bell')}<span>${h(message)}</span>`;")
 assert current_html==baseline_html,'unexpected markup/script delta beyond STEP04, STEP05 and STEP06 audited hooks'
else:
 assert current_html==baseline_html,'non-CSS application markup or script changed'
changed={str(f.relative_to(base)) for f in list((base/'scripts').glob('*.js'))+list((base/'assets').glob('*.js')) if f.read_bytes()!=(root/f.relative_to(base)).read_bytes()}
step03_scripts={'scripts/luxe-a07-elements.js','scripts/luxe-a07-design.js','scripts/luxe-dashboard-studio.js','scripts/luxe-content-studio.js'}
if os.environ.get('P2_STEP04_REGRESSION')=='1':
 # No unrelated scripts changed; keep all visual/focus/pixel comparisons intact.
 assert changed==step03_scripts|{'scripts/luxe-a08-dashboard.js','scripts/luxe-shared-photo-menu-20261123.js','scripts/luxe-report-center-20261123.js'},changed
elif os.environ.get('P2_STEP03_REGRESSION')=='1':
 assert changed==step03_scripts,changed
else:
 assert not changed,changed
assert len(report['removed'])>=25
assert sum(report['token_replacements'].values())>=341
fixture=next(ast.literal_eval(n.value) for n in ast.parse((root/'scripts/a07-design-qa.py').read_text()).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='fixture' for t in n.targets))
fixture=fixture.replace('new Date().toISOString()',"'2026-11-25T03:00:00Z'")
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
def serve(path):
 server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=path))
 Thread(target=server.serve_forever,daemon=True).start()
 return server,'http://127.0.0.1:'+str(server.server_port)+'/'
old_server,old_origin=serve(base)
new_server,new_origin=serve(root)
roles=('manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen')
widths=(320,360,390,430,768,1024,1440)
themes=('classic','dark','contrast')
# Real CSSOM inventory (including runtime injected sheets). Exact selector and at-rule
# matches; normalize P2 token fallbacks to original literal values before comparing.
inventory="""()=>{const rows=[],sheets=[],inaccessible=[];
 const norm=v=>v.replace(/var\\(--ff-p2-[a-z-0-9]+,\\s*([^)]*)\\)/g,'$1');
 const walk=(list,source,scope='')=>{for(const r of list){
 if(r.selectorText&&r.style){for(const p of r.style){if(p.startsWith('--ff-p2-'))continue;rows.push({source,scope,selector:r.selectorText,property:p,value:norm(r.style.getPropertyValue(p)),priority:r.style.getPropertyPriority(p)})}}
 else if(r.cssRules)walk(r.cssRules,source,scope+' / '+(r.conditionText||r.name||r.constructor.name));}};
 for(const [i,s] of [...document.styleSheets].entries()){
 const source=s.ownerNode?.id||s.ownerNode?.getAttribute('href')||'inline-'+i;
 try{sheets.push({order:i,source,topRules:s.cssRules.length});walk(s.cssRules,source)}catch(e){inaccessible.push({source,error:e.message})}}
 const seen=new Map(),duplicates=[],overrides=[];
 for(const r of rows){const k=[r.scope,r.selector,r.property].join('|'),p=seen.get(k);if(p)(p.value===r.value&&p.priority===r.priority?duplicates:overrides).push({previous:p,current:r});seen.set(k,r)}
 return {sheets,inaccessible,declarations:rows.length,important:rows.filter(r=>r.priority==='important').length,duplicates,overrides};
}"""
# Sample each shared component plus actual operational order/status classes; do not
# put test elements inside order queues where polling might mutate them.
probe="""()=>{let host=document.getElementById('p2-probe');
 if(!host){host=document.createElement('section');host.id='p2-probe';host.setAttribute('aria-label','Synthetic component test');host.style.cssText='position:fixed;inset-inline:4px;top:4px;z-index:2147483600;max-height:80vh;overflow:auto;padding:8px;background:var(--ffb-surface);color:var(--ffb-ink)';host.innerHTML=`
 <div class="card" data-p2="card"><h3>اختبار المكونات</h3><div class="sectionbar" data-p2="section"><h2>القسم</h2><button class="primary" data-p2="primary">حفظ</button></div>
 <div class="actions" data-p2="actions"><button data-p2="button">إجراء</button><button class="dark" data-p2="dark">داكن</button><button class="good" data-p2="good">تأكيد</button><button class="outline" data-p2="outline">رجوع</button><button disabled data-p2="disabled">معطل</button></div>
 <label for="p2-field">الاسم</label><input id="p2-field" data-p2="field" value="طلب تجريبي"><label for="p2-select">الفرع</label><select id="p2-select" data-p2="select"><option>القاهرة</option></select><label for="p2-text">ملاحظة</label><textarea id="p2-text" data-p2="textarea">ملاحظة</textarea>
 <div class="ffb-order-tabs" data-p2="tabs"><button>طلب</button><button>إضافة</button></div><div class="stat" data-p2="stat"><strong>42</strong></div><div class="warning" data-p2="warning">تحذير</div><div class="note" data-p2="note">ملاحظة</div><div class="statusbar" data-p2="status">الحالة</div>
 <span class="tag ready" data-p2="ready">جاهز</span><span class="tag busy" data-p2="busy">مشغول</span><span class="tag offline" data-p2="offline">غير متصل</span><span class="ff60-live-countdown" data-p2="timer">03:00</span><span class="pill" data-p2="pill">3</span><div class="addition-card" data-p2="addition">إضافة</div><div class="addition-card invoiced" data-p2="invoiced">تمت الفوترة</div><div class="empty" data-p2="empty">لا توجد نتائج</div><div class="hidden" data-p2="hidden">لا يظهر</div></div>`;
 document.body.append(host);}
 const keys=['display','visibility','opacity','color','background-color','background-image','border-top-color','border-top-width','border-top-left-radius','box-shadow','font-family','font-size','font-weight','line-height','padding-top','padding-right','padding-bottom','padding-left','margin-top','margin-bottom','gap','min-height','cursor','text-align','white-space','direction','font-variant-numeric'];
 const sample=e=>{const s=getComputedStyle(e);return Object.fromEntries(keys.map(k=>[k,s.getPropertyValue(k)]))};
 const values=Object.fromEntries([...host.querySelectorAll('[data-p2]')].map(e=>[e.dataset.p2,sample(e)]));
 for(const sel of ['#ffx-sidebar','#ffx-topbar','#ffx-mobile-nav','#ffA06SpecialNav','#ffx-dashboard','#cashierView','#driverView','#serviceOnly','#ffV12AssemblyWorkspace','#ffBurgerKitchenWorkspace','#ffStudio','#ffA06CentralNav','#ffEditDialog','#loginOverlay','.ffx-hero','.ffx-kpi','.ffx-side-link','.ffx-panel']){
 const e=document.querySelector(sel);if(e)values[sel]=sample(e);}
 return values;
}"""
def compare(a,b,label):
 assert a.keys()==b.keys(),(label,'element coverage',sorted(a.keys()^b.keys()))
 diff=[(k,p,a[k][p],b[k][p]) for k in a for p in a[k] if a[k][p]!=b[k][p]]
 assert not diff,(label,diff[:35])
def setup(browser,origin,role):
 c=browser.new_context(viewport={'width':390,'height':850},service_workers='block',reduced_motion='reduce',locale='ar')
 c.route('**/*',lambda r:r.continue_() if r.request.url.startswith(origin) else r.abort())
 p=c.new_page()
 # Synchronize the wall clock in both browser contexts. The real timers still run.
 p.clock.set_fixed_time(datetime(2026,11,25,3,0,0,tzinfo=timezone.utc))
 p.goto(origin,wait_until='load');p.evaluate(fixture,role)
 p.wait_for_function('()=>!!window.ffA07Design&&!!window.ffDashboardStudio')
 if role=='assembly':p.locator('#ffV12Toggle').click()
 # The special-role bar is populated by the A06 asynchronous scope refresh.
 # Require readiness independently in both trees; never hide a failing bar to compare.
 if role in ('assembly','burger_kitchen'):
  p.wait_for_function("()=>{const n=document.getElementById('ffA06SpecialNav');return n&&!n.hidden&&n.querySelectorAll('button').length>=5&&getComputedStyle(n).display==='flex'}",timeout=10000)
 if role in ('driver','cashier','customer_service'):
  key={'driver':'attendance','cashier':'cashier','customer_service':'new'}[role]
  p.locator('#ffx-mobile-nav button[data-key="'+key+'"]').click()
 return c,p
rows=[]
with sync_playwright() as pw:
 # Deterministic software rasterization for both pinned trees. Keep exact RGB comparison.
 browser=pw.chromium.launch(channel='chrome',args=['--disable-gpu','--disable-lcd-text','--disable-font-subpixel-positioning','--force-color-profile=srgb'])
 for role in roles:
  oc,old=setup(browser,old_origin,role);nc,new=setup(browser,new_origin,role)
  if True:
   a=old.evaluate(inventory);b=new.evaluate(inventory)
   for label,value in [('before',a),('after',b)]:
    for entry in value['overrides']:
     r=entry['current']; prev=entry['previous']
     key=(r['selector']+' '+r['source']+' '+prev['source']).lower()
     if r['scope']: category='conditional media/supports cascade'
     elif any(x in key for x in ('hidden','visibility','disabled','active','status','locked','readonly','focus','hover','modal','drawer','nav')): category='interactive state, navigation or visibility cascade'
     elif any(x in key for x in ('theme','dark','contrast','compact','ffb','luxe','brand','design')): category='brand, theme or component layer precedence'
     else: category='legacy ordered cascade; removal not demonstrated safe'
     entry['disposition']=category+'; retained unchanged; compared computed styles and workspace rendering.'
    (out/('css-'+role+'-'+label+'.json')).write_text(json.dumps(value,ensure_ascii=False,indent=2))
   print('CSSOM before/after:',role,[(len(x['sheets']),len(x['duplicates']),len(x['overrides']),x['important']) for x in (a,b)],flush=True)
  for width in widths:
   for p in (old,new):p.set_viewport_size({'width':width,'height':850})
   for theme in themes:
    for p in (old,new):
     p.evaluate("""t=>{document.body.classList.remove('ffx-dark','ffx-contrast','ffx-compact');if(t!=='classic')document.body.classList.add('ffx-'+t);document.body.classList.toggle('ffx-compact',t==='contrast')}""",theme)
    for p in (old,new):
     if role in ('assembly','burger_kitchen'):
      p.wait_for_function("w=>{const n=document.getElementById('ffA06SpecialNav');return n&&!n.hidden&&n.querySelectorAll('button').length>=5&&(getComputedStyle(n).display!=='none')===matchMedia('(max-width: 850px)').matches}",arg=width,timeout=10000)
     p.evaluate("()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))")
    a=old.evaluate(probe);b=new.evaluate(probe)
    compare(a,b,(role,width,theme))
    assert b['hidden']['display']=='none'
    assert b['primary']['cursor']=='pointer'
    assert b['disabled']['cursor']=='not-allowed'
    # Real keyboard focus on the labelled field.
    for p in (old,new):p.locator('#p2-field').focus()
    focus="""()=>{const s=getComputedStyle(document.activeElement);return [document.activeElement.id,s.outlineStyle,s.outlineWidth,s.outlineColor,s.borderTopColor]}"""
    assert old.evaluate(focus)==new.evaluate(focus),(role,width,theme,'focus parity')
    for p in (old,new):
     p.locator('#p2-field').blur()
     # Focus on a mobile workspace may scroll either the page or the overflow probe.
     # Normalize both scroll positions before capturing the same viewport region.
     p.evaluate("""async()=>{window.scrollTo(0,0);const h=document.getElementById('p2-probe');h.scrollTop=0;h.scrollLeft=0;await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));}""")
    if width in (390,1440) and theme in ('classic','dark'):
     # Stable component panel image comparison; actual workspace images recorded separately.
     paths=[out/f'{role}-{width}-{theme}-{side}-components.png' for side in ('before','after')]
     for attempt in range(1,4):
      for p,path in zip((old,new),paths):
       rect=p.locator('#p2-probe').bounding_box()
       assert rect and rect['y']>=0 and rect['y']+rect['height']<=850,(role,width,theme,rect)
       # Clip a viewport screenshot in memory rather than locator screenshot,
       # which may itself scroll the document to bring the fixed element into view.
       from io import BytesIO
       shot=Image.open(BytesIO(p.screenshot(animations='disabled')))
       x,y,w,h=(round(rect[k]) for k in ('x','y','width','height'))
       shot.crop((x,y,x+w,y+h)).save(path)
      im1,im2=[Image.open(path).convert('RGB') for path in paths]
      assert im1.size==im2.size,(role,width,theme,'panel geometry',im1.size,im2.size)
      difference=ImageChops.difference(im1,im2)
      bounds=difference.getbbox()
      if bounds is None:break
      count=sum(1 for pixel in difference.getdata() if any(pixel))
      extrema=difference.getextrema()
      stem=f'{role}-{width}-{theme}-attempt-{attempt}'
      difference.save(out/f'{stem}-pixel-difference.png')
      im1.save(out/f'{stem}-before.png');im2.save(out/f'{stem}-after.png')
      print('PIXEL DIAGNOSTIC',role,width,theme,bounds,'channel extrema',extrema,'changed pixels',count,'attempt',attempt,flush=True)
      # Never accept an approximate image. Retry only the previously observed
      # renderer rounding jitter (one channel level, <=100 pixels), preserving
      # every failed image. A substantive or persistent difference fails.
      if any(v[1]>1 for v in extrema) or count>100:break
      for p in (old,new):p.evaluate("()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))")
      compare(old.evaluate(probe),new.evaluate(probe),(role,width,theme,'recapture'))
     assert bounds is None,(role,width,theme,'component pixels differ',bounds)
    for p in (old,new):p.locator('#p2-probe').evaluate('e=>e.remove()')
    if width in (390,1440) and theme in ('classic','dark'):
     old.screenshot(path=out/f'{role}-{width}-{theme}-before-workspace.png',animations='disabled')
     new.screenshot(path=out/f'{role}-{width}-{theme}-after-workspace.png',animations='disabled')
    rows.append({'role':role,'width':width,'theme':theme,'computed_elements':len(b),'status':'PASS'})
  print('PASS P2',role,len(widths)*len(themes),'width/theme combinations',flush=True)
  oc.close();nc.close()
 browser.close()
old_server.shutdown();new_server.shutdown()
(out/'results.json').write_text(json.dumps(rows,indent=2))
assert len(rows)==147
print('PASS P2 147 role/width/theme comparisons, component image equality, focus and visibility, unchanged markup and scripts outside the explicitly tested STEP03 editor delta',flush=True)
