// Test the exact production media lifecycle from index.html, without network credentials.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const html=fs.readFileSync('index.html','utf8');
const start=html.indexOf('let ff74Busy=false,ff74'),end=html.indexOf("$x('ff66-tone-refresh').onclick=",start);
assert.ok(start>=0&&end>start);
const production=html.slice(start,end);
const harness=`
let user={id:'A'},data={role:'manager'},prefs={sound:'soft',delaySound:'soft',audio:true,volume:100},client;
const nodes=new Map(),events=new Map(),fallbacks=[],status=[];
function node(){return {children:[],dataset:{},add(o){o.remove=()=>{this.children=this.children.filter(n=>n!==o)};this.children.push(o)},append(...v){this.children.push(...v)},replaceChildren(...v){this.children=v},querySelectorAll(){return this.children.filter(o=>o.dataset?.ff66Tone)},addEventListener(){}}}
const $x=id=>{if(!nodes.has(id))nodes.set(id,node());return nodes.get(id)};
const doc={createElement:node,addEventListener(){}},document={hidden:false};
const window={addEventListener(name,fn){events.set(name,fn)}};
const setInterval=()=>0,showToast=()=>{},storePrefs=()=>{},applyPrefs=()=>{};
function Option(text,value){this.text=text;this.value=value;this.dataset={}}
let rejectPlay=null;
class Audio{constructor(url){this.src=url;this.paused=false}pause(){this.paused=true}removeAttribute(){this.src=''}load(){}play(){return new Promise((_,reject)=>{rejectPlay=reject})}}
function sound(...args){fallbacks.push(args)}function ffLuxeAudioStatus(s){status.push(s)}
const tone=(id)=>({id,name:id,storage_path:'tones/'+id+'.mp3',is_active:true});
const reply=(rows,signed,rpc=async()=>({data:{}}))=>({from:()=>({select:()=>({order:()=>({limit:async()=>({data:rows})})})}),storage:{from:()=>({createSignedUrls:()=>signed})},rpc});
const signedRow=id=>({path:'tones/'+id+'.mp3',signedUrl:'https://example.invalid/'+id});
let tick=()=>Promise.resolve().then(()=>Promise.resolve());
`;
const cases=`
(async()=>{
 const a=tone('a'),b=tone('b'),c=tone('c');
 client=reply([a,b],Promise.resolve({data:[signedRow('b'),signedRow('a'),signedRow('unrelated')]}));
 await ff66Load(true);assert.equal(ff66Urls.get('a'),'https://example.invalid/a');assert.equal(ff66Urls.get('b'),'https://example.invalid/b');assert.equal(ff66Urls.size,2);
 let release,entered;const gated=new Promise(r=>release=r);client=reply([a],gated);const signing=client.storage.from;client.storage.from=()=>({createSignedUrls:()=>{entered=true;return signing().createSignedUrls()}});const old=ff66Load(true);while(!entered)await tick();
 user={id:'B'};data={role:'cashier'};events.get('ff-luxe-session-reset')();
 client=reply([c],Promise.resolve({data:[signedRow('c')]}));await ff66Load(true);release({data:[signedRow('a')]});await old;assert.equal([...ff66Urls.keys()].join(','),'c');assert.equal(ff66User,'B');
 assert.ok(ff66PlayTone('tone:c'));const player=ffLuxeTonePlayers.get('c');const staleReject=rejectPlay;
 user={id:'C'};events.get('ff-luxe-session-reset')();staleReject(Error('old playback'));await tick();assert.equal(fallbacks.length,0);assert.equal(player.src,'');assert.equal(ffLuxeTonePlayers.size,0);
 client=reply([c],Promise.resolve({data:[signedRow('c')]}));await ff66Load(true);
 assert.ok(ff66PlayTone('tone:c'));rejectPlay(Error('current failure'));await tick();assert.equal(fallbacks.length,1);assert.equal(fallbacks[0][0],'soft');
 assert.ok(ff66PlayTone('tone:c'));prefs.audio=false;rejectPlay(Error('muted'));await tick();assert.equal(fallbacks.length,1);prefs.audio=true;
 client=reply([c],Promise.resolve({error:Error('storage unavailable')}));await ff66Load(true);assert.equal(ff66Urls.size,0);assert.equal(ff66PlayTone('tone:c'),false);
 await tick();prefs.sound='tone:not-loaded';ff66ShowChoices();assert.equal(prefs.sound,'tone:not-loaded');assert.equal($x('ffx-sound').value,'tone:not-loaded');
 let finish;client=reply([],Promise.resolve({data:[]}),()=>new Promise(r=>finish=r));const oldConfig=ff74Refresh(true);await tick();
 user={id:'D'};events.get('ff-luxe-session-reset')();prefs={sound:'digital',delaySound:'soft',audio:true,volume:100};finish({data:{new_order:{type:'built_in',key:'urgent'}}});await oldConfig;assert.equal(prefs.sound,'digital');
 data={role:'manager'};let finishSave,writes=0;client=reply([],Promise.resolve({data:[]}),()=>{writes++;return new Promise(r=>finishSave=r)});
 const saving=ff74Change('sound','classic');assert.equal($x('ffx-sound').disabled,true);await ff74Change('delaySound','urgent');assert.equal(writes,1);
 finishSave({data:{new_order:{type:'built_in',key:'classic'},delay:{type:'built_in',key:'soft'}}});await saving;assert.equal(prefs.sound,'classic');assert.equal($x('ffx-sound').disabled,false);
 console.log('PASS STEP05 media: path mapping, account switch, stale playback, mute, failure fallback, central preference and serialized save');
})()
`;
await vm.runInNewContext(harness+production+cases,{assert,console,Date,Promise,Map,Set});
