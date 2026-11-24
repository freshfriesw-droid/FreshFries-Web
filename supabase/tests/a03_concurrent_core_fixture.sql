-- TEST ONLY. Isolated PostgreSQL database on CI; never run against production.
-- Minimal dependency schema. Core dispatch/reply/deadline/capacity functions below
-- are snapshots of the live database (25 Nov 2026), with whitespace normalized.
-- auth.uid and route priority are test doubles; no actual employee or customer data.
create schema auth;
create schema ff_private;
create function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
create table public.ff_profiles(user_id uuid primary key, role text not null, active boolean not null default true);
create table public.ff_orders(
 id uuid primary key,branch_id uuid not null,order_type text not null default 'delivery',
 status text not null default 'new',area_snapshot text,driver_id uuid,
 sent_at timestamptz,updated_at timestamptz default now(),allow_driver_reject boolean not null default false
);
create table public.ff_drivers(id uuid primary key,branch_id uuid not null,active boolean not null default true,sort_order int not null default 0);
create table public.ff38_driver_presence(driver_id uuid primary key references public.ff_drivers,
 state text not null default 'offline',checked_in_at timestamptz,last_seen_at timestamptz,updated_at timestamptz default now());
create table public.ff38_driver_links(user_id uuid primary key references public.ff_profiles,driver_id uuid not null references public.ff_drivers);
create table public.ff38_delivery_tasks(
 order_id uuid primary key references public.ff_orders,driver_id uuid not null references public.ff_drivers,
 phase text not null default 'assigned',assigned_at timestamptz not null default now(),delivered_at timestamptz
);
create table public.ff38_dispatch_offers(
 id uuid primary key default gen_random_uuid(),order_id uuid not null references public.ff_orders,
 driver_id uuid not null references public.ff_drivers,status text not null default 'offered',
 offered_at timestamptz not null default now(),expires_at timestamptz not null,created_by uuid,
 responded_at timestamptz,reject_reason text
);
create unique index ff38_one_open_offer_per_order on public.ff38_dispatch_offers(order_id) where status='offered';
create table public.ff60_offer_policy(singleton int primary key,fast_seconds int,slow_seconds int);
insert into public.ff60_offer_policy values(1,180,600);
create table public.ff62_pinned_drivers(branch_id uuid primary key,driver_id uuid not null references public.ff_drivers);
create table ff_private.special_courier_capacity(driver_id uuid primary key references public.ff_drivers,
 capacity int not null default 5 check(capacity>0),revision bigint not null default 0);
create view ff_private.automatic_dispatch_exclusions as
 select branch_id,driver_id from public.ff62_pinned_drivers
 union select d.branch_id,c.driver_id from ff_private.special_courier_capacity c join public.ff_drivers d on d.id=c.driver_id;
create table public.ff_audit_log(actor_id uuid,action text,entity_type text,entity_id text,branch_id uuid,details jsonb);
create function public.ff52_is_route_priority(uuid,uuid,text) returns boolean language sql stable as $$ select false $$;

CREATE OR REPLACE FUNCTION ff_private.special_courier_load(p_driver uuid, p_except uuid DEFAULT NULL::uuid)
 RETURNS integer
 LANGUAGE sql
 SET search_path TO ''
AS $function$
 select count(*)::integer from (
 select t.order_id from public.ff38_delivery_tasks t join public.ff_orders o on o.id=t.order_id
 where t.driver_id=p_driver and t.delivered_at is null and t.phase<>'delivered' and o.status not in ('delivered','cancelled','reservation_completed')
 union
 select f.order_id from public.ff38_dispatch_offers f join public.ff_orders o on o.id=f.order_id
 where f.driver_id=p_driver and f.status='offered' and f.expires_at>now()
 and o.status not in ('delivered','cancelled','reservation_completed')
 ) active where order_id is distinct from p_except;
$function$;

CREATE OR REPLACE FUNCTION ff_private.guard_special_courier_capacity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.ff49_driver_capacity_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 DECLARE v_driver_branch uuid; v_order_branch uuid; v_active integer; v_reserved integer;
 BEGIN
 IF NEW.delivered_at IS NOT NULL THEN RETURN NEW; END IF;
 IF TG_OP='UPDATE' AND OLD.driver_id IS NOT DISTINCT FROM NEW.driver_id AND OLD.delivered_at IS NULL THEN
 RETURN NEW;
 END IF;
 SELECT branch_id INTO v_driver_branch FROM public.ff_drivers WHERE id=NEW.driver_id AND active=true FOR UPDATE;
 SELECT branch_id INTO v_order_branch FROM public.ff_orders WHERE id=NEW.order_id;
 IF v_driver_branch IS NULL OR v_order_branch IS NULL OR v_order_branch IS DISTINCT FROM v_driver_branch THEN
 RAISE EXCEPTION 'الإسناد يتطلب موصلًا فعالًا من نفس فرع الطلب';
 END IF;
 SELECT count(*)::int INTO v_active FROM public.ff38_delivery_tasks
 WHERE driver_id=NEW.driver_id AND delivered_at IS NULL AND order_id<>NEW.order_id;
 SELECT count(*)::int INTO v_reserved FROM public.ff38_dispatch_offers
 WHERE driver_id=NEW.driver_id AND order_id<>NEW.order_id
 AND status='offered' AND expires_at>now();
 IF v_active+v_reserved>=5 AND NOT EXISTS (SELECT 1 FROM ff_private.special_courier_capacity WHERE driver_id=NEW.driver_id) THEN
 RAISE EXCEPTION 'وصل الموصل للحد الأعلى خمسة طلبات أو حجوزات عروض نشطة';
 END IF;
 RETURN NEW;
 END $function$;

CREATE OR REPLACE FUNCTION public.ff60_driver_capacity_safety()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 DECLARE v_branch uuid;v_existing integer;v_offers integer;
 BEGIN
 IF TG_OP='UPDATE' AND NEW.driver_id IS NOT DISTINCT FROM OLD.driver_id THEN RETURN NEW; END IF;
 IF NEW.delivered_at IS NOT NULL THEN RETURN NEW; END IF;
 SELECT branch_id INTO v_branch FROM public.ff_orders WHERE id=NEW.order_id;
 IF v_branch IS NULL OR NOT EXISTS(
 SELECT 1 FROM public.ff_drivers d WHERE d.id=NEW.driver_id AND d.branch_id=v_branch AND d.active
 ) THEN
 RAISE EXCEPTION 'الموصل غير نشط أو ليس من فرع الطلب' USING ERRCODE='23514';
 END IF;
 PERFORM 1 FROM public.ff38_driver_presence WHERE driver_id=NEW.driver_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'لا يوجد سجل حضور للموصل' USING ERRCODE='23514'; END IF;
 SELECT count(*) INTO v_existing FROM public.ff38_delivery_tasks
 WHERE driver_id=NEW.driver_id AND delivered_at IS NULL AND order_id<>NEW.order_id;
 SELECT count(*) INTO v_offers FROM public.ff38_dispatch_offers
 WHERE driver_id=NEW.driver_id AND status='offered' AND expires_at>now()
 AND order_id<>NEW.order_id;
 IF v_existing+v_offers>=5 AND NOT EXISTS (SELECT 1 FROM ff_private.special_courier_capacity WHERE driver_id=NEW.driver_id) THEN
 RAISE EXCEPTION 'لا يمكن تجاوز خمسة طلبات أو عروض نشطة للموصل' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
 END $function$;

CREATE OR REPLACE FUNCTION public.ff60_offer_deadline()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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

CREATE OR REPLACE FUNCTION public.ff38_guard_driver_rejection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 BEGIN
 IF NEW.status='rejected' AND OLD.status IS DISTINCT FROM NEW.status THEN
 IF NOT EXISTS (SELECT 1 FROM public.ff_orders o
 WHERE o.id=NEW.order_id AND o.allow_driver_reject=true) THEN
 RAISE EXCEPTION 'رفض الطلب غير مسموح من خدمة العملاء' USING ERRCODE='42501';
 END IF;
 END IF;
 RETURN NEW;
 END $function$;

CREATE OR REPLACE FUNCTION public.ff38__offer_next(p_order uuid, p_driver uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 DECLARE v_order public.ff_orders%ROWTYPE; v_driver uuid; v_offer uuid; v_count int; v_eligible int; v_idle int; v_last timestamptz; v_used int; v_waiting int;
 BEGIN
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-o-' || p_order::text));
 SELECT * INTO v_order FROM public.ff_orders WHERE id=p_order FOR UPDATE;
 IF NOT FOUND OR v_order.order_type <> 'delivery' OR v_order.status IN ('delivered','cancelled','reservation_completed') THEN
 RETURN jsonb_build_object('state','not_dispatchable');
 END IF;
 -- Serialize all new offers/assignments in this branch across concurrent requests.
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-branch-rr-' || v_order.branch_id::text));
 IF EXISTS (SELECT 1 FROM public.ff38_delivery_tasks WHERE order_id=p_order) THEN
 RETURN jsonb_build_object('state','already_assigned');
 END IF;
 UPDATE public.ff38_dispatch_offers SET status='expired',responded_at=now()
 WHERE order_id=p_order AND status='offered' AND expires_at<=now();
 IF EXISTS(SELECT 1 FROM public.ff38_dispatch_offers WHERE order_id=p_order AND status='offered') THEN
 RETURN jsonb_build_object('state','pending');
 END IF;
 -- Eligible drivers are active, on shift, connected and belong to the SAME branch.
 -- When all eligible drivers already carry open deliveries, assign directly in
 -- round-robin order. This bypasses the acceptance timer and queue limits.
 SELECT count(*), count(*) FILTER (WHERE NOT EXISTS (
 SELECT 1 FROM public.ff38_delivery_tasks t
 WHERE t.driver_id=d.id AND t.delivered_at IS NULL))
 INTO v_eligible,v_idle
 FROM public.ff_drivers d JOIN public.ff38_driver_presence p ON p.driver_id=d.id
 WHERE d.branch_id=v_order.branch_id AND d.active=true
 AND (p_driver IS NOT NULL OR NOT EXISTS(SELECT 1 FROM ff_private.automatic_dispatch_exclusions pin WHERE pin.branch_id=v_order.branch_id AND pin.driver_id=d.id))
 AND p.state IN ('ready','busy') AND p.checked_in_at IS NOT NULL
 AND p.last_seen_at>now()-interval '90 seconds'
 AND (p_driver IS NULL OR d.id=p_driver);

 IF v_eligible>0 AND v_idle=0 THEN
 -- Branch allocation lock already held from the beginning of dispatch.
 SELECT d.id INTO v_driver
 FROM public.ff_drivers d
 JOIN public.ff38_driver_presence p ON p.driver_id=d.id
 CROSS JOIN LATERAL (
 SELECT count(*)::int AS active_count,
 count(*) FILTER (WHERE pg_catalog.lower(pg_catalog.btrim(o.area_snapshot)) = pg_catalog.lower(pg_catalog.btrim(v_order.area_snapshot)))::int AS same_area,
 count(*) FILTER (WHERE t.phase IN ('on_way','arrived'))::int AS onway
 FROM public.ff38_delivery_tasks t JOIN public.ff_orders o ON o.id=t.order_id
 WHERE t.driver_id=d.id AND t.delivered_at IS NULL
 ) a
 CROSS JOIN LATERAL (
 SELECT count(*)::int AS waiting_count FROM public.ff38_dispatch_offers f
 WHERE f.driver_id=d.id AND f.status='offered' AND f.expires_at>now()
 ) w
 WHERE d.branch_id=v_order.branch_id AND d.active=true
 AND (p_driver IS NOT NULL OR NOT EXISTS(SELECT 1 FROM ff_private.automatic_dispatch_exclusions pin WHERE pin.branch_id=v_order.branch_id AND pin.driver_id=d.id))
 AND p.state IN ('ready','busy') AND p.checked_in_at IS NOT NULL
 AND p.last_seen_at>now()-interval '90 seconds'
 AND (p_driver IS NULL OR d.id=p_driver)
 AND a.active_count>0
 AND a.active_count+w.waiting_count<5
 AND w.waiting_count=0
 AND (a.active_count<2 OR a.same_area>0)
 ORDER BY
 CASE WHEN public.ff52_is_route_priority(d.id,v_order.branch_id,v_order.area_snapshot) THEN 0 ELSE 1 END ASC,
 CASE WHEN a.same_area>0 THEN 0 ELSE 1 END ASC,
 CASE WHEN a.onway>0 THEN 0 ELSE 1 END ASC,
 a.active_count ASC,
 (SELECT max(t.assigned_at) FROM public.ff38_delivery_tasks t WHERE t.driver_id=d.id) ASC NULLS FIRST,
 d.sort_order ASC,d.id ASC
 LIMIT 1;
 IF v_driver IS NOT NULL THEN
 -- Lock driver presence and re-evaluate capacity after concurrent acceptances.
 PERFORM 1 FROM public.ff38_driver_presence WHERE driver_id=v_driver FOR UPDATE;
 SELECT count(*) INTO v_used FROM public.ff38_delivery_tasks
 WHERE driver_id=v_driver AND delivered_at IS NULL;
 SELECT count(*) INTO v_waiting FROM public.ff38_dispatch_offers
 WHERE driver_id=v_driver AND status='offered' AND expires_at>now();
 IF v_used+v_waiting>=5 THEN
 RETURN jsonb_build_object('state','queued','reason','driver_at_capacity');
 END IF;
 INSERT INTO public.ff38_delivery_tasks(order_id,driver_id) VALUES(p_order,v_driver);
 UPDATE public.ff_orders SET driver_id=v_driver,status='sent',sent_at=coalesce(sent_at,now()),updated_at=now() WHERE id=p_order;
 UPDATE public.ff38_driver_presence SET state='busy',updated_at=now() WHERE driver_id=v_driver;
 RETURN jsonb_build_object('state','assigned_cumulative','driver_id',v_driver,'order_id',p_order);
 END IF;
 -- The whole branch is busy and no safe cumulative candidate is available.
 RETURN jsonb_build_object('state','queued','reason','capacity_or_area');
 END IF;

 -- Normal offers: 10 minutes for acceptance. Prefer idle drivers.
 SELECT d.id INTO v_driver
 FROM public.ff_drivers d
 JOIN public.ff38_driver_presence p ON p.driver_id=d.id
 CROSS JOIN LATERAL (
 SELECT count(*)::int AS active_count,
 count(*) FILTER (WHERE pg_catalog.lower(pg_catalog.btrim(o.area_snapshot)) = pg_catalog.lower(pg_catalog.btrim(v_order.area_snapshot)))::int AS same_area,
 count(*) FILTER (WHERE t.phase IN ('on_way','arrived'))::int AS onway
 FROM public.ff38_delivery_tasks t JOIN public.ff_orders o ON o.id=t.order_id
 WHERE t.driver_id=d.id AND t.delivered_at IS NULL
 ) a
 CROSS JOIN LATERAL (
 SELECT count(*)::int AS waiting_count FROM public.ff38_dispatch_offers f
 WHERE f.driver_id=d.id AND f.status='offered' AND f.expires_at>now()
 ) w
 WHERE d.branch_id=v_order.branch_id AND d.active=true
 AND (p_driver IS NOT NULL OR NOT EXISTS(SELECT 1 FROM ff_private.automatic_dispatch_exclusions pin WHERE pin.branch_id=v_order.branch_id AND pin.driver_id=d.id))
 AND p.state IN ('ready','busy') AND p.checked_in_at IS NOT NULL
 AND p.last_seen_at>now()-interval '90 seconds'
 AND a.active_count+w.waiting_count<5
 AND (a.active_count+w.waiting_count<2 OR a.same_area>0)
 AND (p_driver IS NULL OR d.id=p_driver)
 AND NOT EXISTS(SELECT 1 FROM public.ff38_dispatch_offers y WHERE y.driver_id=d.id AND y.status='offered' AND y.expires_at>now())
 AND NOT EXISTS(SELECT 1 FROM public.ff38_dispatch_offers old
 WHERE old.order_id=p_order AND old.driver_id=d.id AND old.status IN ('rejected','expired'))
 ORDER BY
 CASE WHEN a.active_count+w.waiting_count=0 THEN 0 ELSE 1 END ASC,
 CASE WHEN public.ff52_is_route_priority(d.id,v_order.branch_id,v_order.area_snapshot) THEN 0 ELSE 1 END ASC,
 CASE WHEN a.same_area>0 THEN 0 ELSE 1 END ASC,
 CASE WHEN a.onway>0 THEN 0 ELSE 1 END ASC,
 a.active_count+w.waiting_count ASC,
 (SELECT max(offered_at) FROM public.ff38_dispatch_offers h WHERE h.driver_id=d.id) ASC NULLS FIRST,
 d.sort_order ASC,d.id ASC
 LIMIT 1;
 IF v_driver IS NULL THEN RETURN jsonb_build_object('state','queued','reason','no_eligible_driver'); END IF;
 PERFORM 1 FROM public.ff38_driver_presence WHERE driver_id=v_driver FOR UPDATE;
 SELECT count(*) INTO v_used FROM public.ff38_delivery_tasks WHERE driver_id=v_driver AND delivered_at IS NULL;
 SELECT count(*) INTO v_waiting FROM public.ff38_dispatch_offers
 WHERE driver_id=v_driver AND status='offered' AND expires_at>now();
 IF v_used+v_waiting>=5 THEN RETURN jsonb_build_object('state','queued','reason','driver_at_capacity'); END IF;
 INSERT INTO public.ff38_dispatch_offers(order_id,driver_id,expires_at,created_by)
 VALUES(p_order,v_driver,now()+interval '10 minutes',auth.uid()) RETURNING id INTO v_offer;
 RETURN jsonb_build_object('state','offered','offer_id',v_offer,'driver_id',v_driver);

 END $function$;

CREATE OR REPLACE FUNCTION public.ff38_driver_reply(p_offer uuid, p_accept boolean, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 DECLARE v_driver uuid;v_offer public.ff38_dispatch_offers%ROWTYPE;v_result jsonb;v_order_id uuid;v_branch uuid;
 BEGIN
 SELECT l.driver_id INTO v_driver FROM public.ff38_driver_links l JOIN public.ff_profiles p ON p.user_id=l.user_id AND p.role='driver' AND p.active WHERE l.user_id=auth.uid();
 IF v_driver IS NULL THEN RAISE EXCEPTION 'غير مصرح' USING ERRCODE='42501'; END IF;
 
 IF p_accept IS NULL THEN RAISE EXCEPTION 'حدد قبول العرض أو رفضه'; END IF;
 SELECT order_id INTO v_order_id FROM public.ff38_dispatch_offers WHERE id=p_offer AND driver_id=v_driver;
 IF v_order_id IS NULL THEN RAISE EXCEPTION 'العرض غير متاح'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-o-'||v_order_id::text));
 SELECT branch_id INTO v_branch FROM public.ff_orders WHERE id=v_order_id FOR UPDATE;
 IF v_branch IS NULL THEN RAISE EXCEPTION 'العرض غير متاح'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-branch-rr-'||v_branch::text));
 SELECT * INTO v_offer FROM public.ff38_dispatch_offers WHERE id=p_offer AND order_id=v_order_id FOR UPDATE;

 IF v_offer.id IS NULL OR v_offer.driver_id<>v_driver OR v_offer.status<>'offered' THEN RAISE EXCEPTION 'العرض غير متاح'; END IF;
 IF v_offer.expires_at<=now() THEN
 UPDATE public.ff38_dispatch_offers SET status='expired',responded_at=now() WHERE id=p_offer;
 v_result=public.ff38__offer_next(v_offer.order_id);
 RETURN jsonb_build_object('state','expired','next',v_result);
 END IF;
 IF p_accept THEN
 -- Serialize acceptance per driver; prevents concurrent over-assignment.
 PERFORM 1 FROM public.ff38_driver_presence
 WHERE driver_id=v_driver AND checked_in_at IS NOT NULL
 AND state IN ('ready','busy')
 AND last_seen_at > now()-interval '90 seconds'
 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'الموصل غير حاضر أو غير متصل'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.ff_drivers d JOIN public.ff_orders o
 ON o.branch_id=d.branch_id WHERE d.id=v_driver AND d.active
 AND o.id=v_offer.order_id AND o.order_type='delivery'
 AND o.status NOT IN ('delivered','cancelled','reservation_completed'))
 THEN RAISE EXCEPTION 'الطلب أو الفرع غير صالح للإسناد'; END IF;
 IF EXISTS(SELECT 1 FROM public.ff38_delivery_tasks WHERE order_id=v_offer.order_id) THEN RAISE EXCEPTION 'سبق إسناد الطلب'; END IF;
 IF (SELECT count(*) FROM public.ff38_delivery_tasks WHERE driver_id=v_driver AND delivered_at IS NULL)>=5 THEN RAISE EXCEPTION 'وصلت إلى الحد الأقصى'; END IF;
 -- Additional assignments 3-5 must match an existing delivery area.
 IF (SELECT count(*) FROM public.ff38_delivery_tasks WHERE driver_id=v_driver AND delivered_at IS NULL)>=2
 AND NOT EXISTS (
 SELECT 1 FROM public.ff38_delivery_tasks t
 JOIN public.ff_orders prior ON prior.id=t.order_id
 JOIN public.ff_orders incoming ON incoming.id=v_offer.order_id
 WHERE t.driver_id=v_driver AND t.delivered_at IS NULL
 AND lower(btrim(prior.area_snapshot))=lower(btrim(incoming.area_snapshot))
 ) THEN RAISE EXCEPTION 'الطلبات التراكمية تتطلب منطقة متطابقة'; END IF;
 UPDATE public.ff38_dispatch_offers SET status='accepted',responded_at=now() WHERE id=p_offer;
 INSERT INTO public.ff38_delivery_tasks(order_id,driver_id) VALUES(v_offer.order_id,v_driver);
 UPDATE public.ff_orders SET driver_id=v_driver,status='sent',sent_at=coalesce(sent_at,now()),updated_at=now() WHERE id=v_offer.order_id;
 UPDATE public.ff38_driver_presence SET state='busy',last_seen_at=now(),updated_at=now() WHERE driver_id=v_driver;
 RETURN jsonb_build_object('state','accepted','order_id',v_offer.order_id);
 ELSE
 UPDATE public.ff38_dispatch_offers SET status='rejected',responded_at=now(),reject_reason=pg_catalog.left(coalesce(p_reason,''),500) WHERE id=p_offer;
 v_result=public.ff38__offer_next(v_offer.order_id);
 RETURN jsonb_build_object('state','rejected','next',v_result);
 END IF;
 END $function$;

create trigger ff49_driver_capacity_guard_tg before insert or update of driver_id,delivered_at on public.ff38_delivery_tasks for each row execute function public.ff49_driver_capacity_guard();
create trigger ff60_driver_capacity_trg before insert or update of driver_id on public.ff38_delivery_tasks for each row execute function public.ff60_driver_capacity_safety();
create trigger ff_special_task_capacity before insert or update of driver_id,order_id,phase on public.ff38_delivery_tasks for each row execute function ff_private.guard_special_courier_capacity();
create trigger ff60_offer_deadline_trg before insert on public.ff38_dispatch_offers for each row execute function public.ff60_offer_deadline();
create trigger ff_special_offer_capacity before insert or update of driver_id,order_id,status,expires_at on public.ff38_dispatch_offers for each row execute function ff_private.guard_special_courier_capacity();
create trigger ff38_guard_driver_rejection_trigger before update on public.ff38_dispatch_offers for each row execute function public.ff38_guard_driver_rejection();
