-- Run as a transaction and roll back all fixtures, including queued events.
begin;
do $test$
declare branch uuid; driver uuid; other_driver uuid; actor uuid:=gen_random_uuid(); orders uuid[]:='{}'; item uuid; rejected boolean:=false; i int;
begin
 insert into public.ff_branches(code,name) values('qa-'||gen_random_uuid(),'اختبار السعة') returning id into branch;
 insert into public.ff_drivers(name,branch_id) values('موصل اختبار',branch) returning id into driver;
 insert into public.ff_drivers(name,branch_id) values('موصل عادي',branch) returning id into other_driver;
 insert into public.ff38_driver_presence(driver_id) values(driver),(other_driver) on conflict do nothing;
 insert into ff_private.special_courier_capacity(driver_id) values(driver);
 for i in 1..8 loop
  insert into public.ff_orders(order_number,branch_id,phone_snapshot,business_date)
  values(i,branch,'000000000',current_date) returning id into item;
  orders:=array_append(orders,item);
 end loop;
 for i in 1..4 loop
  insert into public.ff38_delivery_tasks(order_id,driver_id) values(orders[i],driver);
 end loop;
 insert into public.ff38_dispatch_offers(order_id,driver_id,expires_at) values(orders[5],driver,now()+interval '3 minutes');
 insert into public.ff38_dispatch_offers(order_id,driver_id,offered_at,expires_at) values(orders[7],driver,now()-interval '1 hour',now()-interval '1 minute');
 if ff_private.special_courier_load(driver)<>5 then raise exception 'expected five active assignments and offers'; end if;
 begin
  insert into public.ff38_delivery_tasks(order_id,driver_id) values(orders[6],driver);
 exception when raise_exception then
  if sqlerrm not like 'اكتمل سقف%' then raise; end if;
  rejected:=true;
 end;
 if not rejected then raise exception 'sixth assignment accepted without override'; end if;
 -- Moving an existing offer to a task must not count the same order twice.
 insert into public.ff38_delivery_tasks(order_id,driver_id) values(orders[5],driver);
 update public.ff38_dispatch_offers set status='accepted' where order_id=orders[5];
 insert into public.ff38_delivery_tasks(order_id,driver_id) values(orders[8],other_driver);
 insert into auth.users(id) values(actor);
 insert into public.ff_profiles(user_id,display_name,role,active) values(actor,'مدير الاختبار','manager',true)
 on conflict(user_id) do update set role='manager',active=true;
 perform set_config('request.jwt.claim.sub',actor::text,true);
 perform set_config('ff_luxe.special_override_driver',driver::text,true);
 perform set_config('ff_luxe.special_override_reason','استثناء اختباري',true);
 insert into public.ff38_delivery_tasks(order_id,driver_id) values(orders[6],driver);
 if not exists(select 1 from public.ff_audit_log where actor_id=actor and entity_id=orders[6]::text and action='special_courier_capacity_override'
  and details->>'reason'='استثناء اختباري') then raise exception 'missing override audit'; end if;
 perform set_config('ff_luxe.special_override_reason','',true);
 perform public.ff_set_special_courier_capacity(driver,7);
 if (public.ff_special_courier_status(driver)->>'capacity')::int<>7 then raise exception 'capacity change failed'; end if;
 update public.ff_orders set status='cancelled' where id=orders[1];
 if ff_private.special_courier_load(driver)<>5 then raise exception 'delivery did not release capacity'; end if;
 update public.ff38_delivery_tasks set driver_id=other_driver where order_id=orders[2];
 if ff_private.special_courier_load(driver)<>4 then raise exception 'reassignment did not release capacity'; end if;
end $test$;
rollback;
