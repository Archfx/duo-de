#!/bin/bash
# Publish a test OTA build: a GitHub PRE-release with the .img.xz plus config/ota.json on a branch
# of a fork. The device polls ro.system.ota.json_url, which for our builds is
#   https://raw.githubusercontent.com/<fork>/main-16/config/ota.json
#
#   publish-ota.sh --image-xz FILE [--image FILE] [--variant treble_arm64_bgN]
#                  [--repo mkostersitz/duo-de] [--branch main-16] [--tag TAG]
#                  [--date EPOCH] [--corrupt-sha256 img|xz] [--no-upload] [--dry-run]
#
# --date             override the json "date" (default: ro.system.build.date.utc read from the image)
# --corrupt-sha256   publish a wrong hash on purpose (negative test of the Updater verification)
# --no-upload        reuse an already uploaded release asset (only rewrite ota.json)
# --dry-run          build ota.json locally and print the plan, change nothing on GitHub
#
# The previous config/ota.json of the branch is saved to ota/state/ so restore-ota-json.sh can undo this.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
STATE="$HERE/state"
DEBUGFS="${DEBUGFS:-/opt/homebrew/opt/e2fsprogs/sbin/debugfs}"
REPO="mkostersitz/duo-de"
BRANCH="main-16"
VARIANT="treble_arm64_bgN"
XZ=""; IMG=""; TAG=""; DATE_OVERRIDE=""; CORRUPT=""; NO_UPLOAD=0; DRY=0

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "$(date +%H:%M:%S) $*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --image-xz) XZ="$2"; shift 2 ;;
    --image) IMG="$2"; shift 2 ;;
    --variant) VARIANT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    --date) DATE_OVERRIDE="$2"; shift 2 ;;
    --corrupt-sha256) CORRUPT="$2"; shift 2 ;;
    --no-upload) NO_UPLOAD=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$XZ" ] && [ -f "$XZ" ] || die "--image-xz FILE is required"
case "$REPO" in
  [Aa]rch[Ff]x/*) die "refusing to publish to Archfx's repository ($REPO); use a fork" ;;
esac
case "$CORRUPT" in ""|img|xz) ;; *) die "--corrupt-sha256 takes img or xz" ;; esac
for t in jq gh curl shasum xz base64; do command -v "$t" >/dev/null || die "missing tool: $t"; done
[ -x "$DEBUGFS" ] || die "debugfs not found at $DEBUGFS (brew install e2fsprogs)"
if [ "$DRY" = 0 ]; then gh auth status >/dev/null 2>&1 || die "gh is not logged in"; fi
mkdir -p "$STATE"

# decompressed image: sibling .img if there is one, else decompress to a temp file
if [ -z "$IMG" ]; then
  cand="${XZ%.xz}"
  if [ -f "$cand" ]; then IMG="$cand"; else
    IMG="$(mktemp -d)/$(basename "$cand")"
    log "decompressing $(basename "$XZ") to $IMG"
    xz -dc "$XZ" > "$IMG"
  fi
fi
[ -f "$IMG" ] || die "image not found: $IMG"

log "hashing"
XZ_SHA="$(shasum -a 256 "$XZ" | awk '{print $1}')"
IMG_SHA="$(shasum -a 256 "$IMG" | awk '{print $1}')"
SIZE="$(wc -c < "$XZ" | tr -d ' ')"
BUILD_DATE="$("$DEBUGFS" -R "cat /system/build.prop" "$IMG" 2>/dev/null | sed -n 's/^ro.system.build.date.utc=//p' | head -1)"
[ -n "$BUILD_DATE" ] || die "could not read ro.system.build.date.utc from $IMG"
JSON_DATE="${DATE_OVERRIDE:-$BUILD_DATE}"
VERSION="v$(date -u -r "$BUILD_DATE" +%Y.%m.%d)"
[ -n "$TAG" ] || TAG="ota-test-$(date -u +%Y%m%d-%H%M)"
ASSET="$(basename "$XZ")"
URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"

SENT_XZ="$XZ_SHA"; SENT_IMG="$IMG_SHA"
flip() { local h="$1" last="${1: -1}"; if [ "$last" = "0" ]; then echo "${h%?}1"; else echo "${h%?}0"; fi; }
[ "$CORRUPT" = xz ] && SENT_XZ="$(flip "$XZ_SHA")"
[ "$CORRUPT" = img ] && SENT_IMG="$(flip "$IMG_SHA")"

OUT="$STATE/ota.json.$TAG"
jq -n --arg version "$VERSION" --arg date "$JSON_DATE" --arg name "$VARIANT" --arg size "$SIZE" \
      --arg xz "$SENT_XZ" --arg img "$SENT_IMG" --arg url "$URL" \
  '{version:$version, date:$date, variants:[{name:$name, size:$size, xz_sha256:$xz, sha256:$img, url:$url}]}' > "$OUT"

echo "------------------------------------------------------------"
echo "repo:            $REPO   branch: $BRANCH   release tag: $TAG (pre-release)"
echo "image:           $ASSET  ($SIZE bytes)"
echo "variant:         $VARIANT"
echo "build date utc:  $BUILD_DATE  (json date: $JSON_DATE)"
echo "xz sha256:       $SENT_XZ$([ "$CORRUPT" = xz ] && echo "   <-- deliberately corrupted")"
echo "image sha256:    $SENT_IMG$([ "$CORRUPT" = img ] && echo "   <-- deliberately corrupted")"
echo "ota.json:        $OUT"
echo "------------------------------------------------------------"
if [ "$DRY" = 1 ]; then log "dry run, nothing published"; cat "$OUT"; exit 0; fi

# 1. release + asset
if [ "$NO_UPLOAD" = 0 ]; then
  if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    log "creating pre-release $TAG"
    gh release create "$TAG" --repo "$REPO" --prerelease --title "OTA test $TAG" \
       --notes "OTA test build for the DUO-DE updater (not a release). Image: $ASSET, build date $BUILD_DATE."
  fi
  log "uploading $ASSET (this takes a while)"
  gh release upload "$TAG" "$XZ" --repo "$REPO" --clobber
fi

# 2. save the current ota.json of the branch, then replace it
CUR="$(gh api "repos/$REPO/contents/config/ota.json?ref=$BRANCH" 2>/dev/null || true)"
if [ -n "$CUR" ]; then
  CUR_SHA="$(echo "$CUR" | jq -r .sha)"
  BACKUP="$STATE/ota.json.before.$BRANCH"
  [ -f "$BACKUP" ] || { echo "$CUR" | jq -r .content | base64 -d > "$BACKUP"; echo "$CUR_SHA" > "$BACKUP.sha"; log "saved previous ota.json to $BACKUP"; }
fi
log "updating config/ota.json on $REPO@$BRANCH"
args=(-X PUT "repos/$REPO/contents/config/ota.json" -f message="OTA test: $TAG ($VARIANT, build date $BUILD_DATE)" -f branch="$BRANCH" -f content="$(base64 < "$OUT" | tr -d '\n')")
[ -n "${CUR_SHA:-}" ] && args+=(-f sha="$CUR_SHA")
gh api "${args[@]}" --jq '.commit.sha' | sed 's/^/commit /'

# 3. verify what the device will see (raw.githubusercontent caches for up to ~5 minutes)
log "verifying"
RAW="https://raw.githubusercontent.com/$REPO/$BRANCH/config/ota.json"
sleep 3
curl -fsSL "$RAW?cb=$RANDOM" | jq -c . | sed 's/^/raw ota.json: /'
code="$(curl -sIL -o /dev/null -w '%{http_code} %{size_download}' "$URL" || true)"
echo "asset $URL -> HTTP $code"
log "published. The Duo reads $RAW (cache up to ~5 min)"
