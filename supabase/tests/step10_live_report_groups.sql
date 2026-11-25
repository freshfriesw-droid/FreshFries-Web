
DO $qa$
DECLARE actor uuid; b record; r jsonb; dy date:=public.ff_business_date(now()); start_date date:=dy-89; x jsonb; n bigint; y record; checks int:=0;
BEGIN
SELECT user_id INTO STRICT actor FROM public.ff_profiles WHERE role='manager' AND active LIMIT 1;
PERFORM set_config('request.jwt.claim.sub',actor::text,true);
FOR b IN SELECT id,code FROM public.ff_branches WHERE active UNION ALL SELECT null::uuid,'all' LOOP
r:=public.ff_a10_reporting_center(start_date,dy,b.id,NULL,NULL,NULL,NULL,NULL);
-- All order aggregations are checked against raw orders, not another reporting RPC.
WITH o AS (SELECT z.*,coalesce(t.delivered_at,z.delivered_at) AS actual_delivery FROM public.ff_orders z LEFT JOIN public.ff38_delivery_tasks t ON t.order_id=z.id WHERE z.order_type='delivery' AND z.business_date BETWEEN start_date AND dy AND ((z.created_at AT TIME ZONE 'Asia/Aden')::time>=time '08:00' OR (z.created_at AT TIME ZONE 'Asia/Aden')::time<time '02:00') AND (b.id IS NULL OR z.branch_id=b.id))
SELECT count(*) FILTER(WHERE status NOT IN('delivered','cancelled')) pending,count(*) FILTER(WHERE status<>'cancelled' AND coalesce(actual_delivery,now())-created_at>interval '60 minutes') late,
count(*) FILTER(WHERE status='delivered' AND actual_delivery-created_at>interval '60 minutes') late_completed,
count(*) FILTER(WHERE status NOT IN('delivered','cancelled') AND now()-created_at>interval '60 minutes') late_pending,
round((percentile_cont(.9) WITHIN GROUP(ORDER BY extract(epoch from(actual_delivery-created_at))/60) FILTER(WHERE status='delivered' AND actual_delivery>=created_at))::numeric,1) p90,
round(min(extract(epoch from(actual_delivery-created_at))/60) FILTER(WHERE status='delivered' AND actual_delivery>=created_at),1) fastest,
round(avg(rating),2) avg_rating,min(rating) min_rating,max(rating) max_rating,count(*) FILTER(WHERE rating<=2) low_ratings,
count(*) FILTER(WHERE delivery_fee=0) free_delivery
INTO y FROM o;
IF (r#>>'{totals,pending}')::bigint IS DISTINCT FROM y.pending OR (r#>>'{totals,late}')::bigint IS DISTINCT FROM y.late OR (r#>>'{totals,late_pending}')::bigint IS DISTINCT FROM y.late_pending OR (r#>>'{totals,late_completed}')::bigint IS DISTINCT FROM y.late_completed OR (r#>>'{totals,p90_delivery_minutes}')::numeric IS DISTINCT FROM y.p90 OR (r#>>'{totals,fastest_minutes}')::numeric IS DISTINCT FROM y.fastest OR (r#>>'{totals,rating_avg}')::numeric IS DISTINCT FROM y.avg_rating OR (r#>>'{totals,rating_min}')::numeric IS DISTINCT FROM y.min_rating OR (r#>>'{totals,rating_max}')::numeric IS DISTINCT FROM y.max_rating OR (r#>>'{totals,low_ratings}')::bigint IS DISTINCT FROM y.low_ratings OR (r#>>'{totals,free_delivery}')::bigint IS DISTINCT FROM y.free_delivery THEN RAISE EXCEPTION 'timing/status/rating mismatch %',b.code;END IF;
checks:=checks+1;
WITH o AS (SELECT z.* FROM public.ff_orders z WHERE z.order_type='delivery' AND z.business_date BETWEEN start_date AND dy AND ((z.created_at AT TIME ZONE 'Asia/Aden')::time>=time '08:00' OR (z.created_at AT TIME ZONE 'Asia/Aden')::time<time '02:00') AND (b.id IS NULL OR z.branch_id=b.id))
SELECT count(DISTINCT phone_snapshot) FILTER(WHERE nullif(btrim(phone_snapshot),'') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.ff_orders old WHERE old.phone_snapshot=o.phone_snapshot AND (old.created_at,old.id)<(o.created_at,o.id))) new_customers,
count(DISTINCT phone_snapshot) FILTER(WHERE nullif(btrim(phone_snapshot),'') IS NOT NULL AND EXISTS(SELECT 1 FROM public.ff_orders old WHERE old.phone_snapshot=o.phone_snapshot AND (old.created_at,old.id)<(o.created_at,o.id))) repeat_customers,
count(DISTINCT lower(btrim(area_snapshot))) FILTER(WHERE nullif(btrim(area_snapshot),'') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.ff_orders old WHERE lower(btrim(old.area_snapshot))=lower(btrim(o.area_snapshot)) AND (old.created_at,old.id)<(o.created_at,o.id))) new_areas INTO y FROM o;
IF (r#>>'{totals,new_customers}')::bigint IS DISTINCT FROM y.new_customers OR (r#>>'{totals,repeat_customers}')::bigint IS DISTINCT FROM y.repeat_customers OR (r#>>'{totals,new_areas}')::bigint IS DISTINCT FROM y.new_areas THEN RAISE EXCEPTION 'customer/area mismatch %',b.code;END IF;
checks:=checks+1;
FOR x IN SELECT value FROM jsonb_array_elements(r->'areas') LOOP
SELECT count(*) INTO n FROM public.ff_orders z WHERE z.order_type='delivery' AND z.business_date BETWEEN start_date AND dy AND ((z.created_at AT TIME ZONE 'Asia/Aden')::time>=time '08:00' OR (z.created_at AT TIME ZONE 'Asia/Aden')::time<time '02:00') AND (b.id IS NULL OR z.branch_id=b.id) AND coalesce(nullif(btrim(z.area_snapshot),''),'غير محددة')=x->>'area_name';
IF n IS DISTINCT FROM (x->>'orders')::bigint THEN RAISE EXCEPTION 'area detail mismatch %',b.code;END IF;
END LOOP;checks:=checks+1;
FOR x IN SELECT value FROM jsonb_array_elements(r->'service_staff') LOOP
SELECT count(*) INTO n FROM public.ff_orders z WHERE z.order_type='delivery' AND z.business_date BETWEEN start_date AND dy AND ((z.created_at AT TIME ZONE 'Asia/Aden')::time>=time '08:00' OR (z.created_at AT TIME ZONE 'Asia/Aden')::time<time '02:00') AND (b.id IS NULL OR z.branch_id=b.id) AND z.created_by IS NOT DISTINCT FROM (x->>'staff_id')::uuid;
IF n IS DISTINCT FROM (x->>'orders')::bigint THEN RAISE EXCEPTION 'staff detail mismatch %',b.code;END IF;
END LOOP;checks:=checks+1;
FOR x IN SELECT value FROM jsonb_array_elements(r->'drivers') LOOP
SELECT count(*) assigned,count(*) FILTER(WHERE z.status='delivered') delivered,coalesce(sum(z.delivery_fee) FILTER(WHERE z.status='delivered'),0) fees INTO y FROM public.ff_orders z LEFT JOIN public.ff38_delivery_tasks t ON t.order_id=z.id WHERE z.order_type='delivery' AND z.business_date BETWEEN start_date AND dy AND ((z.created_at AT TIME ZONE 'Asia/Aden')::time>=time '08:00' OR (z.created_at AT TIME ZONE 'Asia/Aden')::time<time '02:00') AND z.branch_id=(x->>'branch_id')::uuid AND coalesce(t.driver_id,z.driver_id)=(x->>'driver_id')::uuid;
IF y.assigned IS DISTINCT FROM (x->>'assigned')::bigint OR y.delivered IS DISTINCT FROM (x->>'delivered')::bigint OR y.fees IS DISTINCT FROM (x->>'delivery_fees_due')::numeric THEN RAISE EXCEPTION 'driver detail mismatch %',b.code;END IF;
END LOOP;checks:=checks+1;
FOR x IN SELECT value FROM jsonb_array_elements(r->'items') LOOP
WITH o AS (SELECT z.id FROM public.ff_orders z WHERE z.order_type='delivery' AND z.status='delivered' AND z.business_date BETWEEN start_date AND dy AND ((z.created_at AT TIME ZONE 'Asia/Aden')::time>=time '08:00' OR (z.created_at AT TIME ZONE 'Asia/Aden')::time<time '02:00') AND (b.id IS NULL OR z.branch_id=b.id)), i AS (SELECT i.quantity,i.line_total FROM o JOIN public.ff_order_items i ON i.order_id=o.id WHERE i.item_name=x->>'item_name' UNION ALL SELECT i.quantity,i.line_total FROM o JOIN public.ff38_order_additions a ON a.order_id=o.id AND a.status='invoiced' JOIN public.ff38_order_addition_items i ON i.addition_id=a.id WHERE i.item_name=x->>'item_name') SELECT sum(quantity) qty,sum(line_total) value INTO y FROM i;
IF y.qty IS DISTINCT FROM (x->>'quantity')::numeric OR y.value IS DISTINCT FROM (x->>'revenue')::numeric THEN RAISE EXCEPTION 'item detail mismatch %',b.code;END IF;
END LOOP;checks:=checks+1;
SELECT count(*) offered,count(*) FILTER(WHERE f.status='accepted') accepted,count(*) FILTER(WHERE f.status='rejected') rejected,count(*) FILTER(WHERE f.status='expired') expired INTO y FROM public.ff38_dispatch_offers f JOIN public.ff_orders z ON z.id=f.order_id WHERE z.order_type='delivery' AND z.business_date BETWEEN start_date AND dy AND ((z.created_at AT TIME ZONE 'Asia/Aden')::time>=time '08:00' OR (z.created_at AT TIME ZONE 'Asia/Aden')::time<time '02:00') AND (b.id IS NULL OR z.branch_id=b.id);
IF y.offered IS DISTINCT FROM (r#>>'{dispatch,offered}')::bigint OR y.accepted IS DISTINCT FROM (r#>>'{dispatch,accepted}')::bigint OR y.rejected IS DISTINCT FROM (r#>>'{dispatch,rejected}')::bigint OR y.expired IS DISTINCT FROM (r#>>'{dispatch,expired}')::bigint THEN RAISE EXCEPTION 'dispatch mismatch %',b.code;END IF;checks:=checks+1;
SELECT count(*) INTO n FROM public.ff41_cases c WHERE c.kind='customer_complaint' AND public.ff_business_date(c.created_at) BETWEEN start_date AND dy AND (b.id IS NULL OR c.branch_id=b.id);
IF jsonb_array_length(r->'complaints') IS DISTINCT FROM least(n,80)::integer THEN RAISE EXCEPTION 'complaint mismatch %',b.code;END IF;checks:=checks+1;
SELECT count(*) INTO n FROM public.ff49_reservations q WHERE public.ff_business_date(q.created_at) BETWEEN start_date AND dy AND (b.id IS NULL OR q.branch_id=b.id);
IF n IS DISTINCT FROM (r#>>'{reservation_summary,total}')::bigint THEN RAISE EXCEPTION 'reservation mismatch %',b.code;END IF;checks:=checks+1;
END LOOP;
IF checks<>36 THEN RAISE EXCEPTION 'Branch coverage incomplete';END IF;
END $qa$;
SELECT 'PASS STEP10: 36 live source group checks across three branches and consolidated; timing/status/ratings, customer/area, staff, courier, items, dispatch, complaints and reservations' result;