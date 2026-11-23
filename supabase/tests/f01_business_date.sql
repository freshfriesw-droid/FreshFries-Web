-- F-01 acceptance checks on isolated staging only. No inserts/deletes in existing tables.
-- Run AFTER both migration files. All checks raise an error on failure.
BEGIN;
SET LOCAL TIME ZONE 'UTC';
DO $test$
DECLARE r record; actual date; actual_flag boolean;
BEGIN
  FOR r IN SELECT * FROM (VALUES
   ('2026-11-23 08:30:00+03'::timestamptz,date '2026-11-23',false),
   ('2026-11-23 14:00:00+03'::timestamptz,date '2026-11-23',false),
   ('2026-11-23 23:59:59+03'::timestamptz,date '2026-11-23',false),
   ('2026-11-24 00:30:00+03'::timestamptz,date '2026-11-23',false),
   ('2026-11-24 01:59:59+03'::timestamptz,date '2026-11-23',false),
   ('2026-11-24 02:00:00+03'::timestamptz,date '2026-11-23',true),
   ('2026-11-24 07:59:59+03'::timestamptz,date '2026-11-23',true),
   ('2026-11-24 08:00:00+03'::timestamptz,date '2026-11-24',false)
  ) AS x(stamp, expected_date, expected_closed)
  LOOP
    actual:=public.ff_business_date(r.stamp);
    actual_flag := (extract(hour from r.stamp at time zone 'Asia/Aden')>=2
                    and extract(hour from r.stamp at time zone 'Asia/Aden')<8);
    IF actual IS DISTINCT FROM r.expected_date
       OR actual_flag IS DISTINCT FROM r.expected_closed THEN
       RAISE EXCEPTION 'F01 boundary failure at %, date %, flag %',r.stamp,actual,actual_flag;
    END IF;
  END LOOP;
  IF public.ff_business_date('2026-11-24 09:00:00+03'::timestamptz)
       <> date '2026-11-24'
  THEN RAISE EXCEPTION 'F01 today rollover incorrect'; END IF;
  IF EXISTS(SELECT 1 FROM public.ff_orders o
    WHERE o.business_date IS DISTINCT FROM public.ff_business_date(o.created_at))
  THEN RAISE EXCEPTION 'F01 historic backfill mismatch'; END IF;
  IF EXISTS(SELECT 1 FROM public.ff_orders o
    WHERE o.closed_hours_flag IS DISTINCT FROM (
      extract(hour from o.created_at at time zone 'Asia/Aden')>=2
      and extract(hour from o.created_at at time zone 'Asia/Aden')<8))
  THEN RAISE EXCEPTION 'F01 anomaly flags mismatch'; END IF;
  IF EXISTS(SELECT 1 FROM public.ff_orders WHERE business_date IS NULL OR closed_hours_flag IS NULL)
  THEN RAISE EXCEPTION 'F01 required fields missing'; END IF;
  RAISE NOTICE 'F01 boundary and backfill checks passed.';
END $test$;
ROLLBACK;
