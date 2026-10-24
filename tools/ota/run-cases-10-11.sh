#!/bin/bash
# OTA matrix case 10 (low storage) and case 11 (process kill and reboot during the install)
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/ota-cases.sh"
cleanup() { adb shell "rm -f /data/local/tmp/fill.bin" >/dev/null 2>&1; }
trap cleanup EXIT
INSTALLED="$(prop ro.system.build.date.utc)"
log "device date $INSTALLED, running system: $(slot)"

log "=== case 10: low storage"
updater_screen | tee -a "$LOGD/summary.txt"
FREE_KB="$(adb shell "df -k /data | tail -1" | tr -d '\r' | awk '{print $4}')"
FILL_KB=$(( FREE_KB - 1500000 ))
log "free ${FREE_KB} KB, filling ${FILL_KB} KB to leave about 1.5 GB (the OTA slot needs 4 GB)"
adb shell "fallocate -l ${FILL_KB}K /data/local/tmp/fill.bin" 2>&1 | tail -1
log "free now: $(adb shell "df -h /data | tail -1" | tr -d '\r' | awk '{print $4}')"
adb logcat -c; adb logcat -v time -s PHH:* > "$LOGD/case10-phh.txt" 2>&1 &
LC=$!
start_update || { kill $LC; exit 1; }
sleep 60
adb exec-out screencap -p > "$LOGD/case10-screen.png"
dump_ui; python3 -I - "$LOGD/ui.xml" <<'PY' | tee -a "$LOGD/summary.txt"
import sys, xml.etree.ElementTree as ET
for n in ET.parse(sys.argv[1]).iter("node"):
    t = n.get("text", "")
    if t: print("  ui:", t.replace("\n", " | ")[:150])
PY
grep -E "Failed|Exception|rror|space|ENOSPC|new-slot|slot" "$LOGD/case10-phh.txt" | tail -8 | cut -c1-190 | tee -a "$LOGD/summary.txt"
kill $LC 2>/dev/null
adb shell "rm -f /data/local/tmp/fill.bin"
log "freed the space: $(adb shell "df -h /data | tail -1" | tr -d '\r' | awk '{print $4}') free; slots: $(slot)"
adb reboot; sleep 25; wait_boot; sleep 25
log "after reboot: $(slot), build date $(prop ro.system.build.date.utc)"

log "=== case 11a: kill the Updater process in the middle of the install"
updater_screen | tee -a "$LOGD/summary.txt"
start_update || exit 1
sleep 25
log "killing me.phh.treble.app mid-install; slots before: $(slot)"
adb shell "am force-stop me.phh.treble.app"
sleep 20
log "after the kill: slots $(slot)"
adb reboot; sleep 25; wait_boot; sleep 25
log "after reboot: $(slot), build date $(prop ro.system.build.date.utc)"

log "=== case 11b: reboot the device in the middle of the install"
updater_screen | tee -a "$LOGD/summary.txt"
start_update || exit 1
sleep 40
log "rebooting mid-install; slots before: $(slot)"
adb reboot; sleep 25; wait_boot; sleep 30
log "after the interrupted install: $(slot), build date $(prop ro.system.build.date.utc)"
adb reboot; sleep 25; wait_boot; sleep 25
log "after one more reboot: $(slot)"
log "cases 10-11 done; summary in $LOGD/summary.txt"
