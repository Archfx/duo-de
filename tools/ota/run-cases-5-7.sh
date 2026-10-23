#!/bin/bash
# OTA matrix cases 5 (up to date), 6 (wrong variant), 7 (truncated image)
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/ota-cases.sh"
INSTALLED="$(prop ro.system.build.date.utc)"
log "device date $INSTALLED, running system: $(slot)"

log "=== case 5: json date equals the installed build date"
publish_json "$INSTALLED" || exit 1
updater_screen | tee -a "$LOGD/summary.txt"
sleep 90
log "second look 90 s later (no loop expected):"
updater_screen | tee -a "$LOGD/summary.txt"

log "=== case 6: json has only another variant (treble_arm64_bvN), newer date"
publish_json $((INSTALLED+240)) --variant treble_arm64_bvN || exit 1
updater_screen | tee -a "$LOGD/summary.txt"

log "=== case 7: truncated .xz (matching its own hash), newer date"
cp /tmp/otatest/aosp-arm64-ab-gapps-16.0-20261020-truncated.img.xz /tmp/otatest/t.xz
"$HERE/publish-ota.sh" --image-xz /tmp/otatest/aosp-arm64-ab-gapps-16.0-20261020-truncated.img.xz --image "$IMG" --tag "$TAG" --date $((INSTALLED+300)) > "$LOGD/publish-trunc.txt" 2>&1 || { log "publish of the truncated asset failed"; tail -3 "$LOGD/publish-trunc.txt"; exit 1; }
want="$(jq -r '.variants[0].xz_sha256' "$HERE/state/ota.json.$TAG")"
for i in $(seq 1 60); do j="$(curl -fsSL "$RAW" 2>/dev/null)"; [ "$(echo "$j" | jq -r '.variants[0].xz_sha256')" = "$want" ] && break; sleep 10; done
sleep 120
log "truncated json live, running the update (expecting a failure)"
"$HERE/test-ota.sh" --expect fail --timeout 15 2>&1 | grep -v "^  10-2" | tee -a "$LOGD/summary.txt" | grep -E "PASS|FAIL|Updater result|after reboot|passed|Logs:"
log "cases 5-7 done; summary in $LOGD/summary.txt"
