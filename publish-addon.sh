#!/usr/bin/env bash
set -euo pipefail

HELP() {
    cat <<EOF
Sync Utility

This script is designed for private repositories that publish to a
public read-only repository.

How to use:

1) Create 'publish.txt' and list the files or directories to publish (one per line).
2) Run: ./publish.sh URL [BRANCH]
  - Arg 1: https://gitlab:TOKEN@github.com/user/repo.git or git@github.com:user/repo.git
  - Arg 2: Target branch (e.g., master or dev)
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
