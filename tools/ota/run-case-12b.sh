#!/bin/bash
# case 12, part B: reboot into the broken OTA slot and watch what the device does for up to 8 minutes
HERE="$(cd "$(dirname "$0")" && pwd)"
LOG="$HERE/logs/case12-$(date +%Y%m%d-%H%M%S).txt"
say() { echo "$(date +%H:%M:%S) $*" | tee -a "$LOG"; }
say "rebooting into the broken OTA slot"
adb reboot
last=""; booted=0
for i in $(seq 1 96); do
  a="$(adb devices 2>/dev/null | awk 'NR>1 && $2!=""{print $2}' | head -1)"
  f="$(fastboot devices 2>/dev/null | awk '{print "fastboot"}' | head -1)"
  state="adb=${a:-none} fastboot=${f:-none}"
  if [ "$a" = device ]; then
    bc="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    state="$state boot_completed=${bc:-?}"
    [ "$bc" = 1 ] && booted=1
  fi
  [ "$state" != "$last" ] && say "$state"
  last="$state"
  [ "$f" = fastboot ] && break
  [ "$booted" = 1 ] && break
  sleep 5
done
say "monitor ended: $last"
