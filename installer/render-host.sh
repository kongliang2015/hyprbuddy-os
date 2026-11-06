#!/usr/bin/env bash
# 用 hosts/_template/default.nix 渲染一份 host 配置，并做语法校验。
# 用法: render-host.sh <输出文件>
# 需要: HOSTNAME USERNAME GPU_VENDOR [BOOTLOADER WINDOWS_ENTRY NVIDIA_PCI_IDS
#        EXTRA_SESSIONS BATTERY BACKLIGHT AGENT_ENABLE AGENT_LIST LAZY_AGENT_LIST MIRROR STATE_VERSION]
set -euo pipefail

out="${1:?用法: render-host.sh <输出文件>}"
tpl="$(cd "$(dirname "$0")/.." && pwd)/hosts/_template/default.nix"
[ -f "$tpl" ] || { echo "找不到模板: $tpl" >&2; exit 1; }

: "${HOSTNAME:?缺少 HOSTNAME}"
: "${USERNAME:?缺少 USERNAME}"
: "${GPU_VENDOR:?缺少 GPU_VENDOR}"

STATE_VERSION="${STATE_VERSION:-25.11}"
BOOTLOADER="${BOOTLOADER:-systemd-boot}"
WINDOWS_ENTRY="${WINDOWS_ENTRY:-false}"
BATTERY="${BATTERY:-false}"
BACKLIGHT="${BACKLIGHT:-false}"
AGENT_ENABLE="${AGENT_ENABLE:-true}"
MIRROR="${MIRROR:-cn}"

# 空格分隔的裸值 -> Nix 列表元素：a b  =>  "a" "b"
nix_list() {
  local out="" tok
  for tok in $1; do out="$out\"$tok\" "; done
  printf '%s' "${out%% }"
}

NVIDIA_PCI_IDS="$(nix_list "${NVIDIA_PCI_IDS:-}")"
EXTRA_SESSIONS="$(nix_list "${EXTRA_SESSIONS:-}")"
AGENT_LIST="$(nix_list "${AGENT_LIST:-}")"
LAZY_AGENT_LIST="$(nix_list "${LAZY_AGENT_LIST:-}")"

sed \
  -e "s|@HOSTNAME@|$HOSTNAME|g" \
  -e "s|@STATE_VERSION@|$STATE_VERSION|g" \
  -e "s|@USERNAME@|$USERNAME|g" \
  -e "s|@BOOTLOADER@|$BOOTLOADER|g" \
  -e "s|@WINDOWS_ENTRY@|$WINDOWS_ENTRY|g" \
  -e "s|@GPU_VENDOR@|$GPU_VENDOR|g" \
  -e "s|@NVIDIA_PCI_IDS@|$NVIDIA_PCI_IDS|g" \
  -e "s|@EXTRA_SESSIONS@|$EXTRA_SESSIONS|g" \
  -e "s|@BATTERY@|$BATTERY|g" \
  -e "s|@BACKLIGHT@|$BACKLIGHT|g" \
  -e "s|@AGENT_ENABLE@|$AGENT_ENABLE|g" \
  -e "s|@AGENT_LIST@|$AGENT_LIST|g" \
  -e "s|@LAZY_AGENT_LIST@|$LAZY_AGENT_LIST|g" \
  -e "s|@MIRROR@|$MIRROR|g" \
  "$tpl" > "$out"

if grep -qE '@[A-Z_]+@' "$out"; then
  echo "渲染后仍存在未替换的占位符：" >&2
  grep -nE '@[A-Z_]+@' "$out" >&2
  exit 1
fi

nix-instantiate --parse "$out" > /dev/null
echo "已生成 $out" >&2
