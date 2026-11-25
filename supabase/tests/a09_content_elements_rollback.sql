DO $qa$
DECLARE m uuid:=gen_random_uuid();u uuid:=gen_random_uuid();b uuid:=gen_random_uuid();b2 uuid:=gen_random_uuid();rev bigint;gid bigint; res jsonb; checks int:=0;
 normal jsonb:='{"driver_actions":[{"key":"ff51BreakBtn","shape":"pack","size":"normal"},{"key":"clockInBtn","shape":"pack","size":"normal"},{"key":"clockOutBtn","shape":"pack","size":"normal"}]}';
 reversed jsonb:='{"driver_actions":[{"key":"clockOutBtn","shape":"pack","size":"normal"},{"key":"clockInBtn","shape":"pack","size":"normal"},{"key":"ff51BreakBtn","shape":"pack","size":"normal"}]}';
BEGIN
 BEGIN
 INSERT INTO auth.users(id) VALUES(m),(u);
 INSERT INTO public.ff_profiles(user_id,display_name,role,active) VALUES(m,'QA manager','manager',true),(u,'QA central CS','customer_service',true) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,active=true;
 INSERT INTO public.ff_branches(id,code,name) VALUES(b,'qa-'||b,'QA one'),(b2,'qa-'||b2,'QA two');
 INSERT INTO public.ff_user_branches(user_id,branch_id) VALUES(u,b);
 IF NOT public.ff83_valid_content('notices.order_summary','طلب {order_number} عميل {customer_name} موصل {driver_name} رسوم {delivery_fee}') THEN RAISE EXCEPTION 'Valid placeholders rejected';END IF;checks:=checks+1;
 IF public.ff83_valid_content('notices.order_summary','طلب {password}') OR public.ff83_valid_content('reports.pdf_title','عنوان {customer_name}') OR public.ff83_valid_content('orders.cancel','<script>alert(1)</script>') OR public.ff83_valid_content('orders.cancel','تجربة'||chr(8238)) THEN RAISE EXCEPTION 'Unsafe text accepted';END IF;checks:=checks+1;
 IF NOT public.ff83_valid_content('orders.guidance',E'**راجع**\n- [فتح النظام](https://delivery.freshfriesz.com/)') OR public.ff83_valid_content('orders.guidance','[فتح النظام](https://delivery.freshfriesz.com.evil/)') OR public.ff83_valid_content('orders.guidance','[فتح النظام](https://delivery.freshfriesz.com/) https://evil.example') THEN RAISE EXCEPTION 'Link allowlist';END IF;checks:=checks+1;
 IF ff_private.a09_merge_elements('driver',normal,NULL,reversed,ARRAY['buttons']) IS NOT NULL THEN RAISE EXCEPTION 'Buttons grant reordered group';END IF;checks:=checks+1;
 IF ff_private.a09_merge_elements('driver',normal,NULL,reversed,ARRAY['layout']) IS DISTINCT FROM reversed THEN RAISE EXCEPTION 'Layout cannot reorder';END IF;checks:=checks+1;
 IF ff_private.a09_merge_elements('driver',normal,NULL,jsonb_set(normal,'{driver_actions,0,shape}','"pill"'),ARRAY['layout']) IS NOT NULL THEN RAISE EXCEPTION 'Layout grant restyled button';END IF;checks:=checks+1;
 IF ff_private.a09_merge_elements('driver',normal,NULL,normal #- '{driver_actions,0}',ARRAY['buttons','layout']) IS NOT NULL THEN RAISE EXCEPTION 'Mandatory button removed';END IF;checks:=checks+1;
 PERFORM set_config('request.jwt.claim.sub',m::text,true);SET LOCAL ROLE authenticated;
 rev:=public.ff_content_create_draft('nav.orders','customer_service',b2,'QA central label');PERFORM public.ff_content_publish(rev);
 gid:=public.ff_a09_set_grant(u,b,'driver',ARRAY['view','edit','preview','review'],now()-interval '1 minute',now()+interval '1 hour',ARRAY['layout']);
 RESET ROLE;PERFORM set_config('request.jwt.claim.sub',u::text,true);SET LOCAL ROLE authenticated;
 IF (SELECT body FROM public.ff_content_effective(b2) WHERE content_key='nav.orders') IS DISTINCT FROM 'QA central label' THEN RAISE EXCEPTION 'Central content scope';END IF;checks:=checks+1;
 res:=public.ff_a09_design_draft('mobile',jsonb_build_object('elements',reversed),'QA order',NULL);
 IF res->>'ok'<>'true' THEN RAISE EXCEPTION 'Element draft %',res;END IF;checks:=checks+1;
 res:=public.ff_a09_design_draft('mobile',jsonb_build_object('elements',jsonb_set(normal,'{driver_actions,0,shape}','"pill"')),'QA invalid shape',NULL);
 IF res->>'ok'<>'false' THEN RAISE EXCEPTION 'Unauthorized shape';END IF;checks:=checks+1;
 IF public.ff_a09_design_context('mobile')->>'screen'<>'driver' THEN RAISE EXCEPTION 'Missing safe context';END IF;checks:=checks+1;
 RESET ROLE;UPDATE public.ff82_content_grants SET ends_at=clock_timestamp()+interval '100 milliseconds' WHERE id=gid;PERFORM pg_sleep(0.15);
 SET LOCAL ROLE authenticated;
 IF public.ff_a09_design_context('mobile') IS NOT NULL OR EXISTS(SELECT FROM public.ff_a09_design_history('mobile')) OR (public.ff_a09_design_draft('mobile','{"layout":"single"}','QA expired',NULL)->>'ok')<>'false' THEN RAISE EXCEPTION 'Expired access';END IF;checks:=checks+1;
 RESET ROLE;
 IF NOT EXISTS(SELECT FROM public.ff82_content_audit WHERE actor_id=u AND action='design_draft' AND outcome='denied' AND reason='outside_edit_scope') THEN RAISE EXCEPTION 'Expired denial audit';END IF;checks:=checks+1;
 RAISE EXCEPTION 'QA rollback' USING ERRCODE='ZQ029';
 EXCEPTION WHEN SQLSTATE 'ZQ029' THEN NULL;END;
 IF checks<>13 OR EXISTS(SELECT FROM public.ff_branches WHERE id IN(b,b2)) THEN RAISE EXCEPTION 'Incomplete rollback %',checks;END IF;
END $qa$;
SELECT 'PASS A09: 13 content validation, branch, granular element, expiry and rollback assertions' result;