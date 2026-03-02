#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  backup_restore_drill.sh backup <dump-file-path>
  backup_restore_drill.sh restore <dump-file-path> <target-database-url>
  backup_restore_drill.sh verify <target-database-url>

Required env for backup:
  DATABASE_URL
USAGE
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

subcommand="$1"
shift

case "${subcommand}" in
  backup)
    if [[ $# -ne 1 ]]; then
      usage
      exit 1
    fi
    if ! command -v pg_dump >/dev/null 2>&1; then
      echo "pg_dump is required for backup." >&2
      exit 1
    fi
    : "${DATABASE_URL:?DATABASE_URL is required for backup}"
    dump_path="$1"
    dump_dir="$(dirname "${dump_path}")"
    mkdir -p "${dump_dir}"
    pg_dump "${DATABASE_URL}" -Fc -f "${dump_path}"
    echo "Backup created: ${dump_path}"
    ;;

  restore)
    if [[ $# -ne 2 ]]; then
      usage
      exit 1
    fi
    if ! command -v pg_restore >/dev/null 2>&1; then
      echo "pg_restore is required for restore." >&2
      exit 1
    fi
    dump_path="$1"
    target_database_url="$2"
    if [[ ! -f "${dump_path}" ]]; then
      echo "Dump file not found: ${dump_path}" >&2
      exit 1
    fi
    pg_restore --clean --if-exists -d "${target_database_url}" "${dump_path}"
    echo "Restore completed: ${target_database_url}"
    ;;

  verify)
    if [[ $# -ne 1 ]]; then
      usage
      exit 1
    fi
    if ! command -v psql >/dev/null 2>&1; then
      echo "psql is required for verification." >&2
      exit 1
    fi
    target_database_url="$1"
    psql "${target_database_url}" -v ON_ERROR_STOP=1 -c "select 1;"
    echo "Verification query completed."
    ;;

  *)
    usage
    exit 1
    ;;
esac

