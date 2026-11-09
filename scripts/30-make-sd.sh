#!/usr/bin/env bash
# Stage 30 — write the bootable SD card that runs our `ums` U-Boot.
# Layout (sectors, 512 B):  GPT @0 .. idbloader @64 .. uboot.img @0x4000 .. trust.img @0x6000
# The miniloader needs a partition table present or it won't find uboot.img,
# so we copy the eMMC's GPT (captured in stage 20) to the SD.
#
# Usage:  scripts/30-make-sd.sh /dev/sdX
. "$(dirname "$0")/lib.sh"

DEV="${1:-}"; [ -n "$DEV" ] || die "usage: $0 /dev/sdX   (the SD card reader device)"
for f in idbloader.img uboot.img trust.img; do [ -f "$BUILD_DIR/$f" ] || die "$f missing — run 10-build-uboot.sh"; done
GPT="$DUMP_DIR/emmc_gpt.bin"; [ -f "$GPT" ] || die "emmc_gpt.bin missing — run 20-maskrom-idb.sh"

assert_removable "$DEV"
warn "This ERASES the first ~32 MB of $DEV and writes a boot loader to it."
confirm_typed "WIPE AND WRITE SD $DEV" "write sd"

say "clearing first 32 MB…"
dd if=/dev/zero of="$DEV" bs=1M count=32 conv=fsync status=none
say "GPT @ sector 0";       dd if="$GPT"               of="$DEV" bs=512 conv=notrunc,fsync status=none
say "idbloader @ 64";       dd if="$BUILD_DIR/idbloader.img" of="$DEV" seek=64    bs=512 conv=notrunc,fsync status=none
say "uboot.img @ 0x4000";   dd if="$BUILD_DIR/uboot.img"     of="$DEV" seek=16384 bs=512 conv=notrunc,fsync status=none
say "trust.img @ 0x6000";   dd if="$BUILD_DIR/trust.img"     of="$DEV" seek=24576 bs=512 conv=notrunc,fsync status=none
sync
ok "SD written. Insert it in the frame, power on, and run 40-dump-boot.sh."
