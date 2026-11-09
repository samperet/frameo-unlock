#!/usr/bin/env bash
# Stage 10 — build a U-Boot for RK3326 whose boot command is `ums 0 mmc 0`.
#
# WHY: the frame's maskrom USB "download" mode caps block reads at 32 MB, so you
# cannot dump the boot/ramdisk that way. Instead we boot our own U-Boot off an
# SD card and let it expose the eMMC as a plain USB Mass Storage disk (`ums`),
# which has no cap. This stage produces idbloader.img, uboot.img and trust.img.
. "$(dirname "$0")/lib.sh"

UB="$BUILD_DIR/u-boot"; RKBIN="$BUILD_DIR/rkbin"
[ -d "$UB" ] || die "u-boot tree missing — run 00-prereqs.sh"
need aarch64-linux-gnu-gcc
export CROSS_COMPILE=aarch64-linux-gnu-
export ARCH=arm64

say "Patching boot command to 'ums 0 mmc 0' …"
HDR="$UB/include/configs/rockchip-common.h"
# Vendor U-Boot hard-codes RKIMG_BOOTCOMMAND; replace the normal boot chain with ums.
if grep -q 'ums 0 mmc 0' "$HDR"; then ok "already patched";
else
  cp "$HDR" "$HDR.orig"
  # Replace the first boot_android/bootrkp style command with our ums command.
  python3 - "$HDR" <<'PY'
import re,sys
p=sys.argv[1]; s=open(p).read()
s=re.sub(r'#define RKIMG_BOOTCOMMAND\s*\\\n(?:\s*".*?"\s*\\\n)*\s*".*?"',
         '#define RKIMG_BOOTCOMMAND \\\n\t"ums 0 mmc 0;"', s, count=1, flags=re.S)
open(p,'w').write(s)
print("patched RKIMG_BOOTCOMMAND")
PY
fi

# mawk lacks strtonum(); make the size script portable.
UBSH="$UB/scripts/uboot.sh"
[ -f "$UBSH" ] && sed -i 's/strtonum(\$2)/\$2/' "$UBSH" 2>/dev/null || true

say "Configuring evb-rk3326 …"
( cd "$UB" && make evb-rk3326_defconfig )
# mkeficapsule needs gnutls headers we may not have; it is not needed here.
sed -i 's/^CONFIG_TOOLS_MKEFICAPSULE=y/# CONFIG_TOOLS_MKEFICAPSULE is not set/' "$UB/.config" 2>/dev/null || true

say "Building U-Boot (warnings-as-errors off for old tree) …"
( cd "$UB" && KCFLAGS=-Wno-error ./make.sh evb-rk3326 ) \
  || ( cd "$UB" && KCFLAGS=-Wno-error make -j"$(nproc)" )

# Assemble idbloader = DDR + miniloader (RK3326 blobs from rkbin).
DDR="$(ls -1 "$RKBIN"/bin/rk33/rk3326_ddr_*.bin | sort -V | tail -1)"
MINI="$(ls -1 "$RKBIN"/bin/rk33/rk3326_miniloader_*.bin | sort -V | tail -1)"
MKIMAGE="$RKBIN/tools/mkimage"
say "idbloader from: $(basename "$DDR") + $(basename "$MINI")"
"$MKIMAGE" -n rk3326 -T rksd -d "$DDR" "$BUILD_DIR/idbloader.img"
cat "$MINI" >> "$BUILD_DIR/idbloader.img"
cp "$UB/uboot.img" "$BUILD_DIR/uboot.img"
cp "$UB/trust.img" "$BUILD_DIR/trust.img"

ok "built: idbloader.img, uboot.img, trust.img  (in $BUILD_DIR)"
