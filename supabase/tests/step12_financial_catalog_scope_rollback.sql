BEGIN;
DO $qa$
DECLARE b uuid:=gen_random_uuid(); m uuid:=gen_random_uuid(); d uuid:=gen_random_uuid(); cat uuid:=gen_random_uuid(); item uuid; settlement uuid; actor uuid; role_name text; roles text[]:=ARRAY['cashier','driver','assembly','supervisor','customer_service','burger_kitchen','nonstaff','disabled_manager']; callers uuid[]:=ARRAY[]::uuid[]; call_sql text; checks int:=0; r jsonb; calls text[]; day date:=public.ff_business_date(now())-1; o uuid:=gen_random_uuid(); ts timestamptz; n bigint:=-1000000000000-floor(random()*1e12)::bigint;
BEGIN
 ts:=(day+time '12:00') AT TIME ZONE 'Asia/Aden';
 INSERT INTO auth.users(id) VALUES(m);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 financial manager','manager',true);
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-step12-finance-'||b,'QA STEP12 finance');
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d,'QA STEP12 finance driver',b);
 INSERT INTO public.ff_menu_categories(id,name,active) VALUES(cat,'QA STEP12 finance '||cat,true);
 INSERT INTO public.ff_menu_items(category_id,name,price,active) VALUES(cat,'QA STEP12 finance item',100,true) RETURNING id INTO item;
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,area_snapshot,driver_id,status,created_by,created_at,delivered_at,items_total,delivery_fee,total) VALUES(o,n,b,'000'||replace(gen_random_uuid()::text,'-',''),'QA synthetic area',d,'delivered',m,ts,ts+interval '20 minutes',100,0,100);
 INSERT INTO public.ff38_delivery_tasks(order_id,driver_id,delivered_at) VALUES(o,d,ts+interval '20 minutes');
 INSERT INTO public.ff_order_items(order_id,item_name,quantity,unit_price,line_total) VALUES(o,'QA synthetic item',1,100,100);
 FOREACH role_name IN ARRAY roles LOOP
  actor:=gen_random_uuid(); callers:=array_append(callers,actor); INSERT INTO auth.users(id) VALUES(actor);
  IF role_name<>'nonstaff' THEN INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(actor,'QA STEP12 finance '||role_name,CASE WHEN role_name='disabled_manager' THEN 'manager' ELSE role_name END,role_name<>'disabled_manager'); END IF;
  IF role_name IN ('cashier','driver','assembly','supervisor','burger_kitchen') THEN INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(actor,b); END IF;
 END LOOP;
 SET LOCAL ROLE authenticated;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 r:=public.ff42_settlement_save(day,b,d,100,100,'QA synthetic');settlement:=(r->>'settlement_id')::uuid;
 IF settlement IS NULL OR r->>'saved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Synthetic settlement fixture failed';END IF;
 calls:=ARRAY[
 format('SELECT public.ff42_settlement_save(%L::date,%L::uuid,%L::uuid,100,100,%L)',day,b,d,'QA denied'),
 format('SELECT public.ff42_settlement_close(%L::uuid,%L)',settlement,'QA denied'),
 format('SELECT public.ff42_settlement_detail(%L::uuid)',settlement),
 format('SELECT public.ff76_report_approval_save(%L::date,%L::uuid,%L,%L)',day,b,'QA approval','QA manager'),
 format('SELECT public.ff_luxe_settlement_period(%L::date,%L::date,%L::uuid)',day,day,b),
 format('SELECT public.ff_a02_catalog_presentation(%L,%L::uuid,10,%L)','item',item,'standard'),
 format('SELECT public.ff_save_catalog_parser_aliases(%L,%L::uuid,NULL::text[],ARRAY[%L])','item',item,'QA alias'),
 format('SELECT public.ff52_admin_route_save(%L::uuid,%L::uuid,ARRAY[%L],%L::time,%L::time,true)',b,d,'QA zone','10:00','11:00')];
 FOREACH actor IN ARRAY callers LOOP
  PERFORM set_config('request.jwt.claim.sub',actor::text,true);
  FOREACH call_sql IN ARRAY calls LOOP
   BEGIN EXECUTE call_sql; RAISE EXCEPTION 'Unauthorized financial/catalog call returned: %',call_sql USING ERRCODE='ZQA12';
   EXCEPTION WHEN SQLSTATE '42501' THEN checks:=checks+1; END;
  END LOOP;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 r:=public.ff42_settlement_detail(settlement);IF jsonb_typeof(r) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Manager detail failed';END IF;checks:=checks+1;
 r:=public.ff42_settlement_close(settlement,'QA closing');IF r->>'closed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Manager close failed';END IF;checks:=checks+1;
 r:=public.ff76_report_approval_save(day,b,'QA approval','QA manager');IF r->>'approved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Manager approval failed';END IF;checks:=checks+1;
 r:=public.ff_luxe_settlement_period(day,day,b);IF (r#>>'{totals,settlements}')::int IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'Manager period report mismatch';END IF;checks:=checks+1;
 r:=public.ff_a02_catalog_presentation('item',item,10,'standard');IF r->>'saved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Manager presentation failed';END IF;checks:=checks+1;
 PERFORM public.ff_save_catalog_parser_aliases('item',item,NULL::text[],ARRAY['QA alias']);checks:=checks+1;
 r:=public.ff52_admin_route_save(b,d,ARRAY['QA zone'],'10:00','11:00',true);IF r->>'saved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Manager route failed';END IF;checks:=checks+1;
 RESET ROLE;
 IF NOT EXISTS(SELECT FROM public.ff42_driver_settlements WHERE id=settlement AND status='closed' AND closed_by=m) OR NOT EXISTS(SELECT FROM public.ff_menu_items WHERE id=item AND parser_aliases=ARRAY['QA alias'] AND sort_order=10) THEN RAISE EXCEPTION 'Fixture state mismatch';END IF;checks:=checks+1;
 IF checks<>72 THEN RAISE EXCEPTION 'Expected 72 assertions, got %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 financial/catalog/route RPC: 64 denials in eight contexts and 8 authorized/state assertions' result;
ROLLBACK;
