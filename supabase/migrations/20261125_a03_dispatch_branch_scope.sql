-- A03 FIX-09: enforce order branch scope at the authenticated dispatch boundary.
-- Manager and central customer service retain their approved all-branch scope.
-- Individual assignment permission never grants a cashier/supervisor access to other branches.
create or replace function public.ff38_dispatch(p_order uuid,p_driver uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_role text; v_branch uuid;
begin
 select role into v_role from public.ff_profiles where user_id=auth.uid() and active;
 if v_role is null or not public.ff38_permission_allowed(auth.uid(),'assign_driver') then
  raise exception 'لا تملك صلاحية توزيع الطلبات' using errcode='42501';
 end if;
 if p_order is null then raise exception 'الطلب غير متاح لصلاحيات حسابك' using errcode='42501'; end if;
 -- Acquire the same order lock first as the internal dispatcher.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('ff38-o-'||p_order::text));
 select branch_id into v_branch from public.ff_orders where id=p_order for update;
 if v_branch is null or not public.ff49_can_work_branch(v_branch,array[v_role]) then
  raise exception 'الطلب غير متاح لصلاحيات حسابك' using errcode='42501';
 end if;
 return public.ff38__offer_next(p_order,p_driver);
end $function$;
revoke execute on function public.ff38_dispatch(uuid,uuid) from public,anon;
grant execute on function public.ff38_dispatch(uuid,uuid) to authenticated;
