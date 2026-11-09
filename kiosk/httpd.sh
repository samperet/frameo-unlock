#!/system/bin/sh
. /data/local/kiosk/config.sh
exec busybox httpd -f -p 127.0.0.1:${HTTP_PORT} -h ${WWW}
