#!/bin/bash
# Helpers for the OTA failure/edge cases (5-12 of the test matrix). Source this file, then call the functions.
#   publish_json DATE [publish-ota.sh args...]  publish a ota.json variant (asset already uploaded) and wait until live
#   updater_screen                              open the Updater, print its title/description/button text
#   start_update                                tap the update button (assumes an update is offered)
#   slot                                        which system is running (system_b or OTA(system_otaphh_x))
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAG="${TAG:-ota-test-matrix}"
XZ="${XZ:-$(ls ~/aosp-images/launcher-reset/*.img.xz)}"
IMG="${IMG:-$(ls ~/aosp-images/launcher-reset/*.img)}"
RAW="https://raw.githubusercontent.com/mkostersitz/duo-de/main-16/config/ota.json"
LOGD="$HERE/logs/cases-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$LOGD"

log() { echo "$(date +%H:%M:%S) $*" | tee -a "$LOGD/summary.txt"; }
prop() { adb shell getprop "$1" 2>/dev/null | tr -d '\r'; }
slot() {
  local src dm
  src="$(adb shell "grep ' / ' /proc/mounts | head -1 | cut -d' ' -f1" 2>/dev/null | tr -d '\r')"
  case "$src" in
    *otaphh*) echo "OTA($(adb shell "ls /dev/block/mapper | grep '^system_otaphh_'" 2>/dev/null | tr -d '\r' | tr '\n' ',' | sed 's/,$//'))" ;;
    *) dm="$src"; adb shell "ls -l /dev/block/mapper | grep ' -> $dm\$' | head -1" 2>/dev/null | tr -d '\r' | awk '{print $(NF-2)}' ;;
  esac
}
wait_boot() { adb wait-for-device; for i in $(seq 1 120); do [ "$(prop sys.boot_completed)" = 1 ] && return 0; sleep 3; done; return 1; }

# publish a JSON variant and wait until raw.githubusercontent serves it (then add a margin for other cache nodes)
publish_json() {
  local date="$1"; shift
  "$HERE/publish-ota.sh" --image-xz "$XZ" --image "$IMG" --tag "$TAG" --no-upload --date "$date" "$@" >"$LOGD/publish-$date.txt" 2>&1 || { log "publish failed, see $LOGD/publish-$date.txt"; return 1; }
  local want; want="$(jq -r '.variants[0].sha256' "$HERE/state/ota.json.$TAG")"
  local d h
  for i in $(seq 1 60); do
    j="$(curl -fsSL "$RAW" 2>/dev/null)"; d="$(echo "$j" | jq -r .date 2>/dev/null)"; h="$(echo "$j" | jq -r '.variants[0].sha256' 2>/dev/null)"
    [ "$d" = "$date" ] && [ "$h" = "$want" ] && break
    sleep 10
  done
  [ "$d" = "$date" ] || { log "json date $date did not become live"; return 1; }
  sleep 120   # margin: the device may be served by a different cache node
  log "json date $date is live"
}

dump_ui() { adb shell uiautomator dump /sdcard/c-ui.xml >/dev/null 2>&1; adb pull -q /sdcard/c-ui.xml "$LOGD/ui.xml" 2>/dev/null; }
close_crash_dialog() {
  dump_ui
  local xy; xy="$(python3 -I - "$LOGD/ui.xml" <<'PY'
import re, sys, xml.etree.ElementTree as ET
nodes = list(ET.parse(sys.argv[1]).iter("node"))
if any("has stopped" in n.get("text", "") or "keeps stopping" in n.get("text", "") for n in nodes):
    for n in nodes:
        if n.get("text", "") == "Close app":
            m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", n.get("bounds", ""))
            if m:
                a, b, c, d = map(int, m.groups()); print((a + c) // 2, (b + d) // 2)
PY
)"
  [ -n "$xy" ] && { log "closing a crash dialog"; adb shell input tap $xy; sleep 1; }
}
updater_screen() {
  adb shell "input keyevent KEYCODE_WAKEUP; am force-stop me.phh.treble.app; am start -n me.phh.treble.app/.UpdaterActivity" >/dev/null 2>&1
  sleep 12; close_crash_dialog; dump_ui
  python3 -I - "$LOGD/ui.xml" <<'PY'
import re, sys, xml.etree.ElementTree as ET
for n in ET.parse(sys.argv[1]).iter("node"):
    r = n.get("resource-id", "")
    if r.endswith(("txt_update_title", "txt_update_description", "btn_update")):
        print(r.split("/")[-1] + ":", n.get("text", "").replace("\n", " | "))
PY
}
start_update() {
  dump_ui
  local xy; xy="$(python3 -I - "$LOGD/ui.xml" <<'PY'
import re, sys, xml.etree.ElementTree as ET
for n in ET.parse(sys.argv[1]).iter("node"):
    if n.get("resource-id", "").endswith("btn_update"):
        m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", n.get("bounds", ""))
        if m:
            a, b, c, d = map(int, m.groups()); print((a + c) // 2, (b + d) // 2); break
PY
)"
  [ -n "$xy" ] && adb shell input tap $xy || { log "no update button"; return 1; }
}
