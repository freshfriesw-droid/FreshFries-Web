-- A02 UI-08/09/10: reuse existing authorized records, stable IDs and metadata.
CREATE OR REPLACE FUNCTION public.ff28_customer(p_order uuid DEFAULT NULL::uuid, p_stars integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_phone text; v_number text; v_order uuid; v_result jsonb;
BEGIN
 IF auth.uid() IS NULL OR EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid()) THEN
  RAISE EXCEPTION 'بوابة العميل متاحة للعملاء المخولين فقط' USING ERRCODE='42501';
 END IF;
 SELECT phone INTO v_phone FROM auth.users
 WHERE id=auth.uid() AND phone_confirmed_at IS NOT NULL;
 v_number:=pg_catalog.regexp_replace(coalesce(v_phone,''),'[^0-9]','','g');
 IF v_number !~ '^9677[0-9]{8}$' THEN RAISE EXCEPTION 'يرجى تأكيد ملكية رقم هاتف يمني صالح' USING ERRCODE='42501'; END IF;
 v_number:=pg_catalog.right(v_number,9);
 IF p_order IS NOT NULL OR p_stars IS NOT NULL THEN
   IF p_order IS NULL OR p_stars IS NULL OR p_stars NOT BETWEEN 1 AND 5 THEN
    RAISE EXCEPTION 'معرف الطلب والتقييم 1–5 مطلوبان' USING ERRCODE='22023';
   END IF;
   UPDATE public.ff_orders o SET rating=p_stars,updated_at=now()
     WHERE o.id=p_order AND o.status='delivered' AND o.rating IS NULL
       AND pg_catalog.regexp_replace(pg_catalog.translate(coalesce(o.phone_snapshot,''),'٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','01234567890123456789'),'[^0-9]','','g') IN
           (v_number,'967'||v_number,'00967'||v_number)
   RETURNING o.id INTO v_order;
   IF v_order IS NULL THEN RAISE EXCEPTION 'الطلب غير متاح للتقييم أو تم تقييمه مسبقًا' USING ERRCODE='42501'; END IF;
 END IF;
 SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
  'id',r.id,'order_number',r.order_number,'status',r.status,'total',r.total,
  'phase',r.phase,'cashier_stage',r.cashier_stage,'rating',r.rating
 ) ORDER BY r.created_at DESC),'[]'::jsonb)
 INTO v_result FROM (
   SELECT o.id,o.order_number,o.status,o.total+coalesce((SELECT sum(a.amount) FROM public.ff38_order_additions a WHERE a.order_id=o.id AND a.status='invoiced'),0) AS total,o.rating,o.created_at,
    t.phase,t.cashier_stage
   FROM public.ff_orders o
   LEFT JOIN LATERAL (
      SELECT dt.phase,dt.cashier_stage FROM public.ff38_delivery_tasks dt
      WHERE dt.order_id=o.id ORDER BY dt.updated_at DESC LIMIT 1
   ) t ON true
   WHERE pg_catalog.regexp_replace(pg_catalog.translate(coalesce(o.phone_snapshot,''),'٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','01234567890123456789'),'[^0-9]','','g') IN
       (v_number,'967'||v_number,'00967'||v_number)
   ORDER BY o.created_at DESC LIMIT 100
 ) r;
 RETURN v_result;
END;
$function$;
CREATE OR REPLACE FUNCTION public.ff49_catalog()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active=true)
    THEN RAISE EXCEPTION 'غير مصرح' USING ERRCODE='42501'; END IF;
      RETURN (
          COALESCE((SELECT jsonb_agg(jsonb_build_object(
                'id',m.id,'name',m.name,'price',m.price,'category',c.name,
                      'kind','item','type','item','parser_aliases',m.parser_aliases,'image_path',m.extra->>'image_path',
                            'image_version',m.extra->>'image_version','card_style',coalesce(m.extra->>'card_style','standard'),'sort_order',m.sort_order)
                                  ORDER BY c.sort_order,m.sort_order,m.name)
                                       FROM public.ff_menu_items m JOIN public.ff_menu_categories c ON c.id=m.category_id
                                            WHERE m.active AND c.active),'[]'::jsonb)
                                                ||
                                                    COALESCE((SELECT jsonb_agg(jsonb_build_object(
                                                          'id',o.id,'name',o.name,'price',o.price,'category','العروض',
                                                                'kind','offer','type','offer','parser_aliases',o.parser_aliases,'image_path',o.details->>'image_path',
                                                                      'image_version',o.details->>'image_version','card_style',coalesce(o.details->>'card_style','standard'),'sort_order',CASE WHEN o.details->>'sort_order' ~ '^[0-9]{1,5}
                                                                            FROM public.ff_offers o WHERE o.active),'[]'::jsonb)
                                                                              );
                                                                              END $function$
 THEN (o.details->>'sort_order')::integer ELSE 0 END) ORDER BY CASE WHEN o.details->>'sort_order' ~ '^[0-9]{1,5}
                                                                            FROM public.ff_offers o WHERE o.active),'[]'::jsonb)
                                                                              );
                                                                              END $function$
 THEN (o.details->>'sort_order')::integer ELSE 0 END,o.name)
                                                                            FROM public.ff_offers o WHERE o.active),'[]'::jsonb)
                                                                              );
                                                                              END $function$;
CREATE OR REPLACE FUNCTION public.ff49_create_reservation(p_branch uuid, p_customer_name text, p_phone text, p_pickup timestamp with time zone, p_items jsonb, p_notes text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                                                                     DECLARE v_id uuid; v_count int;
                                                                                     BEGIN
                                                                                      IF NOT public.ff49_can_work_branch(p_branch,ARRAY['manager','customer_service'])
                                                                                       OR NOT public.ff38_permission_allowed(auth.uid(),'create_order') THEN
                                                                                         RAISE EXCEPTION 'غير مصرح بإنشاء حجز' USING ERRCODE='42501'; END IF;
                                                                                          IF NOT EXISTS(SELECT 1 FROM public.ff_branches WHERE id=p_branch AND active) THEN
  RAISE EXCEPTION 'الفرع غير صحيح' USING ERRCODE='22023';
 END IF;
 IF jsonb_typeof(p_items) IS DISTINCT FROM 'array' THEN
  RAISE EXCEPTION 'راجع اسم العميل والهاتف والموعد والأصناف' USING ERRCODE='22023';
 END IF;
 IF (p_pickup IS NOT NULL AND p_pickup<=now()-interval '5 minutes')
                                                                                           OR length(btrim(coalesce(p_customer_name,''))) NOT BETWEEN 2 AND 100
                                                                                            OR length(btrim(coalesce(p_phone,''))) NOT BETWEEN 5 AND 40
                                                                                             OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 50 THEN
                                                                                               RAISE EXCEPTION 'راجع اسم العميل والهاتف والموعد والأصناف' USING ERRCODE='22023'; END IF;
                                                                                                SELECT count(*)::int INTO v_count FROM jsonb_to_recordset(p_items) AS x(name text,qty numeric,price numeric)
                                                                                                 WHERE length(btrim(coalesce(name,'')))>0 AND qty>0 AND price>=0
 AND qty::text NOT IN ('NaN','Infinity','-Infinity') AND price::text NOT IN ('NaN','Infinity','-Infinity');
                                                                                                  IF v_count<>jsonb_array_length(p_items) OR EXISTS(SELECT 1 FROM jsonb_to_recordset(p_items) AS x(name text,qty numeric,price numeric) WHERE qty NOT BETWEEN 1 AND 100 OR qty<>trunc(qty) OR price<>round(price,2) OR price>=1000000000000) OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_items) x WHERE jsonb_typeof(x->'qty') IS DISTINCT FROM 'number' OR jsonb_typeof(x->'price') IS DISTINCT FROM 'number' OR (x ? 'item_notes' AND jsonb_typeof(x->'item_notes') NOT IN ('string','null'))) THEN RAISE EXCEPTION 'أصناف الحجز غير صحيحة' USING ERRCODE='22023'; END IF;
                                                                                                   INSERT INTO public.ff49_reservations(branch_id,customer_name,customer_phone,pickup_at,items,notes,created_by,pickup_unspecified)
                                                                                                    VALUES(p_branch,btrim(p_customer_name),btrim(p_phone),coalesce(p_pickup,now()),p_items,left(coalesce(p_notes,''),2000),auth.uid(),p_pickup IS NULL)
                                                                                                     RETURNING id INTO v_id;
                                                                                                      INSERT INTO public.ff49_reservation_events(reservation_id,new_status,actor_id,note)
                                                                                                       VALUES(v_id,'new',auth.uid(),'تم إنشاء الحجز');
                                                                                                        RETURN jsonb_build_object('reservation_id',v_id,'status','new');
                                                                                                        END $function$;
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
                                                                       updated_at=now() WHERE id=p_id RETURNING id INTO v_item;
                                                                         IF v_item IS NULL THEN RAISE EXCEPTION 'الصنف المطلوب غير موجود'; END IF;
                                                                          END IF;
                                                                           RETURN jsonb_build_object('saved',true,'id',v_item);
                                                                           END $function$;
CREATE OR REPLACE FUNCTION public.ff51_customer_directory(p_query text DEFAULT ''::text, p_limit integer DEFAULT 60)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_role text;v_query text:=btrim(coalesce(p_query,''));v_key text:=ff_private.customer_phone_key(p_query);
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role IS NULL OR v_role NOT IN ('manager','customer_service') THEN
  RAISE EXCEPTION 'غير مصرح' USING ERRCODE='42501';END IF;
 RETURN coalesce((
  WITH history AS (
   SELECT o.id,ff_private.customer_phone_key(o.phone_snapshot) phone_key,o.phone_snapshot,
    o.area_snapshot,o.created_at,d.customer_name,d.full_address
   FROM public.ff_orders o LEFT JOIN public.ff49_order_details d ON d.order_id=o.id
   WHERE o.order_type='delivery' AND length(btrim(coalesce(o.phone_snapshot,'')))>=5
  ), latest AS (
   SELECT DISTINCT ON (phone_key) * FROM history ORDER BY phone_key,created_at DESC,id DESC
  ), summary AS (
   SELECT phone_key,count(*)::int orders_count,min(created_at) first_order_at
   FROM history GROUP BY phone_key
  ), matched AS (
   SELECT l.*,s.orders_count,s.first_order_at
   FROM latest l JOIN summary s USING(phone_key)
   WHERE v_query='' OR l.phone_key ILIKE '%'||v_key||'%'
    OR EXISTS(SELECT 1 FROM history h WHERE h.phone_key=l.phone_key
      AND (h.phone_snapshot ILIKE '%'||v_query||'%' OR coalesce(h.customer_name,'') ILIKE '%'||v_query||'%' OR coalesce(h.area_snapshot,'') ILIKE '%'||v_query||'%'))
   ORDER BY l.created_at DESC,l.id DESC LIMIT greatest(1,least(coalesce(p_limit,60),150))
  )
  SELECT jsonb_agg(jsonb_build_object(
    'phone',x.phone_key,'name',coalesce(x.customer_name,''),'address',coalesce(x.full_address,x.area_snapshot),
    'area',x.area_snapshot,'last_order_at',x.created_at,'first_order_at',x.first_order_at,'orders_count',x.orders_count,
    'notes_count',(SELECT count(*)::int FROM public.ff51_customer_notes n
       WHERE ff_private.customer_phone_key(n.phone)=x.phone_key)) ORDER BY x.created_at DESC)
  FROM matched x
 ),'[]'::jsonb);
END $function$;
CREATE OR REPLACE FUNCTION public.ff51_manager_catalog()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
                         BEGIN
                          IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND role='manager' AND active) THEN
                            RAISE EXCEPTION 'المنيو والعروض للمدير العام فقط' USING ERRCODE='42501'; END IF;
                             RETURN jsonb_build_object(
                               'categories',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.sort_order,x.name),'[]'::jsonb)
                                   FROM (SELECT id,name,active,sort_order FROM public.ff_menu_categories) x),
                                     'items',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.sort_order,x.name),'[]'::jsonb)
                                         FROM (SELECT id,category_id,name,price,active,sort_order,parser_aliases,extra FROM public.ff_menu_items) x),
                                           'offers',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.name),'[]'::jsonb)
                                               FROM (SELECT id,name,price,active,details,parser_aliases FROM public.ff_offers) x)
                                                );
                                                END $function$;
CREATE OR REPLACE FUNCTION public.ff_a02_customer_history(p_phone text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $$
DECLARE k text:=ff_private.customer_phone_key(p_phone);
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role IN ('manager','customer_service')) THEN
  RAISE EXCEPTION 'غير مصرح' USING ERRCODE='42501';END IF;
 IF length(k) NOT BETWEEN 5 AND 40 THEN RAISE EXCEPTION 'رقم غير صالح' USING ERRCODE='22023';END IF;
 RETURN jsonb_build_object(
 'orders',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC,x.id DESC),'[]'::jsonb) FROM
 (SELECT o.id,o.order_number,o.branch_id,o.status,o.created_at,o.area_snapshot AS area,
 coalesce(d.full_address,o.area_snapshot) AS address,o.rating,
 o.total+coalesce((SELECT sum(a.amount) FROM public.ff38_order_additions a WHERE a.order_id=o.id AND a.status='invoiced'),0) total,
 (SELECT count(*) FROM public.ff_order_customer_edits e WHERE e.order_id=o.id) edit_count
 FROM public.ff_orders o LEFT JOIN public.ff49_order_details d ON d.order_id=o.id
 WHERE o.order_type='delivery' AND ff_private.customer_phone_key(o.phone_snapshot)=k
 ORDER BY o.created_at DESC,o.id DESC LIMIT 100) x),
 'complaints',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC),'[]'::jsonb) FROM
 (SELECT c.id,c.order_id,c.subject,c.status,c.created_at FROM public.ff41_cases c
 WHERE c.kind='customer_complaint' AND (ff_private.customer_phone_key(c.customer_phone)=k OR
 (coalesce(btrim(c.customer_phone),'')='' AND EXISTS(SELECT 1 FROM public.ff_orders o WHERE o.id=c.order_id AND ff_private.customer_phone_key(o.phone_snapshot)=k)))
 ORDER BY c.created_at DESC LIMIT 50) x));
END $$;
REVOKE ALL ON FUNCTION public.ff_a02_customer_history(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a02_customer_history(text) TO authenticated;
CREATE OR REPLACE FUNCTION public.ff_a02_catalog_presentation(p_kind text,p_id uuid,p_sort integer,p_card_style text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND active AND role='manager') THEN RAISE EXCEPTION 'للمدير فقط' USING ERRCODE='42501'; END IF;
 IF p_kind IS NULL OR p_kind NOT IN ('item','offer') OR p_sort IS NULL OR p_sort NOT BETWEEN 0 AND 99999
 OR p_card_style IS NULL OR p_card_style NOT IN ('standard','compact','large') THEN RAISE EXCEPTION 'إعدادات البطاقة غير صالحة' USING ERRCODE='22023';END IF;
 IF p_kind='item' THEN UPDATE public.ff_menu_items SET sort_order=p_sort,extra=coalesce(extra,'{}'::jsonb)||jsonb_build_object('card_style',p_card_style),updated_at=now() WHERE id=p_id;
 ELSE UPDATE public.ff_offers SET details=coalesce(details,'{}'::jsonb)||jsonb_build_object('sort_order',p_sort,'card_style',p_card_style),updated_at=now() WHERE id=p_id; END IF;
 IF NOT FOUND THEN RAISE EXCEPTION 'الصنف غير موجود' USING ERRCODE='22023';END IF;
 RETURN jsonb_build_object('saved',true,'id',p_id);
END $$;
REVOKE ALL ON FUNCTION public.ff_a02_catalog_presentation(text,uuid,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a02_catalog_presentation(text,uuid,integer,text) TO authenticated;
