# Monitoring and Alert Baseline (OPS-1)

Last updated: 2026-03-02 (KST)

## Data Sources

1. PostgreSQL query source:
   - `backend/scripts/ops/monitoring_queries.sql`
2. API/worker logs:
   - FastAPI application logs
   - Celery worker logs
3. Audit trail:
   - `audit_logs` table

## Required Metrics

1. `refresh_reuse_detected_15m`
2. `sync_ingested_rows_15m`
3. `ai_generation_jobs` status breakdown
4. `subscription_access_denied_15m`
5. log-derived:
   - report aggregation failure count
   - content publish failure count
   - R2 finalize failure count

## Required Alerts

1. Worker failure spike
   - Trigger: `Failed student report aggregation` >= 5 in 5 minutes
2. DB connection failure
   - Trigger: DB connection error logs >= 3 in 5 minutes
3. R2 signed URL / finalize failure spike
   - Trigger: `asset_object_not_found` or `asset_head_check_failed` >= 5 in 10 minutes
4. AI failed-rate threshold
   - Trigger: FAILED / (SUCCEEDED + FAILED) >= 0.2 for 10 minutes
5. AI dead-letter
   - Trigger: at least 1 `ai_job_dead_lettered` in 15 minutes

## Dashboard Panels (Minimum)

1. Auth panel:
   - refresh reuse detections (15m)
2. Sync panel:
   - ingested row count trend
3. AI panel:
   - queued/running/succeeded/failed counts
   - dead-letter event trend
4. Subscription panel:
   - access denied trend
5. Content/R2 panel:
   - finalize failure trend

## Verification Steps

1. Execute SQL query pack and confirm panel data updates.
2. Force one test alert event per alert rule in non-production.
3. Confirm alert delivery channel receives notification.
4. Confirm runbook links for each alert are attached.

## Evidence Format

Keep the following artifacts in your ops change record:

1. dashboard URL or exported definition
2. alert policy IDs
3. test alert timestamps and notification proof
4. on-call runbook link for each alert

