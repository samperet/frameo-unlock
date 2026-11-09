# Contributing

The most valuable contributions are **other models' details** so the next person
with a different Frameo has a map.

## Adding a model

Open a PR (or issue) with:

- Model name, SoC (`2207:PID` from `lsusb` in maskrom, or `getprop
  ro.board.platform`), panel resolution, Android version, storage type.
- **How you entered maskrom** on that unit (pads, button, key combo).
- `sgdisk -p /dev/sdX` of the eMMC over `ums` (partition layout).
- Which blob/U-Boot versions and `ums 0 mmc N` index worked.
- Anything that differed from the DPF156 path.

Add a row to [`docs/hardware-compatibility.md`](docs/hardware-compatibility.md).

## Never commit

- **Device dumps** (`*.img`, `*.bin`) — they can contain wifi creds, tokens and
  personal data. The `.gitignore` already blocks them; don't force-add.
- Your `kiosk/config.sh`, ADB keys, or any URL/IP/token from your own network.

## Scripts

- Keep every destructive action behind `confirm`/`confirm_typed` and the
  `assert_removable` guard in `scripts/lib.sh`.
- Prefer portable POSIX/`busybox`-friendly shell for anything that runs **on the
  frame**; host scripts can assume bash + coreutils.
- Test on your own unit and say so in the PR.
