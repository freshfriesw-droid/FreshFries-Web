CREATE OR REPLACE FUNCTION ff_private.a11_message_audience(p_role text,p_branch uuid,p_people uuid[]) RETURNS TABLE(user_id uuid,display_name text,role text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT p.user_id,p.display_name,p.role FROM public.ff_profiles p
 WHERE p.active AND p.user_id<>auth.uid() AND (p_role='all' OR p.role=p_role)
 AND (p_people IS NULL OR p.user_id=ANY(p_people))
 AND (p.role<>'assembly' OR EXISTS(SELECT FROM public.ff_v9_assembly_access a JOIN public.ff_branches b ON b.id=a.branch_id AND b.active WHERE a.user_id=p.user_id AND a.enabled AND (p_branch IS NULL OR a.branch_id=p_branch)))
 AND (p.role<>'driver' OR EXISTS(SELECT FROM public.ff38_driver_links l JOIN public.ff_drivers d ON d.id=l.driver_id JOIN public.ff_branches b ON b.id=d.branch_id AND b.active WHERE l.user_id=p.user_id AND d.active AND (p_branch IS NULL OR d.branch_id=p_branch)))
 AND (p_branch IS NULL OR p.role IN ('assembly','driver','manager','customer_service') OR EXISTS(SELECT FROM public.ff_user_branches u WHERE u.user_id=p.user_id AND u.branch_id=p_branch))
 ORDER BY p.user_id LIMIT 501
$$;
CREATE OR REPLACE FUNCTION public.ff_a11_message_access() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('manager',public.ff_is_manager(),'can_send',EXISTS(SELECT FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active) AND (public.ff_is_manager() OR EXISTS(SELECT FROM public.ff_a11_message_grants g WHERE g.user_id=auth.uid() AND g.revoked_at IS NULL AND g.expires_at>now())),
 'branches',coalesce((SELECT jsonb_agg(jsonb_build_object('id',b.id,'name',b.name) ORDER BY b.name) FROM public.ff_branches b WHERE b.active AND EXISTS(SELECT FROM public.ff_profiles p WHERE p.user_id=auth.uid() AND p.active) AND (public.ff_is_manager() OR EXISTS(SELECT FROM public.ff_a11_message_grants g WHERE g.user_id=auth.uid() AND g.revoked_at IS NULL AND g.expires_at>now() AND (g.branch_id IS NULL OR g.branch_id=b.id)))),'[]'::jsonb), 'grants',coalesce((SELECT jsonb_agg(jsonb_build_object('role',g.target_role,'branch',g.branch_id,'priority',g.max_priority,'expires_at',g.expires_at)) FROM public.ff_a11_message_grants g WHERE g.user_id=auth.uid() AND g.revoked_at IS NULL AND g.expires_at>now()),'[]'::jsonb))
$$;
