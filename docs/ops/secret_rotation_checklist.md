# Secret Rotation Checklist (OPS-1)

Last updated: 2026-03-02 (KST)

## Scope

Secrets covered by this checklist:

- `JWT_SECRET`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `CONTENT_PIPELINE_API_KEY`
- `AI_GENERATION_API_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `APP_STORE_SHARED_SECRET`

## Rotation Procedure

1. Create new secret version in the secret manager.
2. Update staging with new version.
3. Run staging smoke checks:
   - auth login/refresh
   - R2 upload/download signed URL
   - AI worker job execution
   - billing webhook signature verification
4. If staging checks pass, deploy to production.
5. Verify production health and error rates.
6. Revoke old secret version.
7. Record rotation event in change log.

## Rollback Procedure

1. Re-point runtime to previous working secret version.
2. Restart affected workloads.
3. Confirm health endpoint and critical API paths recover.
4. Create incident note with root cause and corrective action.

## Evidence Requirements

For each rotation event, record:

1. rotated secret name
2. rotation timestamp (UTC)
3. staging verification results
4. production verification results
5. old secret revoke timestamp
6. operator identity

