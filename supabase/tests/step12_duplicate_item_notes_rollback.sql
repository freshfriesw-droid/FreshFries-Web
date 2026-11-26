BEGIN;
DO $qa$
DECLARE b uuid:=gen_random_uuid();m uuid:=gen_random_uuid();o uuid:=gen_random_uuid();v jsonb;first_id uuid:=gen_random_uuid();second_id uuid:=gen_random_uuid();third_id uuid:=gen_random_uuid();tmp uuid;checks int:=0;
BEGIN
 IF first_id>second_id THEN tmp:=first_id;first_id:=second_id;second_id:=tmp;END IF;
 INSERT INTO auth.users(id) VALUES(m);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP12 duplicate notes','manager',true);
 PERFORM set_config('request.jwt.claim.sub',m::text,true);
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-step12-duplicate-'||b,'QA STEP12 duplicate');
 INSERT INTO public.ff_orders(id,order_number,branch_id,phone_snapshot,area_snapshot,status,created_by,items_total,delivery_fee,total) VALUES(o,-1000000000000-floor(random()*1e12)::bigint,b,'000000000','QA area','new',m,400,0,400);
 INSERT INTO public.ff_order_items(id,order_id,item_name,quantity,unit_price,line_total) VALUES(first_id,o,'QA STEP12 same item',1,100,100),(second_id,o,'QA STEP12 same item',1,100,100),(third_id,o,'QA STEP12 same item',2,100,200);
 SET LOCAL ROLE authenticated;
 v:=public.ff70_set_item_notes(o,'[{"name":"QA STEP12 same item","qty":1,"price":100,"item_notes":"first"},{"name":" QA STEP12 same item ","qty":1.0,"price":100.0,"item_notes":"second"},{"name":"QA STEP12 same item","qty":2,"price":100,"item_notes":"third"}]');
 IF v->>'updated' IS DISTINCT FROM '3' THEN RAISE EXCEPTION 'Duplicate count mismatch %',v;END IF;checks:=checks+1;
 RESET ROLE;
 IF (SELECT item_notes FROM public.ff_order_items WHERE id=first_id) IS DISTINCT FROM 'first' OR (SELECT item_notes FROM public.ff_order_items WHERE id=second_id) IS DISTINCT FROM 'second' OR (SELECT item_notes FROM public.ff_order_items WHERE id=third_id) IS DISTINCT FROM 'third' THEN RAISE EXCEPTION 'Duplicate notes mapped incorrectly';END IF;checks:=checks+1;
 IF (SELECT sum(line_total) FROM public.ff_order_items WHERE order_id=o)<>400 OR (SELECT total FROM public.ff_orders WHERE id=o)<>400 THEN RAISE EXCEPTION 'Financial mutation';END IF;checks:=checks+1;
 SET LOCAL ROLE authenticated;
 v:=public.ff70_set_item_notes(o,'[{"name":" QA STEP12 same item ","qty":"1.00","price":"100.00","item_notes":"again first"},{"name":"QA STEP12 same item","qty":1,"price":100,"item_notes":"again second"},{"name":"QA STEP12 same item","qty":2,"price":100,"item_notes":"again third"}]');
 IF v->>'updated' IS DISTINCT FROM '3' THEN RAISE EXCEPTION 'Numeric text retry mismatch';END IF;checks:=checks+1;
 RESET ROLE;
 IF (SELECT item_notes FROM public.ff_order_items WHERE id=first_id) IS DISTINCT FROM 'again first' OR (SELECT item_notes FROM public.ff_order_items WHERE id=second_id) IS DISTINCT FROM 'again second' OR (SELECT item_notes FROM public.ff_order_items WHERE id=third_id) IS DISTINCT FROM 'again third' THEN RAISE EXCEPTION 'Retry mapping mismatch';END IF;checks:=checks+1;
 IF checks<>5 THEN RAISE EXCEPTION 'Assertion count %',checks;END IF;
END $qa$;
SELECT 'PASS STEP12 normalized duplicate item notes: 5 assertions; rollback' result;
ROLLBACK;
