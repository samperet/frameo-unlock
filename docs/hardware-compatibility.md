# Hardware compatibility

## Verified

| Model | SoC | Panel | Android | Storage |
|-------|-----|-------|---------|---------|
| Frameo **DPF156** | RK3326 / PX30, 32-bit (`rk3326_32bit_r135`) | 15.6" 1920×1080 | 8.1 | eMMC (~29.8 GB) |

Touch controller `gsl_thzy` (multitouch), g-sensor, ADC keys, power key.

## Likely compatible (untested — please report)

Other **RK3326/PX30** Frameo and generic Android photo frames. The method is not
model-specific in principle, but these differ per unit and you must confirm them:

- **Entering maskrom** — test pads to short, a hidden button, or holding a key
  while plugging USB. Find it before you start. On the **DPF156 this means
  opening the frame** (pry off the back cover) and bridging the two internal
  "Update" solder pads on power-up — there is no externally accessible button.
- **Partition layout** — stage 40 finds the `boot` partition by name from the
  GPT, so it adapts, but verify `sgdisk -p` output looks sane.
- **Blob versions** — `scripts/00-prereqs.sh` pulls the latest `rk3326_ddr_*`,
  `rk3326_miniloader_*` and builds the matching loader. If U-Boot won't come up,
  try pinning blob versions.
- **U-Boot board** — we use `evb-rk3326`. A different RK3326 board defconfig may
  map eMMC to a different `mmc` index; adjust `ums 0 mmc N` accordingly.

## Not compatible

- Frameo models on **Allwinner** or other non-Rockchip SoCs.
- 64-bit RK parts (RK3399, etc.) — the same ideas apply but the blobs, board and
  offsets are all different. Don't use this repo's loader as-is.

## How to identify your SoC

In maskrom, `lsusb` shows a Rockchip VID `2207`; the PID hints at the family
(RK3326 enumerates as `2207:0006`). If you already have any shell:
`getprop ro.board.platform` and `getprop ro.product.device`.

Adding a model? See [`CONTRIBUTING.md`](../CONTRIBUTING.md) — a row in the table
plus your maskrom method and `sgdisk -p` output helps the next person a lot.
