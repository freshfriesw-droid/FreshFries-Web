import webpush from "npm:web-push@3.6.7";
import { validatedPushEndpoint } from "./push-endpoint.mjs";
import { createClient } from "npm:@supabase/supabase-js@2.95.0";

type Subscription = {endpoint:string;keys:{p256dh:string;auth:string};expirationTime?:number|null};
type Job = {id:number;user_id:string;kind:string;title:string;body:string;event_key:string};
const url = Deno.env.get("SUPABASE_URL") || "";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const anonymousKey = Deno.env.get("SUPABASE_ANON_KEY") || "";
if(!url || !serviceKey)console.error("FF Push: Supabase server credentials are not configured");
const admin = createClient(url,serviceKey,{auth:{autoRefreshToken:false,persistSession:false}});
const allowedOrigins = new Set([
 "https://delivery.freshfriesz.com",
 "https://freshfriesz.com",
 "https://www.freshfriesz.com",
 "https://freshfriesw-droid.github.io"
]);
function headers(req:Request):Record<string,string>{
 const origin=req.headers.get("origin")||"";
 return {
  "Content-Type":"application/json; charset=utf-8",
  "Access-Control-Allow-Origin":allowedOrigins.has(origin)?origin:"null",
  "Access-Control-Allow-Methods":"GET,POST,OPTIONS",
  "Access-Control-Allow-Headers":"authorization,apikey,content-type,x-client-info,x-ff-push-key",
  "Cache-Control":"no-store", "Vary":"Origin",
 };
}
function json(req:Request,value:unknown,status=200):Response{
 return new Response(JSON.stringify(value),{status,headers:headers(req)});
}
let configured=false;
async function configureVapid():Promise<string>{
 const {data,error}=await admin.rpc("ff_push_server_config");
 if(error||!data?.public||!data?.private)throw new Error("VAPID_CONFIG_MISSING");
 if(!configured){
  webpush.setVapidDetails("mailto:freshfriesw@gmail.com",data.public,data.private);
  configured=true;
 }
 return data.public as string;
}
function normalize(s:unknown,max:number):string{
 return String(s??"").slice(0,max);
}
async function sendOne(sub:Subscription,payload:Record<string,unknown>,ttl=300):Promise<void>{
 const endpoint=validatedPushEndpoint(sub?.endpoint);
 if(!endpoint)throw new Error("UNSUPPORTED_PUSH_ENDPOINT");
 if(!sub?.keys?.p256dh||!sub?.keys?.auth)throw new Error("INVALID_SUBSCRIPTION");
 await webpush.sendNotification({...sub,endpoint},JSON.stringify(payload),{TTL:ttl,urgency:"high"});
}
async function authorizedUser(req:Request):Promise<string|null>{
 const token=(req.headers.get("Authorization")||"").replace(/^Bearer\s+/i,"");
 if(!token||token.length>4096||!anonymousKey)return null;
 const sb=createClient(url,anonymousKey,{
  global:{headers:{Authorization:"Bearer "+token}},auth:{autoRefreshToken:false,persistSession:false}
 });
 const {data:{user},error}=await sb.auth.getUser(token);
 if(error||!user)return null;
 const {data:profile}=await admin.from("ff_profiles").select("active,role").eq("user_id",user.id).maybeSingle();
 if(!profile?.active||!["manager","supervisor","customer_service","cashier","driver","assembly","burger_kitchen"].includes(profile.role))return null;
 return user.id;
}
async function dispatchJobs():Promise<{claimed:number,sent:number,retry:number,without_devices:number}>{
 await configureVapid();
 const {data,error}=await admin.rpc("ff_push_claim_jobs",{p_limit:60});
 if(error||!Array.isArray(data))throw new Error("CLAIM_FAILED:"+error?.message);
 const jobs=data as Job[];
 let sent=0,retry=0,without_devices=0;
 // Cap fan-out concurrency so the worker remains stable on small restaurants.
 for(let i=0;i<jobs.length;i+=6){
  await Promise.all(jobs.slice(i,i+6).map(async(job)=>{
   let ok=false,failure="";
   try{
    const {data:profile,error:profileErr}=await admin.from("ff_profiles").select("active").eq("user_id",job.user_id).maybeSingle();
    if(profileErr)throw profileErr;
    if(!profile?.active){failure='INACTIVE_RECIPIENT';without_devices++;return;}
    const {data:devices,error:deviceErr}=await admin.from("ff_push_devices")
       .select("id,subscription").eq("user_id",job.user_id).eq("enabled",true).limit(15);
    if(deviceErr)throw deviceErr;
    if(!devices?.length){failure='NO_ENABLED_DEVICE';without_devices++;return;}
    // Cancellation may occur after the job was claimed; recheck before external delivery.
    if(job.kind==='message'){
      const mid=job.event_key.startsWith('message:')?job.event_key.slice(8):'';
      if(!/^[0-9a-f-]{36}$/i.test(mid)){failure='MESSAGE_CANCELLED';return;}
      const {data:message,error:messageErr}=await admin.from('ff39_messages').select('cancelled_at').eq('id',mid).maybeSingle();
      if(messageErr)throw messageErr;
      if(!message||message.cancelled_at){failure='MESSAGE_CANCELLED';return;}
    }
    const body={
      type:"order-alert",kind:normalize(job.kind,24),
      title:normalize(job.title,90),body:normalize(job.body,180),
      tag:"ff-luxe-push-"+String(job.id),path:"./index.html"
    };
    const results=await Promise.allSettled(devices.map(async(d)=>{
      try{await sendOne(d.subscription as Subscription,body,300);return true;}
      catch(err){
       const code=Number((err as {statusCode?:number})?.statusCode||0);
       if(code===404||code===410||(err as Error)?.message==='UNSUPPORTED_PUSH_ENDPOINT'){
        await admin.from("ff_push_devices").update({enabled:false}).eq("id",d.id).eq("user_id",job.user_id);
       }
       throw err;
      }
    }));
    const successes=results.filter(r=>r.status==="fulfilled").length;
    ok=successes>0;
    failure=ok?"":("DELIVERY_FAILED:"+results.filter(r=>r.status==="rejected").length);
   }catch(err){failure=normalize((err as Error)?.message||err,100)}
   finally{
    try{
     const {error:doneErr}=await admin.rpc("ff_push_finish_job",{
       p_job:job.id,p_success:ok,p_error:ok?'PROVIDER_ACCEPTED':failure
     });
     if(doneErr)console.error("FF push finish error",doneErr.message);
    }catch(e){console.error("FF push acknowledgement error",String(e))}
    if(ok)sent++;else if(!['NO_ENABLED_DEVICE','INACTIVE_RECIPIENT','MESSAGE_CANCELLED'].includes(failure))retry++;
   }
  }));
 }
 return {claimed:jobs.length,sent,retry,without_devices};
}
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response(null,{status:204,headers:headers(req)});
 if(req.method==="GET"){
  try{return json(req,{key:await configureVapid(),ready:true,background:true});}
  catch{return json(req,{ready:false,error:"PUSH_NOT_CONFIGURED"},503);}
 }
 if(req.method!=="POST")return json(req,{error:"METHOD_NOT_ALLOWED"},405);
 let payload:Record<string,unknown>;
 try{payload=await req.json();if(!payload||typeof payload!=="object"||Array.isArray(payload))throw Error("INVALID_JSON");}
 catch{return json(req,{error:"INVALID_BODY"},400);}
 if(payload.action==="dispatch"){
  const token=req.headers.get("X-FF-Push-Key")||"";
  if(token.length!==64)return json(req,{error:"FORBIDDEN"},403);
  const {data:valid,error}=await admin.rpc("ff_push_verify_dispatch",{p_token:token});
  if(error||valid!==true)return json(req,{error:"FORBIDDEN"},403);
  try{return json(req,{ok:true,...await dispatchJobs()});}
  catch(e){console.error("FF Push dispatch error",String(e));return json(req,{error:"DISPATCH_FAILED"},503)}
 }
 // Explicit device test only: valid, active employee session, never other users' devices.
 if(payload.action!==undefined && payload.action!=="test")return json(req,{error:"UNKNOWN_ACTION"},400);
 const uid=await authorizedUser(req);
 if(!uid)return json(req,{error:"AUTH_REQUIRED"},401);
 try{
  await configureVapid();
  const {data:devices,error}=await admin.from("ff_push_devices")
   .select("id,subscription").eq("user_id",uid).eq("enabled",true).limit(12);
  if(error)throw error;
  const results=await Promise.allSettled((devices||[]).map(d=>sendOne(d.subscription as Subscription,{
    type:"test",title:"🔔 اختبار إشعارات فريش فرايز",
    body:"تم الاتصال بخادم إشعارات المطعم بنجاح.",
    tag:"ff-luxe-test",path:"./index.html"
  },120)));
  return json(req,{
    ok:true,devices:(devices||[]).length,
    sent:results.filter(x=>x.status==="fulfilled").length,
    failed:results.filter(x=>x.status==="rejected").length
  });
 }catch(e){console.error("FF Push test error",String(e));return json(req,{error:"PUSH_SEND_FAILED"},503)}
});