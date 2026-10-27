#!/usr/bin/env bash
# hyprlock 变量文件（控件块在 hyprlock.conf）
# （P2 从 theme-next 拆分；由编排器 source，T_* 环境由 exporters/lib.sh 的 theme_env_load 提供）
# ── hyprlock 锁屏（只写变量；控件块在 hyprlock.conf 里，写控件块会因 source 追加出重复控件） ──
mkdir -p "$XDG_CONFIG_HOME/hypr"
cat > "$XDG_CONFIG_HOME/hypr/theme-hyprlock.conf" <<LOCK
\$hl_bg = rgba(${T_BG}ff)
\$hl_fg = rgba(${T_FG}ff)
\$hl_inner = rgba(${T_BG}e6)
\$hl_outer = rgba(${T_BAR_AGENT}ff)
\$hl_dots = rgba(${T_FG}ff)
\$hl_bgpath = ${HOME}/Pictures/wallpapers/${T_WALLPAPER}
LOCK
