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
assert.match(html, /ff28_customer/, 'Customer records must be server-filtered');
assert.doesNotMatch(html, /sb_secret_[A-Za-z0-9]+/, 'Secret API key must never be embedded in the client');

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
const resetBlock=html.match(/<script id="ff-luxe-reset-ui-20261121">([\\s\\S]*?)<\\/script>/)?.[1];
assert.ok(resetBlock, 'Manager reset panel creation missing');
assert.match(resetBlock, /run\\.disabled=true/, 'Reset must be disabled until safe controller loads');
assert.doesNotMatch(resetBlock, /run\\.onclick\\s*=/, 'Legacy direct reset action must not be wired');
assert.doesNotMatch(html, /rpc\\(['"]ff_luxe_reset_scoped/, 'Privileged internal reset function must never be invoked by browser');
const guardedReset=get(operationalFiles[0]).toString('utf8');
assert.match(guardedReset, /rpc\\(['"]ff_luxe_reset_safe/, 'Guarded reset entry point missing');
assert.match(guardedReset, /ff_luxe_reset_preview/, 'Preview must be available before the reset');
assert.match(guardedReset, /if\\(!backupCheck\\.checked\\)/, 'Backup confirmation required');
assert.match(guardedReset, /run\\.dataset\\.ffResetMode='guarded'/, 'Safe controller must enable reset only after wiring');


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