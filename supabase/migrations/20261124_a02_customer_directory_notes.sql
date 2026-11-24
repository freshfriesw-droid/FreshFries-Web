-- A02 FIX-07/UI-08: normalize equivalent Yemeni phone representations only
-- for lookup and new customer notes. Never rewrite historical order snapshots.
CREATE OR REPLACE FUNCTION ff_private.customer_phone_key(p_phone text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO ''
AS $function$
 SELECT CASE WHEN raw ~ '^[+0-9 ()-]+$'
  AND digits ~ '^(00967|967)?7[0-9]{8}$'
  THEN right(digits,9) ELSE btrim(coalesce(p_phone,'')) END
 FROM (SELECT translate(btrim(coalesce(p_phone,'')),
 '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','01234567890123456789') raw) r
 CROSS JOIN LATERAL (SELECT regexp_replace(raw,'[^0-9]','','g') digits) d
$function$;
REVOKE ALL ON FUNCTION ff_private.customer_phone_key(text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.ff51_customer_directory(p_query text DEFAULT '',p_limit integer DEFAULT 60)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
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
      AND (h.phone_snapshot ILIKE '%'||v_query||'%' OR coalesce(h.customer_name,'') ILIKE '%'||v_query||'%'))
   ORDER BY l.created_at DESC,l.id DESC LIMIT greatest(1,least(coalesce(p_limit,60),150))
  )
  SELECT jsonb_agg(jsonb_build_object(
    'phone',x.phone_key,'name',coalesce(x.customer_name,''),'address',coalesce(x.full_address,x.area_snapshot),
    'last_order_at',x.created_at,'first_order_at',x.first_order_at,'orders_count',x.orders_count,
    'notes_count',(SELECT count(*)::int FROM public.ff51_customer_notes n
       WHERE ff_private.customer_phone_key(n.phone)=x.phone_key)) ORDER BY x.created_at DESC)
  FROM matched x
 ),'[]'::jsonb);
END $function$;

CREATE OR REPLACE FUNCTION public.ff51_customer_note_add(p_phone text,p_note text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_note uuid;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND role IN ('manager','customer_service') AND active)
 THEN RAISE EXCEPTION 'غير مصرح' USING ERRCODE='42501';END IF;
 IF length(btrim(coalesce(p_phone,''))) NOT BETWEEN 5 AND 40 OR length(btrim(coalesce(p_note,''))) NOT BETWEEN 3 AND 2000
 THEN RAISE EXCEPTION 'بيانات ملاحظة العميل غير صحيحة' USING ERRCODE='22023';END IF;
 INSERT INTO public.ff51_customer_notes(phone,note,added_by)
 VALUES(ff_private.customer_phone_key(p_phone),btrim(p_note),auth.uid()) RETURNING id INTO v_note;
 RETURN jsonb_build_object('saved',true,'note_id',v_note);
END $function$;

CREATE OR REPLACE FUNCTION public.ff51_customer_notes_list(p_phone text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND role IN ('manager','customer_service') AND active)
 THEN RAISE EXCEPTION 'غير مصرح' USING ERRCODE='42501';END IF;
 RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('note',x.note,'added_at',x.added_at,'added_by',x.added_by)
  ORDER BY x.added_at DESC) FROM
  (SELECT * FROM public.ff51_customer_notes WHERE ff_private.customer_phone_key(phone)=ff_private.customer_phone_key(p_phone)
   ORDER BY added_at DESC LIMIT 30) x),'[]'::jsonb);
END $function$;

-- An optional new customer note is saved atomically with a contact correction.
-- Existing notes stay with their original identity; no automatic phone merge.
CREATE OR REPLACE FUNCTION public.ff_order_customer_edit_with_note(
 p_order uuid,p_phone text,p_area text,p_name text,p_address text,p_reason text,p_note text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_result jsonb;v_note jsonb;v_branch uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'تسجيل الدخول مطلوب' USING ERRCODE='42501';END IF;
 IF length(btrim(coalesce(p_note,'')))>0 AND NOT EXISTS(
  SELECT 1 FROM public.ff_profiles WHERE user_id=auth.uid() AND role IN ('manager','customer_service') AND active)
 THEN RAISE EXCEPTION 'ملاحظات العميل للمدير وخدمة العملاء فقط' USING ERRCODE='42501';END IF;
 v_result:=public.ff_order_customer_edit(p_order,p_phone,p_area,p_name,p_address,p_reason);
 IF length(btrim(coalesce(p_note,'')))>0 THEN
  v_note:=public.ff51_customer_note_add(p_phone,p_note);
  SELECT branch_id INTO v_branch FROM public.ff_orders WHERE id=p_order;
  INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
  VALUES(auth.uid(),'customer_note_from_order','order',p_order::text,v_branch,
   jsonb_build_object('note_id',v_note->>'note_id'));
  v_result:=v_result||jsonb_build_object('note_saved',true,'note_id',v_note->>'note_id');
 END IF;
 RETURN v_result;
END $function$;
REVOKE ALL ON FUNCTION public.ff_order_customer_edit_with_note(uuid,text,text,text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_order_customer_edit_with_note(uuid,text,text,text,text,text,text) TO authenticated,service_role;
