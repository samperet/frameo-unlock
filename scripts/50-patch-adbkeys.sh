#!/usr/bin/env bash
# Stage 50 — inject your ADB public key into the boot ramdisk as /adb_keys.
# adbd reads /adb_keys at boot and authorises that host with NO on-screen
# prompt, even when ro.adb.secure=1 (which is why the frame showed no dialog).
. "$(dirname "$0")/lib.sh"

SRC="$DUMP_DIR/boot_orig.img"; [ -f "$SRC" ] || die "boot_orig.img missing — run 40-dump-boot.sh"
MB="$BUILD_DIR/magiskboot"

# Locate (or create) this host's ADB public key.
PUB=""
for p in "$HOME/.android/adbkey.pub" "$HOME/.config/.android/adbkey.pub"; do [ -f "$p" ] && PUB="$p" && break; done
if [ -z "$PUB" ]; then
  need adb; say "no adb key yet — generating one…"
  adb keygen "$HOME/.android/adbkey" >/dev/null 2>&1 || adb start-server >/dev/null 2>&1 || true
  PUB="$HOME/.android/adbkey.pub"
fi
[ -f "$PUB" ] || die "could not find or create an adb public key"
say "using host key: $PUB"
cp "$PUB" "$BUILD_DIR/adb_keys"

cd "$BUILD_DIR"
if [ -x "$MB" ]; then
  say "patching ramdisk with magiskboot…"
  rm -f kernel ramdisk.cpio* second* dtb* header recovery_dtbo extra
  "$MB" unpack "$SRC"
  "$MB" cpio ramdisk.cpio "add 0644 adb_keys $BUILD_DIR/adb_keys" "exists adb_keys"
  "$MB" repack "$SRC" "$DUMP_DIR/boot_patched.img"
  ok "wrote boot_patched.img (magiskboot)"
else
  die "magiskboot not available — see docs/how-it-works.md for the manual cpio/gzip method"
fi

say "verify /adb_keys made it into the ramdisk that was repacked:"
"$MB" cpio ramdisk.cpio "exists adb_keys" >/dev/null 2>&1 \
  && ok "/adb_keys present in ramdisk" || warn "could not confirm — inspect manually before writing"
say "patched image: $DUMP_DIR/boot_patched.img  ($(stat -c%s "$DUMP_DIR/boot_patched.img" 2>/dev/null) bytes)"
