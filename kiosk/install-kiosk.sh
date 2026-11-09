#!/usr/bin/env bash
# Install the kiosk + slideshow onto an already-unlocked, rooted frame over ADB.
# Run from your HOST (not the frame). Requires: adb authorised, su on device.
#
#   cp config.sh.example config.sh   # then edit it
#   ./install-kiosk.sh "https://photos.app.goo.gl/XXXX"   # album is optional
set -euo pipefail
cd "$(dirname "$0")"
ALBUM="${1:-}"
[ -f config.sh ] || { echo "copy config.sh.example to config.sh and edit it first"; exit 1; }
command -v adb >/dev/null || { echo "adb not found"; exit 1; }
adb get-state >/dev/null 2>&1 || { echo "frame not connected/authorised over adb"; exit 1; }

# 1) build the slideshow page from your album (if given)
if [ -n "$ALBUM" ]; then
  echo "==> generating slideshow from album"
  python3 gen_slideshow.py "$ALBUM" www/slideshow.html
else
  [ -f www/slideshow.html ] || cp www/slideshow.tpl www/slideshow.html
  echo "==> no album passed; using existing www/slideshow.html"
fi

# 2) push everything to /data/local/kiosk
echo "==> pushing files"
adb shell 'su -c "mkdir -p /data/local/kiosk/www"'
for f in config.sh scheduler.sh toggle.sh touchd.sh httpd.sh; do
  adb push "$f" "/data/local/kiosk/$f" >/dev/null
done
adb push www/slideshow.html /data/local/kiosk/www/slideshow.html >/dev/null
adb shell 'su -c "chmod 755 /data/local/kiosk/*.sh"'

# 3) install the init service that starts the three daemons on boot
echo "==> installing init service (remounts /system rw)"
adb push kiosk-cron.rc /data/local/tmp/kiosk-cron.rc >/dev/null
adb shell 'su -c "mount -o rw,remount /system 2>/dev/null; mount -o rw,remount / 2>/dev/null; \
  cp /data/local/tmp/kiosk-cron.rc /system/etc/init/kiosk-cron.rc; \
  chmod 644 /system/etc/init/kiosk-cron.rc; chcon u:object_r:system_file:s0 /system/etc/init/kiosk-cron.rc 2>/dev/null; \
  mount -o ro,remount /system 2>/dev/null"'

# 4) start the services now (so you do not have to reboot to see it)
echo "==> starting services"
adb shell 'su -c "setenforce 0 2>/dev/null; \
  nohup /system/bin/sh /data/local/kiosk/httpd.sh   >/dev/null 2>&1 & \
  nohup /system/bin/sh /data/local/kiosk/scheduler.sh >/dev/null 2>&1 & \
  nohup /system/bin/sh /data/local/kiosk/touchd.sh  >/dev/null 2>&1 &"'

echo "==> done."
echo "    Long-press the screen (~1.5s) to toggle dashboard <-> slideshow."
echo "    Re-run after adding photos:  python3 gen_slideshow.py \"\$ALBUM\" www/slideshow.html && adb push www/slideshow.html /data/local/kiosk/www/"
