-- Catalog tests use real manager and CS identities and rolled-back fixtures.
DO $qa$
DECLARE
 v_manager uuid;v_cs uuid;v_category text:='QA-'||gen_random_uuid()::text;
 v_item uuid;v_offer uuid;v_img_item uuid;v_img_path text;v_before jsonb;v_after jsonb;
 v_catalog jsonb;v_msg text;v_prev text;v_checks integer:=0;v_stmt text;
BEGIN
 SELECT user_id INTO v_manager FROM public.ff_profiles WHERE role='manager' AND active LIMIT 1;
 SELECT user_id INTO v_cs FROM public.ff_profiles WHERE role='customer_service' AND active LIMIT 1;
 SELECT m.id,m.extra->>'image_path',m.extra INTO v_img_item,v_img_path,v_before
 FROM public.ff_menu_items m JOIN storage.objects s ON s.bucket_id='ff_menu_media' AND s.name=m.extra->>'image_path'
 WHERE m.active AND s.name ~* '^menu/[0-9a-f-]{36}[.](png|jpg|jpeg|webp)$' LIMIT 1;
 IF v_manager IS NULL OR v_cs IS NULL OR v_img_item IS NULL THEN RAISE EXCEPTION 'QA role/image fixture unavailable';END IF;
 v_prev:=current_setting('request.jwt.claim.sub',true);
 BEGIN
  PERFORM set_config('request.jwt.claim.sub',v_manager::text,true);
  SET LOCAL ROLE authenticated;
  v_item:=(public.ff51_catalog_save_item(NULL,v_category,'QA item',1500)->>'id')::uuid;
  v_offer:=(public.ff51_offer_save(NULL,'QA offer '||v_category,2000,true)->>'id')::uuid;
  PERFORM public.ff_save_catalog_parser_aliases('item',v_item,NULL,ARRAY['QA alias']);
  PERFORM public.ff_save_catalog_parser_aliases('offer',v_offer,NULL,ARRAY['QA offer alias']);
  PERFORM public.ff51_catalog_save_item(v_item,v_category,'QA item',1600);
  PERFORM public.ff51_offer_save(v_offer,'QA offer '||v_category,2100,true);
  PERFORM public.ff53_save_menu_image(v_img_item,v_img_path,'item');
  FOREACH v_stmt IN ARRAY ARRAY[
   format('select public.ff51_catalog_save_item(NULL,%L,''QA invalid'',1.001)',v_category),
   format('select public.ff51_offer_save(%L::uuid,''QA invalid'',1.001,true)',v_offer),
   format('select public.ff51_offer_save(%L::uuid,''QA invalid'',100,NULL)',v_offer),
   format('select public.ff53_save_menu_image(%L::uuid,%L,NULL)',v_img_item,v_img_path),
   format('select public.ff53_save_menu_image(%L::uuid,%L,''item'')',v_img_item,'menu/'||v_img_item::text||'.invalid.jpg')
  ] LOOP
   v_msg:=NULL;
   BEGIN EXECUTE v_stmt; EXCEPTION WHEN OTHERS THEN v_msg:=SQLERRM;END;
   IF v_msg IS NULL THEN RAISE EXCEPTION 'Invalid catalog input accepted';END IF;
   v_checks:=v_checks+1;
  END LOOP;
  PERFORM set_config('request.jwt.claim.sub',v_cs::text,true);
  v_catalog:=public.ff49_catalog();
  IF NOT v_catalog @> jsonb_build_array(jsonb_build_object('id',v_item,'price',1600,'parser_aliases',jsonb_build_array('QA alias')))
   OR NOT v_catalog @> jsonb_build_array(jsonb_build_object('id',v_offer,'kind','offer','price',2100,'parser_aliases',jsonb_build_array('QA offer alias')))
   OR NOT v_catalog @> jsonb_build_array(jsonb_build_object('id',v_img_item,'image_path',v_img_path))
   THEN RAISE EXCEPTION 'Shared catalog not updated';END IF;
  FOREACH v_stmt IN ARRAY ARRAY[
   format('select public.ff51_catalog_save_item(%L::uuid,%L,''QA unauthorized'',1)',v_item,v_category),
   format('select public.ff51_offer_save(%L::uuid,''QA unauthorized'',1,true)',v_offer),
   format('select public.ff53_save_menu_image(%L::uuid,%L,''item'')',v_img_item,v_img_path),
   format('select public.ff_save_catalog_parser_aliases(''item'',%L::uuid,NULL,NULL)',v_item)
  ] LOOP
   v_msg:=NULL;
   BEGIN EXECUTE v_stmt;EXCEPTION WHEN SQLSTATE '42501' THEN v_msg:=SQLSTATE;END;
   IF v_msg IS DISTINCT FROM '42501' THEN RAISE EXCEPTION 'Unauthorized catalog mutation';END IF;
   v_checks:=v_checks+1;
  END LOOP;
  PERFORM set_config('request.jwt.claim.sub',v_manager::text,true);
  PERFORM public.ff51_catalog_toggle(v_item,false);
  PERFORM public.ff51_offer_save(v_offer,'QA offer '||v_category,2100,false);
  v_catalog:=public.ff49_catalog();
  IF v_catalog @> jsonb_build_array(jsonb_build_object('id',v_item)) OR v_catalog @> jsonb_build_array(jsonb_build_object('id',v_offer))
   THEN RAISE EXCEPTION 'Inactive item or offer visible';END IF;
  RESET ROLE;
  RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 SELECT extra INTO v_after FROM public.ff_menu_items WHERE id=v_img_item;
 IF v_checks<>9 OR v_after IS DISTINCT FROM v_before
  OR EXISTS(SELECT 1 FROM public.ff_menu_items WHERE id=v_item)
  OR EXISTS(SELECT 1 FROM public.ff_offers WHERE id=v_offer)
  OR EXISTS(SELECT 1 FROM public.ff_menu_categories WHERE name=v_category)
 THEN RAISE EXCEPTION 'Catalog rollback failed';END IF;
 PERFORM set_config('request.jwt.claim.sub',coalesce(v_prev,''),true);
END $qa$;
SELECT 'PASS: manager item/offer prices, aliases, existing image link, CS shared read, mutation denied, inactive hidden, rollback' AS result;
