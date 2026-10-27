#!/usr/bin/env bash
# kitty theme.inc.conf + 实时 set-colors（color15 缺项回落前景色）
# （P2 从 theme-next 拆分；由编排器 source，T_* 环境由 exporters/lib.sh 的 theme_env_load 提供）
# ── Kitty（include 持久化 + 实时 set-colors） ───
mkdir -p "$XDG_CONFIG_HOME/kitty"
cat > "$XDG_CONFIG_HOME/kitty/theme.inc.conf" <<KITTY
foreground #${T_TERM_FG}
background #${T_TERM_BG}
cursor #${T_TERM_CURSOR}
cursor_text_color #${T_TERM_BG}
selection_background #${T_TERM_FG}
selection_foreground #${T_TERM_BG}
color0  #${T_TERM_C0}
color1  #${T_TERM_C1}
color2  #${T_TERM_C2}
color3  #${T_TERM_C3}
color4  #${T_TERM_C4}
color5  #${T_TERM_C5}
color6  #${T_TERM_C6}
color7  #${T_TERM_C7}
color8  #${T_TERM_C8}
color9  #${T_TERM_C9}
color10 #${T_TERM_C10}
color11 #${T_TERM_C11}
color12 #${T_TERM_C12}
color13 #${T_TERM_C13}
color14 #${T_TERM_C14}
color15 #${T_TERM_FG}
KITTY
if command -v kitty >/dev/null 2>&1; then
  timeout 3 kitty @ set-colors -a \
    background=#${T_TERM_BG} foreground=#${T_TERM_FG} cursor=#${T_TERM_CURSOR} \
    color0=#${T_TERM_C0} color1=#${T_TERM_C1} color2=#${T_TERM_C2} color3=#${T_TERM_C3} color4=#${T_TERM_C4} color5=#${T_TERM_C5} color6=#${T_TERM_C6} color7=#${T_TERM_C7} \
    color8=#${T_TERM_C8} color9=#${T_TERM_C9} color10=#${T_TERM_C10} color11=#${T_TERM_C11} color12=#${T_TERM_C12} color13=#${T_TERM_C13} color14=#${T_TERM_C14} color15=#${T_TERM_FG} \
    2>/dev/null || true
fi
