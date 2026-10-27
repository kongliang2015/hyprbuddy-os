#!/usr/bin/env bash
# 壁纸：awww/swww（Hyprland 栈）。COSMIC 栈走 de_wallpaper_set（cosmic-bg）。
# hyprpaper 在本 VM 因 GBM 分配失败段错误已弃用；26.05 起 swww 更名 awww。
WALL="$HOME/Pictures/wallpapers"
IMG="$WALL/${T_WALLPAPER}"
if [ -f "$IMG" ]; then
  WP= WPD=
  if command -v awww >/dev/null 2>&1; then
    WP=awww WPD=awww-daemon
  elif command -v swww >/dev/null 2>&1; then
    WP=swww WPD=swww-daemon
  fi
  if [ -n "$WPD" ]; then
    pgrep -f "$WPD" >/dev/null 2>&1 || setsid "$WPD" >/dev/null 2>&1 < /dev/null &
    for _i in 1 2 3 4 5; do
      sleep 0.3
      pgrep -f "$WPD" >/dev/null 2>&1 && break
    done
    "$WP" img "$IMG" 2>/dev/null
  fi
fi

