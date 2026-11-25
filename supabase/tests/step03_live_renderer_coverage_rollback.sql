BEGIN;
DO $qa$
DECLARE spec jsonb:='{"driver_addition_warning":{"screen":"driver","keys":["driver_addition_notice","driver_addition_invoice_notice"],"styleOnly":true},"cashier_customer_edit":{"screen":"cashier","keys":["cashier_customer_edit"],"styleOnly":true},"assembly_order_components":{"screen":"assembly","keys":["assembly_stage_action","assembly_stage_state","assembly_order_age","assembly_order_note"],"styleOnly":true},"burger_order_components":{"screen":"burger_kitchen","keys":["burger_stage_action","burger_stage_state","burger_required_note","burger_confirm_note"],"styleOnly":true},"cashier_burger_components":{"screen":"cashier","keys":["cashier_burger_skip","cashier_burger_state","cashier_burger_timer"],"styleOnly":true},"assembly_burger_components":{"screen":"assembly","keys":["assembly_burger_skip","assembly_burger_state","assembly_burger_timer"],"styleOnly":true}}'; g record; rows jsonb; patch jsonb; item_key text; invalid jsonb;
BEGIN
 FOR g IN SELECT * FROM jsonb_each(spec) LOOP
 SELECT jsonb_agg(jsonb_build_object('key',a.k,'shape','round','size','normal','align','center','shadow','soft') ORDER BY a.ord) INTO rows FROM jsonb_array_elements_text(g.value->'keys') WITH ORDINALITY a(k,ord);
 patch:=jsonb_build_object(g.key,rows);
 IF NOT ff_private.a07_valid_elements(patch,g.value->>'screen') THEN RAISE EXCEPTION 'valid controls %',g.key;END IF;
 IF ff_private.a07_valid_elements(patch,'finance') OR ff_private.a07_valid_elements(jsonb_build_object(g.key,jsonb_set(rows,'{0,key}','"unknown_unsafe"')),g.value->>'screen') OR ff_private.a07_valid_elements(jsonb_build_object(g.key,jsonb_set(rows,'{0,hidden}','true')),g.value->>'screen') THEN RAISE EXCEPTION 'scope or protected identity %',g.key;END IF;
 FOR item_key IN SELECT jsonb_array_elements_text(g.value->'keys') LOOP
  SELECT jsonb_agg(CASE WHEN a.x->>'key'=item_key THEN a.x||'{"tone":"dark"}'::jsonb ELSE a.x END ORDER BY a.ord) INTO invalid FROM jsonb_array_elements(rows) WITH ORDINALITY a(x,ord);
  IF ff_private.a07_valid_elements(jsonb_build_object(g.key,invalid),g.value->>'screen') THEN RAISE EXCEPTION 'semantic tone %',item_key;END IF;
 END LOOP;
 IF ff_private.a09_merge_elements(g.value->>'screen',patch,patch,jsonb_build_object(g.key,jsonb_set(rows,'{0,align}','"end"')),ARRAY['layout','buttons','colors']) IS NOT NULL THEN RAISE EXCEPTION 'delegation bypass %',g.key;END IF;
 END LOOP;
END $qa$;
SELECT 'PASS STEP03 17 rendered operational component keys; protected warning and semantic tone' AS result;
ROLLBACK;