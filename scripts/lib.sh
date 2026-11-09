#!/usr/bin/env bash
# Shared helpers for the frameo-unlock scripts.
# Source this at the top of every stage script:  . "$(dirname "$0")/lib.sh"
set -euo pipefail

# ---- paths -----------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${FRAMEO_BUILD_DIR:-$REPO_ROOT/build}"
DUMP_DIR="${FRAMEO_DUMP_DIR:-$REPO_ROOT/dumps}"
mkdir -p "$BUILD_DIR" "$DUMP_DIR"

# ---- pretty logging --------------------------------------------------------
if [ -t 1 ]; then C_B=$'\e[1m'; C_R=$'\e[31m'; C_G=$'\e[32m'; C_Y=$'\e[33m'; C_0=$'\e[0m'
else C_B=; C_R=; C_G=; C_Y=; C_0=; fi
say()  { printf '%s==>%s %s\n' "$C_B" "$C_0" "$*"; }
ok()   { printf '%s ok %s %s\n' "$C_G" "$C_0" "$*"; }
warn() { printf '%s !! %s %s\n' "$C_Y" "$C_0" "$*" >&2; }
die()  { printf '%sABORT%s %s\n' "$C_R" "$C_0" "$*" >&2; exit 1; }

# ---- confirmation gates ----------------------------------------------------
# Every irreversible or physical step goes through confirm(). Set FRAMEO_YES=1
# to auto-accept (use only when you have read the script and know your device).
confirm() {
  [ "${FRAMEO_YES:-0}" = "1" ] && { warn "auto-confirm: $*"; return 0; }
  printf '%s%s%s [y/N] ' "$C_Y" "$*" "$C_0"
  read -r a </dev/tty || true
  case "$a" in y|Y|yes|YES) return 0;; *) die "declined";; esac
}

# A loud, typed confirmation for the genuinely dangerous writes.
confirm_typed() { # confirm_typed "WIPE SD" "phrase user must type"
  local label="$1" phrase="$2"
  [ "${FRAMEO_YES:-0}" = "1" ] && { warn "auto-confirm ($label)"; return 0; }
  printf '%s%s%s\n  type exactly: %s\n> ' "$C_R" "$label" "$C_0" "$phrase"
  read -r a </dev/tty || true
  [ "$a" = "$phrase" ] || die "phrase did not match — nothing was written"
}

# ---- block-device safety ---------------------------------------------------
# Refuse to touch anything that is not a small, removable, USB block device,
# unless the caller explicitly overrides with FRAMEO_ALLOW_BIG=1.
assert_removable() { # assert_removable /dev/sdX  [max_bytes]
  local dev="$1" maxb="${2:-137438953472}"   # default cap 128 GiB
  [ -b "$dev" ] || die "$dev is not a block device"
  local base; base="$(basename "$dev")"
  local rm sz; rm="$(cat "/sys/block/$base/removable" 2>/dev/null || echo 0)"
  sz="$(cat "/sys/block/$base/size" 2>/dev/null || echo 0)"; sz=$((sz*512))
  say "$dev : removable=$rm  size=$(numfmt --to=iec "$sz" 2>/dev/null || echo "$sz")B  model=$(cat /sys/block/$base/device/model 2>/dev/null||echo ?)"
  if [ "${FRAMEO_ALLOW_BIG:-0}" != "1" ]; then
    [ "$rm" = "1" ]  || die "$dev is not removable — refusing (set FRAMEO_ALLOW_BIG=1 to override)"
    [ "$sz" -le "$maxb" ] || die "$dev is larger than the cap — refusing (set FRAMEO_ALLOW_BIG=1 to override)"
  fi
  # never let the root disk through
  local rootsrc; rootsrc="$(findmnt -no SOURCE / 2>/dev/null || true)"
  case "$rootsrc" in *"$base"*) die "$dev backs the running root filesystem — refusing";; esac
}

# ---- tool checks -----------------------------------------------------------
need() { command -v "$1" >/dev/null 2>&1 || die "missing tool: $1  (run scripts/00-prereqs.sh)"; }

# ---- rockchip IDB sector map (RK3326/PX30 standard) -------------------------
# The eMMC carries 5 copies of the ID-block boot header; the BootROM tries them
# in order. Zeroing all 5 makes the BootROM fall through to the SD card.
IDB_SECTORS="64 1088 2112 3136 4160"
