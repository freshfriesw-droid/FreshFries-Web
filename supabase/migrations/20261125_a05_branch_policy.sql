-- UI-15 / TR-33: versioned branch hours, delivery tariffs and catalog prices.
-- All versions append only; existing order fees/prices and business_date remain untouched.
CREATE TABLE ff_private.a05_branch_hours(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),branch_id uuid NOT NULL REFERENCES public.ff_branches(id),
 day_of_week smallint NOT NULL CHECK(day_of_week BETWEEN 0 AND 6),
 opens_at time,closes_at time,shift_change time,closed boolean NOT NULL,
 effective_at timestamptz NOT NULL,recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 actor_id uuid NOT NULL REFERENCES public.ff_profiles(user_id),reason text NOT NULL,
 CHECK((closed AND opens_at IS NULL AND closes_at IS NULL AND shift_change IS NULL) OR
 (NOT closed AND opens_at IS NOT NULL AND closes_at IS NOT NULL AND opens_at<>closes_at))
);
CREATE INDEX a05_branch_hours_idx ON ff_private.a05_branch_hours(branch_id,day_of_week,effective_at DESC,recorded_at DESC);
CREATE TABLE ff_private.a05_area_tariffs(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),branch_id uuid NOT NULL REFERENCES public.ff_branches(id),
 area_key text NOT NULL,area_name text NOT NULL,fee numeric NOT NULL CHECK(fee BETWEEN 0 AND 1000000 AND fee::text NOT IN ('NaN','Infinity','-Infinity') AND round(fee,2)=fee),
 effective_at timestamptz NOT NULL,recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 actor_id uuid NOT NULL REFERENCES public.ff_profiles(user_id),reason text NOT NULL
);
CREATE INDEX a05_area_tariff_idx ON ff_private.a05_area_tariffs(branch_id,area_key,effective_at DESC,recorded_at DESC);
CREATE TABLE ff_private.a05_catalog_prices(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),kind text NOT NULL CHECK(kind IN ('item','offer')),catalog_id uuid NOT NULL,
 name text NOT NULL,price numeric NOT NULL,active boolean NOT NULL,previous_price numeric,
 effective_at timestamptz NOT NULL DEFAULT clock_timestamp(),actor_id uuid,source text NOT NULL
);
CREATE INDEX a05_catalog_prices_idx ON ff_private.a05_catalog_prices(kind,catalog_id,effective_at DESC);
ALTER TABLE ff_private.a05_branch_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE ff_private.a05_area_tariffs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ff_private.a05_catalog_prices ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ff_private.a05_branch_hours,ff_private.a05_area_tariffs,ff_private.a05_catalog_prices FROM PUBLIC,anon,authenticated;
CREATE FUNCTION ff_private.a05_branch_settings_allowed(p_branch uuid,p_write boolean)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $body$
 SELECT EXISTS(SELECT 1 FROM public.ff_profiles p JOIN public.ff_branches b ON b.id=p_branch AND b.active
 WHERE p.user_id=auth.uid() AND p.active AND
 (p.role='manager' OR (p.role IN ('customer_service','cashier','supervisor') AND
 (p.role='customer_service' OR EXISTS(SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=p.user_id AND ub.branch_id=b.id))
 AND (NOT p_write OR public.ff38_permission_allowed(p.user_id,'manage_branches')))));
$body$;
REVOKE EXECUTE ON FUNCTION ff_private.a05_branch_settings_allowed(uuid,boolean) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.ff_a05_set_branch_hours(p_branch uuid,p_day integer,p_open time,p_close time,p_shift time,p_closed boolean,p_effective timestamptz,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $body$
DECLARE v_id uuid;span interval;shift_span interval;
BEGIN
 IF NOT ff_private.a05_branch_settings_allowed(p_branch,true) THEN RAISE EXCEPTION 'إدارة هذا الفرع غير مصرح بها' USING ERRCODE='42501';END IF;
 IF p_day IS NULL OR p_day NOT BETWEEN 0 AND 6 OR p_closed IS NULL OR p_effective IS NULL OR p_effective<now()-interval '5 minutes' OR p_effective>now()+interval '365 days' OR length(btrim(coalesce(p_reason,''))) NOT BETWEEN 5 AND 500 THEN RAISE EXCEPTION 'بيانات الدوام أو سبب التغيير غير صالح' USING ERRCODE='22023';END IF;
 IF p_closed THEN p_open:=NULL;p_close:=NULL;p_shift:=NULL;
 ELSE
  IF p_open IS NULL OR p_close IS NULL OR p_open=p_close THEN RAISE EXCEPTION 'حدد وقت فتح وإغلاق مختلفين' USING ERRCODE='22023';END IF;
  span:=p_close-p_open;IF span<interval '0' THEN span:=span+interval '24 hours';END IF;
  IF p_shift IS NOT NULL THEN shift_span:=p_shift-p_open;IF shift_span<interval '0' THEN shift_span:=shift_span+interval '24 hours';END IF;
  IF shift_span<=interval '0' OR shift_span>=span THEN RAISE EXCEPTION 'موعد تبديل الوردية خارج ساعات العمل' USING ERRCODE='22023';END IF;END IF;
 END IF;
 INSERT INTO ff_private.a05_branch_hours(branch_id,day_of_week,opens_at,closes_at,shift_change,closed,effective_at,actor_id,reason)
 VALUES(p_branch,p_day,p_open,p_close,p_shift,p_closed,p_effective,auth.uid(),btrim(p_reason)) RETURNING id INTO v_id;
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 VALUES(auth.uid(),'a05_branch_hours_changed','branch',p_branch::text,p_branch,jsonb_build_object('version_id',v_id,'day',p_day,'effective_at',p_effective));
 RETURN jsonb_build_object('saved',true,'id',v_id);
END $body$;
CREATE FUNCTION public.ff_a05_set_area_tariff(p_branch uuid,p_area text,p_fee numeric,p_effective timestamptz,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $body$
DECLARE v_id uuid;v_area text:=regexp_replace(btrim(coalesce(p_area,'')),'[[:space:]]+',' ','g');
BEGIN
 IF NOT ff_private.a05_branch_settings_allowed(p_branch,true) THEN RAISE EXCEPTION 'إدارة هذا الفرع غير مصرح بها' USING ERRCODE='42501';END IF;
 IF length(v_area) NOT BETWEEN 2 AND 120 OR p_fee IS NULL OR p_fee<0 OR p_fee>1000000 OR p_fee::text IN ('NaN','Infinity','-Infinity') OR round(p_fee,2)<>p_fee OR p_effective IS NULL OR p_effective<now()-interval '5 minutes' OR p_effective>now()+interval '365 days' OR length(btrim(coalesce(p_reason,''))) NOT BETWEEN 5 AND 500 THEN RAISE EXCEPTION 'بيانات الرسوم أو سبب التغيير غير صالح' USING ERRCODE='22023';END IF;
 INSERT INTO ff_private.a05_area_tariffs(branch_id,area_key,area_name,fee,effective_at,actor_id,reason)
 VALUES(p_branch,lower(v_area),v_area,p_fee,p_effective,auth.uid(),btrim(p_reason)) RETURNING id INTO v_id;
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 VALUES(auth.uid(),'a05_area_tariff_changed','branch',p_branch::text,p_branch,jsonb_build_object('version_id',v_id,'area',v_area,'fee',p_fee,'effective_at',p_effective));
 RETURN jsonb_build_object('saved',true,'id',v_id);
END $body$;
CREATE FUNCTION public.ff_a05_branch_policy(p_branch uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $body$
BEGIN
 IF NOT ff_private.a05_branch_settings_allowed(p_branch,false) THEN RAISE EXCEPTION 'الفرع غير مصرح به' USING ERRCODE='42501';END IF;
 RETURN jsonb_build_object('can_write',ff_private.a05_branch_settings_allowed(p_branch,true),
 'hours',coalesce((SELECT jsonb_agg(to_jsonb(h) ORDER BY h.day_of_week) FROM (
 SELECT DISTINCT ON(day_of_week) day_of_week,opens_at,closes_at,shift_change,closed,effective_at,reason,(SELECT display_name FROM public.ff_profiles WHERE user_id=a.actor_id) AS source
 FROM ff_private.a05_branch_hours a WHERE branch_id=p_branch AND effective_at<=now()
 ORDER BY day_of_week,effective_at DESC,recorded_at DESC,id DESC) h),'[]'::jsonb),
 'hour_history',coalesce((SELECT jsonb_agg(to_jsonb(h) ORDER BY h.effective_at DESC) FROM (
 SELECT day_of_week,opens_at,closes_at,shift_change,closed,effective_at,recorded_at,reason,(SELECT display_name FROM public.ff_profiles WHERE user_id=a.actor_id) AS source FROM ff_private.a05_branch_hours a WHERE branch_id=p_branch ORDER BY effective_at DESC,recorded_at DESC LIMIT 80) h),'[]'::jsonb),
 'tariffs',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY t.area_name) FROM (
 SELECT DISTINCT ON(area_key) area_name,fee,effective_at,reason,(SELECT display_name FROM public.ff_profiles WHERE user_id=a.actor_id) AS source FROM ff_private.a05_area_tariffs a WHERE branch_id=p_branch AND effective_at<=now() ORDER BY area_key,effective_at DESC,recorded_at DESC,id DESC) t),'[]'::jsonb),
 'tariff_history',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY t.effective_at DESC) FROM (
 SELECT area_name,fee,effective_at,recorded_at,reason,(SELECT display_name FROM public.ff_profiles WHERE user_id=a.actor_id) AS source FROM ff_private.a05_area_tariffs a WHERE branch_id=p_branch ORDER BY effective_at DESC,recorded_at DESC LIMIT 100) t),'[]'::jsonb));
END $body$;
CREATE FUNCTION public.ff_a05_area_fee_hint(p_branch uuid,p_area text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $body$
DECLARE k text:=lower(regexp_replace(btrim(coalesce(p_area,'')),'[[:space:]]+',' ','g'));
BEGIN
 IF NOT ff_private.a05_branch_settings_allowed(p_branch,false) THEN RAISE EXCEPTION 'الفرع غير مصرح به' USING ERRCODE='42501';END IF;
 IF length(k) NOT BETWEEN 2 AND 120 THEN RETURN jsonb_build_object('approved',NULL,'history','[]'::jsonb);END IF;
 RETURN jsonb_build_object('approved',(SELECT jsonb_build_object('fee',a.fee,'effective_at',a.effective_at,'source',(SELECT display_name FROM public.ff_profiles WHERE user_id=a.actor_id),'reason',a.reason)
 FROM ff_private.a05_area_tariffs a WHERE a.branch_id=p_branch AND a.area_key=k AND a.effective_at<=now() ORDER BY a.effective_at DESC,a.recorded_at DESC,a.id DESC LIMIT 1),
 'history',coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.last_used_at DESC) FROM (
 SELECT delivery_fee AS fee,max(created_at) AS last_used_at,count(*) AS orders FROM public.ff_orders o WHERE o.branch_id=p_branch AND o.order_type='delivery' AND lower(regexp_replace(btrim(o.area_snapshot),'[[:space:]]+',' ','g'))=k AND o.status NOT IN ('cancelled','canceled') GROUP BY delivery_fee ORDER BY max(created_at) DESC LIMIT 10) x),'[]'::jsonb));
END $body$;
CREATE FUNCTION ff_private.a05_record_catalog_price()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $body$
BEGIN
 IF TG_OP='UPDATE' AND NEW.price IS NOT DISTINCT FROM OLD.price AND NEW.active IS NOT DISTINCT FROM OLD.active AND NEW.name IS NOT DISTINCT FROM OLD.name THEN RETURN NEW;END IF;
 INSERT INTO ff_private.a05_catalog_prices(kind,catalog_id,name,price,active,previous_price,actor_id,source)
 VALUES(CASE WHEN TG_TABLE_NAME='ff_menu_items' THEN 'item' ELSE 'offer' END,NEW.id,NEW.name,NEW.price,NEW.active,CASE WHEN TG_OP='UPDATE' THEN OLD.price ELSE NULL END,auth.uid(),'recorded_change');
 RETURN NEW;
END $body$;
REVOKE EXECUTE ON FUNCTION ff_private.a05_record_catalog_price() FROM PUBLIC,anon,authenticated;
INSERT INTO ff_private.a05_catalog_prices(kind,catalog_id,name,price,active,source)
 SELECT 'item',id,name,price,active,'observed_baseline' FROM public.ff_menu_items
 UNION ALL SELECT 'offer',id,name,price,active,'observed_baseline' FROM public.ff_offers;
CREATE TRIGGER a05_menu_price_history AFTER INSERT OR UPDATE OF price,active,name ON public.ff_menu_items FOR EACH ROW EXECUTE FUNCTION ff_private.a05_record_catalog_price();
CREATE TRIGGER a05_offer_price_history AFTER INSERT OR UPDATE OF price,active,name ON public.ff_offers FOR EACH ROW EXECUTE FUNCTION ff_private.a05_record_catalog_price();
CREATE FUNCTION public.ff_a05_catalog_price_history(p_limit int DEFAULT 100)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $body$
BEGIN
 IF NOT public.ff_is_manager() THEN RAISE EXCEPTION 'للمدير فقط' USING ERRCODE='42501';END IF;
 RETURN coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.effective_at DESC) FROM(
 SELECT kind,name,price,previous_price,active,effective_at,source,coalesce((SELECT display_name FROM public.ff_profiles WHERE user_id=h.actor_id),'غير مسجل') AS actor
 FROM ff_private.a05_catalog_prices h ORDER BY effective_at DESC,id DESC LIMIT greatest(1,least(coalesce(p_limit,100),300))) x),'[]'::jsonb);
END $body$;
REVOKE EXECUTE ON FUNCTION public.ff_a05_set_branch_hours(uuid,integer,time,time,time,boolean,timestamptz,text),public.ff_a05_set_area_tariff(uuid,text,numeric,timestamptz,text),public.ff_a05_branch_policy(uuid),public.ff_a05_area_fee_hint(uuid,text),public.ff_a05_catalog_price_history(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a05_set_branch_hours(uuid,integer,time,time,time,boolean,timestamptz,text),public.ff_a05_set_area_tariff(uuid,text,numeric,timestamptz,text),public.ff_a05_branch_policy(uuid),public.ff_a05_area_fee_hint(uuid,text),public.ff_a05_catalog_price_history(integer) TO authenticated;
