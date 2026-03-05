#!/usr/bin/env bash
set -euo pipefail

STRICT=0
if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

required_cli=("curl" "docker")
optional_cli=("jq" "psql" "pg_dump" "pg_restore")

required_cloud_env=(
  "CLOUDFLARE_API_TOKEN"
  "CLOUDFLARE_ACCOUNT_ID"
  "R2_BUCKET"
)

required_runtime_env=(
  "DATABASE_URL"
  "REDIS_URL"
  "JWT_SECRET"
  "R2_ENDPOINT"
  "R2_ACCESS_KEY_ID"
  "R2_SECRET_ACCESS_KEY"
  "CONTENT_PIPELINE_API_KEY"
)

optional_env=(
  "AI_GENERATION_PROVIDER"
  "AI_GENERATION_API_KEY"
  "AI_MOCK_EXAM_MODEL"
  "AI_MOCK_EXAM_PROMPT_TEMPLATE_VERSION"
  "STRIPE_WEBHOOK_SECRET"
  "APP_STORE_SHARED_SECRET"
)

missing_required_cli=0
missing_required_env=0
missing_cloud_env=0

echo "== CLI availability =="
for cmd in "${required_cli[@]}"; do
  if command -v "${cmd}" >/dev/null 2>&1; then
    echo "[present] ${cmd}"
  else
    echo "[missing] ${cmd}"
    missing_required_cli=1
  fi
done

for cmd in "${optional_cli[@]}"; do
  if command -v "${cmd}" >/dev/null 2>&1; then
    echo "[present] ${cmd}"
  else
    echo "[optional-missing] ${cmd}"
  fi
done

echo
echo "== Runtime env key presence (value redacted) =="
for key in "${required_runtime_env[@]}"; do
  if [[ -n "${!key:-}" ]]; then
    echo "[present] ${key}"
  else
    echo "[missing] ${key}"
    missing_required_env=1
  fi
done

echo
echo "== Cloud env key presence (value redacted) =="
for key in "${required_cloud_env[@]}"; do
  if [[ -n "${!key:-}" ]]; then
    echo "[present] ${key}"
  else
    echo "[missing] ${key}"
    missing_cloud_env=1
  fi
done

echo
echo "== Optional env key presence (value redacted) =="
for key in "${optional_env[@]}"; do
  if [[ -n "${!key:-}" ]]; then
    echo "[present] ${key}"
  else
    echo "[optional-missing] ${key}"
  fi
done

echo
if (( missing_required_cli == 0 && missing_required_env == 0 && missing_cloud_env == 0 )); then
  echo "Environment check: READY"
else
  echo "Environment check: NOT READY"
fi

if (( STRICT == 1 )); then
  if (( missing_required_cli != 0 || missing_required_env != 0 || missing_cloud_env != 0 )); then
    exit 1
  fi
fi

