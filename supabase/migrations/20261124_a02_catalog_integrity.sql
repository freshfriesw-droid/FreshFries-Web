-- Match public photo path contract and prevent silently rounded menu prices.
CREATE OR REPLACE FUNCTION public.ff51_catalog_save_item(p_id uuid, p_category text, p_name text, p_price numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                                 DECLARE v_cat uuid;v_item uuid;
                                                 BEGIN
                                                  IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND role='manager' AND active) THEN
                                                    RAISE EXCEPTION 'للمدير فقط' USING ERRCODE='42501'; END IF;
                                                     IF length(btrim(coalesce(p_category,''))) NOT BETWEEN 2 AND 80
                                                      OR length(btrim(coalesce(p_name,''))) NOT BETWEEN 2 AND 120
                                                       OR p_price IS NULL OR p_price<0 OR p_price>1000000 OR p_price::text IN ('NaN','Infinity','-Infinity') OR round(p_price,2)<>p_price THEN
                                                         RAISE EXCEPTION 'اسم القسم والصنف والسعر غير صالحين'; END IF;
                                                          INSERT INTO public.ff_menu_categories(name,active)
                                                           VALUES(btrim(p_category),true)
                                                            ON CONFLICT(name) DO UPDATE SET active=true RETURNING id INTO v_cat;
                                                             IF p_id IS NULL THEN
                                                               INSERT INTO public.ff_menu_items(category_id,name,price,active)
                                                                 VALUES(v_cat,btrim(p_name),p_price,true) RETURNING id INTO v_item;
                                                                  ELSE
                                                                    UPDATE public.ff_menu_items SET category_id=v_cat,name=btrim(p_name),price=p_price,
                                                                       active=true,updated_at=now() WHERE id=p_id RETURNING id INTO v_item;
                                                                         IF v_item IS NULL THEN RAISE EXCEPTION 'الصنف المطلوب غير موجود'; END IF;
                                                                          END IF;
                                                                           RETURN jsonb_build_object('saved',true,'id',v_item);
                                                                           END $function$;

CREATE OR REPLACE FUNCTION public.ff51_offer_save(p_id uuid, p_name text, p_price numeric, p_active boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                                                                 DECLARE v_id uuid;
                                                                                 BEGIN
                                                                                  IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND role='manager' AND active) THEN
                                                                                    RAISE EXCEPTION 'للمدير فقط' USING ERRCODE='42501'; END IF;
                                                                                     IF p_active IS NULL OR length(btrim(coalesce(p_name,''))) NOT BETWEEN 2 AND 120
                                                                                      OR p_price IS NULL OR p_price<0 OR p_price>1000000 OR p_price::text IN ('NaN','Infinity','-Infinity') OR round(p_price,2)<>p_price THEN RAISE EXCEPTION 'اسم العرض والسعر غير صالحين'; END IF;
                                                                                       IF p_id IS NULL THEN
                                                                                         INSERT INTO public.ff_offers(name,price,active) VALUES(btrim(p_name),p_price,p_active)
                                                                                           RETURNING id INTO v_id;
                                                                                            ELSE
                                                                                              UPDATE public.ff_offers SET name=btrim(p_name),price=p_price,active=p_active
                                                                                                WHERE id=p_id RETURNING id INTO v_id;
                                                                                                  IF v_id IS NULL THEN RAISE EXCEPTION 'العرض غير موجود'; END IF;
                                                                                                   END IF;
                                                                                                    RETURN jsonb_build_object('saved',true,'id',v_id);
                                                                                                    END $function$;

CREATE OR REPLACE FUNCTION public.ff53_save_menu_image(p_item uuid, p_path text, p_kind text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                                                              DECLARE v_rows integer;v_prefix text;
                                                                              BEGIN
                                                                               IF auth.uid() IS NULL OR NOT public.ff_is_manager()
                                                                                THEN RAISE EXCEPTION 'للمدير فقط' USING ERRCODE='42501'; END IF;
                                                                                 IF p_item IS NULL OR p_kind IS NULL OR p_kind NOT IN ('item','offer')
                                                                                  THEN RAISE EXCEPTION 'بيانات الصنف غير صحيحة'; END IF;
                                                                                   v_prefix:=CASE WHEN p_kind='offer' THEN 'offer/' ELSE 'menu/' END || p_item::text || '.';
                                                                                    IF p_path IS NULL OR left(p_path,length(v_prefix))<>v_prefix OR
                                                                                        substring(p_path from length(v_prefix)+1) !~* '^(png|jpg|jpeg|webp)$' OR length(p_path)>130
                                                                                         THEN RAISE EXCEPTION 'مسار الصورة غير صحيح'; END IF;
                                                                                          IF NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='ff_menu_media' AND name=p_path)
                                                                                           THEN RAISE EXCEPTION 'ارفع الصورة إلى التخزين قبل اعتمادها'; END IF;
                                                                                            IF p_kind='offer' THEN
                                                                                              UPDATE public.ff_offers SET details=jsonb_set(jsonb_set(coalesce(details,'{}'::jsonb),
                                                                                                  '{image_path}',to_jsonb(p_path)), '{image_version}',to_jsonb(extract(epoch from now())::text)),
                                                                                                      updated_at=now() WHERE id=p_item;
                                                                                                       ELSE
                                                                                                         UPDATE public.ff_menu_items SET extra=jsonb_set(jsonb_set(coalesce(extra,'{}'::jsonb),
                                                                                                             '{image_path}',to_jsonb(p_path)), '{image_version}',to_jsonb(extract(epoch from now())::text)),
                                                                                                                 updated_at=now() WHERE id=p_item;
                                                                                                                  END IF;
                                                                                                                   GET DIAGNOSTICS v_rows=ROW_COUNT;
                                                                                                                    IF v_rows<>1 THEN RAISE EXCEPTION 'الصنف أو العرض غير موجود'; END IF;
                                                                                                                     RETURN jsonb_build_object('success',true,'path',p_path);
                                                                                                                     END $function$;
