BEGIN;
DO $qa$
DECLARE u uuid:=gen_random_uuid();c uuid:=gen_random_uuid();d uuid:=gen_random_uuid();m uuid:=gen_random_uuid();b uuid:=gen_random_uuid();drv uuid:=gen_random_uuid();cat uuid:=gen_random_uuid();item uuid:=gen_random_uuid();offer uuid:=gen_random_uuid();staff uuid:=gen_random_uuid();ord uuid:=gen_random_uuid();ev uuid:=gen_random_uuid();tag text:='qa-'||gen_random_uuid();actor uuid;stm text;updates text[];inserts text[];deletes text[];n int;checks int:=0;
BEGIN
 INSERT INTO auth.users(id) VALUES(u),(c),(d),(m);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(c,'QA STEP12 direct cashier','cashier',true),(d,'QA STEP12 direct disabled','cashier',false),(m,'QA STEP12 direct manager','manager',true);
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,tag,'QA branch');
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c,b),(d,b);
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(drv,'QA driver',b);
 INSERT INTO public.ff_menu_categories(id,name) VALUES(cat,tag);
 INSERT INTO public.ff_menu_items(id,category_id,name,price) VALUES(item,cat,tag,100);
 INSERT INTO public.ff_offers(id,name,price) VALUES(offer,tag,100);
 INSERT INTO public.ff_staff(id,name,role) VALUES(staff,tag,'cashier');
 INSERT INTO public.ff_app_settings(setting_key,setting_value) VALUES(tag,'{"qa":true}');
 INSERT INTO public.ff_role_permissions(role,permission,enabled) VALUES('cashier',tag,false);
 INSERT INTO public.ff_user_permissions(user_id,permission,enabled) VALUES(c,tag,false);
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,business_date,area_snapshot,status) VALUES(ord,-1000000000000-floor(random()*1e12)::bigint,b,'000000000',public.ff_business_date(now()),'QA','new');
 INSERT INTO public.ff_order_events(id,order_id,new_status) VALUES(ev,ord,'new');
 updates:=ARRAY[
 format('UPDATE public.ff_app_settings SET setting_value=%L::jsonb WHERE setting_key=%L','{"qa":false}',tag),
 format('UPDATE public.ff_branches SET name=%L WHERE id=%L::uuid','QA denied',b),
 format('UPDATE public.ff_drivers SET name=%L WHERE id=%L::uuid','QA denied',drv),
 format('UPDATE public.ff_menu_categories SET name=%L WHERE id=%L::uuid','QA denied',cat),
 format('UPDATE public.ff_menu_items SET price=999 WHERE id=%L::uuid',item),
 format('UPDATE public.ff_offers SET price=999 WHERE id=%L::uuid',offer),
 format('UPDATE public.ff_staff SET name=%L WHERE id=%L::uuid','QA denied',staff),
 format('UPDATE public.ff_role_permissions SET enabled=true WHERE role=%L AND permission=%L','cashier',tag),
 format('UPDATE public.ff_user_permissions SET enabled=true WHERE user_id=%L::uuid AND permission=%L',c,tag),
 format('UPDATE public.ff_order_events SET new_status=%L WHERE id=%L::uuid','cancelled',ev)];
 deletes:=ARRAY[
 format('DELETE FROM public.ff_app_settings WHERE setting_key=%L',tag),
 format('DELETE FROM public.ff_menu_categories WHERE id=%L::uuid',cat),
 format('DELETE FROM public.ff_menu_items WHERE id=%L::uuid',item),
 format('DELETE FROM public.ff_offers WHERE id=%L::uuid',offer),
 format('DELETE FROM public.ff_staff WHERE id=%L::uuid',staff),
 format('DELETE FROM public.ff_role_permissions WHERE role=%L AND permission=%L','cashier',tag),
 format('DELETE FROM public.ff_user_permissions WHERE user_id=%L::uuid AND permission=%L',c,tag)];
 SET LOCAL ROLE authenticated;
 FOREACH actor IN ARRAY ARRAY[u,c,d] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  FOREACH stm IN ARRAY updates||deletes LOOP
   EXECUTE stm;GET DIAGNOSTICS n=ROW_COUNT;
   IF n<>0 THEN RAISE EXCEPTION 'Unauthorized DML changed % rows',n;END IF;checks:=checks+1;
  END LOOP;
  inserts:=ARRAY[
  format('INSERT INTO public.ff_app_settings(setting_key,setting_value) VALUES(%L,%L::jsonb)',tag||'-insert','{}'),
  format('INSERT INTO public.ff_branches(code,name) VALUES(%L,%L)',tag||'-insert','QA branch'),
  format('INSERT INTO public.ff_drivers(name,branch_id) VALUES(%L,%L::uuid)','QA driver',b),
  format('INSERT INTO public.ff_menu_categories(name) VALUES(%L)',tag||'-insert'),
  format('INSERT INTO public.ff_menu_items(category_id,name,price) VALUES(%L::uuid,%L,100)',cat,tag||'-insert'),
  format('INSERT INTO public.ff_offers(name,price) VALUES(%L,100)',tag||'-insert'),
  format('INSERT INTO public.ff_staff(name,role) VALUES(%L,%L)',tag||'-insert','cashier'),
  format('INSERT INTO public.ff_role_permissions(role,permission,enabled) VALUES(%L,%L,true)','cashier',tag||'-insert'),
  format('INSERT INTO public.ff_user_permissions(user_id,permission,enabled) VALUES(%L::uuid,%L,true)',actor,tag||'-insert'),
  format('INSERT INTO public.ff_order_events(order_id,new_status) VALUES(%L::uuid,%L)',ord,'cancelled'),
  format('INSERT INTO public.ff66_tones(name,storage_path,mime_type,size_bytes,created_by) VALUES(%L,%L,%L,100,%L::uuid)','QA tone','tones/'||gen_random_uuid()||'.mp3','audio/mpeg',actor)];
  FOREACH stm IN ARRAY inserts LOOP
   BEGIN EXECUTE stm;RAISE EXCEPTION 'Unauthorized insert accepted' USING ERRCODE='ZQA12';
   EXCEPTION WHEN SQLSTATE '42501' THEN checks:=checks+1;END;
  END LOOP;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 UPDATE public.ff_menu_items SET price=120 WHERE id=item;GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>1 THEN RAISE EXCEPTION 'Manager menu update denied';END IF;checks:=checks+1;
 UPDATE public.ff_user_permissions SET enabled=true WHERE user_id=c AND permission=tag;GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>1 THEN RAISE EXCEPTION 'Manager permission update denied';END IF;checks:=checks+1;
 UPDATE public.ff_app_settings SET setting_value='{"qa":false}' WHERE setting_key=tag;GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>1 THEN RAISE EXCEPTION 'Manager setting update denied';END IF;checks:=checks+1;
 RESET ROLE;
 IF (SELECT name FROM public.ff_branches WHERE id=b) IS DISTINCT FROM 'QA branch' OR (SELECT price FROM public.ff_offers WHERE id=offer) IS DISTINCT FROM 100::numeric OR (SELECT new_status FROM public.ff_order_events WHERE id=ev) IS DISTINCT FROM 'new' THEN RAISE EXCEPTION 'Protected fixture altered';END IF;checks:=checks+1;
 IF checks<>88 THEN RAISE EXCEPTION 'Expected 88 checks, got %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 direct client DML: 88 assertions (84 denied writes, 3 manager writes, 1 fixture integrity check)' result;
ROLLBACK;
