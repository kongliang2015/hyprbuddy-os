#!/usr/bin/env bash
# hyprtoolkit（hyprpolkitagent 认证框配色）
# （P2 从 theme-next 拆分；由编排器 source，T_* 环境由 exporters/lib.sh 的 theme_env_load 提供）
# ── hyprtoolkit（hyprpolkitagent 0.2.0 认证框的配色）────────────
# 0.2.0 起认证框改由 hyprtoolkit 渲染，颜色/圆角/字体取自这个文件；
# agent 每次弹窗前重读，所以切主题不需要重启 polkit 代理。
# 键名见 hyprtoolkit wiki：background/base/alternate_base/text/bright_text/
# accent/accent_secondary/rounding_large/rounding_small/font_family/font_size
cat > "$XDG_CONFIG_HOME/hypr/hyprtoolkit.conf" <<HTK
background = rgba(${T_BG}ff)
base = rgba($(mixhex "$T_BG" "$T_FG" 6 | cut -c2-)ff)
alternate_base = rgba($(mixhex "$T_BG" "$T_FG" 3 | cut -c2-)ff)
text = rgba(${T_FG}ff)
bright_text = rgba($(mixhex "$T_FG" FFFFFF 25 | cut -c2-)ff)
accent = rgba(${T_ACCENT}ff)
accent_secondary = rgba(${T_ACCENT2}ff)
rounding_large = 14
rounding_small = 8
font_family = JetBrainsMono Nerd Font
font_size = 11
HTK

# agent 主题跟随（agent 层未启用时脚本不存在，静默跳过）
# 明暗：按 waybar 背景亮度判断（浅色主题 T_BG 接近 #FFF），agent 界面据此跟随
AGENT_MODE=dark
if [ $(( (16#${T_BG:0:2} * 299 + 16#${T_BG:2:2} * 587 + 16#${T_BG:4:2} * 114) / 1000 )) -ge 140 ]; then
  AGENT_MODE=light
fi
