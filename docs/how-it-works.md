# How it works

The full chain, with the reasoning behind each step. If something goes wrong,
understanding this is what lets you recover instead of guess.

## The RK3326 boot chain

```
BootROM (masked, in SoC)
  └─ ID-block (idbloader): DDR init (TPL) + miniloader/SPL
       └─ U-Boot + trust (BL31/ATF)
            └─ Android boot.img (kernel + ramdisk)
```

The BootROM looks for a valid **ID-block** first on eMMC, then on SD. The
ID-block header is written in **5 copies** at LBA `64, 1088, 2112, 3136, 4160`
(512-byte sectors). The header magic starts with `3b 8c dc fc` on little-endian
dumps.

## Problem 1 — no authorize dialog

The frame ships with `ro.adb.secure=1` but the launcher never surfaces the
"Allow USB debugging?" dialog, so `adb` sits at `unauthorized` forever. `adbd`
also trusts any key listed in **`/adb_keys`** (a file in the boot ramdisk root;
`init.rc` runs `restorecon /adb_keys`). Put your public key there and `adbd`
authorizes you silently. But to edit the ramdisk you must first read the boot
partition…

## Problem 2 — the 32 MB maskrom read cap

In maskrom/loader mode, `rkdeveloptool rl` (read LBA) returns real data only for
roughly the first `0x10000` sectors (32 MB); past that it returns `0xCC` filler.
That's baked into the closed `usbplug` blob — not fixable from the host. The GPT
(LBA 0–33) and the ID-block sectors are *inside* the cap, so you can read/zero
those, but the boot partition usually sits past it.

## The workaround — `ums` from an SD-booted U-Boot

U-Boot's `ums` (USB Mass Storage gadget) exposes an MMC device to the host as a
plain block disk — **no cap**. So we build a U-Boot whose boot command is just:

```
ums 0 mmc 0
```

(`mmc 0` is eMMC in the vendor `rockchip-linux/u-boot` tree.) Boot that and the
host sees the entire eMMC as `/dev/sdX`; now `dd` can read and write any
partition.

### Getting the frame to boot our U-Boot

The frame is **eMMC-first**, and its "Update" test pads force USB **download**
mode (to the host), *not* SD boot. To make the BootROM choose the SD card, we
temporarily **zero the 5 eMMC ID-block sectors** (stage 20). With no valid eMMC
ID-block, the BootROM falls through to the SD card, which carries our loader.
After everything is written we **restore** those 5 sectors (stage 60) so the
frame boots from eMMC normally again. **Keep the backups** — if you lose them the
frame won't boot from eMMC.

### SD card layout

```
sector 0       GPT   (copied from the eMMC — the miniloader needs a partition
                      table present or it can't locate uboot.img)
sector 64      idbloader.img   (DDR blob + miniloader)
sector 0x4000  uboot.img
sector 0x6000  trust.img
```

> Maskrom `db` (download-boot the loader) **hangs if an SD card is in the frame**.
> Pull the SD for any maskrom work; insert it only to boot `ums`.

## Patching the ramdisk

`magiskboot` handles the Android boot image (header v0, gzip cpio ramdisk)
cleanly — it recomputes sizes and the SHA1 id for you:

```bash
magiskboot unpack boot_orig.img
magiskboot cpio ramdisk.cpio "add 0644 adb_keys /path/to/adbkey.pub"
magiskboot repack boot_orig.img boot_patched.img
```

Kernel and second-stage areas are untouched. If you must do it by hand: gunzip
the ramdisk at its offset, append an `adb_keys` entry to the newc cpio, re-gzip,
fix `ramdisk_size` in the header, and recompute the image `id` (SHA1 over
kernel+ramdisk+second and their sizes). `magiskboot` is strongly preferred.

## Root (optional, separate)

Opening ADB does **not** root the frame. If you want `su`, patch the same boot
image with Magisk (`magiskboot` is already here), or remount `/system` and drop
a `su` binary if the device has no verity. The kiosk install uses `su`; a
non-rooted frame can still run ADB-pushed foreground apps but not the on-boot
init service. Rooting specifics vary by unit and are out of scope here.
