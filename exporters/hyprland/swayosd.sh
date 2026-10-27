#!/usr/bin/env bash
# swayosd 值替换 + flock 重启 swayosd-server
# （P2 从 theme-next 拆分；由编排器 source，T_* 环境由 exporters/lib.sh 的 theme_env_load 提供）
# ── swayosd OSD（值替换 + 重启 swayosd-server） ──
# 注意 comm 是 .swayosd-server（包装器改名），与 waybar 同理用无标志 pgrep/pkill
OSD="$XDG_CONFIG_HOME/swayosd/style.css"
if [ -f "$OSD" ]; then
  if [ -L "$OSD" ]; then SSRC=$(readlink -f "$OSD"); else SSRC="$OSD"; fi
  mkdir -p "$XDG_CONFIG_HOME/swayosd"
  sed -e "s/#0f2438/#${T_BG}/" \
      -e "s/#0e7fa8/#${T_FG}/" \
      -e "s/#d7e7f5/#${T_FG}/" \
      -e "s/#1e9bd8/#${T_BAR_PULSE}/" \
      -e "s/#1b3d5f/#${T_SURFACE}/" \
      "$SSRC" > "$OSD.tmp" 2>/dev/null || true
  (
    flock -x 201
    if [ -s "$OSD.tmp" ]; then
      mv -f "$OSD.tmp" "$OSD"
    else
      rm -f "$OSD.tmp"
    fi
    if pgrep swayosd-server >/dev/null 2>&1; then
      pkill swayosd-server 2>/dev/null
      sleep 0.3
      setsid swayosd-server >/dev/null 2>&1 < /dev/null 201>&- &
    fi
  ) 201>"$RUNTIME/theme-next/osd.lock"
fi
