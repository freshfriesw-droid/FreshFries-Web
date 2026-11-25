// STEP11: execute the actual service worker with deterministic browser API boundaries.
const {readFileSync}=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const handlers={}, notifications=[], posted=[], opened=[], deleted=[], cached=[], fetched=[];
let offline=false, focused=0, windows=[];
const scope='https://freshfriesz.com/';
const self={location:{origin:'https://freshfriesz.com'},registration:{scope,showNotification:async(title,options)=>notifications.push({title,options})},
 clients:{claim:async()=>{},matchAll:async()=>windows,openWindow:async url=>opened.push(url)},
 skipWaiting:async()=>{},addEventListener:(name,fn)=>handlers[name]=fn};
const caches={open:async()=>({addAll:async a=>cached.push(...a)}),keys:async()=>['ff-luxe-static-old','other-app-cache'],delete:async k=>deleted.push(k),match:async req=>req==='./offline.html'?'offline-page':null};
const fetch=async(req,options)=>{fetched.push({req,options});if(offline)throw Error('offline');return 'network'};
vm.runInNewContext(readFileSync('sw.js','utf8'),{self,caches,fetch,URL,Set,Promise});
async function wait(name,event={}){let done;handlers[name]({...event,waitUntil:p=>done=p});await done}
async function response(req){let p;handlers.fetch({request:req,respondWith:r=>p=r});return p?await p:undefined}
(async()=>{
 await wait('install');await wait('activate');
 assert.equal(cached.length,4);
 assert.ok(cached.every(p=>p.includes('offline.html')||p.includes('manifest')||p.includes('ff-icon-')));
 assert.deepEqual(deleted,['ff-luxe-static-old']);
 const nav={method:'GET',mode:'navigate',url:scope+'index.html'};
 assert.equal(await response(nav),'network');assert.equal(fetched.at(-1).options.cache,'no-store');
 offline=true;assert.equal(await response(nav),'offline-page');offline=false;
 assert.equal(await response({method:'GET',mode:'cors',url:'https://example.supabase.co/rest/v1/ff_orders'}),undefined);
 assert.equal(await response({method:'GET',mode:'cors',url:scope+'index.html'}),undefined);
 assert.equal(await response({method:'POST',mode:'cors',url:scope+'index.html'}),undefined);
 windows=[{url:scope+'index.html',visibilityState:'hidden',postMessage:m=>posted.push(m),focus:async()=>focused++}];
 await wait('push',{data:{json:()=>({kind:'message',title:'PRIVATE',body:'PRIVATE',tag:'valid-tag',path:'https://evil.example'})}});
 assert.equal(notifications[0].title,'✉️ رسالة داخلية جديدة');
 assert.ok(!JSON.stringify(notifications[0]).includes('PRIVATE'));
 assert.equal(notifications[0].options.data.path,scope+'index.html');
 assert.equal(posted[0].type,'FF_LUXE_PUSH_RECEIVED');
 await wait('notificationclick',{notification:{close(){},data:{kind:'message'}}});
 assert.equal(focused,1);
 assert.ok(!posted.some(x=>x.type==='FF_LUXE_NOTIFICATION_OPENED'));
 await wait('notificationclick',{notification:{close(){},data:{kind:'offer'}}});
 assert.equal(focused,2);assert.ok(posted.some(x=>x.type==='FF_LUXE_NOTIFICATION_OPENED'));
 windows=[];
 await wait('notificationclick',{notification:{close(){},data:{kind:'message'}}});
 assert.equal(opened.at(-1),scope+'index.html');
 await wait('notificationclick',{notification:{close(){},data:{kind:'offer'}}});
 assert.equal(opened.at(-1),scope+'index.html?ff_push_opened=1');
 await wait('push',{data:{json(){throw Error('bad payload')}}});
 assert.equal(notifications.at(-1).options.data.kind,'general');
 console.log('PASS STEP11 SW lifecycle, cache isolation, offline shell, generic message privacy, safe click and order-ring separation');
})().catch(e=>{console.error(e);process.exitCode=1});
