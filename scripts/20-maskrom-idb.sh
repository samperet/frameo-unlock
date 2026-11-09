#!/usr/bin/env bash
# Stage 20 — in maskrom: read the eMMC GPT, back up the 5 ID-block sectors,
# then ZERO them so the BootROM will fall through to our SD card.
#
# You must put the frame into maskrom/loader mode first (see docs: usually the
# two "Update" test pads, or hold the hidden button, while plugging USB).
# REMOVE any SD card from the frame for maskrom work — `db` hangs otherwise.
. "$(dirname "$0")/lib.sh"

RKDEV="$BUILD_DIR/rkdeveloptool/rkdeveloptool"; RKBIN="$BUILD_DIR/rkbin"
[ -x "$RKDEV" ] || die "rkdeveloptool missing — run 00-prereqs.sh"

# Build an RK3326 loader for db if we don't have one.
LOADER="$(ls -1 "$BUILD_DIR"/rk3326_loader_*.bin 2>/dev/null | tail -1 || true)"
if [ -z "${LOADER:-}" ]; then
  say "building RK3326 loader with boot_merger…"
  ( cd "$RKBIN" && ./tools/boot_merger RKBOOT/RK3326MINIALL.ini )
  LOADER="$(ls -1 "$RKBIN"/rk3326_loader_*.bin | tail -1)"; cp "$LOADER" "$BUILD_DIR"/
  LOADER="$(ls -1 "$BUILD_DIR"/rk3326_loader_*.bin | tail -1)"
fi
say "loader: $(basename "$LOADER")"

say "Looking for a device in maskrom/loader mode…"
"$RKDEV" ld || true
confirm "Is the frame in maskrom mode, SD card REMOVED, and listed above?"

say "Downloading loader to SRAM (db)…"
"$RKDEV" db "$LOADER"; sleep 2

say "Reading GPT (LBA 0..33) → emmc_gpt.bin"
"$RKDEV" rl 0 34 "$DUMP_DIR/emmc_gpt.bin"
grep -qa 'EFI PART' <(dd if="$DUMP_DIR/emmc_gpt.bin" bs=512 skip=1 count=1 2>/dev/null) \
  && ok "valid GPT captured" || warn "no GPT magic — this unit may use a different layout"

say "Backing up the 5 ID-block header sectors…"
for s in $IDB_SECTORS; do "$RKDEV" rl "$s" 1 "$DUMP_DIR/idb_sec_${s}.bin"; done
head -c4 "$DUMP_DIR/idb_sec_64.bin" | xxd | sed 's/^/  sec64: /'

warn "NEXT STEP ZEROES THE eMMC BOOT HEADER. The frame will not boot from eMMC"
warn "until stage 60 restores these sectors. Your backups are in: $DUMP_DIR"
confirm_typed "ZERO eMMC ID-BLOCK (5 sectors)" "zero idb"

dd if=/dev/zero of="$BUILD_DIR/zero1.bin" bs=512 count=1 status=none
for s in $IDB_SECTORS; do say "zero sector $s"; "$RKDEV" wl "$s" "$BUILD_DIR/zero1.bin"; done
ok "ID-block zeroed. Backups kept. Now build the SD (stage 30) and boot it."
