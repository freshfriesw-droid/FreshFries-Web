-- Reservations without a mandatory pickup date. Legacy scheduled bookings remain unchanged.
ALTER TABLE public.ff49_reservations
 ADD COLUMN IF NOT EXISTS pickup_unspecified boolean NOT NULL DEFAULT false;
DO $patch$
DECLARE s text;
BEGIN
 SELECT pg_get_functiondef(oid) INTO s FROM pg_proc
 WHERE pronamespace='public'::regnamespace AND proname='ff49_create_reservation';
 IF s IS NULL OR position('IF p_pickup IS NULL OR p_pickup<=now()-interval ''5 minutes''' in s)=0 THEN
  RAISE EXCEPTION 'Reservation creation function changed';END IF;
 s:=replace(s,
  'IF p_pickup IS NULL OR p_pickup<=now()-interval ''5 minutes''',
  'IF (p_pickup IS NOT NULL AND p_pickup<=now()-interval ''5 minutes'')');
 IF position('INSERT INTO public.ff49_reservations(branch_id,customer_name,customer_phone,pickup_at,items,notes,created_by)' in s)=0 THEN
  RAISE EXCEPTION 'Reservation insert signature changed'; END IF;
 s:=replace(s,
  'INSERT INTO public.ff49_reservations(branch_id,customer_name,customer_phone,pickup_at,items,notes,created_by)',
  'INSERT INTO public.ff49_reservations(branch_id,customer_name,customer_phone,pickup_at,items,notes,created_by,pickup_unspecified)');
 IF position('VALUES(p_branch,btrim(p_customer_name),btrim(p_phone),p_pickup,p_items,left(coalesce(p_notes,'''')' in s)=0 THEN
  RAISE EXCEPTION 'Reservation insert values changed'; END IF;
 s:=replace(s,
  'VALUES(p_branch,btrim(p_customer_name),btrim(p_phone),p_pickup,p_items,left(coalesce(p_notes,'''')',
  'VALUES(p_branch,btrim(p_customer_name),btrim(p_phone),coalesce(p_pickup,now()),p_items,left(coalesce(p_notes,'''')');
 IF position('2000),auth.uid())' in s)=0 THEN RAISE EXCEPTION 'Reservation insert tail changed';END IF;
 s:=replace(s,'2000),auth.uid())','2000),auth.uid(),p_pickup IS NULL)');
 EXECUTE s;

 SELECT pg_get_functiondef(oid) INTO s FROM pg_proc
 WHERE pronamespace='public'::regnamespace AND proname='ff49_reservations_list';
 IF s IS NULL OR position('''customer_phone'',r.customer_phone,''pickup_at'',r.pickup_at' in s)=0 THEN
  RAISE EXCEPTION 'Reservation list changed';END IF;
 s:=replace(s,'''customer_phone'',r.customer_phone,''pickup_at'',r.pickup_at',
 '''customer_phone'',r.customer_phone,''pickup_at'',r.pickup_at,''pickup_unspecified'',r.pickup_unspecified');
 EXECUTE s;
END $patch$;
