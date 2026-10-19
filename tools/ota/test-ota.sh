#!/bin/bash
# Drive one OTA on the connected Duo through the Updater app and verify the result.
#
#   test-ota.sh [--expect success|verify-fail] [--timeout MINUTES] [--preflight-only] [--no-reboot]
#               [--installed-date EPOCH]   build date expected after the update when the json date was bumped
#
#   success      (default) the update installs, the device reboots into the new build and keeps its data
#   verify-fail  the published hashes are wrong on purpose: the Updater must refuse (hash mismatch),
#                the running system must stay unchanged
#
# Needs: adb with the Duo attached, python3, curl. Logs go to ota/logs/<run id>/.
# The install itself reboots the device and the current system is replaced on success.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
EXPECT=success; TIMEOUT_MIN=45; PREFLIGHT_ONLY=0; NO_REBOOT=0; INSTALLED_DATE=""
RUN_ID="$(date +%Y%m%d-%H%M%S)"

while [ $# -gt 0 ]; do
  case "$1" in
    --expect) EXPECT="$2"; shift 2 ;;
    --timeout) TIMEOUT_MIN="$2"; shift 2 ;;
    --preflight-only) PREFLIGHT_ONLY=1; shift ;;
    --no-reboot) NO_REBOOT=1; shift ;;
    --installed-date) INSTALLED_DATE="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
case "$EXPECT" in success|verify-fail) ;; *) echo "--expect takes success or verify-fail" >&2; exit 2 ;; esac

LOGDIR="$HERE/logs/$RUN_ID"; mkdir -p "$LOGDIR"
SUMMARY="$LOGDIR/summary.txt"
PASS=0; FAIL=0
say()  { echo "$(date +%H:%M:%S) $*" | tee -a "$SUMMARY"; }
ok()   { PASS=$((PASS+1)); say "PASS  $*"; }
bad()  { FAIL=$((FAIL+1)); say "FAIL  $*"; }
prop() { adb shell getprop "$1" 2>/dev/null | tr -d '\r'; }

wait_boot() {
  adb wait-for-device
  local i
  for i in $(seq 1 120); do
    [ "$(prop sys.boot_completed)" = 1 ] && return 0
    sleep 3
  done
  return 1
}

# tap the node whose resource-id ends with the given id (uiautomator dump + python parsing)
tap_id() {
  adb shell uiautomator dump /sdcard/ota-ui.xml >/dev/null 2>&1 || return 1
  adb pull -q /sdcard/ota-ui.xml "$LOGDIR/ui.xml" 2>/dev/null || return 1
  local xy
  xy="$(python3 -I - "$LOGDIR/ui.xml" "$1" <<'PY'
import re, sys, xml.etree.ElementTree as ET
tree = ET.parse(sys.argv[1])
for n in tree.iter("node"):
    if n.get("resource-id", "").endswith(sys.argv[2]) and n.get("clickable") != "false":
        m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", n.get("bounds", ""))
        if m:
            x1, y1, x2, y2 = map(int, m.groups())
            print((x1 + x2) // 2, (y1 + y2) // 2)
            break
PY
)"
  [ -n "$xy" ] || return 1
  adb shell input tap $xy
}

# ---------------------------------------------------------------- preflight
say "run $RUN_ID, expectation: $EXPECT"
adb get-state >/dev/null 2>&1 || { echo "no adb device" >&2; exit 2; }
BEFORE_DATE="$(prop ro.system.build.date.utc)"
BEFORE_ID="$(prop ro.build.display.id)"
FLAVOR="$(prop ro.build.flavor | sed -E 's/-user(debug)?//')"
URL="$(prop ro.system.ota.json_url)"
say "device build: $BEFORE_ID, date utc $BEFORE_DATE, flavor $FLAVOR"
say "ota.json url: $URL"
[ -n "$URL" ] || { bad "ro.system.ota.json_url is empty"; exit 1; }
curl -fsSL "$URL?cb=$RANDOM" -o "$LOGDIR/ota.json" || { bad "could not fetch $URL"; exit 1; }
JSON_DATE="$(python3 -I -c "import json,sys;print(json.load(open(sys.argv[1]))['date'])" "$LOGDIR/ota.json")"
VERSION="$(python3 -I -c "import json,sys;print(json.load(open(sys.argv[1]))['version'])" "$LOGDIR/ota.json")"
HAS_VARIANT="$(python3 -I -c "import json,sys;print(any(v['name']==sys.argv[2] for v in json.load(open(sys.argv[1]))['variants']))" "$LOGDIR/ota.json" "$FLAVOR")"
HAS_HASH="$(python3 -I -c "import json,sys;print(all(v.get('sha256') and v.get('xz_sha256') for v in json.load(open(sys.argv[1]))['variants'] if v['name']==sys.argv[2]))" "$LOGDIR/ota.json" "$FLAVOR")"
say "published: version $VERSION, date $JSON_DATE, variant for this device: $HAS_VARIANT, carries hashes: $HAS_HASH"
[ "$HAS_VARIANT" = True ] && ok "ota.json lists variant $FLAVOR" || bad "ota.json has no variant $FLAVOR (the Updater matches on the flavor name)"
if [ "$JSON_DATE" \> "$BEFORE_DATE" ]; then ok "json date $JSON_DATE is newer than the installed $BEFORE_DATE: the Updater will offer it"
else bad "json date $JSON_DATE is not newer than the installed $BEFORE_DATE: no update would be offered"; fi
[ "$PREFLIGHT_ONLY" = 1 ] && { say "preflight only: $PASS passed, $FAIL failed"; [ "$FAIL" = 0 ]; exit $?; }
[ "$FAIL" = 0 ] || { say "preflight failed, not starting the update"; exit 1; }

# the Updater is driven through the UI, which needs an unlocked, awake screen
adb shell "settings put global stay_on_while_plugged_in 3; input keyevent KEYCODE_WAKEUP" >/dev/null 2>&1
sleep 1
if adb shell dumpsys window 2>/dev/null | grep -E "mCurrentFocus" | grep -q -E "NotificationShade|Keyguard|Bouncer|null"; then
  bad "the device is locked: unlock it (fingerprint or PIN) and run the test again"
  exit 1
fi

# ---------------------------------------------------------------- marker that must survive the update
adb shell "settings put global ota_test_marker $RUN_ID; echo $RUN_ID > /sdcard/ota-test-marker.txt"
PKGS_BEFORE="$(adb shell pm list packages 2>/dev/null | wc -l | tr -d ' ')"
say "marker written, $PKGS_BEFORE packages installed"

# ---------------------------------------------------------------- run the Updater
adb logcat -c
adb logcat -v time -s PHH:* > "$LOGDIR/phh-logcat.txt" 2>&1 &
LC_PID=$!
trap 'kill $LC_PID 2>/dev/null' EXIT
adb shell am force-stop me.phh.treble.app
adb shell am start -n me.phh.treble.app/.UpdaterActivity >/dev/null 2>&1
say "Updater opened, waiting for the update button"
tapped=0
for i in $(seq 1 30); do
  sleep 2
  if tap_id "id/btn_update"; then tapped=1; break; fi
done
if [ "$tapped" = 0 ]; then bad "no update button appeared (see $LOGDIR/ui.xml and the PHH log)"; adb shell screencap -p /sdcard/ota.png && adb pull -q /sdcard/ota.png "$LOGDIR/no-button.png"; exit 1; fi
say "tapped the update button, waiting up to $TIMEOUT_MIN minutes"
DEADLINE=$(( $(date +%s) + TIMEOUT_MIN * 60 ))
RESULT=timeout
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  if grep -q "OTA image install finished" "$LOGDIR/phh-logcat.txt"; then RESULT=installed; break; fi
  if grep -q "Failed applying OTA image" "$LOGDIR/phh-logcat.txt"; then RESULT=failed; break; fi
  if grep -q "Failed downloading OTA image" "$LOGDIR/phh-logcat.txt"; then RESULT=download-failed; break; fi
  sleep 5
done
say "Updater result: $RESULT"
grep -E "OTA download sha256|OTA image sha256|OTA image verified|no hashes|mismatch|Failed" "$LOGDIR/phh-logcat.txt" | sed 's/^/  /' | tee -a "$SUMMARY"

case "$EXPECT:$RESULT" in
  success:installed) ok "update installed and verified"
     if grep -q "OTA image verified" "$LOGDIR/phh-logcat.txt"; then ok "hashes verified by the Updater"
     elif grep -q "no hashes" "$LOGDIR/phh-logcat.txt"; then say "NOTE  ota.json had no hashes, installed unverified"
     else say "NOTE  the installed Updater predates hash verification"; fi ;;
  verify-fail:failed)
     if grep -q "OtaVerificationException\|hash mismatch" "$LOGDIR/phh-logcat.txt"; then ok "update refused with a hash mismatch"
     else bad "update failed, but not because of verification (see the PHH log)"; fi ;;
  *) bad "expected $EXPECT but the Updater reported $RESULT" ;;
esac

# ---------------------------------------------------------------- reboot and verify
if [ "$NO_REBOOT" = 1 ]; then say "skipping the reboot as requested"; say "$PASS passed, $FAIL failed"; [ "$FAIL" = 0 ]; exit $?; fi
adb shell screencap -p /sdcard/ota-end.png && adb pull -q /sdcard/ota-end.png "$LOGDIR/updater-end.png"
kill $LC_PID 2>/dev/null
say "rebooting"
adb reboot
sleep 20
if wait_boot; then ok "device booted again"; else bad "device did not finish booting within 6 minutes: recover with fastboot (see README)"; say "$PASS passed, $FAIL failed"; exit 1; fi
sleep 15
AFTER_DATE="$(prop ro.system.build.date.utc)"; AFTER_ID="$(prop ro.build.display.id)"
say "after reboot: $AFTER_ID, date utc $AFTER_DATE"
if [ "$EXPECT" = success ]; then
  WANT_DATE="${INSTALLED_DATE:-$JSON_DATE}"
  [ "$AFTER_DATE" = "$WANT_DATE" ] && ok "running the published build (date $AFTER_DATE)" || bad "build date is $AFTER_DATE, expected $WANT_DATE"
else
  [ "$AFTER_DATE" = "$BEFORE_DATE" ] && ok "system unchanged after the refused update" || bad "build date changed to $AFTER_DATE although verification should have failed"
fi
[ "$(adb shell settings get global ota_test_marker 2>/dev/null | tr -d '\r')" = "$RUN_ID" ] && ok "settings marker survived" || bad "settings marker lost"
# /sdcard is credential-encrypted: it is only readable after the first unlock following the reboot
if [ "$(prop sys.user.0.ce_available)" != true ]; then
  say "waiting up to 5 minutes for you to unlock the device (needed to read /sdcard)"
  for i in $(seq 1 60); do [ "$(prop sys.user.0.ce_available)" = true ] && break; sleep 5; done
fi
if [ "$(prop sys.user.0.ce_available)" = true ]; then
  [ "$(adb shell cat /sdcard/ota-test-marker.txt 2>/dev/null | tr -d '\r')" = "$RUN_ID" ] && ok "file marker survived" || bad "file marker lost"
else
  say "NOTE  device still locked, file marker not checked"
fi
PKGS_AFTER="$(adb shell pm list packages 2>/dev/null | wc -l | tr -d ' ')"
[ "$PKGS_AFTER" = "$PKGS_BEFORE" ] && ok "package count unchanged ($PKGS_AFTER)" || say "NOTE  package count $PKGS_BEFORE -> $PKGS_AFTER"
CRASHES="$(adb logcat -b crash -d 2>/dev/null | grep -c 'FATAL EXCEPTION')"
say "crash buffer after boot: $CRASHES fatal entries (the early display-receiver one is known)"
adb logcat -b crash -d > "$LOGDIR/crash-after.txt" 2>&1
say "$PASS passed, $FAIL failed. Logs: $LOGDIR"
[ "$FAIL" = 0 ]
