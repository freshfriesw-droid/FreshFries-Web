// Exercise the actual Edge handler offline; Auth/DB adapters are mocks, no production network.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {stripTypeScriptTypes} from 'node:module';
import {webcrypto} from 'node:crypto';
const source=fs.readFileSync('supabase/functions/ff61-employees/index.ts','utf8').replace(/^import .*;\s*$/gm,'');
const actor='11111111-1111-4111-8111-111111111111',app='22222222-2222-4222-8222-222222222222',newUser='33333333-3333-4333-8333-333333333333',branch='44444444-4444-4444-8444-444444444444';
const origin='https://delivery.freshfriesz.com';
let handler,mode='ok',cap=true,created=0,deleted=0,inserts=[],calls=[];
const mock={
 auth:{getUser:async token=>({data:{user:token==='qa-valid-token-abcdefghijklmnopqrstuvwxyz'?{id:actor}:null}}),
 admin:{createUser:async x=>{created++;return {data:{user:{id:newUser}}}},deleteUser:async()=>{deleted++;return {error:null}}}},
 rpc:async(name,args)=>{calls.push({name,args});if(name==='ff62_claim_public_request')return {data:true};if(name==='ff61_can_act')return {data:cap};if(name==='ff_a05_approve_application')return mode==='ok'?{data:{approved:true,desk:args.p_desk}}:{error:{message:'QA uncertainty'}};if(name==='ff61_reject_application')return {data:{rejected:true}};throw Error('Unexpected RPC '+name)},
 from:table=>{assert.equal(table,'ff61_employee_applications');return {
 insert:async row=>{inserts.push(row);return {error:null}},
 select:()=>({eq:()=>({single:async()=>({data:{id:app,email:null,phone:'+967700000001',full_name:'QA Applicant',status:'pending'}}),
 maybeSingle:async()=>mode==='unknown'?{error:{message:'QA offline'},data:null}:mode==='committed'?{data:{status:'approved',approved_user_id:newUser}}:{data:{status:'pending',approved_user_id:null}}})})
 }}
};
const sandbox={serve:fn=>{handler=fn},createClient:()=>mock,Deno:{env:{get:()=>''}},TextEncoder,crypto:webcrypto,URLSearchParams,Request,Response,AbortSignal,console,fetch:async()=>{throw Error('Unexpected network')}};
vm.runInNewContext(stripTypeScriptTypes(source,{mode:'strip'}),sandbox,{filename:'actual-edge-handler.js'});
async function send(body,authenticated=false,where=origin){
 const headers={'origin':where,'content-type':'application/json'};if(authenticated)headers.authorization='Bearer qa-valid-token-abcdefghijklmnopqrstuvwxyz';
 const res=await handler(new Request('https://example.invalid',{method:'POST',headers,body:JSON.stringify(body)}));return {status:res.status,data:await res.json()};
}
const application={full_name:'أحمد محمد',phone:'700000001',qualification:'QA',address:'QA address',age_years:25,marital_status:'single',requested_role:'cashier',privacy_agreement:true};
let r=await send({action:'submit',application});assert.equal(r.status,201);assert.match(r.data.application_id,/^[a-f0-9]{64}$/);assert.equal(inserts.length,1);assert.equal(created,0);assert.equal(inserts[0].full_name,'أحمد محمد');assert.notEqual(inserts[0].tracking_token_hash,r.data.application_id);
r=await send({action:'submit',application:{...application,full_name:'أحمد'}});assert.equal(r.status,400);assert.equal(inserts.length,1);
r=await send({action:'submit',application},false,'https://other.invalid');assert.equal(r.status,403);
const approval={action:'approve',application_id:app,role:'cashier',branch_id:branch,desk:'cairo_first',reason:'QA reviewed identity',password:'Qa!23456',phone_ownership_verified:true};
r=await send(approval);assert.equal(r.status,401);
cap=false;r=await send(approval,true);assert.equal(r.status,400);assert.equal(created,0);cap=true;
r=await send({...approval,phone_ownership_verified:false},true);assert.equal(r.status,400);assert.equal(created,0);
r=await send(approval,true);assert.equal(r.status,200);assert.equal(r.data.desk,'cairo_first');assert.equal(created,1);assert.ok(!JSON.stringify(r.data).includes(approval.password));
const call=calls.find(x=>x.name==='ff_a05_approve_application');assert.equal(call.args.p_reason,approval.reason);assert.equal(call.args.p_desk,approval.desk);assert.equal(call.args.p_actor,actor);assert.ok(!JSON.stringify(call.args).includes(approval.password));
mode='unknown';r=await send(approval,true);assert.equal(r.status,409);assert.equal(deleted,0,'ambiguous committed decision must not delete user');
mode='committed';r=await send(approval,true);assert.equal(r.status,200);assert.equal(deleted,0);
mode='failure';r=await send(approval,true);assert.equal(r.status,409);assert.equal(deleted,1);
console.log('PASS A05 edge: 10 scenarios, binary name, no preapproval Auth creation, origin/auth/delegation, atomic desk and reason, safe ambiguous cleanup and no password output');
