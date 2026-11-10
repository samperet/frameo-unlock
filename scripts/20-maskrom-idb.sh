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

# Never overwrite an existing backup: after zeroing, a re-run would "back up"
# the zeros over the only good copy — the easiest way to brick the frame.
if ls "$DUMP_DIR"/idb_sec_*.bin >/dev/null 2>&1; then
  die "ID-block backups already exist in $DUMP_DIR — refusing to overwrite them.
       If stage 20 already zeroed the eMMC, go on to stage 30. If these files
       belong to a DIFFERENT frame, move them somewhere safe first."
fi

say "Backing up the 5 ID-block header sectors…"
for s in $IDB_SECTORS; do "$RKDEV" rl "$s" 1 "$DUMP_DIR/idb_sec_${s}.bin"; done
head -c4 "$DUMP_DIR/idb_sec_64.bin" | xxd | sed 's/^/  sec64: /'

# Validate before anything destructive: every copy must carry the RK ID-block
# magic and all 5 must be identical. Then re-read once and compare, to rule out
# a flaky USB read.
for s in $IDB_SECTORS; do
  f="$DUMP_DIR/idb_sec_${s}.bin"
  [ "$(stat -c%s "$f")" = 512 ] || die "sector $s backup is not 512 bytes — not zeroing"
  [ "$(head -c4 "$f" | xxd -p)" = "3b8cdcfc" ] \
    || die "sector $s has no ID-block magic (3b8cdcfc) — read is bad or layout differs; not zeroing"
  cmp -s "$f" "$DUMP_DIR/idb_sec_64.bin" || die "sector $s differs from sector 64 — not zeroing"
  "$RKDEV" rl "$s" 1 "$BUILD_DIR/idb_verify.bin"
  cmp -s "$f" "$BUILD_DIR/idb_verify.bin" || die "sector $s re-read mismatch — flaky USB? not zeroing"
done
cp "$DUMP_DIR/idb_sec_64.bin" "$DUMP_DIR/idb_sec_64.bin.bak"
ok "all 5 ID-block copies valid, identical and re-read cleanly (extra copy: idb_sec_64.bin.bak)"

warn "NEXT STEP ZEROES THE eMMC BOOT HEADER. The frame will not boot from eMMC"
warn "until stage 60 restores these sectors. Your backups are in: $DUMP_DIR"
confirm_typed "ZERO eMMC ID-BLOCK (5 sectors)" "zero idb"

dd if=/dev/zero of="$BUILD_DIR/zero1.bin" bs=512 count=1 status=none
for s in $IDB_SECTORS; do say "zero sector $s"; "$RKDEV" wl "$s" "$BUILD_DIR/zero1.bin"; done
ok "ID-block zeroed. Backups kept. Now build the SD (stage 30) and boot it."
