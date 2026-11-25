-- STEP12: audit records are written only by server RPCs or trusted service-role code.
revoke insert, update, delete, truncate on public.ff_audit_log from public, anon, authenticated;
