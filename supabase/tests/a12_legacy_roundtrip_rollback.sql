-- Owner-confirmed existing test cohort: real data round-trip ONLY inside outer rollback.
-- Do not run without BEGIN/ROLLBACK enclosing the entire suite.
DO $qa$
declare m uuid; c uuid; r record; p jsonb; q jsonb; ids uuid[]; snap jsonb; b uuid; before_n bigint; total_tested int:=0;
 before_audit bigint; before_archive bigint; before_modes text; protected_hash text; protected_after text;
 n int:=0; first_pass boolean:=true;
begin
 select user_id into m from public.ff_profiles where active and role='manager' limit 1;
 select user_id into c from public.ff_profiles where active and role<>'manager' limit 1;
 if m is null or c is null then raise exception 'Need existing manager and nonmanager';end if;
 select count(*) into before_n from public.ff_orders;
 select count(*) into before_audit from public.ff_audit_log;
 select count(*) into before_archive from public.ff_luxe_reset_audit_archive;
 before_modes:=ff_private.a12_legacy_schema_hash();
 select md5(jsonb_build_array(
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from auth.users t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_profiles t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_staff t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_branches t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_menu_items t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_menu_categories t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_offers t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_app_settings t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_role_permissions t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_user_permissions t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_drivers t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_rr_cursors t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_reward_codes t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff70_atomic_requests t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff60_workflow_events t)
 )::text) into protected_hash;
 begin
 for r in select branch_id,min((created_at at time zone 'Asia/Aden')::date) date_from,max((created_at at time zone 'Asia/Aden')::date) date_to from ff_private.a12_legacy_registry group by branch_id order by branch_id loop
  select array_agg(id order by id) into ids from ff_private.a12_legacy_registry where branch_id=r.branch_id;
  snap:=ff_private.a12_legacy_snapshot(ids);
  perform set_config('request.jwt.claim.sub',m::text,true);set local role authenticated;
  p:=public.ff_a12_legacy_preview(r.branch_id,'delivery',r.date_from,r.date_to);
  if p->'blockers'<>'{}'::jsonb or (p->>'eligible_orders')::int<>cardinality(ids) then raise exception 'Preview blocked or wrong scope %',p->'blockers';end if;n:=n+1;
  if (public.ff_a12_legacy_preview(r.branch_id,'reservation',r.date_from,r.date_to)->>'eligible_orders')::int<>0 then raise exception 'Type isolation failed';end if;n:=n+1;
  if first_pass then
   begin perform public.ff_a12_legacy_execute(r.branch_id,'delivery',r.date_from,r.date_to,p->>'token','wrong');raise exception 'wrong confirmation accepted' using errcode='ZQA01';exception when others then if sqlstate='ZQA01' then raise;end if;end;n:=n+1;
   begin perform public.ff_a12_legacy_execute(r.branch_id,'delivery',r.date_from,r.date_to,'stale','تصفير البيانات التجريبية السابقة');raise exception 'stale token accepted' using errcode='ZQA01';exception when others then if sqlstate='ZQA01' then raise;end if;end;n:=n+1;
   reset role;perform set_config('request.jwt.claim.sub',c::text,true);set local role authenticated;
   begin perform public.ff_a12_legacy_preview(r.branch_id,'delivery',r.date_from,r.date_to);raise exception 'nonmanager allowed' using errcode='ZQA01';exception when insufficient_privilege then null;end;n:=n+1;
   begin perform public.ff_a12_legacy_execute(r.branch_id,'delivery',r.date_from,r.date_to,p->>'token','تصفير البيانات التجريبية السابقة');raise exception 'nonmanager execute allowed' using errcode='ZQA01';exception when insufficient_privilege then null;end;n:=n+1;
   reset role;perform set_config('request.jwt.claim.sub',m::text,true);set local role authenticated;
  end if;
  q:=public.ff_a12_legacy_execute(r.branch_id,'delivery',r.date_from,r.date_to,p->>'token','تصفير البيانات التجريبية السابقة');b:=(q->>'batch_id')::uuid;
  if q->>'backup_saved'<>'true' or q->'removed' is distinct from p->'counts' then raise exception 'Backup mismatch';end if;n:=n+1;
  reset role;
  if exists(select 1 from public.ff_orders where id=any(ids)) or (select count(*) from public.ff_orders)<>before_n-cardinality(ids)
   or not exists(select 1 from ff_private.a12_legacy_batches where id=b and snapshot=snap)
   or ff_private.a12_legacy_schema_hash()<>before_modes then raise exception 'Delete, scope, backup or trigger modes mismatch';end if;n:=n+1;
  if first_pass then
   perform set_config('request.jwt.claim.sub',c::text,true);set local role authenticated;
   begin perform public.ff_a12_legacy_restore(b,'استرجاع البيانات التجريبية السابقة');raise exception 'nonmanager restore allowed' using errcode='ZQA01';exception when insufficient_privilege then null;end;n:=n+1;
   reset role;perform set_config('request.jwt.claim.sub',m::text,true);set local role authenticated;
   begin perform public.ff_a12_legacy_restore(b,'wrong');raise exception 'wrong restore accepted' using errcode='ZQA01';exception when others then if sqlstate='ZQA01' then raise;end if;end;n:=n+1;
  end if;
  set local role authenticated;
  q:=public.ff_a12_legacy_restore(b,'استرجاع البيانات التجريبية السابقة');
  if q->>'exact_match'<>'true' then raise exception 'Restore mismatch';end if;n:=n+1;
  begin perform public.ff_a12_legacy_restore(b,'استرجاع البيانات التجريبية السابقة');raise exception 'duplicate restore accepted' using errcode='ZQA01';exception when others then if sqlstate='ZQA01' then raise;end if;end;n:=n+1;
  reset role;
  if ff_private.a12_legacy_snapshot(ids) is distinct from snap or (select count(*) from public.ff_orders)<>before_n or ff_private.a12_legacy_schema_hash()<>before_modes then raise exception 'Restored graph differs';end if;n:=n+1;
  total_tested:=total_tested+cardinality(ids);first_pass:=false;
 end loop;
 if total_tested<>82 or (select count(*) from public.ff_audit_log where action in('a12_legacy_test_reset','a12_legacy_test_restore'))<2 or (select count(*) from public.ff_luxe_reset_audit_archive)<=before_archive then raise exception 'Cohort/audit coverage incomplete';end if;n:=n+1;
 select md5(jsonb_build_array(
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from auth.users t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_profiles t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_staff t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_branches t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_menu_items t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_menu_categories t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_offers t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_app_settings t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_role_permissions t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_user_permissions t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_drivers t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_rr_cursors t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff_reward_codes t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff70_atomic_requests t),
  (select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) from public.ff60_workflow_events t)
 )::text) into protected_after;
 if protected_hash is distinct from protected_after then raise exception 'Protected records changed';end if;n:=n+1;
 if has_function_privilege('anon','public.ff_a12_legacy_preview(uuid,text,date,date)','EXECUTE') or has_function_privilege('authenticated','ff_private.a12_legacy_set_modes(jsonb,boolean)','EXECUTE') or has_table_privilege('authenticated','ff_private.a12_legacy_batches','SELECT') then raise exception 'Unsafe grants';end if;n:=n+1;
 raise exception 'Rollback actual-cohort QA' using errcode='ZQA12';
 exception when sqlstate 'ZQA12' then null;end;
 if total_tested<>82 or n<15 or (select count(*) from public.ff_orders)<>before_n or (select count(*) from public.ff_audit_log)<>before_audit or (select count(*) from public.ff_luxe_reset_audit_archive)<>before_archive then raise exception 'Rollback QA incomplete, % assertions',n;end if;
end $qa$;
select 'PASS: all 82 legacy test orders and all known dependent records round-tripped in rollback; protected hashes identical, audit archived, manager gates and trigger modes verified' result;
