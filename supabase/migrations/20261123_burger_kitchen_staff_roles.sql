-- Extend employee application role check without altering existing applications.
ALTER TABLE public.ff61_employee_applications DROP CONSTRAINT IF EXISTS ff61_employee_applications_requested_role_check;
ALTER TABLE public.ff61_employee_applications ADD CONSTRAINT ff61_employee_applications_requested_role_check
 CHECK (requested_role = ANY (ARRAY['driver','cashier','customer_service','supervisor','assembly','burger_kitchen']));

CREATE OR REPLACE FUNCTION public.ff28_my_role()
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text; v_phone text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'تسجيل الدخول مطلوب' USING ERRCODE='42501'; END IF;
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active=true;
 IF v_role IN ('manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen') THEN RETURN v_role; END IF;
 IF EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid()) THEN
  RAISE EXCEPTION 'حساب موظف غير مفعل أو غير مصرح له' USING ERRCODE='42501';
 END IF;
 SELECT phone INTO v_phone FROM auth.users WHERE id=auth.uid() AND phone_confirmed_at IS NOT NULL;
 IF v_phone IS NOT NULL AND pg_catalog.regexp_replace(v_phone,'[^0-9]','','g') ~ '^9677[0-9]{8}$' THEN
  RETURN 'customer';
 END IF;
 RAISE EXCEPTION 'حساب غير مفعل أو رقم هاتف غير موثق' USING ERRCODE='42501';
END;
$function$;

CREATE OR REPLACE FUNCTION public.ff38_admin_link_user(p_email text, p_name text, p_role text, p_branch uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  DECLARE
    v_user uuid;
      v_driver uuid;
        v_previous_role text;
          v_previous_branch uuid;
            v_open_tasks integer;
              v_open_offers integer;
              BEGIN
                IF auth.uid() IS NULL OR NOT public.ff_is_manager() THEN
                    RAISE EXCEPTION 'هذه العملية للمدير فقط' USING ERRCODE='42501';
                      END IF;
                        IF p_role IS NULL OR p_role NOT IN ('driver','customer_service','cashier','supervisor','burger_kitchen') THEN
                            RAISE EXCEPTION 'دور غير مدعوم';
                              END IF;
                                IF pg_catalog.btrim(coalesce(p_name,'')) = '' OR pg_catalog.btrim(coalesce(p_email,'')) = '' THEN
                                    RAISE EXCEPTION 'الاسم والبريد مطلوبان';
                                      END IF;
                                        SELECT id INTO v_user FROM auth.users
                                           WHERE pg_catalog.lower(email) = pg_catalog.lower(pg_catalog.btrim(p_email)) LIMIT 1;
                                             IF v_user IS NULL THEN
                                                 RAISE EXCEPTION 'أنشئ الحساب أولاً في Supabase Authentication > Users ثم أعد المحاولة';
                                                   END IF;

                                                     -- Serialize account changes, including when the profile does not yet exist.
                                                       PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-user-' || v_user::text));
                                                         SELECT role INTO v_previous_role FROM public.ff_profiles
                                                             WHERE user_id = v_user FOR UPDATE;
                                                               IF v_previous_role = 'manager' THEN
                                                                   RAISE EXCEPTION 'لا يمكن تغيير حساب المدير' USING ERRCODE='42501';
                                                                     END IF;
                                                                       IF p_role IN ('driver','cashier','burger_kitchen') AND
                                                                           (p_branch IS NULL OR NOT EXISTS (
                                                                                 SELECT 1 FROM public.ff_branches WHERE id=p_branch AND active
                                                                                     )) THEN
                                                                                         RAISE EXCEPTION 'اختر فرعاً صحيحاً';
                                                                                           END IF;

                                                                                             SELECT driver_id INTO v_driver FROM public.ff38_driver_links
                                                                                                 WHERE user_id=v_user FOR UPDATE;
                                                                                                   IF v_driver IS NOT NULL THEN
                                                                                                       -- Lock presence row to serialize with driver acceptance operations.
                                                                                                           PERFORM 1 FROM public.ff38_driver_presence
                                                                                                                 WHERE driver_id=v_driver FOR UPDATE;
                                                                                                                     SELECT branch_id INTO v_previous_branch FROM public.ff_drivers
                                                                                                                           WHERE id=v_driver FOR UPDATE;
                                                                                                                               IF p_role <> 'driver' OR v_previous_branch IS DISTINCT FROM p_branch THEN
                                                                                                                                     SELECT count(*) INTO v_open_tasks
                                                                                                                                             FROM public.ff38_delivery_tasks t
                                                                                                                                                     JOIN public.ff_orders o ON o.id = t.order_id
                                                                                                                                                             WHERE t.driver_id = v_driver
                                                                                                                                                                       AND t.delivered_at IS NULL
                                                                                                                                                                                 AND t.phase IS DISTINCT FROM 'delivered'
                                                                                                                                                                                           AND o.status NOT IN ('delivered','cancelled','reservation_completed');
                                                                                                                                                                                                 SELECT count(*) INTO v_open_offers
                                                                                                                                                                                                         FROM public.ff38_dispatch_offers
                                                                                                                                                                                                                 WHERE driver_id=v_driver AND status='offered' AND expires_at > now();
                                                                                                                                                                                                                       IF v_open_tasks > 0 OR v_open_offers > 0 THEN
                                                                                                                                                                                                                               RAISE EXCEPTION 'لا يمكن تغيير دور أو فرع الموصل حتى ينهي طلباته وتنتهي عروضه النشطة';
                                                                                                                                                                                                                                     END IF;
                                                                                                                                                                                                                                         END IF;
                                                                                                                                                                                                                                           END IF;

                                                                                                                                                                                                                                             INSERT INTO public.ff_profiles(user_id,display_name,role,active)
                                                                                                                                                                                                                                                 VALUES(v_user,pg_catalog.btrim(p_name),p_role,true)
                                                                                                                                                                                                                                                     ON CONFLICT (user_id) DO UPDATE
                                                                                                                                                                                                                                                         SET display_name=excluded.display_name,role=excluded.role,active=true;

                                                                                                                                                                                                                                                           -- Old branch grants must never survive a role change.
                                                                                                                                                                                                                                                             DELETE FROM public.ff_user_branches WHERE user_id=v_user;

                                                                                                                                                                                                                                                               IF p_role='driver' THEN
                                                                                                                                                                                                                                                                   IF v_driver IS NULL THEN
                                                                                                                                                                                                                                                                         INSERT INTO public.ff_drivers(name,branch_id,status,active,sort_order)
                                                                                                                                                                                                                                                                                 VALUES(pg_catalog.btrim(p_name),p_branch,'ready',true,100)
                                                                                                                                                                                                                                                                                         RETURNING id INTO v_driver;
                                                                                                                                                                                                                                                                                               INSERT INTO public.ff38_driver_links(user_id,driver_id)
                                                                                                                                                                                                                                                                                                       VALUES(v_user,v_driver);
                                                                                                                                                                                                                                                                                                           ELSE
                                                                                                                                                                                                                                                                                                                 UPDATE public.ff_drivers
                                                                                                                                                                                                                                                                                                                         SET name=pg_catalog.btrim(p_name),branch_id=p_branch,active=true
                                                                                                                                                                                                                                                                                                                                 WHERE id=v_driver;
                                                                                                                                                                                                                                                                                                                                     END IF;
                                                                                                                                                                                                                                                                                                                                         INSERT INTO public.ff38_driver_presence(driver_id)
                                                                                                                                                                                                                                                                                                                                               VALUES(v_driver) ON CONFLICT DO NOTHING;
                                                                                                                                                                                                                                                                                                                                                 ELSE
                                                                                                                                                                                                                                                                                                                                                     IF v_driver IS NOT NULL THEN
                                                                                                                                                                                                                                                                                                                                                           UPDATE public.ff38_driver_presence
                                                                                                                                                                                                                                                                                                                                                                   SET state='offline',checked_out_at=now(),updated_at=now()
                                                                                                                                                                                                                                                                                                                                                                           WHERE driver_id=v_driver;
                                                                                                                                                                                                                                                                                                                                                                                 UPDATE public.ff_drivers SET active=false
                                                                                                                                                                                                                                                                                                                                                                                         WHERE id=v_driver;
                                                                                                                                                                                                                                                                                                                                                                                               DELETE FROM public.ff38_driver_links WHERE user_id=v_user;
                                                                                                                                                                                                                                                                                                                                                                                                   END IF;
                                                                                                                                                                                                                                                                                                                                                                                                       IF p_role IN ('cashier','burger_kitchen') THEN
                                                                                                                                                                                                                                                                                                                                                                                                             INSERT INTO public.ff_user_branches(user_id,branch_id)
                                                                                                                                                                                                                                                                                                                                                                                                                     VALUES(v_user,p_branch);
                                                                                                                                                                                                                                                                                                                                                                                                                         END IF;
                                                                                                                                                                                                                                                                                                                                                                                                                           END IF;

                                                                                                                                                                                                                                                                                                                                                                                                                             RETURN pg_catalog.jsonb_build_object(
                                                                                                                                                                                                                                                                                                                                                                                                                                 'linked',true,'user_id',v_user,'driver_id',
                                                                                                                                                                                                                                                                                                                                                                                                                                     CASE WHEN p_role='driver' THEN v_driver ELSE NULL END,
                                                                                                                                                                                                                                                                                                                                                                                                                                         'role',p_role
                                                                                                                                                                                                                                                                                                                                                                                                                                           );
                                                                                                                                                                                                                                                                                                                                                                                                                                           END;
                                                                                                                                                                                                                                                                                                                                                                                                                                           $function$;

CREATE OR REPLACE FUNCTION public.ff38_admin_staff_set_access(p_user uuid, p_role text, p_branches uuid[] DEFAULT ARRAY[]::uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_old public.ff_profiles%ROWTYPE;
  v_driver uuid;
   v_old_branch uuid;
    v_old_branches jsonb;
     v_new_branches jsonb;
      v_branch uuid;
       v_tasks integer;
        v_offers integer;
         v_conversion boolean;
         BEGIN
          IF auth.uid() IS NULL OR NOT EXISTS (
            SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND role='manager' AND active=true
             ) THEN RAISE EXCEPTION 'صلاحية المدير العام مطلوبة' USING ERRCODE='42501'; END IF;
              IF p_user IS NULL OR p_role IS NULL OR p_role NOT IN ('customer_service','cashier','supervisor','driver','burger_kitchen') THEN
                RAISE EXCEPTION 'الموظف أو الدور غير صالح'; END IF;
                 IF p_user=auth.uid() THEN RAISE EXCEPTION 'لا يمكنك تعديل دور حسابك'; END IF;
                  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-user-'||p_user::text));
                   SELECT * INTO v_old FROM public.ff_profiles WHERE user_id=p_user FOR UPDATE;
                    IF NOT FOUND THEN RAISE EXCEPTION 'حساب الموظف غير موجود'; END IF;
                     IF v_old.role='manager' THEN RAISE EXCEPTION 'لا يمكن تعديل حساب المدير العام'; END IF;
                      IF NOT v_old.active THEN RAISE EXCEPTION 'فعّل حساب الموظف أولًا قبل تغيير دوره'; END IF;
                       IF p_role='driver' AND coalesce(pg_catalog.array_length(p_branches,1),0)<>1 THEN
                         RAISE EXCEPTION 'اختر فرعًا واحدًا فقط للموصل'; END IF;
                          IF p_role='cashier' AND coalesce(pg_catalog.array_length(p_branches,1),0)<1 THEN
                            RAISE EXCEPTION 'اختر فرعًا واحدًا على الأقل للكاشير'; END IF;
                             IF p_role='burger_kitchen' AND coalesce(pg_catalog.array_length(p_branches,1),0)<>1 THEN
    RAISE EXCEPTION 'اختر فرعًا واحدًا فقط لقسم البرجر'; END IF;
   IF p_role IN ('customer_service','supervisor') AND coalesce(pg_catalog.array_length(p_branches,1),0)>0 THEN
                               RAISE EXCEPTION 'هذا الدور مركزي ولا يحتاج تحديد فروع'; END IF;
                                IF EXISTS (SELECT 1 FROM pg_catalog.unnest(p_branches) x WHERE x IS NULL OR NOT EXISTS (
                                  SELECT 1 FROM public.ff_branches b WHERE b.id=x AND b.active=true)) THEN
                                    RAISE EXCEPTION 'فرع غير موجود أو غير نشط'; END IF;
                                     SELECT coalesce(pg_catalog.jsonb_agg(branch_id ORDER BY branch_id),'[]'::jsonb)
                                      INTO v_old_branches FROM public.ff_user_branches WHERE user_id=p_user;
                                       SELECT l.driver_id INTO v_driver FROM public.ff38_driver_links l WHERE l.user_id=p_user FOR UPDATE;
                                        IF v_old.role='driver' AND v_driver IS NULL THEN
                                          RAISE EXCEPTION 'حساب الموصل لا يرتبط بسجل موصل، يلزم إصلاح الربط أولًا'; END IF;
                                           IF v_driver IS NOT NULL THEN
                                             PERFORM 1 FROM public.ff38_driver_presence WHERE driver_id=v_driver FOR UPDATE;
                                               SELECT d.branch_id INTO v_old_branch FROM public.ff_drivers d WHERE d.id=v_driver FOR UPDATE;
                                                 -- Check active work before any driver role conversion or branch transfer.
                                                   IF p_role<>'driver' OR v_old_branch IS DISTINCT FROM p_branches[1] THEN
                                                      SELECT count(*) INTO v_tasks FROM public.ff38_delivery_tasks t
                                                          JOIN public.ff_orders o ON o.id=t.order_id
                                                              WHERE t.driver_id=v_driver AND t.delivered_at IS NULL
                                                                    AND t.phase IS DISTINCT FROM 'delivered'
                                                                          AND o.status NOT IN ('delivered','cancelled','reservation_completed');
                                                                             SELECT count(*) INTO v_offers FROM public.ff38_dispatch_offers f
                                                                                 WHERE f.driver_id=v_driver AND f.status='offered' AND f.expires_at>now();
                                                                                    IF v_tasks>0 OR v_offers>0 THEN
                                                                                        RAISE EXCEPTION 'لا يمكن تحويل الموصل أو تغيير فرعه قبل إنهاء طلباته وعروضه النشطة'; END IF;
                                                                                          END IF;
                                                                                           END IF;
                                                                                            v_conversion := (v_old.role='driver') IS DISTINCT FROM (p_role='driver');
                                                                                             -- Lock target branch driver allocation during driver creation.
                                                                                              IF p_role='driver' AND v_driver IS NULL THEN
                                                                                                v_branch:=p_branches[1];
                                                                                                  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-branch-rr-'||v_branch::text));
                                                                                                    INSERT INTO public.ff_drivers(name,branch_id,status,active,sort_order)
                                                                                                      VALUES(v_old.display_name,v_branch,'ready',true,100) RETURNING id INTO v_driver;
                                                                                                        INSERT INTO public.ff38_driver_links(user_id,driver_id) VALUES(p_user,v_driver);
                                                                                                          INSERT INTO public.ff38_driver_presence(driver_id) VALUES(v_driver) ON CONFLICT DO NOTHING;
                                                                                                           ELSIF p_role='driver' AND v_driver IS NOT NULL THEN
                                                                                                             UPDATE public.ff_drivers SET branch_id=p_branches[1],active=true,name=v_old.display_name WHERE id=v_driver;
                                                                                                              ELSIF p_role<>'driver' AND v_driver IS NOT NULL THEN
                                                                                                                -- Preserve driver history; deactivate historical driver and unlink only the user mapping.
                                                                                                                  UPDATE public.ff38_driver_presence SET state='offline',checked_out_at=now(),updated_at=now() WHERE driver_id=v_driver;
                                                                                                                    UPDATE public.ff_drivers SET active=false WHERE id=v_driver;
                                                                                                                      DELETE FROM public.ff38_driver_links WHERE user_id=p_user;
                                                                                                                       END IF;
                                                                                                                        UPDATE public.ff_profiles SET role=p_role WHERE user_id=p_user;
                                                                                                                         DELETE FROM public.ff_user_branches WHERE user_id=p_user;
                                                                                                                          IF p_role IN ('cashier','burger_kitchen') THEN
                                                                                                                            INSERT INTO public.ff_user_branches(user_id,branch_id)
                                                                                                                              SELECT p_user,x FROM (SELECT DISTINCT pg_catalog.unnest(p_branches) x) s;
                                                                                                                               END IF;
                                                                                                                                SELECT coalesce(pg_catalog.jsonb_agg(branch_id ORDER BY branch_id),'[]'::jsonb)
                                                                                                                                 INTO v_new_branches FROM public.ff_user_branches WHERE user_id=p_user;
                                                                                                                                  INSERT INTO public.ff38_staff_admin_audit(actor_id,target_user_id,action,old_data,new_data)
                                                                                                                                   VALUES(auth.uid(),p_user,'set_access',
                                                                                                                                     pg_catalog.jsonb_build_object('role',v_old.role,'branches',v_old_branches,'driver_id',CASE WHEN v_old.role='driver' THEN v_driver ELSE NULL END),
                                                                                                                                       pg_catalog.jsonb_build_object('role',p_role,'branches',v_new_branches,'driver_id',CASE WHEN p_role='driver' THEN v_driver ELSE NULL END,'driver_branch',CASE WHEN p_role='driver' THEN p_branches[1] ELSE NULL END));
                                                                                                                                        RETURN pg_catalog.jsonb_build_object('changed',true,'role',p_role,'branches',v_new_branches,'driver_id',CASE WHEN p_role='driver' THEN v_driver ELSE NULL END,'converted',v_conversion);
                                                                                                                                        END; $function$;

CREATE OR REPLACE FUNCTION public.ff61_approve_application(p_application uuid, p_actor uuid, p_auth_user uuid, p_role text, p_branch uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                         DECLARE a public.ff61_employee_applications%ROWTYPE; v_auth_phone text; v_app_phone text; v_driver uuid;
                                         BEGIN
                                          IF NOT public.ff61_can_act(p_actor,'approve') THEN RAISE EXCEPTION 'لا تملك صلاحية اعتماد طلبات الانضمام' USING ERRCODE='42501'; END IF;
                                           IF p_role NOT IN ('cashier','driver','customer_service','supervisor','assembly','burger_kitchen') THEN RAISE EXCEPTION 'دور غير مسموح'; END IF;
                                            IF p_role IN ('cashier','driver','assembly','burger_kitchen') THEN
                                               IF p_branch IS NULL OR NOT EXISTS(SELECT 1 FROM public.ff_branches WHERE id=p_branch AND active=true)
                                                  THEN RAISE EXCEPTION 'الفرع غير صالح أو غير نشط'; END IF;
                                                   ELSE
                                                      IF p_branch IS NOT NULL THEN RAISE EXCEPTION 'هذا الدور لا يتطلب فرعًا منفردًا'; END IF;
                                                       END IF;
                                                        IF p_role='assembly' AND NOT EXISTS (
                                                           SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
                                                              WHERE n.nspname='public' AND p.proname='ff_v12_assembly_snapshot')
                                                               THEN RAISE EXCEPTION 'يجب تركيب وظائف نقطة التجميع الخادمية قبل قبول هذا الدور'; END IF;
                                                                SELECT * INTO a FROM public.ff61_employee_applications WHERE id=p_application FOR UPDATE;
                                                                 IF NOT FOUND OR a.status<>'pending' THEN RAISE EXCEPTION 'الطلب لم يعد معلقًا'; END IF;
                                                                  -- FF67: the approved employee logs in by PHONE; contact email is entirely optional.
                                                                   SELECT pg_catalog.regexp_replace(COALESCE(phone,''),'[^0-9]','','g') INTO v_auth_phone FROM auth.users WHERE id=p_auth_user;
                                                                    v_app_phone := pg_catalog.regexp_replace(COALESCE(a.phone,''),'[^0-9]','','g');
                                                                     IF pg_catalog.left(v_app_phone,2)='00' THEN v_app_phone:=pg_catalog.substr(v_app_phone, 3); END IF;
                                                                      IF pg_catalog.length(v_app_phone)=9 AND pg_catalog.left(v_app_phone,1)='7' THEN v_app_phone:='967'||v_app_phone; END IF;
                                                                       IF v_auth_phone IS NULL OR v_auth_phone<>v_app_phone
                                                                        THEN RAISE EXCEPTION 'هاتف حساب الدخول لا يطابق طلب الانضمام'; END IF;
                                                                         IF EXISTS (SELECT 1 FROM public.ff_profiles WHERE user_id=p_auth_user) THEN RAISE EXCEPTION 'حساب الدخول مرتبط مسبقًا'; END IF;
                                                                          INSERT INTO public.ff_profiles(user_id,display_name,role,active)
                                                                           VALUES(p_auth_user,a.full_name,p_role,true);
                                                                            IF p_role='cashier' THEN
                                                                               INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(p_auth_user,p_branch);
                                                                                ELSIF p_role='driver' THEN
                                                                                   PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-branch-rr-'||p_branch::text));
                                                                                      INSERT INTO public.ff_drivers(name,branch_id,status,active,sort_order)
                                                                                         VALUES(a.full_name,p_branch,'ready',true,100) RETURNING id INTO v_driver;
                                                                                            INSERT INTO public.ff38_driver_links(user_id,driver_id) VALUES(p_auth_user,v_driver);
                                                                                               INSERT INTO public.ff38_driver_presence(driver_id) VALUES(v_driver) ON CONFLICT DO NOTHING;
                                                                                                ELSIF p_role='burger_kitchen' THEN
   INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(p_auth_user,p_branch);
 ELSIF p_role='assembly' THEN
                                                                                                   INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(p_auth_user,p_branch);
                                                                                                      INSERT INTO public.ff_v9_assembly_access(user_id,branch_id,enabled,granted_by)
                                                                                                         VALUES(p_auth_user,p_branch,true,p_actor);
                                                                                                          END IF;
                                                                                                           UPDATE public.ff61_employee_applications SET status='approved',approved_role=p_role,
                                                                                                            approved_branch_id=p_branch,approved_user_id=p_auth_user,decided_by=p_actor,decided_at=now(),updated_at=now(),
                                                                                                             decision_reason='تم قبول الطلب، تُستلم بيانات الدخول من الإدارة.',
                                                                                                              phone_ownership_confirmed_by=p_actor,phone_ownership_confirmed_at=now() WHERE id=p_application;
                                                                                                               INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
                                                                                                                VALUES(p_actor,'ff61_application_approved','employee_application',p_application::text,p_branch,
                                                                                                                 jsonb_build_object('user_id',p_auth_user,'role',p_role));
                                                                                                                  RETURN jsonb_build_object('approved',true,'user_id',p_auth_user);
                                                                                                                  END; $function$;

CREATE OR REPLACE FUNCTION public.ff68_admin_staff_set_role(p_user uuid, p_role text, p_branches uuid[] DEFAULT ARRAY[]::uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                                                                                                   DECLARE v_old_role text; v_branch uuid; v_result jsonb;
                                                                                                                   BEGIN
                                                                                                                    IF NOT public.ff_is_manager() THEN RAISE EXCEPTION 'صلاحية المدير العام مطلوبة' USING ERRCODE='42501'; END IF;
                                                                                                                     IF p_user IS NULL OR p_user=auth.uid() OR p_role NOT IN ('assembly','driver','cashier','supervisor','customer_service','burger_kitchen')
                                                                                                                      THEN RAISE EXCEPTION 'طلب تعديل الدور غير صالح' USING ERRCODE='22023'; END IF;
                                                                                                                       SELECT role INTO v_old_role FROM public.ff_profiles WHERE user_id=p_user AND active=true FOR UPDATE;
                                                                                                                        IF v_old_role IS NULL OR v_old_role='manager' THEN RAISE EXCEPTION 'الموظف غير موجود أو غير نشط أو حساب مدير'; END IF;
                                                                                                                         IF p_role='assembly' THEN
                                                                                                                            IF COALESCE(pg_catalog.array_length(p_branches,1),0)<>1
                                                                                                                               THEN RAISE EXCEPTION 'نقطة التجميع يجب ربطها بفرع واحد فقط'; END IF;
                                                                                                                                  v_branch:=p_branches[1];
                                                                                                                                     IF v_branch IS NULL OR NOT EXISTS (SELECT 1 FROM public.ff_branches WHERE id=v_branch AND active=true)
                                                                                                                                        THEN RAISE EXCEPTION 'الفرع غير صالح أو غير نشط'; END IF;
                                                                                                                                           IF v_old_role='assembly' THEN
                                                                                                                                                RETURN public.ff62_assembly_set_branch(p_user,v_branch,true);
                                                                                                                                                   END IF;
                                                                                                                                                      -- Reuse the existing manager-only conversion for driver safety checks,
                                                                                                                                                         -- removal of old driver assignments, and individual permission reset.
                                                                                                                                                            PERFORM public.ff38_admin_staff_set_access(p_user,'cashier',ARRAY[v_branch]);
                                                                                                                                                               UPDATE public.ff_profiles SET role='assembly' WHERE user_id=p_user;
                                                                                                                                                                  UPDATE public.ff_v9_assembly_access SET enabled=false WHERE user_id=p_user;
                                                                                                                                                                     DELETE FROM public.ff_user_branches WHERE user_id=p_user;
                                                                                                                                                                        INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(p_user,v_branch);
                                                                                                                                                                           INSERT INTO public.ff_v9_assembly_access(user_id,branch_id,enabled,granted_by)
                                                                                                                                                                              VALUES(p_user,v_branch,true,auth.uid())
                                                                                                                                                                                 ON CONFLICT (user_id,branch_id) DO UPDATE SET enabled=true,granted_by=auth.uid(),granted_at=now();
                                                                                                                                                                                  ELSE
                                                                                                                                                                                     IF v_old_role='assembly' THEN
                                                                                                                                                                                           -- Revoke special assembly access before changing back to an ordinary role.
                                                                                                                                                                                                 UPDATE public.ff_v9_assembly_access SET enabled=false WHERE user_id=p_user;
                                                                                                                                                                                                    END IF;
                                                                                                                                                                                                       v_result:=public.ff38_admin_staff_set_access(p_user,p_role,p_branches);
                                                                                                                                                                                                          RETURN v_result;
                                                                                                                                                                                                           END IF;
                                                                                                                                                                                                            INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
                                                                                                                                                                                                             VALUES(auth.uid(),'ff68_staff_assembly_role','employee',p_user::text,v_branch,
                                                                                                                                                                                                                pg_catalog.jsonb_build_object('old_role',v_old_role,'new_role',p_role,'branch',v_branch));
                                                                                                                                                                                                                 RETURN pg_catalog.jsonb_build_object('saved',true,'role',p_role,'branch',v_branch);
                                                                                                                                                                                                                 END;
                                                                                                                                                                                                                 $function$;

CREATE OR REPLACE FUNCTION public.ff_luxe_manager_create_staff(p_actor uuid, p_auth_user uuid, p_name text, p_role text, p_branch uuid DEFAULT NULL::uuid, p_desk text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_driver uuid;v_branch uuid;
BEGIN
 IF NOT EXISTS(
  SELECT 1 FROM public.ff_profiles p
  WHERE p.user_id=p_actor AND p.active AND p.role='manager'
 ) THEN RAISE EXCEPTION 'هذه العملية للمدير العام فقط' USING ERRCODE='42501'; END IF;
 IF p_actor IS NULL OR p_auth_user IS NULL OR
    NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=p_auth_user)
 THEN RAISE EXCEPTION 'حساب الدخول غير صالح'; END IF;
 IF EXISTS(SELECT 1 FROM public.ff_profiles p WHERE p.user_id=p_auth_user)
 THEN RAISE EXCEPTION 'الحساب مرتبط مسبقًا بموظف'; END IF;
 IF p_name IS NULL OR length(btrim(p_name))<3 OR length(btrim(p_name))>150 OR
    array_length(regexp_split_to_array(btrim(p_name),'\s+'),1)<2
 THEN RAISE EXCEPTION 'اسم الموظف يجب أن يكون ثنائيًا على الأقل'; END IF;
 IF p_role NOT IN ('cashier','driver','customer_service','supervisor','assembly','burger_kitchen')
 THEN RAISE EXCEPTION 'الدور الوظيفي غير صالح'; END IF;
 IF p_role IN ('cashier','driver','assembly','burger_kitchen') THEN
  IF p_branch IS NULL OR NOT EXISTS(
   SELECT 1 FROM public.ff_branches b WHERE b.id=p_branch AND b.active
  ) THEN RAISE EXCEPTION 'حدد فرعًا نشطًا للموظف'; END IF;
 ELSIF p_branch IS NOT NULL THEN
  RAISE EXCEPTION 'هذا الدور مركزي ولا يحتاج فرعًا محددًا';
 END IF;
 IF p_role='cashier' THEN
  SELECT d.branch_id INTO v_branch FROM public.ff_luxe_cashier_desks d
  WHERE d.code=p_desk AND d.active;
  IF v_branch IS NULL OR v_branch<>p_branch
  THEN RAISE EXCEPTION 'وجهة الكاشير لا تتطابق مع الفرع'; END IF;
 ELSIF p_desk IS NOT NULL THEN
  RAISE EXCEPTION 'وجهة الكاشير مخصصة لدور الكاشير فقط';
 END IF;
 INSERT INTO public.ff_profiles(user_id,display_name,role,active)
 VALUES(p_auth_user,btrim(p_name),p_role,true);
 IF p_role='cashier' THEN
  INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(p_auth_user,p_branch);
  INSERT INTO public.ff_luxe_cashier_staff_desks(user_id,desk_code,assigned_by)
  VALUES(p_auth_user,p_desk,p_actor);
 ELSIF p_role='driver' THEN
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-branch-rr-'||p_branch::text));
  INSERT INTO public.ff_drivers(name,branch_id,status,active,sort_order)
  VALUES(btrim(p_name),p_branch,'ready',true,100) RETURNING id INTO v_driver;
  INSERT INTO public.ff38_driver_links(user_id,driver_id) VALUES(p_auth_user,v_driver);
  INSERT INTO public.ff38_driver_presence(driver_id) VALUES(v_driver)
  ON CONFLICT DO NOTHING;
 ELSIF p_role='burger_kitchen' THEN
  INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(p_auth_user,p_branch);
 ELSIF p_role='assembly' THEN
  IF NOT EXISTS (
   SELECT 1 FROM pg_catalog.pg_proc fn JOIN pg_catalog.pg_namespace n ON n.oid=fn.pronamespace
   WHERE n.nspname='public' AND fn.proname='ff_v12_assembly_snapshot'
  ) THEN RAISE EXCEPTION 'واجهة نقطة التجميع غير مثبتة'; END IF;
  INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(p_auth_user,p_branch);
  INSERT INTO public.ff_v9_assembly_access(user_id,branch_id,enabled,granted_by)
  VALUES(p_auth_user,p_branch,true,p_actor);
 END IF;
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 VALUES(p_actor,'manager_create_employee','employee',p_auth_user::text,p_branch,
        jsonb_build_object('role',p_role,'name',btrim(p_name),'desk',p_desk,'driver_id',v_driver,'source','manager_direct'));
 RETURN jsonb_build_object('ok',true,'user_id',p_auth_user,'role',p_role,'branch_id',p_branch,'cashier_desk',p_desk);
END;
$function$;

CREATE OR REPLACE FUNCTION public.ff_luxe_manager_prepare_staff(p_name text, p_phone text, p_email text, p_role text, p_qualification text, p_address text, p_age integer, p_marital text, p_experience integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_actor uuid:=auth.uid();v_id uuid;v_name text;v_phone text;v_email text;
BEGIN
 IF v_actor IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.ff_profiles p
  WHERE p.user_id=v_actor AND p.role='manager' AND p.active
 ) THEN RAISE EXCEPTION 'إضافة موظف جديد مخصصة للمدير العام فقط' USING ERRCODE='42501'; END IF;
 v_name:=regexp_replace(btrim(coalesce(p_name,'')),'\s+',' ','g');
 v_phone:=regexp_replace(coalesce(p_phone,''),'[^0-9]','','g');
 IF left(v_phone,2)='00' THEN v_phone:=substr(v_phone,3); END IF;
 IF length(v_phone)=9 AND left(v_phone,1)='7' THEN v_phone:='967'||v_phone; END IF;
 v_email:=nullif(lower(btrim(coalesce(p_email,''))),'');
 IF length(v_name)<3 OR length(v_name)>150 OR array_length(regexp_split_to_array(v_name,'\s+'),1)<2
 THEN RAISE EXCEPTION 'اسم الموظف ثنائي على الأقل'; END IF;
 IF v_phone !~ '^9677[0-9]{8}$' AND v_phone !~ '^[1-9][0-9]{7,14}$'
 THEN RAISE EXCEPTION 'رقم الهاتف غير صحيح'; END IF;
 IF v_email IS NOT NULL AND (length(v_email)>254 OR v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')
 THEN RAISE EXCEPTION 'البريد الإلكتروني غير صالح'; END IF;
 IF p_role NOT IN ('driver','cashier','customer_service','supervisor','assembly','burger_kitchen')
 THEN RAISE EXCEPTION 'الوظيفة غير صحيحة'; END IF;
 IF length(btrim(coalesce(p_qualification,''))) NOT BETWEEN 2 AND 150
 OR length(btrim(coalesce(p_address,''))) NOT BETWEEN 5 AND 240
 OR p_age NOT BETWEEN 16 AND 90
 OR p_marital NOT IN ('single','married','other','prefer_not_say')
 OR (p_experience IS NOT NULL AND p_experience NOT BETWEEN 0 AND 60)
 THEN RAISE EXCEPTION 'راجع المؤهل والعنوان والعمر والحالة الاجتماعية'; END IF;
 -- Avoid creating pending duplicates for existing employees or pending applicants.
 IF EXISTS (
  SELECT 1 FROM auth.users u
  WHERE regexp_replace(coalesce(u.phone,''),'[^0-9]','','g')=v_phone
    OR (v_email IS NOT NULL AND lower(u.email)=v_email)
 ) THEN RAISE EXCEPTION 'يوجد حساب دخول مسجل بهذا الهاتف أو البريد؛ استخدم إدارة الحسابات بدل إنشاء حساب جديد'; END IF;
 IF EXISTS (
  SELECT 1 FROM public.ff61_employee_applications a
  WHERE a.status='pending' AND
   (regexp_replace(a.phone,'[^0-9]','','g')=v_phone
     OR (v_email IS NOT NULL AND lower(a.email)=v_email))
 ) THEN RAISE EXCEPTION 'يوجد طلب انضمام معلّق لهذا الموظف؛ اعتمد الطلب الموجود أولًا'; END IF;
 INSERT INTO public.ff61_employee_applications(
  full_name,phone,email,qualification,address,age_years,marital_status,
  requested_role,experience_years,applicant_message,status
 ) VALUES(
  v_name,'+'||v_phone,v_email,btrim(p_qualification),btrim(p_address),p_age,p_marital,
  p_role,p_experience,'إنشاء حساب مباشرة بواسطة المدير العام من إدارة الموظفين','pending'
 ) RETURNING id INTO v_id;
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,details)
 VALUES(v_actor,'manager_prepared_employee','employee_application',v_id::text,
        jsonb_build_object('name',v_name,'role',p_role,'direct_create',true));
 RETURN jsonb_build_object('ok',true,'application_id',v_id,'phone','+'||v_phone);
END;
$function$;