-- FIX-12/13: branch-only realtime hints; payload holds no order/customer/financial data.
CREATE TABLE IF NOT EXISTS public.ff27_branch_updates(
 branch_id uuid PRIMARY KEY REFERENCES public.ff_branches(id) ON DELETE CASCADE,
 revision bigint NOT NULL DEFAULT 0,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE public.ff27_branch_updates ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ff27_branch_updates FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.ff27_branch_updates TO authenticated;
CREATE POLICY ff27_branch_updates_read ON public.ff27_branch_updates FOR SELECT TO authenticated
 USING (
 EXISTS(SELECT 1 FROM public.ff_profiles p JOIN public.ff_user_branches ub ON ub.user_id=p.user_id
 JOIN public.ff_branches b ON b.id=ub.branch_id AND b.active
 WHERE p.user_id=auth.uid() AND p.active AND ub.branch_id=ff27_branch_updates.branch_id
 AND (p.role='cashier' OR (p.role='assembly' AND (public.ff_v12_assembly_me()->'branch'->>'id')=ff27_branch_updates.branch_id::text)))
 );
CREATE OR REPLACE FUNCTION ff_private.a04_emit_branch_stage()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $body$
DECLARE b uuid;
BEGIN
 IF TG_OP='UPDATE' AND NEW.cashier_stage IS NOT DISTINCT FROM OLD.cashier_stage
 AND NEW.driver_id IS NOT DISTINCT FROM OLD.driver_id AND NEW.phase IS NOT DISTINCT FROM OLD.phase THEN RETURN NEW; END IF;
 SELECT branch_id INTO b FROM public.ff_orders WHERE id=NEW.order_id;
 IF b IS NOT NULL THEN
 INSERT INTO public.ff27_branch_updates(branch_id,revision,updated_at) VALUES(b,1,clock_timestamp())
 ON CONFLICT(branch_id) DO UPDATE SET revision=public.ff27_branch_updates.revision+1,updated_at=clock_timestamp();
 END IF;
 RETURN NEW;
END $body$;
REVOKE EXECUTE ON FUNCTION ff_private.a04_emit_branch_stage() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER a04_emit_branch_stage AFTER INSERT OR UPDATE OF cashier_stage,driver_id,phase ON public.ff38_delivery_tasks
 FOR EACH ROW EXECUTE FUNCTION ff_private.a04_emit_branch_stage();
DO $pub$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='ff27_branch_updates') THEN
 ALTER PUBLICATION supabase_realtime ADD TABLE public.ff27_branch_updates;
 END IF;
END $pub$;
-- Use the same live scope for realtime ticket rows as for ff_burger_list.
-- This helper returns only a boolean for the caller's own current branch.
CREATE OR REPLACE FUNCTION ff_private.a04_burger_branch_read(p_branch uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $body$
 SELECT EXISTS(SELECT 1 FROM public.ff_profiles p
 JOIN public.ff_user_branches ub ON ub.user_id=p.user_id
 JOIN public.ff_branches b ON b.id=ub.branch_id AND b.active
 WHERE p.user_id=auth.uid() AND p.active AND ub.branch_id=p_branch
 AND (p.role='cashier' OR (p.role='burger_kitchen' AND
 (SELECT count(*) FROM public.ff_user_branches u JOIN public.ff_branches br ON br.id=u.branch_id AND br.active WHERE u.user_id=p.user_id)=1)
 OR (p.role='assembly' AND (public.ff_v12_assembly_me()->'branch'->>'id')=p_branch::text
 AND (SELECT count(*) FROM public.ff_user_branches u JOIN public.ff_branches br ON br.id=u.branch_id AND br.active WHERE u.user_id=p.user_id)=1)));
$body$;
REVOKE EXECUTE ON FUNCTION ff_private.a04_burger_branch_read(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION ff_private.a04_burger_branch_read(uuid) TO authenticated;
ALTER POLICY ff_burger_ticket_branch_read ON public.ff_burger_tickets TO authenticated
 USING (ff_private.a04_burger_branch_read(branch_id));
