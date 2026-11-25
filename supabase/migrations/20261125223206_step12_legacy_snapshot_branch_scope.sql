-- STEP12: scope the legacy snapshot and inherited readers before pagination.
CREATE OR REPLACE FUNCTION public.ff38_snapshot()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
                                DECLARE v_role text;v_driver uuid;v_branch uuid;v_data jsonb;
                                BEGIN
                                 SELECT role INTO v_role FROM public.ff_profiles WHERE user_id=auth.uid() AND active LIMIT 1;
                                  IF v_role IS NULL OR v_role NOT IN ('manager','customer_service','cashier','driver','supervisor') THEN
                                    RAISE EXCEPTION 'حسابك غير مفعل في نظام v38' USING ERRCODE='42501'; END IF;
                                     SELECT driver_id INTO v_driver FROM public.ff38_driver_links WHERE user_id=auth.uid();
                                      IF v_role='driver' AND v_driver IS NULL THEN RAISE EXCEPTION 'يجب أن يربط المدير حسابك بالموصل أولاً' USING ERRCODE='42501'; END IF;
                                       
                                        SELECT jsonb_build_object(
                                          'role',v_role,'user_id',auth.uid(),'driver_id',v_driver,
                                            'my_presence',(SELECT p.state FROM public.ff38_driver_presence p WHERE p.driver_id=v_driver),
                                              'branches',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',b.id,'name',b.name,'code',b.code) ORDER BY b.name),'[]'::jsonb)
                                                  FROM public.ff_branches b WHERE b.active AND ff_private.a10_branch_visible(v_role,b.id)),
                                                    'drivers',CASE WHEN v_role IN ('manager','customer_service','supervisor') THEN
                                                       (SELECT coalesce(jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,'branch_id',d.branch_id,
                                                            'state',coalesce(p.state,'offline'),'last_seen_at',p.last_seen_at,
                                                                 'connected',coalesce(p.last_seen_at>now()-interval '90 seconds',false),
                                                                      'active_count',(SELECT count(*) FROM public.ff38_delivery_tasks t WHERE t.driver_id=d.id AND t.delivered_at IS NULL)) ORDER BY d.name),'[]'::jsonb)
                                                                           FROM public.ff_drivers d LEFT JOIN public.ff38_driver_presence p ON p.driver_id=d.id WHERE d.active AND ff_private.a10_branch_visible(v_role,d.branch_id))
                                                                              ELSE '[]'::jsonb END,
                                                                                'offers',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',f.id,'order_id',f.order_id,'driver_id',f.driver_id,
                                                                                     'status',f.status,'expires_at',f.expires_at,'order_number',o.order_number,'area',o.area_snapshot,
                                                                                          'branch_id',o.branch_id,'offered_at',f.offered_at) ORDER BY f.offered_at DESC),'[]'::jsonb)
                                                                                              FROM public.ff38_dispatch_offers f JOIN public.ff_orders o ON o.id=f.order_id
                                                                                                  WHERE f.status='offered' AND f.expires_at>now() AND ff_private.a10_branch_visible(v_role,o.branch_id) AND (v_role IN ('manager','customer_service','supervisor') OR (v_role='driver' AND f.driver_id=v_driver))),
                                                                                                    'orders',(SELECT coalesce(jsonb_agg(jsonb_build_object(
                                                                                                          'id',o.id,'number',o.order_number,'branch_id',o.branch_id,'area',o.area_snapshot,
                                                                                                                'phone',CASE WHEN v_role='driver' AND (t.driver_id IS DISTINCT FROM v_driver) THEN '' ELSE o.phone_snapshot END,
                                                                                                                      'notes',o.notes,'delivery_fee',o.delivery_fee,'items_total',o.items_total,'total',o.total,
                                                                                                                            'status',o.status,'driver_id',t.driver_id,'driver_name',assigned_driver.name,'phase',t.phase,'cashier_stage',t.cashier_stage,
                                                                                                                                  'created_at',o.created_at,'assigned_at',t.assigned_at,'picked_up_at',t.picked_up_at,
                                                                                                                                        'delivered_at',t.delivered_at,
                                                                                                                                              'items',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',it.item_name,'item_notes',it.item_notes,'qty',it.quantity,'price',it.unit_price) ORDER BY it.item_name),'[]'::jsonb)
                                                                                                                                                      FROM public.ff_order_items it WHERE it.order_id=o.id)) ORDER BY o.created_at DESC),'[]'::jsonb)
                                                                                                                                                          FROM (SELECT candidate.* FROM public.ff_orders candidate
 WHERE candidate.order_type='delivery' AND candidate.created_at>now()-interval '14 days'
 AND ff_private.a10_branch_visible(v_role,candidate.branch_id)
 AND (v_role IN ('manager','customer_service','supervisor')
 OR (v_role='cashier' AND ff_private.a05_can_read_order(candidate.id))
 OR (v_role='driver' AND EXISTS(SELECT 1 FROM public.ff38_delivery_tasks dt WHERE dt.order_id=candidate.id AND dt.driver_id=v_driver)))
 ORDER BY candidate.created_at DESC LIMIT 300) o
                                                                                                                                                              LEFT JOIN public.ff38_delivery_tasks t ON t.order_id=o.id
                                                                                                                                                                  LEFT JOIN public.ff_drivers assigned_driver ON assigned_driver.id=t.driver_id
                                                                                                                                                                      WHERE ff_private.a10_branch_visible(v_role,o.branch_id)
 AND (v_role IN ('manager','customer_service','supervisor')
                                                                                                                                                                                       OR (v_role='cashier' AND ff_private.a05_can_read_order(o.id))
                                                                                                                                                                                                  OR (v_role='driver' AND t.driver_id=v_driver))
                                                                                                                                                                                                      )
                                                                                                                                                                                                       ) INTO v_data;
                                                                                                                                                                                                        RETURN v_data;
                                                                                                                                                                                                        END $function$;
