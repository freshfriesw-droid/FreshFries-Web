"""A10 browser acceptance: report filter contract, restricted data, actual PDF/CSV and no operational writes."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]
out=root/"a10-evidence";out.mkdir(exist_ok=True)
server=ThreadingHTTPServer(("127.0.0.1",0),partial(SimpleHTTPRequestHandler,directory=root))
Thread(target=server.serve_forever,daemon=True).start()
origin=f"http://127.0.0.1:{server.server_port}/"
fixture="""async role=>{
 document.body.dataset.access='staff';document.body.classList.remove('ff-booting');
 document.getElementById('loginOverlay').classList.add('hidden');
 user={id:'qa-'+role,email:'qa@example.invalid'};
 const b={id:'b1',code:'cairo',name:'القاهرة'};
 const b2={id:'b2',code:'sam_mall',name:'سام مول'};
 const b3={id:'b3',code:'khamseen',name:'الخمسين'};
 const branches=['manager','customer_service','supervisor'].includes(role)?[b,b2,b3]:[b];
 selfPermissions={create_order:['manager','customer_service'].includes(role),view_reports:['manager','supervisor','customer_service'].includes(role),edit_order:true,assign_driver:true};
 const orders=[{id:'qa-order',number:123,branch_id:b.id,area:'منطقة تجريبية',status:'sent',phase:'assigned',cashier_stage:'waiting',driver_name:'موصل تجريبي',created_at:new Date().toISOString(),items:[]}];
 window.__a06Calls=[];window.__a09Grant=null;window.__a09DesignRows=[];window.__a09Content=[];
 client={channel:()=>{const ch={on:(event,cfg,fn)=>{if(cfg?.table==='ff_a09_grant_events')window.__a09GrantSignal=fn;return ch},subscribe:()=>ch};return ch},removeChannel:async()=>true};
 rpc=async(name,args={})=>{
  window.__a06Calls.push({name,args});
  if(name==='ff_content_effective')return window.__a09Content||[];
  if(name==='ff82_my_grant')return window.__a09Grant?[window.__a09Grant]:[];
  if(name==='ff82_manager_accounts')return [{user_id:'qa-cashier',display_name:'موظف اختباري',role:'cashier',branch_id:'b1',branch_name:'القاهرة'}];
  if(name==='ff82_manager_grants')return window.__a09Grant?[window.__a09Grant]:[];
  if(name==='ff82_manager_audit')return [{id:91,created_at:'2026-11-25T01:00:00Z',actor_id:'qa-cashier',action:'design_publish',outcome:'denied',reason:'manager_only:revoked',attempted_revision:902,effect:'no_change'}];
  if(name==='ff_a09_set_grant'){
   window.__a09Grant={id:901,recipient:args.p_recipient,role_scope:'cashier',branch_id:args.p_branch,screen:args.p_screen,capabilities:args.p_capabilities,edit_kinds:args.p_kinds,starts_at:args.p_start,ends_at:args.p_end};return 901;
  }
  if(name==='ff82_delegate_catalog')return [];
  if(name==='ff_a09_design_context')return {pack:'D01',style_config:{accent:'red'},screen:'cashier'};
  if(name==='ff_a09_design_history')return window.__a09DesignRows||[];
  if(name==='ff_a09_design_draft'){
   const id=902+window.__a09DesignRows.length;window.__a09DesignRows.unshift({id,actor_id:user.id,role_scope:role,branch_id:'b1',screen_scope:'cashier',device:args.p_device,pack:'D01',draft_name:args.p_name,style_config:args.p_patch,published_at:null});return {ok:true,revision:id};
  }
  if(name==='ff_a09_design_review')return {ok:true};
  if(name==='ff_a06_nav_scope')return {role,revision:null,mode:'accordion',drawer_width:280,bar:null};
  if(name==='ff_burger_my_branch')return {role,branches:[b]};
  if(name==='ff_v12_assembly_snapshot')return {role:'assembly',branch:b,orders:[]};
  if(name==='ff_burger_menu'||name==='ff_burger_list')return [];
  if(name==='ff_burger_online_status')return [];
  if(name==='ff80_dashboard_metrics')return {role,business_day:'2026-11-25',orders_today:1,late_today:0,completed_today:0,available_drivers:0};
  if(name==='ff49_catalog')return [{id:'qa-item',name:'تشكن فرايز',price:1500,active:true,parser_aliases:['تشكن']}];
  if(name==='ff_a07_effective_designs')return window.__a07Rows||{};
  if(name==='ff_a07_design_catalog')return window.__a07Catalog||[];
  if(name==='ff_a07_named_design')return 4321;
  if(name==='ff81_effective_design')return null;
  return [];
 };
 data={role,branches,orders:role==='manager'||role==='customer_service'||role==='supervisor'?orders:[],drivers:[],offers:[],driver_id:'qa-driver',my_presence:'offline'};
 if(role==='assembly'){await ffV12Start();return}
 if(role==='burger_kitchen'){data=null;await window.ffBurgerStart();return}
 draw();
}"""

from subprocess import run
bundle=root/"node_modules/html2pdf.js/dist/html2pdf.bundle.min.js"
assert bundle.is_file()
with sync_playwright() as pw:
 browser=pw.chromium.launch(channel="chrome")
 ctx=browser.new_context(viewport={"width":390,"height":850},service_workers="block",reduced_motion="reduce",accept_downloads=True)
 def route(r):
  if r.request.url.startswith(origin):r.continue_()
  elif "html2pdf.js@" in r.request.url:r.fulfill(path=str(bundle),content_type="application/javascript")
  else:r.abort()
 ctx.route("**/*",route)
 page=ctx.new_page();page.goto(origin,wait_until="load");page.evaluate(fixture,"manager")
 page.evaluate("""()=>{
 const prior=rpc;
 window.a10Revoked=false;window.a10Escalated=false;window.a10DetailsChanged=false;window.a10Presets=[];window.a10Shared=[];
 Object.defineProperty(navigator,'canShare',{configurable:true,value:()=>true});
 Object.defineProperty(navigator,'share',{configurable:true,value:async payload=>{const f=payload.files[0];window.a10Shared.push({name:f.name,type:f.type,header:await f.slice(0,4).text()})}});
 window.__a09Content=[{content_key:'reports.section.items',body:'أصناف مخصصة اختباريًا'},{content_key:'reports.section.finance',body:'ملخص مخصص'},{content_key:'reports.pdf_title',body:'عنوان PDF مخصص'},{content_key:'reports.pdf_note',body:'ملاحظة PDF مخصصة'}];
 rpc=async(name,args={})=>{
 if(name==='ff_a10_reporting_center'){
 window.__a06Calls.push({name,args});
 const manager=data.role==='manager',money=manager&&!window.a10Revoked;
 return {from:args.p_from,to:args.p_to,role:data.role,scope:'فرع اختبار',access_key:window.a10Revoked?'revoked':'allowed',generated_at:'2026-11-25T01:00:00Z',
 available_sections:money?['summary','finance','orders','branches','drivers','staff','areas','items','ratings','cases','attendance','analytics','comparisons','approval']:['summary','orders','items'],
 branches:[{id:'b1',name:'القاهرة'}],driver_options:[{id:'d1',name:'موصل تجريبي',branch_id:'b1'}],
 filter_options:{staff:[{id:'s1',name:'موظف تجريبي'}],areas:['منطقة اختبار'],items:['صنف اختبار']},
 filters:{branch:args.p_branch,driver:args.p_driver},partial_order_filter:!!(args.p_staff||args.p_area||args.p_item||args.p_status),
 totals:{orders:3,delivered:2,cancelled:1,pending:0,late_pending:0,late_completed:1,late:1,net:money?4000:undefined,item_sales:money?3200:undefined,delivery_fees:money?800:undefined,fastest_minutes:20,rating_avg:2,low_ratings:1},
 finance_evidence:money?{confirmed_received:1400,fee_collection_confirmed:250,draft_received:2200,confirmed_difference:100,closed_statements:1,fees_need_review:0}:undefined,
 items:[{item_name:'=HYPERLINK("bad")',quantity:2,revenue:money?1000:undefined}],
 offer_performance:[{offer_name:'عرض مثبت',orders:1,quantity:2,registered_value:money?1000:undefined}],
 internal_low_ratings:money?[{rating_id:'r1',order_number:123,rater_role:'cashier',stars:2,note:window.a10DetailsChanged?'REPLACED-QA':'PRIVATE-QA'}]:[],
 cashier_coordination:[],days:[{work_day:args.p_from,orders:3,net:money?4000:undefined}],comparison:{today:{orders:3,delivered:2,net:money?4000:undefined}},
 reservation_summary:{total:1,collected:1},dispatch:{offered:2,accepted:1},additions:{count:1,invoiced_count:1},settlements:money?[]:undefined};
 }
 if(name==='ff_report_preset_list')return window.a10Presets;
 if(name==='ff_report_preset_save'){window.a10Presets=[{id:'preset-1',title:args.p_title,sections:args.p_sections,trend:args.p_trend}];return true}
 if(name==='ff_a10_report_grants')return {accounts:[{id:'s1',name:'موظف تجريبي'}],grants:[]};
 if(name==='ff_a10_report_grant'){window.a10Grant=args;return true}
 if(name==='ff_a10_escalate_rating'){window.a10Escalated=args;return {already_exists:false}}
 return prior(name,args);
 };
 window.ff76OpenReports();
 }""")
 page.locator('#ff76Body [data-report-section=finance]').wait_for()
 assert 'أصناف مخصصة اختباريًا' in page.locator('#ff76Body [data-report-section=items] h3').inner_text()
 assert 'المبالغ المسجلة ورسوم التوصيل' in page.locator('#ff76Body [data-report-section=finance] h3').inner_text()
 assert 'ملخص مخصص' in page.locator('#ff76Body [data-report-section=finance] h3').inner_text()
 assert "تحصيل مثبت" in page.locator('#ff76Body').inner_text()
 assert "أداء العروض" in page.locator('#ff76Body').inner_text()
 assert "PRIVATE-QA" in page.locator('#ff76Body').inner_text()
 page.locator('#ff76Branch').select_option('b1');page.locator('#ff76Run').click()
 page.locator('#ff76Body [data-report-section=finance]').wait_for()
 for field,val in [('ff76Driver','d1'),('ffA10Staff','s1'),('ffA10Area','منطقة اختبار'),('ffA10Item','صنف اختبار'),('ffA10Status','delivered')]:page.locator('#'+field).select_option(val)
 page.locator('#ff76Run').click();page.locator('#ff76Body [data-report-section=finance]').wait_for()
 args=page.evaluate("()=>window.__a06Calls.filter(x=>x.name==='ff_a10_reporting_center').at(-1).args")
 assert args["p_branch"]=="b1" and args["p_driver"]=="d1" and args["p_staff"]=="s1" and args["p_area"]=="منطقة اختبار" and args["p_item"]=="صنف اختبار" and args["p_status"]=="delivered"
 assert page.locator('#ff76ApprovalBox').is_hidden()
 page.locator('#ffA10Grants summary').click()
 page.locator('#ffA10GrantUser').select_option('s1');page.locator('#ffA10GrantSection').select_option('finance');page.locator('#ffA10GrantAllowed').select_option('false');page.locator('#ffA10GrantSave').click()
 assert page.evaluate("window.a10Grant.p_allowed===false")
 page.locator('#ff76Mode').select_option('custom')
 page.locator('#ff76Choices input').evaluate_all("nodes=>nodes.forEach(n=>{n.checked=n.value==='items';n.dispatchEvent(new Event('change'))})")
 assert page.locator('#ff76Body [data-report-section]').count()==1
 with page.expect_download(timeout=30000) as d:page.locator('#ff76CSV').click()
 d.value.save_as(out/"report.csv")
 csv=(out/"report.csv").read_text(encoding="utf-8-sig")
 assert "'=HYPERLINK" in csv and "PRIVATE-QA" not in csv and "تحصيل مثبت" not in csv
 # Native Excel opens as an actual OOXML ZIP, with RTL and no formulas.
 with page.expect_download(timeout=30000) as x:page.locator('#ff76Excel').click()
 assert x.value.suggested_filename.endswith('.xlsx')
 x.value.save_as(out/'report.xlsx')
 from zipfile import ZipFile
 from xml.etree import ElementTree as ET
 with ZipFile(out/'report.xlsx') as z:
  assert z.testzip() is None
  xml=z.read('xl/worksheets/sheet1.xml')
  ns={'m':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
  worksheet=ET.fromstring(xml)
  assert worksheet.find('m:sheetViews/m:sheetView',ns).attrib['rightToLeft']=='1'
  assert not worksheet.findall('.//m:f',ns)
  values=[v.text or '' for v in worksheet.findall('.//m:t',ns)]
  assert '=HYPERLINK("bad")' in values and not any('PRIVATE-QA' in v or 'تحصيل مثبت' in v for v in values)
  assert any('صنف' in v or 'أصناف' in v for v in values)
 # Parse the actual workbook with an independent spreadsheet reader.
 from openpyxl import load_workbook
 wb=load_workbook(out/'report.xlsx',data_only=False)
 assert wb.active.sheet_view.rightToLeft is True
 assert all(c.data_type!='f' for row in wb.active.iter_rows() for c in row)
 wb.close()
 print('PASS STEP10 XLSX: ZIP CRC, independent workbook reader, RTL, literal formula-like text and section isolation',flush=True)

 with page.expect_download(timeout=90000) as d:page.locator('#ff76Download').click()
 d.value.save_as(out/"report.pdf")
 print("PDF bytes:",(out/"report.pdf").stat().st_size,flush=True)
 assert (out/"report.pdf").read_bytes().startswith(b"%PDF")
 run(["pdftoppm","-f","1","-l","1","-scale-to","800","-png",str(out/"report.pdf"),str(out/"render")],check=True)
 from PIL import Image
 im=Image.open(out/"render-1.png").convert("L")
 assert im.getextrema()[0]<100 and sum(1 for p in im.getdata() if p<200)>500,"PDF is visually blank"
 # Exercise the actual preview and sharing code; the OS share boundary is a
 # deterministic stub, not a claim of delivery to a real external recipient.
 page.locator('#ff76Share').click()
 page.locator('#ff76PdfDialog').wait_for(state='visible',timeout=90000)
 page.locator('#ff76DlgShare').click()
 page.wait_for_function("()=>window.a10Shared.length===1")
 assert page.evaluate("window.a10Shared[0].header")=='%PDF'
 assert page.evaluate("window.a10Shared[0].type")=='application/pdf'
 # Revocation of detail ownership can occur even when role/branch hash is unchanged.
 page.evaluate("window.a10DetailsChanged=true")
 page.locator('#ff76DlgShare').click()
 page.wait_for_function("()=>document.querySelector('#ff76Body').textContent===''")
 assert page.evaluate("window.a10Shared.length") == 1
 assert page.locator('#ff76Excel').is_disabled()
 page.evaluate("window.a10DetailsChanged=false")
 page.locator('#ff76Run').click()
 page.locator('#ff76Body [data-report-section=items]').wait_for()
 print('PASS STEP10 PDF preview and share, revoked detail blocks stale file even with unchanged access key',flush=True)

 page.evaluate("window.a10Revoked=true")
 page.locator('#ff76CSV').click()
 page.wait_for_function("()=>document.querySelector('#ff76Body').textContent===''",timeout=20000)
 assert page.locator('#ff76Download').is_disabled() and page.locator('#ff76Excel').is_disabled()
 page.evaluate("()=>{window.a10Revoked=false;data.role='supervisor';user={id:'qa-supervisor'};window.dispatchEvent(new Event('ff-luxe-session-reset'));window.ff76OpenReports()}")
 page.locator('#ff76Body [data-report-section=items]').wait_for()
 assert page.locator('#ff76Body [data-report-section=finance]').count()==0 and page.locator('#ffA10Grants').is_hidden()
 assert "PRIVATE-QA" not in page.locator('#ff76Body').inner_text()
 for width in (320,390,768,1440):
  page.set_viewport_size({"width":width,"height":850})
  page.screenshot(path=out/f"report-{width}.png",animations="disabled")
 print("PASS A10 report filters, section delegation, scoped output, CSV injection protection, real nonblank PDF, authorization revocation and mobile widths",flush=True)
 ctx.close();browser.close()
server.shutdown()
