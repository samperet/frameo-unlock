# Safety — read before you touch anything

This process **rewrites the boot partition and briefly disables the eMMC boot
header** of a device that has **no official recovery image or download tool**.
Mistakes can leave the frame unable to boot.

## The rules

1. **Dump before you write.** Stage 40 keeps `boot_orig.img` *and* a
   `boot_orig.img.bak` you must never overwrite. Stage 20 backs up the 5
   ID-block sectors before zeroing them. If any of these backups are missing,
   **stop** — do not proceed to a write stage.
2. **The ID-block must be restored.** Between stage 20 (zero) and stage 60
   (restore) the frame **cannot boot from eMMC**. That's expected. If you walk
   away, write a note. Losing `idb_sec_*.bin` is the easiest way to brick it.
3. **Confirm every physical step.** Entering maskrom, inserting/removing the SD,
   leaving `ums`, power-cycling — do them deliberately. The scripts pause for
   these; don't set `FRAMEO_YES=1` until you've read them.
4. **Know your target disk.** `/dev/sdX` is different for your SD reader vs. the
   eMMC-over-`ums`. The scripts refuse non-removable or over-size disks and
   refuse the disk backing your root filesystem, but **you** still pass the path
   — check `lsblk` every time. Writing the loader to the wrong disk wipes it.
5. **A boot/eMMC dump is private.** It can contain wifi credentials, tokens and
   personal data. The `.gitignore` blocks `*.img`/`*.bin` — never commit dumps,
   and don't post them in issues.

## What's reversible vs. not

| Action | Reversible? |
|--------|-------------|
| Zero ID-block | Yes — restore from `idb_sec_*.bin` (stage 60) |
| Write patched boot | Yes — re-write `boot_orig.img.bak` over `ums` |
| Writing the SD card | N/A — it's a throwaway SD, not the frame |
| A bad U-Boot / wrong blobs | Usually recoverable via maskrom (eMMC ID-block still intact until stage 20) |

Keep the finished SD card: it re-exposes the eMMC over `ums` any time the frame
misbehaves, which is your recovery path.

## Legality / ethics

This is for **your own device**, for local/offline use (a kiosk you own). It
doesn't circumvent DRM on copyrighted content. Respect the licenses of the
Rockchip blobs and any apps you install.
