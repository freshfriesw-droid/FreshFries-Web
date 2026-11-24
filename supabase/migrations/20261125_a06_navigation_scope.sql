-- A06 DEC-05/07: central navigation defaults, scope checked independently of presentation.
CREATE TABLE ff_private.a06_nav_versions(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 role_scope text NOT NULL CHECK(role_scope IN ('all','manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen')),
 branch_id uuid REFERENCES public.ff_branches(id),
 device text NOT NULL CHECK(device IN ('all','mobile','desktop')),
 mode text NOT NULL CHECK(mode IN ('accordion','flat')),
 drawer_width integer NOT NULL CHECK(drawer_width BETWEEN 260 AND 300),
 bar text CHECK(bar IN ('labels','icons','wide','floating','compact')),
 actor_id uuid NOT NULL REFERENCES public.ff_profiles(user_id),
 reason text NOT NULL CHECK(length(reason) BETWEEN 5 AND 500),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE ff_private.a06_nav_versions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ff_private.a06_nav_versions FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.ff_a06_nav_scope(p_branch uuid,p_device text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $body$
DECLARE r text;b uuid;row_ ff_private.a06_nav_versions;
BEGIN
 SELECT role INTO r FROM public.ff_profiles WHERE user_id=auth.uid() AND active;
 IF r IS NULL OR p_device IS NULL OR p_device NOT IN ('mobile','desktop') THEN RAISE EXCEPTION 'حساب فعال وجهاز صالح مطلوبان' USING ERRCODE='42501';END IF;
 IF r='driver' THEN SELECT d.branch_id INTO b FROM public.ff38_driver_links l JOIN public.ff_drivers d ON d.id=l.driver_id AND d.active WHERE l.user_id=auth.uid();
 ELSIF r='assembly' THEN b:=(public.ff_v12_assembly_me()->'branch'->>'id')::uuid;
 ELSIF r IN ('cashier','burger_kitchen') THEN
 SELECT ub.branch_id INTO b FROM public.ff_user_branches ub JOIN public.ff_branches br ON br.id=ub.branch_id AND br.active WHERE ub.user_id=auth.uid() AND (p_branch IS NULL OR ub.branch_id=p_branch) ORDER BY ub.branch_id LIMIT 1;
 END IF;
 IF r IN ('driver','assembly','cashier','burger_kitchen') THEN
 IF b IS NULL OR (p_branch IS NOT NULL AND p_branch<>b) THEN RAISE EXCEPTION 'الفرع غير مصرح به' USING ERRCODE='42501';END IF;
 ELSE
 b:=p_branch;
 IF b IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.ff_branches br WHERE br.id=b AND br.active) THEN RAISE EXCEPTION 'الفرع غير صالح' USING ERRCODE='42501';END IF;
 IF r='supervisor' AND b IS NOT NULL AND EXISTS(SELECT 1 FROM public.ff_user_branches WHERE user_id=auth.uid()) AND NOT public.ff_has_branch(b) THEN RAISE EXCEPTION 'الفرع غير مصرح به' USING ERRCODE='42501';END IF;
 END IF;
 SELECT * INTO row_ FROM ff_private.a06_nav_versions v WHERE v.role_scope IN ('all',r) AND (v.branch_id IS NULL OR v.branch_id=b) AND v.device IN ('all',p_device)
 ORDER BY ((v.role_scope<>'all')::int+(v.branch_id IS NOT NULL)::int+(v.device<>'all')::int) DESC,(v.role_scope<>'all') DESC,(v.branch_id IS NOT NULL) DESC,(v.device<>'all') DESC,v.id DESC LIMIT 1;
 RETURN jsonb_build_object('role',r,'branch',b,'revision',row_.id,'mode',coalesce(row_.mode,'accordion'),'drawer_width',coalesce(row_.drawer_width,280),'bar',row_.bar);
END $body$;
CREATE FUNCTION public.ff_a06_nav_save(p_role text,p_branch uuid,p_device text,p_mode text,p_width integer,p_bar text,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $body$
DECLARE v_id bigint;
BEGIN
 IF NOT public.ff_is_manager() THEN RAISE EXCEPTION 'للمدير العام فقط' USING ERRCODE='42501';END IF;
 IF p_role IS NULL OR p_role NOT IN ('all','manager','supervisor','customer_service','cashier','driver','assembly','burger_kitchen') OR p_device IS NULL OR p_device NOT IN ('all','mobile','desktop') OR p_mode IS NULL OR p_mode NOT IN ('accordion','flat') OR p_width IS NULL OR p_width NOT BETWEEN 260 AND 300 OR (p_bar IS NOT NULL AND p_bar NOT IN ('labels','icons','wide','floating','compact')) OR length(btrim(coalesce(p_reason,''))) NOT BETWEEN 5 AND 500 OR (p_branch IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.ff_branches WHERE id=p_branch AND active)) THEN RAISE EXCEPTION 'إعداد التنقل غير صالح' USING ERRCODE='22023';END IF;
 INSERT INTO ff_private.a06_nav_versions(role_scope,branch_id,device,mode,drawer_width,bar,actor_id,reason) VALUES(p_role,p_branch,p_device,p_mode,p_width,p_bar,auth.uid(),btrim(p_reason)) RETURNING id INTO v_id;
 INSERT INTO public.ff_audit_log(actor_id,action,entity_type,entity_id,branch_id,details) VALUES(auth.uid(),'a06_nav_defaults','ui_navigation',v_id::text,p_branch,jsonb_build_object('role',p_role,'device',p_device,'mode',p_mode,'width',p_width,'bar',p_bar,'reason',p_reason));
 RETURN jsonb_build_object('saved',true,'revision',v_id);
END $body$;
REVOKE EXECUTE ON FUNCTION public.ff_a06_nav_scope(uuid,text),public.ff_a06_nav_save(text,uuid,text,text,integer,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.ff_a06_nav_scope(uuid,text),public.ff_a06_nav_save(text,uuid,text,text,integer,text,text) TO authenticated;
