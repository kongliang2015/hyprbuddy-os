#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

# 机型 profile：virtio（默认）/ leonard-nvidia（真实 NVIDIA 显卡）
PROFILE=""
# Home Manager 接入方式：module（默认，随系统构建）/ standalone（channel + home-manager switch）
HM_MODE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --hm)      HM_MODE="${2:-}"; shift 2 ;;
    -h|--help) echo "用法: ./install.sh [--profile virtio|leonard-nvidia] [--hm module|standalone]"; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done
case "$HM_MODE" in ""|module|standalone) ;; *) echo "--hm 只接受 module 或 standalone" >&2; exit 1 ;; esac

TARGET_USER="${SUDO_USER:-$(id -un)}"


echo "==> deploying user-level config to ~/.config and ~/.local/bin"
mkdir -p "$HOME/.config"/{hypr,waybar,fuzzel,kitty,mako,swayosd} "$HOME/.local/bin"
cp -r "$here/home/hypr/."      "$HOME/.config/hypr/"
cp -r "$here/home/waybar/."    "$HOME/.config/waybar/"
cp -r "$here/home/fuzzel/."    "$HOME/.config/fuzzel/"
cp -r "$here/home/kitty/."     "$HOME/.config/kitty/"
cp -r "$here/home/mako/."      "$HOME/.config/mako/"
cp -r "$here/home/swayosd/."   "$HOME/.config/swayosd/"
cp "$here"/scripts/* "$HOME/.local/bin/"
chmod +x "$HOME"/.local/bin/*
echo "user-level config deployed."
detect_bootloader() {
  local cfg=/etc/nixos/configuration.nix
  if [ -f "$cfg" ] && grep -q 'boot.loader.grub.enable = true' "$cfg"; then
    echo grub
  elif [ -d /sys/firmware/efi ]; then
    echo systemd-boot
  else
    echo grub
  fi
}
BOOT="$(detect_bootloader)"
echo "==> detected target bootloader: $BOOT"
SYS_SRC="$here/system/configuration.nix"
SYS_DST="/etc/nixos/configuration.nix"
SYS_TMP="$(mktemp /tmp/hyprland-config.XXXXXX.nix)"
CUR_STATE="$(grep -oE 'system.stateVersion = "[0-9.]+"' /etc/nixos/configuration.nix 2>/dev/null | grep -oE '[0-9]+[.][0-9]+' | head -1)"
[ -z "$CUR_STATE" ] && CUR_STATE="25.11"
if [ "$BOOT" = "grub" ]; then
  cp "$SYS_SRC" "$SYS_TMP"
  sed -i 's|^  boot.loader.systemd-boot.enable = true;|  boot.loader.grub.enable = true;|' "$SYS_TMP"
  sed -i '/^  boot.loader.efi.canTouchEfiVariables = true;/d' "$SYS_TMP"
  sed -i '/^  boot.loader.grub.enable = true;/a   boot.loader.grub.device = "/dev/sda";' "$SYS_TMP"
  sed -i '/^  boot.loader.grub.device /a   boot.loader.grub.useOSProber = true;' "$SYS_TMP"
  sed -i "/^  # Windows entry/,/^  '';/d" "$SYS_TMP"
else
  cp "$SYS_SRC" "$SYS_TMP"
fi
if [ -n "$PROFILE" ]; then
  sed -i "s|^  hardwareProfile = \"virtio\";|  hardwareProfile = \"$PROFILE\";|" "$SYS_TMP"
  echo "==> hardware profile: $PROFILE"
fi
if [ -n "$HM_MODE" ]; then
  sed -i "s|^  homeManagerMode = \"module\";|  homeManagerMode = \"$HM_MODE\";|" "$SYS_TMP"
  echo "==> home-manager mode: $HM_MODE"
fi
sed -i -E 's/^  system.stateVersion = "[0-9.]+";/  system.stateVersion = "PLACEHOLDER";/' "$SYS_TMP"
sed -i "s/PLACEHOLDER/$CUR_STATE/" "$SYS_TMP"
sed -i '/^  users.users.nixos = {$/,/^  };/d' "$SYS_TMP"
echo "==> generated system config (bootloader=$BOOT, stateVersion=$CUR_STATE, removed weak nixos user)"
if [ -f "$SYS_DST" ]; then
  sudo cp "$SYS_DST" "$SYS_DST.$(date +%Y%m%d%H%M%S).bak"
  echo "backed up original config -> $SYS_DST.<timestamp>.bak"
fi
sudo cp "$SYS_TMP" "$SYS_DST"
sudo rm -f "$SYS_TMP"
sudo mkdir -p /etc/nixos/profiles
sudo cp -f "$here"/system/profiles/*.nix /etc/nixos/profiles/
echo "system config written to $SYS_DST"
echo
echo "review $SYS_DST then run:"
echo "  sudo nixos-rebuild switch"
echo "then log out/in (or reboot) and pick Hyprland at the login manager."


echo "==> installing wallpapers and rewriting hardcoded /home/nixos paths"
mkdir -p "$HOME/Pictures/wallpapers"
cp -f "$here"/wallpapers/* "$HOME/Pictures/wallpapers/" || true
# 将配置/脚本里写死的 /home/nixos 替换为当前用户 HOME，使任意用户名可用
for f in "$HOME"/.config/hypr/* "$HOME"/.local/bin/*; do
  if [ -f "$f" ]; then sed -i "s|/home/nixos|$HOME|g" "$f" || true; fi
done


# 部署 Home Manager 用户配置（home.nix），并确保 home-manager channel 存在
HM_MODE="${HM_MODE:-module}"
if [ "$HM_MODE" = "module" ]; then
  sudo cp "$here/system/home.nix" /etc/nixos/home.nix
  HM_NIX=/etc/nixos/home.nix
else
  HM_NIX="$HOME/.config/home-manager/home.nix"
  mkdir -p "${HM_NIX%/*}"
  cp "$here/system/home.nix" "$HM_NIX"
fi
if ! sudo nix-channel --list 2>/dev/null | grep -q "^home-manager "; then
  echo "==> adding home-manager channel"
  sudo nix-channel --add https://github.com/nix-community/home-manager/archive/release-26.05.tar.gz home-manager || true
  sudo nix-channel --update home-manager || true
fi


# 将系统配置中的用户名占位符替换为实际用户（适配安装时创建的任意用户名）
if [ -f /etc/nixos/configuration.nix ]; then
  sudo sed -i "s|__TARGET_USER__|$TARGET_USER|g" /etc/nixos/configuration.nix
fi
# profile 里也可能出现占位符（如 home-manager-module.nix）
for f in /etc/nixos/profiles/*.nix; do
  [ -e "$f" ] && sudo sed -i "s|__TARGET_USER__|$TARGET_USER|g" "$f"
done

# home.nix：替换用户名占位符，并把 home.stateVersion 对齐到系统 stateVersion
if [ -f "$HM_NIX" ]; then
  if [ "$HM_MODE" = "module" ]; then
    sudo sed -i "s|__TARGET_USER__|$TARGET_USER|g" "$HM_NIX"
    sudo sed -i -E "s/^  home.stateVersion = \"[0-9.]+\";/  home.stateVersion = \"$CUR_STATE\";/" "$HM_NIX"
  else
    sed -i "s|__TARGET_USER__|$TARGET_USER|g" "$HM_NIX"
    sed -i -E "s/^  home.stateVersion = \"[0-9.]+\";/  home.stateVersion = \"$CUR_STATE\";/" "$HM_NIX"
  fi
fi

if [ "$HM_MODE" = "standalone" ]; then
  echo
  echo "==> Home Manager 为 standalone 模式，系统重建后再执行：home-manager switch"
fi
