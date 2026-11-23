import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.48.1";
const url = Deno.env.get("SUPABASE_URL") || "";
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const admin = createClient(url, key, {auth:{autoRefreshToken:false,persistSession:false}});
const origins = new Set((Deno.env.get("FF61_ALLOWED_ORIGINS") || "https://delivery.freshfriesz.com").split(",").map(x=>x.trim()).filter(Boolean));
const secret = Deno.env.get("FF62_TURNSTILE_SECRET") || "";
const encoder = new TextEncoder();
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const roles = new Set(["driver","cashier","customer_service","supervisor","assembly","burger_kitchen"]);
const pick = (v:unknown):string => typeof v === "string" ? v.trim() : "";
const check = (ok:unknown,msg:string):asserts ok => {if(!ok)throw Error(msg)};
const normalizePhone = (v:string):string => {
 let p=v.replace(/[٠-٩]/g,c=>String(c.charCodeAt(0)-0x660)).replace(/[۰-۹]/g,c=>String(c.charCodeAt(0)-0x6f0)).replace(/[\s()\-]/g,"");
 if(p.startsWith("00"))p="+"+p.slice(2);
 if(/^7\d{8}$/.test(p))p="+967"+p;
 if(/^9677\d{8}$/.test(p))p="+"+p;
 check(/^\+[1-9]\d{7,14}$/.test(p),"رقم الهاتف غير صالح");
 return p;
};
async function hash(s:string):Promise<string>{
 const a=new Uint8Array(await crypto.subtle.digest("SHA-256",encoder.encode(s)));
 return Array.from(a,x=>x.toString(16).padStart(2,"0")).join("");
}
async function rate(kind:string,value:string,max:number,mins:number):Promise<boolean>{
 const salt=Deno.env.get("FF62_RATE_SALT")||key;
 const {data,error}=await admin.rpc("ff62_claim_public_request",{p_key:await hash(salt+"|"+kind+"|"+value),p_limit:max,p_minutes:mins});
 if(error)throw Error("خدمة حماية الطلبات غير جاهزة");
 return data===true;
}
async function captcha(token:string):Promise<boolean>{
 if(!secret)return true;
 if(!token||token.length>4096)return false;
 const res=await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify",{method:"POST",body:new URLSearchParams({secret,response:token}),signal:AbortSignal.timeout(7000)});
 return res.ok&&(await res.json()).success===true;
}
function cors(origin:string|null):Record<string,string>{
 return {"Access-Control-Allow-Origin":origin&&origins.has(origin)?origin:"null","Access-Control-Allow-Methods":"POST, OPTIONS","Access-Control-Allow-Headers":"authorization,apikey,content-type,x-client-info","Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store","Vary":"Origin"};
}
function reply(body:unknown,status=200,origin:string|null=null){return new Response(JSON.stringify(body),{status,headers:cors(origin)});}
async function can(id:string,what:string):Promise<boolean>{
 const {data,error}=await admin.rpc("ff61_can_act",{p_actor:id,p_action:what});
 if(error)throw Error("تعذر التحقق من الصلاحية");
 return data===true;
}
serve(async req=>{
 const origin=req.headers.get("origin");
 if(req.method==="OPTIONS")return new Response(null,{status:204,headers:cors(origin)});
 if(req.method!=="POST")return reply({error:"الطريقة غير مدعومة"},405,origin);
 if(!origin||!origins.has(origin))return reply({error:"المصدر غير مسموح"},403,origin);
 if(Number(req.headers.get("content-length")||0)>16384)return reply({error:"حجم الطلب كبير"},413,origin);
 try{
  const input=await req.text();check(input.length<=16384,"حجم الطلب كبير");
  const b=JSON.parse(input);const action=pick(b?.action);
  const rawIp=(req.headers.get("cf-connecting-ip")||req.headers.get("x-forwarded-for")?.split(",")[0]||"").trim();
  if(action==="submit"){
    const v=b?.application||{};
    const full_name=pick(v.full_name).replace(/\s+/g," ");
    const email=pick(v.email).toLowerCase();const phone=normalizePhone(pick(v.phone));
    const qualification=pick(v.qualification),address=pick(v.address),marital_status=pick(v.marital_status),requested_role=pick(v.requested_role),applicant_message=pick(v.applicant_message);
    const age_years=Number(v.age_years);
    const experience_years=v.experience_years==null||v.experience_years===""?null:Number(v.experience_years);
    check(v.privacy_agreement===true,"يجب الموافقة على حفظ بيانات التقديم");
    check(full_name.trim().split(/\s+/u).length>=2&&full_name.length<=150,"أدخل اسمك الثنائي على الأقل");
    check(!email||(email.length>=6&&email.length<=254&&/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)),"البريد الإلكتروني اختياري، لكن عند إدخاله يجب أن يكون صالحًا");
    check(qualification.length>=2&&qualification.length<=150,"المؤهل العلمي مطلوب");
    check(address.length>=5&&address.length<=240,"العنوان مطلوب");
    check(Number.isInteger(age_years)&&age_years>=16&&age_years<=90,"العمر غير صحيح");
    check(["single","married","other","prefer_not_say"].includes(marital_status),"الحالة الاجتماعية غير صحيحة");
    check(roles.has(requested_role),"الوظيفة المطلوبة غير صحيحة");
    check(experience_years===null||(Number.isInteger(experience_years)&&experience_years>=0&&experience_years<=60),"سنوات الخبرة غير صحيحة");
    check(applicant_message.length<=1500,"ملاحظات المتقدم طويلة");
    if(!(await captcha(pick(b.captcha_token))))return reply({error:"أكمل التحقق الأمني"},400,origin);
    if(rawIp&&!(await rate("submit:ip",rawIp,12,60)))return reply({error:"تجاوز عدد المحاولات"},429,origin);
    if(!(await rate("submit:global","all",500,1440)))return reply({error:"خدمة التقديم مزدحمة، حاول لاحقًا"},429,origin);
    if(!(await rate("submit:phone",phone,3,1440)))return reply({error:"تجاوز حد التقديم لهذا الرقم"},429,origin);
    if(email&&!(await rate("submit:email",email,3,1440)))return reply({error:"تجاوز حد التقديم لهذا البريد"},429,origin);
    const receipt=Array.from(crypto.getRandomValues(new Uint8Array(32)),x=>x.toString(16).padStart(2,"0")).join("");
    const {error}=await admin.from("ff61_employee_applications").insert({full_name,email:email||null,phone,qualification,address,age_years,marital_status,requested_role,experience_years,applicant_message,tracking_token_hash:await hash(receipt),privacy_accepted_at:new Date().toISOString()});
    if(error?.code==="23505")return reply({error:"يوجد طلب معلق لهذا الهاتف أو البريد"},409,origin);
    if(error)throw Error("تعذر حفظ طلب الانضمام");
    return reply({ok:true,application_id:receipt,message:"تم إرسال الطلب واحتفظ برمز المتابعة"},201,origin);
  }
  if(action==="status"){
    if(rawIp&&!(await rate("status:ip",rawIp,30,60)))return reply({error:"محاولات متابعة كثيرة"},429,origin);
    const receipt=pick(b.application_id).toLowerCase();
    check(/^[a-f0-9]{64}$/.test(receipt),"رمز المتابعة غير صحيح");
    const {data,error}=await admin.from("ff61_employee_applications").select("status,decision_reason,approved_role,submitted_at,decided_at").eq("tracking_token_hash",await hash(receipt)).maybeSingle();
    if(error)throw Error("تعذر متابعة الطلب");
    if(!data)return reply({error:"رمز المتابعة غير موجود"},404,origin);
    return reply({ok:true,...data},200,origin);
  }
  const jwt=(req.headers.get("authorization")||"").replace(/^Bearer\s+/i,"").trim();
  if(jwt.length<=30)return reply({error:"سجّل الدخول أولًا"},401,origin);
  const {data:auth,error:authErr}=await admin.auth.getUser(jwt);
  if(authErr||!auth?.user?.id)return reply({error:"جلسة الدخول غير صالحة"},401,origin);
  const actor=auth.user.id;

  if(action==="staff_details"||action==="staff_update"){
    const target=pick(b.user_id);
    check(uuid.test(target),"معرف الموظف غير صحيح");
    const {data:manager,error:managerError}=await admin.from("ff_profiles").select("role,active").eq("user_id",actor).maybeSingle();
    check(!managerError&&manager?.active===true&&manager.role==="manager","هذه العملية للمدير العام فقط");
    const {data:p,error:pe}=await admin.from("ff_profiles").select("user_id,display_name,role,active").eq("user_id",target).maybeSingle();
    check(!pe&&p,"الموظف غير موجود");
    check(p.role!=="manager"||actor===target,"لا يمكن تعديل مدير آخر");
    const {data:existing,error:ae}=await admin.auth.admin.getUserById(target);
    check(!ae&&existing?.user,"تعذر تحميل حساب الموظف");
    const u=existing.user;
    const meta=u.user_metadata||{};
    const {data:application}=await admin.from("ff61_employee_applications").select("id,qualification,address,age_years,marital_status,experience_years,applicant_message").eq("approved_user_id",target).maybeSingle();
    if(action==="staff_details"){
      const alias=(u.email||"").endsWith("@users.freshfriesz.com");
      return reply({ok:true,employee:{
        user_id:target,name:p.display_name||"",role:p.role,
        username:alias?(u.email||"").split("@")[0]:pick(meta.ff_username),
        email:alias?pick(meta.ff_contact_email):(u.email||""),
        phone:u.phone||"",qualification:application?.qualification||meta.qualification||"",
        address:application?.address||meta.address||"",age_years:application?.age_years??meta.age_years??"",
        marital_status:application?.marital_status||meta.marital_status||"",
        experience_years:application?.experience_years??meta.experience_years??"",
        applicant_message:application?.applicant_message||meta.applicant_message||""
      }},200,origin);
    }
    const d=b.employee||{};
    const name=pick(d.name).replace(/\s+/g," "),username=pick(d.username).toLowerCase(),email=pick(d.email).toLowerCase(),phone=pick(d.phone);
    check(name.length>=2&&name.length<=150,"اسم الموظف غير صحيح");
    check(!username||/^[a-z][a-z0-9._-]{1,62}$/.test(username),"اسم المستخدم يجب أن يكون أحرفًا لاتينية أو أرقامًا");
    check(!email||/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email),"البريد الإلكتروني غير صالح");
    const password=typeof d.password==="string"?d.password:"";
    check(!password||Array.from(password).length===8,"كلمة المرور يجب أن تكون 8 خانات بالضبط");
    const alias=(u.email||"").endsWith("@users.freshfriesz.com");
    const newAuthEmail=username?username+"@users.freshfriesz.com":(!alias&&email?email:u.email);
    const fields:any={user_metadata:{...meta,full_name:name,display_name:name,ff_username:username,ff_contact_email:email,qualification:pick(d.qualification),address:pick(d.address),marital_status:pick(d.marital_status),applicant_message:pick(d.applicant_message)}};
    if(newAuthEmail&&newAuthEmail!==u.email){fields.email=newAuthEmail;fields.email_confirm=true;}
    if(phone){fields.phone=normalizePhone(phone);fields.phone_confirm=true;}
    if(password)fields.password=password;
    const {error:updateError}=await admin.auth.admin.updateUserById(target,fields);
    if(updateError)throw Error("تعذر تحديث حساب الدخول: "+updateError.message);
    const {error:profileError}=await admin.from("ff_profiles").update({display_name:name}).eq("user_id",target);
    if(profileError)throw Error("تم تحديث بيانات الدخول لكن تعذر تحديث الاسم في سجل الموظفين");
    if(application?.id){
      const {error:appError}=await admin.from("ff61_employee_applications").update({full_name:name,qualification:pick(d.qualification)||application.qualification,address:pick(d.address)||application.address,marital_status:pick(d.marital_status)||application.marital_status,age_years:d.age_years!==""&&Number.isInteger(Number(d.age_years))&&Number(d.age_years)>=16&&Number(d.age_years)<=90?Number(d.age_years):application.age_years,experience_years:d.experience_years!==""&&Number.isInteger(Number(d.experience_years))&&Number(d.experience_years)>=0&&Number(d.experience_years)<=60?Number(d.experience_years):application.experience_years,applicant_message:pick(d.applicant_message)}).eq("approved_user_id",target);
      if(appError)throw Error("تم تعديل الحساب لكن لم يمكن تحديث ملف طلب الانضمام");
    }
    await admin.from("ff_audit_log").insert({actor_id:actor,action:"manager_edit_employee",entity_type:"employee",entity_id:target,details:{password_changed:!!password,username_changed:newAuthEmail!==u.email,source:"ff61-employees"}});
    return reply({ok:true,login_username:username||newAuthEmail||phone,password_changed:!!password},200,origin);
  }
  if(action==="manager_reset_staff_password"){
    const target=pick(b.user_id),password=typeof b.password==="string"?b.password:"";
    check(uuid.test(target),"معرف الموظف غير صحيح");
    check(Array.from(password).length===8,"كلمة المرور يجب أن تكون 8 خانات بالضبط");
    const {data:m}=await admin.from("ff_profiles").select("role,active").eq("user_id",actor).maybeSingle();
    check(m?.active===true&&m.role==="manager","للمدير فقط");
    check(actor!==target,"لا يمكن تعديل حساب المدير هنا");
    const {data:p}=await admin.from("ff_profiles").select("role").eq("user_id",target).maybeSingle();
    check(p&&p.role!=="manager","الحساب غير مؤهل");
    const {error:e}=await admin.auth.admin.updateUserById(target,{password});
    if(e)throw Error("تعذر تغيير كلمة المرور");
    await admin.from("ff_audit_log").insert({actor_id:actor,action:"manager_reset_staff_password",entity_type:"employee",entity_id:target,details:{source:"ff61-employees"}});
    return reply({ok:true},200,origin);
  }
  if(action==="capabilities"){
    const [view,approve,reject,notify]=await Promise.all(["view","approve","reject","notify"].map(x=>can(actor,x)));
    return reply({ok:true,view,approve,reject,notify},200,origin);
  }
  if(action==="alerts"){
    check(await can(actor,"notify"),"لا توجد صلاحية للإشعارات");
    const {data,count,error}=await admin.from("ff61_employee_applications").select("id",{count:"exact"}).eq("status","pending").order("submitted_at",{ascending:false}).limit(100);
    if(error)throw Error("تعذر جلب الطلبات");
    return reply({ok:true,pending_count:count||0,ids:(data||[]).map(x=>x.id)},200,origin);
  }
  if(action==="notifications_count"||action==="notifications"){
    check(await can(actor,"notify"),"لا توجد صلاحية للإشعارات");
    const {count,error}=await admin.from("ff63_employee_notifications").select("id",{count:"exact",head:true}).eq("recipient_user_id",actor).is("read_at",null);
    if(error)throw Error("تعذر قراءة الإشعارات");
    if(action==="notifications_count")return reply({ok:true,unread_count:count||0},200,origin);
    const {data,error:err}=await admin.from("ff63_employee_notifications").select("id,application_id,notification_kind,title,created_at,read_at").eq("recipient_user_id",actor).order("created_at",{ascending:false}).order("id",{ascending:false}).limit(80);
    if(err)throw Error("تعذر قراءة الإشعارات");
    return reply({ok:true,notifications:data||[],unread_count:count||0},200,origin);
  }
  if(action==="notifications_read_all"||action==="notification_read"){
    check(await can(actor,"notify"),"لا توجد صلاحية للإشعارات");
    let query=admin.from("ff63_employee_notifications").update({read_at:new Date().toISOString()}).eq("recipient_user_id",actor).is("read_at",null);
    if(action==="notification_read"){const id=pick(b.notification_id);check(/^[1-9]\d{0,17}$/.test(id),"معرف الإشعار غير صحيح");query=query.eq("id",id);}
    const {error}=await query;if(error)throw Error("تعذر حفظ قراءة الإشعار");
    return reply({ok:true},200,origin);
  }
  const cols="id,full_name,email,phone,qualification,address,age_years,marital_status,requested_role,experience_years,applicant_message,status,decision_reason,approved_role,approved_branch_id,submitted_at,decided_at";
  if(action==="list"||action==="application_details"){
    check(await can(actor,"view"),"لا توجد صلاحية لعرض طلبات الانضمام");
    if(action==="application_details"){
      const id=pick(b.application_id);check(uuid.test(id),"معرف الطلب غير صحيح");
      const {data,error}=await admin.from("ff61_employee_applications").select(cols).eq("id",id).maybeSingle();
      if(error)throw Error("تعذر جلب الطلب");
      return data?reply({ok:true,application:data},200,origin):reply({error:"الطلب غير موجود"},404,origin);
    }
    const status=pick(b.status);check(["","pending","history"].includes(status),"حالة قائمة الطلبات غير صحيحة");
    const page=b.page??0;check(Number.isSafeInteger(page)&&page>=0&&page<=10000,"رقم الصفحة غير صالح");
    const pageSize=status===""?100:25;
    let query=admin.from("ff61_employee_applications").select(cols,{count:"exact"});
    if(status==="pending")query=query.eq("status","pending");
    if(status==="history")query=query.in("status",["approved","rejected"]);
    const {data,count,error}=await query.order("submitted_at",{ascending:false}).order("id",{ascending:false}).range(page*pageSize,page*pageSize+pageSize-1);
    if(error)throw Error("تعذر عرض طلبات الانضمام");
    return reply({ok:true,applications:data||[],total_count:count||0,page,page_size:pageSize},200,origin);
  }
  if(action==="approve"){
    check(await can(actor,"approve"),"ليس لديك صلاحية القبول");
    const id=pick(b.application_id),role=pick(b.role),branch=pick(b.branch_id),password=typeof b.password==="string"?b.password:"";
    check(uuid.test(id)&&roles.has(role),"بيانات القرار غير صحيحة");
    check(["driver","cashier","assembly","burger_kitchen"].includes(role)?uuid.test(branch):!branch,"الفرع غير صالح");
    check(Array.from(password).length===8,"كلمة المرور يجب أن تكون 8 خانات بالضبط");
    check(b.phone_ownership_verified===true,"يجب أن تؤكد الإدارة ملكية رقم الهاتف");
    const {data:application,error:appErr}=await admin.from("ff61_employee_applications").select("id,email,phone,full_name,status").eq("id",id).single();
    if(appErr||application.status!=="pending")return reply({error:"الطلب لم يعد معلقًا"},409,origin);
    const {data:user,error:createErr}=await admin.auth.admin.createUser({...(application.email?{email:application.email,email_confirm:false}:{}),phone:normalizePhone(application.phone),password,phone_confirm:true,user_metadata:{full_name:application.full_name,created_via:"ff61_employee_application"}});
    if(createErr||!user?.user?.id)return reply({error:"تعذر إنشاء حساب الدخول؛ قد يكون رقم الهاتف مسجلًا سابقًا"},409,origin);
    const {error:decisionErr}=await admin.rpc("ff61_approve_application",{p_application:id,p_actor:actor,p_auth_user:user.user.id,p_role:role,p_branch:branch||null});
    if(decisionErr){
      const {data:latest}=await admin.from("ff61_employee_applications").select("status,approved_user_id").eq("id",id).maybeSingle();
      if(latest?.status==="approved"&&latest?.approved_user_id===user.user.id)return reply({ok:true,approved:true,user_id:user.user.id},200,origin);
      const {error:cleanupErr}=await admin.auth.admin.deleteUser(user.user.id);
      return reply({error:cleanupErr?"تعذر ربط الحساب ويجب مراجعة إدارة Authentication":"تعذر اعتماد الموظف ولم تُمنح له صلاحيات"},409,origin);
    }
    return reply({ok:true,approved:true,user_id:user.user.id},200,origin);
  }
  if(action==="reject"){
    check(await can(actor,"reject"),"ليس لديك صلاحية الرفض");
    const id=pick(b.application_id),reason=pick(b.reason);
    check(uuid.test(id)&&reason.length>=5&&reason.length<=1200,"سبب الرفض مطلوب");
    const {data,error}=await admin.rpc("ff61_reject_application",{p_application:id,p_actor:actor,p_reason:reason});
    if(error)throw Error("تعذر رفض الطلب");
    return reply({ok:true,...data},200,origin);
  }
  if(action==="delegations"||action==="set_delegation"){
    const {data:profile}=await admin.from("ff_profiles").select("role,active").eq("user_id",actor).single();
    check(profile?.active&&profile.role==="manager","هذه العملية للمدير العام فقط");
    if(action==="delegations"){
      const [staff,delegations]=await Promise.all([
        admin.from("ff_profiles").select("user_id,display_name,role,active").neq("role","manager").order("display_name").limit(250),
        admin.from("ff61_application_delegations").select("user_id,may_view,may_approve,may_reject,may_notify")
      ]);
      if(staff.error||delegations.error)throw Error("تعذر تحميل التفويضات");
      return reply({ok:true,staff:staff.data||[],delegations:delegations.data||[]},200,origin);
    }
    const uid=pick(b.user_id);check(uuid.test(uid),"معرف الموظف غير صحيح");
    const anonKey=Deno.env.get("SUPABASE_ANON_KEY")||"";check(anonKey,"مفتاح إعداد الخادم غير موجود");
    const userClient=createClient(url,anonKey,{global:{headers:{Authorization:"Bearer "+jwt}},auth:{autoRefreshToken:false,persistSession:false}});
    const {error}=await userClient.rpc("ff61_set_delegation",{p_user:uid,p_view:b.view===true,p_approve:b.approve===true,p_reject:b.reject===true,p_notify:b.notify===true});
    if(error)throw Error("تعذر حفظ تفويض الموظف");
    return reply({ok:true},200,origin);
  }
  return reply({error:"الإجراء غير معروف"},400,origin);
 }catch(e){
  const msg=e instanceof Error?e.message:"حدث خطأ في الطلب";
  return reply({error:msg.slice(0,300)},400,origin);
 }
});