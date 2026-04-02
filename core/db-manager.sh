#!/usr/bin/env bash
# Noden | DevX Suite
# core/db-manager.sh — Odoo DB Backup & Restore via Web API
set -euo pipefail

CMD="${1:-}"
URL="${2:-}"
MASTER_PWD="${3:-}"
NAME="${4:-}"

show_help() {
    cat <<EOF
db.sh — Backup & restore Odoo databases via /web/database API.

USAGE
  db.sh backup  URL MASTER_PWD DB_NAME [FORMAT] [LOCATION]
  db.sh restore URL MASTER_PWD DB_NAME FILE    [COPY]

COMMANDS
  backup    Download a full database backup.
  restore   Upload and restore a backup file.

BACKUP ARGUMENTS
  URL         Odoo server URL (e.g. http://localhost:8069)
  MASTER_PWD  Odoo master password
  DB_NAME     Database name to back up
  FORMAT      zip (default) or dump
  LOCATION    Directory to save the backup (default: .)

RESTORE ARGUMENTS
  URL         Odoo server URL
  MASTER_PWD  Odoo master password
  DB_NAME     New database name for the restore
  FILE        Path to the backup file (.zip or .dump)
  COPY        true (default) to neutralize the restored DB, false to keep as-is

EXAMPLES
  db.sh backup  http://localhost:8069 master-pass mydb zip ./backups
  db.sh restore http://localhost:8069 master-pass mydb_copy ./backups/mydb-20260401.zip
EOF
}

do_backup() {
    local format="${5:-zip}"
    local location="${6:-.}"

    if [[ "${format}" != "zip" && "${format}" != "dump" ]]; then
        echo "Error: FORMAT must be 'zip' or 'dump'." >&2
        exit 1
    fi

    mkdir -p "${location}"
    local output="${location}/${NAME}-$(date +"%Y%m%d-%H%M%S").${format}"
    local http_code

    http_code=$(curl -s -o "${output}" -w "%{http_code}" \
        -X POST \
        --header "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "master_pwd=${MASTER_PWD}" \
        --data-urlencode "name=${NAME}" \
        --data-urlencode "backup_format=${format}" \
        "${URL}/web/database/backup")

    if [[ "${http_code}" != "200" ]]; then
        echo "Error: backup failed (HTTP ${http_code})." >&2
        rm -f "${output}"
        exit 1
    fi

    echo "Backup saved: ${output}"
}

do_restore() {
    local file="${5:-}"
    local copy="${6:-true}"

    if [[ -z "${file}" ]]; then
        echo "Error: FILE is required for restore." >&2
        exit 1
    fi
    if [[ ! -f "${file}" ]]; then
        echo "Error: file not found: ${file}" >&2
        exit 1
    fi

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -F "master_pwd=${MASTER_PWD}" \
        -F "name=${NAME}" \
        -F "backup_file=@${file}" \
        -F "copy=${copy}" \
        "${URL}/web/database/restore")

    if [[ "${http_code}" != "200" ]]; then
        echo "Error: restore failed (HTTP ${http_code})." >&2
        exit 1
    fi

    echo "Restored: ${NAME} from ${file}"
}

# ── Entry ────────────────────────────────────────────────────────────────────

if [[ -z "${CMD}" || "${CMD}" == "help" || "${CMD}" == "h" ]]; then
    show_help
    exit 0
fi

if [[ -z "${URL}" || -z "${MASTER_PWD}" || -z "${NAME}" ]]; then
    echo "Error: URL, MASTER_PWD, and DB_NAME are required." >&2
    show_help >&2
    exit 1
fi

case "${CMD}" in
    backup)  do_backup "$@" ;;
    restore) do_restore "$@" ;;
    *)
        echo "Error: unknown command '${CMD}'. Use 'backup' or 'restore'." >&2
        exit 1
        ;;
esac
