# frameo-unlock

Open, dialog-free **ADB** on RK3326-based **Frameo** digital photo frames — and
turn one into a proper wall kiosk (web dashboard + Google Photos slideshow with
a tap-to-toggle). A scrubbed, reusable toolkit built from a unit that had ADB
stuck at *"unauthorized"* with **no on-screen authorize dialog**.

> ⚠️ **This rewrites the boot partition of a device with no official recovery.**
> Read [`docs/safety.md`](docs/safety.md) first. You can brick your frame. You
> do this at your own risk. Back up everything the scripts tell you to.

---

## ELI5 — what is this, and what do I need?

A Frameo frame is a tiny, **locked** Android computer. "Unlocking" it just means
getting it to trust *your* computer, so you can make it show whatever you want
(a dashboard, your own photo slideshow) instead of only the Frameo app.

You need three things:

1. **A Linux computer** with a USB port (a laptop/PC running Linux — or a Linux
   VM). This does all the work and talks to the frame over a USB cable.
2. **A spare SD card** (and a card reader if your computer has no slot). We turn
   it into a temporary "rescue boot disk" that tricks the frame into letting us
   in. Keep it afterward — it's also your undo/recovery disk.
3. **Access to the frame's hidden "Update" button.** There is **no button on the
   outside.** You have to **open the frame** — pop/pry off the back cover — and
   reach two little metal contacts ("solder pads") on the circuit board. You
   **touch them together while plugging in USB**, and that's what puts the frame
   into the special mode we need. (On some other frame models this is a recessed
   button instead, but on the tested DPF156 you must open it.)

Then you plug the frame into the Linux computer and run the steps — or just point
[Claude Code](skills/frameo-unlock/SKILL.md) at this repo and let it walk you
through each one. At the end the frame permanently trusts your computer, and you
**never have to open it again.**

**Is it risky?** A little. You're rewriting the part that makes the frame turn
on, and the maker gives no official "undo." Follow [`docs/safety.md`](docs/safety.md),
keep every backup the scripts make, and keep that SD card. If something goes
wrong, the SD card gets you back in.

---

## Why this is hard (and how it's solved)

A locked Frameo gives you two dead ends:

1. **`adb` says `unauthorized` but shows no dialog**, so you can never approve
   your key the normal way.
2. **Maskrom USB "download" mode caps block reads at 32 MB**, so you can't even
   dump the boot image to patch it offline.

The way through:

| Stage | What happens |
|------|---------------|
| Build a tiny **U-Boot** for RK3326 whose boot command is `ums 0 mmc 0` | lets the frame expose its **whole eMMC** as a USB disk, with no 32 MB cap |
| **Zero the eMMC ID-block** (5 sectors) in maskrom | forces the BootROM to fall through and boot our **SD card** instead |
| Boot the SD → `ums` → dump the **boot** partition | now readable in full |
| Inject your ADB public key as **`/adb_keys`** in the boot ramdisk | `adbd` authorizes your host with **no dialog**, even with `ro.adb.secure=1` |
| Write the patched boot back + **restore the ID-block** over the same `ums` | frame boots from eMMC again, ADB open and persistent |

Full explanation with the *why* behind each step: [`docs/how-it-works.md`](docs/how-it-works.md).

---

## Two ways to run it

### A. Let Claude drive it (recommended)
This repo ships a **Claude Code skill** that walks the whole process
interactively, runs each stage, and stops to confirm every physical step (loader
mode, SD swap, power-cycle). See [`skills/frameo-unlock/`](skills/frameo-unlock/SKILL.md).
Run `claude` from inside this repo and say *"unlock my Frameo."* — the skill is
auto-loaded via `.claude/skills/frameo-unlock` (a symlink to `skills/frameo-unlock`).
To make it available from any directory instead:
`cp -r skills/frameo-unlock ~/.claude/skills/`.

### B. Run the stages yourself
```bash
scripts/00-prereqs.sh                 # host deps + Rockchip toolchain
scripts/10-build-uboot.sh             # U-Boot with `ums 0 mmc 0`
scripts/20-maskrom-idb.sh             # (frame in maskrom) read GPT, back up + zero ID-block
scripts/30-make-sd.sh   /dev/sdX      # write the boot SD (SD reader)
scripts/40-dump-boot.sh /dev/sdX      # (SD booted) dump boot over ums
scripts/50-patch-adbkeys.sh           # inject /adb_keys
scripts/60-write-restore.sh /dev/sdX  # write patched boot + restore ID-block
scripts/99-verify-adb.sh              # confirm ADB is open and persists
```
Every destructive step requires a typed confirmation and refuses to touch a
non-removable or over-size disk unless you override. Set `FRAMEO_YES=1` only
once you've read the script.

---

## After unlock: the kiosk (optional)

[`kiosk/`](kiosk/README.md) turns the frame into a standalone wall display:

- **Fully Kiosk Browser** shows a web page fullscreen.
- A **Google Photos slideshow** generated from any public shared album
  (`gen_slideshow.py`) — no login, no cloud service, served off the frame itself.
- A daily schedule (e.g. dashboard 6–8 am, photos the rest of the day, screen
  off overnight) run **on-device** — no computer attached at runtime.
- **Long-press the screen** to toggle dashboard ⇄ slideshow.

```bash
cd kiosk
cp config.sh.example config.sh        # set your dashboard URL, times, Fully password
./install-kiosk.sh "https://photos.app.goo.gl/XXXXXXXX"
```

---

## Hardware scope

Built and verified on a **DPF156** (15.6", 1920×1080, RK3326/PX30, Android 8.1,
eMMC). The method should carry to other RK3326 Frameo frames, but partition
layouts, the loader button/pads, and blob versions vary — see
[`docs/hardware-compatibility.md`](docs/hardware-compatibility.md). **Not** for the
Allwinner/other-SoC Frameo models.

## Credits & license

Method pieced together from the Rockchip `rkbin` / `rkdeveloptool` / `u-boot`
projects, `magiskboot`, and a lot of trial and error. MIT licensed — see
[`LICENSE`](LICENSE). Contributions with other models' details very welcome:
[`CONTRIBUTING.md`](CONTRIBUTING.md).
