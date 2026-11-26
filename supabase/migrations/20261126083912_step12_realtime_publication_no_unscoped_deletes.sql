SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';
-- DELETE events cannot use per-row RLS after removal; the app uses INSERT/UPDATE hints and existing refresh fallbacks.
ALTER PUBLICATION supabase_realtime SET (publish = 'insert, update');
