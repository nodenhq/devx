#!/usr/bin/env bash
set -euo pipefail

URL="${1:-}"
MASTER_PWD="${2:-}"
NAME="${3:-}"
FORMAT="${4:-zip}"
LOCATION="${5:-.}"

backup_help() {
    cat <<EOF
backup-web-db.sh — Download a backup from an Odoo server.

USAGE
  backup-web-db.sh URL MASTER_PWD DB_NAME [FORMAT] [LOCATION]

ARGUMENTS
  URL         Odoo server URL (e.g. http://localhost:8069)
  MASTER_PWD  Odoo master password
  DB_NAME     Database name to back up
  FORMAT      Backup format: zip (default) or dump
  LOCATION    Directory to save the backup (default: current directory)

OUTPUT
  Saves: LOCATION/DB_NAME-YYYYMMDD-HHMMSS.FORMAT

EXAMPLE
  backup-web-db.sh http://localhost:8069 master-pass mydb zip ./backups
EOF
}

backup_request() {
    local output="$LOCATION/$NAME-$(date +"%Y%m%d-%H%M%S").$FORMAT"
    local http_code

    http_code=$(curl -s -o "$output" -w "%{http_code}" \
        -X POST \
        --header "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "master_pwd=$MASTER_PWD" \
        --data-urlencode "name=$NAME" \
        --data-urlencode "backup_format=$FORMAT" \
        "$URL/web/database/backup")

    if [[ "$http_code" != "200" ]]; then
        echo "Error: backup failed (HTTP $http_code). Check URL, master password, and database name." >&2
        rm -f "$output"
        exit 1
    fi

    echo "Backup saved: $output"
}

if [[ -z "$URL" || "$URL" == "help" || "$URL" == "h" ]]; then
    backup_help
    exit 0
fi

if [[ -z "$MASTER_PWD" || -z "$NAME" ]]; then
    echo "Error: URL, MASTER_PWD, and DB_NAME are required." >&2
    backup_help >&2
    exit 1
fi

if [[ "$FORMAT" != "zip" && "$FORMAT" != "dump" ]]; then
    echo "Error: FORMAT must be 'zip' or 'dump'." >&2
    exit 1
fi

mkdir -p "$LOCATION"
backup_request
