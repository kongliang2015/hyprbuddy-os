#!/usr/bin/env bash
# hyprshell GTK4 CSS 变量覆盖（自动热重载）
# （P2 从 theme-next 拆分；由编排器 source，T_* 环境由 exporters/lib.sh 的 theme_env_load 提供）
# ── hyprshell（overview / switch / launcher；GTK4 CSS 变量，自动热重载）──────
# 官方样式用 var(--bg-window-color) 之类的自定义属性，所以只要在 * 上覆盖变量即可，
# 不必猜它的类名；文件会被 mv 覆盖成实体文件（install.sh 建的是指向 store 的软链）。
HS_STYLE="$XDG_CONFIG_HOME/hyprshell/styles.css"
mkdir -p "$XDG_CONFIG_HOME/hyprshell"
HS_BG2="$(mixhex "$T_BG" "$T_FG" 10 | cut -c2-)"
HS_BG2H="$(mixhex "$T_BG" "$T_FG" 16 | cut -c2-)"
cat > "$HS_STYLE.tmp.$$" <<HSCSS
/* 由 theme-next 生成，勿手改；改配色请改主题表 */
* {
  font-family: "JetBrainsMono Nerd Font", "Noto Sans CJK SC";
  --border-radius: 12px;
  --border-size: 2px;
  --border-style: solid;
  --window-padding: 6px;
  --bg-window-color: rgba(${T_BG}, 0.72);   /* ç»çï¼éåºæ¡é¢ */
  --bg-color: rgba(${HS_BG2}, 0.55);
  --bg-color-hover: rgba(${T_ACCENT}, 0.18);
  --border-color: rgba(${T_ACCENT}, 0.38);
  --border-color-active: rgba(${T_ACCENT}, 0.95);
}
.monitor, .launcher {
  border-radius: 14px;
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.07), 0 10px 30px rgba(0,0,0,0.45);
}
.workspace, .client, .launcher-item-name { color: #${T_FG}; }
HSCSS
if [ -s "$HS_STYLE.tmp.$$" ]; then
  mv -f "$HS_STYLE.tmp.$$" "$HS_STYLE"
else
  rm -f "$HS_STYLE.tmp.$$"
fi
