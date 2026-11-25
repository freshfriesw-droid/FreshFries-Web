"""STEP05 targeted real Chromium failure-path tests using the existing role fixture."""
import ast, json, time
from pathlib import Path
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread
from functools import partial
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
out=root/'step05-evidence';out.mkdir(exist_ok=True)
fixture=next(ast.literal_eval(n.value) for n in ast.parse((root/'scripts/a07-design-qa.py').read_text()).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='fixture' for t in n.targets))
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=root));Thread(target=server.serve_forever,daemon=True).start()
origin=f'http://127.0.0.1:{server.server_port}/'
results=[]
with sync_playwright() as pw:
 browser=pw.chromium.launch(channel='chrome')
 for role,selector,screen in [('manager','#ffx-dashboard','dashboard'),('cashier','#cashierView','cashier'),('driver','#driverView','driver')]:
  ctx=browser.new_context(viewport={'width':390,'height':850},service_workers='block',reduced_motion='reduce')
  def route(r):
   u=r.request.url
   if not u.startswith(origin) or '/assets/ff-official-logo.png' in u or '/assets/ff-icon-192.png' in u:r.abort()
   else:r.continue_()
  ctx.route('**/*',route);page=ctx.new_page();page.goto(origin,wait_until='load');page.evaluate(fixture,role)
  page.evaluate("""async screen=>{window.__a07Rows={[screen]:{id:505,pack:'D08',style_config:{logoAsset:'brand',font:'cairo'}}};await ffDashboardStudio.sync(true);ffA07Design.refresh()}""",screen)
  if role in ('cashier','driver'):
   key='cashier' if role=='cashier' else 'attendance';page.locator('#ffx-mobile-nav button[data-key="'+key+'"]').click()
  # Inspect a real image in the real workspace, not a fabricated logo.
  image=page.locator(selector+' img').filter(has_not=page.locator('span')).first
  page.wait_for_function("""sel=>Array.from(document.querySelectorAll(sel+' img')).some(i=>i.src.startsWith('data:image/png;base64,')&&i.complete&&i.naturalWidth===192)""",arg=selector,timeout=15000)
  assert page.locator(selector).evaluate("e=>getComputedStyle(e).fontFamily.includes('Tahoma')")
  page.screenshot(path=out/f'{role}-offline-logo.png',animations='disabled')
  # Use the actual shared product tile code with a failed image request.
  result=page.evaluate("""async origin=>{
   client.storage={from:()=>({getPublicUrl:()=>({data:{publicUrl:origin+'missing-step05-image.png'}})})};
   const item={id:'qa',name:'تشكن',price:1500,image_path:'menu/12345678-1234-1234-1234-123456789abc.png',image_version:'2'};
   let added=0;const tile=ffLuxePhotoMenu.createTile(item,{quantity:1,onAdd:()=>added++});document.body.append(tile.element);
   await new Promise((resolve,reject)=>{const start=performance.now();const poll=()=>{if(tile.element.querySelector('.ffb-placeholder'))resolve();else if(performance.now()-start>5000)reject(Error('image fallback timed out'));else setTimeout(poll,50)};poll()});
   tile.element.querySelector('.ffl-picker-product').click();
   const result={fallback:true,added,quantity:tile.quantityNode.textContent,versioned:ffLuxePhotoMenu.imageUrl(item).endsWith('?v=2')};tile.element.remove();return result
  }""",origin)
  assert result=={'fallback':True,'added':1,'quantity':'1','versioned':True},result
  results.append({'role':role,'offline_logo':True,'local_font':True,**result});ctx.close()
 browser.close()
(out/'media-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
print('PASS STEP05 real workspace offline logo and failed product media in',len(results),'roles',flush=True)
