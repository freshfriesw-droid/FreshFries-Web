-- A03 FIX-09 / FIX-11: prevent delegated reassignment outside the actor's branch.
-- Lock the order before the task, matching cancellation and dispatch paths.
create or replace function public.ff52_reassign_before_pos(p_order uuid,p_driver uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare
 v_task public.ff38_delivery_tasks%rowtype;
 v_order public.ff_orders%rowtype;
 v_role text;
begin
 select role into v_role from public.ff_profiles where user_id=auth.uid() and active;
 if v_role is null or not public.ff38_permission_allowed(auth.uid(),'assign_driver')
 or length(btrim(coalesce(p_reason,''))) not between 5 and 500 then
  raise exception 'السبب وصلاحية الإسناد مطلوبان' using errcode='42501';
 end if;
 if p_order is null then raise exception 'الطلب غير متاح لصلاحيات حسابك' using errcode='42501'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-o-'||p_order::text));
 select * into v_order from public.ff_orders where id=p_order for update;
 if v_order.id is null or not public.ff49_can_work_branch(v_order.branch_id,array[v_role]) then
  raise exception 'الطلب غير متاح لصلاحيات حسابك' using errcode='42501';
 end if;
 if v_order.order_type<>'delivery' or v_order.status in ('cancelled','delivered','reservation_completed') then
  raise exception 'حالة الطلب لا تسمح بنقل الموصل';
 end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-branch-rr-'||v_order.branch_id::text));
 select * into v_task from public.ff38_delivery_tasks where order_id=p_order for update;
 if p_driver is null or v_task.order_id is null or v_task.delivered_at is not null
 or v_task.cashier_stage<>'waiting' or v_task.phase<>'assigned' or v_task.driver_id=p_driver then
  raise exception 'النقل المباشر متاح قبل الفاتورة فقط';
 end if;
 if not exists(select 1 from public.ff_drivers d join public.ff38_driver_presence p on p.driver_id=d.id
 where d.id=p_driver and d.branch_id=v_order.branch_id and d.active=true and p.state in ('ready','busy')
 and p.checked_in_at is not null and p.last_seen_at>now()-interval '90 seconds') then
  raise exception 'موصل بديل غير متصل أو من فرع مختلف';
 end if;
 update public.ff38_delivery_tasks set driver_id=p_driver,updated_at=now() where order_id=p_order;
 update public.ff_orders set driver_id=p_driver,updated_at=now() where id=p_order;
 update public.ff38_driver_presence set state='busy',updated_at=now() where driver_id=p_driver;
 update public.ff38_driver_presence set state='ready',updated_at=now() where driver_id=v_task.driver_id
 and state='busy' and not exists(select 1 from public.ff38_delivery_tasks where driver_id=v_task.driver_id and delivered_at is null)
 and not exists(select 1 from public.ff38_dispatch_offers where driver_id=v_task.driver_id and status='offered' and expires_at>now());
 insert into public.ff52_driver_reassignment_audit(order_id,old_driver_id,new_driver_id,actor_id,reason)
 values(p_order,v_task.driver_id,p_driver,auth.uid(),btrim(p_reason));
 return jsonb_build_object('reassigned',true,'driver_id',p_driver);
end $function$;
revoke execute on function public.ff52_reassign_before_pos(uuid,uuid,text) from public,anon;
grant execute on function public.ff52_reassign_before_pos(uuid,uuid,text) to authenticated;
