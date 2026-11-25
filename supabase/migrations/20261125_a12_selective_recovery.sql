-- A12 FIX-20 / UI-16 / QA-19 / QA-42: reversible, explicitly generated test orders.
-- Existing data is never classified by a name, date, or guessed marker.
create table ff_private.a12_test_orders(
 id uuid primary key, branch_id uuid not null, order_type text not null,
 created_at timestamptz not null, created_by uuid not null
);
create table ff_private.a12_reset_batches(
 id uuid primary key default gen_random_uuid(), actor_id uuid not null,
 branch_id uuid not null, order_type text not null, date_from date not null, date_to date not null,
 snapshot jsonb not null, counts jsonb not null, created_at timestamptz not null default now(),
 restored_at timestamptz, restored_by uuid
);
create sequence ff_private.a12_test_number start with 1;
alter table ff_private.a12_test_orders enable row level security;
alter table ff_private.a12_reset_batches enable row level security;
revoke all on ff_private.a12_test_orders,ff_private.a12_reset_batches from public,anon,authenticated;
revoke all on sequence ff_private.a12_test_number from public,anon,authenticated;

-- Fail closed: historical globally destructive interfaces are no longer callable from the app.
revoke execute on function public.ff_luxe_reset_safe(text[],text),
 public.ff_luxe_reset_scoped(text[],text),public.ff_manager_reset_data(text),
 public.ff_luxe_reset_preview(text[]) from public,anon,authenticated;

create function ff_private.a12_require_manager() returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.ff_is_manager() then
  raise exception 'هذا الإجراء للمدير العام فقط' using errcode='42501';
 end if;
end $$;

-- Only these four tables may be changed by the reset. Every other incoming FK
-- (including audit, rewards, push, tasks, additions, complaints) is checked and blocks deletion.
create function ff_private.a12_snapshot(p_ids uuid[]) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object(
 'orders',coalesce((select jsonb_agg(to_jsonb(o) order by o.id) from public.ff_orders o where o.id=any(p_ids)),'[]'),
 'items',coalesce((select jsonb_agg(to_jsonb(o) order by o.id) from public.ff_order_items o where o.order_id=any(p_ids)),'[]'),
 'events',coalesce((select jsonb_agg(to_jsonb(o) order by o.id) from public.ff_order_events o where o.order_id=any(p_ids)),'[]'),
 'desks',coalesce((select jsonb_agg(to_jsonb(o) order by o.order_id) from public.ff_luxe_cashier_order_desks o where o.order_id=any(p_ids)),'[]')
 ) $$;

create function ff_private.a12_counts(p_snapshot jsonb) returns jsonb language sql immutable set search_path='' as $$
 select jsonb_object_agg(key,jsonb_array_length(value)) from jsonb_each(p_snapshot) $$;

create function ff_private.a12_blockers(p_ids uuid[]) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare f record; n bigint; result jsonb:='{}';
begin
 if cardinality(p_ids)=0 then return result; end if;
 for f in
  select c.conrelid::regclass child,c.confrelid::regclass parent,c.conkey,c.confkey,
         a.attname child_col,b.attname parent_col
  from pg_constraint c
  left join pg_attribute a on a.attrelid=c.conrelid and a.attnum=c.conkey[1]
  left join pg_attribute b on b.attrelid=c.confrelid and b.attnum=c.confkey[1]
  where c.contype='f' and c.confrelid in ('public.ff_orders'::regclass,'public.ff_order_items'::regclass,
   'public.ff_order_events'::regclass,'public.ff_luxe_cashier_order_desks'::regclass)
 loop
  if f.parent='public.ff_orders'::regclass and f.parent_col='id' and f.child_col='order_id'
   and cardinality(f.conkey)=1 and f.child in ('public.ff_order_items'::regclass,'public.ff_order_events'::regclass,'public.ff_luxe_cashier_order_desks'::regclass) then continue; end if;
  if cardinality(f.conkey)<>1 or f.parent<>'public.ff_orders'::regclass or f.parent_col<>'id' then
   result:=result||jsonb_build_object(f.child::text,'unsupported_dependency'); continue;
  end if;
  execute format('select count(*) from %s where %I=any($1)',f.child,f.child_col) into n using p_ids;
  if n>0 then result:=result||jsonb_build_object(f.child::text,n); end if;
 end loop;
 if exists(select 1 from public.ff_orders o join ff_private.a12_test_orders t on t.id=o.id
  where o.id=any(p_ids) and (o.branch_id<>t.branch_id or o.order_type<>t.order_type or o.created_at<>t.created_at
   or o.status not in ('cancelled','canceled') or o.customer_id is not null or o.driver_id is not null
   or o.phone_snapshot<>'000000000' or o.idempotency_key is distinct from ('A12-QA:'||o.id::text))) then
  result:=result||jsonb_build_object('changed_fixture','protected');
 end if;
 return result;
end $$;

create function public.ff_a12_reset_preview(p_branch uuid,p_type text,p_from date,p_to date)
returns jsonb language plpgsql security definer set search_path='' as $$
declare ids uuid[]; snap jsonb; blockers jsonb; result jsonb;
begin
 perform ff_private.a12_require_manager();
 if p_branch is null or not exists(select 1 from public.ff_branches where id=p_branch)
  or p_type is null or p_type not in ('delivery','reservation','all') or p_from is null or p_to is null
  or p_to<p_from or p_to-p_from>30 then raise exception 'حدد فرعاً ونوعاً وفترة لا تتجاوز 31 يوماً'; end if;
 select coalesce(array_agg(id order by id),'{}') into ids from (
  select o.id from public.ff_orders o join ff_private.a12_test_orders t on t.id=o.id
  where t.branch_id=p_branch and (p_type='all' or t.order_type=p_type)
   and (t.created_at at time zone 'Asia/Aden')::date between p_from and p_to
  order by o.id limit 101
 ) s;
 if cardinality(ids)>100 then raise exception 'أكثر من 100 طلب اختبار؛ ضيق الفترة'; end if;
 snap:=ff_private.a12_snapshot(ids); blockers:=ff_private.a12_blockers(ids);
 select jsonb_build_object('counts',ff_private.a12_counts(snap),'blockers',blockers,
 'total_orders',(select count(*) from public.ff_orders),
 'protected_orders',(select count(*) from public.ff_orders o where not exists(select 1 from ff_private.a12_test_orders t where t.id=o.id)),
 'orders',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'number',o.order_number,'type',o.order_type,'date',o.business_date) order by o.id)
   from public.ff_orders o where o.id=any(ids)),'[]'),
 'token',md5(jsonb_build_array(auth.uid(),p_branch,p_type,p_from,p_to,snap,blockers)::text)) into result;
 return result;
end $$;

-- This explicit fixture generator never marks existing records or uses the ordinary order number sequence.
create function public.ff_a12_create_fixture(p_branch uuid,p_type text,p_date date,p_confirmation text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare id uuid:=gen_random_uuid(); num bigint; stamp timestamptz;
begin
 perform ff_private.a12_require_manager();
 if p_confirmation is distinct from 'إنشاء طلب اختبار' or p_type is null or p_type not in ('delivery','reservation')
  or p_date is null or p_date>(now() at time zone 'Asia/Aden')::date or p_date<(now() at time zone 'Asia/Aden')::date-30
  or not exists(select 1 from public.ff_branches where ff_branches.id=p_branch and active) then
  raise exception 'تأكيد أو فرع أو تاريخ الاختبار غير صالح'; end if;
 stamp:=(p_date+time '12:00') at time zone 'Asia/Aden';
 num:=-nextval('ff_private.a12_test_number');
 insert into ff_private.a12_test_orders(id,branch_id,order_type,created_at,created_by) values(id,p_branch,p_type,stamp,auth.uid());
 insert into public.ff_orders(id,branch_id,order_number,order_type,status,phone_snapshot,notes,created_at,updated_at,created_by,business_date,idempotency_key)
 values(id,p_branch,num,p_type,'cancelled','000000000','A12 — طلب اختبار اصطناعي فقط',stamp,stamp,auth.uid(),p_date,'A12-QA:'||id::text);
 insert into public.ff_order_items(order_id,item_name,item_notes,quantity,unit_price,line_total) values(id,'A12 QA','اختبار فقط',1,0,0);
 insert into public.ff_order_events(order_id,new_status,note,actor_id) values(id,'cancelled','A12 QA fixture',auth.uid());
 insert into public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 values(auth.uid(),'a12_fixture_created','order',id::text,p_branch,jsonb_build_object('type',p_type,'date',p_date));
 return jsonb_build_object('id',id,'number',num,'test_only',true);
end $$;

create function public.ff_a12_reset_execute(p_branch uuid,p_type text,p_from date,p_to date,p_token text,p_confirmation text)
returns jsonb language plpgsql security definer set search_path='' set lock_timeout='3s' as $$
declare preview jsonb; ids uuid[]; snap jsonb; batch uuid; removed bigint; after_counts jsonb; total_after bigint;
begin
 perform ff_private.a12_require_manager();
 if p_confirmation is distinct from 'تصفير طلبات الاختبار فقط' then raise exception 'عبارة التأكيد غير صحيحة'; end if;
 -- Serialize only this maintenance transaction; never disable RLS or triggers.
 lock table public.ff_orders,public.ff_order_items,public.ff_order_events,public.ff_luxe_cashier_order_desks,ff_private.a12_test_orders in share row exclusive mode;
 preview:=public.ff_a12_reset_preview(p_branch,p_type,p_from,p_to);
 if p_token is distinct from preview->>'token' then raise exception 'تغيرت البيانات؛ أعد المعاينة'; end if;
 if preview->'blockers'<>'{}'::jsonb then raise exception 'تبعيات محمية تمنع التصفير: %',preview->'blockers'; end if;
 select coalesce(array_agg((x->>'id')::uuid),'{}') into ids from jsonb_array_elements(preview->'orders') x;
 if cardinality(ids)=0 then raise exception 'لا توجد طلبات اختبار مؤهلة'; end if;
 perform 1 from public.ff_orders where id=any(ids) for update;
 -- Locking selected parents also blocks new incoming FK references.
 if ff_private.a12_blockers(ids)<>'{}'::jsonb then raise exception 'ظهرت تبعيات جديدة؛ أعد المعاينة'; end if;
 snap:=ff_private.a12_snapshot(ids);
 if md5(jsonb_build_array(auth.uid(),p_branch,p_type,p_from,p_to,snap,'{}'::jsonb)::text) is distinct from p_token then raise exception 'تغيرت البيانات؛ أعد المعاينة'; end if;
 insert into ff_private.a12_reset_batches(actor_id,branch_id,order_type,date_from,date_to,snapshot,counts)
 values(auth.uid(),p_branch,p_type,p_from,p_to,snap,ff_private.a12_counts(snap)) returning id into batch;
 -- Only registered, exactly previewed test order IDs. FK cascade is restricted by the blocker check.
 delete from public.ff_orders where id=any(ids);
 get diagnostics removed=row_count;
 after_counts:=ff_private.a12_counts(ff_private.a12_snapshot(ids));
 if removed<>cardinality(ids) or after_counts<>'{"orders":0,"items":0,"events":0,"desks":0}'::jsonb then raise exception 'عدم تطابق الأعداد؛ تم التراجع'; end if;
 select count(*) into total_after from public.ff_orders;
 insert into public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 values(auth.uid(),'a12_test_reset','a12_batch',batch::text,p_branch,jsonb_build_object('before',preview->'counts','after',after_counts,'total_before',preview->'total_orders','total_after',total_after));
 return jsonb_build_object('ok',true,'batch_id',batch,'removed',preview->'counts','remaining_selected',after_counts,
 'total_before',preview->'total_orders','total_after',total_after,'backup_saved',true);
end $$;

create function public.ff_a12_reset_batches() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform ff_private.a12_require_manager();
 return coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from
  (select id,branch_id,order_type,date_from,date_to,counts,created_at,restored_at
   from ff_private.a12_reset_batches order by created_at desc limit 100) x),'[]');
end $$;

create function public.ff_a12_restore(p_batch uuid,p_confirmation text)
returns jsonb language plpgsql security definer set search_path='' set lock_timeout='3s' as $$
declare b ff_private.a12_reset_batches%rowtype; ids uuid[]; after_snapshot jsonb;
begin
 perform ff_private.a12_require_manager();
 if p_confirmation is distinct from 'استرجاع نسخة الاختبار' then raise exception 'عبارة التأكيد غير صحيحة'; end if;
 lock table public.ff_orders,public.ff_order_items,public.ff_order_events,public.ff_luxe_cashier_order_desks,ff_private.a12_test_orders in share row exclusive mode;
 select * into b from ff_private.a12_reset_batches where id=p_batch for update;
 if not found or b.restored_at is not null then raise exception 'النسخة غير موجودة أو سبق استرجاعها'; end if;
 select array_agg((x->>'id')::uuid) into ids from jsonb_array_elements(b.snapshot->'orders') x;
 if cardinality(ids) is null or cardinality(ids)=0 or exists(select 1 from public.ff_orders where id=any(ids))
 or exists(select 1 from unnest(ids) x where not exists(select 1 from ff_private.a12_test_orders t where t.id=x)) then
  raise exception 'تعارض في بيانات الاسترجاع؛ لم يتم تعديل شيء'; end if;
 insert into public.ff_orders select * from jsonb_populate_recordset(null::public.ff_orders,b.snapshot->'orders');
 -- Existing routing trigger may create a desk. Replace only rows for the just-restored fixture IDs.
 delete from public.ff_luxe_cashier_order_desks where order_id=any(ids);
 insert into public.ff_luxe_cashier_order_desks select * from jsonb_populate_recordset(null::public.ff_luxe_cashier_order_desks,b.snapshot->'desks');
 insert into public.ff_order_items select * from jsonb_populate_recordset(null::public.ff_order_items,b.snapshot->'items');
 insert into public.ff_order_events select * from jsonb_populate_recordset(null::public.ff_order_events,b.snapshot->'events');
 after_snapshot:=ff_private.a12_snapshot(ids);
 if after_snapshot is distinct from b.snapshot or ff_private.a12_blockers(ids)<>'{}'::jsonb then raise exception 'فشل التحقق من تطابق النسخة؛ تم التراجع'; end if;
 update ff_private.a12_reset_batches set restored_at=now(),restored_by=auth.uid() where id=p_batch;
 insert into public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 values(auth.uid(),'a12_test_restore','a12_batch',p_batch::text,b.branch_id,jsonb_build_object('restored',b.counts));
 return jsonb_build_object('ok',true,'batch_id',p_batch,'restored',b.counts,'exact_match',true);
end $$;

revoke execute on function ff_private.a12_require_manager(),ff_private.a12_snapshot(uuid[]),ff_private.a12_counts(jsonb),ff_private.a12_blockers(uuid[]) from public,anon,authenticated;
revoke execute on function public.ff_a12_reset_preview(uuid,text,date,date),public.ff_a12_create_fixture(uuid,text,date,text),
 public.ff_a12_reset_execute(uuid,text,date,date,text,text),public.ff_a12_reset_batches(),public.ff_a12_restore(uuid,text) from public,anon,authenticated;
grant execute on function public.ff_a12_reset_preview(uuid,text,date,date),public.ff_a12_create_fixture(uuid,text,date,text),
 public.ff_a12_reset_execute(uuid,text,date,date,text,text),public.ff_a12_reset_batches(),public.ff_a12_restore(uuid,text) to authenticated;
