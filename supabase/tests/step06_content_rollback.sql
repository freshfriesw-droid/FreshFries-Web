-- STEP06 regression on actual database, without persistent synthetic data.
BEGIN;
DO $qa$
DECLARE m uuid:=gen_random_uuid();c uuid:=gen_random_uuid();d uuid:=gen_random_uuid();i uuid:=gen_random_uuid();b uuid;b2 uuid;v bigint;stale bigint;pub bigint;draft bigint;checks int:=0;n int;denied boolean;bad text;row record;
BEGIN
 SELECT id INTO b FROM public.ff_branches WHERE active ORDER BY code LIMIT 1;
 SELECT id INTO b2 FROM public.ff_branches WHERE active AND id<>b ORDER BY code LIMIT 1;
 IF b IS NULL OR b2 IS NULL THEN RAISE EXCEPTION 'two real branches required';END IF;
 INSERT INTO auth.users(id) VALUES(m),(c),(d),(i);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA STEP06 manager','manager',true),(c,'QA STEP06 cashier A','cashier',true),(d,'QA STEP06 cashier B','cashier',true),(i,'QA STEP06 inactive','cashier',false)
 ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=excluded.active;
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(c,b),(d,b2);
 SELECT count(*) INTO n FROM public.ff_content_catalog;IF n<831 THEN RAISE EXCEPTION 'catalog count %',n;END IF;checks:=checks+1;
 IF EXISTS(SELECT 1 FROM public.ff_content_catalog WHERE NOT public.ff83_valid_content(key,'نص آمن للاختبار') OR NOT public.ff83_valid_content(key,NULL)) THEN RAISE EXCEPTION 'catalog validation mismatch';END IF;checks:=checks+1;
 FOR bad IN SELECT x FROM unnest(ARRAY['<script>alert(1)</script>','www.evil.example','https://evil.example','javascript:alert(1)','data:text/html','&#x3c;script&#x3e;','&lt;script&gt;','{password}','{phone}','نص'||chr(8203),'نص'||chr(8232),'نص'||chr(8238),'نص'||chr(65279),'نص'||chr(8291),'نص'||chr(173),repeat('أ',181)]) x LOOP
  IF public.ff83_valid_content('orders.cancel',bad) OR public.ff83_valid_content('login.title',bad) THEN RAISE EXCEPTION 'unsafe content accepted %',bad;END IF;checks:=checks+1;
 END LOOP;
 IF NOT public.ff83_valid_content('notices.order_summary','طلب {order_number} · {customer_name} · {driver_name} · {delivery_fee}')
 OR public.ff83_valid_content('notices.order_summary','طلب {password}') OR public.ff83_valid_content('reports.pdf_title','{customer_name} نص') OR public.ff83_valid_content('login.title','{customer_name} نص') THEN RAISE EXCEPTION 'template allowlist';END IF;checks:=checks+1;
 FOR row IN SELECT key FROM public.ff_content_catalog WHERE key LIKE '%.guidance' OR key IN ('system.security_guidance','orders.late_guidance','orders.transfer_guidance') LOOP
  IF NOT public.ff83_valid_content(row.key,E'**راجع**\n- [فتح النظام](https://delivery.freshfriesz.com/)')
  OR public.ff83_valid_content(row.key,'[فتح النظام](https://delivery.freshfriesz.com.evil/)') THEN RAISE EXCEPTION 'rich allowlist %',row.key;END IF;checks:=checks+1;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 IF (SELECT count(*) FROM public.ff_content_catalog_list())<>n THEN RAISE EXCEPTION 'manager registry incomplete';END IF;checks:=checks+1;
 v:=public.ff_content_create_draft('cashier.title','all',NULL,'عنوان عام اختباري');PERFORM public.ff_content_publish(v);
 v:=public.ff_content_create_draft('cashier.title','cashier',b,'عنوان الفرع الأول');PERFORM public.ff_content_publish(v);
 draft:=public.ff_content_create_draft('cashier.title','cashier',b2,'مسودة سرية غير منشورة');
 IF (SELECT count(*) FROM public.ff86_content_history_scoped('cashier.title','cashier',b,false))<>1 THEN RAISE EXCEPTION 'history branch filter';END IF;checks:=checks+1;
 pub:=public.ff_content_create_draft('login.title','all',NULL,'عنوان دخول عام اختباري');PERFORM public.ff_content_publish(pub);
 v:=public.ff_content_create_draft('login.title','all',NULL,'مسودة دخول غير منشورة');
 denied:=false;BEGIN PERFORM public.ff_content_create_draft('login.title','cashier',b,'نطاق غير عام');EXCEPTION WHEN check_violation THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'scoped public draft accepted';END IF;checks:=checks+1;
 IF (SELECT body FROM public.ff_step06_public_content('login') WHERE content_key='login.title') IS DISTINCT FROM 'عنوان دخول عام اختباري' THEN RAISE EXCEPTION 'public published mismatch';END IF;checks:=checks+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',c::text,true);SET LOCAL ROLE authenticated;
 IF (SELECT body FROM public.ff_content_effective(b) WHERE content_key='cashier.title') IS DISTINCT FROM 'عنوان الفرع الأول' THEN RAISE EXCEPTION 'own scope not applied';END IF;checks:=checks+1;
 IF (SELECT body FROM public.ff_content_effective(b2) WHERE content_key='cashier.title') IS DISTINCT FROM 'عنوان عام اختباري' THEN RAISE EXCEPTION 'other branch leakage';END IF;checks:=checks+1;
 IF EXISTS(SELECT FROM public.ff_content_catalog_list()) OR EXISTS(SELECT FROM public.ff_content_history('cashier.title')) THEN RAISE EXCEPTION 'nonmanager admin read';END IF;checks:=checks+1;
 denied:=false;BEGIN v:=public.ff_content_create_draft('cashier.title','cashier',b,'غير مصرح');denied:=v IS NULL;EXCEPTION WHEN OTHERS THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'nonmanager edit';END IF;checks:=checks+1;
 BEGIN PERFORM public.ff_content_publish(draft);EXCEPTION WHEN OTHERS THEN NULL;END;
 RESET ROLE;IF EXISTS(SELECT FROM public.ff_content_versions WHERE id=draft AND published_at IS NOT NULL) THEN RAISE EXCEPTION 'nonmanager publish';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',d::text,true);SET LOCAL ROLE authenticated;
 IF (SELECT body FROM public.ff_content_effective(b2) WHERE content_key='cashier.title') IS DISTINCT FROM 'عنوان عام اختباري' THEN RAISE EXCEPTION 'unpublished draft leaked';END IF;checks:=checks+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',i::text,true);SET LOCAL ROLE authenticated;
 IF EXISTS(SELECT FROM public.ff_content_effective(b)) THEN RAISE EXCEPTION 'inactive reads private content';END IF;checks:=checks+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub','',true);SET LOCAL ROLE anon;
 IF (SELECT body FROM public.ff_step06_public_content('login') WHERE content_key='login.title') IS DISTINCT FROM 'عنوان دخول عام اختباري'
 OR EXISTS(SELECT FROM public.ff_step06_public_content('cashier')) OR EXISTS(SELECT FROM public.ff_step06_public_content('customer_portal')) THEN RAISE EXCEPTION 'public scope leak';END IF;checks:=checks+1;
 RESET ROLE;
 IF has_table_privilege('anon','public.ff_content_versions','SELECT') OR has_table_privilege('authenticated','public.ff_content_versions','INSERT') OR has_function_privilege('anon','public.ff_content_create_draft(text,text,uuid,text)','EXECUTE') THEN RAISE EXCEPTION 'direct grants';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 v:=public.ff_content_create_draft('cashier.title','cashier',b,NULL);stale:=public.ff_content_create_draft('cashier.title','cashier',b,'قديم');PERFORM public.ff_content_publish(v);
 denied:=false;BEGIN PERFORM public.ff_content_publish(stale);EXCEPTION WHEN OTHERS THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'stale publish accepted';END IF;checks:=checks+1;
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',c::text,true);SET LOCAL ROLE authenticated;
 IF NOT EXISTS(SELECT FROM public.ff_content_effective(b) WHERE content_key='cashier.title' AND body IS NULL) THEN RAISE EXCEPTION 'original restoration not explicit';END IF;checks:=checks+1;
 RESET ROLE;
 PERFORM set_config('ff.qa.step06',jsonb_build_object('catalog',n,'assertions',checks,'public_scope',true,'stale_rejected',true,'restore',true)::text,true);
END $qa$;
SELECT current_setting('ff.qa.step06')::jsonb result;
ROLLBACK;
