# Backend Ops Scripts

This directory contains operational scripts for production-readiness execution.

## 1) Environment and Auth Readiness

```bash
cd backend
./scripts/ops/check_environment.sh
./scripts/ops/check_environment.sh --strict
```

- Reports CLI availability
- Reports env key presence only (never prints secret values)
- `--strict` exits non-zero when required dependencies are missing

## 2) Cloudflare R2 Lifecycle Apply

Required env:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `R2_BUCKET`

Read current lifecycle config backup:

```bash
cd backend
./scripts/ops/r2_lifecycle_backup.sh
```

Apply lifecycle policy JSON:

```bash
cd backend
./scripts/ops/r2_lifecycle_apply.sh /absolute/path/to/lifecycle-policy.json
```

The apply script:

1. Backs up current lifecycle config
2. Applies new config
3. Backs up lifecycle config again for post-apply evidence

## 3) PostgreSQL Backup / Restore Drill

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

## 4) Monitoring Query Pack

Use:

```bash
cd backend
cat ./scripts/ops/monitoring_queries.sql
```

Apply the queries in your dashboard platform against PostgreSQL and combine with worker/API log-based alerts.

