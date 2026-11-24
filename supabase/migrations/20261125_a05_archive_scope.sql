-- A05: old order archive is not a route around individual report revocation or cashier desk scope.
DO $patch$
DECLARE s text:=pg_get_functiondef('public.ff51_order_archive(date,date,uuid,text,integer,integer)'::regprocedure);old text:='AND (p_branch IS NULL OR o.branch_id=p_branch)';hits int;
BEGIN
 hits:=(length(s)-length(replace(s,old,'')))/length(old);
 IF hits<>2 OR position('IF p_from IS NULL' in s)=0 THEN RAISE EXCEPTION 'Unexpected archive source';END IF;
 s:=replace(s,'IF p_from IS NULL',$body$
 IF v_role<>'manager' AND ((v_role IN ('customer_service','supervisor') AND NOT public.ff38_permission_allowed(auth.uid(),'view_reports'))
 OR EXISTS(SELECT 1 FROM public.ff38_staff_permission_overrides WHERE user_id=auth.uid() AND permission_key='view_reports' AND allowed=false)) THEN
 RAISE EXCEPTION 'صلاحية التقارير مسحوبة' USING ERRCODE='42501';END IF;
 IF p_from IS NULL$body$);
 s:=replace(s,old,old||$body$
 AND (v_role<>'cashier' OR ff_private.a05_can_read_order(o.id))
 $body$);
 EXECUTE s;
END $patch$;