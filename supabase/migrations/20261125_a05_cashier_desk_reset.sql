-- A05: remove only invalid cashier routing after a role/branch change.
DO $patch$
DECLARE s text; needle text:='SELECT coalesce(pg_catalog.jsonb_agg(branch_id ORDER BY branch_id),''[]''::jsonb)' ;
BEGIN
 SELECT pg_get_functiondef('public.ff38_admin_staff_set_access(uuid,text,uuid[])'::regprocedure) INTO s;
 IF position('INTO v_new_branches' in s)=0 THEN RAISE EXCEPTION 'staff access source mismatch';END IF;
 -- The same SELECT appears twice; insert just before final return using unique audit insertion.
 needle:='INSERT INTO public.ff38_staff_admin_audit(actor_id,target_user_id,action,old_data,new_data)';
 IF position(needle in s)=0 OR position('a05_cashier_desk_reset' in s)>0 THEN RAISE EXCEPTION 'staff audit patch mismatch';END IF;
 s:=replace(s,needle,$body$
 WITH removed AS (
 DELETE FROM public.ff_luxe_cashier_staff_desks sd WHERE sd.user_id=p_user
 AND (p_role<>'cashier' OR NOT EXISTS(
 SELECT 1 FROM public.ff_luxe_cashier_desks d JOIN public.ff_user_branches ub ON ub.branch_id=d.branch_id
 WHERE d.code=sd.desk_code AND d.active AND ub.user_id=p_user))
 RETURNING desk_code)
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,details)
 SELECT auth.uid(),'a05_cashier_desk_reset','employee',p_user,jsonb_build_object('old_desk',desk_code,'new_role',p_role) FROM removed;
 $body$||needle);
 EXECUTE s;
END $patch$;
-- Assembly conversion changes role after the ordinary access function.
CREATE OR REPLACE FUNCTION ff_private.a05_clear_non_cashier_desk() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $body$
BEGIN
 IF OLD.role='cashier' AND NEW.role<>'cashier' THEN
 WITH removed AS (DELETE FROM public.ff_luxe_cashier_staff_desks WHERE user_id=NEW.user_id RETURNING desk_code)
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,details)
 SELECT auth.uid(),'a05_cashier_desk_reset','employee',NEW.user_id,jsonb_build_object('old_desk',desk_code,'new_role',NEW.role) FROM removed;
 END IF;
 RETURN NEW;
END $body$;
REVOKE ALL ON FUNCTION ff_private.a05_clear_non_cashier_desk() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER a05_clear_non_cashier_desk AFTER UPDATE OF role ON public.ff_profiles FOR EACH ROW EXECUTE FUNCTION ff_private.a05_clear_non_cashier_desk();