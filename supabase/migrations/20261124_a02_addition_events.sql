-- FIX-08: durable events after a complete addition is saved, and role-scoped archive details.
-- Do not alter order state, historical records, staff roles or delivery fees.
CREATE OR REPLACE FUNCTION ff_private.a02_record_addition_event()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE a public.ff38_order_additions%ROWTYPE; v_action text; v_from text; v_to text; v_branch uuid; v_items jsonb;
BEGIN
 IF TG_TABLE_NAME='ff38_order_additions' THEN
  a:=NEW;
  IF OLD.amount=0 AND NEW.amount>0 AND OLD.status='pending' AND NEW.status='pending' THEN
   v_action:='addition_created';v_from:=NULL;v_to:=NEW.status;
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
   v_action:=CASE NEW.status WHEN 'invoiced' THEN 'addition_invoiced' WHEN 'cancelled' THEN 'addition_cancelled' END;
   v_from:=OLD.status;v_to:=NEW.status;
  END IF;
 ELSE
  IF NEW.state IS NOT DISTINCT FROM OLD.state THEN RETURN NEW;END IF;
  SELECT * INTO STRICT a FROM public.ff38_order_additions WHERE id=NEW.addition_id;
  v_action:='addition_late_state';v_from:=OLD.state;v_to:=NEW.state;
 END IF;
 IF v_action IS NULL THEN RETURN NEW;END IF;
 SELECT branch_id INTO STRICT v_branch FROM public.ff_orders WHERE id=a.order_id;
 SELECT coalesce(jsonb_agg(jsonb_build_object('item_name',i.item_name,'quantity',i.quantity,'unit_price',i.unit_price,'line_total',i.line_total,'item_notes',i.item_notes) ORDER BY i.id),'[]'::jsonb)
 INTO v_items FROM public.ff38_order_addition_items i WHERE i.addition_id=a.id;
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details)
 VALUES(auth.uid(),v_action,'order_addition_event',a.id::text,v_branch,jsonb_build_object('order_id',a.order_id,'from_state',v_from,'to_state',v_to,'amount',a.amount,'addition_notes',a.addition_notes,'items',v_items,
 'invoice_ref',(SELECT invoice_ref FROM public.ff52_addition_pos WHERE addition_id=a.id)));
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION ff_private.a02_record_addition_event() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS ff_a02_addition_event ON public.ff38_order_additions;
CREATE TRIGGER ff_a02_addition_event AFTER UPDATE OF amount,status ON public.ff38_order_additions FOR EACH ROW EXECUTE FUNCTION ff_private.a02_record_addition_event();
DROP TRIGGER IF EXISTS ff_a02_late_addition_event ON public.ff52_late_addition_consent;
CREATE TRIGGER ff_a02_late_addition_event AFTER UPDATE OF state ON public.ff52_late_addition_consent FOR EACH ROW EXECUTE FUNCTION ff_private.a02_record_addition_event();
-- The reserved server event type cannot be forged through the existing client audit INSERT policy.
DROP POLICY IF EXISTS ff_a02_protect_addition_events ON public.ff_audit_log;
CREATE POLICY ff_a02_protect_addition_events ON public.ff_audit_log AS RESTRICTIVE FOR INSERT TO authenticated,anon WITH CHECK (entity_type <> 'order_addition_event');
CREATE OR REPLACE FUNCTION public.ff51_order_archive(p_from date, p_to date, p_branch uuid DEFAULT NULL::uuid, p_status text DEFAULT NULL::text, p_limit integer DEFAULT 60, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                                           DECLARE v_role text;v_rows jsonb;v_total bigint;
                                                           BEGIN
                                                            SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active=true;
                                                             IF v_role IS NULL OR v_role NOT IN ('manager','customer_service','cashier','supervisor') THEN
                                                               RAISE EXCEPTION 'غير مصرح بالأرشيف' USING ERRCODE='42501'; END IF;
                                                                IF p_from IS NULL OR p_to IS NULL OR p_to<p_from OR p_to-p_from>366 THEN
                                                                  RAISE EXCEPTION 'الفترة مطلوبة وبحد أقصى سنة'; END IF;
                                                                   IF p_status IS NOT NULL AND p_status NOT IN ('delivered','cancelled','sent','new') THEN
                                                                     RAISE EXCEPTION 'فلتر الحالة غير مدعوم'; END IF;
                                                                      SELECT count(*) INTO v_total FROM public.ff_orders o
                                                                       WHERE o.order_type='delivery'
                                                                        AND o.business_date BETWEEN p_from AND p_to
                                                                         
                                                                          AND (p_branch IS NULL OR o.branch_id=p_branch)
                                                                           AND (p_status IS NULL OR o.status=p_status)
                                                                            AND (v_role IN ('manager','customer_service') OR EXISTS(
                                                                              SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid() AND ub.branch_id=o.branch_id));
                                                                               SELECT coalesce(jsonb_agg(jsonb_build_object(
                                                                                 'id',o.id,'number',o.order_number,'branch_id',o.branch_id,'phone',o.phone_snapshot,
                                                                                   'customer_name',coalesce(d.customer_name,''),'channel',coalesce(d.channel,'phone'),
                                                                                     'address',coalesce(d.full_address,o.area_snapshot),'status',o.status,
                                                                                       'created_at',o.created_at,'notes',o.notes,'items_total',o.items_total,
                                                                                         'delivery_fee',o.delivery_fee,'total',o.total,'driver_name',dr.name,
                                                                                           'cashier_stage',t.cashier_stage,'driver_phase',t.phase,
                                                                                             'items',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',it.item_name,'qty',it.quantity,'price',it.unit_price,'item_notes',it.item_notes)),'[]'::jsonb)
                                                                                                        FROM public.ff_order_items it WHERE it.order_id=o.id),
                                                                                                          'events',(SELECT coalesce(jsonb_agg(to_jsonb(ev)),'[]'::jsonb)
                                                                                                                     FROM (SELECT * FROM public.ff_order_events e WHERE e.order_id=o.id LIMIT 100) ev),
                                                                                                                       'changes',(SELECT coalesce(jsonb_agg(jsonb_build_object('status',c.status,'old_items',c.old_items,
                                                                                                                             'new_items',c.new_items,'reason',c.reason,'requested_at',c.requested_at,'external_invoice_ref',c.external_invoice_ref)
                                                                                                                                   ORDER BY c.requested_at),'[]'::jsonb)
                                                                                                                                         FROM public.ff50_order_changes c WHERE c.order_id=o.id),
                                                                                                                                           'addition_events',(SELECT coalesce(jsonb_agg(jsonb_build_object('action',al.action,'created_at',al.created_at,'actor_id',al.actor_id,'details',al.details) ORDER BY al.created_at,al.id),'[]'::jsonb)
 FROM public.ff_audit_log al JOIN public.ff38_order_additions ax ON ax.id::text=al.entity_id
 WHERE ax.order_id=o.id AND al.entity_type='order_addition_event'),
 'additions',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',a.id,'status',a.status,'amount',a.amount,'created_at',a.created_at,'addition_notes',a.addition_notes,
 'invoice_ref',(SELECT invoice_ref FROM public.ff52_addition_pos pos WHERE pos.addition_id=a.id),
 'late_state',(SELECT state FROM public.ff52_late_addition_consent cs WHERE cs.addition_id=a.id),
 'items',(SELECT coalesce(jsonb_agg(jsonb_build_object('item_name',ai.item_name,'quantity',ai.quantity,'unit_price',ai.unit_price,'line_total',ai.line_total,'item_notes',ai.item_notes) ORDER BY ai.id),'[]'::jsonb) FROM public.ff38_order_addition_items ai WHERE ai.addition_id=a.id)) ORDER BY a.created_at,a.id),'[]'::jsonb)
                                                                                                                                                 FROM public.ff38_order_additions a WHERE a.order_id=o.id)
                                                                                                                                                  ) ORDER BY o.created_at DESC),'[]'::jsonb) INTO v_rows
                                                                                                                                                   FROM (SELECT * FROM public.ff_orders o
                                                                                                                                                    WHERE o.order_type='delivery'
                                                                                                                                                     AND o.business_date BETWEEN p_from AND p_to
                                                                                                                                                      
                                                                                                                                                       AND (p_branch IS NULL OR o.branch_id=p_branch)
                                                                                                                                                        AND (p_status IS NULL OR o.status=p_status)
                                                                                                                                                         AND (v_role IN ('manager','customer_service') OR EXISTS(
                                                                                                                                                           SELECT 1 FROM public.ff_user_branches ub WHERE ub.user_id=auth.uid() AND ub.branch_id=o.branch_id))
                                                                                                                                                            ORDER BY created_at DESC LIMIT greatest(1,least(coalesce(p_limit,60),150)) OFFSET greatest(0,least(coalesce(p_offset,0),100000))) o
                                                                                                                                                             LEFT JOIN public.ff49_order_details d ON d.order_id=o.id
                                                                                                                                                              LEFT JOIN public.ff38_delivery_tasks t ON t.order_id=o.id
                                                                                                                                                               LEFT JOIN public.ff_drivers dr ON dr.id=t.driver_id;
                                                                                                                                                                RETURN jsonb_build_object('total',v_total,'rows',v_rows,'offset',greatest(0,p_offset));
                                                                                                                                                                END $function$;
