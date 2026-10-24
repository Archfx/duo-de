#!/bin/bash
# case 12, part A: wait for the broken json, install the broken OTA, do NOT reboot
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/ota-cases.sh"
WANT_DATE=1792519839
log "device running: $(slot), build $(prop ro.system.build.date.utc)"
for i in $(seq 1 90); do d="$(curl -fsSL "$RAW" 2>/dev/null | jq -r .date 2>/dev/null)"; [ "$d" = "$WANT_DATE" ] && break; sleep 10; done
[ "$d" = "$WANT_DATE" ] || { log "broken json did not become live"; exit 1; }
sleep 150
log "broken json live; markers + install (no reboot)"
adb shell 'settings put global ota_test_marker case12-before; echo case12-before > /sdcard/ota-test-marker.txt'
"$HERE/test-ota.sh" --no-reboot --timeout 30 --installed-date 1792519139 2>&1 | grep -v "^  10-2" | grep -E "PASS|FAIL|Updater result|installed|verified|skipping" 
log "install step finished; the Duo is still running the old system: $(slot)"
