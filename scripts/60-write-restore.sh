#!/usr/bin/env bash
# Stage 60 — the finish line. Over the SAME ums connection (eMMC = /dev/sdX),
# write the patched boot image back, then restore the 5 ID-block sectors so the
# frame boots from eMMC again. After this: power-cycle and you have rootless,
# dialog-free ADB. (Root, if you want it, is a separate step — see the docs.)
#
# Usage:  scripts/60-write-restore.sh /dev/sdX
. "$(dirname "$0")/lib.sh"

DEV="${1:-}"; [ -b "${DEV:-}" ] || die "usage: $0 /dev/sdX  (the eMMC exposed over ums)"
PATCHED="$DUMP_DIR/boot_patched.img"; [ -f "$PATCHED" ] || die "boot_patched.img missing — run 50-patch-adbkeys.sh"
[ -f "$DUMP_DIR/boot_partition.txt" ] || die "boot_partition.txt missing — run 40-dump-boot.sh first"
read -r PNUM START < "$DUMP_DIR/boot_partition.txt"
for s in $IDB_SECTORS; do [ -f "$DUMP_DIR/idb_sec_${s}.bin" ] || die "missing IDB backup idb_sec_${s}.bin"; done

# Sanity: this really is the eMMC (GPT present) and the boot partition matches.
need sgdisk
dd if="$DEV" bs=512 skip=1 count=1 2>/dev/null | grep -qa 'EFI PART' || die "$DEV has no GPT — refusing"
CURSTART="$(sgdisk -i "$PNUM" "$DEV" | awk '/First sector/{print $3}')"
[ "$CURSTART" = "$START" ] || die "partition $PNUM start moved ($CURSTART != $START) — wrong disk? refusing"

say "about to write patched boot to partition $PNUM (start $START) and restore IDB on $DEV"
confirm_typed "WRITE PATCHED BOOT + RESTORE IDB on $DEV" "write boot"

# extra snapshot right before writing
dd if="$DEV" skip="$START" count=$(( $(stat -c%s "$PATCHED") / 512 + 1 )) bs=512 of="$DUMP_DIR/boot_before_write.img" status=none || true

say "writing patched boot…"
dd if="$PATCHED" of="$DEV" seek="$START" bs=512 conv=notrunc,fsync status=progress

say "restoring ID-block sectors…"
for s in $IDB_SECTORS; do dd if="$DUMP_DIR/idb_sec_${s}.bin" of="$DEV" seek="$s" bs=512 conv=notrunc,fsync status=none; echo "  restored $s"; done
sync
say "ID-block check (sector 64 should NOT be zero):"; dd if="$DEV" bs=512 skip=64 count=1 2>/dev/null | head -c4 | xxd | sed 's/^/  /'
ok "done. In U-Boot press Ctrl-C / reset to leave ums, remove the SD, power-cycle the frame."
echo;  say "then:  scripts/99-verify-adb.sh"
