import fs from 'node:fs';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import zlib from 'node:zlib';

const get = path => fs.readFileSync(path);
const html = get('index.html').toString('utf8');
assert.match(html, /<!doctype html>/i, 'Missing HTML doctype');
assert.match(html, /href="\.\/manifest\.webmanifest"/, 'Missing PWA link');
assert.match(html, /https:\/\/api\.freshfriesz\.com/, 'Production gateway URL was lost');
assert.match(html, /ff61-employees/, 'Employee application portal missing');
assert.match(html, /ff71-customer-phone-otp/, 'Customer OTP portal missing');
assert.match(html, /ff_v12_assembly_set_stage/, 'Assembly workflow missing');

assert.match(html, /window\.addEventListener\('ff-luxe-session-reset',ff61ClearPrivate\)/,
  'Employee requests must invalidate private state on every session reset');
assert.match(html, /const current=\(\)=>token===ff61AccessToken&&ff61SessionEpoch===epoch&&ff61Viewer\(\)===viewer/,
  'Staff permission responses must be tied to the active account and role');
assert.match(html, /const current=\(\)=>ff61BadgeToken===token&&ff61SessionEpoch===epoch&&/,
  'Staff notification badges must never show a previous account response');
assert.match(html, /if\(!current\(\)\)return;\s*capabilities=permitted/,
  'Grant/revoke updates must discard stale permission results');
assert.match(html, /if\(!permitted\.notify\)\{ff61BadgeToken\+\+;/,
  'Revoked notification capability must invalidate pending counters');
assert.match(html, /byId\('logoutBtn'\)\.addEventListener\('click',ff61ClearPrivate\)/,
  'Logout must immediately clear employee-management UI');


assert.match(html, /function ff51ClearPrivate\(\)/, 'FF51 must clear all private customer/archive UI on logout');
assert.match(html, /window\.addEventListener\('ff-luxe-session-reset',\(\)=>\{ff51ClearPrivate\(\)/,
  'FF51 must listen for logout/session change');
assert.match(html, /async function ff51LoadArchive\(reset=false\)[\s\S]*?if\(!current\(\)\)return;/,
  'Archive result must recheck viewer and filter after RPC');
assert.match(html, /ff51ArchiveSeq\+\+;ff51ArchiveRows=\[\];ff51ArchiveOffset=0;/,
  'Archive close must erase page records and invalidate outstanding requests');
assert.match(html, /async function ff51LoadCustomers\(\)[\s\S]*?if\(!current\(\)\)return;/,
  'Customer directory must reject stale account responses');
assert.match(html, /async function ff51CustomerNotes\(phone\)[\s\S]*?if\(!current\(\)\)return;/,
  'Customer notes must reject stale account responses');
assert.match(html, /async function ff51LoadRatings\(\)[\s\S]*?if\(!current\(\)\)return;/,
  'Ratings must reject stale account responses');
assert.match(html, /Prevent spreadsheet formula injection/, 'Archive CSV must protect spreadsheet users from formula injection');


const completedFile=get('scripts/luxe-completed-universal-20261123.js').toString('utf8');
new vm.Script(completedFile, {filename:'scripts/luxe-completed-universal-20261123.js'});
assert.match(completedFile, /window\.addEventListener\('ff-luxe-session-reset',clear\)/,
  'Completed order data must be wiped when the session resets');
assert.match(completedFile, /if\(!stillAuthorized\(\)\)return;/,
  'Stale completed order records must never update the UI');
assert.match(completedFile, /if\(stillAuthorized\(\)\)status\.textContent=/,
  'Async errors must not expose old account state');
assert.match(completedFile, /requestId===requestSequence/,
  'Overlapping history responses must not overwrite the latest query');
assert.match(completedFile, /if\(!canShowAction\(\)\)return;/,
  'Completed action feedback must use the current authenticated viewer');


assert.match(html, /data=null;user=null;window\.dispatchEvent\(new Event\('ff-luxe-session-reset'\)\)/,
  'Every resetUI must invalidate asynchronous manager-only reports');
const settlementHistory=get('scripts/luxe-history-period-20261123.js').toString('utf8');
new vm.Script(settlementHistory, {filename:'scripts/luxe-history-period-20261123.js'});
assert.match(settlementHistory, /window\.addEventListener\('ff-luxe-session-reset',resetPrivateReport\)/,
  'Sensitive settlement report must clear on session reset');
assert.match(settlementHistory, /if\(!stillAuthorized\(\)\)return;/,
  'Late settlement responses must be discarded after role or date changes');
assert.match(settlementHistory, /list\.replaceChildren\(\);\s*state\.textContent='';/,
  'Settlement report data must be erased when the viewer changes');

assert.doesNotMatch(html, /\.head,#toast\{display:none!important\}/, 'Legacy operational feedback must not be globally hidden');
assert.match(html, /id="toast" class="alert hidden" role="status" aria-live="polite" aria-atomic="true"/,
  'Legacy toast must expose accessible status semantics');
assert.match(html, /#toast\{\s*z-index:1245;/, 'Legacy toast must be visible over the shell');
assert.match(html, /bottom:calc\(118px \+ env\(safe-area-inset-bottom\)\)/,
  'Mobile status must stay above the bottom navigation');
assert.doesNotMatch(html, /@media\(min-width:1151px\)\{main,#ffx-topbar\{margin-right:278px\}\}/,
  'Remove obsolete desktop gutter override');

assert.match(html, /ff28_customer/, 'Customer records must be server-filtered');
assert.doesNotMatch(html, /sb_secret_[A-Za-z0-9]+/, 'Secret API key must never be embedded in the client');
assert.match(html, /sidebar\.inert=true;sidebar\.setAttribute\('aria-hidden','true'\)/,
  'Sidebar must be inaccessible when closed');
assert.match(html, /sidebar\.inert=false;sidebar\.removeAttribute\('aria-hidden'\)/,
  'Sidebar must become accessible when opened');
assert.match(html, /--ffl-drawer-width:278px/, 'Canonical drawer sizing missing');
assert.match(html, /visibility:hidden;\s*pointer-events:none;/, 'Closed drawer must not accept input');
assert.doesNotMatch(html, /#ffx-nav-toggle\{display:inline-flex!important\}/, 'Remove dead sidebar toggle rule');

const operationsPath = 'styles/luxe-operations.css';
assert.ok(html.includes(`href="./${operationsPath}"`));
const operations = get(operationsPath).toString('utf8');
assert.match(operations, /#cashierOrders>\.item:not\(\.ff-luxe-cancelled\)/, 'Ordinary cashier cards must exclude cancelled orders');
assert.match(operations, /#driverTasks>\.item:not\(\.ff-luxe-cancelled\)/, 'Ordinary driver cards must exclude cancelled orders');
assert.doesNotMatch(html + operations, /\.ff60-order,\s*\.ff-luxe-cancelled,/, 'Generic blue cards must not override cancelled orders');
assert.match(operations, /#cashierOrders>\.ff-luxe-cancelled\{[^}]*#b91c1c/, 'Cashier cancellation outline must be red');

const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)];
let validated = 0;
for (let i=0; i<scripts.length; i++) {
  if (/\bsrc\s*=/.test(scripts[i][1])) continue;
  new vm.Script(scripts[i][2], {filename:`inline-script-${i}.js`});
  validated++;
}
assert.ok(validated >= 20, `Expected at least 20 JavaScript modules; found ${validated}`);
// Regression: stalled authentication must offer a retry but must never unlock the app.
const watchdogScript = scripts.find(m => /id="ff-luxe-boot-watchdog"/.test(m[1]))?.[2];
assert.ok(watchdogScript, 'Boot watchdog script missing');
assert.match(html, /<noscript>[\s\S]*?JavaScript[\s\S]*?<\/noscript>/, 'Missing no-JavaScript explanation');
assert.doesNotMatch(watchdogScript, /classList\.remove\(['"]ff-booting/, 'Watchdog may not bypass session checks');
let fireWatchdog, booting = true;
const message = {textContent: 'جارِ استعادة جلسة فريش فرايز…'};
const boot = {links: [], querySelector: () => boot.links[0] || null, appendChild: node => boot.links.push(node)};
const sandbox = {
  setTimeout: (fn, ms) => { assert.equal(ms, 20000); fireWatchdog = fn; return 1; },
  clearTimeout: () => {},
  document: {
    body: {classList: {contains: name => name === 'ff-booting' && booting}},
    getElementById: name => name === 'ff65Boot' ? boot : name === 'ff65BootMessage' ? message : null,
    createElement: tag => ({tag, style: {}, setAttribute(name, value) {this[name] = value;}})
  },
  window: {location: {href: 'https://example.com/index.html'}, addEventListener: () => {}}
};
vm.runInNewContext(watchdogScript, sandbox, {timeout: 1000});
assert.equal(typeof fireWatchdog, 'function');
fireWatchdog();
assert.equal(boot.links.length, 1, 'Retry link must be added once');
assert.equal(boot.links[0].href, 'https://example.com/index.html');
assert.match(message.textContent, /تأخر تحميل النظام/);
fireWatchdog();
assert.equal(boot.links.length, 1, 'Avoid duplicate retry links');
booting = false;
fireWatchdog();
assert.equal(boot.links.length, 1, 'Do not change session state after boot completes');
const operationalFiles = [
  'scripts/luxe-operational-fixes-20261121.js',
  'scripts/luxe-operational-polish-20261121.js',
  'assets/ff-pinned-cairo-v38-37.js'
];
for (const filename of operationalFiles) {
  new vm.Script(get(filename).toString('utf8'), {filename});
}
assert.match(html, /v38\.38\.0/, 'Version not updated');
assert.match(html, /ff_luxe_cancel_assigned/, 'Assigned-order cancellation missing');
assert.match(html, /ff_luxe_ack_cashier_cancel/, 'Cashier cancellation acknowledgement missing');
assert.match(html, /ff_luxe_dispatch_preview/, 'Courier candidate preview missing');
assert.match(html, /ff_luxe_driver_rate_order/, 'Courier feedback missing');
assert.match(html, /ff_luxe_driver_grievance/, 'Courier grievance form missing');
assert.match(get(operationalFiles[1]).toString('utf8'), /ff_luxe_manager_driver_progress/,
  'Manager driver-phase action missing');
const guardedReset=get('scripts/luxe-a12-recovery.js').toString('utf8');
new vm.Script(guardedReset,{filename:'scripts/luxe-a12-recovery.js'});
assert.match(html,/scripts\/luxe-a12-recovery\.js\?v=20261125-a12/,'A12 recovery controller missing');
assert.doesNotMatch(html+get(operationalFiles[0]).toString('utf8')+guardedReset,/rpc\(['"]ff_(?:luxe_reset_(?:scoped|safe|preview)|manager_reset_data)/,'Unsafe legacy reset must not be called');
assert.match(guardedReset,/rpc\('ff_a12_reset_preview'/,'Preview must be available');
assert.match(guardedReset,/rpc\('ff_a12_reset_execute'/,'Scoped server backup and reset missing');
assert.match(guardedReset,/rpc\('ff_a12_restore'/,'Server-side recovery missing');
assert.match(guardedReset,/p_token:p\.result\.token/,'Exact preview token required');
assert.match(guardedReset,/backup_saved!==true/,'Server must confirm backup saved');
assert.match(guardedReset,/exact_match!==true/,'Server must confirm recovery equality');
assert.match(guardedReset,/id="ffA12Execute"[^>]*disabled/,'Reset starts disabled');
assert.match(guardedReset,/ff-luxe-session-reset/,'Reset private state on logout');

const manifest=JSON.parse(get('manifest.webmanifest').toString('utf8'));
assert.equal(manifest.start_url, './index.html');
assert.equal(manifest.display, 'standalone');
assert.equal(manifest.dir, 'rtl');
assert.ok(manifest.icons.length>=2);
const signature=Buffer.from([137,80,78,71,13,10,26,10]);
for (const icon of manifest.icons) {
  assert.match(icon.src, /^\.\/assets\/ff-icon-(192|512)\.png$/, 'Unexpected manifest icon');
  const png=get(icon.src.replace(/^\.\//,''));
  assert.ok(png.subarray(0,8).equals(signature), `PNG signature invalid: ${icon.src}`);
  const width=png.readUInt32BE(16),height=png.readUInt32BE(20),name=Number(icon.sizes.split('x')[0]);
  assert.equal(width,name); assert.equal(height,name);
  assert.equal(png[24],8, 'PNG icons must use 8-bit indexed palette');
  assert.equal(png[25],3, 'PNG icons must use indexed color');
  const parts=[];
  for (let pos=8;pos<png.length;) {
    const size=png.readUInt32BE(pos),type=png.toString('ascii',pos+4,pos+8);
    assert.ok(pos+size+12<=png.length, 'Bad PNG chunk length');
    if(type==='IDAT')parts.push(png.subarray(pos+8,pos+8+size));
    pos+=size+12;
  }
  const decompressed=zlib.inflateSync(Buffer.concat(parts));
  assert.equal(decompressed.length,name*(1+name), `Invalid image raster length: ${icon.src}`);
}
const sw=get('sw.js').toString('utf8');
assert.match(sw, /req\.mode === 'navigate'/, 'Navigation must not be served from a user-data cache');
assert.match(sw, /fetch\(req, \{ cache: 'no-store' \}\)/, 'Navigation must be fetched network-only');
assert.ok(fs.existsSync('offline.html'), 'Missing offline fallback');
console.log(`PASS: ${validated} inline JS syntax checks; PWA manifests/icons/zlib verified; secure offline rules; required portals present`);

// F-01: deterministic Asia/Aden boundary checks (no database access).
const f01Source=get('scripts/luxe-f01-operational-day-20261123.js').toString('utf8');
new vm.Script(f01Source, {filename:'scripts/luxe-f01-operational-day-20261123.js'});
const f01Context={
  window:{}, document:{getElementById:()=>null}, Date, Intl, console, TypeError,
};
vm.runInNewContext(f01Source,f01Context);
assert.match(html,/luxe-f01-operational-day-20261123\.js/,'F01 module must load');
assert.match(html,/if\(window\.ffF01BusinessDate\)return window\.ffF01BusinessDate\(\)/,
  'Manager reporting must default to 8am business day');
assert.match(get('scripts/luxe-history-period-20261123.js').toString('utf8'),
  /window\.ffF01BusinessDate/,'Historic period defaults must use the business day');
assert.match(get('scripts/luxe-completed-universal-20261123.js').toString('utf8'),
  /window\.ffF01BusinessDate/,'Completed archive must use business-day date selector');
const timeCases=[
 ['2026-11-23T05:30:00Z','2026-11-23',false], // 08:30 Sana'a
 ['2026-11-23T11:00:00Z','2026-11-23',false],
 ['2026-11-23T20:59:59Z','2026-11-23',false],
 ['2026-11-23T21:30:00Z','2026-11-23',false], // 00:30 Nov 24
 ['2026-11-23T22:59:59Z','2026-11-23',false], // 01:59 Nov 24
 ['2026-11-23T23:00:00Z','2026-11-23',true],  // 02:00 Nov 24
 ['2026-11-24T04:59:59Z','2026-11-23',true],  // 07:59 Nov 24
 ['2026-11-24T05:00:00Z','2026-11-24',false], // 08:00 Nov 24
];
for(const [stamp,expectedDay,expectedFlag] of timeCases){
  assert.equal(f01Context.window.ffF01BusinessDate(new Date(stamp)),expectedDay,
    'F01 business day: '+stamp);
  assert.equal(f01Context.window.ffF01IsClosedHours(new Date(stamp)),expectedFlag,
    'F01 closed-hours detection: '+stamp);
}
const schemaSQL=get('supabase/migrations/20261123_f01_operational_day.sql').toString('utf8');
const reportSQL=get('supabase/migrations/20261123_f01_business_reports.sql').toString('utf8');
const testSQL=get('supabase/tests/f01_business_date.sql').toString('utf8');
assert.match(schemaSQL,/ADD COLUMN IF NOT EXISTS business_date date/);
assert.match(schemaSQL,/ff_f01_stamp_order/);
assert.match(schemaSQL,/ff_f01_anomaly_notice/);
assert.match(schemaSQL,/ff_f01_daily_summary/);
assert.match(reportSQL,/ff40_operations_report/);
assert.match(reportSQL,/ff51_order_archive/);
assert.match(testSQL,/2026-11-24 08:00:00\+03/);


// Burger station: login isolation, durable server-side transitions, audit and live alerts.
const burgerScript=get('scripts/luxe-burger-kitchen-20261123.js').toString('utf8');
new vm.Script(burgerScript,{filename:'scripts/luxe-burger-kitchen-20261123.js'});
assert.match(html,/luxe-burger-kitchen-20261123\.js/, 'Burger station module missing');
assert.match(html,/window\.ffBurgerStart\(\)/, 'Kitchen account must route to its dedicated interface');
assert.match(html,/window\.ffBurgerActive\?\.\(\)/, 'Kitchen role must not poll staff snapshot');
assert.match(html,/data-ff-burger-notify/, 'Cashier order burger shortcut missing');
assert.match(html,/window\.ffBurgerReset\?\.\(\)/, 'Kitchen session logout cleanup missing');
assert.match(burgerScript,/ff_burger_send/, 'Cashier order submission RPC missing');
assert.match(burgerScript,/ff_burger_transition/, 'Accept-ready-skip RPC missing');
assert.match(burgerScript,/data-ff-burger-start/, 'Prep timer missing');
assert.match(burgerScript,/postgres_changes/, 'Realtime hint missing');
assert.match(burgerScript,/ffBurgerCashierReady/, 'Ready alert list missing');

assert.match(burgerScript,/ff-burger-product/, 'Tap-to-add burger buttons are missing');
// The unified photo picker owns the DOM click listeners; the burger station injects
// quantity callbacks. Check both sides of this actual contract, not the retired
// product.addEventListener() implementation (FIX-02).
const photoMenuScript=get('scripts/luxe-shared-photo-menu-20261123.js').toString('utf8');
new vm.Script(photoMenuScript,{filename:'scripts/luxe-shared-photo-menu-20261123.js'});
assert.match(html,/luxe-shared-photo-menu-20261123\.js/, 'Shared photo menu must be loaded');
assert.match(burgerScript,/ui\.createTile\(item,\{quantity:0,quantityInput:qty,showPrice:true,onAdd:\(\)=>shift\(1\),onRemove:\(\)=>shift\(-1\)\}\)/,
  'Burger picker must wire tap/plus/minus to the quantity stepper');
assert.match(photoMenuScript,/product\.addEventListener\('click',\(\)=>opts\.onAdd\?\.\(\)\)/,
  'Tap product must dispatch the increment callback');
assert.match(photoMenuScript,/plus\.addEventListener\('click',\(\)=>opts\.onAdd\?\.\(\)\)/,
  'Photo picker plus must dispatch the increment callback');
assert.match(photoMenuScript,/less\.addEventListener\('click',\(\)=>opts\.onRemove\?\.\(\)\)/,
  'Photo picker minus must dispatch the decrement callback');
assert.match(burgerScript,/product\.onclick=\(\)=>shift\(1\)/,'Fallback burger tap must increment');
assert.match(burgerScript,/less\.onclick=\(\)=>shift\(-1\);more\.onclick=\(\)=>shift\(1\)/,
  'Fallback burger plus/minus must adjust quantity');
assert.match(burgerScript,/qty\.dataset\.burgerItem=item\.id/,'Order payload must retain official menu ID');
assert.match(burgerScript,/Math\.max\(0,Math\.min\(99,Number\(value\)\|\|0\)\)/,
  'Quantity buttons must enforce 0–99 bounds and normalize nonnumeric input');
assert.match(burgerScript,/picker\.element\.querySelector\('\.ffl-picker-product'\)\?\.setAttribute\('aria-pressed'/,
  'Shared picker must expose the selected product state');
assert.match(photoMenuScript,/product\.setAttribute\('aria-label','إضافة '/,
  'Product picker must expose accessible product names');
assert.match(burgerScript,/رقم فاتورة الكاشير \(اختياري\)/,'Burger invoice input must be visibly optional');
assert.doesNotMatch(burgerScript,/name="invoice" required/,'Burger invoice cannot be required in HTML');
assert.doesNotMatch(burgerScript,/if\(!f\('invoice'\)\.value\.trim\(\)\)/,'Burger invoice cannot be required before saving');
const burgerInvoiceSQL=get('supabase/migrations/20261123_burger_optional_invoice.sql').toString('utf8');
assert.match(burgerInvoiceSQL,/length\(btrim\(invoice_ref\)\) <= 80/,'DB must permit empty invoice references');
assert.match(burgerInvoiceSQL,/length\(btrim\(coalesce\(p_invoice,''\)\)\) > 80/,'Server must retain invoice length validation');

assert.match(burgerScript,/id="ffBurgerKitchenLogout"/,'Burger kitchen must show a dedicated visible logout button');
assert.match(burgerScript,/ffBurgerDrawerLogout/,'Burger kitchen must show logout in mobile drawer');
assert.match(burgerScript,/button\.click\(\)/,'Kitchen logout must invoke existing authenticated sign-out');
assert.match(burgerScript,/attachKitchenDrawer\(\); \/\/ Logout must remain available even if a network\/RPC request fails/,'Logout must be visible before any kitchen RPC calls');
assert.match(burgerScript,/\$\(kitchenNavId\)\?\.remove\(\)/,'Burger drawer logout must be removed when leaving kitchen mode');

const burgerSQL=get('supabase/migrations/20261123_burger_kitchen_workflow.sql').toString('utf8');
const burgerRoles=get('supabase/migrations/20261123_burger_kitchen_staff_roles.sql').toString('utf8');
assert.match(burgerSQL,/ENABLE ROW LEVEL SECURITY/,'Burger ticket RLS missing');
assert.match(burgerSQL,/ff_burger_ticket_branch_read/,'Kitchen branch access policy missing');
assert.match(burgerSQL,/ff_burger_event_and_notify/,'Burger notification trigger missing');
assert.match(burgerSQL,/ON CONFLICT\(client_token\) DO NOTHING/,'Duplicate send guard missing');
assert.match(burgerSQL,/t\.kitchen_id/, 'Kitchen receiver not present in list');
assert.match(burgerRoles,/ff28_my_role/,'Kitchen login role not installed');
assert.match(burgerRoles,/burger_kitchen/,'Kitchen staff role not supported');
const edgeBurger=get('supabase/functions/ff61-employees/index.ts').toString('utf8');
assert.match(edgeBurger, /"burger_kitchen"/,'Employee approval endpoint missing kitchen role');


const offerSeconds=vm.runInNewContext(html.slice(html.indexOf('function ffOfferSecondsLeft'),
  html.indexOf('function drawDriver()'))+'\nffOfferSecondsLeft');
const offerStart=Date.parse('2026-11-24T05:00:00Z');
assert.equal(offerSeconds('2026-11-24T05:03:00Z',offerStart),180);
assert.equal(offerSeconds('2026-11-24T05:10:00Z',offerStart),600);
assert.equal(offerSeconds('2026-11-24T04:59:59Z',offerStart),0);
assert.equal(offerSeconds('',offerStart),'—');

// Use the shipped parser with representative catalog entries and check the preview payload.
const parserSource=html.slice(html.indexOf('const ff49NormalizeInput='),
  html.indexOf('// Prevent older create callback'));
const menuNames=['تشكن فرايز','تشكن استربس','رايس تشكن فرايز','سماش برجر دبل أسمر',
  'جبن شيدر وذرة','جبن شيدر وهالبينو'];
const parseQuick=vm.runInNewContext(parserSource+'\nff49ParseItemsAndNotes',{
  ff49Catalog:menuNames.map((name,id)=>({id:id+1,name,price:1000}))
});
const preview=parseQuick(['١ تشكن بدون شطّة','1 استربس','1 رايس','2 برجر اسمر دبل',
  '1 جبن ذرة','1 هلبينو','٧٧٧١٢٣٤٥٦','شارع القاهرة','0','اسم الموصل: أحمد',
  '1 صنف مجهول'].join('\n'),{allowPartial:true});
assert.deepEqual(Array.from(preview.items,item=>item.name),menuNames);
assert.equal(preview.items[0].item_notes,'بدون شطّة');
assert.equal(preview.items[3].qty,2);
assert.equal(preview.meta.phone,'777123456');
assert.equal(preview.meta.area,'شارع القاهرة');
assert.equal(preview.meta.fee,0);
assert.equal(preview.meta.driver,'أحمد');
assert.equal(preview.errors.length,1);
assert.equal(preview.errors[0].line,11);
const labelled=parseQuick([
  '١ تشكن', 'اسمُ العميل： مُحمّد   علي', 'العنوان: حيّ   الجامعة',
  'اسم الموصل: أحْمَد  علي', 'هاتف العميل: ٧٧٧ ۱۲۳-٤٥٦',
  'رسوم التوصيل: ٥٠٠', 'ملاحظات: بَدون   شطّة',
  'حَجْز: استلام  مسائي'
].join('\n'));
assert.equal(labelled.meta.customer,'مُحمّد   علي');
assert.equal(labelled.meta.area,'حيّ   الجامعة');
assert.equal(labelled.meta.driver,'أحْمَد  علي');
assert.equal(labelled.meta.phone,'777123456');
assert.equal(labelled.meta.fee,500);
assert.equal(labelled.notes,'بَدون   شطّة | استلام  مسائي');
for(const input of ['رسوم التوصيل:', 'العميل:', 'الموصل:', 'عنوان:', 'رقم الهاتف:']){
  const empty=parseQuick('١ تشكن\n'+input,{allowPartial:true});
  assert.equal(empty.errors.length,1,input);
  assert.equal(empty.errors[0].line,2,input);
  assert.equal(Object.keys(empty.meta).length,0,input);
}
assert.equal(parseQuick('١ تشكن\nرسوم التوصيل: ٠').meta.fee,0);
assert.equal(parseQuick('١ تشكن\nملاحظة:').notes,'');
assert.equal(parseQuick('١ تشكن\nرسوم التوصيل - ٥٠٠').meta.fee,500);
for(const fee of ['-٥٠٠', ': -٥٠٠', ': ،', ': 0x10']){
  const invalid=parseQuick('١ تشكن\nرسوم التوصيل '+fee,{allowPartial:true});
  assert.equal(invalid.errors[0].line,2);
  assert.equal(invalid.meta.fee,undefined);
}
const customParse=vm.runInNewContext(parserSource+'\nff49ParseItemsAndNotes',{
 ff49Catalog:[{id:1,name:'تشكن فرايز',price:2000,parser_aliases:['وجبة الدجاج']},
 {id:2,name:'عرض الأسرة',price:3000,parser_aliases:['عائلي']}]});
assert.equal(customParse('1 وجبة الدجاج بدون شطّة').items[0].item_notes,'بدون شطّة');
assert.equal(customParse('2 عائلي').items[0].name,'عرض الأسرة');
assert.throws(()=>customParse('1 تشكن'));


// Operational follow-ups: syntax, shared parser and security regression guards.
for(const file of [
 'scripts/luxe-burger-kitchen-20261123.js',
 'scripts/luxe-case-alerts-20261123.js',
 'scripts/luxe-unified-order-inputs-20261123.js',
 'scripts/luxe-order-customer-edit-20261123.js',
 'scripts/luxe-one-time-rewards-20261123.js',
 'scripts/luxe-completed-detail-popup-20261123.js'
]){
 const src=get(file).toString('utf8');
 new vm.Script(src,{filename:file});
 assert.ok(html.includes(file),'Missing deferred script '+file);
}
const burgerNotes=get('scripts/luxe-burger-kitchen-20261123.js').toString('utf8');
assert.match(burgerNotes,/ffBurgerViewFinished/, 'Kitchen finished orders button missing');
assert.match(burgerNotes,/ff_burger_confirm_notes/, 'Kitchen must confirm special notes');
assert.match(burgerNotes,/ff_burger_online_status/, 'Cashier cannot see kitchen presence');
assert.match(burgerNotes,/Never wait for network to sign out/, 'Kitchen logout must never wait for network');
const burgerPatch=get('supabase/migrations/20261123_burger_notes_presence.sql').toString('utf8');
assert.match(burgerPatch,/ff_burger_ready_notes_guard/,'Mandatory kitchen notes guard missing');
const complaintPatch=get('supabase/migrations/20261123_order_case_notifications.sql').toString('utf8');
assert.match(complaintPatch,/ff_case_order_push/,'Complaint push missing');
assert.match(complaintPatch,/ff_case_alert_receipts/,'Complaint read receipts missing');
const customerPatch=get('supabase/migrations/20261123_customer_live_correction.sql').toString('utf8');
assert.match(customerPatch,/customer_contact_corrected/, 'Customer contact audit missing');
assert.match(customerPatch,/ff_order_customer_read/, 'Secure customer order prefill missing');
assert.match(html,/data-ff-customer-edit/, 'Customer edit buttons missing');
assert.match(html,/o\.customer_update/, 'Driver inline customer-change warning missing');
const reservationPatch=get('supabase/migrations/20261123_reservations_unscheduled.sql').toString('utf8');
assert.match(reservationPatch,/pickup_unspecified/, 'Unscheduled reservation indicator missing');
assert.doesNotMatch(html,/id="ff49ReserveWhen"/,'Pickup appointment must be removed');
assert.match(html,/id="ffx-hero-reserve"/,'Reservation next to new order missing');
assert.match(html,/id="ffReserveBottom"/,'Lower reservation button missing');
const voucherPatch=get('supabase/migrations/20261123_one_time_customer_rewards.sql').toString('utf8');
assert.match(voucherPatch,/FOR UPDATE/,'Voucher must lock row for single use');
assert.match(voucherPatch,/redeem_token/,'Voucher idempotency token missing');
assert.match(voucherPatch,/ff_reward_issue/,'Manager issue function missing');
assert.match(voucherPatch,/ff_reward_redeem/,'Voucher redemption function missing');
assert.match(get('scripts/luxe-unified-order-inputs-20261123.js').toString('utf8'),/ff49ParseItemsAndNotes/, 'Approved FF75 parser must be shared');


// A02: real parser + shared picker quantity logic, with no database mutations.
const unifiedSource=get('scripts/luxe-unified-order-inputs-20261123.js').toString('utf8');
const pickerSource=unifiedSource.slice(unifiedSource.indexOf('function itemRows('),unifiedSource.indexOf('window.ffLuxeOrderText='));
const a02Picker=vm.runInNewContext(parserSource+'\n'+pickerSource+'\n({itemRows,appendText,undo,canUndo,clearUndo})',{
 ff49Catalog:menuNames.map((name,id)=>({id:id+1,name,price:1000})),
 Event:class {constructor(type){this.type=type}}
});
let a02Events=0;
const a02Area={isConnected:true,value:'٣ برجر اسمر دبل بدون شطة | 1000\n1 تشكن\nملاحظة: لا تتصل',
 dispatchEvent(event){assert.ok(['input','ff-cart-edit'].includes(event.type));if(event.type==='input')a02Events++}};
const a02Burger=menuNames[3];
assert.equal(a02Picker.itemRows(a02Area)[0].qty,3);
for(const [delta,expected] of [[-1,2],[-1,1],[1,2],[1,3]]){
 a02Picker.appendText(a02Area,a02Burger,delta);
 const parsed=parseQuick(a02Area.value);
 assert.equal(parsed.items[0].qty,expected);
 assert.equal(parsed.items[0].item_notes,'بدون شطة');
 assert.equal(parsed.items[0].price,1000);
 assert.equal(parsed.notes,'لا تتصل');
 assert.equal(parsed.items[1].qty,1);
}
for(let i=0;i<3;i++)a02Picker.appendText(a02Area,a02Burger,-1);
assert.equal(a02Area.value,'1 تشكن\nملاحظة: لا تتصل');
assert.equal(a02Events,7);
a02Area.value='98 تشكن\n1 تشكن فرايز بدون شطة';
a02Picker.appendText(a02Area,menuNames[0],1);
assert.equal(a02Area.value,'98 تشكن\n1 تشكن فرايز بدون شطة');
assert.equal(a02Picker.itemRows(a02Area).reduce((sum,row)=>sum+row.qty,0),99);
a02Picker.appendText(a02Area,menuNames[0],-1);
assert.equal(a02Area.value,'98 تشكن');
console.log('PASS A02: shared picker, aliases, notes, price, decrement/restore, removal and quantity cap');

// Main order cart and popup share the same text editor. No separate cart serializer.
assert.ok(html.includes("editor.appendText($('newItems'),item,by,line)"));
assert.ok(html.includes("editor?.itemRows(area)"));
assert.ok(html.includes("sum+=qty*line.price"));
assert.ok(html.includes("clearUndo($('newItems'))"));
assert.ok(html.includes("ffbUndoCart"));
assert.ok(html.includes("i.item_notes||i.notes"));
assert.doesNotMatch(html,/function syncCart\(\)\{const rows=\[\]/);
const a02Raw='١ تشكن بدون شطة | 900\n1 تشكن فرايز | 1000\nملاحظة: اتصل';
a02Area.value=a02Raw;
a02Picker.appendText(a02Area,{name:menuNames[0],price:1000},1,0);
assert.equal(a02Area.value,'2 تشكن بدون شطة | 900\n1 تشكن فرايز | 1000\nملاحظة: اتصل');
assert.ok(a02Picker.canUndo(a02Area));assert.ok(a02Picker.undo(a02Area));assert.equal(a02Area.value,a02Raw);
a02Picker.appendText(a02Area,{name:menuNames[0],price:1000},1);
assert.equal(a02Area.value,'١ تشكن بدون شطة | 900\n2 تشكن فرايز | 1000\nملاحظة: اتصل');
a02Area.value='1 تشكن بدون شطة | 900';
a02Picker.appendText(a02Area,{name:menuNames[0],price:1000},1);
assert.equal(a02Area.value,'1 تشكن بدون شطة | 900\n1 تشكن فرايز');
a02Area.value+='\nملاحظة: جديدة';assert.equal(a02Picker.canUndo(a02Area),false);
assert.throws(()=>a02Picker.appendText(a02Area,{name:menuNames[0],price:1000},1,99));
a02Area.value='1 صنف مجهول';assert.throws(()=>a02Picker.appendText(a02Area,{name:menuNames[0],price:1000},1));
const exactParser=vm.runInNewContext(parserSource+'\nff49ParseItemsAndNotes',{ff49Catalog:[{id:1,name:menuNames[0],price:1000,parser_aliases:[menuNames[0]]},{id:2,name:'عرض الأسرة',price:2000,parser_aliases:[menuNames[0]]}]});
assert.equal(exactParser('1 تشكن فرايز').items[0].name,menuNames[0]);
console.log('PASS A02: exact names, line-specific prices and notes, reversible edits, ambiguous draft guard');


 // A03: exercise the production CS offer-list renderer and tick, including a replacement offer.
 const a03Clock=Date.parse('2026-11-25T00:00:00Z');
 let a03Now=a03Clock;
 const a03Root={innerHTML:''};
 const a03Node={dataset:{exp:'2026-11-25T00:03:00Z'},textContent:'',hasAttribute:k=>k==='data-ff-cs-offer-id'};
 const a03Data={role:'customer_service',offers:[{id:'old',order_number:1,driver_id:'d1',driver_phone:'000000001',area:'QA',status:'offered',expires_at:a03Node.dataset.exp}]};
 const a03Context=vm.createContext({data:a03Data,$:()=>a03Root,esc:v=>String(v??''),driverName:id=>id==='d1'?'الموصل الأول':'الموصل الثاني',time:v=>v,
 Date:class extends Date{static now(){return a03Now;}},document:{querySelectorAll:s=>s==='[data-exp]'?[a03Node]:[]}});
 vm.runInContext(html.slice(html.indexOf('function ffOfferSecondsLeft'),html.indexOf('function drawDriver()')),a03Context);
 const a03Line=html.slice(html.indexOf('function drawOffers()'),html.indexOf('function drawOffers()')+2500);
 const a03Render=a03Line.slice(0,a03Line.indexOf('\n}',1)+2);
 vm.runInContext(a03Render,a03Context);
 const a03Tick=html.match(/function tick\(\)\{[^\n]+/)[0];
 vm.runInContext(a03Tick,a03Context);
 vm.runInContext('drawOffers();tick()',a03Context);
 assert.match(a03Root.innerHTML,/الموصل الأول/);
 assert.match(a03Root.innerHTML,/data-ff-offer-courier-contact[\s\S]*?000000001/);
 a03Data.role='driver';vm.runInContext('drawOffers()',a03Context);assert.doesNotMatch(a03Root.innerHTML,/000000001|data-ff-offer-courier-contact/);
 a03Data.role='customer_service';vm.runInContext('drawOffers()',a03Context);
 assert.match(a03Root.innerHTML,/data-ff-cs-offer-id="old">180 ثانية/);
 assert.equal(a03Node.textContent,'180 ثانية');
 a03Now=a03Clock+179000;vm.runInContext('tick()',a03Context);assert.equal(a03Node.textContent,'1 ثانية');
 a03Now=a03Clock+180000;vm.runInContext('tick()',a03Context);assert.equal(a03Node.textContent,'انتهت المهلة');
 a03Data.offers=[{id:'replacement',order_number:1,driver_id:'d2',area:'QA',status:'offered',expires_at:'2026-11-25T00:13:00Z'}];
 a03Node.dataset.exp=a03Data.offers[0].expires_at;
 vm.runInContext('drawOffers();tick()',a03Context);
 assert.match(a03Root.innerHTML,/الموصل الثاني/);assert.match(a03Root.innerHTML,/رقم الموصل غير مسجل/);assert.doesNotMatch(a03Root.innerHTML,/000000001/);assert.match(a03Root.innerHTML,/data-ff-cs-offer-id="replacement">600 ثانية/);
 assert.equal(a03Node.textContent,'600 ثانية');
 a03Data.offers[0].status='accepted';vm.runInContext('drawOffers()',a03Context);assert.doesNotMatch(a03Root.innerHTML,/data-exp=/);
 a03Data.offers=[];vm.runInContext('drawOffers()',a03Context);assert.doesNotMatch(a03Root.innerHTML,/data-exp=/);
 console.log('PASS A03: production CS countdown, expiry, new offer and acceptance removal');


 // A04: exercise actual priority and overdue selectors, including closed and finished states.
 const a04Now=Date.parse('2026-11-25T12:00:00Z');
 const a04Date=mins=>new Date(a04Now-mins*60000).toISOString();
 const a04Assembly=vm.runInNewContext(html.slice(html.indexOf('function ffV12Age('),html.indexOf('function ffV12Render()'))+'\nffV12SelectOrders');
 const a04Orders=[{id:'new',cashier_stage:'printed',created_at:a04Date(2)},{id:'old',cashier_stage:'preparing',created_at:a04Date(45)},{id:'ready',cashier_stage:'ready',created_at:a04Date(4)},{id:'warning',cashier_stage:'preparing',created_at:a04Date(25)}];
 const a04Ids=x=>Array.from(x,o=>o.id).join(',');
 assert.equal(a04Ids(a04Assembly(a04Orders,'all',a04Now)),'old,warning,ready,new');
 assert.equal(a04Ids(a04Assembly(a04Orders,'late',a04Now)),'old');
 assert.equal(a04Ids(a04Assembly(a04Orders,'priority',a04Now)),'old,warning,ready');
 assert.equal(a04Ids(a04Assembly(a04Orders,'printed',a04Now)),'new');
 assert.match(html,/ffV12SetOpened\(false\);/);
 assert.match(html,/!ffV12AssemblyActive\|\|!ffV12AssemblyOpened\|\|ffV12AssemblyLoading/);
 assert.match(html,/product\.item_notes/);
 const a04Burger=vm.runInNewContext(burgerScript.slice(burgerScript.indexOf('function burgerIsLate('),burgerScript.indexOf("kitchen.querySelectorAll('[data-ff-burger-filter]')"))+'\nburgerFilterTickets');
 const a04Tickets=[{id:'new',status:'sent',sent_at:a04Date(3)},{id:'prep',status:'preparing',sent_at:a04Date(30)},{id:'done',status:'ready',sent_at:a04Date(90)},{id:'ack',status:'acknowledged',sent_at:a04Date(80)}];
 assert.equal(a04Ids(a04Burger(a04Tickets,'all',a04Now)),'prep,new');
 assert.equal(a04Ids(a04Burger(a04Tickets,'sent',a04Now)),'new');
 assert.equal(a04Ids(a04Burger(a04Tickets,'preparing',a04Now)),'prep');
 assert.equal(a04Ids(a04Burger(a04Tickets,'late',a04Now)),'prep');
 assert.match(burgerScript,/ffBurgerPendingCount/);
 assert.match(burgerScript,/const scoped=await rpc\('ff_burger_my_branch'\)/);
 console.log('PASS A04: optional assembly, live priority and delay filters, burger queue separation and scoped refresh');
