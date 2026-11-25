-- STEP12: scope completed-order listing and its shared action guard to supervisor's authorized branches.
CREATE OR REPLACE FUNCTION ff_private.ff_luxe_completed_can_view(p_order uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select exists(
  select 1 from public.ff_orders o
  left join public.ff38_delivery_tasks t on t.order_id=o.id
  join public.ff_profiles p on p.user_id=auth.uid() and p.active
  left join public.ff_luxe_cashier_order_desks od on od.order_id=o.id
  left join public.ff_luxe_cashier_staff_desks sd on sd.user_id=p.user_id
  where o.id=p_order and o.order_type='delivery'
    and (o.status in ('delivered','cancelled','canceled','closed')
       or (t.cashier_stage='handed_over' and o.status not in ('cancelled','canceled','closed')))
    and (
      p.role='manager'
      or (p.role='supervisor' and ff_private.a10_branch_visible(p.role,o.branch_id))
      or (p.role='customer_service' and (
         not exists(select 1 from public.ff_user_branches b where b.user_id=p.user_id)
         or exists(select 1 from public.ff_user_branches b
                   where b.user_id=p.user_id and b.branch_id=o.branch_id)
      ))
      or (p.role='cashier' and exists(select 1 from public.ff_user_branches b
         where b.user_id=p.user_id and b.branch_id=o.branch_id)
         and (sd.user_id is null or od.order_id is null or sd.desk_code=od.desk_code))
      or (p.role='assembly' and exists(
         select 1 from public.ff_v9_assembly_access a
         where a.user_id=p.user_id and a.branch_id=o.branch_id and a.enabled
      ))
      or (p.role='driver' and exists(
         select 1 from public.ff38_driver_links l
         where l.user_id=p.user_id and l.driver_id=coalesce(t.driver_id,o.driver_id)
      ))
    )
 );
$function$;
CREATE OR REPLACE FUNCTION public.ff_luxe_completed_universal(p_from date DEFAULT NULL::date, p_to date DEFAULT NULL::date, p_branch uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 30, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_start date:=coalesce(p_from,public.ff_business_date(now()));
 v_end date:=coalesce(p_to,public.ff_business_date(now()));
 v_limit integer:=least(greatest(coalesce(p_limit,30),1),60);
 v_offset integer:=least(greatest(coalesce(p_offset,0),0),10000);
 v_role text;v_rows jsonb;v_found int;v_branches jsonb;v_desk text;
begin
 select role into v_role from public.ff_profiles
 where user_id=auth.uid() and active;
 if v_role not in ('manager','supervisor','customer_service','cashier','driver','assembly') or v_role is null
 then raise exception 'حساب غير مخوّل' using errcode='42501';end if;
 if v_start>v_end or v_start<'2020-01-01'::date or v_end>'2100-01-01'::date
    or v_end-v_start>366 then raise exception 'اختر نطاق تاريخ صحيحًا لا يتجاوز 366 يومًا';end if;
 if p_branch is not null and not exists(
  select 1 from public.ff_branches where id=p_branch and active
 ) then raise exception 'فرع غير صحيح';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',b.id,'code',b.code,'name',b.name)
                  order by b.code),'[]'::jsonb)
 into v_branches from public.ff_branches b where b.active and (
  v_role='manager'
  or (v_role='supervisor' and ff_private.a10_branch_visible(v_role,b.id))
  or (v_role='customer_service' and (
     not exists(select 1 from public.ff_user_branches ub where ub.user_id=auth.uid())
     or exists(select 1 from public.ff_user_branches ub where ub.user_id=auth.uid() and ub.branch_id=b.id)))
  or (v_role='cashier' and exists(select 1 from public.ff_user_branches ub where ub.user_id=auth.uid() and ub.branch_id=b.id))
  or (v_role='assembly' and exists(select 1 from public.ff_v9_assembly_access a where a.user_id=auth.uid() and a.branch_id=b.id and a.enabled))
  or (v_role='driver' and exists(select 1 from public.ff38_driver_links l join public.ff_drivers d on d.id=l.driver_id where l.user_id=auth.uid() and d.branch_id=b.id))
 );
 select sd.desk_code into v_desk from public.ff_luxe_cashier_staff_desks sd where sd.user_id=auth.uid();
 with scoped as (
   select o.id,o.order_number,o.branch_id,o.status,o.created_at,o.delivered_at,
      o.phone_snapshot,o.area_snapshot,o.notes,o.cancel_reason,
      o.items_total,o.delivery_fee,o.total,o.driver_id as fallback_driver,
      t.driver_id,t.phase,t.cashier_stage,t.assigned_at,t.delivered_at as task_delivered_at,
      coalesce(nullif(dt.customer_name,''),nullif(c.name,''),'عميل') as customer_name,
      coalesce(nullif(dt.full_address,''),nullif(o.area_snapshot,''),'') as address,
      coalesce(nullif(d.name,''),'لم يحدد') as driver_name,
      coalesce(nullif(created_staff.display_name,''),'غير محدد') as customer_service_name,
      coalesce(nullif(receiving_cashier.display_name,''),'بانتظار استلام الكاشير') as cashier_employee_name,
      coalesce(nullif(btrim(r.invoice_ref),''),late.invoice_ref) as invoice_ref,
      rt.stars as role_rating,case when rt.rater_id=auth.uid() or v_role='manager' then rt.note else null end as role_rating_note,
      (v_role='cashier' and r.received_by=auth.uid() and t.cashier_stage='handed_over' and o.status not in ('cancelled','canceled','closed') and not exists(select from ff_private.a10_cashier_coordination c0 where c0.order_id=o.id)) as can_rate_coordination,
      (select stars from ff_private.a10_cashier_coordination c0 where c0.order_id=o.id and c0.cashier_user_id=auth.uid()) as coordination_stars,
      fb.overall_stars as driver_feedback,
      (select count(*) from public.ff41_cases fc where fc.order_id=o.id and fc.kind='customer_complaint') as cases
   from public.ff_orders o
   left join public.ff38_delivery_tasks t on t.order_id=o.id
   left join public.ff49_order_details dt on dt.order_id=o.id
   left join public.ff_customers c on c.id=o.customer_id
   left join public.ff_drivers d on d.id=coalesce(t.driver_id,o.driver_id)
   left join public.ff49_cashier_receipts r on r.order_id=o.id
   left join public.ff_profiles created_staff on created_staff.user_id=o.created_by
   left join public.ff_profiles receiving_cashier on receiving_cashier.user_id=coalesce(r.received_by,r.invoiced_by)
   left join public.ff_luxe_late_invoice_refs late on late.order_id=o.id
   left join public.ff51_driver_ratings rt on rt.order_id=o.id and rt.rater_role=v_role
   left join public.ff_luxe_driver_feedback fb on fb.order_id=o.id and fb.driver_user_id=auth.uid()
   where o.order_type='delivery'
    and (o.status in ('delivered','cancelled','canceled','closed')
       or (t.cashier_stage='handed_over' and o.status not in ('cancelled','canceled','closed')))
    and o.business_date between v_start and v_end
    and (p_branch is null or o.branch_id=p_branch)
    and ff_private.ff_luxe_completed_can_view(o.id)
   order by o.created_at desc,o.id desc
   limit v_limit+1 offset v_offset
 ), paged as (
   select s.*,row_number() over(order by s.created_at desc,s.id desc) seq from scoped s
 )
 select count(*),coalesce(jsonb_agg(jsonb_build_object(
   'id',p.id,'number',p.order_number,'branch_id',p.branch_id,'status',p.status,
   'phase',p.phase,'cashier_stage',p.cashier_stage,'created_at',p.created_at,
   'assigned_at',p.assigned_at,'delivered_at',coalesce(p.delivered_at,p.task_delivered_at),
   'customer_name',p.customer_name,'phone',p.phone_snapshot,'area',p.area_snapshot,
   'full_address',p.address,'notes',p.notes,'cancel_reason',p.cancel_reason,
   'driver_id',coalesce(p.driver_id,p.fallback_driver),'driver_name',p.driver_name,
   'customer_service_name',p.customer_service_name,'cashier_employee_name',p.cashier_employee_name,
   'items_total',p.items_total,'delivery_fee',p.delivery_fee,'total',p.total,
   'invoice_ref',p.invoice_ref,'role_rating',p.role_rating,
   'role_rating_note',p.role_rating_note,'driver_feedback',p.driver_feedback,'can_rate_coordination',coalesce(p.can_rate_coordination,false),'coordination_stars',p.coordination_stars,
   'case_count',p.cases,
   'items',coalesce((select jsonb_agg(jsonb_build_object(
       'name',i.item_name,'qty',i.quantity,'price',i.unit_price,
       'line_total',i.line_total,'notes',i.item_notes) order by i.id)
     from public.ff_order_items i where i.order_id=p.id),'[]'::jsonb)
 ) order by p.seq) filter(where p.seq<=v_limit),'[]'::jsonb)
 into v_found,v_rows from paged p;
 return jsonb_build_object(
  'items',coalesce(v_rows,'[]'::jsonb),'has_more',v_found>v_limit,
  'offset',v_offset,'limit',v_limit,'from',v_start,'to',v_end,'branches',v_branches,
  'role',v_role,'cashier_desk',v_desk
 );
end;
$function$;
