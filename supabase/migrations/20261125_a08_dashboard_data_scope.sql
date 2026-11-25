-- A08: common authorized dashboard data source for metrics, branch summaries and drill-down.
CREATE OR REPLACE FUNCTION ff_private.a08_dashboard_scope(p_branch uuid)
RETURNS TABLE(role_name text,branch_ids uuid[],driver_id uuid) LANGUAGE plpgsql STABLE SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); r text; branches uuid[]; driver uuid;
BEGIN
 select p.role into r from public.ff_profiles p where p.user_id=uid and p.active;
 if uid is null or r is null or r not in ('manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen') then
  raise exception 'حساب موظف فعّال مطلوب' using errcode='42501'; end if;
 if r in ('supervisor','customer_service') and not public.ff38_permission_allowed(uid,'view_reports') then
  raise exception 'ليست لديك صلاحية المؤشرات' using errcode='42501';end if;
 
 if exists(select 1 from public.ff38_staff_permission_overrides where user_id=uid and permission_key='view_reports' and allowed=false) then
 raise exception 'صلاحية المؤشرات مسحوبة' using errcode='42501';end if;
 if r='assembly' and public.ff_v12_assembly_me()->>'is_assembly' is distinct from 'true' then
 raise exception 'صلاحية التجميع مسحوبة' using errcode='42501';end if;
 if r='burger_kitchen' then perform public.ff_burger_my_branch();end if;
 if r='driver' then
  select d.id,array[d.branch_id] into driver,branches from public.ff38_driver_links l join public.ff_drivers d on d.id=l.driver_id and d.active where l.user_id=uid;
  if driver is null then raise exception 'حساب الموصل غير مربوط' using errcode='42501';end if;
 elsif r<>'manager' then
  select array_agg(distinct ub.branch_id) into branches from public.ff_user_branches ub where ub.user_id=uid;
 end if;
 if r='customer_service' or (r='supervisor' and coalesce(cardinality(branches),0)=0) then
 select array_agg(b.id) into branches from public.ff_branches b where b.active;end if;
 if p_branch is not null and not exists(select 1 from public.ff_branches b where b.id=p_branch and (r='manager' or b.id=any(branches))) then
  raise exception 'الفرع غير مصرح به' using errcode='42501';end if;
 if r<>'manager' and coalesce(cardinality(branches),0)=0 then raise exception 'لم يحدد فرع للحساب' using errcode='42501';end if;

 RETURN QUERY SELECT r,branches,driver;
END $$;
CREATE OR REPLACE FUNCTION ff_private.a08_order_rows(p_branch uuid,r text,branches uuid[],driver uuid,work_day date)
RETURNS TABLE(order_id uuid,order_number bigint,branch_id uuid,status text,created_at timestamptz,updated_at timestamptz)
LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT o.id,o.order_number,o.branch_id,o.status,o.created_at,o.updated_at
from public.ff_orders o left join public.ff38_delivery_tasks t on t.order_id=o.id
 where o.order_type='delivery' and o.business_date=work_day
 and ((o.created_at at time zone 'Asia/Aden')::time>=time '08:00' or (o.created_at at time zone 'Asia/Aden')::time<time '02:00')
 and (p_branch is null or o.branch_id=p_branch) and (r='manager' or o.branch_id=any(branches))
 and (r<>'customer_service' or o.created_by=auth.uid())
 and (r<>'driver' or coalesce(t.driver_id,o.driver_id)=driver)
 and (r<>'cashier' or exists(select 1 from public.ff49_cashier_receipts c where c.order_id=o.id and c.received_by=auth.uid()))
 and (r<>'burger_kitchen' or exists(select 1 from public.ff_burger_tickets k where k.delivery_order_id=o.id and k.kitchen_id=auth.uid()))
$$;
CREATE OR REPLACE FUNCTION ff_private.a08_ready_rows(p_branch uuid,r text,branches uuid[])
RETURNS TABLE(driver_id uuid,driver_name text,branch_id uuid)
LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT d.id,d.name,d.branch_id FROM public.ff_drivers d JOIN public.ff38_driver_presence p ON p.driver_id=d.id
 WHERE r IN ('manager','supervisor','customer_service') AND d.active AND p.state='ready' AND p.last_seen_at>now()-interval '90 seconds'
 AND (p_branch IS NULL OR d.branch_id=p_branch) AND (r='manager' OR d.branch_id=ANY(branches))
$$;
REVOKE ALL ON FUNCTION ff_private.a08_dashboard_scope(uuid),ff_private.a08_order_rows(uuid,text,uuid[],uuid,date),ff_private.a08_ready_rows(uuid,text,uuid[]) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.ff80_dashboard_metrics(p_branch uuid DEFAULT NULL::uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE r text; branches uuid[]; driver uuid; work_day date:=public.ff_business_date(now()); result jsonb;
BEGIN
 SELECT role_name,branch_ids,driver_id INTO r,branches,driver FROM ff_private.a08_dashboard_scope(p_branch);
 WITH scoped AS MATERIALIZED (SELECT * FROM ff_private.a08_order_rows(p_branch,r,branches,driver,work_day)),
 ready AS MATERIALIZED (SELECT * FROM ff_private.a08_ready_rows(p_branch,r,branches)),
 order_counts AS (SELECT branch_id,count(*) AS orders,count(*) FILTER(WHERE status='delivered') AS completed,count(*) FILTER(WHERE status NOT IN ('delivered','cancelled') AND created_at<now()-interval '60 minutes') AS late FROM scoped GROUP BY branch_id),
 ready_counts AS (SELECT branch_id,count(*) AS ready_count FROM ready GROUP BY branch_id),
 activity AS (SELECT s.order_number,s.branch_id,b.name AS branch_name,s.status,s.updated_at FROM scoped s JOIN public.ff_branches b ON b.id=s.branch_id WHERE r IN ('manager','supervisor','customer_service','cashier','driver') ORDER BY s.updated_at DESC,s.order_id DESC LIMIT 5)
 SELECT jsonb_build_object('business_day',work_day,'role',r,'orders_today',(SELECT count(*) FROM scoped),
 'late_today',(SELECT count(*) FROM scoped WHERE status NOT IN ('delivered','cancelled') AND created_at<now()-interval '60 minutes'),
 'completed_today',(SELECT count(*) FROM scoped WHERE status='delivered'),
 'available_drivers',CASE WHEN r IN ('manager','supervisor','customer_service') THEN (SELECT count(*) FROM ready) ELSE NULL END,
 'branch_status',coalesce((SELECT jsonb_agg(jsonb_build_object('branch_id',b.id,'branch_name',b.name,'active',b.active,'orders_today',coalesce(c.orders,0),'completed_today',coalesce(c.completed,0),'late_today',coalesce(c.late,0),'available_drivers',CASE WHEN r IN ('manager','supervisor','customer_service') THEN coalesce(rc.ready_count,0) ELSE NULL END) ORDER BY b.code,b.id)
 FROM public.ff_branches b LEFT JOIN order_counts c ON c.branch_id=b.id LEFT JOIN ready_counts rc ON rc.branch_id=b.id
 WHERE (p_branch IS NULL OR b.id=p_branch) AND (r='manager' OR b.id=ANY(branches)) AND (r IN ('manager','supervisor','customer_service','cashier','driver'))),'[]'::jsonb),
 'recent_activity',coalesce((SELECT jsonb_agg(to_jsonb(a) ORDER BY a.updated_at DESC,a.order_number DESC) FROM activity a),'[]'::jsonb))
 INTO result;
 RETURN result;
END $$;
CREATE OR REPLACE FUNCTION public.ff_a08_metric_detail(p_branch uuid,p_metric text,p_offset integer DEFAULT 0,p_limit integer DEFAULT 30)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE r text; branches uuid[]; driver uuid; work_day date:=public.ff_business_date(now()); result jsonb;
BEGIN
 SELECT role_name,branch_ids,driver_id INTO r,branches,driver FROM ff_private.a08_dashboard_scope(p_branch);
 IF p_metric IS NULL OR p_metric NOT IN ('orders_today','late_today','completed_today','available_drivers') OR p_offset IS NULL OR p_offset<0 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'معيار أو صفحة غير صالحة' USING ERRCODE='22023'; END IF;
 IF r NOT IN ('manager','supervisor','customer_service','cashier','driver') OR (p_metric='available_drivers' AND r NOT IN ('manager','supervisor','customer_service')) THEN RAISE EXCEPTION 'المؤشر غير مصرح' USING ERRCODE='42501'; END IF;
 IF p_metric='available_drivers' THEN
  WITH scoped AS MATERIALIZED (SELECT a.driver_id,a.driver_name,a.branch_id,b.name AS branch_name FROM ff_private.a08_ready_rows(p_branch,r,branches) a JOIN public.ff_branches b ON b.id=a.branch_id),
  paged AS (SELECT driver_name,branch_id,branch_name FROM scoped ORDER BY branch_name,driver_name,driver_id LIMIT p_limit OFFSET p_offset)
  SELECT jsonb_build_object('total',(SELECT count(*) FROM scoped),'rows',coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM paged p),'[]'::jsonb)) INTO result;
 ELSE
  WITH scoped AS MATERIALIZED (SELECT a.*,b.name AS branch_name FROM ff_private.a08_order_rows(p_branch,r,branches,driver,work_day) a JOIN public.ff_branches b ON b.id=a.branch_id
   WHERE p_metric='orders_today' OR (p_metric='completed_today' AND a.status='delivered') OR (p_metric='late_today' AND a.status NOT IN ('delivered','cancelled') AND a.created_at<now()-interval '60 minutes')),
  paged AS (SELECT order_number,branch_id,branch_name,status,created_at,updated_at FROM scoped ORDER BY updated_at DESC,order_id DESC LIMIT p_limit OFFSET p_offset)
  SELECT jsonb_build_object('total',(SELECT count(*) FROM scoped),'rows',coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM paged p),'[]'::jsonb)) INTO result;
 END IF;
 RETURN result||jsonb_build_object('metric',p_metric,'role',r,'business_day',work_day,'offset',p_offset,'limit',p_limit);
END $$;
REVOKE ALL ON FUNCTION public.ff_a08_metric_detail(uuid,text,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a08_metric_detail(uuid,text,integer,integer) TO authenticated;
ALTER TABLE public.ff_ui_versions VALIDATE CONSTRAINT ff_a08_dashboard_scope;
