#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "${BACKEND_DIR}"

export UV_CACHE_DIR="${UV_CACHE_DIR:-.uv-cache}"

usage() {
  cat <<'USAGE'
Usage: backend_ci.sh [sync|quality-strict|test|alembic|full] [changed-python-files...]

  sync     Install/update Python dependencies with uv.
  quality-strict
           Run strict lint/type checks only for changed backend Python files.
           Changed files are resolved in this order:
             1) positional file arguments
             2) CHANGED_PYTHON_FILES env (newline-separated)
             3) BASE_SHA + HEAD_SHA env via git diff
             4) default git diff (HEAD~1..HEAD)
  test     Run full backend test gates (compileall, pytest, app import smoke).
  alembic  Run alembic upgrade head (requires runtime env vars and PostgreSQL).
  full     Run sync + quality-strict + test + alembic.
USAGE
}

require_env_for_alembic() {
  local required_vars=(
    DATABASE_URL
    REDIS_URL
    JWT_SECRET
    R2_ENDPOINT
    R2_BUCKET
    R2_ACCESS_KEY_ID
    R2_SECRET_ACCESS_KEY
    CONTENT_PIPELINE_API_KEY
  )

  local missing=()
  local variable_name
  for variable_name in "${required_vars[@]}"; do
    if [[ -z "${!variable_name:-}" ]]; then
      missing+=("${variable_name}")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    printf 'Missing required environment variables for alembic: %s\n' "${missing[*]}" >&2
    exit 1
  fi
}

run_sync() {
  uv sync --extra dev
}

collect_changed_python_files() {
  if (($# > 0)); then
    printf '%s\n' "$@"
    return 0
  fi

  if [[ -n "${CHANGED_PYTHON_FILES:-}" ]]; then
    printf '%s\n' "${CHANGED_PYTHON_FILES}"
    return 0
  fi

  if [[ -n "${BASE_SHA:-}" && -n "${HEAD_SHA:-}" ]]; then
    python3 scripts/list_changed_python_files.py --base "${BASE_SHA}" --head "${HEAD_SHA}"
    return 0
  fi

  python3 scripts/list_changed_python_files.py
}

run_quality_strict() {
  changed_files=()
  while IFS= read -r line; do
    if [[ -n "${line}" ]]; then
      changed_files+=("${line}")
    fi
  done < <(collect_changed_python_files "$@" | sed '/^[[:space:]]*$/d' | sort -u)

  if ((${#changed_files[@]} == 0)); then
    echo "No changed backend Python files detected. Skipping strict lint/type gate."
    return 0
  fi

  echo "Strict lint targets (${#changed_files[@]} files):"
  printf ' - %s\n' "${changed_files[@]}"
  uv run ruff check "${changed_files[@]}"

  mypy_targets=()
  while IFS= read -r line; do
    if [[ -n "${line}" ]]; then
      mypy_targets+=("${line}")
    fi
  done < <(printf '%s\n' "${changed_files[@]}" | python3 scripts/list_mypy_targets.py)
  if ((${#mypy_targets[@]} == 0)); then
    echo "No mypy module targets derived from changed files. Skipping mypy strict gate."
    return 0
  fi

  echo "Strict mypy targets (${#mypy_targets[@]} modules):"
  printf ' - %s\n' "${mypy_targets[@]}"
  mypy_args=()
  for target in "${mypy_targets[@]}"; do
    mypy_args+=("-m" "${target}")
  done
  uv run mypy "${mypy_args[@]}"
}

run_test() {
  python3 -m compileall app tests alembic
  uv run pytest -q
  DATABASE_URL="${DATABASE_URL:-postgresql+psycopg://ci:ci@127.0.0.1:5432/resol_backend_ci}" \
  REDIS_URL="${REDIS_URL:-redis://127.0.0.1:6379/0}" \
  JWT_SECRET="${JWT_SECRET:-ci-jwt-secret-value-1234567890123456}" \
  R2_ENDPOINT="${R2_ENDPOINT:-https://example.r2.cloudflarestorage.com}" \
  R2_BUCKET="${R2_BUCKET:-resol-private-ci-bucket}" \
  R2_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID:-ci-r2-access-key-id}" \
  R2_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY:-ci-r2-secret-access-key}" \
  CONTENT_PIPELINE_API_KEY="${CONTENT_PIPELINE_API_KEY:-ci-content-internal-key-2026}" \
  uv run python -c "from app.main import app; assert app.title"
}

run_alembic() {
  require_env_for_alembic
  uv run alembic upgrade head
  assert_mock_exam_single_draft_index
}

assert_mock_exam_single_draft_index() {
  if ! command -v psql >/dev/null 2>&1; then
    echo "psql is not available; skipping PostgreSQL schema contract check."
    return 0
  fi

  local postgres_url="${DATABASE_URL/postgresql+psycopg/postgresql}"
  local index_count
  index_count="$(
    psql "${postgres_url}" -tAc \
      "SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'mock_exam_revisions' AND indexname = 'uq_mock_exam_revisions_single_draft_per_exam';"
  )"
  index_count="$(echo "${index_count}" | tr -d '[:space:]')"

  if [[ "${index_count}" != "1" ]]; then
    echo "Missing required index uq_mock_exam_revisions_single_draft_per_exam." >&2
    exit 1
  fi

  echo "Verified index uq_mock_exam_revisions_single_draft_per_exam."
}

command="${1:-full}"
shift || true
case "${command}" in
  sync)
    run_sync
    ;;
  quality-strict)
    run_quality_strict "$@"
    ;;
  test)
    run_test
    ;;
  alembic)
    run_alembic
    ;;
  full)
    run_sync
    run_quality_strict "$@"
    run_test
    run_alembic
    ;;
  *)
    usage
    exit 1
    ;;
esac
