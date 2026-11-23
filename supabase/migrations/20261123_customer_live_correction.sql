-- Customer-contact correction on ANY order state, with server-side role checks,
-- full audit and a push alert to the assigned driver. No order-state transition.
CREATE TABLE IF NOT EXISTS public.ff_order_customer_edits(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 order_id uuid NOT NULL REFERENCES public.ff_orders(id) ON DELETE CASCADE,
 branch_id uuid NOT NULL REFERENCES public.ff_branches(id),
 actor_id uuid NOT NULL REFERENCES public.ff_profiles(user_id),
 changed_fields text[] NOT NULL,
 old_values jsonb NOT NULL,
 new_values jsonb NOT NULL,
 reason text NOT NULL DEFAULT '',
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ff_order_customer_edits_order_idx
ON public.ff_order_customer_edits(order_id,created_at DESC);
ALTER TABLE public.ff_order_customer_edits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ff_order_customer_edits FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.ff_order_customer_edit(
 p_order uuid,p_phone text,p_area text,p_name text,p_address text,p_reason text DEFAULT ''
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=''
AS $body$
DECLARE
 v_role text;v_order public.ff_orders%ROWTYPE;
 v_old_name text;v_old_address text;v_new_name text;v_new_address text;
 v_phone text:=btrim(coalesce(p_phone,''));v_area text:=btrim(coalesce(p_area,''));
 v_old jsonb;v_new jsonb;v_fields text[]:=ARRAY[]::text[];v_edit uuid;
BEGIN
 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF v_role NOT IN ('manager','customer_service','cashier') OR
    NOT public.ff38_permission_allowed(auth.uid(),'edit_order') THEN
  RAISE EXCEPTION 'تعديل بيانات العميل غير مسموح لدورك' USING ERRCODE='42501';
 END IF;
 SELECT * INTO v_order FROM public.ff_orders WHERE id=p_order FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'الطلب غير موجود';END IF;
 IF v_role='cashier' AND (NOT EXISTS(
  SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid() AND ub.branch_id=v_order.branch_id)
  OR (EXISTS(SELECT 1 FROM public.ff_luxe_cashier_staff_desks sd WHERE sd.user_id=auth.uid())
   AND EXISTS(SELECT 1 FROM public.ff_luxe_cashier_order_desks od WHERE od.order_id=p_order)
   AND NOT EXISTS(SELECT 1 FROM public.ff_luxe_cashier_staff_desks sd
    JOIN public.ff_luxe_cashier_order_desks od ON od.desk_code=sd.desk_code
    WHERE sd.user_id=auth.uid() AND od.order_id=p_order)))
 THEN RAISE EXCEPTION 'الطلب خارج فرعك أو وجهتك' USING ERRCODE='42501';END IF;
 IF v_phone !~ '^[+]?[0-9٠-٩ ()-]{7,30}$' OR length(v_area) NOT BETWEEN 2 AND 150
  OR length(btrim(coalesce(p_name,''))) NOT BETWEEN 2 AND 100
  OR length(btrim(coalesce(p_address,''))) NOT BETWEEN 2 AND 500
  OR length(coalesce(p_reason,''))>300 THEN
  RAISE EXCEPTION 'تحقق من اسم العميل والهاتف والعنوان والمنطقة';
 END IF;
 SELECT customer_name,full_address INTO v_old_name,v_old_address
 FROM public.ff49_order_details WHERE order_id=p_order;
 v_old_name:=coalesce(v_old_name,'عميل');
 v_old_address:=coalesce(v_old_address,v_order.area_snapshot);
 v_new_name:=btrim(p_name);v_new_address:=btrim(p_address);
 v_old:=jsonb_build_object('phone',v_order.phone_snapshot,'area',v_order.area_snapshot,'name',v_old_name,'address',v_old_address);
 v_new:=jsonb_build_object('phone',v_phone,'area',v_area,'name',v_new_name,'address',v_new_address);
 IF v_old=v_new THEN RETURN jsonb_build_object('saved',true,'unchanged',true);END IF;
 IF v_phone IS DISTINCT FROM v_order.phone_snapshot THEN v_fields:=array_append(v_fields,'phone');END IF;
 IF v_area IS DISTINCT FROM v_order.area_snapshot THEN v_fields:=array_append(v_fields,'area');END IF;
 IF v_new_name IS DISTINCT FROM v_old_name THEN v_fields:=array_append(v_fields,'name');END IF;
 IF v_new_address IS DISTINCT FROM v_old_address THEN v_fields:=array_append(v_fields,'address');END IF;
 UPDATE public.ff_orders SET phone_snapshot=v_phone,area_snapshot=v_area,updated_at=now()
 WHERE id=p_order;
 INSERT INTO public.ff49_order_details(order_id,customer_name,channel,full_address)
 VALUES(p_order,v_new_name,'phone',v_new_address)
 ON CONFLICT(order_id) DO UPDATE SET customer_name=EXCLUDED.customer_name,full_address=EXCLUDED.full_address;
 INSERT INTO public.ff_order_customer_edits(order_id,branch_id,actor_id,changed_fields,old_values,new_values,reason)
 VALUES(p_order,v_order.branch_id,auth.uid(),v_fields,v_old,v_new,left(coalesce(p_reason,''),300))
 RETURNING id INTO v_edit;
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 VALUES(auth.uid(),'customer_contact_corrected','order',p_order::text,v_order.branch_id,
  jsonb_build_object('fields',v_fields,'change_id',v_edit));
 BEGIN
 INSERT INTO public.ff_push_jobs(user_id,order_id,event_key,kind,title,body)
 SELECT DISTINCT l.user_id,p_order,'customer-edit:'||v_edit::text,'employee_notice',
  '⚠️ بيانات العميل تغيرت',
  'تم تحديث '||array_to_string(v_fields,'، ')||' للطلب #'||v_order.order_number||' — افتح بطاقة الطلب'
 FROM public.ff38_delivery_tasks t JOIN public.ff38_driver_links l ON l.driver_id=t.driver_id
 WHERE t.order_id=p_order
 ON CONFLICT(user_id,event_key) DO NOTHING;
 PERFORM ff_private.push_kick();
 EXCEPTION WHEN OTHERS THEN
   RAISE WARNING 'Order contact edit saved; driver push deferred: %',SQLERRM;
 END;
 RETURN jsonb_build_object('saved',true,'edit_id',v_edit,'changed_fields',to_jsonb(v_fields));
END $body$;

DO $patch$
DECLARE s text;
BEGIN
 SELECT pg_get_functiondef(oid) INTO s FROM pg_proc
 WHERE pronamespace='public'::regnamespace AND proname='ff49_snapshot';
 IF s IS NULL OR position('''cashier_employee_name'',coalesce(nullif(receiving_cashier.display_name,''''),''بانتظار استلام الكاشير'')' in s)=0 THEN
  RAISE EXCEPTION 'Snapshot extension anchor missing';END IF;
 s:=replace(s,'''cashier_employee_name'',coalesce(nullif(receiving_cashier.display_name,''''),''بانتظار استلام الكاشير'')',
 '''cashier_employee_name'',coalesce(nullif(receiving_cashier.display_name,''''),''بانتظار استلام الكاشير''),
   ''customer_update'',(SELECT jsonb_build_object(''at'',u.created_at,''fields'',to_jsonb(u.changed_fields))
    FROM public.ff_order_customer_edits u WHERE u.order_id=o.id ORDER BY u.created_at DESC LIMIT 1)');
 EXECUTE s;
END $patch$;
REVOKE ALL ON FUNCTION public.ff_order_customer_edit(uuid,text,text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_order_customer_edit(uuid,text,text,text,text,text) TO authenticated;
