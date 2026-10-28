#!/bin/bash
# OTA matrix case 8 (network cut mid-download) and case 9 (Delete OTA files)
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/ota-cases.sh"
INSTALLED="$(prop ro.system.build.date.utc)"
log "device date $INSTALLED, running system: $(slot)"

log "=== case 8: cut Wi-Fi and mobile data during the download"
publish_json $((INSTALLED+500)) || exit 1
updater_screen | tee -a "$LOGD/summary.txt"
adb logcat -c; adb logcat -v time -s PHH:* > "$LOGD/case8-phh.txt" 2>&1 &
LC=$!
start_update || { kill $LC; exit 1; }
sleep 14
log "cutting the network now"
adb shell "svc wifi disable; svc data disable"
sleep 30
log "30 s after the cut: slots = $(slot)"
adb exec-out screencap -p > "$LOGD/case8-after-cut.png"
dump_ui; python3 -I - "$LOGD/ui.xml" <<'PY' | tee -a "$LOGD/summary.txt"
import sys, xml.etree.ElementTree as ET
for n in ET.parse(sys.argv[1]).iter("node"):
    t = n.get("text", "")
    if t: print("  ui:", t.replace("\n", " | ")[:140])
PY
grep -E "Failed|Exception|error|download|progress|Downloaded" "$LOGD/case8-phh.txt" | tail -8 | cut -c1-170 | tee -a "$LOGD/summary.txt"
adb shell "svc wifi enable; svc data enable"
sleep 25
kill $LC 2>/dev/null
log "network restored; running system: $(slot)"
log "rebooting to check that nothing half-installed remains"
adb reboot; sleep 25; wait_boot; sleep 25
log "after reboot: running system: $(slot), build date $(prop ro.system.build.date.utc)"

log "=== case 9: Delete OTA files from the Updater menu"
log "before: $(slot)"
adb shell "input keyevent KEYCODE_WAKEUP; am force-stop me.phh.treble.app; am start -n me.phh.treble.app/.UpdaterActivity" >/dev/null 2>&1
sleep 10; close_crash_dialog
adb shell input tap 2694 119; sleep 2
adb shell input tap 2580 118; sleep 4
adb exec-out screencap -p > "$LOGD/case9-after-delete.png"
dump_ui; python3 -I - "$LOGD/ui.xml" <<'PY' | tee -a "$LOGD/summary.txt"
import sys, xml.etree.ElementTree as ET
for n in ET.parse(sys.argv[1]).iter("node"):
    t = n.get("text", "")
    if t: print("  ui:", t.replace("\n", " | ")[:140])
PY
log "slots right after Delete OTA files: $(slot)"
log "rebooting"
adb reboot; sleep 25; wait_boot; sleep 25
log "after reboot: running system: $(slot), build date $(prop ro.system.build.date.utc)"
log "cases 8-9 done; summary in $LOGD/summary.txt"
