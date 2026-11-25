BEGIN;
DO $$ BEGIN
 IF NOT ff_private.a07_valid_style('{"logoWidth":"30%","logoPosition":"menu","dialogRadius":"square","dialogPadding":"wide","ratingScale":"large"}'::jsonb) THEN RAISE EXCEPTION 'new safe tokens rejected'; END IF;
 IF ff_private.a07_valid_style('{"logoWidth":"1000%"}'::jsonb) OR ff_private.a07_valid_style('{"logoPosition":"javascript:alert(1)"}'::jsonb) OR ff_private.a07_valid_style('{"dialogRadius":"display:none"}'::jsonb) OR ff_private.a07_valid_style('{"ratingScale":"hidden"}'::jsonb) THEN RAISE EXCEPTION 'unsafe token accepted'; END IF;
END $$;
SELECT 'PASS STEP03 relative logo and protected modal tokens' AS result;
ROLLBACK;