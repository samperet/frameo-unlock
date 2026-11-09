#!/system/bin/sh
. /data/local/kiosk/config.sh
log "scheduler start (pid $$)"
rm -f "$LASTSLOT"                 # force content re-apply after a (re)boot
# wait for Fully's REST to answer before first load
i=0; while [ $i -lt 40 ]; do fw_ready && break; i=$((i+1)); sleep 2; done
while :; do
  slot=$(cur_slot); last=$(cat "$LASTSLOT" 2>/dev/null)
  if [ "$slot" != "$last" ]; then
    case "$slot" in
      MORNING) echo dashboard > "$MODE"; screen_on; sleep 1
               j=0; while [ $j -lt 5 ]; do fw_load "$DASH_ENC" && break; j=$((j+1)); sleep 2; done
               log "MORNING -> dashboard" ;;
      DAY)     echo slideshow > "$MODE"; screen_on; sleep 1
               j=0; while [ $j -lt 5 ]; do fw_load "$SLIDE_ENC" && break; j=$((j+1)); sleep 2; done
               log "DAY -> slideshow" ;;
      NIGHT)   screen_off; log "NIGHT -> off" ;;
    esac
    echo "$slot" > "$LASTSLOT"
  else
    case "$slot" in MORNING|DAY) screen_on ;; NIGHT) screen_off ;; esac
  fi
  sleep 20
done
