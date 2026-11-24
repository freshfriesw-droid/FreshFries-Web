-- DEC-06 phase 1: real operational-day dashboard counts, not snapshot-list lengths.
create function public.ff80_dashboard_metrics(p_branch uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare uid uuid:=auth.uid(); r text; branches uuid[]; driver uuid; work_day date:=public.ff_business_date(now()); result jsonb; ready_count bigint;
begin
 select p.role into r from public.ff_profiles p where p.user_id=uid and p.active;
 if uid is null or r is null or r not in ('manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen') then
  raise exception 'حساب موظف فعّال مطلوب' using errcode='42501'; end if;
 if r in ('supervisor','customer_service') and not public.ff38_permission_allowed(uid,'view_reports') then
  raise exception 'ليست لديك صلاحية المؤشرات' using errcode='42501';end if;
 if r='driver' then
  select d.id,array[d.branch_id] into driver,branches from public.ff38_driver_links l join public.ff_drivers d on d.id=l.driver_id and d.active where l.user_id=uid;
  if driver is null then raise exception 'حساب الموصل غير مربوط' using errcode='42501';end if;
 elsif r<>'manager' then
  select array_agg(distinct ub.branch_id) into branches from public.ff_user_branches ub where ub.user_id=uid;
 end if;
 if p_branch is not null and not exists(select 1 from public.ff_branches b where b.id=p_branch and (r='manager' or b.id=any(branches))) then
  raise exception 'الفرع غير مصرح به' using errcode='42501';end if;
 if r<>'manager' and coalesce(cardinality(branches),0)=0 then raise exception 'لم يحدد فرع للحساب' using errcode='42501';end if;
 select jsonb_build_object('business_day',work_day,'role',r,'orders_today',count(*),
 'late_today',count(*) filter(where o.status not in ('delivered','cancelled') and o.created_at<now()-interval '60 minutes'),
 'completed_today',count(*) filter(where o.status='delivered'))
 into result
 from public.ff_orders o left join public.ff38_delivery_tasks t on t.order_id=o.id
 where o.order_type='delivery' and o.business_date=work_day
 and ((o.created_at at time zone 'Asia/Aden')::time>=time '08:00' or (o.created_at at time zone 'Asia/Aden')::time<time '02:00')
 and (p_branch is null or o.branch_id=p_branch) and (r='manager' or o.branch_id=any(branches))
 and (r<>'customer_service' or o.created_by=uid)
 and (r<>'driver' or coalesce(t.driver_id,o.driver_id)=driver)
 and (r<>'cashier' or exists(select 1 from public.ff49_cashier_receipts c where c.order_id=o.id and c.received_by=uid))
 and (r<>'burger_kitchen' or exists(select 1 from public.ff_burger_tickets k where k.delivery_order_id=o.id and k.kitchen_id=uid));
 -- Only the roles authorized to inspect the courier roster see a real availability number.
 if r in ('manager','supervisor','customer_service') then
  select count(*) into ready_count from public.ff_drivers d join public.ff38_driver_presence p on p.driver_id=d.id
  where d.active and p.state='ready' and p.last_seen_at>now()-interval '90 seconds'
  and (p_branch is null or d.branch_id=p_branch) and (r='manager' or d.branch_id=any(branches));
 end if;
 return result||jsonb_build_object('available_drivers',ready_count);
end $$;
revoke all on function public.ff80_dashboard_metrics(uuid) from public,anon;
grant execute on function public.ff80_dashboard_metrics(uuid) to authenticated;
