BEGIN;
DO $qa$
DECLARE m uuid:=gen_random_uuid();actor uuid;roles text[]:=ARRAY['cashier','driver','assembly','supervisor','customer_service','burger_kitchen','nonstaff','disabled_manager'];kind text;callers uuid[]:=ARRAY[]::uuid[];cashier_id uuid;cs_id uuid;cat uuid:=gen_random_uuid();item uuid;code_value text;reward_id uuid;app uuid;phone_value text:='999'||lpad(floor(random()*1e9)::bigint::text,9,'0');email_value text:='qa-'||gen_random_uuid()||'@example.invalid';r jsonb;checks int:=0;v_path text;
BEGIN
 INSERT INTO auth.users(id) VALUES(m);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 reward admin','manager',true);
 INSERT INTO public.ff_menu_categories(id,name,active) VALUES(cat,'QA STEP12 reward admin '||cat,true);
 INSERT INTO public.ff_menu_items(category_id,name,price,active) VALUES(cat,'QA STEP12 reward admin item',100,true) RETURNING id INTO item;
 v_path:='menu/'||item||'.png';
 FOREACH kind IN ARRAY roles LOOP
  actor:=gen_random_uuid();callers:=array_append(callers,actor);INSERT INTO auth.users(id) VALUES(actor);
  IF kind<>'nonstaff' THEN INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(actor,'QA STEP12 reward admin '||kind,CASE WHEN kind='disabled_manager' THEN 'manager' ELSE kind END,kind<>'disabled_manager');END IF;
  IF kind='cashier' THEN cashier_id:=actor;END IF;
  IF kind='customer_service' THEN cs_id:=actor;END IF;
 END LOOP;
 SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',m::text,true);
 r:=public.ff_reward_issue('hospitality','QA synthetic recipient','0000000000',jsonb_build_array(jsonb_build_object('id',item,'qty',1)),NULL);code_value:=r->>'code';reward_id:=(r->>'id')::uuid;
 FOREACH actor IN ARRAY callers LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  BEGIN PERFORM public.ff_reward_list(150);RAISE EXCEPTION 'Unauthorized reward list accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff_reward_void(code_value);RAISE EXCEPTION 'Unauthorized reward void accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff53_save_menu_image(item,v_path,'item');RAISE EXCEPTION 'Unauthorized menu image accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  BEGIN PERFORM public.ff_luxe_manager_prepare_staff('QA Applicant',phone_value,email_value,'cashier','QA degree','QA address',25,'single',0);RAISE EXCEPTION 'Unauthorized applicant preparation accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  IF actor NOT IN (cashier_id,cs_id) THEN
   BEGIN PERFORM public.ff_reward_check(code_value);RAISE EXCEPTION 'Unauthorized reward lookup accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
  ELSE
   r:=public.ff_reward_check(code_value);IF r->>'id' IS DISTINCT FROM reward_id::text THEN RAISE EXCEPTION 'Authorized reward lookup failed';END IF;checks:=checks+1;
  END IF;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 r:=public.ff_reward_list(150);IF NOT EXISTS(SELECT FROM jsonb_array_elements(r) z WHERE z->>'id'=reward_id::text AND z->>'status'='issued') THEN RAISE EXCEPTION 'Manager reward list failed';END IF;checks:=checks+1;
 IF public.ff_reward_void(code_value) IS DISTINCT FROM true THEN RAISE EXCEPTION 'Manager void failed';END IF;checks:=checks+1;
 BEGIN PERFORM public.ff_reward_check(code_value);RAISE EXCEPTION 'Voided code returned' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'الكود غير موجود أو منتهي أو مستخدم مسبقًا' THEN RAISE;END IF;END;checks:=checks+1;
 BEGIN PERFORM public.ff53_save_menu_image(item,v_path,'item');RAISE EXCEPTION 'Missing storage object accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'ارفع الصورة إلى التخزين قبل اعتمادها' THEN RAISE;END IF;END;checks:=checks+1;
 r:=public.ff_luxe_manager_prepare_staff('QA Applicant',phone_value,email_value,'cashier','QA degree','QA address',25,'single',0);
 app:=(r->>'application_id')::uuid;IF app IS NULL OR r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Manager preparation failed';END IF;checks:=checks+1;
 BEGIN PERFORM public.ff_luxe_manager_prepare_staff('QA Applicant',phone_value,email_value,'cashier','QA degree','QA address',25,'single',0);RAISE EXCEPTION 'Duplicate pending application accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE 'P0001' THEN IF SQLERRM<>'يوجد طلب انضمام معلّق لهذا الموظف؛ اعتمد الطلب الموجود أولًا' THEN RAISE;END IF;END;checks:=checks+1;
 RESET ROLE;
 IF NOT EXISTS(SELECT FROM public.ff61_employee_applications WHERE id=app AND status='pending') OR EXISTS(SELECT FROM auth.users WHERE email=email_value) OR (SELECT count(*) FROM public.ff61_employee_applications WHERE email=email_value)<>1 THEN RAISE EXCEPTION 'Unexpected application activation/duplication';END IF;checks:=checks+1;
 IF (SELECT status FROM public.ff_reward_codes WHERE id=reward_id) IS DISTINCT FROM 'void' OR EXISTS(SELECT FROM public.ff_menu_items WHERE id=item AND extra ? 'image_path') THEN RAISE EXCEPTION 'Reward or image fixture state mismatch';END IF;checks:=checks+1;
 IF checks<>48 THEN RAISE EXCEPTION 'Expected 48 assertions, got %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 reward admin, menu image guard and pending staff preparation: 48 assertions; rollback' result;
ROLLBACK;
