#!/usr/bin/env bash
set -euo pipefail

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required." >&2
  exit 1
fi

: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}"
: "${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID is required}"
: "${R2_BUCKET:?R2_BUCKET is required}"

output_dir="${1:-backend/scripts/ops/artifacts}"
mkdir -p "${output_dir}"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
output_file="${output_dir}/r2_lifecycle_${R2_BUCKET}_${timestamp}.json"
endpoint="https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/r2/buckets/${R2_BUCKET}/lifecycle"

curl -sS \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  "${endpoint}" > "${output_file}"

if command -v jq >/dev/null 2>&1; then
  success="$(jq -r '.success // empty' "${output_file}")"
  if [[ "${success}" != "true" ]]; then
    echo "Cloudflare lifecycle read failed. Saved response: ${output_file}" >&2
    jq -r '.errors // empty' "${output_file}" >&2 || true
    exit 1
  fi
fi

echo "Saved lifecycle response to ${output_file}"

