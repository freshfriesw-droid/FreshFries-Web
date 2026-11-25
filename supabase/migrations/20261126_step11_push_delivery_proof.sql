-- STEP11: explicit gateway acceptance evidence, never infer device delivery.
ALTER TABLE public.ff_push_jobs ADD COLUMN IF NOT EXISTS provider_accepted_at timestamptz;
CREATE OR REPLACE FUNCTION public.ff_push_finish_job(p_job bigint,p_success boolean,p_error text DEFAULT NULL) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_count int; v_accepted boolean:=p_success IS TRUE AND p_error='PROVIDER_ACCEPTED';
BEGIN
 UPDATE public.ff_push_jobs j SET
 status=CASE WHEN p_success IS TRUE THEN 'sent' WHEN p_error IN ('NO_ENABLED_DEVICE','INACTIVE_RECIPIENT','MESSAGE_CANCELLED') OR attempts>=5 THEN 'failed' ELSE 'retry' END,
 sent_at=CASE WHEN p_success IS TRUE THEN now() ELSE NULL END,
 provider_accepted_at=CASE WHEN v_accepted THEN clock_timestamp() ELSE NULL END,
 last_error=CASE WHEN p_success IS TRUE THEN NULL ELSE left(coalesce(p_error,'PUSH_NOT_DELIVERED'),220) END,
 next_attempt_at=CASE WHEN p_success IS TRUE OR p_error IN ('NO_ENABLED_DEVICE','INACTIVE_RECIPIENT','MESSAGE_CANCELLED') THEN now() ELSE now()+make_interval(mins=>least(30,2*greatest(attempts,1))) END,
 updated_at=now()
 WHERE id=p_job AND status='sending';
 GET DIAGNOSTICS v_count=ROW_COUNT; RETURN v_count=1;
END $$;
REVOKE ALL ON FUNCTION public.ff_push_finish_job(bigint,boolean,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ff_push_finish_job(bigint,boolean,text) TO service_role;
DO $migration$
DECLARE d text; a text; z text;
BEGIN
 d:=pg_get_functiondef('public.ff_a11_message_history(integer)'::regprocedure);
 a:=$s$(SELECT count(DISTINCT j.user_id) FROM public.ff_push_jobs j WHERE j.event_key='message:'||m.id AND j.status='sent') AS push_accepted_count$s$;
 z:=$s$(SELECT count(DISTINCT j.user_id) FROM public.ff_push_jobs j WHERE j.event_key='message:'||m.id AND j.provider_accepted_at IS NOT NULL) AS push_accepted_count,
 (SELECT count(DISTINCT j.user_id) FROM public.ff_push_jobs j WHERE j.event_key='message:'||m.id AND j.status='sent' AND j.provider_accepted_at IS NULL) AS push_unverified_count,
 (SELECT count(DISTINCT j.user_id) FROM public.ff_push_jobs j WHERE j.event_key='message:'||m.id AND j.status='failed' AND j.last_error IN ('NO_ENABLED_DEVICE','INACTIVE_RECIPIENT')) AS push_unavailable_count$s$;
 IF (length(d)-length(replace(d,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'Unexpected message history anchor';END IF;
 EXECUTE replace(d,a,z);
END $migration$;
