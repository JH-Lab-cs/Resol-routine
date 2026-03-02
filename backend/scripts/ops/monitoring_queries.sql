-- Operational SQL query pack (PostgreSQL)
-- Use these queries to back dashboards/alerts in staging and production.

-- 1) Refresh token reuse detection count (last 15 minutes)
select count(*) as refresh_reuse_detected_15m
from audit_logs
where action = 'refresh_reuse_detected'
  and created_at >= now() - interval '15 minutes';

-- 2) Study event accepted count proxy (ingested rows, last 15 minutes)
select count(*) as sync_ingested_rows_15m
from study_events
where received_at_server >= now() - interval '15 minutes';

-- 3) Report aggregation failure count (last 15 minutes)
-- This metric is log-derived in the worker process.
-- Search pattern: "Failed student report aggregation"

-- 4) Content publish failure count (last 15 minutes)
-- This metric is log-derived in internal API/service logs.
-- Search for 4xx/5xx with endpoint:
--   POST /internal/content/units/{unit_id}/publish

-- 5) AI generation job status counts (last 15 minutes)
select status, count(*) as job_count
from ai_generation_jobs
where created_at >= now() - interval '15 minutes'
group by status
order by status;

-- 6) Subscription access denied count (last 15 minutes)
select count(*) as subscription_access_denied_15m
from audit_logs
where action = 'subscription_access_denied'
  and created_at >= now() - interval '15 minutes';

-- 7) R2 finalize failures (last 15 minutes)
-- This metric is log-derived in content asset finalize errors.
-- Search for detail code:
--   asset_object_not_found
--   asset_head_check_failed

