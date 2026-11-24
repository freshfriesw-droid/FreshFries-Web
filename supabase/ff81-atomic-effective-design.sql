-- Read the design and its card layout in the same database snapshot.
create function public.ff81_effective_design(p_branch uuid,p_device text)
returns jsonb language sql stable security definer set search_path='' as $$
 select to_jsonb(e)||jsonb_build_object('card_layout',v.card_layout)
 from public.ff_ui_effective(p_branch,p_device) e join public.ff_ui_versions v on v.id=e.id
 where auth.uid() is not null
$$;
revoke all on function public.ff81_effective_design(uuid,text) from public,anon;
grant execute on function public.ff81_effective_design(uuid,text) to authenticated;
