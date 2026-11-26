// Execute the actual client functions, with deferred RPC/auth responses.
// No production Auth, network, tokens, or data. Node's built-in test/VM only.
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync('index.html','utf8');
function extract(a,b){const x=source.indexOf(a),y=source.indexOf(b,x+a.length);assert(x>=0&&y>x,'missing source marker '+a);return source.slice(x,y);}
const reloadSource=extract('async function reload(force=false)','function ding()');
const roleSource=extract('async function ff28ReadRole(','async function setSession(');
const logoutSource=extract("$('logoutBtn').onclick=","$('refreshBtn').onclick=");
const defer=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b});return {promise,resolve,reject}};
const tick=()=>new Promise(r=>setImmediate(r));
function harness(){
 const elements=new Map(),events=[],calls=[],toasts=[];
 const $=id=>{if(!elements.has(id))elements.set(id,{disabled:false,textContent:'',classList:{add(){},remove(){}}});return elements.get(id)};
 const c=vm.createContext({console,Date,Event:class{constructor(t){this.type=t}},window:{dispatchEvent:e=>events.push(e.type)},$,data:{role:'cashier'},user:{id:'A'},ff28Epoch:1,ffV12AssemblyActive:false,client:{auth:{signOut:async()=>({error:null})}},inFlight:false,ffSnapshotRetryAfter:0,ffSnapshotConsecutiveFailures:0,selfPermissionsNextTry:0,selfPermissions:null,selfPermissionsFetchedAt:0,rejectPermissionsNextTry:0,rejectPermissions:{},rejectPermissionReady:false,additionReady:false,additionData:[],lastAdditionKey:'',fetchCount:0,ff39LastSync:Date.now(),draw(){events.push('draw')},conn(){events.push('conn')},ding(){events.push('ding')},notify(){events.push('notify')},ff39RefreshInbox(){events.push('inbox')},time:()=>'',toast:s=>toasts.push(s),rpc:async(name)=>{calls.push(name);if(name==='ff49_snapshot')return {role:c.data.role};if(name==='ff38_my_permissions')return {view_reports:true};if(name==='ff52_list_additions'||name==='ff38_get_reject_permissions')return [];throw Error(name)},resetUI(){events.push('reset');c.ff28Epoch++;c.user=null;c.data=null;c.inFlight=false;c.selfPermissions=null;c.additionData=[];}});
 vm.runInContext(reloadSource+'\n'+roleSource+'\n'+logoutSource,c);
 return {c,events,calls,toasts,$};
}
function switchAccount(h,id='B'){const c=h.c;c.ff28Epoch++;c.user={id};c.data={role:'cashier',marker:'new'};c.inFlight=true;c.selfPermissions={newOnly:true};c.additionData=[{id:'new'}];c.rejectPermissions={newOnly:true};h.events.length=0;}
const submitSource=extract('const ff27Pending=new Map();',"\n\n(()=>{\n const csv=document.getElementById('ff40ExportCSV');");
function submitHarness(){
 const h=harness(),store=new Map(),sent=[];let serial=0;
 h.c.TextEncoder=TextEncoder;
 h.c.crypto={subtle:{digest:async()=>new Uint8Array([1,2,3]).buffer},randomUUID:()=>('request-'+(++serial))};
 h.c.sessionStorage={getItem:k=>store.get(k)??null,setItem:(k,v)=>store.set(k,v),removeItem:k=>store.delete(k)};
 h.c.rpc=async(n,args)=>{sent.push({n,args,actor:h.c.user?.id});return {order_number:123};};
 vm.runInContext(submitSource,h.c);
 return {...h,store,sent};
}
async function submitChecks(){
 let n=0;
 // Account changes while asynchronous hashing is in flight: no RPC or retry state.
 {const h=submitHarness(),d=defer();h.c.crypto.subtle.digest=()=>d.promise;const p=h.c.ff27Submit('delivery',{name:'old draft'});switchAccount(h);d.resolve(new Uint8Array([1]).buffer);await assert.rejects(p,/تغيرت جلسة/);assert.equal(h.sent.length,0);assert.equal(h.store.size,0);n++;}
 // Same account signs in again; generation change still blocks old draft.
 {const h=submitHarness(),d=defer();h.c.crypto.subtle.digest=()=>d.promise;const p=h.c.ff27Submit('reservation',{name:'old draft'});switchAccount(h,'A');d.resolve(new Uint8Array([1]).buffer);await assert.rejects(p,/تغيرت جلسة/);assert.equal(h.sent.length,0);n++;}
 // Identical concurrent submissions in one session share one request; another payload is refused.
 {const h=submitHarness(),d=defer();h.c.crypto.subtle.digest=()=>d.promise;const p=h.c.ff27Submit('delivery',{name:'one'});const p2=h.c.ff27Submit('delivery',{name:'one'});assert.equal(p,p2);await assert.rejects(h.c.ff27Submit('delivery',{name:'different'}),/انتظر/);d.resolve(new Uint8Array([1]).buffer);await p;assert.equal(h.sent.length,1);assert.equal(h.store.size,0);n++;}
 // Payload remains the captured draft even if the caller mutates its input during hashing.
 {const h=submitHarness(),d=defer(),input={name:'captured'};h.c.crypto.subtle.digest=()=>d.promise;const p=h.c.ff27Submit('delivery',input);input.name='changed';d.resolve(new Uint8Array([1]).buffer);await p;assert.equal(h.sent[0].args.p_input.name,'captured');n++;}
 // Network failure preserves the same retry token; success removes it.
 {const h=submitHarness();let first;h.c.rpc=async(n,args)=>{first=args.p_request;throw Error('offline')};await assert.rejects(h.c.ff27Submit('delivery',{name:'retry'}),/offline/);assert.equal(h.store.size,1);h.c.rpc=async(n,args)=>{assert.equal(args.p_request,first);return {order_number:321}};await h.c.ff27Submit('delivery',{name:'retry'});assert.equal(h.store.size,0);n++;}
 // Old response cannot display success or delete a retry token after a new generation.
 {const h=submitHarness(),d=defer();h.c.rpc=()=>d.promise;const old=h.c.ff27Submit('delivery',{name:'old'});await tick();switchAccount(h,'A');const stored=JSON.stringify({digest:'new',request:'new-request'});h.store.set('ff27-request-A-delivery',stored);d.resolve({order_number:999});await assert.rejects(old,/تغيرت جلسة/);assert.equal(h.store.get('ff27-request-A-delivery'),stored);n++;}
 assert.equal(n,6);console.log('PASS STEP12 order submit generation: '+n+' cases; stale drafts blocked, retry idempotency retained');
}
async function main(){
 let count=0;
 // Successful normal refresh, followed by a stale permissions response.
 {const h=harness();await h.c.reload(true);assert(h.events.includes('draw'));assert.equal(h.c.inFlight,false);count++;}
 {const h=harness(),d=defer();h.c.rpc=async n=>{h.calls.push(n);return n==='ff49_snapshot'?{role:'cashier'}:n==='ff38_my_permissions'?d.promise:[]};const p=h.c.reload(true);await tick();switchAccount(h);d.resolve({oldOnly:true});await p;assert.equal(h.c.selfPermissions.newOnly,true);assert.equal(h.c.additionData[0].id,'new');assert.equal(h.c.inFlight,true);assert(!h.calls.includes('ff52_list_additions'));assert(!h.events.includes('draw'));count++;}
 // Same user, different session epoch: stale additions must not repopulate caches.
 {const h=harness(),d=defer();h.c.rpc=async n=>n==='ff49_snapshot'?{role:'cashier'}:n==='ff38_my_permissions'?{}:d.promise;const p=h.c.reload(true);await tick();switchAccount(h,'A');d.resolve([{id:'old',status:'pending'}]);await p;assert.equal(h.c.additionData[0].id,'new');assert.equal(h.c.inFlight,true);assert(!h.events.includes('draw'));count++;}
 // A late failing RPC from old session must not reset or alter the new session.
 {const h=harness(),d=defer();h.c.rpc=async n=>n==='ff49_snapshot'?d.promise:[];const p=h.c.reload(true);switchAccount(h);d.reject(Object.assign(Error('old denied'),{code:'42501'}));await p;assert.equal(h.c.user.id,'B');assert.equal(h.c.inFlight,true);assert(!h.events.includes('reset'));count++;}
 // PostgREST session invalidation from snapshot and a nested permission call.
 for(const at of ['ff49_snapshot','ff38_my_permissions']){const h=harness();h.c.rpc=async n=>{if(n===at)throw Object.assign(Error('session invalid'),{code:'PT401'});return {role:'cashier'}};await h.c.reload(true);assert(h.events.includes('reset'));assert.equal(h.c.user,null);count++;}
 // Role resolution is request-local and abandons stale fallback.
 {const h=harness();h.c.rpc=async()=>({role:'manager',marker:'onlyA'});const x=await h.c.ff28ReadRole(1);assert.equal(x.role,'manager');assert.equal(x.snapshot.marker,'onlyA');count++;}
 {const h=harness(),d=defer();h.c.rpc=async n=>{h.calls.push(n);return d.promise};const p=h.c.ff28ReadRole(1);switchAccount(h);d.reject(Error('stale'));assert.equal(await p,null);assert.equal(h.calls.length,1);count++;}
 {const h=harness();h.c.rpc=async n=>{if(n==='ff49_snapshot')throw Object.assign(Error('session invalid'),{code:'PT401'});throw Error('must not fall back')};await assert.rejects(h.c.ff28ReadRole(1),/session invalid/);count++;}
 // Logout must handle the returned Supabase error, retain driver clock-out protection,
 // and never reset another session after an awaited operation.
 {const h=harness();h.c.client.auth.signOut=async()=>({error:Error('offline')});await h.$('logoutBtn').onclick();assert(!h.events.includes('reset'));assert(h.toasts[0].includes('لم يتم تأكيد'));assert.equal(h.$('logoutBtn').disabled,false);count++;}
 {const h=harness();let scope;h.c.client.auth.signOut=async x=>{scope=x.scope;return {error:null}};await h.$('logoutBtn').onclick();assert.equal(scope,'local');assert(h.events.includes('reset'));count++;}
 {const h=harness();h.c.data.role='driver';h.c.rpc=async()=>{throw Error('pending assignment')};let calls=0;h.c.client.auth.signOut=async()=>{calls++;return {error:null}};await h.$('logoutBtn').onclick();assert.equal(calls,0);assert(!h.events.includes('reset'));count++;}
 {const h=harness(),d=defer();h.c.data.role='driver';h.c.rpc=async()=>d.promise;let calls=0;h.c.client.auth.signOut=async()=>{calls++;return {error:null}};const p=h.$('logoutBtn').onclick();switchAccount(h);d.resolve({ok:true});await p;assert.equal(calls,0);assert(!h.events.includes('reset'));count++;}
 {const h=harness(),d=defer();h.c.client.auth.signOut=async()=>d.promise;const p=h.$('logoutBtn').onclick();switchAccount(h);d.resolve({error:null});await p;assert.equal(h.c.user.id,'B');assert(!h.events.includes('reset'));count++;}
 assert.equal(count,14);console.log('PASS STEP12 client session generation: '+count+' cases; deferred RPC isolation, revoked session, role fallback, logout');
}
main().then(submitChecks).catch(e=>{console.error(e);process.exitCode=1});
