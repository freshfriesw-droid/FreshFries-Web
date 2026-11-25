DO $qa$
DECLARE b1 uuid:=gen_random_uuid();b2 uuid:=gen_random_uuid();m uuid:=gen_random_uuid();s uuid:=gen_random_uuid();c uuid:=gen_random_uuid();c2 uuid:=gen_random_uuid();d1 uuid:=gen_random_uuid();d2 uuid:=gen_random_uuid();o1 uuid:=gen_random_uuid();o2 uuid:=gen_random_uuid();o3 uuid:=gen_random_uuid();o4 uuid:=gen_random_uuid();ad uuid:=gen_random_uuid();sett uuid:=gen_random_uuid();draft uuid:=gen_random_uuid();r jsonb;denied boolean;checks int:=0;dy date:=public.ff_business_date(now())-5; ts timestamptz; n bigint:=-1000000000000-floor(random()*1e12)::bigint; old_count int;
BEGIN
 BEGIN
 ts:=(dy+time '23:30') AT TIME ZONE 'Asia/Aden';
 INSERT INTO public.ff_branches(id,code,name) VALUES(b1,'qa-a10-'||b1,'A10 QA one'),(b2,'qa-a10-'||b2,'A10 QA two');
 INSERT INTO auth.users(id) VALUES(m),(s),(c),(c2);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'A10 QA manager','manager',true),(s,'A10 QA supervisor','supervisor',true),(c,'A10 QA CS','customer_service',true),(c2,'A10 QA CS','customer_service',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(s,b1),(c,b1),(c2,b1);
 INSERT INTO public.ff_drivers(id,name,branch_id) VALUES(d1,'A10 QA same driver name',b1),(d2,'A10 QA same driver name',b2);
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,area_snapshot,driver_id,status,created_by,created_at,delivered_at,items_total,delivery_fee,total) VALUES
 (o1,n,b1,'000'||replace(gen_random_uuid()::text,'-',''),'QA area A',d1,'delivered',c,ts,ts+interval '20 minutes',1000,300,1300),
 (o2,n-1,b1,'000'||replace(gen_random_uuid()::text,'-',''),'QA area B',d1,'delivered',c2,ts+interval '70 minutes',ts+interval '150 minutes',2000,500,2500),
 (o3,n-2,b1,'000'||replace(gen_random_uuid()::text,'-',''),'QA area A',d1,'cancelled',c,ts+interval '10 minutes',NULL,500,300,800),
 (o4,n-3,b2,'000'||replace(gen_random_uuid()::text,'-',''),'QA area B',d2,'delivered',c2,ts,ts+interval '15 minutes',9000,700,9700);
 INSERT INTO public.ff38_delivery_tasks(order_id,driver_id,delivered_at) VALUES(o1,d1,ts+interval '20 minutes'),(o2,d1,ts+interval '150 minutes'),(o4,d2,ts+interval '15 minutes');
 INSERT INTO public.ff_offers(name,price,active) VALUES('QA burger',1000,true);
 INSERT INTO public.ff_order_items(order_id,item_name,quantity,unit_price,line_total) VALUES(o1,'QA chicken',1,1000,1000),(o2,'QA burger',2,1000,2000),(o3,'QA chicken',1,500,500),(o4,'QA hidden',1,9000,9000);
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 INSERT INTO public.ff38_order_additions(id,order_id,status,amount,requested_by,created_at) VALUES(ad,o1,'pending',0,c,ts);
 INSERT INTO public.ff38_order_addition_items(addition_id,item_name,quantity,unit_price) VALUES(ad,'QA addon',1,200);
 INSERT INTO public.ff52_addition_pos(addition_id,invoice_ref,recorded_by,recorded_at) VALUES(ad,'QA-ADD-1',m,ts+interval '3 minutes');
 UPDATE public.ff38_order_additions SET status='invoiced',amount=200,invoiced_by=m,invoiced_at=ts+interval '3 minutes' WHERE id=ad;
 INSERT INTO public.ff42_driver_settlements(id,settlement_date,branch_id,driver_id,delivered_orders,delivered_order_value,delivered_delivery_fees,invoiced_additions,cash_due,cash_received,notes,status,created_by,updated_by,closed_by,closed_at) VALUES(sett,dy,b1,d1,1,1500,300,200,1500,1400,'QA verified difference','closed',m,m,m,ts);
 INSERT INTO public.ff42_driver_settlements(id,settlement_date,branch_id,driver_id,delivered_orders,delivered_order_value,delivered_delivery_fees,cash_due,cash_received,notes,status,created_by,updated_by) VALUES(draft,dy+1,b1,d1,1,2500,500,2500,2200,'QA draft','draft',m,m);
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff_a10_reporting_center(dy,dy,b1,NULL,NULL,NULL,NULL,NULL);
 IF (r#>>'{totals,orders}')::int<>3 OR (r#>>'{totals,delivered}')::int<>2 OR (r#>>'{totals,cancelled}')::int<>1 THEN RAISE EXCEPTION 'Cohort counts %',r->'totals';END IF;checks:=checks+1;
 IF (r#>>'{totals,item_sales}')::numeric<>3200 OR (r#>>'{totals,delivery_fees}')::numeric<>800 OR (r#>>'{totals,net}')::numeric<>4000 THEN RAISE EXCEPTION 'Amount reconciliation %',r->'totals';END IF;checks:=checks+1;
 IF (r#>>'{totals,late_completed}')::int<>1 OR (r#>>'{totals,fastest_minutes}')::numeric<>20 OR (r#>>'{totals,p90_delivery_minutes}')::numeric<>74 THEN RAISE EXCEPTION 'Time reconciliation %',r->'totals';END IF;checks:=checks+1;
 IF (r#>>'{comparison,today,net}')::numeric<>4000 THEN RAISE EXCEPTION 'Comparison addition mismatch';END IF;checks:=checks+1;
 IF (r#>>'{finance_evidence,confirmed_received}')::numeric<>1400 OR (r#>>'{finance_evidence,confirmed_difference}')::numeric<>100 OR r#>>'{finance_evidence,fee_collection_confirmed}' IS NOT NULL OR (r#>>'{finance_evidence,fees_need_review}')::int<>1 THEN RAISE EXCEPTION 'Unconfirmed fee inferred';END IF;checks:=checks+1;
 PERFORM public.ff_a10_confirm_fee(sett,250,'QA evidence reference');
 r:=public.ff_a10_reporting_center(dy,dy+1,b1,d1,NULL,NULL,NULL,NULL);
 IF (r#>>'{finance_evidence,confirmed_received}')::numeric<>1400 OR (r#>>'{finance_evidence,draft_received}')::numeric<>2200 OR (r#>>'{finance_evidence,fee_collection_confirmed}')::numeric<>250 THEN RAISE EXCEPTION 'Draft vs closed settlement %',r->'finance_evidence';END IF;checks:=checks+1;
 PERFORM public.ff_a10_confirm_fee(sett,275,'QA corrected reference');
 IF jsonb_array_length(public.ff_a10_fee_history(sett))<>2 THEN RAISE EXCEPTION 'Fee evidence history';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM public.ff_a10_confirm_fee(draft,100,'QA draft evidence');EXCEPTION WHEN OTHERS THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Draft fee confirmation';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM public.ff_a10_confirm_fee(sett,301,'QA excess evidence');EXCEPTION WHEN OTHERS THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Excess fee confirmation';END IF;checks:=checks+1;
 r:=public.ff_a10_reporting_center(dy,dy,b1,NULL,c,'QA area A','QA addon','delivered');
 IF (r#>>'{totals,orders}')::int<>1 OR (r#>>'{totals,net}')::numeric<>1500 OR (r#>>'{comparison,today,net}')::numeric<>1500 OR r#>>'{finance_evidence,confirmed_received}' IS NOT NULL OR jsonb_array_length(r->'settlements')<>0 THEN RAISE EXCEPTION 'Filtered cohort or settlement attribution';END IF;checks:=checks+1;
 r:=public.ff_a10_reporting_center(dy,dy,b1,NULL,NULL,NULL,NULL,'cancelled');
 IF (r#>>'{totals,orders}')::int<>1 OR (r#>>'{totals,net}')::numeric<>0 THEN RAISE EXCEPTION 'Cancellation filter';END IF;checks:=checks+1;
 r:=public.ff_a10_reporting_center(dy,dy,b1,NULL,NULL,NULL,NULL,NULL);
 IF (r#>>'{offer_performance,0,offer_name}') IS DISTINCT FROM 'QA burger' OR (r#>>'{offer_performance,0,quantity}')::numeric<>2 OR (r#>>'{offer_performance,0,registered_value}')::numeric<>2000 THEN RAISE EXCEPTION 'Offer attribution %',r->'offer_performance';END IF;checks:=checks+1;
 IF jsonb_array_length(r->'service_staff')<>2 THEN RAISE EXCEPTION 'Same staff names collapsed';END IF;checks:=checks+1;
 IF NOT EXISTS(SELECT FROM jsonb_array_elements_text(r#>'{filter_options,items}') z WHERE z='QA addon') OR EXISTS(SELECT FROM jsonb_array_elements_text(r#>'{filter_options,items}') z WHERE z='QA hidden') THEN RAISE EXCEPTION 'Filter options scope';END IF;checks:=checks+1;
 PERFORM public.ff_a10_report_grant(s,'finance',false);PERFORM public.ff_a10_report_grant(s,'ratings',false);
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',s::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff_a10_reporting_center(dy,dy,b1,NULL,NULL,NULL,NULL,NULL);
 IF r->'available_sections' ? 'finance' OR r->'available_sections' ? 'ratings' OR r ? 'finance_evidence' OR r ? 'low_ratings' OR r->'totals' ? 'net' OR r->'additions' ? 'invoiced_value' OR EXISTS(SELECT FROM jsonb_array_elements(r->'items') z WHERE z ? 'revenue') THEN RAISE EXCEPTION 'Revoked sections data leak';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM public.ff_a10_reporting_center(dy,dy,b2,NULL,NULL,NULL,NULL,NULL);EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Foreign branch';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM public.ff_a10_report_grant(s,'finance',true);EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Self grant';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM public.ff_a10_confirm_fee(sett,50,'QA unauthorized');EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'Unauthorized fee';END IF;checks:=checks+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',c::text,true);SET LOCAL ROLE authenticated;
 r:=public.ff_a10_reporting_center(dy,dy,b1,NULL,NULL,NULL,NULL,NULL);
 IF (r#>>'{totals,orders}')::int<>2 OR r->'totals' ? 'net' OR r ? 'settlements' OR r ? 'customers' AND jsonb_array_length(r->'customers')>0 OR r ? 'cases' THEN RAISE EXCEPTION 'CS cohort privacy';END IF;checks:=checks+1;
 denied:=false;BEGIN PERFORM public.ff_a10_reporting_center(dy,dy,b1,NULL,c2,NULL,NULL,NULL);EXCEPTION WHEN insufficient_privilege THEN denied:=true;END;IF NOT denied THEN RAISE EXCEPTION 'CS other staff filter';END IF;checks:=checks+1;
 RESET ROLE;
 IF has_function_privilege('authenticated','ff_private.a10_report_core(date,date,uuid,uuid,uuid,text,text,text)','EXECUTE') OR has_table_privilege('authenticated','ff_private.a10_fee_evidence','SELECT') OR has_function_privilege('anon','public.ff_a10_reporting_center(date,date,uuid,uuid,uuid,text,text,text)','EXECUTE') THEN RAISE EXCEPTION 'Private source exposed';END IF;checks:=checks+1;
 RAISE EXCEPTION 'QA rollback' USING ERRCODE='ZQA10';
 EXCEPTION WHEN SQLSTATE 'ZQA10' THEN NULL;END;
 IF checks<>21 OR EXISTS(SELECT FROM public.ff_branches WHERE id IN(b1,b2)) THEN RAISE EXCEPTION 'Incomplete QA rollback %',checks;END IF;
END $qa$;
SELECT 'PASS A10: 21 source reconciliation, midnight, filters, finance evidence, section and branch scope assertions' result;