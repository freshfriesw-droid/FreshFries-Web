-- A03 TR-42: expose the assigned offer courier's business contact number only
-- to manager/customer_service, and only for currently visible active offers.
-- Do not expose the entire staff phone directory or change existing role scope.
DO $migration$
DECLARE src text:=pg_get_functiondef('public.ff49_snapshot()'::regprocedure);
 marker text:=' return v_data;';
 patched text:=$body$
 if v_role in ('manager','customer_service') then
  v_data:=jsonb_set(v_data,'{offers}',coalesce((
   select jsonb_agg(e.obj||jsonb_build_object('driver_phone',nullif(btrim(d.phone),'')) order by e.ord)
   from jsonb_array_elements(coalesce(v_data->'offers','[]'::jsonb)) with ordinality e(obj,ord)
   left join public.ff_drivers d on d.id=(e.obj->>'driver_id')::uuid
    and d.branch_id=(e.obj->>'branch_id')::uuid and d.active
  ),'[]'::jsonb),true);
 end if;
 return v_data;$body$;
BEGIN
 IF strpos(src,marker)=0 OR strpos(substr(src,strpos(src,marker)+length(marker)),marker)>0 THEN
 RAISE EXCEPTION 'Unexpected ff49_snapshot source'; END IF;
 EXECUTE replace(src,marker,patched);
END $migration$;
