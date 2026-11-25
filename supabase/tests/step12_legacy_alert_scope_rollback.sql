BEGIN;
DO $qa$
DECLARE s uuid:=gen_random_uuid(); cs uuid:=gen_random_uuid(); b1 uuid:=gen_random_uuid(); b2 uuid:=gen_random_uuid(); o1 uuid:=gen_random_uuid(); o2 uuid:=gen_random_uuid(); v jsonb;checks int:=0;
BEGIN
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-alerts-'||b1,'QA alerts one'),(b2,'qa-alerts-'||b2,'QA alerts two');
 INSERT INTO auth.users(id) VALUES(s),(cs);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(s,'QA STEP12 supervisor','supervisor',true),(cs,'QA STEP12 central','customer_service',true);
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(s,b1);
 INSERT INTO public.ff38_staff_permission_overrides(user_id,permission_key,allowed,updated_by) VALUES(s,'view_reports',true,s),(cs,'view_reports',true,cs);
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot,order_type,created_at) VALUES(o1,-(1+floor(random()*1e12)::bigint),b1,'000000000',public.ff_business_date(now()),'QA','delivery',now()-interval '13 days'),(o2,-(1+floor(random()*1e12)::bigint),b2,'000000000',public.ff_business_date(now()),'QA','delivery',now()-interval '13 days');
 SET LOCAL ROLE authenticated;
 PERFORM set_config('request.jwt.claim.sub',s::text,true);
 BEGIN PERFORM public.ff40_operations_alerts(b2);RAISE EXCEPTION 'Foreign branch requested' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 v:=public.ff40_operations_alerts(b1);
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(v->'items') x WHERE x->>'order_id'=o1::text) THEN RAISE EXCEPTION 'Own branch alert missing';END IF;checks:=checks+1;
 v:=public.ff40_operations_alerts(NULL);
 IF EXISTS(SELECT FROM jsonb_array_elements(v->'items') x WHERE x->>'order_id'=o2::text) THEN RAISE EXCEPTION 'Implicit scope leak';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',cs::text,true);
 v:=public.ff40_operations_alerts(b2);
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(v->'items') x WHERE x->>'order_id'=o2::text) THEN RAISE EXCEPTION 'Central branch access broken';END IF;checks:=checks+1;
 RESET ROLE;
 UPDATE public.ff38_staff_permission_overrides SET allowed=false WHERE user_id=s AND permission_key='view_reports';
 SET LOCAL ROLE authenticated;PERFORM set_config('request.jwt.claim.sub',s::text,true);
 BEGIN PERFORM public.ff40_operations_alerts(b1);RAISE EXCEPTION 'Revoked report access accepted' USING ERRCODE='ZQA12';EXCEPTION WHEN SQLSTATE '42501' THEN NULL;END;checks:=checks+1;
 RESET ROLE;
 IF checks<>5 THEN RAISE EXCEPTION 'Incomplete alert checks';END IF;
END $qa$;
SELECT 'PASS STEP12 alerts: 5 checks; explicit/implicit branch scope, own branch, central CS, revoked permission' result;
ROLLBACK;
