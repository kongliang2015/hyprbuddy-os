#!/usr/bin/env bash
# Waybar 整份 style.css 重写 + flock 重启
# （P2 从 theme-next 拆分；由编排器 source，T_* 环境由 exporters/lib.sh 的 theme_env_load 提供）
# ── Waybar（整份重写 style.css + 重启） ─────────
# GTK CSS 不支持 :root / var()，必须写具体颜色值。
# style.css 默认是指向 store 的软链，先摘掉再写常规文件。
mkdir -p "$XDG_CONFIG_HOME/waybar"
rm -f "$XDG_CONFIG_HOME/waybar/style.css"
rm -f "$XDG_CONFIG_HOME/waybar/theme.css"
cat > "$XDG_CONFIG_HOME/waybar/style.css" <<CSS
* {
  font-family: "JetBrainsMono Nerd Font", "Noto Sans CJK SC", sans-serif;
  font-size: 13px;
  color: #${T_FG};
  border: none;
  border-radius: 0;
}
window#waybar { background: transparent; }
window#waybar > box {
  background: #${T_BG};
  border-radius: 12px;
  padding: 2px 8px;
  margin: 0 4px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.4);
}
/* workspaces：胶囊 + hover */
#workspaces button { padding: 0 8px; margin: 2px 1px; color: #${T_MUTED}; border-radius: 8px; }
#workspaces button:hover { color: #${T_FG}; background: #${T_SURFACE}; }
#workspaces button.active { color: #${T_FG}; background: #${T_SURFACE}; }
#workspaces button.urgent { color: #${T_URGENT}; }
/* 中间窗口标题：独立胶囊 */
#window { background: #${T_BG}; border-radius: 10px; padding: 0 12px; color: #${T_MUTED}; }
/* 分组胶囊（与 Hyprland rounding=10 对齐） */
#group-hardware, #group-media, #group-clock {
  background: #${T_SURFACE};
  border: 1px solid #${T_FG};
  border-radius: 10px;
  padding: 0 8px;
  margin: 4px 3px;
}
#group-hardware:hover, #group-media:hover, #group-clock:hover { background: #${T_MUTED}; }
#network, #tray { border: 1px solid #${T_FG}; border-radius: 10px; padding: 0 8px; margin: 4px 3px; }
#network:hover { background: #${T_SURFACE}; }
#clock { color: #${T_BAR_CLOCK}; }
#cpu { color: #${T_BAR_CPU}; }
#memory { color: #${T_BAR_MEM}; }
#battery { color: #${T_BAR_BAT}; }
#pulseaudio { color: #${T_BAR_PULSE}; }
#custom-agent-usage { color: #${T_BAR_AGENT}; padding: 0 6px; }
CSS
# 在跑就重启（换肤生效），没跑就拉起（登录后 CSS 被旧缓存打断等场景）。
# 注意匹配方式：NixOS 包装的 waybar 进程 comm 是 ".waybar-wrapped"，
# pgrep -x waybar 永远匹配不上（旧实例杀不掉会堆叠），须用对 comm 子串匹配的
# 无标志 pgrep/pkill waybar。
# flock 串行化：exec-once 的 restore 与配置自动 reload 触发的 restore 可能并发，
# 不加锁会 pkill/setsid 交错导致状态栏堆叠出多份。
(
  flock -x 200
  if pgrep waybar >/dev/null 2>&1; then
    pkill waybar 2>/dev/null
    sleep 0.4
  fi
  setsid waybar >/dev/null 2>&1 < /dev/null 200>&- &   # 200>&- 防止子进程继承锁 fd
) 200>"$RUNTIME/theme-next/waybar.lock"
