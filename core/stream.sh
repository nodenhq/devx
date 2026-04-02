#! /bin/bash
# Noden | DevX Suite
# core/stream.sh — Local DB & Filestore Backup/Restore Stream

set -uo pipefail

CMD="${1:-backup}"

# ── JSON helpers ─────────────────────────────────────────────────────────────

cfg()  { jq -r "$1" "${CONFIG_FILE}"; }
cfgd() { jq -r "$1 // \"$2\"" "${CONFIG_FILE}"; }

# ── Helpers ──────────────────────────────────────────────────────────────────

log() { echo "  [$1]  $2"; }

show_help() {
    cat <<EOF
stream.sh — Backup & restore Odoo databases locally (pg_dump/psql + filestore).

USAGE
  stream.sh backup  [CONFIG_FILE]
  stream.sh restore INSTANCE DB ZIP_FILE [CONFIG_FILE]
  stream.sh help

COMMANDS
  backup    Back up all databases defined in the config file.
  restore   Restore a single database from a ZIP backup.

BACKUP
  Reads instances and databases from CONFIG_FILE (default: stream.json)
  and runs pg_dump + filestore copy for each one.

RESTORE ARGUMENTS
  INSTANCE    Instance name (must exist in config for pg credentials).
  DB          Target database name (will be created).
  ZIP_FILE    Path to .zip backup (containing dump.sql + filestore/).

ENVIRONMENT
  ODOO_BACKUP_CONFIG   Default config file path.

EXAMPLES
  stream.sh backup
  stream.sh backup /etc/odoo/stream.json
  stream.sh restore prod mydb-copy ./backups/mydb-20260401-120000.zip
EOF
}

configure_s3() {
    local endpoint access_key secret_key
    endpoint=$(cfg '.storage.s3.endpoint')
    access_key=$(cfgd '.storage.s3.access_key' "${S3_ACCESS_KEY:-}")
    secret_key=$(cfgd '.storage.s3.secret_key' "${S3_SECRET_KEY:-}")
    cat > ~/.s3cfg << EOF
[default]
access_key = ${access_key}
secret_key = ${secret_key}
host_base = ${endpoint}
host_bucket = %(bucket)s.${endpoint}
use_https = True
EOF
}

# ── pg_dump / pg_restore ────────────────────────────────────────────────────

run_pg_dump() {
    local pg_exec="$1" container="$2" host="$3" port="$4" user="$5" pass="$6" db="$7" out="$8"
    local args=(-h "${host}" -p "${port}" -U "${user}" "${db}")

    if [[ "${pg_exec}" == "docker" ]]; then
        docker exec -e PGPASSWORD="${pass}" "${container}" pg_dump "${args[@]}" > "${out}"
    else
        PGPASSWORD="${pass}" pg_dump "${args[@]}" > "${out}"
    fi
}

run_pg_create() {
    local pg_exec="$1" container="$2" host="$3" port="$4" user="$5" pass="$6" db="$7"
    local args=(-h "${host}" -p "${port}" -U "${user}" "${db}")

    if [[ "${pg_exec}" == "docker" ]]; then
        docker exec -e PGPASSWORD="${pass}" "${container}" createdb "${args[@]}"
    else
        PGPASSWORD="${pass}" createdb "${args[@]}"
    fi
}

run_psql() {
    local pg_exec="$1" container="$2" host="$3" port="$4" user="$5" pass="$6" db="$7" sql_file="$8"
    local args=(-h "${host}" -p "${port}" -U "${user}" -q -f "${sql_file}" "${db}")

    if [[ "${pg_exec}" == "docker" ]]; then
        docker cp "${sql_file}" "${container}:/tmp/_restore.sql"
        docker exec -e PGPASSWORD="${pass}" "${container}" \
            psql -h "${host}" -p "${port}" -U "${user}" -q -f /tmp/_restore.sql "${db}"
        docker exec "${container}" rm -f /tmp/_restore.sql
    else
        PGPASSWORD="${pass}" psql "${args[@]}"
    fi
}

# ── Storage backends ─────────────────────────────────────────────────────────

store_s3() {
    local zip_file="$1" instance="$2" db="$3" filename="$4"
    local bucket max_backups s3_path
    bucket=$(cfg '.storage.s3.bucket')
    max_backups=$(cfgd '.storage.s3.max_backups' '5')
    s3_path="${bucket}${instance}/${db}/"

    if ! s3cmd put "${zip_file}" "${s3_path}${filename}" --quiet; then
        log ERROR "s3 upload failed for ${instance}/${db}"
        return 1
    fi
    log ok "s3 → ${s3_path}${filename}"

    # Rotate
    mapfile -t all < <(s3cmd ls "${s3_path}" 2>/dev/null | grep " ${db}-" | sort | awk '{print $4}')
    local count=${#all[@]}
    if (( count > max_backups )); then
        local del=$(( count - max_backups ))
        for (( i=0; i<del; i++ )); do
            s3cmd del "${all[$i]}" --quiet
            log del "${all[$i]}"
        done
    fi
}

store_local() {
    local zip_file="$1" instance="$2" db="$3" filename="$4"
    local base max_backups dest
    base=$(cfg '.storage.local.path')
    max_backups=$(cfgd '.storage.local.max_backups' '5')
    dest="${base}/${instance}/${db}"

    mkdir -p "${dest}"
    if ! cp "${zip_file}" "${dest}/${filename}"; then
        log ERROR "local copy failed for ${instance}/${db}"
        return 1
    fi
    log ok "local → ${dest}/${filename}"

    # Rotate: keep newest max_backups
    mapfile -t all < <(ls -1t "${dest}/${db}"-*.zip 2>/dev/null)
    local count=${#all[@]}
    if (( count > max_backups )); then
        for (( i=max_backups; i<count; i++ )); do
            rm -f "${all[$i]}"
            log del "${all[$i]}"
        done
    fi
}

# ── Per-database backup ─────────────────────────────────────────────────────

backup_database() {
    local instance="$1" pg_host="$2" pg_port="$3" pg_exec="$4" container="$5"
    local filestore_base="$6" pg_user="$7" pg_pass="$8" db="$9"

    local ts work_dir filename zip_file
    ts=$(date +"%Y%m%d-%H%M%S")
    work_dir="${BACKUP_DIR}/${instance}_${db}_${ts}"
    filename="${db}-${ts}.zip"
    zip_file="${BACKUP_DIR}/${filename}"

    mkdir -p "${work_dir}"

    # 1. pg_dump
    log dump "${instance}/${db} via ${pg_exec}"
    if ! run_pg_dump "${pg_exec}" "${container}" "${pg_host}" "${pg_port}" \
            "${pg_user}" "${pg_pass}" "${db}" "${work_dir}/dump.sql"; then
        rm -rf "${work_dir}"
        log ERROR "pg_dump failed for ${instance}/${db}"
        return 1
    fi
    log ok "sql: $(du -sh "${work_dir}/dump.sql" | cut -f1)"

    # 2. Filestore
    local fs="${filestore_base}/${db}"
    if [[ -d "${fs}" ]]; then
        log copy "${fs}"
        if ! cp -r "${fs}" "${work_dir}/filestore"; then
            rm -rf "${work_dir}"
            log ERROR "filestore copy failed"
            return 1
        fi
        log ok "filestore: $(du -sh "${work_dir}/filestore" | cut -f1)"
    else
        log warn "filestore not found: ${fs} (skipping)"
    fi

    # 3. Zip
    log zip "${filename}"
    if ! (cd "${work_dir}" && zip -r "${zip_file}" . -q); then
        rm -rf "${work_dir}" "${zip_file}"
        log ERROR "zip failed"
        return 1
    fi
    rm -rf "${work_dir}"
    log ok "compressed: $(du -sh "${zip_file}" | cut -f1)"

    # 4. Store to enabled backends
    local store_ok=true

    if [[ "$(cfgd '.storage.s3.enabled' 'false')" == "true" ]]; then
        store_s3 "${zip_file}" "${instance}" "${db}" "${filename}" || store_ok=false
    fi

    if [[ "$(cfgd '.storage.local.enabled' 'false')" == "true" ]]; then
        store_local "${zip_file}" "${instance}" "${db}" "${filename}" || store_ok=false
    fi

    rm -f "${zip_file}"
    [[ "${store_ok}" == "true" ]]
}

# ── Per-database restore ────────────────────────────────────────────────────

restore_database() {
    local instance="$1" pg_host="$2" pg_port="$3" pg_exec="$4" container="$5"
    local filestore_base="$6" pg_user="$7" pg_pass="$8" db="$9" zip_file="${10}"

    local work_dir
    work_dir=$(mktemp -d)

    # 1. Unzip
    log unzip "${zip_file}"
    if ! unzip -q "${zip_file}" -d "${work_dir}"; then
        rm -rf "${work_dir}"
        log ERROR "unzip failed"
        return 1
    fi

    # Find the SQL dump (support both dump.sql and {db}.sql for old backups)
    local sql_file="${work_dir}/dump.sql"
    if [[ ! -f "${sql_file}" ]]; then
        sql_file=$(find "${work_dir}" -maxdepth 1 -name "*.sql" | head -1)
    fi
    if [[ -z "${sql_file}" || ! -f "${sql_file}" ]]; then
        rm -rf "${work_dir}"
        log ERROR "no SQL dump found in ${zip_file}"
        return 1
    fi
    log ok "sql: $(du -sh "${sql_file}" | cut -f1)"

    # 2. Create database
    log createdb "${instance}/${db}"
    if ! run_pg_create "${pg_exec}" "${container}" "${pg_host}" "${pg_port}" \
            "${pg_user}" "${pg_pass}" "${db}"; then
        rm -rf "${work_dir}"
        log ERROR "createdb failed for ${db}"
        return 1
    fi

    # 3. Restore SQL
    log psql "${instance}/${db}"
    if ! run_psql "${pg_exec}" "${container}" "${pg_host}" "${pg_port}" \
            "${pg_user}" "${pg_pass}" "${db}" "${sql_file}"; then
        rm -rf "${work_dir}"
        log ERROR "psql restore failed for ${db}"
        return 1
    fi
    log ok "database restored"

    # 4. Restore filestore
    if [[ -d "${work_dir}/filestore" ]]; then
        local dest="${filestore_base}/${db}"
        log copy "filestore → ${dest}"
        mkdir -p "${dest}"
        if ! cp -r "${work_dir}/filestore/"* "${dest}/"; then
            rm -rf "${work_dir}"
            log ERROR "filestore restore failed"
            return 1
        fi
        log ok "filestore: $(du -sh "${dest}" | cut -f1)"
    else
        log warn "no filestore in backup (skipping)"
    fi

    rm -rf "${work_dir}"
    log ok "restore complete: ${instance}/${db}"
}

# ── Lookup instance config ──────────────────────────────────────────────────

get_instance_index() {
    local target="$1"
    local count
    count=$(cfg '.instances | length')
    for (( i=0; i<count; i++ )); do
        local name
        name=$(cfg ".instances[${i}].name")
        if [[ "${name}" == "${target}" ]]; then
            echo "${i}"
            return 0
        fi
    done
    return 1
}

# ── Main: backup ─────────────────────────────────────────────────────────────

main_backup() {
    echo "========================================"
    echo " Odoo Multi-instance Backup"
    echo " $(date '+%Y-%m-%d %H:%M:%S')"
    echo "========================================"

    BACKUP_DIR=$(cfgd '.backup_dir' '/tmp/odoo-backups')
    mkdir -p "${BACKUP_DIR}"

    if [[ "$(cfgd '.storage.s3.enabled' 'false')" == "true" ]]; then
        configure_s3
    fi

    local ok_dbs=() fail_dbs=()
    local instance_count
    instance_count=$(cfg '.instances | length')

    for (( idx=0; idx<instance_count; idx++ )); do
        local name pg_host pg_port pg_exec container filestore_base
        name=$(cfg ".instances[${idx}].name")
        pg_host=$(cfgd ".instances[${idx}].pg_host" "127.0.0.1")
        pg_port=$(cfgd ".instances[${idx}].pg_port" "5432")
        pg_exec=$(cfgd ".instances[${idx}].pg_exec" "local")
        container=$(cfgd ".instances[${idx}].docker_container" "")
        filestore_base=$(cfg ".instances[${idx}].filestore_base")

        local pg_user pg_pass
        pg_user=$(cfgd ".instances[${idx}].pg_user" "")
        pg_pass=$(cfgd ".instances[${idx}].pg_pass" "")

        if [[ -z "${pg_user}" || -z "${pg_pass}" ]]; then
            echo ""
            echo "--- [SKIP] '${name}': missing pg_user or pg_pass in config ---"
            continue
        fi

        if [[ "${pg_exec}" == "docker" && -z "${container}" ]]; then
            echo ""
            echo "--- [SKIP] '${name}': pg_exec=docker but no docker_container ---"
            continue
        fi

        echo ""
        echo "--- ${name} (${pg_exec}, ${pg_host}:${pg_port}) ---"

        while IFS= read -r db; do
            [[ -z "${db}" ]] && continue
            if backup_database "${name}" "${pg_host}" "${pg_port}" "${pg_exec}" "${container}" \
                    "${filestore_base}" "${pg_user}" "${pg_pass}" "${db}"; then
                ok_dbs+=("${name}/${db}")
            else
                fail_dbs+=("${name}/${db}")
            fi
        done < <(cfg ".instances[${idx}].databases[]")
    done

    # Summary
    echo ""
    echo "========================================"
    echo " ${#ok_dbs[@]} ok | ${#fail_dbs[@]} failed"
    echo "========================================"

    local msg
    if (( ${#fail_dbs[@]} == 0 )); then
        msg="Odoo backup complete — ${#ok_dbs[@]} db(s) ($(date '+%Y-%m-%d %H:%M:%S'))"
    else
        local failed_list
        failed_list=$(printf '%s, ' "${fail_dbs[@]}" | sed 's/, $//')
        msg="Odoo backup — ${#ok_dbs[@]} ok, ${#fail_dbs[@]} failed: ${failed_list} ($(date '+%Y-%m-%d %H:%M:%S'))"
    fi

    echo "${msg}"
    [[ ${#fail_dbs[@]} -eq 0 ]]
}

# ── Main: restore ────────────────────────────────────────────────────────────

main_restore() {
    local instance="$1" db="$2" zip_file="$3"

    echo "========================================"
    echo " Odoo Restore: ${instance}/${db}"
    echo " $(date '+%Y-%m-%d %H:%M:%S')"
    echo "========================================"

    if [[ ! -f "${zip_file}" ]]; then
        echo "[ERROR] File not found: ${zip_file}"
        exit 1
    fi

    local idx
    if ! idx=$(get_instance_index "${instance}"); then
        echo "[ERROR] Instance '${instance}' not found in config"
        exit 1
    fi

    local pg_host pg_port pg_exec container filestore_base pg_user pg_pass
    pg_host=$(cfgd ".instances[${idx}].pg_host" "127.0.0.1")
    pg_port=$(cfgd ".instances[${idx}].pg_port" "5432")
    pg_exec=$(cfgd ".instances[${idx}].pg_exec" "local")
    container=$(cfgd ".instances[${idx}].docker_container" "")
    filestore_base=$(cfg ".instances[${idx}].filestore_base")
    pg_user=$(cfgd ".instances[${idx}].pg_user" "")
    pg_pass=$(cfgd ".instances[${idx}].pg_pass" "")

    if [[ -z "${pg_user}" || -z "${pg_pass}" ]]; then
        echo "[ERROR] Missing pg_user or pg_pass for instance '${instance}'"
        exit 1
    fi

    if restore_database "${instance}" "${pg_host}" "${pg_port}" "${pg_exec}" "${container}" \
            "${filestore_base}" "${pg_user}" "${pg_pass}" "${db}" "${zip_file}"; then
        echo ""
        echo "Restore complete: ${instance}/${db}"
    else
        echo ""
        echo "[ERROR] Restore failed: ${instance}/${db}"
        exit 1
    fi
}

# ── Entry ────────────────────────────────────────────────────────────────────

if [[ "${CMD}" == "help" || "${CMD}" == "h" ]]; then
    show_help
    exit 0
fi

if [[ "${CMD}" == "restore" ]]; then
    INSTANCE="${2:-}"
    DB="${3:-}"
    ZIP_FILE="${4:-}"
    CONFIG_FILE="${5:-${ODOO_BACKUP_CONFIG:-$(dirname "$0")/stream.json}}"

    if [[ -z "${INSTANCE}" || -z "${DB}" || -z "${ZIP_FILE}" ]]; then
        echo "Error: INSTANCE, DB, and ZIP_FILE are required for restore." >&2
        show_help >&2
        exit 1
    fi
else
    CONFIG_FILE="${2:-${ODOO_BACKUP_CONFIG:-$(dirname "$0")/stream.json}}"
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "[ERROR] Config not found: ${CONFIG_FILE}"
    exit 1
fi
if ! command -v jq &>/dev/null; then
    echo "[ERROR] jq is required"
    exit 1
fi

case "${CMD}" in
    backup)  main_backup ;;
    restore) main_restore "${INSTANCE}" "${DB}" "${ZIP_FILE}" ;;
    *)
        echo "Error: unknown command '${CMD}'. Use 'backup', 'restore', or 'help'." >&2
        exit 1
        ;;
esac
