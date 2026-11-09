# Troubleshooting

**`adb` shows `unauthorized`, no dialog.** That's the starting condition this
repo solves — the fix is `/adb_keys` (stages 40–60), not anything in Developer
Options.

**`rkdeveloptool ld` lists nothing.**
- Use a known-good **USB-A → USB-C data cable**. C-to-C often fails on these frames.
- Confirm maskrom: `lsusb` should show `2207:xxxx`. If you see the normal Android
  device instead, you're not in maskrom.

**`rkdeveloptool db` hangs.** An SD card is in the frame. Remove it for all
maskrom work; only insert it to boot `ums`.

**The frame ignores the SD / still boots Frameo.** The eMMC ID-block is still
valid, so the BootROM prefers eMMC. Run stage 20 to zero the 5 ID-block sectors
first. The pads force *download* mode, not SD boot — zeroing the ID-block is what
makes it fall through to SD.

**Nothing enumerates after inserting the SD.**
- The miniloader needs a **GPT** on the SD — stage 30 copies the eMMC GPT. If you
  skipped stage 20, there's no `emmc_gpt.bin` to copy.
- Check the SD layout offsets (GPT@0, idbloader@64, uboot@0x4000, trust@0x6000).
- Some card readers only detect a card inserted **before** the reader is plugged
  in. If `lsblk` shows 0 B, replug the reader with the card already in it, or try
  another card/reader.

**`ums` disk appears then drops.** Don't move the SD card or touch the reader
mid-session; re-seat the frame's USB and let U-Boot re-run `ums`. Keep the SD in
the **frame** (that's what's running U-Boot), not back in the host reader.

**Init service won't start (`service does not have a SELinux domain defined`).**
The `.rc` needs `seclabel u:r:shell:s0`. On a permissive kernel, AVC denials are
non-blocking. `setenforce 0` (the kiosk installer does this) while testing.

**Fully Kiosk toggle does nothing.** The toggle uses Fully's local REST
(`loadUrl`). Enable **Settings → Remote Administration**, set a password, and put
that password in `kiosk/config.sh` (`FULLY_PW`). Confirm with
`adb shell 'busybox wget -qO- "http://127.0.0.1:2323/?cmd=deviceInfo&password=PW"'`.

**I think I bricked it.** As long as you can still reach maskrom (`2207` on
`lsusb`), you can re-write. Boot the recovery SD to get `ums` back and restore
`boot_orig.img.bak` and the `idb_sec_*.bin` sectors.
