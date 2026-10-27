#!/usr/bin/env bash
# Hyprland 边框/窗口色（Lua 管理器 theme.lua 或 hyprctl keyword）
# （P2 从 theme-next 拆分；由编排器 source，T_* 环境由 exporters/lib.sh 的 theme_env_load 提供）
# ── Hyprland 边框（实时，无需重建） ──────────────
# 经典 hyprlang 用 keyword；Lua 配置管理器下 keyword 不被支持（会弹红条
# "keyword can't work with non-legacy parsers"），改为写 theme.lua + reload。
if command -v hyprctl >/dev/null 2>&1; then
  if hyprctl systeminfo 2>/dev/null | grep -q "configProvider: lua"; then
    cat > "$XDG_CONFIG_HOME/hypr/theme.lua.tmp.$$" <<THEMELUA
hl.config({ general = { col = {
    active_border   = { colors = { "rgba(@T_ACCENT@ee)", "rgba(@T_ACCENT2@ee)" }, angle = 45 },
    inactive_border = "rgba(@T_INACTIVE@aa)",
} } })
THEMELUA
    sed -i -e "s/@T_ACCENT@/${T_ACCENT}/g" -e "s/@T_ACCENT2@/${T_ACCENT2}/g" -e "s/@T_INACTIVE@/${T_INACTIVE}/g" \
      "$XDG_CONFIG_HOME/hypr/theme.lua.tmp.$$" 2>/dev/null || true
    mv -f "$XDG_CONFIG_HOME/hypr/theme.lua.tmp.$$" "$XDG_CONFIG_HOME/hypr/theme.lua" 2>/dev/null \
      && hyprctl reload >/dev/null 2>&1
    # hyprctl reload 会清空所有 bind，而 hyprshell 只在启动时注册热键，
    # 所以每次改边框（切主题）后必须重启它的 daemon，否则 Super+` / Alt+Tab 失效。
    if command -v hyprshell >/dev/null 2>&1 && pgrep -x .hyprshell-wrap >/dev/null 2>&1; then
      pkill -x .hyprshell-wrap 2>/dev/null
      sleep 0.3
      setsid hyprshell run >/dev/null 2>&1 < /dev/null &
    fi
  else
    hyprctl keyword general:col.active_border "rgba(${T_ACCENT}ee) rgba(${T_ACCENT2}ee) 45deg" 2>/dev/null
    hyprctl keyword general:col.inactive_border "rgba(${T_INACTIVE}aa)" 2>/dev/null
  fi
fi
