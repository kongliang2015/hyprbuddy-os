#!/usr/bin/env bash
# 探测目标机硬件，输出可被 install.sh source 的 KEY=value。
# 只读操作，不改动任何东西。人类可读摘要写 stderr。
set -euo pipefail

note() { printf '%s\n' "$*" >&2; }

# ── 引导器 ────────────────────────────────────────────────
if [ -f /boot/grub/grub.cfg ]; then
  BOOTLOADER=grub
elif [ -d /sys/firmware/efi ]; then
  BOOTLOADER=systemd-boot
else
  BOOTLOADER=grub
fi

# ── 显卡 ──────────────────────────────────────────────────
GPU_VENDOR=virtio
gpu_lines=$(lspci -nn 2>/dev/null | grep -Ei '(vga compatible|3d controller|display controller)' || true)

while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in
    *10de:*) GPU_VENDOR=nvidia ;;
    *1002:*) [ "$GPU_VENDOR" = nvidia ] || GPU_VENDOR=amd ;;
    *8086:*) { [ "$GPU_VENDOR" = nvidia ] || [ "$GPU_VENDOR" = amd ]; } || GPU_VENDOR=intel ;;
  esac
done <<< "$gpu_lines"

NVIDIA_PCI_IDS=""
if [ "$GPU_VENDOR" = nvidia ]; then
  NVIDIA_PCI_IDS=$(printf '%s\n' "$gpu_lines" \
    | grep -oE '10de:[0-9a-f]{4}' | sort -u | paste -sd' ' - || true)
fi

# ── 笔记本特征 ────────────────────────────────────────────
BATTERY=false
compgen -G '/sys/class/power_supply/BAT*' >/dev/null && BATTERY=true

BACKLIGHT=false
compgen -G '/sys/class/backlight/*' >/dev/null && BACKLIGHT=true

# ── Windows 链式启动 ──────────────────────────────────────
WINDOWS_ENTRY=false
if [ "$BOOTLOADER" = systemd-boot ] && [ -f /boot/EFI/Microsoft/Boot/bootmgfw.efi ]; then
  WINDOWS_ENTRY=true
fi

# ── 输出 ──────────────────────────────────────────────────
note "==> 硬件探测"
note "    引导器:   $BOOTLOADER"
note "    显卡:     $GPU_VENDOR ${NVIDIA_PCI_IDS:+($NVIDIA_PCI_IDS)}"
note "    电池:     $BATTERY"
note "    背光:     $BACKLIGHT"
note "    Windows:  $WINDOWS_ENTRY"

cat <<EOF
BOOTLOADER=$BOOTLOADER
GPU_VENDOR=$GPU_VENDOR
NVIDIA_PCI_IDS="$NVIDIA_PCI_IDS"
BATTERY=$BATTERY
BACKLIGHT=$BACKLIGHT
WINDOWS_ENTRY=$WINDOWS_ENTRY
EOF
