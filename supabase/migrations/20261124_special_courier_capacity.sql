-- DEC-08. Identify the existing special courier once. All runtime checks use IDs.
create table ff_private.special_courier_capacity (
 driver_id uuid primary key references public.ff_drivers(id),
 capacity integer not null default 5 check(capacity > 0),
 revision bigint not null default 0
);
revoke all on ff_private.special_courier_capacity from public, anon, authenticated;
do $seed$
declare special_id uuid;
begin
 select d.id into strict special_id from public.ff_drivers d join public.ff_branches b on b.id=d.branch_id
 where b.code='cairo' and d.active and translate(trim(d.name),'أإآ','ااا')='ابراهيم الحداد';
 insert into ff_private.special_courier_capacity(driver_id) values(special_id);
end $seed$;

create function ff_private.special_courier_load(p_driver uuid,p_except uuid default null)
returns integer language sql volatile set search_path='' as $$
 select count(*)::integer from (
  select t.order_id from public.ff38_delivery_tasks t join public.ff_orders o on o.id=t.order_id
  where t.driver_id=p_driver and t.delivered_at is null and t.phase<>'delivered' and o.status not in ('delivered','cancelled','reservation_completed')
  union
  select f.order_id from public.ff38_dispatch_offers f join public.ff_orders o on o.id=f.order_id
  where f.driver_id=p_driver and f.status='offered' and f.expires_at>now()
  and o.status not in ('delivered','cancelled','reservation_completed')
 ) active where order_id is distinct from p_except;
$$;
revoke all on function ff_private.special_courier_load(uuid,uuid) from public,anon,authenticated;

create function ff_private.guard_special_courier_capacity() returns trigger
language plpgsql security definer set search_path='' as $$
declare lim integer; used integer; reason text; branch uuid;
begin
 if tg_table_name='ff38_dispatch_offers' then
  if new.status<>'offered' or new.expires_at<=now() then return new; end if;
 elsif new.phase='delivered' then return new;
 elsif tg_op='UPDATE' then
  if old.driver_id=new.driver_id and old.order_id=new.order_id and old.phase<>'delivered' then return new; end if;
 end if;
 update ff_private.special_courier_capacity set revision=revision+1 where driver_id=new.driver_id returning capacity into lim;
 if not found then return new; end if;
 select branch_id into branch from public.ff_orders where id=new.order_id;
 if not exists(select 1 from public.ff_drivers where id=new.driver_id and branch_id=branch and active) then
  raise exception 'الموصل الخاص خارج الفرع أو غير نشط';
 end if;
 used:=ff_private.special_courier_load(new.driver_id,new.order_id);
 if used<lim then return new; end if;
 reason:=nullif(trim(current_setting('ff_luxe.special_override_reason',true)),'');
 if reason is null or current_setting('ff_luxe.special_override_driver',true) is distinct from new.driver_id::text
 or not exists(select 1 from public.ff_profiles where user_id=auth.uid() and active and role='manager')
 then raise exception 'اكتمل سقف الموصل الخاص (%). يلزم تجاوز معتمد مع سبب',lim; end if;
 insert into public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 values(auth.uid(),'special_courier_capacity_override','order',new.order_id::text,branch,
 jsonb_build_object('driver_id',new.driver_id,'capacity',lim,'previous_active',used,'reason',reason));
 return new;
end $$;
revoke all on function ff_private.guard_special_courier_capacity() from public,anon,authenticated;
create trigger ff_special_offer_capacity before insert or update of driver_id,order_id,status,expires_at on public.ff38_dispatch_offers
 for each row execute function ff_private.guard_special_courier_capacity();
create trigger ff_special_task_capacity before insert or update of driver_id,order_id,phase on public.ff38_delivery_tasks
 for each row execute function ff_private.guard_special_courier_capacity();

create function public.ff_special_courier_status(p_driver uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare role_name text; branch uuid; lim integer;
begin
 select role into role_name from public.ff_profiles where user_id=auth.uid() and active;
 select d.branch_id,c.capacity into branch,lim from public.ff_drivers d
 join ff_private.special_courier_capacity c on c.driver_id=d.id where d.id=p_driver;
 if lim is null then return null; end if;
 if role_name is null or role_name not in ('manager','customer_service','supervisor')
 or not public.ff49_can_work_branch(branch,array[role_name]) then raise exception 'غير مصرح' using errcode='42501'; end if;
 return jsonb_build_object('capacity',lim,'active',ff_private.special_courier_load(p_driver),'can_manage',role_name='manager');
end $$;
create function public.ff_set_special_courier_capacity(p_driver uuid,p_capacity integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare branch uuid; previous integer;
begin
 if not exists(select 1 from public.ff_profiles where user_id=auth.uid() and role='manager' and active)
 then raise exception 'تعديل السقف للمدير العام' using errcode='42501'; end if;
 select branch_id into strict branch from public.ff_drivers where id=p_driver;
 if not public.ff49_can_work_branch(branch,array['manager']) then raise exception 'الفرع خارج الصلاحية'; end if;
 select capacity into strict previous from ff_private.special_courier_capacity where driver_id=p_driver for update;
 if p_capacity is null or p_capacity<1 then raise exception 'السقف يجب أن يكون عددًا صحيحًا موجبًا'; end if;
 update ff_private.special_courier_capacity set capacity=p_capacity where driver_id=p_driver;
 insert into public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 values(auth.uid(),'special_courier_capacity_changed','driver',p_driver::text,branch,jsonb_build_object('before',previous,'after',p_capacity));
 return public.ff_special_courier_status(p_driver);
end $$;

create function public.ff_confirm_pinned_order(p_driver uuid,p_branch uuid,p_desk text,p_phone text,p_area text,p_items jsonb,p_notes text,p_override_reason text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; reason text:=trim(coalesce(p_override_reason,''));
begin
 if auth.uid() is null or not exists(select 1 from public.ff_profiles where user_id=auth.uid() and active and role in ('manager','customer_service'))
 then raise exception 'إنشاء الطلب غير مصرح به' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtext('ff62-pin-cairo'));
 if p_driver is null or not exists(select 1 from public.ff62_pinned_drivers where branch_id=p_branch and driver_id=p_driver)
 then raise exception 'تغير الموصل المثبت؛ أعد المعاينة'; end if;
 if reason<>'' and (length(reason)>300 or not exists(select 1 from public.ff_profiles where user_id=auth.uid() and role='manager' and active))
 then raise exception 'التجاوز يتطلب مديرًا وسببًا حتى 300 حرف' using errcode='42501'; end if;
 perform set_config('ff_luxe.special_override_reason',reason,true);
 perform set_config('ff_luxe.special_override_driver',p_driver::text,true);
 result:=public.ff_luxe_create_pinned_order_in_desk(p_branch,p_desk,p_phone,p_area,p_items,0,p_notes);
 perform set_config('ff_luxe.special_override_reason','',true);
 perform set_config('ff_luxe.special_override_driver','',true);
 return result;
end $$;
revoke all on function public.ff_special_courier_status(uuid),public.ff_set_special_courier_capacity(uuid,integer),public.ff_confirm_pinned_order(uuid,uuid,text,text,text,jsonb,text,text) from public,anon;
grant execute on function public.ff_special_courier_status(uuid),public.ff_set_special_courier_capacity(uuid,integer),public.ff_confirm_pinned_order(uuid,uuid,text,text,text,jsonb,text,text) to authenticated;

-- Share the same exclusions between automatic dispatch and its candidate preview.
create view ff_private.automatic_dispatch_exclusions as
 select branch_id,driver_id from public.ff62_pinned_drivers
 union select d.branch_id,c.driver_id from ff_private.special_courier_capacity c join public.ff_drivers d on d.id=c.driver_id;
revoke all on ff_private.automatic_dispatch_exclusions from public,anon,authenticated;
do $dispatch$
declare f record; definition text;
begin
 for f in select p.oid,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('ff38__offer_next','ff_luxe_dispatch_preview') loop
  definition:=pg_get_functiondef(f.oid);
  if position('public.ff62_pinned_drivers pin' in definition)=0 then raise exception 'Unexpected dispatch definition: %',f.proname; end if;
  execute replace(definition,'public.ff62_pinned_drivers pin','ff_private.automatic_dispatch_exclusions pin');
 end loop;
end $dispatch$;

-- Preserve legacy presence and branch checks. The special policy alone sets its ceiling.
do $legacy$
declare target regprocedure; source text; predicate text;
begin
 for target,predicate in select * from (values
  ('public.ff49_driver_capacity_guard()'::regprocedure,'IF v_active+v_reserved>=5 THEN'),
  ('public.ff60_driver_capacity_safety()'::regprocedure,'IF v_existing+v_offers>=5 THEN')
 ) x(target,predicate) loop
  source:=pg_get_functiondef(target);
  if position(predicate in source)=0 then raise exception 'Unexpected capacity guard: %',target; end if;
  execute replace(source,predicate,replace(predicate,' THEN',' AND NOT EXISTS (SELECT 1 FROM ff_private.special_courier_capacity WHERE driver_id=NEW.driver_id) THEN'));
 end loop;
end $legacy$;
