CREATE OR REPLACE FUNCTION public.ff_luxe_cashier_completed_orders(p_limit integer DEFAULT 30, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_limit integer:=least(greatest(coalesce(p_limit,30),1),60);
 v_offset integer:=least(greatest(coalesce(p_offset,0),0),3000);
 v_result jsonb;v_count integer;v_total integer;
begin
 if auth.uid() is null or not exists(
  select 1 from public.ff_profiles p where p.user_id=auth.uid() and p.active and p.role='cashier'
 ) then raise exception 'الطلبات المنتهية مخصصة للكاشير المخول' using errcode='42501'; end if;
 with recent as (
   select o.id,o.order_number,o.branch_id,o.status,o.created_at,o.updated_at,o.delivered_at,
          o.phone_snapshot,o.area_snapshot,o.notes,o.delivery_fee,o.items_total,o.total,o.cancel_reason,
          o.customer_id,o.driver_id as base_driver_id,
          t.driver_id,t.phase,t.cashier_stage,t.assigned_at,t.delivered_at as driver_delivered_at,
          coalesce(nullif(dtl.customer_name,''),nullif(c.name,''),'عميل') as customer_name,
          coalesce(nullif(dtl.full_address,''),nullif(o.area_snapshot,''),'') as full_address,
          coalesce(nullif(d.name,''),'لم يُحدد') as driver_name,
          coalesce(nullif(btrim(r.invoice_ref),''),late.invoice_ref) as invoice_ref,
          r.received_at as cashier_received_at,r.invoiced_at,
          late.entered_at as late_invoice_entered_at,
          rating.stars as cashier_rating,case when rating.rater_id=auth.uid() then rating.note else null end as cashier_rating_note,
          (r.received_by=auth.uid() and t.cashier_stage='handed_over' and o.status not in ('cancelled','canceled','closed') and not exists(select from ff_private.a10_cashier_coordination c0 where c0.order_id=o.id)) as can_rate_coordination,
          (select stars from ff_private.a10_cashier_coordination c0 where c0.order_id=o.id and c0.cashier_user_id=auth.uid()) as coordination_stars,
          (select count(*) from public.ff41_cases cases where cases.order_id=o.id and cases.kind='customer_complaint') as case_count
   from public.ff_orders o
   left join public.ff38_delivery_tasks t on t.order_id=o.id
   left join public.ff49_order_details dtl on dtl.order_id=o.id
   left join public.ff_customers c on c.id=o.customer_id
   left join public.ff_drivers d on d.id=coalesce(t.driver_id,o.driver_id)
   left join public.ff49_cashier_receipts r on r.order_id=o.id
   left join public.ff_luxe_late_invoice_refs late on late.order_id=o.id
   left join public.ff51_driver_ratings rating on rating.order_id=o.id and rating.rater_role='cashier'
   where o.order_type='delivery'
     and (o.status in ('delivered','cancelled','canceled','closed')
          or (t.cashier_stage='handed_over' and o.status not in ('cancelled','canceled','closed')))
     and ff_private.cashier_can_view_completed(o.id)
   order by o.created_at desc,o.id desc
   limit v_limit+1 offset v_offset
 ), paged as (
   select rec.*,row_number() over(order by rec.created_at desc,rec.id desc) as row_num from recent rec
 ), records as (
   select p.row_num,
    jsonb_build_object(
      'id',p.id,'number',p.order_number,'branch_id',p.branch_id,
      'status',p.status,'phase',p.phase,'cashier_stage',p.cashier_stage,
      'created_at',p.created_at,'assigned_at',p.assigned_at,
      'delivered_at',coalesce(p.delivered_at,p.driver_delivered_at),
      'customer_name',p.customer_name,'phone',p.phone_snapshot,'area',p.area_snapshot,
      'full_address',p.full_address,'notes',p.notes,'cancel_reason',p.cancel_reason,
      'driver_id',coalesce(p.driver_id,p.base_driver_id),'driver_name',p.driver_name,
      'items_total',p.items_total,'delivery_fee',p.delivery_fee,'total',p.total,
      'invoice_ref',p.invoice_ref,'invoiced_at',p.invoiced_at,
      'cashier_received_at',p.cashier_received_at,'late_invoice_entered_at',p.late_invoice_entered_at,
      'cashier_rating',p.cashier_rating,'cashier_rating_note',p.cashier_rating_note,
      'can_rate_coordination',coalesce(p.can_rate_coordination,false),'coordination_stars',p.coordination_stars,
      'case_count',p.case_count,
      'items',coalesce((
        select jsonb_agg(jsonb_build_object(
          'name',i.item_name,'qty',i.quantity,'price',i.unit_price,
          'line_total',i.line_total,'notes',i.item_notes
        ) order by i.id)
        from public.ff_order_items i where i.order_id=p.id
      ),'[]'::jsonb)
    ) as detail
   from paged p where p.row_num<=v_limit
 )
 select coalesce(jsonb_agg(detail order by row_num),'[]'::jsonb)
 into v_result from records;
 with scope as (
   select o.id from public.ff_orders o
   left join public.ff38_delivery_tasks t on t.order_id=o.id
   where o.order_type='delivery'
     and (o.status in ('delivered','cancelled','canceled','closed')
       or (t.cashier_stage='handed_over' and o.status not in ('cancelled','canceled','closed')))
     and ff_private.cashier_can_view_completed(o.id)
   order by o.created_at desc,o.id desc
   limit v_limit+1 offset v_offset
 )
 select count(*) into v_count from scope;
 return jsonb_build_object('items',coalesce(v_result,'[]'::jsonb),
                           'offset',v_offset,'limit',v_limit,'has_more',v_count>v_limit);
end;
$function$
;
