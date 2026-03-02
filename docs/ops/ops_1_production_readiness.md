# OPS-1 Production Readiness Runbook

Last updated: 2026-03-02 (KST)

## Scope

This runbook operationalizes B1 backend readiness without changing backend feature logic.

Targets:

1. Cloudflare R2 lifecycle and retention
2. Secret injection and rotation procedure
3. Monitoring, alerts, and dashboard baseline
4. PostgreSQL backup and restore drill

## 1) Prerequisites and Identity Check

Run:

```bash
cd backend
./scripts/ops/check_environment.sh
```

Strict gate:

```bash
cd backend
./scripts/ops/check_environment.sh --strict
```

Required keys (name-only validation):

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `R2_BUCKET`
- `DATABASE_URL`
- `REDIS_URL`
- `JWT_SECRET`
- `R2_ENDPOINT`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `CONTENT_PIPELINE_API_KEY`

## 2) R2 Lifecycle Apply (Private Bucket Only)

### Policy split

- Prefix `content-assets/`: long retention
- Prefix `ai-artifacts/`: shorter retention

### Apply steps

1. Backup current lifecycle config:

```bash
cd backend
./scripts/ops/r2_lifecycle_backup.sh
```

2. Apply lifecycle JSON policy:

```bash
cd backend
./scripts/ops/r2_lifecycle_apply.sh /absolute/path/to/lifecycle-policy.json
```

3. Save apply response + post-apply backup as evidence in:

- `backend/scripts/ops/artifacts/`

### Rollback

Re-apply the previously backed-up lifecycle JSON file using the same apply script.

## 3) Secrets Injection and Rotation

### Required runtime secrets

- `DATABASE_URL`
- `REDIS_URL`
- `JWT_SECRET`
- `R2_ENDPOINT`
- `R2_BUCKET`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `CONTENT_PIPELINE_API_KEY`
- `AI_GENERATION_PROVIDER`
- `AI_GENERATION_API_KEY`
- `AI_MOCK_EXAM_MODEL`
- `AI_MOCK_EXAM_PROMPT_TEMPLATE_VERSION`
- `STRIPE_WEBHOOK_SECRET`
- `APP_STORE_SHARED_SECRET`

### Rotation sequence

1. Provision new secret in secret manager
2. Deploy with dual-read/dual-accept window when possible
3. Shift traffic to new secret
4. Revoke old secret
5. Record rotation in operations change log

Reference checklist:

- `docs/ops/secret_rotation_checklist.md`

### Verification

- App boot success
- Auth flow success
- R2 signed URL issuance success
- AI worker queue processing success
- Billing webhook/receipt verification endpoint health checks

### Rollback

Re-point runtime secret references to previous active version and restart affected workloads.

## 4) Monitoring and Alert Baseline

Query pack:

- `backend/scripts/ops/monitoring_queries.sql`
- `docs/ops/monitoring_alert_baseline.md`

### Minimum dashboard widgets

1. `refresh_reuse_detected_15m`
2. `sync_ingested_rows_15m`
3. `ai_generation_jobs` status breakdown (QUEUED/RUNNING/SUCCEEDED/FAILED)
4. `subscription_access_denied_15m`

### Minimum log-based alert patterns

1. `Failed student report aggregation`
2. Content publish failures (`POST /internal/content/units/{unit_id}/publish` with 4xx/5xx spikes)
3. Asset finalize failure codes:
   - `asset_object_not_found`
   - `asset_head_check_failed`
4. AI job failed-rate increase and dead-letter events (`ai_job_dead_lettered`)

### Suggested initial thresholds

- Worker failures: >= 5 errors in 5 minutes
- AI job failed ratio: FAILED / (SUCCEEDED + FAILED) >= 0.2 for 10 minutes
- DB connection errors: >= 3 in 5 minutes
- R2 finalize failures: >= 5 in 10 minutes

## 5) Backup and Restore Drill

Scripts:

- `backend/scripts/ops/backup_restore_drill.sh`

### Execute

Backup:

```bash
cd backend
DATABASE_URL='postgresql://...' ./scripts/ops/backup_restore_drill.sh backup ./scripts/ops/artifacts/resol_backend_$(date -u +%Y%m%dT%H%M%SZ).dump
```

Restore:

```bash
cd backend
./scripts/ops/backup_restore_drill.sh restore ./scripts/ops/artifacts/resol_backend_20260302T000000Z.dump 'postgresql://target-user:target-pass@target-host:5432/target_db'
```

Verify:

```bash
cd backend
./scripts/ops/backup_restore_drill.sh verify 'postgresql://target-user:target-pass@target-host:5432/target_db'
```

### Rollback

If drill restore fails, drop the drill DB and restore from the previous known-good dump.

## 6) Completion Gate

OPS-1 can be marked complete only when the following evidence is collected:

1. Strict environment check passes
2. R2 lifecycle apply response saved
3. Secret rotation checklist executed for at least one non-production environment
4. Monitoring dashboard + alert policies created and test alert fired
5. PostgreSQL backup and restore drill completed with verify query success

## 7) Security Rules During Ops

- Never print secret values in terminal logs
- Never commit `.env` files
- Never store signed URL full query strings in logs
- Keep artifact evidence files outside Git commits unless they are redacted and explicitly required
