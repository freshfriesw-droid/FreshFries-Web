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
  v_role in ('manager','supervisor')
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
$function$
;
CREATE OR REPLACE FUNCTION public.ff_luxe_completed_universal_action(p_order uuid, p_action text, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_role text;v_order public.ff_orders%rowtype;
 v_stage text;v_driver uuid;v_receipt boolean;v_current text;v_ref text;
 v_stars integer;v_note text;v_subject text;v_description text;
 v_category text;v_priority text;v_id uuid;v_rating record;
begin
 select role into v_role from public.ff_profiles where user_id=auth.uid() and active;
 if v_role not in ('manager','supervisor','customer_service','cashier','driver','assembly')
   or not ff_private.ff_luxe_completed_can_view(p_order)
 then raise exception 'الطلب غير مصرح به لهذا الحساب' using errcode='42501';end if;
 if p_action not in ('invoice','rating','report') or jsonb_typeof(p_payload)<>'object'
 then raise exception 'الإجراء أو البيانات غير صالحة';end if;
 select * into v_order from public.ff_orders o where o.id=p_order for update;
 select t.cashier_stage,t.driver_id into v_stage,v_driver
 from public.ff38_delivery_tasks t where t.order_id=p_order;
 if p_action='invoice' then
  if v_order.status in ('cancelled','canceled','closed') or
     not (v_order.status='delivered' or v_stage='handed_over')
  then raise exception 'لا يمكن توثيق فاتورة لطلب ملغي أو غير مكتمل';end if;
  v_ref:=btrim(coalesce(p_payload->>'invoice',''));
  if length(v_ref) not between 1 and 80 then raise exception 'رقم الفاتورة من 1 إلى 80 حرفًا';end if;
  select true,r.invoice_ref into v_receipt,v_current
  from public.ff49_cashier_receipts r where r.order_id=p_order for update;
  if nullif(btrim(coalesce(v_current,'')),'') is not null
    or exists(select 1 from public.ff_luxe_late_invoice_refs where order_id=p_order)
  then raise exception 'تم تسجيل رقم فاتورة سابقًا ولا يمكن تغييره من الاستكمال';end if;
  if coalesce(v_receipt,false) then
   update public.ff49_cashier_receipts
   set invoice_ref=v_ref,invoiced_by=auth.uid(),invoiced_at=now()
   where order_id=p_order;
  else
   insert into public.ff_luxe_late_invoice_refs(order_id,invoice_ref,entered_by)
   values(p_order,v_ref,auth.uid());
  end if;
  insert into public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
  values(auth.uid(),'completed_invoice_backfill','delivery_order',p_order::text,v_order.branch_id,
         jsonb_build_object('invoice_ref',v_ref,'role',v_role));
  return jsonb_build_object('saved',true,'action','invoice');
 end if;
 if p_action='rating' then
  if v_order.status in ('cancelled','canceled','closed') or v_stage<>'handed_over'
     or v_driver is null then raise exception 'التقييم بعد تسليم الطلب للموصل فقط';end if;
  v_note:=left(btrim(coalesce(p_payload->>'note','')),500);
  if v_role='driver' then
    if v_order.status<>'delivered' then raise exception 'تقييم الموصل بعد التسليم فقط';end if;
    if exists(select 1 from public.ff_luxe_driver_feedback fb
      where fb.order_id=p_order and fb.driver_user_id=auth.uid()) then
      raise exception 'تم تسجيل تقييمك مسبقًا';end if;
    if not exists(select 1 from public.ff38_driver_links l
       where l.user_id=auth.uid() and l.driver_id=v_driver) then
      raise exception 'الموصل لا يستطيع تقييم طلب غير مسند له' using errcode='42501';end if;
    if exists(select 1 from jsonb_array_elements_text(jsonb_build_array(
      p_payload->>'cs',p_payload->>'cashier',p_payload->>'customer',p_payload->>'overall'
    )) elem where elem is null or elem !~ '^[1-5]$') then
      raise exception 'اختر كل التقييمات من 1 إلى 5';end if;
    insert into public.ff_luxe_driver_feedback(
      order_id,driver_user_id,customer_service_stars,cashier_stars,customer_stars,overall_stars,note)
    values(p_order,auth.uid(),(p_payload->>'cs')::integer,(p_payload->>'cashier')::integer,
      (p_payload->>'customer')::integer,(p_payload->>'overall')::integer,v_note);
  else
    if v_role='customer_service' and v_order.created_by is distinct from auth.uid() then raise exception 'تقييم الطلب بواسطة منشئه فقط' using errcode='42501';end if;
    if coalesce(p_payload->>'stars','') !~ '^[1-5]$' then
      raise exception 'اختر تقييمًا من 1 إلى 5';end if;
    v_stars:=(p_payload->>'stars')::integer;
    if exists(select 1 from public.ff51_driver_ratings
      where order_id=p_order and rater_role=v_role) then
      raise exception 'تم تسجيل تقييم هذا الدور مسبقًا';end if;
    insert into public.ff51_driver_ratings(order_id,driver_id,stars,note,rater_id,rater_role)
    values(p_order,v_driver,v_stars,v_note,auth.uid(),v_role);
  end if;
  return jsonb_build_object('saved',true,'action','rating','role',v_role);
 end if;
 -- All user roles can report their own completed delivery orders. Cases remain
 -- in the existing management review center, never in the order status workflow.
 v_category:=coalesce(p_payload->>'category','operational');
 v_priority:=coalesce(p_payload->>'priority','normal');
 v_subject:=btrim(coalesce(p_payload->>'subject',''));
 v_description:=btrim(coalesce(p_payload->>'description',''));
 if v_category not in ('operational','management_complaint')
    or v_priority not in ('low','normal','high')
 then raise exception 'نوع البلاغ أو الأولوية غير صالح';end if;
 if length(v_subject) not between 4 and 110
   or length(v_description) not between 10 and 4000
 then raise exception 'عنوان البلاغ من 4 أحرف والوصف من 10 أحرف على الأقل';end if;
 if (select count(*) from public.ff41_cases fc
   where fc.created_by=auth.uid() and fc.created_at>now()-interval '24 hours')>=20
 then raise exception 'تم بلوغ 20 بلاغًا خلال 24 ساعة';end if;
 insert into public.ff41_cases(kind,branch_id,order_id,subject,description,
   customer_name,customer_phone,contact_channel,priority,created_by)
 select 'customer_complaint',o.branch_id,o.id,
        left((case when v_category='management_complaint'
          then 'شكوى للإدارة: ' else 'بلاغ على طلب: ' end)||v_subject,140),
        v_description,
        nullif(coalesce(nullif(dt.customer_name,''),nullif(c.name,'')),''),
        nullif(o.phone_snapshot,''),'phone',v_priority,auth.uid()
 from public.ff_orders o
 left join public.ff49_order_details dt on dt.order_id=o.id
 left join public.ff_customers c on c.id=o.customer_id
 where o.id=p_order returning id into v_id;
 if v_id is null then raise exception 'تعذر إنشاء البلاغ';end if;
 return jsonb_build_object('saved',true,'action','report','case_id',v_id);
end;
$function$
;
