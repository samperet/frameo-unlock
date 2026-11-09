#!/usr/bin/env bash
# Stage 99 — confirm ADB is authorised with no dialog, and persists.
. "$(dirname "$0")/lib.sh"
need adb
say "waiting for the frame over USB…"
adb wait-for-device
STATE="$(adb get-state 2>/dev/null || echo unknown)"
say "adb state: $STATE"
[ "$STATE" = "device" ] || die "not authorised ($STATE). If it says 'unauthorized', /adb_keys did not take — re-check stage 50/60."
echo
say "device:    $(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
say "android:   $(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')"
say "secure:    ro.adb.secure=$(adb shell getprop ro.adb.secure 2>/dev/null | tr -d '\r')  (dialog-free anyway via /adb_keys)"
say "root?:     $(adb shell 'command -v su >/dev/null 2>&1 && echo yes || echo no' 2>/dev/null | tr -d '\r')"
ok "ADB is open. Reboot test: unplug/replug and re-run — it should stay 'device'."
echo; say "To turn it into a kiosk, see ../kiosk/install-kiosk.sh"
