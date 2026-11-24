-- FIX-15: ensure all report entry points honor explicit individual revocation.
-- Retain the personal reports already available to cashier/courier/kitchen/assembly by default.
INSERT INTO public.ff38_role_permission_defaults(role,permission_key,allowed)
 VALUES('assembly','view_reports',false),('burger_kitchen','view_reports',false)
 ON CONFLICT(role,permission_key) DO NOTHING;
DO $migration$
DECLARE f regprocedure;src text;marker text;
BEGIN
 f:='public.ff76_reporting_center(date,date,uuid,uuid)'::regprocedure;
 src:=pg_get_functiondef(f);marker:='IF v_start>v_end';
 IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected reporting center guard';END IF;
 src:=replace(src,marker,$body$
 IF EXISTS(SELECT 1 FROM public.ff38_staff_permission_overrides WHERE user_id=v_uid AND permission_key='view_reports' AND allowed=false) THEN
 RAISE EXCEPTION 'صلاحية التقارير مسحوبة' USING ERRCODE='42501';END IF;
 IF v_role='assembly' AND public.ff_v12_assembly_me()->>'is_assembly' IS DISTINCT FROM 'true' THEN
 RAISE EXCEPTION 'صلاحية التجميع مسحوبة' USING ERRCODE='42501';END IF;
 IF v_role='burger_kitchen' THEN PERFORM public.ff_burger_my_branch();END IF;
 $body$||marker);
 marker:=$body$IF v_role='customer_service' AND coalesce(cardinality(v_branches),0)=0 THEN
 SELECT array_agg(DISTINCT o.branch_id) INTO v_branches FROM public.ff_orders AS o WHERE o.created_by=v_uid;
 END IF;$body$;
 -- Whitespace in the live body may differ; replace the entire exact semantic statement via regex.
 IF src !~ 'IF v_role=''customer_service'' AND coalesce\(cardinality\(v_branches\),0\)=0 THEN' THEN RAISE EXCEPTION 'Unexpected central report scope';END IF;
 src:=regexp_replace(src,'IF v_role=''customer_service'' AND coalesce\(cardinality\(v_branches\),0\)=0 THEN[[:space:]]+SELECT array_agg\(DISTINCT o.branch_id\) INTO v_branches FROM public.ff_orders AS o WHERE o.created_by=v_uid;[[:space:]]+END IF;',
 $body$IF v_role='customer_service' OR (v_role='supervisor' AND coalesce(cardinality(v_branches),0)=0) THEN
 SELECT array_agg(b.id) INTO v_branches FROM public.ff_branches b WHERE b.active;
 END IF;$body$);
 IF strpos(src,'SELECT array_agg(DISTINCT o.branch_id) INTO v_branches FROM public.ff_orders AS o WHERE o.created_by=v_uid;')>0 THEN RAISE EXCEPTION 'Report scope replacement failed';END IF;
 EXECUTE src;
 f:='public.ff80_dashboard_metrics(uuid)'::regprocedure;
 src:=pg_get_functiondef(f);marker:=$body$if r='driver' then$body$;
 IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected dashboard guard';END IF;
 src:=replace(src,marker,$body$
 if exists(select 1 from public.ff38_staff_permission_overrides where user_id=uid and permission_key='view_reports' and allowed=false) then
 raise exception 'صلاحية المؤشرات مسحوبة' using errcode='42501';end if;
 if r='assembly' and public.ff_v12_assembly_me()->>'is_assembly' is distinct from 'true' then
 raise exception 'صلاحية التجميع مسحوبة' using errcode='42501';end if;
 if r='burger_kitchen' then perform public.ff_burger_my_branch();end if;
 $body$||marker);
 marker:='if p_branch is not null and not exists';
 IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected dashboard branch guard';END IF;
 src:=replace(src,marker,$body$if r='customer_service' or (r='supervisor' and coalesce(cardinality(branches),0)=0) then
 select array_agg(b.id) into branches from public.ff_branches b where b.active;end if;
 $body$||marker);
 EXECUTE src;
 -- Prevent calling the older snapshot directly to bypass cashier desk filtering.
 f:='public.ff38_snapshot()'::regprocedure;
 src:=pg_get_functiondef(f);marker:=$body$OR (v_role='cashier' AND EXISTS (SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid() AND ub.branch_id=o.branch_id) AND t.order_id IS NOT NULL)$body$;
 IF strpos(src,marker)=0 THEN RAISE EXCEPTION 'Unexpected legacy snapshot scope';END IF;
 EXECUTE replace(src,marker,$body$OR (v_role='cashier' AND ff_private.a05_can_read_order(o.id))$body$);
END $migration$;
