#!/usr/bin/env bash
# Stage 40 — with the SD booted and U-Boot running `ums`, the frame's eMMC now
# appears to the host as a plain USB disk. Dump the `boot` partition from it.
#
# Usage:  scripts/40-dump-boot.sh /dev/sdX     (the eMMC exposed over ums)
#         scripts/40-dump-boot.sh --list       (help find which /dev/sdX it is)
. "$(dirname "$0")/lib.sh"

if [ "${1:-}" = "--list" ] || [ -z "${1:-}" ]; then
  say "Block devices (look for a ~16–32 GB disk that just appeared):"
  lsblk -dpo NAME,SIZE,RM,MODEL | sed 's/^/  /'
  echo; say "Re-run:  $0 /dev/sdX"; exit 0
fi

DEV="$1"; [ -b "$DEV" ] || die "$DEV is not a block device"
need sgdisk
say "Partition table on $DEV:"; sgdisk -p "$DEV" | sed 's/^/  /' || die "no GPT — is this the eMMC (ums) disk?"

# Find the partition whose name is 'boot'.
LINE="$(sgdisk -p "$DEV" | awk 'tolower($0) ~ /boot/ && $1 ~ /^[0-9]+$/ {print; exit}')"
[ -n "$LINE" ] || die "could not find a 'boot' partition by name — inspect 'sgdisk -p $DEV' yourself"
PNUM="$(echo "$LINE" | awk '{print $1}')"
START="$(sgdisk -i "$PNUM" "$DEV" | awk '/First sector/{print $3}')"
END="$(sgdisk -i "$PNUM" "$DEV"   | awk '/Last sector/{print $3}')"
COUNT=$((END-START+1))
say "boot = partition $PNUM : start=$START count=$COUNT sectors ($(numfmt --to=iec $((COUNT*512)) 2>/dev/null)B)"

OUT="$DUMP_DIR/boot_orig.img"
dd if="$DEV" skip="$START" count="$COUNT" bs=512 of="$OUT" status=progress
# Keep a pristine copy you will never touch.
cp -n "$OUT" "$DUMP_DIR/boot_orig.img.bak"
printf '%s %s\n' "$PNUM" "$START" > "$DUMP_DIR/boot_partition.txt"   # remembered for stage 60
say "boot magic:"; dd if="$OUT" bs=8 count=1 2>/dev/null | xxd | sed 's/^/  /'
ok "dumped boot → $OUT  (pristine backup: boot_orig.img.bak)"
