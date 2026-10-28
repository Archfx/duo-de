#!/bin/bash
# Negative test of the Updater hash verification: republish the already uploaded image with a wrong hash and a
# slightly newer date, then let the Duo try to install it. It must refuse and stay on the current build.
#
#   run-negative-test.sh --image-xz FILE --tag TAG [--corrupt img|xz|none]   (none: reinstall with correct hashes)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
XZ=""; TAG=""; CORRUPT="img"; REPO="mkostersitz/duo-de"; BRANCH="main-16"
while [ $# -gt 0 ]; do
  case "$1" in
    --image-xz) XZ="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    --corrupt) CORRUPT="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -f "$XZ" ] && [ -n "$TAG" ] || { echo "--image-xz and --tag are required" >&2; exit 2; }
log() { echo "$(date +%H:%M:%S) $*"; }

# keep the screen awake for the whole test and restore the setting afterwards
OLD_TIMEOUT="$(adb shell settings get system screen_off_timeout | tr -d '\r')"
trap 'adb shell settings put system screen_off_timeout "$OLD_TIMEOUT" >/dev/null 2>&1; log "screen timeout restored to $OLD_TIMEOUT"' EXIT
adb shell "settings put system screen_off_timeout 1800000; input keyevent KEYCODE_WAKEUP" >/dev/null

DEV_DATE="$(adb shell getprop ro.system.build.date.utc | tr -d '\r')"
NEWER=$(( DEV_DATE + 60 ))
log "installed build date $DEV_DATE, publishing the same image with date $NEWER and a wrong $CORRUPT hash"
if [ "$CORRUPT" = none ]; then
  "$HERE/publish-ota.sh" --image-xz "$XZ" --tag "$TAG" --no-upload --date "$NEWER" || exit 1
else
  "$HERE/publish-ota.sh" --image-xz "$XZ" --tag "$TAG" --no-upload --date "$NEWER" --corrupt-sha256 "$CORRUPT" || exit 1
fi

RAW="https://raw.githubusercontent.com/$REPO/$BRANCH/config/ota.json"
log "waiting for raw.githubusercontent.com to serve the new json (cache up to ~5 minutes)"
WANT_SHA="$(jq -r '.variants[0].sha256' "$HERE/state/ota.json.$TAG")"
for i in $(seq 1 60); do
  j="$(curl -fsSL "$RAW" 2>/dev/null)"
  d="$(echo "$j" | jq -r .date 2>/dev/null)"; h="$(echo "$j" | jq -r '.variants[0].sha256' 2>/dev/null)"
  [ "$d" = "$NEWER" ] && [ "$h" = "$WANT_SHA" ] && break
  sleep 10
done
[ "$d" = "$NEWER" ] && [ "$h" = "$WANT_SHA" ] || { log "the json (date and image hash) did not update in time"; exit 1; }
log "json is live, starting the test"
adb shell "input keyevent KEYCODE_WAKEUP" >/dev/null
if [ "$CORRUPT" = none ]; then
  "$HERE/test-ota.sh" --expect success --installed-date "$DEV_DATE"
else
  "$HERE/test-ota.sh" --expect verify-fail
fi
