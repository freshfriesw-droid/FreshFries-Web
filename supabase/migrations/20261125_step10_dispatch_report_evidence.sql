-- STEP10: record dispatch origin at the actual successful dispatch boundary.
-- No historical inference, no new foreign key or changes to routing/capacity.
-- Retain evidence in the existing audit log (which is preserved by recovery).
CREATE POLICY ff_step10_dispatch_evidence_server_only ON public.ff_audit_log AS RESTRICTIVE FOR INSERT TO anon,authenticated WITH CHECK(entity_type <> 'dispatch_report_evidence' AND action <> 'step10_dispatch_evidence');
DO $migration$
DECLARE d text; old_c text:='RETURN jsonb_build_object(''state'',''assigned_cumulative'',''driver_id'',v_driver,''order_id'',p_order);'; old_o text:='RETURN jsonb_build_object(''state'',''offered'',''offer_id'',v_offer,''driver_id'',v_driver);'; a text; b text; prior text; replacement text;
BEGIN
 d:=pg_get_functiondef('public.ff38__offer_next(uuid,uuid)'::regprocedure);
 IF (length(d)-length(replace(d,old_c,'')))/length(old_c)<>1 OR (length(d)-length(replace(d,old_o,'')))/length(old_o)<>1 THEN RAISE EXCEPTION 'Unexpected dispatch source'; END IF;
 a:=$body$INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 VALUES(auth.uid(),'step10_dispatch_evidence','dispatch_report_evidence',p_order::text,v_order.branch_id,
 jsonb_build_object('mode',CASE WHEN p_driver IS NULL THEN 'automatic' ELSE 'manual' END,'kind','cumulative','driver_id',v_driver,'special',EXISTS(SELECT 1 FROM ff_private.special_courier_capacity c WHERE c.driver_id=v_driver)));
 $body$||old_c;
 b:=$body$INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 VALUES(auth.uid(),'step10_dispatch_evidence','dispatch_report_evidence',p_order::text,v_order.branch_id,
 jsonb_build_object('mode',CASE WHEN p_driver IS NULL THEN 'automatic' ELSE 'manual' END,'kind','offer','offer_id',v_offer,'driver_id',v_driver,'special',EXISTS(SELECT 1 FROM ff_private.special_courier_capacity c WHERE c.driver_id=v_driver)));
 $body$||old_o;
 EXECUTE replace(replace(d,old_c,a),old_o,b);
 d:=pg_get_functiondef('ff_private.a10_report_core(date,date,uuid,uuid,uuid,text,text,text)'::regprocedure);
 prior:=$body$'special_direct_confirmed',NULL) FROM scoped)$body$;
 replacement:=$body$'special_direct_confirmed',(SELECT count(DISTINCT z.id) FROM scoped z JOIN public.ff_audit_log e ON e.entity_id=z.id::text AND e.branch_id=z.branch_id WHERE e.entity_type='dispatch_report_evidence' AND e.action='step10_dispatch_evidence' AND e.details->>'kind'='cumulative' AND e.details->>'mode'='manual' AND e.details->>'special'='true' AND (p_driver IS NULL OR e.details->>'driver_id'=p_driver::text) AND (v_role<>'driver' OR e.details->>'driver_id'=v_driver::text)),
 'automatic_confirmed',(SELECT count(DISTINCT z.id) FROM scoped z JOIN public.ff_audit_log e ON e.entity_id=z.id::text AND e.branch_id=z.branch_id WHERE e.entity_type='dispatch_report_evidence' AND e.action='step10_dispatch_evidence' AND e.details->>'mode'='automatic' AND (e.details->>'kind'='cumulative' OR EXISTS(SELECT 1 FROM public.ff38_dispatch_offers f WHERE f.id::text=e.details->>'offer_id' AND f.order_id=z.id AND f.status='accepted')) AND (p_driver IS NULL OR e.details->>'driver_id'=p_driver::text) AND (v_role<>'driver' OR e.details->>'driver_id'=v_driver::text)),
 'manual_confirmed',(SELECT count(DISTINCT z.id) FROM scoped z JOIN public.ff_audit_log e ON e.entity_id=z.id::text AND e.branch_id=z.branch_id WHERE e.entity_type='dispatch_report_evidence' AND e.action='step10_dispatch_evidence' AND e.details->>'mode'='manual' AND (e.details->>'kind'='cumulative' OR EXISTS(SELECT 1 FROM public.ff38_dispatch_offers f WHERE f.id::text=e.details->>'offer_id' AND f.order_id=z.id AND f.status='accepted')) AND (p_driver IS NULL OR e.details->>'driver_id'=p_driver::text) AND (v_role<>'driver' OR e.details->>'driver_id'=v_driver::text)),
 'evidence_events',(SELECT count(*) FROM scoped z JOIN public.ff_audit_log e ON e.entity_id=z.id::text AND e.branch_id=z.branch_id WHERE e.entity_type='dispatch_report_evidence' AND e.action='step10_dispatch_evidence' AND (p_driver IS NULL OR e.details->>'driver_id'=p_driver::text) AND (v_role<>'driver' OR e.details->>'driver_id'=v_driver::text))) FROM scoped)$body$;
 IF (length(d)-length(replace(d,prior,'')))/length(prior)<>1 THEN RAISE EXCEPTION 'Unexpected report assignment source';END IF;
 EXECUTE replace(d,prior,replacement);
END $migration$;
