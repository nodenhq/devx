#!/usr/bin/env bash
# Noden | DevX Suite
# modules/publish.sh — Publish to read-only repos or mirror between repos
set -euo pipefail

# --- Colors & logging ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log()  { echo -e "${CYAN}[publish]${NC} $*"; }
ok()   { echo -e "${GREEN}[publish]${NC} $*"; }
warn() { echo -e "${YELLOW}[publish]${NC} $*" >&2; }
err()  { echo -e "${RED}[publish]${NC} $*" >&2; }

HELP() {
    cat <<EOF
${BOLD}publish.sh${NC} — Publish files to a read-only repo, or mirror a full branch.

${BOLD}USAGE${NC}
  ./publish.sh <command> <url> [options]
  ./publish.sh mirror [origin_url] <dest_url> [options]

${BOLD}COMMANDS${NC}
  sync    Sync selected files/dirs (from publish.txt) to a read-only repo.
  mirror  Mirror a branch to a remote repo. With two URLs, mirrors from origin to dest.
  help    Show this help message.

${BOLD}OPTIONS${NC}
  -b, --branch BRANCH   Target branch (default: current branch or 'main').
  -f, --file FILE       Publish list file (default: publish.txt). [sync only]
  -m, --message MSG     Custom commit message (default: latest commit msg). [sync only]
  --force               Force push (for mirror or overwriting target). Use with care.
  --dry-run             Show what would be done without pushing.

${BOLD}EXAMPLES${NC}
  # Sync specific paths to a read-only public repo
  ./publish.sh sync git@github.com:org/public-repo.git -b main

  # Mirror current branch to another repo
  ./publish.sh mirror git@github.com:org/backup-repo.git

  # Mirror from one repo to another
  ./publish.sh mirror git@github.com:org/source.git git@github.com:org/dest.git

  # Mirror a specific branch between repos
  ./publish.sh mirror git@github.com:org/source.git git@github.com:org/dest.git -b staging

  # Dry run
  ./publish.sh sync https://TOKEN@github.com/user/repo.git --dry-run

${BOLD}SETUP (sync mode)${NC}
  Create a file named 'publish.txt' listing files/dirs to publish, one per line.
  Lines starting with '#' are ignored. Glob patterns are supported.
EOF
}

# --- Defaults ---
CMD="${1:-help}"
shift 2>/dev/null || true

URL=""
URL2=""
BRANCH=""
TXT="publish.txt"
MSG=""
FORCE=false
DRY_RUN=false
WORK_DIR=".publish_tmp"

# --- Parse args ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--branch)  BRANCH="$2"; shift 2 ;;
        -f|--file)    TXT="$2"; shift 2 ;;
        -m|--message) MSG="$2"; shift 2 ;;
        --force)      FORCE=true; shift ;;
        --dry-run)    DRY_RUN=true; shift ;;
        -h|--help)    HELP; exit 0 ;;
        -*)           err "Unknown option: $1"; exit 1 ;;
        *)
            if [[ -z "$URL" ]]; then
                URL="$1"
            elif [[ -z "$URL2" ]]; then
                URL2="$1"
            else
                err "Unexpected argument: $1"
                exit 1
            fi
            shift ;;
    esac
done

# --- Resolve branch ---
if [[ -z "$BRANCH" ]]; then
    BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
fi

# --- Helpers ---
cleanup() { [[ -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"; }

ensure_url() {
    if [[ -z "$URL" ]]; then
        err "Repository URL is required."
        echo "  Usage: ./publish.sh $CMD <url> [options]" >&2
        exit 1
    fi
}

# --- sync: publish selected paths to a read-only repo ---
cmd_sync() {
    ensure_url

    if [[ ! -f "$TXT" ]]; then
        err "Publish list '$TXT' not found. Create it with paths to sync."
        exit 1
    fi

    trap cleanup EXIT
    [[ -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"

    # Clone target or init if branch doesn't exist yet
    if git ls-remote --heads "$URL" "$BRANCH" 2>/dev/null | grep -q .; then
        log "Cloning $BRANCH from target..."
        git clone "$URL" -b "$BRANCH" --single-branch --depth 1 "$WORK_DIR" 2>/dev/null
    else
        log "Branch '$BRANCH' not found on remote, creating..."
        mkdir -p "$WORK_DIR"
        git -C "$WORK_DIR" init -q
        git -C "$WORK_DIR" remote add origin "$URL"
        git -C "$WORK_DIR" checkout -b "$BRANCH"
    fi

    # Collect and copy files
    local count=0
    local items=()
    while IFS= read -r line; do
        [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
        # Support glob patterns
        local matches=()
        matches=($line) 2>/dev/null || true
        for item in "${matches[@]}"; do
            if [[ -e "$item" ]]; then
                log "  $item -> target"
                cp -r "$item" "$WORK_DIR/"
                items+=("$item")
                (( count++ ))
            else
                warn "  $item — not found, skipping"
            fi
        done
    done < "$TXT"

    if (( count == 0 )); then
        warn "Nothing to publish."
        exit 0
    fi

    # Commit message
    local commit_msg="${MSG:-$(git show -s --format='%s' 2>/dev/null || echo "publish update")}"

    pushd "$WORK_DIR" > /dev/null

    if [[ -z "$(git status --porcelain)" ]]; then
        popd > /dev/null
        ok "No changes to publish."
        exit 0
    fi

    if $DRY_RUN; then
        echo ""
        log "Dry run — changes that would be published:"
        git status --short
        popd > /dev/null
        exit 0
    fi

    [[ -z "$(git config user.email 2>/dev/null)" ]] && git config user.email "no-reply@publish.bot"
    [[ -z "$(git config user.name 2>/dev/null)" ]]  && git config user.name "Publish Bot"

    git add .
    git commit -q -m "$commit_msg"

    local push_flags=("--set-upstream" "origin" "$BRANCH")
    $FORCE && push_flags=("--force" "${push_flags[@]}")

    git push "${push_flags[@]}"
    popd > /dev/null

    echo ""
    ok "Published $count item(s) to $BRANCH"
    printf '  %s\n' "${items[@]}"
}

# --- mirror: push branch as-is to remote ---
# Supports two forms:
#   mirror <dest>               — mirror current repo -> dest
#   mirror <origin> <dest>      — mirror origin repo -> dest
cmd_mirror() {
    local origin_url=""
    local dest_url=""

    if [[ -n "$URL2" ]]; then
        # Two positional args: origin dest
        origin_url="$URL"
        dest_url="$URL2"
    elif [[ -n "$URL" ]]; then
        # One positional arg: current repo -> dest
        dest_url="$URL"
    else
        err "Repository URL is required."
        echo "  Usage: ./publish.sh mirror [origin_url] <dest_url> [options]" >&2
        exit 1
    fi

    local src_branch="$BRANCH"
    local push_flags=()
    $FORCE && push_flags+=("--force")

    if [[ -n "$origin_url" ]]; then
        # Clone origin into a temp dir, then push to dest
        log "Mirroring '$src_branch': $origin_url -> $dest_url"

        if $DRY_RUN; then
            log "Dry run — would mirror '$src_branch' from $origin_url to $dest_url"
            exit 0
        fi

        trap cleanup EXIT
        [[ -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"

        log "Cloning from origin..."
        git clone "$origin_url" -b "$src_branch" --single-branch --bare "$WORK_DIR" 2>/dev/null

        git -C "$WORK_DIR" push "${push_flags[@]}" "$dest_url" "$src_branch:$BRANCH"

        ok "Mirrored '$src_branch': $origin_url -> $dest_url ($BRANCH)"
    else
        # Original behavior: push current repo's branch to dest
        log "Mirroring branch '$src_branch' -> $dest_url"

        local remote_name="publish_mirror_$$"
        git remote add "$remote_name" "$dest_url" 2>/dev/null || true
        trap "git remote remove '$remote_name' 2>/dev/null || true" EXIT

        if $DRY_RUN; then
            log "Dry run — would push '$src_branch' to $dest_url"
            exit 0
        fi

        git push "${push_flags[@]}" "$remote_name" "$src_branch:$BRANCH"

        ok "Mirrored '$src_branch' -> $dest_url ($BRANCH)"
    fi
}

# --- Dispatch ---
case "$CMD" in
    sync)    cmd_sync ;;
    mirror)  cmd_mirror ;;
    help|h|-h|--help) HELP ;;
    *)
        # Backward compat: treat first arg as URL for sync mode
        if [[ "$CMD" =~ ^(https?://|git@) ]]; then
            URL="$CMD"
            cmd_sync
        else
            err "Unknown command: $CMD"
            echo "  Run './publish.sh help' for usage." >&2
            exit 1
        fi
        ;;
esac
