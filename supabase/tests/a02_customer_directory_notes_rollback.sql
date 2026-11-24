DO $qa$
DECLARE
 a uuid;b uuid;k uuid;ca uuid;r1 uuid:=gen_random_uuid();r2 uuid:=gen_random_uuid();
 o1 uuid;o2 uuid;n1 uuid;n2 uuid;pa text;pb text;price numeric;inp jsonb;
 res jsonb;d jsonb;state text;prev text;checks int:=0;
BEGIN
 SELECT user_id INTO STRICT a FROM public.ff_profiles WHERE active AND role='customer_service' LIMIT 1;
 SELECT user_id INTO STRICT ca FROM public.ff_profiles WHERE active AND role='cashier' LIMIT 1;
 SELECT id INTO STRICT k FROM public.ff_branches WHERE active AND code='khamseen';
 SELECT m.price INTO STRICT price FROM public.ff_menu_items m WHERE active AND name='تشكن فرايز';
 pa:='7'||lpad((floor(random()*100000000)::bigint)::text,8,'0');
 pb:='7'||lpad((floor(random()*100000000)::bigint)::text,8,'0');
 IF pa=pb OR EXISTS(SELECT 1 FROM public.ff_orders WHERE ff_private.customer_phone_key(phone_snapshot) IN(pa,pb))
 OR EXISTS(SELECT 1 FROM public.ff51_customer_notes WHERE ff_private.customer_phone_key(phone) IN(pa,pb)) THEN RAISE EXCEPTION 'QA number collision';END IF;
 prev:=current_setting('request.jwt.claim.sub',true);
 PERFORM set_config('lock_timeout','3s',true);
 BEGIN
  PERFORM set_config('request.jwt.claim.sub',a::text,true);
  SET LOCAL ROLE authenticated;
  inp:=jsonb_build_object('p_branch',k,'p_phone',pa,'p_area','QA area',
   'p_items',jsonb_build_array(jsonb_build_object('name','تشكن فرايز','qty',1,'price',price,'item_notes','')),
   'p_delivery_fee',0,'p_customer_name','QA customer A','p_channel','phone','p_full_address','QA address','p_notes','A02_DIRECTORY_QA');
  o1:=(public.ff27_submit(r1,'delivery',inp)->>'order_id')::uuid;
  o2:=(public.ff27_submit(r2,'delivery',jsonb_set(inp,'{p_phone}',to_jsonb('+967'||pa)))->>'order_id')::uuid;
  n1:=(public.ff51_customer_note_add('00967'||pa,'QA original note')->>'note_id')::uuid;
  d:=public.ff51_customer_directory('+967'||pa,10);
  IF jsonb_array_length(d)<>1 OR d->0->>'phone'<>pa OR (d->0->>'orders_count')::int<>2 OR (d->0->>'notes_count')::int<>1 THEN RAISE EXCEPTION 'Directory grouping mismatch';END IF;
  d:=public.ff51_customer_notes_list(translate(pa,'0123456789','٠١٢٣٤٥٦٧٨٩'));
  IF jsonb_array_length(d)<>1 OR d->0->>'note'<>'QA original note' THEN RAISE EXCEPTION 'Equivalent phone notes missing';END IF;
  checks:=checks+2;
  res:=public.ff_order_customer_edit_with_note(o1,pb,'QA area B','QA customer B','QA address B','QA correct number','QA new note');
  n2:=(res->>'note_id')::uuid;
  IF NOT coalesce((res->>'saved')::boolean,false) OR NOT coalesce((res->>'note_saved')::boolean,false) OR n2 IS NULL THEN RAISE EXCEPTION 'Atomic note not saved';END IF;
  d:=public.ff51_customer_directory(pa,10);
  IF jsonb_array_length(d)<>1 OR (d->0->>'orders_count')::int<>1 OR (d->0->>'notes_count')::int<>1 THEN RAISE EXCEPTION 'Original identity changed incorrectly';END IF;
  d:=public.ff51_customer_directory(pb,10);
  IF jsonb_array_length(d)<>1 OR (d->0->>'orders_count')::int<>1 OR (d->0->>'notes_count')::int<>1 THEN RAISE EXCEPTION 'Corrected identity missing';END IF;
  d:=public.ff51_customer_notes_list(pb);
  IF jsonb_array_length(d)<>1 OR d->0->>'note'<>'QA new note' THEN RAISE EXCEPTION 'Note crossed identity';END IF;
  checks:=checks+4;
  state:=NULL;
  BEGIN PERFORM public.ff_order_customer_edit_with_note(o1,pb,'QA invalid area','QA customer B','QA invalid address','QA rollback test','x');
  EXCEPTION WHEN SQLSTATE '22023' THEN state:=SQLSTATE;END;
  IF state IS DISTINCT FROM '22023' THEN RAISE EXCEPTION 'Invalid note not rejected';END IF;
  checks:=checks+1;
  PERFORM set_config('request.jwt.claim.sub',ca::text,true);
  state:=NULL;
  BEGIN PERFORM public.ff_order_customer_edit_with_note(o1,pb,'QA area B','QA customer B','QA address B','QA permission test','QA private note');
  EXCEPTION WHEN SQLSTATE '42501' THEN state:=SQLSTATE;END;
  IF state IS DISTINCT FROM '42501' THEN RAISE EXCEPTION 'Cashier note permission bypass';END IF;
  state:=NULL;
  BEGIN PERFORM public.ff51_customer_notes_list(pb);EXCEPTION WHEN SQLSTATE '42501' THEN state:=SQLSTATE;END;
  IF state IS DISTINCT FROM '42501' THEN RAISE EXCEPTION 'Cashier private note read bypass';END IF;
  checks:=checks+2;
  RESET ROLE;
  IF NOT EXISTS(SELECT 1 FROM public.ff_orders WHERE id=o1 AND phone_snapshot=pb AND area_snapshot='QA area B')
  OR NOT EXISTS(SELECT 1 FROM public.ff49_order_details WHERE order_id=o1 AND full_address='QA address B')
  OR NOT EXISTS(SELECT 1 FROM public.ff_orders WHERE id=o2 AND phone_snapshot='+967'||pa)
  OR NOT EXISTS(SELECT 1 FROM public.ff_audit_log WHERE action='customer_note_from_order' AND entity_id=o1::text AND details->>'note_id'=n2::text)
  THEN RAISE EXCEPTION 'Atomic edit rollback/audit/historical snapshot mismatch';END IF;
  checks:=checks+1;
  RAISE EXCEPTION 'QA rollback sentinel' USING ERRCODE='ZQ001';
 EXCEPTION WHEN SQLSTATE 'ZQ001' THEN NULL;END;
 IF checks<>10 OR o1 IS NULL OR o2 IS NULL OR n1 IS NULL OR n2 IS NULL
 OR EXISTS(SELECT 1 FROM public.ff_orders WHERE id IN(o1,o2))
 OR EXISTS(SELECT 1 FROM public.ff51_customer_notes WHERE id IN(n1,n2))
 OR EXISTS(SELECT 1 FROM public.ff70_atomic_requests WHERE request_id IN(r1,r2))
 OR EXISTS(SELECT 1 FROM public.ff_push_jobs WHERE order_id IN(o1,o2)) THEN RAISE EXCEPTION 'QA rollback failure';END IF;
 PERFORM set_config('request.jwt.claim.sub',coalesce(prev,''),true);
END $qa$;
SELECT 'PASS: equivalent phone directory grouping and notes, corrected identity isolation, atomic edit-note audit, invalid-note rollback, cashier denial, full cleanup' AS result;