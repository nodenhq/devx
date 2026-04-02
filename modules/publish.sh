#!/usr/bin/env bash
# Noden | DevX Suite
# modules/publish.sh — Addon Publisher to Public Repo
set -euo pipefail

HELP() {
    cat <<EOF
publish-addon.sh — Sync selected files from a private repo to a public read-only repo.

USAGE
  ./publish-addon.sh URL [BRANCH]
  ./publish-addon.sh help

ARGUMENTS
  URL     Remote repository URL.
            Token-based : https://TOKEN@github.com/user/repo.git
            SSH         : git@github.com:user/repo.git
  BRANCH  Target branch to push to. Defaults to 'master'.
          Can also be set via the BRANCH environment variable.

SETUP
  Create a file named 'publish.txt' in the current directory listing the files
  or directories to sync, one per line. Lines starting with '#' are ignored.

EXAMPLE
  export BRANCH=dev
  ./publish-addon.sh git@github.com:org/public-repo.git

OUTPUT
  Creates or updates the target branch with the listed files, using the latest
  local commit message. Prints the published items on success.
EOF
}

URL="${1:-}"
BRANCH="${2:-${BRANCH:-master}}"
DIR=publish
TXT=publish.txt

if [[ -z "$URL" ]]; then
    echo "Error: repo URL is required." >&2
    exit 1
fi
if [[ "$URL" == "help" || "$URL" == "h" ]]; then
    HELP
    exit 0
fi
if [[ ! -f "$TXT" ]]; then
    echo "Error: $TXT does not exist." >&2
    exit 1
fi

cleanup() { [[ -d "$DIR" ]] && rm -rf "$DIR"; }
trap cleanup EXIT

[[ -d "$DIR" ]] && rm -rf "$DIR"
git clone "$URL" -b "$BRANCH" "$DIR"

PUBLISH_LIST=()
while IFS= read -r LINE; do
    [[ -z "$LINE" || "${LINE:0:1}" == "#" ]] && continue
    if [[ -e "$LINE" ]]; then
        echo "Copying $LINE -> $DIR/"
        cp -r "$LINE" "$DIR/"
        PUBLISH_LIST+=("$LINE")
    else
        echo "Warning: $LINE does not exist, skipping." >&2
    fi
done < "$TXT"

MSG=$(git show -s --format='%s')

pushd "$DIR" > /dev/null

if [[ -n "$(git status --porcelain)" ]]; then
    [[ -z "$(git config user.email)" ]] && git config user.email "no-reply@publish.bot"
    [[ -z "$(git config user.name)" ]]  && git config user.name "Publish Bot"

    git add .
    git commit -m "$MSG"
    git push --set-upstream origin "$BRANCH"

    popd > /dev/null
    trap - EXIT  # successful push — don't delete on exit

    echo -e "Publish at branch: $BRANCH\n\n${PUBLISH_LIST[*]}"
else
    popd > /dev/null
    echo "No changes to publish."
fi
