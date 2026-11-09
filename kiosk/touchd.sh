#!/system/bin/sh
. /data/local/kiosk/config.sh
# locate the touchscreen event node (gsl_thzy); fall back to event1
EV=$(awk '/Name=.*[Gg][Ss][Ll]/{f=1} f&&/Handlers=/{if(match($0,/event[0-9]+/)){print "/dev/input/"substr($0,RSTART,RLENGTH);exit}}' /proc/bus/input/devices)
[ -z "$EV" ] && EV=/dev/input/event1
log "touchd on $EV"
# long-press (>=1.2s) anywhere = toggle; 3s cooldown between toggles
while :; do
  getevent -lt "$EV" 2>/dev/null | awk '
    function ts(){ s=$0; sub(/^\[[ ]*/,"",s); return s+0 }
    /BTN_TOUCH/ && /DOWN/ { down=ts() }
    /BTN_TOUCH/ && /UP/ {
      if(down>0){ d=ts()-down;
        if(d>=1.2 && d<=12){ t=ts(); if(t-cd>3){ cd=t; system("/system/bin/sh /data/local/kiosk/toggle.sh >/dev/null 2>&1 &") } }
        down=0 }
    }'
  sleep 2          # if getevent dies, restart it
done
