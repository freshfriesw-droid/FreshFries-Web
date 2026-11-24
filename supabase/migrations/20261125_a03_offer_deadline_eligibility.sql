-- FIX-09 / QA-12: match automatic dispatch eligibility when setting the deadline.
-- Keep already-issued deadlines fixed; exclude special/pinned couriers and previously
-- rejected/expired candidates, because automatic dispatch cannot re-offer to them.
create or replace function public.ff60_offer_deadline()
returns trigger language plpgsql security definer set search_path='' as $function$
declare
  v_branch uuid;
  v_has_backup boolean := false;
  v_fast integer := 180;
  v_slow integer := 600;
begin
  if new.status <> 'offered' then return new; end if;
  select branch_id into v_branch from public.ff_orders where id=new.order_id;
  if v_branch is null then raise exception 'تعذر تحديد فرع عرض التوصيل'; end if;
  select exists (
    select 1 from public.ff_drivers d
    join public.ff38_driver_presence p on p.driver_id=d.id
    where d.branch_id=v_branch and d.id<>new.driver_id and d.active
      and p.state='ready' and p.checked_in_at is not null
      and p.last_seen_at>now()-interval '90 seconds'
      and not exists(select 1 from ff_private.automatic_dispatch_exclusions e
                     where e.branch_id=v_branch and e.driver_id=d.id)
      and not exists(select 1 from public.ff38_delivery_tasks t
                     where t.driver_id=d.id and t.delivered_at is null)
      and not exists(select 1 from public.ff38_dispatch_offers f
                     where f.driver_id=d.id and f.status='offered' and f.expires_at>now())
      and not exists(select 1 from public.ff38_dispatch_offers prior
                     where prior.order_id=new.order_id and prior.driver_id=d.id
                       and prior.status in ('rejected','expired'))
  ) into v_has_backup;
  select fast_seconds,slow_seconds into v_fast,v_slow
    from public.ff60_offer_policy where singleton=1;
  new.expires_at:=coalesce(new.offered_at,now())+
    pg_catalog.make_interval(secs=>case when v_has_backup then coalesce(v_fast,180) else coalesce(v_slow,600) end);
  return new;
end $function$;
