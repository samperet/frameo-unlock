#!/system/bin/sh
. /data/local/kiosk/config.sh
# Ignore presses while the frame is meant to be off (night).
[ "$(cur_slot)" = NIGHT ] && { log "toggle ignored (night)"; exit 0; }
screen_on
m=$(cat "$MODE" 2>/dev/null); [ -z "$m" ] && m=slideshow
if [ "$m" = slideshow ]; then
  echo dashboard > "$MODE"; fw_load "$DASH_ENC";  log "toggle -> dashboard"
else
  echo slideshow > "$MODE"; fw_load "$SLIDE_ENC"; log "toggle -> slideshow"
fi
