#!/usr/bin/env bash
# 部署用户级 Hyprland 配置到 ~/.config 与 ~/.local/bin
# 系统层仍需手动执行 sudo nixos-rebuild switch（见 README）。
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$HOME/.config"/{hypr,waybar,fuzzel,kitty,mako,swayosd} "$HOME/.local/bin"

cp -r "$here/home/hypr/."      "$HOME/.config/hypr/"
cp -r "$here/home/waybar/."    "$HOME/.config/waybar/"
cp -r "$here/home/fuzzel/."    "$HOME/.config/fuzzel/"
cp -r "$here/home/kitty/."     "$HOME/.config/kitty/"
cp -r "$here/home/mako/."      "$HOME/.config/mako/"
cp -r "$here/home/swayosd/."   "$HOME/.config/swayosd/"

cp "$here"/scripts/* "$HOME/.local/bin/"
chmod +x "$HOME"/.local/bin/*

echo "用户级配置已部署到 ~/.config 与 ~/.local/bin。"
echo
echo "接下来应用系统层（需要 sudo）："
echo "  sudo cp '$here/system/configuration.nix' /etc/nixos/configuration.nix"
echo "  sudo nixos-rebuild switch"
echo
echo "然后注销重登（或重启）。"
