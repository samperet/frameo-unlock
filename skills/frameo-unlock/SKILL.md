---
name: frameo-unlock
description: >
  Open dialog-free ADB on an RK3326 Frameo digital photo frame (ADB stuck at
  "unauthorized" with no on-screen authorize prompt), then optionally set it up
  as a kiosk with a web dashboard + Google Photos slideshow. Use when the user
  wants to hack / unlock / root / get ADB on a Frameo or similar RK3326 Android
  photo frame, or make one into a wall display. Drives the scripts in this repo
  and pauses for every physical step. Linux host with USB access required.
---

# Frameo unlock — operator guide for Claude

You are driving a **hardware** procedure that rewrites a frame's boot partition.
There is no official recovery. Move deliberately, confirm every physical action
with the user, and never skip a backup. The human is at the machine with the
frame on USB.

## Ground rules

1. **Read [`docs/safety.md`](../../docs/safety.md) and
   [`docs/how-it-works.md`](../../docs/how-it-works.md) before starting**, and keep
   the safety rules in mind the whole way.
2. **Never set `FRAMEO_YES=1`.** Let each script's typed confirmation reach the
   user; relay what it's about to do in plain language first.
3. **One physical step at a time.** Before maskrom entry, SD insert/remove,
   leaving `ums`, or power-cycling, stop and tell the user exactly what to do,
   then wait for them to confirm it's done.
4. **Verify backups exist before any write.** `dumps/boot_orig.img.bak` and
   `dumps/idb_sec_*.bin` must be present before stages 50/60. If missing, stop.
5. Run long host commands normally; the frame-side work is short. Report the
   real output of each stage; if a stage fails, diagnose with
   [`docs/troubleshooting.md`](../../docs/troubleshooting.md) before moving on.

## Flow

Confirm the host is Linux with `adb`, `lsusb`, a free USB port, and a spare
SD card + reader. Then:

| Step | Command | You must first tell the user to… |
|------|---------|----------------------------------|
| 0 | `scripts/00-prereqs.sh` | expect a sudo prompt |
| 1 | `scripts/10-build-uboot.sh` | — (pure build; a few minutes) |
| 2 | `scripts/20-maskrom-idb.sh` | **put the frame in maskrom, SD removed**, USB-A→C cable. Verify `rkdeveloptool ld` lists it. This zeroes the eMMC ID-block — explain it won't boot from eMMC until step 6, and backups are kept |
| 3 | `scripts/30-make-sd.sh /dev/sdX` | insert the SD **in the host reader**; confirm `/dev/sdX` via `lsblk` (NOT the frame's eMMC, NOT the root disk) |
| 4 | `scripts/40-dump-boot.sh /dev/sdX` | move the SD **into the frame**, power on; U-Boot runs `ums`; the eMMC appears as a new `/dev/sdX` on the host (use `--list`) |
| 5 | `scripts/50-patch-adbkeys.sh` | — (injects this host's `/adb_keys`) |
| 6 | `scripts/60-write-restore.sh /dev/sdX` | same `ums` disk as step 4; writes patched boot + restores the ID-block |
| 7 | leave `ums`, remove SD, power-cycle | then `scripts/99-verify-adb.sh` |

After step 7, `adb` should be `device` with no dialog, and survive a replug.

## Picking the right `/dev/sdX` (critical)

There are two different disks and getting them wrong is how people wipe things:
- **Step 3** target = the **SD card in the host reader** (small, removable).
- **Steps 4 & 6** target = the **eMMC exposed over `ums`** (~16–32 GB, appears
  only after the SD boots in the frame).
Always run `lsblk -dpo NAME,SIZE,RM,MODEL` and have the user confirm the size
matches before you pass a path. The scripts refuse non-removable/over-size/root
disks, but you still choose the path.

## If it goes wrong

The finished SD is the recovery tool — booting it restores `ums`, from which you
can re-write `dumps/boot_orig.img.bak` and the `idb_sec_*.bin` sectors. As long
as maskrom still enumerates (`2207:` on `lsusb`), the frame is recoverable. Walk
the user through [`docs/troubleshooting.md`](../../docs/troubleshooting.md).

## Optional: kiosk

If the user wants the wall-display setup, switch to
[`../../kiosk/README.md`](../../kiosk/README.md): help them fill `config.sh`
(dashboard URL + URL-encoded form, Fully password, schedule), install Fully Kiosk
with Remote Administration enabled, then run `kiosk/install-kiosk.sh` with their
public Google Photos album link. The result: dashboard on a schedule, slideshow
the rest of the day, long-press to toggle, screen off overnight — all on-device.
