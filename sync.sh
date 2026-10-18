#!/usr/bin/env bash
# 把线上实际配置同步回本项目目录，并提交到 git。
# 用法：
#   ./sync.sh                  # 自动提交，消息带时间戳
#   ./sync.sh "调整通知样式"   # 自定义提交信息
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
msg="${1:-sync: $(date '+%Y-%m-%d %H:%M:%S')}"

copy() {
  local src="$1" dst="$2"
  if [ -e "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp -p "$src" "$dst"
  else
    echo "skip (missing): $src"
  fi
}

# ── 系统层 ─────────────────────────────────────────────
copy "$HOME/configuration.nix.new" "$here/system/configuration.nix"

# ── 用户层 ─────────────────────────────────────────────
for f in hyprland.conf hypridle.conf hyprlock.conf hyprpaper.conf; do
  copy "$HOME/.config/hypr/$f" "$here/home/hypr/$f"
done
copy "$HOME/.config/waybar/config"    "$here/home/waybar/config"
copy "$HOME/.config/waybar/style.css" "$here/home/waybar/style.css"
copy "$HOME/.config/fuzzel/fuzzel.ini" "$here/home/fuzzel/fuzzel.ini"
copy "$HOME/.config/kitty/kitty.conf" "$here/home/kitty/kitty.conf"
copy "$HOME/.config/mako/config"      "$here/home/mako/config"
copy "$HOME/.config/swayosd/style.css" "$here/home/swayosd/style.css"

# ── 脚本 ───────────────────────────────────────────────
for s in hypr-menu show-keybinds night-mode notif-dnd \
         record-toggle screenshot-annotate wallpaper-next; do
  copy "$HOME/.local/bin/$s" "$here/scripts/$s"
done
chmod +x "$here"/scripts/* 2>/dev/null || true

# ── 壁纸（如存在）─────────────────────────────────────
if [ -d "$HOME/Pictures/wallpapers" ]; then
  mkdir -p "$here/wallpapers"
  cp -p "$HOME/Pictures/wallpapers/"* "$here/wallpapers/" 2>/dev/null || true
fi

cd "$here"

if [ -z "$(git status --porcelain)" ]; then
  echo "没有需要提交的改动。"
  exit 0
fi

git add -A
echo "=== 变更 ==="
git diff --cached --stat
git commit -m "$msg"
echo "已提交：$(git log -1 --oneline)"
