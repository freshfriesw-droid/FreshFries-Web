-- STEP14: executed field readiness query. Read-only, aggregate evidence; no PII.
BEGIN READ ONLY;
WITH b AS (SELECT * FROM public.ff_branches WHERE active),
h AS (SELECT DISTINCT ON(branch_id,day_of_week) branch_id,day_of_week FROM ff_private.a05_branch_hours WHERE effective_at<=now() ORDER BY branch_id,day_of_week,effective_at DESC,recorded_at DESC,id DESC),
t AS (SELECT DISTINCT ON(branch_id,area_key) branch_id,area_key,fee FROM ff_private.a05_area_tariffs WHERE effective_at<=now() ORDER BY branch_id,area_key,effective_at DESC,recorded_at DESC,id DESC),
branch_counts AS (
 SELECT b.code,
 (SELECT count(*) FROM public.ff_user_branches ub JOIN public.ff_profiles p ON p.user_id=ub.user_id AND p.active AND p.role='cashier' JOIN auth.users u ON u.id=p.user_id WHERE ub.branch_id=b.id) cashiers,
 (SELECT count(*) FROM public.ff_v9_assembly_access a JOIN public.ff_profiles p ON p.user_id=a.user_id AND p.active AND p.role='assembly' JOIN auth.users u ON u.id=p.user_id WHERE a.enabled AND a.branch_id=b.id) assembly_accounts,
 (SELECT count(*) FROM public.ff_user_branches ub JOIN public.ff_profiles p ON p.user_id=ub.user_id AND p.active AND p.role='burger_kitchen' JOIN auth.users u ON u.id=p.user_id WHERE ub.branch_id=b.id) burger_accounts,
 (SELECT count(*) FROM public.ff_drivers d WHERE d.branch_id=b.id AND d.active) active_drivers,
 (SELECT count(DISTINCT l.user_id) FROM public.ff38_driver_links l JOIN public.ff_drivers d ON d.id=l.driver_id AND d.active JOIN public.ff_profiles p ON p.user_id=l.user_id AND p.active AND p.role='driver' JOIN auth.users u ON u.id=p.user_id WHERE d.branch_id=b.id) linked_driver_accounts,
 (SELECT count(*) FROM public.ff_staff s WHERE s.branch_id=b.id AND s.active) staff_records,
 (SELECT count(*) FROM h WHERE h.branch_id=b.id) configured_days,
 (SELECT count(*) FROM t WHERE t.branch_id=b.id) tariff_count,
 (SELECT jsonb_agg(cap.capacity) FROM public.ff62_pinned_drivers pd LEFT JOIN ff_private.special_courier_capacity cap ON cap.driver_id=pd.driver_id WHERE pd.branch_id=b.id) pinned_capacities
 FROM b),
role_counts AS (SELECT p.role,count(*) active_accounts,(SELECT count(DISTINCT d.user_id) FROM public.ff_push_devices d JOIN public.ff_profiles pr ON pr.user_id=d.user_id AND pr.active AND pr.role=p.role WHERE d.enabled) enabled_push_accounts FROM public.ff_profiles p JOIN auth.users u ON u.id=p.user_id WHERE p.active GROUP BY p.role)
SELECT jsonb_build_object(
 'branches',(SELECT jsonb_agg(to_jsonb(bc) ORDER BY code) FROM branch_counts bc),
 'roles',(SELECT jsonb_agg(to_jsonb(rc) ORDER BY role) FROM role_counts rc),
 'offer_policy',(SELECT jsonb_agg(jsonb_build_object('fast_seconds',fast_seconds,'slow_seconds',slow_seconds)) FROM public.ff60_offer_policy),
 'active_menu_items',(SELECT count(*) FROM public.ff_menu_items WHERE active),
 'offers',(SELECT count(*) FROM public.ff_offers),
 'active_priority_routes',(SELECT count(*) FROM public.ff52_priority_routes WHERE active),
 'enabled_push_devices',(SELECT count(*) FROM public.ff_push_devices WHERE enabled),
 'ready_drivers',(SELECT count(*) FROM public.ff38_driver_presence WHERE state='ready'),
 'orders',(SELECT count(*) FROM public.ff_orders),
 'order_items',(SELECT count(*) FROM public.ff_order_items),
 'field_run_records',(SELECT count(*) FROM public.ff47_test_runs),
 'active_qa_catalog_tests',(SELECT count(*) FROM public.ff47_test_catalog WHERE active),
 'rls_tables',(SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('public','ff_private','storage') AND c.relkind IN ('r','p') AND c.relrowsecurity),
 'total_tables',(SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('public','ff_private','storage') AND c.relkind IN ('r','p'))
) AS readiness;
COMMIT;
