#!/usr/bin/env bash
# noden | Odoo DevX
# scripts/copy-addons.sh — Copy Odoo modules from another repo at the same branch
set -euo pipefail

# --- Colors & logging ---
RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; NC=$'\033[0m'
log()  { echo -e "${CYAN}[copy-addons]${NC} $*"; }
ok()   { echo -e "${GREEN}[copy-addons]${NC} $*"; }
warn() { echo -e "${YELLOW}[copy-addons]${NC} $*" >&2; }
err()  { echo -e "${RED}[copy-addons]${NC} $*" >&2; }

HELP() {
    cat <<EOF
${BOLD}copy-addons.sh${NC} — Copy Odoo modules from another repo, at the branch you are on.

Detects the current branch of the repo you run it from, positions the source repo
on that same branch, and copies the modules across. Use it to pull a shared
connector into a project repo without hand-copying directories.

${BOLD}USAGE${NC}
  ./copy-addons.sh --path DIR  [options] [MODULE ...]
  ./copy-addons.sh --repo URL  [options] [MODULE ...]
  ./copy-addons.sh help

${BOLD}SOURCE (one required)${NC}
  --path DIR            Local repo to copy from (e.g. ../odoo-skydropx).
  --repo URL            Remote repo to clone from (ssh:// | git@ | https://).

${BOLD}OPTIONS${NC}
  --sources DIR         Addons dir inside the source (default: addons).
  --destiny DIR         Addons dir inside the destination (default: addons).
  -b, --branch BRANCH   Override the detected branch.
  --no-checkout         With --path, read the branch via 'git archive' instead of
                        checking it out. Leaves the source repo untouched.
  --skip-existing       Keep modules that already exist in the destination.
  --dry-run             Show what would be copied without writing anything.
  -h, --help            Show this help message.

  MODULE ...            Copy only these modules. Default: every module found.

${BOLD}BEHAVIOUR${NC}
  * A "module" is a direct subdirectory of --sources containing __manifest__.py.
  * Each module is replaced wholesale: the destination copy is removed first, so
    files deleted upstream do not linger behind. Use --skip-existing to opt out.
  * __pycache__, *.pyc and .git are never copied.
  * With --path the source repo is switched to the target branch and left there.
    The script refuses to do that if its working tree is dirty. --no-checkout
    avoids touching it at all.
  * With --repo the clone lands in a temp dir that is removed on exit.

${BOLD}EXAMPLES${NC}
  # On branch 18.0 of the current project, pull every module from a sibling repo
  ./copy-addons.sh --path ../odoo-skydropx

  # Same, but clone the source instead and copy one module
  ./copy-addons.sh --repo git@github.com:nodenlabs/odoo-skydropx.git innovt_srenvio

  # Non-default directory layout
  ./copy-addons.sh --path ../odoo-galacom --sources . --destiny addons

  # Always look first
  ./copy-addons.sh --path ../odoo-skydropx --dry-run
EOF
}

# --- Defaults ---
SRC_PATH=""
SRC_REPO=""
SOURCES="addons"
DESTINY="addons"
BRANCH=""
NO_CHECKOUT=false
SKIP_EXISTING=false
DRY_RUN=false
MODULES=()
TMP_DIR=""

cleanup() { [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR" || true; }
trap cleanup EXIT

# --- Parse args ---
[[ $# -eq 0 ]] && { HELP; exit 0; }
case "${1:-}" in help) HELP; exit 0 ;; esac

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)          SRC_PATH="${2:-}"; shift 2 ;;
        --repo)          SRC_REPO="${2:-}"; shift 2 ;;
        --sources)       SOURCES="${2:-}"; shift 2 ;;
        --destiny|--dest) DESTINY="${2:-}"; shift 2 ;;
        -b|--branch)     BRANCH="${2:-}"; shift 2 ;;
        --no-checkout)   NO_CHECKOUT=true; shift ;;
        --skip-existing) SKIP_EXISTING=true; shift ;;
        --dry-run)       DRY_RUN=true; shift ;;
        -h|--help)       HELP; exit 0 ;;
        -*)              err "Unknown option: $1"; exit 1 ;;
        *)               MODULES+=("$1"); shift ;;
    esac
done

# --- Validate source selection ---
if [[ -n "$SRC_PATH" && -n "$SRC_REPO" ]]; then
    err "--path and --repo are mutually exclusive."; exit 1
fi
if [[ -z "$SRC_PATH" && -z "$SRC_REPO" ]]; then
    err "A source is required: --path DIR or --repo URL. See 'help'."; exit 1
fi

# --- 1. Detect the branch of the repo we are run from ---
DEST_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$DEST_ROOT" ]]; then
    err "Not inside a git repository — run this from the destination repo."; exit 1
fi

if [[ -z "$BRANCH" ]]; then
    BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    if [[ "$BRANCH" == "HEAD" ]]; then
        err "Detached HEAD — cannot detect a branch. Pass -b/--branch."; exit 1
    fi
    log "Detected branch: ${BOLD}${BRANCH}${NC} (from $DEST_ROOT)"
else
    log "Using branch: ${BOLD}${BRANCH}${NC} (given)"
fi

# --- 2. Position the source on that branch ---
SRC_ROOT=""
ARCHIVE_MODE=false

if [[ -n "$SRC_REPO" ]]; then
    TMP_DIR="$(mktemp -d -t copy-addons.XXXXXXXX)"
    log "Cloning $SRC_REPO at branch $BRANCH ..."
    if ! git clone --quiet --depth 1 --branch "$BRANCH" "$SRC_REPO" "$TMP_DIR/src"; then
        err "Clone failed. Does branch '$BRANCH' exist in $SRC_REPO?"; exit 1
    fi
    SRC_ROOT="$TMP_DIR/src"
    ok "Cloned into $SRC_ROOT"
else
    [[ -d "$SRC_PATH" ]] || { err "--path not found: $SRC_PATH"; exit 1; }
    SRC_ROOT="$(cd "$SRC_PATH" && git rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$SRC_ROOT" ]] || { err "--path is not a git repository: $SRC_PATH"; exit 1; }

    if [[ "$SRC_ROOT" == "$DEST_ROOT" ]]; then
        err "Source and destination are the same repository ($SRC_ROOT)."; exit 1
    fi

    # The branch must exist in the source
    if ! git -C "$SRC_ROOT" rev-parse --verify --quiet "refs/heads/$BRANCH" >/dev/null; then
        if git -C "$SRC_ROOT" rev-parse --verify --quiet "refs/remotes/origin/$BRANCH" >/dev/null; then
            log "Branch '$BRANCH' exists only on origin; creating a local tracking branch."
            if [[ "$DRY_RUN" == false && "$NO_CHECKOUT" == false ]]; then
                git -C "$SRC_ROOT" branch --quiet --track "$BRANCH" "origin/$BRANCH"
            fi
        else
            err "Branch '$BRANCH' does not exist in $SRC_ROOT (neither local nor origin/)."
            err "Available: $(git -C "$SRC_ROOT" for-each-ref --format='%(refname:short)' refs/heads | tr '\n' ' ')"
            exit 1
        fi
    fi

    if [[ "$NO_CHECKOUT" == true ]]; then
        ARCHIVE_MODE=true
        log "Reading $BRANCH from $SRC_ROOT via git archive (source untouched)."
    else
        CURRENT_SRC_BRANCH="$(git -C "$SRC_ROOT" rev-parse --abbrev-ref HEAD)"
        if [[ "$CURRENT_SRC_BRANCH" != "$BRANCH" ]]; then
            if [[ -n "$(git -C "$SRC_ROOT" status --porcelain)" ]]; then
                err "Source repo has uncommitted changes; refusing to switch branch."
                err "Commit/stash in $SRC_ROOT, or use --no-checkout."
                exit 1
            fi
            if [[ "$DRY_RUN" == true ]]; then
                log "Would check out $BRANCH in $SRC_ROOT (currently $CURRENT_SRC_BRANCH)."
                ARCHIVE_MODE=true
            else
                log "Checking out $BRANCH in $SRC_ROOT (was $CURRENT_SRC_BRANCH)."
                git -C "$SRC_ROOT" checkout --quiet "$BRANCH"
                warn "Source repo left on '$BRANCH' (was '$CURRENT_SRC_BRANCH')."
            fi
        else
            log "Source repo already on $BRANCH."
        fi
    fi
fi

# --- 3. Resolve directories and list modules ---
if [[ "$ARCHIVE_MODE" == true ]]; then
    TMP_DIR="${TMP_DIR:-$(mktemp -d -t copy-addons.XXXXXXXX)}"
    mkdir -p "$TMP_DIR/archive"
    SRC_REL="${SOURCES#./}"; SRC_REL="${SRC_REL%/}"
    if [[ "$SRC_REL" == "." || -z "$SRC_REL" ]]; then
        git -C "$SRC_ROOT" archive "$BRANCH" | tar -x -C "$TMP_DIR/archive"
    else
        git -C "$SRC_ROOT" archive "$BRANCH" "$SRC_REL" | tar -x -C "$TMP_DIR/archive"
    fi
    SRC_DIR="$TMP_DIR/archive/${SRC_REL:-.}"
else
    SRC_DIR="$SRC_ROOT/${SOURCES#./}"
fi
SRC_DIR="${SRC_DIR%/}"
[[ -d "$SRC_DIR" ]] || { err "Sources dir not found in source: $SOURCES"; exit 1; }

DEST_DIR="$DEST_ROOT/${DESTINY#./}"
DEST_DIR="${DEST_DIR%/}"

# Discover modules: direct subdirs holding a manifest
FOUND=()
while IFS= read -r d; do
    [[ -f "$d/__manifest__.py" ]] && FOUND+=("$(basename "$d")")
done < <(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ ${#FOUND[@]} -eq 0 ]]; then
    err "No Odoo modules (dirs with __manifest__.py) found in $SRC_DIR"; exit 1
fi

# Restrict to the requested modules, if any
if [[ ${#MODULES[@]} -gt 0 ]]; then
    for m in "${MODULES[@]}"; do
        printf '%s\n' "${FOUND[@]}" | grep -qx -- "$m" || {
            err "Module '$m' not found in $SRC_DIR"
            err "Available: ${FOUND[*]}"
            exit 1
        }
    done
    SELECTED=("${MODULES[@]}")
else
    SELECTED=("${FOUND[@]}")
fi

log "Source     : $SRC_DIR"
log "Destination: $DEST_DIR"
log "Modules    : ${#SELECTED[@]} of ${#FOUND[@]} found — ${SELECTED[*]}"
[[ "$DRY_RUN" == true ]] && warn "DRY RUN — nothing will be written."

# --- Copy ---
if command -v rsync >/dev/null 2>&1; then
    COPY() { rsync -a --exclude='__pycache__' --exclude='*.pyc' --exclude='.git' "$1/" "$2/"; }
else
    COPY() { cp -a "$1/." "$2/" && find "$2" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true; }
fi

[[ "$DRY_RUN" == false ]] && mkdir -p "$DEST_DIR"

COPIED=0; SKIPPED=0; REPLACED=0
for m in "${SELECTED[@]}"; do
    src="$SRC_DIR/$m"
    dst="$DEST_DIR/$m"
    if [[ -d "$dst" ]]; then
        if [[ "$SKIP_EXISTING" == true ]]; then
            warn "skip     $m (already in destination)"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi
        if [[ "$DRY_RUN" == true ]]; then
            log "replace  $m"
        else
            rm -rf "$dst"
            mkdir -p "$dst"
            COPY "$src" "$dst"
            ok "replace  $m"
        fi
        REPLACED=$((REPLACED + 1))
    else
        if [[ "$DRY_RUN" == true ]]; then
            log "copy     $m"
        else
            mkdir -p "$dst"
            COPY "$src" "$dst"
            ok "copy     $m"
        fi
        COPIED=$((COPIED + 1))
    fi
done

echo
ok "Branch $BRANCH — ${COPIED} new, ${REPLACED} replaced, ${SKIPPED} skipped."
if [[ "$DRY_RUN" == false ]]; then
    log "Review with: git -C $DEST_ROOT status --short $DESTINY"
fi
