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

assert.match(html, /#cashierOrders>\.item:not\(\.ff-luxe-cancelled\)/, 'Ordinary cashier cards must exclude cancelled orders');
assert.match(html, /#driverTasks>\.item:not\(\.ff-luxe-cancelled\)/, 'Ordinary driver cards must exclude cancelled orders');
assert.doesNotMatch(html, /\.ff60-order,\s*\.ff-luxe-cancelled,/, 'Generic blue cards must not override cancelled orders');
assert.match(html, /#cashierOrders>\.ff-luxe-cancelled\{[^}]*#b91c1c/, 'Cashier cancellation outline must be red');

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
assert.match(get(operationalFiles[0]).toString('utf8'), /ff_luxe_reset_safe/, 'Protected selective reset missing');
assert.match(html, /ff_luxe_driver_rate_order/, 'Courier feedback missing');
assert.match(html, /ff_luxe_driver_grievance/, 'Courier grievance form missing');
assert.match(get(operationalFiles[1]).toString('utf8'), /ff_luxe_manager_driver_progress/,
  'Manager driver-phase action missing');
assert.match(get(operationalFiles[0]).toString('utf8'), /ff_luxe_reset_preview/,
  'Pre-reset data preview missing');
const resetBlock=html.match(/<script id="ff-luxe-reset-ui-20261121">([\s\S]*?)<\/script>/)?.[1];
assert.ok(resetBlock, 'Manager reset panel creation missing');
assert.match(resetBlock, /run\.disabled=true/, 'Reset must be disabled until safe controller loads');
assert.doesNotMatch(resetBlock, /run\.onclick\s*=/, 'Legacy direct reset action must not be wired');
assert.doesNotMatch(html, /rpc\(['"]ff_luxe_reset_scoped/, 'Privileged internal reset function must never be invoked by browser');
const guardedReset=get(operationalFiles[0]).toString('utf8');
assert.match(guardedReset, /rpc\(['"]ff_luxe_reset_safe/, 'Guarded reset entry point missing');
assert.match(guardedReset, /ff_luxe_reset_preview/, 'Preview must be available before the reset');
assert.match(guardedReset, /if\(!backupCheck\.checked\)/, 'Backup confirmation required');
assert.match(guardedReset, /run\.dataset\.ffResetMode='guarded'/, 'Safe controller must enable reset only after wiring');

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
