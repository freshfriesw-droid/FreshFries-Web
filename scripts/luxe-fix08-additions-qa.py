"""FIX-08 regression: real deployed source fragments in isolated Chrome.
Synthetic catalog and RPC responses; no production credentials/network.
"""
from pathlib import Path
import re
from playwright.sync_api import sync_playwright

root=Path(__file__).resolve().parents[1]
html=(root/'index.html').read_text(encoding='utf-8')
def section(start,end):
    i=html.index(start)
    return html[i:html.index(end,i)]
parser=section('const ff49NormalizeInput=', '// Prevent older create callback')
cards=section('function additionsFor(order)', 'function drawMetrics()')
staff=section('function drawOrders()', 'function drawCashier()')
driver=section('function drawDriver()', 'function drawRoster()')
review=re.search(r'<script id="ff75-unified-parser-ux">(.*?)</script>',html,re.S).group(1)
clicks=section("document.addEventListener('click',async ev=>{let b=ev.target.closest('button[data-auto]", 'initialize().catch')
late_save=section("$('ff52LateSave').onclick=async()=>{", 'function ff52RouteSelections()')
menu=(root/'scripts/luxe-unified-order-inputs-20261123.js').read_text(encoding='utf-8')
photo=(root/'scripts/luxe-shared-photo-menu-20261123.js').read_text(encoding='utf-8')
fixture="""
var user={id:'cs-fixture'},activeAdditionForm='a',additionDraft='',additionReady=true,additionData=[],lastOfferKey='',rejectPermissionReady=false,ff52LateOrderId='b';
var $=id=>document.getElementById(id),esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
var amount=x=>String(x),time=x=>String(x),branchName=x=>x,driverName=x=>x,canAction=()=>true;
var phaseNames={},cashierNames={},presenceNames={},ffLuxeAssignmentPanel=()=>'',ffLuxeOrderStaffMeta=()=>'',ffLuxeDial=()=>'',ff27DriverCall=()=>'',rejectControl=()=>'',itemLines=()=>'',ding=()=>{},notify=()=>{},toast=m=>window.lastToast=m,confirm=()=>true;
var ff49CatalogAt=0,ff49Catalog=[{id:'chicken',name:'تشكن فرايز',price:1500,category:'وجبات',active:true,parser_aliases:['تشكن']},{id:'cheese',name:'جبن شيدر وذرة',price:300,category:'سمبوسة',active:true,parser_aliases:['جبن ذرة']}];
var data={role:'customer_service',orders:[{id:'a',number:1,driver_id:'driver',status:'sent',phase:'assigned',cashier_stage:'ready',total:2000,delivery_fee:500,branch_id:'cairo'},{id:'b',number:2,driver_id:'driver',status:'sent',phase:'on_way',cashier_stage:'handed_over',total:2500,delivery_fee:500,branch_id:'cairo'}],offers:[]};
window.calls=[];
var ff49LoadCatalog=async()=>{};
var rpc=async(name,args)=>{if(name==='ff49_catalog')return ff49Catalog;window.calls.push({name,args});return {addition_id:'fixture'}};
var reload=async()=>{},ffOfferSecondsLeft=()=>0,rejectAllowed=()=>false;
$('ff52LateClose').onclick=()=>{ff52LateOrderId=null};
"""
with sync_playwright() as pw:
    browser=pw.chromium.launch(channel='chrome')
    for width in (390,1280):
        ctx=browser.new_context(viewport={'width':width,'height':850},service_workers='block')
        ctx.route('**/*',lambda route:route.abort())
        page=ctx.new_page()
        page.set_content('<div id="staffOrders"></div><div id="offersCount"></div><div id="myPresence"></div><div id="driverOffers"></div><div id="driverTasks"></div><section id="ff52LatePanel"><textarea id="ff52LateItems"></textarea><div id="ff75LateReview"></div><button id="ff75LatePreview">معاينة</button><button id="ff52LateSave" hidden disabled>حفظ</button><button id="ff52LateClose">إغلاق</button></section>')
        for code in (fixture,parser,cards,staff,driver,review,clicks,late_save,photo):
            page.add_script_tag(content=code)
        page.evaluate('drawOrders()')
        page.add_script_tag(content=menu)
        regular=page.locator('#additionItemsInput')
        save=page.locator('[data-save-addition]')
        regular.fill('2 تشكن بدون شطة | 1600\nملاحظة: اتصال بالعميل')
        page.locator('[data-ff75-preview-addition]').click()
        page.wait_for_function("window.ff75AdditionReview?.items[0].quantity===2")
        assert save.is_enabled() and save.is_visible()
        assert 'بدون شطة' in page.locator('#ff75AdditionPreview').inner_text()
        page.evaluate("window.draftNode=document.querySelector('#additionItemsInput');drawOrders()")
        assert page.evaluate("draftNode===document.querySelector('#additionItemsInput')")
        assert save.is_enabled() and save.is_visible()
        # Open the real shared menu, survive refresh, edit quantity and use its canonical preview.
        regular.locator('xpath=following-sibling::div[contains(@class,"ff-unified-wrapper")]//button').first.click()
        page.get_by_role('button',name='زيادة تشكن فرايز',exact=True).wait_for()
        page.evaluate('drawOrders()')
        page.get_by_role('button',name='زيادة تشكن فرايز',exact=True).click()
        assert '3 تشكن بدون شطة | 1600' in regular.input_value()
        page.locator('#ffUnifiedMenuReview').click()
        page.wait_for_function("window.ff75AdditionReview?.items[0].quantity===3")
        assert save.is_enabled() and save.is_visible()
        assert page.evaluate("ff75AdditionReview.items[0].unit_price") == 1600
        assert page.evaluate("ff75AdditionReview.items[0].addition_notes") == 'اتصال بالعميل'
        regular.fill('1 تشكن\nرقم العميل: 700000000')
        page.locator('[data-ff75-preview-addition]').click()
        page.wait_for_function("document.querySelector('#ff75AdditionPreview').textContent.includes('بيانات الطلب الأصلي')")
        assert save.is_hidden() and page.evaluate('ff75AdditionReview===null')
        regular.fill('1 تشكن | 1600.001')
        page.locator('[data-ff75-preview-addition]').click()
        page.wait_for_function("document.querySelector('#ff75AdditionPreview').textContent.includes('بمنزلتين')")
        assert save.is_hidden() and page.evaluate('ff75AdditionReview===null')
        regular.fill('3 تشكن بدون شطة | 1600\nملاحظة: اتصال بالعميل')
        page.locator('[data-ff75-preview-addition]').click()
        page.wait_for_function("window.ff75AdditionReview?.items[0].quantity===3")
        save.click()
        page.wait_for_function("calls.some(c=>c.name==='ff52_regular_addition_create')")
        result=page.evaluate("calls.find(c=>c.name==='ff52_regular_addition_create').args")
        assert result=={'p_order':'a','p_items':[{'item_name':'تشكن فرايز','quantity':3,'unit_price':1600,'item_notes':'بدون شطة','addition_notes':'اتصال بالعميل'}]}
        late=page.locator('#ff52LateItems')
        late.fill('1 جبن ذرة')
        late.locator('xpath=following-sibling::div[contains(@class,"ff-unified-wrapper")]//button').first.click()
        page.get_by_role('button',name='زيادة جبن شيدر وذرة',exact=True).click()
        page.locator('#ffUnifiedMenuReview').click()
        page.wait_for_function("window.ff75LateAdditionReview?.items[0].quantity===2")
        assert page.locator('#ff52LateSave').is_enabled() and page.locator('#ff52LateSave').is_visible()
        page.locator('#ff52LateSave').click()
        page.wait_for_function("calls.some(c=>c.name==='ff52_late_addition_create')")
        assert page.evaluate("calls.find(c=>c.name==='ff52_late_addition_create').args.p_items[0].quantity")==2
        page.evaluate("""data.role='driver';data.orders[0].cashier_stage='handed_over';
          additionData=[{id:'add',order_id:'a',status:'pending',amount:4800,items:[{quantity:3,item_name:'تشكن فرايز',line_total:4800,item_notes:'بدون شطة <script>'}],addition_notes:'اتصال بالعميل'}, {id:'late',order_id:'b',status:'invoiced',amount:600,late_state:'invoiced',items:[]}];
          drawDriver()""")
        assert page.locator('[data-progress="a"][data-phase="on_way"]').count()==0
        assert page.locator('[data-progress="b"][data-phase="delivered"]').count()==0
        assert 'بدون شطة <script>' in page.locator('#driverTasks').inner_text()
        assert page.locator('#driverTasks script').count()==0
        assert 'اتصال بالعميل' in page.locator('#driverTasks').inner_text()
        page.evaluate("additionData[0].status='invoiced';additionData[1].late_state='picked_up';drawDriver()")
        assert page.locator('[data-progress="a"][data-phase="on_way"]').is_visible()
        assert page.locator('[data-progress="b"][data-phase="delivered"]').is_visible()
        assert '6800 ريال' in page.locator('#driverTasks').inner_text()
        page.evaluate('additionReady=false;drawDriver()')
        assert page.locator('[data-progress="a"][data-phase="on_way"]').count()==0
        assert page.locator('[data-progress="b"][data-phase="delivered"]').count()==0
        ctx.close()
        print(f'PASS FIX-08 {width}px: actual parser/menu preview, draft sync, regular/late RPC payloads, notes escaping, invoice totals and delivery guards',flush=True)
    browser.close()
