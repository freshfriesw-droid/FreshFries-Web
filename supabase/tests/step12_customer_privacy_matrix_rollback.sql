BEGIN;
DO $qa$
DECLARE b uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); cs uuid:=gen_random_uuid(); actor uuid; o uuid:=gen_random_uuid(); phone_value text:='000'||replace(gen_random_uuid()::text,'-',''); n bigint:=-1000000000000-floor(random()*1e12)::bigint; roles text[]:=ARRAY['cashier','driver','assembly','supervisor','burger_kitchen','nonstaff','disabled_manager','disabled_cs']; role_name text; callers uuid[]:=ARRAY[]::uuid[]; call_sql text; calls text[]; checks int:=0; r jsonb; v_notes int;
BEGIN
 INSERT INTO auth.users(id) VALUES(m),(cs);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 privacy manager','manager',true),(cs,'QA STEP12 privacy CS','customer_service',true);
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-step12-privacy-'||b,'QA STEP12 privacy');
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,area_snapshot,status,created_by,items_total,delivery_fee,total) VALUES(o,n,b,phone_value,'QA synthetic area','new',m,100,0,100);
 FOREACH role_name IN ARRAY roles LOOP
  actor:=gen_random_uuid(); callers:=array_append(callers,actor); INSERT INTO auth.users(id) VALUES(actor);
  IF role_name<>'nonstaff' THEN INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(actor,'QA STEP12 privacy '||role_name,CASE WHEN role_name='disabled_manager' THEN 'manager' WHEN role_name='disabled_cs' THEN 'customer_service' ELSE role_name END,role_name NOT LIKE 'disabled_%');END IF;
  IF role_name IN ('cashier','driver','assembly','supervisor','burger_kitchen') THEN INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(actor,b);END IF;
 END LOOP;
 calls:=ARRAY[
 format('SELECT public.ff51_customer_directory(%L,10)',phone_value),
 format('SELECT public.ff51_customer_note_add(%L,%L)',phone_value,'QA synthetic unauthorized note'),
 format('SELECT public.ff51_customer_notes_list(%L)',phone_value),
 format('SELECT public.ff_a02_customer_history(%L)',phone_value)];
 SET LOCAL ROLE authenticated;
 FOREACH actor IN ARRAY callers LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  FOREACH call_sql IN ARRAY calls LOOP
   BEGIN EXECUTE call_sql; RAISE EXCEPTION 'Unauthorized customer privacy call returned: %',call_sql USING ERRCODE='ZQA12';
   EXCEPTION WHEN SQLSTATE '42501' THEN checks:=checks+1;END;
  END LOOP;
 END LOOP;
 FOREACH actor IN ARRAY ARRAY[m,cs] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  r:=public.ff51_customer_directory(phone_value,10);
  IF jsonb_array_length(r)<>1 OR r->0->>'phone' IS DISTINCT FROM phone_value THEN RAISE EXCEPTION 'Authorized directory failed';END IF;checks:=checks+1;
  r:=public.ff51_customer_note_add(phone_value,'QA synthetic authorized note');
  IF r->>'saved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Authorized note failed';END IF;checks:=checks+1;
  r:=public.ff51_customer_notes_list(phone_value);
  IF NOT EXISTS(SELECT FROM jsonb_array_elements(r) j WHERE j->>'added_by'=actor::text) THEN RAISE EXCEPTION 'Authorized note list failed';END IF;checks:=checks+1;
  r:=public.ff_a02_customer_history(phone_value);
  IF NOT EXISTS(SELECT FROM jsonb_array_elements(r->'orders') j WHERE j->>'id'=o::text) THEN RAISE EXCEPTION 'Authorized history failed';END IF;checks:=checks+1;
 END LOOP;
 RESET ROLE;
 SELECT count(*) INTO v_notes FROM public.ff51_customer_notes WHERE phone=phone_value;
 IF v_notes<>2 OR EXISTS(SELECT FROM public.ff51_customer_notes WHERE phone=phone_value AND added_by NOT IN(m,cs)) THEN RAISE EXCEPTION 'Unexpected note persistence';END IF;checks:=checks+1;
 IF checks<>41 THEN RAISE EXCEPTION 'Expected 41 checks, got %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 customer privacy: 32 unauthorized calls denied; 8 authorized and 1 state checks' result;
ROLLBACK;
