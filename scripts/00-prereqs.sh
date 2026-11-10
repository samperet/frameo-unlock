#!/usr/bin/env bash
# Stage 00 — install host dependencies and fetch the Rockchip toolchain.
# Tested on Debian/Ubuntu x86_64. Idempotent: safe to re-run.
. "$(dirname "$0")/lib.sh"

say "Installing host packages (sudo may prompt)…"
sudo apt-get update -qq
sudo apt-get install -y \
  build-essential git bc bison flex libssl-dev python3 python3-pyelftools \
  gcc-aarch64-linux-gnu device-tree-compiler libusb-1.0-0-dev pkg-config \
  libgnutls28-dev swig android-sdk-platform-tools-common android-tools-adb \
  gdisk parted curl unzip autoconf automake libudev-dev

cd "$BUILD_DIR"

# --- rkbin: DDR init, BL31, miniloader blobs + boot_merger / mkimage ---------
[ -d rkbin ] || { say "cloning rkbin…"; git clone --depth 1 https://github.com/rockchip-linux/rkbin.git; }

# --- rkdeveloptool: maskrom / loader flashing --------------------------------
if [ ! -x rkdeveloptool/rkdeveloptool ]; then
  say "building rkdeveloptool…"
  [ -d rkdeveloptool ] || git clone --depth 1 https://github.com/rockchip-linux/rkdeveloptool.git
  ( cd rkdeveloptool && autoreconf -i && ./configure && make -j"$(nproc)" )
fi

# --- vendor U-Boot (has working RK3326 eMMC + ums) ---------------------------
[ -d u-boot ] || { say "cloning rockchip-linux/u-boot (next-dev)…"; \
  git clone --depth 1 -b next-dev https://github.com/rockchip-linux/u-boot.git; }

# --- magiskboot: unpack/repack Android boot images reliably ------------------
if [ ! -x "$BUILD_DIR/magiskboot" ]; then
  say "fetching magiskboot…"
  MV="v27.0"
  curl -fsSL -o magisk.apk "https://github.com/topjohnwu/Magisk/releases/download/${MV}/Magisk-${MV}.apk" \
    && unzip -o -q magisk.apk 'lib/x86_64/libmagiskboot.so' -d magisk_x \
    && cp magisk_x/lib/x86_64/libmagiskboot.so magiskboot && chmod +x magiskboot \
    && ok "magiskboot ready" || warn "magiskboot download failed — stage 50 will fall back to manual cpio surgery"
fi

ok "prereqs done. Build dir: $BUILD_DIR"
