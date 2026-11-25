-- A12 development-only legacy cohort. Owner confirmed existing operational orders are test data.
-- No deletion occurs in this migration. New ordinary orders are NOT automatically classified.
create table ff_private.a12_legacy_registry(
 id uuid primary key, branch_id uuid not null, order_type text not null, created_at timestamptz not null
);
create table ff_private.a12_legacy_batches(
 id uuid primary key default gen_random_uuid(), actor_id uuid not null,
 branch_id uuid not null, order_type text not null, date_from date not null, date_to date not null,
 ids uuid[] not null, snapshot jsonb not null, counts jsonb not null, schema_hash text not null,
 created_at timestamptz not null default now(), restored_at timestamptz, restored_by uuid
);
alter table ff_private.a12_legacy_registry enable row level security;
alter table ff_private.a12_legacy_batches enable row level security;
revoke all on ff_private.a12_legacy_registry,ff_private.a12_legacy_batches from public,anon,authenticated;
insert into ff_private.a12_legacy_registry
 select o.id,o.branch_id,o.order_type,o.created_at from public.ff_orders o
 where o.created_at<='2026-11-23 04:29:08.120072+00'::timestamptz
 and o.status in ('cancelled','delivered') and not exists(select 1 from ff_private.a12_test_orders t where t.id=o.id);
do $$ begin
 if (select count(*) from ff_private.a12_legacy_registry)<>82 then
  raise exception 'Confirmed development cohort changed; review before applying';
 end if;
end $$;

-- Fixed allowlist: never auto-delete a newly introduced relation.
create function ff_private.a12_legacy_plan()
returns table(step int,rel regclass,parent regclass,child_key text)
language sql stable set search_path='' as $$
 values
(1,'public.ff_orders'::regclass,null::regclass,'id'::text),
(2,'public.ff_burger_tickets'::regclass,'public.ff_orders'::regclass,'delivery_order_id'::text),
(3,'public.ff_luxe_cancel_ack'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(4,'public.ff_luxe_cashier_order_desks'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(5,'public.ff_luxe_driver_cancel_skip'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(6,'public.ff_luxe_driver_feedback'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(7,'public.ff_luxe_late_invoice_refs'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(8,'public.ff_order_customer_edits'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(9,'public.ff_order_events'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(10,'public.ff_order_items'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(11,'ff_private.a10_cashier_coordination'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(12,'public.ff_push_jobs'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(13,'public.ff27_branch_updates'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(14,'public.ff38_delivery_tasks'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(15,'public.ff38_dispatch_offers'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(16,'public.ff38_order_additions'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(17,'public.ff38_order_cancellation_audit'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(18,'public.ff38_reject_permission_audit'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(19,'public.ff41_cases'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(20,'public.ff49_cashier_receipts'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(21,'public.ff49_driver_transfers'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(22,'public.ff49_manual_dispatch_audit'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(23,'public.ff49_order_details'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(24,'public.ff50_order_changes'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(25,'public.ff51_driver_ratings'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(26,'public.ff52_driver_reassignment_audit'::regclass,'public.ff_orders'::regclass,'order_id'::text),
(27,'public.ff_burger_ticket_events'::regclass,'public.ff_burger_tickets'::regclass,'ticket_id'::text),
(28,'public.ff_case_alert_receipts'::regclass,'public.ff41_cases'::regclass,'case_id'::text),
(29,'public.ff41_case_events'::regclass,'public.ff41_cases'::regclass,'case_id'::text),
(30,'public.ff38_order_addition_items'::regclass,'public.ff38_order_additions'::regclass,'addition_id'::text),
(31,'public.ff52_addition_pos'::regclass,'public.ff38_order_additions'::regclass,'addition_id'::text),
(32,'public.ff52_late_addition_consent'::regclass,'public.ff38_order_additions'::regclass,'addition_id'::text),
(33,'public.ff50_order_change_events'::regclass,'public.ff50_order_changes'::regclass,'change_id'::text),
(34,'public.ff_luxe_driver_grievances'::regclass,'public.ff_orders'::regclass,'order_id'::text)
$$;

create function ff_private.a12_legacy_schema_hash() returns text language sql stable set search_path='' as $$
 select md5(jsonb_build_array(
  (select jsonb_agg(jsonb_build_array(c.rel::text,a.attname,a.atttypid,a.atttypmod,a.attgenerated,a.attidentity,a.attnotnull) order by c.step,a.attnum)
   from ff_private.a12_legacy_plan() c join pg_attribute a on a.attrelid=c.rel and a.attnum>0 and not a.attisdropped),
  (select jsonb_agg(jsonb_build_array(c.rel::text,pg_get_constraintdef(k.oid)) order by c.step,k.conname)
   from ff_private.a12_legacy_plan() c join pg_constraint k on k.conrelid=c.rel),
  (select jsonb_agg(jsonb_build_array(c.rel::text,pg_get_triggerdef(t.oid),t.tgenabled) order by c.step,t.tgname)
   from ff_private.a12_legacy_plan() c join pg_trigger t on t.tgrelid=c.rel where not t.tgisinternal)
 )::text)
$$;

create function ff_private.a12_legacy_snapshot(p_ids uuid[]) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare r record; s jsonb:='{}'; rows jsonb; keys text[]; case_keys text[];
begin
 for r in select * from ff_private.a12_legacy_plan() order by step loop
  if r.parent is null then
   select coalesce(array_agg(x::text),'{}') into keys from unnest(p_ids) x;
  else
   select coalesce(array_agg(x->>'id'),'{}') into keys from jsonb_array_elements(s->r.parent::text) x;
  end if;
  if r.rel='public.ff_luxe_driver_grievances'::regclass then
   select coalesce(array_agg(x->>'id'),'{}') into case_keys from jsonb_array_elements(s->'public.ff41_cases') x;
   execute format('select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),''[]''::jsonb) from %s t where t.order_id::text=any($1) or t.case_id::text=any($2)',r.rel)
    into rows using keys,case_keys;
  else
   execute format('select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),''[]''::jsonb) from %s t where t.%I::text=any($1)',r.rel,r.child_key)
    into rows using keys;
  end if;
  s:=s||jsonb_build_object(r.rel::text,rows);
 end loop;
 return s;
end $$;

create function ff_private.a12_legacy_blockers(p_ids uuid[],p_snapshot jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb:='{}'; f record; n bigint;
begin
 -- An unexpected FK, including SET NULL or CASCADE, is a hard block.
 for f in select c.*,a.attname child_col,b.attname parent_col
   from pg_constraint c
   left join pg_attribute a on a.attrelid=c.conrelid and a.attnum=c.conkey[1]
   left join pg_attribute b on b.attrelid=c.confrelid and b.attnum=c.confkey[1]
   where c.contype='f' and c.confrelid in(select rel from ff_private.a12_legacy_plan())
 loop
  if cardinality(f.conkey)=1 and f.parent_col='id' and
   (exists(select 1 from ff_private.a12_legacy_plan() p where p.rel=f.conrelid and p.parent=f.confrelid and p.child_key=f.child_col)
    or (f.conrelid='public.ff_luxe_driver_grievances'::regclass and f.confrelid='public.ff41_cases'::regclass and f.child_col='case_id')) then continue;end if;
  if f.conrelid='public.ff_reward_codes'::regclass and f.confrelid='public.ff_orders'::regclass and f.child_col='redeemed_order_id' and cardinality(f.conkey)=1 then
   select count(*) into n from public.ff_reward_codes where redeemed_order_id=any(p_ids);
   if n>0 then result:=result||jsonb_build_object('protected_reward_codes',n);end if;continue;
  end if;
  result:=result||jsonb_build_object('unexpected_fk:'||f.conrelid::regclass::text||':'||f.conname,'blocked');
 end loop;
 if exists(select 1 from public.ff_orders o left join ff_private.a12_legacy_registry t on t.id=o.id where o.id=any(p_ids)
 and (t.id is null or o.branch_id<>t.branch_id or o.created_at<>t.created_at or o.order_type<>t.order_type or o.status not in('cancelled','delivered')))
 then result:=result||jsonb_build_object('changed_or_active_order','blocked');end if;
 if exists(select 1 from jsonb_array_elements(p_snapshot->'public.ff_push_jobs') x where x->>'status'<>'sent')
 then result:=result||jsonb_build_object('undelivered_push_jobs','blocked');end if;
 if exists(select 1 from jsonb_array_elements(p_snapshot->'public.ff_luxe_driver_grievances') x
 where (x->>'order_id' is not null and not (x->>'order_id')::uuid=any(p_ids))
 or (x->>'case_id' is not null and not exists(select 1 from jsonb_array_elements(p_snapshot->'public.ff41_cases') c where c->>'id'=x->>'case_id')))
 then result:=result||jsonb_build_object('cross_scope_grievance','blocked');end if;
 return result;
end $$;

-- Lock all explicit tables and the protected reward reference table. Foreign key triggers remain enabled.
create function ff_private.a12_legacy_lock() returns void language plpgsql security definer set search_path='' as $$
declare r record;
begin
 for r in select rel from ff_private.a12_legacy_plan() union select 'public.ff_reward_codes'::regclass order by rel loop
  execute format('lock table %s in access exclusive mode',r.rel);
 end loop;
 lock table ff_private.a12_legacy_registry,ff_private.a12_legacy_batches in share row exclusive mode;
end $$;

-- Exact temporary trigger modes are restored before commit. Only explicit user triggers on the fixed graph
-- are suspended within the exclusive transaction to avoid sending historical notifications or rewriting history.
-- All FK/internal constraint triggers stay enabled. A transaction failure rolls back DDL as well as data.
create function ff_private.a12_legacy_trigger_modes() returns jsonb language sql stable set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('rel',p.rel::text,'name',t.tgname,'mode',t.tgenabled) order by p.step,t.tgname),'[]')
 from ff_private.a12_legacy_plan() p join pg_trigger t on t.tgrelid=p.rel where not t.tgisinternal
$$;
create function ff_private.a12_legacy_set_modes(p_modes jsonb,p_restore boolean) returns void
language plpgsql security definer set search_path='' as $$
declare r jsonb; relation regclass; mode text;
begin
 for r in select value from jsonb_array_elements(p_modes) loop
  relation:=(r->>'rel')::regclass;
  if not exists(select 1 from ff_private.a12_legacy_plan() p where p.rel=relation)
   or not exists(select 1 from pg_trigger t where t.tgrelid=relation and t.tgname=r->>'name' and not t.tgisinternal)
   then raise exception 'Unknown trigger';end if;
  mode:=case when not p_restore then 'DISABLE' when r->>'mode'='O' then 'ENABLE'
   when r->>'mode'='A' then 'ENABLE ALWAYS' when r->>'mode'='R' then 'ENABLE REPLICA'
   when r->>'mode'='D' then 'DISABLE' else null end;
  if mode is null then raise exception 'Unknown trigger mode';end if;
  execute format('alter table %s %s trigger %I',relation,mode,r->>'name');
 end loop;
end $$;

create function public.ff_a12_legacy_preview(p_branch uuid,p_type text,p_from date,p_to date)
returns jsonb language plpgsql security definer set search_path='' as $$
declare ids uuid[]; s jsonb; blockers jsonb; schema_hash text; total bigint;
begin
 perform ff_private.a12_require_manager();
 if p_branch is null or not exists(select 1 from public.ff_branches where id=p_branch)
 or p_type is null or p_type not in('all','delivery','reservation') or p_from is null or p_to is null
 or p_to<p_from or p_to-p_from>30 then raise exception 'حدد الفرع والنوع وفترة لا تتجاوز 31 يوماً';end if;
 select coalesce(array_agg(o.id order by o.id),'{}') into ids from public.ff_orders o join ff_private.a12_legacy_registry t on t.id=o.id
 where t.branch_id=p_branch and (p_type='all' or t.order_type=p_type) and (t.created_at at time zone 'Asia/Aden')::date between p_from and p_to;
 s:=ff_private.a12_legacy_snapshot(ids);blockers:=ff_private.a12_legacy_blockers(ids,s);schema_hash:=ff_private.a12_legacy_schema_hash();
 select count(*) into total from public.ff_orders;
 return jsonb_build_object('counts',ff_private.a12_counts(s),'blockers',blockers,'total_orders',total,
 'registered_total',(select count(*) from ff_private.a12_legacy_registry),'eligible_orders',cardinality(ids),
 'orders',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'number',o.order_number,'type',o.order_type,'date',o.business_date) order by o.id) from public.ff_orders o where o.id=any(ids)),'[]'),
 'token',md5(jsonb_build_array(auth.uid(),p_branch,p_type,p_from,p_to,s,blockers,schema_hash)::text));
end $$;

create function public.ff_a12_legacy_execute(p_branch uuid,p_type text,p_from date,p_to date,p_token text,p_confirmation text)
returns jsonb language plpgsql security definer set search_path='' set lock_timeout='3s' as $$
declare preview jsonb; ids uuid[]; s jsonb; remaining jsonb; b uuid; modes jsonb; r record; n bigint; hash text;
begin
 perform ff_private.a12_require_manager();
 if p_confirmation is distinct from 'تصفير البيانات التجريبية السابقة' then raise exception 'عبارة التأكيد غير صحيحة';end if;
 perform ff_private.a12_legacy_lock();
 preview:=public.ff_a12_legacy_preview(p_branch,p_type,p_from,p_to);
 if p_token is distinct from preview->>'token' then raise exception 'تغيرت المعاينة؛ أعد الفحص';end if;
 if preview->'blockers'<>'{}'::jsonb or (preview->>'eligible_orders')::int=0 then raise exception 'لا توجد سجلات مؤهلة أو توجد تبعيات محمية';end if;
 select array_agg((x->>'id')::uuid order by x->>'id') into ids from jsonb_array_elements(preview->'orders') x;
 s:=ff_private.a12_legacy_snapshot(ids);hash:=ff_private.a12_legacy_schema_hash();
 if md5(jsonb_build_array(auth.uid(),p_branch,p_type,p_from,p_to,s,'{}'::jsonb,hash)::text) is distinct from p_token then raise exception 'تغيرت البيانات؛ أعد المعاينة';end if;
 insert into ff_private.a12_legacy_batches(actor_id,branch_id,order_type,date_from,date_to,ids,snapshot,counts,schema_hash)
 values(auth.uid(),p_branch,p_type,p_from,p_to,ids,s,ff_private.a12_counts(s),hash) returning id into b;
 -- Preserve original order-related audit rows in the existing permanent audit archive.
 for r in select * from ff_private.a12_legacy_plan() where rel in ('public.ff38_order_cancellation_audit'::regclass,'public.ff38_reject_permission_audit'::regclass,'public.ff49_manual_dispatch_audit'::regclass,'public.ff52_driver_reassignment_audit'::regclass) loop
  insert into public.ff_luxe_reset_audit_archive(batch_id,source_table,original_record,archived_by)
  select b,r.rel::text,x,auth.uid() from jsonb_array_elements(s->r.rel::text) x;
 end loop;
 modes:=ff_private.a12_legacy_trigger_modes();perform ff_private.a12_legacy_set_modes(modes,false);
 for r in select * from ff_private.a12_legacy_plan() order by step desc loop
  if jsonb_array_length(s->r.rel::text)=0 then continue;end if;
  execute format('delete from %s t using jsonb_array_elements($1) x where to_jsonb(t)=x.value',r.rel) using s->r.rel::text;
  get diagnostics n=row_count;
  if n<>jsonb_array_length(s->r.rel::text) then raise exception 'عدد غير مطابق: %',r.rel;end if;
 end loop;
 perform ff_private.a12_legacy_set_modes(modes,true);
 if ff_private.a12_legacy_schema_hash()<>hash then raise exception 'تعذر استعادة حالات المحفزات';end if;
 remaining:=ff_private.a12_counts(ff_private.a12_legacy_snapshot(ids));
 if exists(select 1 from jsonb_each_text(remaining) x where x.value::int<>0) then raise exception 'بقيت سجلات تابعة';end if;
 insert into public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details) values(auth.uid(),'a12_legacy_test_reset','a12_legacy_batch',b::text,p_branch,
 jsonb_build_object('before',preview->'counts','after',remaining,'scope',jsonb_build_array(p_from,p_to,p_type)));
 return jsonb_build_object('ok',true,'batch_id',b,'backup_saved',true,'removed',preview->'counts','remaining_selected',remaining,'total_before',preview->'total_orders','total_after',(select count(*) from public.ff_orders));
end $$;

create function public.ff_a12_legacy_batches() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform ff_private.a12_require_manager();
 return coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from
 (select id,branch_id,order_type,date_from,date_to,counts,created_at,restored_at from ff_private.a12_legacy_batches order by created_at desc limit 100)x),'[]');
end $$;

create function public.ff_a12_legacy_restore(p_batch uuid,p_confirmation text)
returns jsonb language plpgsql security definer set search_path='' set lock_timeout='3s' as $$
declare b ff_private.a12_legacy_batches%rowtype; modes jsonb; r record; cols text; select_cols text; n bigint; post jsonb;
begin
 perform ff_private.a12_require_manager();
 if p_confirmation is distinct from 'استرجاع البيانات التجريبية السابقة' then raise exception 'عبارة التأكيد غير صحيحة';end if;
 perform ff_private.a12_legacy_lock();
 select * into b from ff_private.a12_legacy_batches where id=p_batch for update;
 if not found or b.restored_at is not null then raise exception 'النسخة غير موجودة أو سبق استرجاعها';end if;
 if b.schema_hash<>ff_private.a12_legacy_schema_hash() then raise exception 'تغيرت بنية البيانات؛ يلزم تحقق فني قبل الاسترجاع';end if;
 if exists(select 1 from public.ff_orders where id=any(b.ids)) or exists(select 1 from unnest(b.ids) u(id) where not exists(select 1 from ff_private.a12_legacy_registry t where t.id=u.id))
 then raise exception 'تعارض في هوية الطلبات';end if;
 modes:=ff_private.a12_legacy_trigger_modes();perform ff_private.a12_legacy_set_modes(modes,false);
 for r in select * from ff_private.a12_legacy_plan() order by step loop
  if jsonb_array_length(b.snapshot->r.rel::text)=0 then continue;end if;
  select string_agg(format('%I',attname),',' order by attnum),string_agg(format('x.%I',attname),',' order by attnum)
   into cols,select_cols from pg_attribute where attrelid=r.rel and attnum>0 and not attisdropped and attgenerated='';
  execute format('insert into %s(%s) overriding system value select %s from jsonb_populate_recordset(null::%s,$1) x',r.rel,cols,select_cols,r.rel) using b.snapshot->r.rel::text;
  get diagnostics n=row_count;if n<>jsonb_array_length(b.snapshot->r.rel::text) then raise exception 'عدد غير مطابق: %',r.rel;end if;
 end loop;
 perform ff_private.a12_legacy_set_modes(modes,true);
 if ff_private.a12_legacy_schema_hash()<>b.schema_hash then raise exception 'تعذر استعادة حالات المحفزات';end if;
 post:=ff_private.a12_legacy_snapshot(b.ids);
 if post is distinct from b.snapshot or ff_private.a12_legacy_blockers(b.ids,post)<>'{}'::jsonb then raise exception 'فشل تطابق الاسترجاع؛ تم التراجع';end if;
 update ff_private.a12_legacy_batches set restored_at=now(),restored_by=auth.uid() where id=p_batch;
 insert into public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details) values(auth.uid(),'a12_legacy_test_restore','a12_legacy_batch',p_batch::text,b.branch_id,jsonb_build_object('restored',b.counts));
 return jsonb_build_object('ok',true,'exact_match',true,'batch_id',p_batch,'restored',b.counts);
end $$;

-- Keep non-FK security/workflow audit and idempotency records intact.
-- Replay of a removed development order must not return a stale successful result or create a new order.
do $$ declare f text; old text:='    return prior.result;';begin
 select pg_get_functiondef('public.ff27_submit(uuid,text,jsonb)'::regprocedure) into f;
 if strpos(f,old)=0 then raise exception 'Atomic request source changed';end if;
 f:=replace(f,old,'    if exists(select 1 from ff_private.a12_legacy_registry t where t.id::text=prior.result->>''order_id'' and not exists(select 1 from public.ff_orders o where o.id=t.id)) then raise exception ''تم تصفير الطلب التجريبي؛ استخدم معرف طلب جديد'';end if;
    return prior.result;');
 execute f;
end $$;

revoke execute on function ff_private.a12_legacy_plan(),ff_private.a12_legacy_schema_hash(),ff_private.a12_legacy_snapshot(uuid[]),
 ff_private.a12_legacy_blockers(uuid[],jsonb),ff_private.a12_legacy_lock(),ff_private.a12_legacy_trigger_modes(),ff_private.a12_legacy_set_modes(jsonb,boolean)
 from public,anon,authenticated;
revoke execute on function public.ff_a12_legacy_preview(uuid,text,date,date),public.ff_a12_legacy_execute(uuid,text,date,date,text,text),
 public.ff_a12_legacy_batches(),public.ff_a12_legacy_restore(uuid,text) from public,anon,authenticated;
grant execute on function public.ff_a12_legacy_preview(uuid,text,date,date),public.ff_a12_legacy_execute(uuid,text,date,date,text,text),
 public.ff_a12_legacy_batches(),public.ff_a12_legacy_restore(uuid,text) to authenticated;
