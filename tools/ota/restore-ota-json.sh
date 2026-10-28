#!/bin/bash
# Undo publish-ota.sh: put the previously saved config/ota.json back on the branch, and optionally
# delete a test pre-release (and its tag).
#
#   restore-ota-json.sh [--repo mkostersitz/duo-de] [--branch main-16] [--delete-release TAG]
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
STATE="$HERE/state"
REPO="mkostersitz/duo-de"
BRANCH="main-16"
DEL_TAG=""

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "$(date +%H:%M:%S) $*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --delete-release) DEL_TAG="$2"; shift 2 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
case "$REPO" in [Aa]rch[Ff]x/*) die "refusing to touch Archfx's repository ($REPO)" ;; esac
gh auth status >/dev/null 2>&1 || die "gh is not logged in"

BACKUP="$STATE/ota.json.before.$BRANCH"
[ -f "$BACKUP" ] || die "no saved ota.json for branch $BRANCH in $STATE (nothing to restore)"
CUR_SHA="$(gh api "repos/$REPO/contents/config/ota.json?ref=$BRANCH" --jq .sha)"
log "restoring config/ota.json on $REPO@$BRANCH from $BACKUP"
gh api -X PUT "repos/$REPO/contents/config/ota.json" -f message="Restore config/ota.json after the OTA test" \
   -f branch="$BRANCH" -f sha="$CUR_SHA" -f content="$(base64 < "$BACKUP" | tr -d '\n')" --jq '.commit.sha' | sed 's/^/commit /'

if [ -n "$DEL_TAG" ]; then
  log "deleting release $DEL_TAG and its tag"
  gh release delete "$DEL_TAG" --repo "$REPO" --cleanup-tag --yes
fi
log "done"
