#!/usr/bin/env bash
set -euo pipefail

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required." >&2
  exit 1
fi

: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}"
: "${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID is required}"
: "${R2_BUCKET:?R2_BUCKET is required}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <lifecycle-policy-json-path> [artifact-output-dir]" >&2
  exit 1
fi

policy_path="$1"
artifact_dir="${2:-backend/scripts/ops/artifacts}"

if [[ ! -f "${policy_path}" ]]; then
  echo "Policy file not found: ${policy_path}" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "${artifact_dir}"

echo "Backing up current lifecycle configuration..."
"${script_dir}/r2_lifecycle_backup.sh" "${artifact_dir}" >/dev/null

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
response_file="${artifact_dir}/r2_lifecycle_apply_response_${R2_BUCKET}_${timestamp}.json"
endpoint="https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/r2/buckets/${R2_BUCKET}/lifecycle"

echo "Applying lifecycle policy from ${policy_path}..."
curl -sS \
  -X PUT \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data-binary "@${policy_path}" \
  "${endpoint}" > "${response_file}"

if command -v jq >/dev/null 2>&1; then
  success="$(jq -r '.success // empty' "${response_file}")"
  if [[ "${success}" != "true" ]]; then
    echo "Lifecycle apply failed. Saved response: ${response_file}" >&2
    jq -r '.errors // empty' "${response_file}" >&2 || true
    exit 1
  fi
fi

echo "Lifecycle apply response saved to ${response_file}"
echo "Verifying lifecycle configuration after apply..."
"${script_dir}/r2_lifecycle_backup.sh" "${artifact_dir}" >/dev/null
echo "Lifecycle policy apply completed."

