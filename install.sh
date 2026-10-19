#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
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
if [ -f "$here/system/home.nix" ]; then
  sudo cp "$here/system/home.nix" /etc/nixos/home.nix
fi
if ! sudo nix-channel --list 2>/dev/null | grep -q "^home-manager "; then
  echo "==> adding home-manager channel"
  sudo nix-channel --add https://github.com/nix-community/home-manager/archive/release-26.05.tar.gz home-manager || true
  sudo nix-channel --update home-manager || true
fi


# 将系统配置中的用户名占位符替换为实际用户（适配安装时创建的任意用户名）
TARGET_USER="${SUDO_USER:-$(id -un)}"
if [ -f /etc/nixos/configuration.nix ]; then
  sudo sed -i "s|__TARGET_USER__|$TARGET_USER|g" /etc/nixos/configuration.nix
fi
