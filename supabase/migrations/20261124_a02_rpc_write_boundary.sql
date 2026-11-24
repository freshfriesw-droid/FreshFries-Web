-- A02: active frontend and its 22 local scripts use server RPCs for these
-- four core tables; both deployed Edge Functions also have no direct use.
-- Keep existing SELECT grants (including Realtime) and service-role grants.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE
 public.ff_orders, public.ff_order_items, public.ff_customers, public.ff_customer_notes
 FROM authenticated, anon, PUBLIC;

-- Old atomic clients retain compatibility through the current guarded path.
CREATE OR REPLACE FUNCTION public.ff70_submit_atomic(p_request uuid,p_kind text,p_input jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 IF p_kind IS DISTINCT FROM 'delivery' THEN RAISE EXCEPTION 'Invalid request' USING ERRCODE='22023'; END IF;
 RETURN public.ff27_submit(p_request,p_kind,p_input);
END;
$function$;

-- Keep internal functions and their service-role privileges. The active
-- browser calls ff27_submit and ff52_regular_addition_* instead.
REVOKE EXECUTE ON FUNCTION
 public.ff_create_order_with_items(jsonb,jsonb),
 public.ff38_create_delivery_order(uuid,text,text,jsonb,numeric,text),
 public.ff49_create_delivery_order(uuid,text,text,jsonb,numeric,text,text,text,text),
 public.ff38_create_order_addition(uuid,jsonb),
 public.ff38_cancel_order_addition(uuid)
 FROM authenticated, anon, PUBLIC;

-- The obsolete desk-create callback is still present in old cached HTML
-- and overwritten by the current preview handler. Its retirement requires
-- live publishing/client verification, so retain its existing access here.
