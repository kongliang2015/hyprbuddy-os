#!/usr/bin/env bash
# swaync 整份 CSS 重写 + reload 热加载
# （P2 从 theme-next 拆分；由编排器 source，T_* 环境由 exporters/lib.sh 的 theme_env_load 提供）
# ── swaync（通知中心 + 控制中心；整份 CSS 重写，reload 热加载）────────────
# 从 mako 迁移：卡片底 = 主题底向正文提亮 8%，描边 = 底×强调色 28%，
# 与 waybar/hyprtoolkit 共用同一套推导，视觉不割裂。
SN_BG2="$(mixhex "$T_BG" "$T_FG" 8 | cut -c2-)"
# 正文色：muted 向 fg 提 35%（原始 muted 在卡片底上对比度只有 2.8:1，几乎看不见）
SN_FMT="$(mixhex "$T_MUTED" "$T_FG" 35 | cut -c2-)"
SWAYNC="$XDG_CONFIG_HOME/swaync/style.css"
mkdir -p "$XDG_CONFIG_HOME/swaync"
cat > "$SWAYNC.tmp.$$" <<SWAYNCCSS
/* 由 theme-next 生成，勿手改；改配色请改主题表 */
@define-color bg      #${T_BG};
@define-color bg2     #${SN_BG2};
@define-color fg      #${T_FG};
@define-color muted   #${SN_FMT};
@define-color accent  #${T_ACCENT};
@define-color accent2 #${T_ACCENT2};
@define-color border  alpha(#${T_ACCENT}, 0.38);
@define-color urgent  #${T_URGENT};

* {
  font-family: "JetBrainsMono Nerd Font", "Noto Sans CJK SC", sans-serif;
  font-size: 13px;
}

.control-center {
  background: alpha(@bg, 0.94);
  border: 1px solid @border;
  border-radius: 14px;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.06), 0 12px 32px rgba(0, 0, 0, 0.45);
}
.control-center-list { background: transparent; }

.widget-title { color: @accent; font-weight: bold; margin: 8px 12px 4px 12px; }
.widget-title > button {
  background: alpha(@bg2, 0.55); color: @muted;
  border: 1px solid @border; border-radius: 8px; padding: 2px 10px;
}
.widget-title > button:hover { color: @urgent; }

.widget-dnd { color: @fg; margin: 4px 14px; }
.widget-dnd > switch { background: alpha(@bg2, 0.55); border: 1px solid @border; border-radius: 999px; }
.widget-dnd > switch:checked { background: @accent; }

.notification-row { background: transparent; outline: none; }
.notification {
  background: alpha(@bg2, 0.72);
  border: 1px solid @border;
  border-radius: 12px;
  margin: 6px 8px;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.07);
}
.notification-content { padding: 10px 12px; }
.summary { color: @fg; font-weight: bold; }
.body { color: @muted; }
.time { color: @muted; }
.close-button { background: transparent; color: @muted; border-radius: 999px; }
.close-button:hover { color: @urgent; }
.notification.critical { border-color: @urgent; }

.widget-buttons-grid { margin: 6px 8px; background: transparent; }
.widget-buttons-grid > flowbox > flowboxchild > button {
  background: alpha(@bg2, 0.55);
  border: 1px solid @border;
  border-radius: 10px;
  color: @fg;
  padding: 8px 4px;
  min-height: 26px;
  font-size: 12px;
}
.widget-buttons-grid > flowbox > flowboxchild > button:hover {
  background: alpha(@accent, 0.18); color: @accent; border-color: alpha(@accent, 0.5);
}
.widget-buttons-grid > flowbox > flowboxchild > button:checked {
  background: alpha(@accent, 0.28); color: @accent;
}

.widget-mpris {
  background: alpha(@bg2, 0.72);
  border: 1px solid @border; border-radius: 12px;
  margin: 6px 8px; color: @fg;
}
.widget-volume {
  background: alpha(@bg2, 0.72);
  border: 1px solid @border; border-radius: 12px;
  margin: 6px 8px; padding: 6px 10px; color: @accent;
}
.widget-volume > box > label { color: @fg; }
SWAYNCCSS
if [ -s "$SWAYNC.tmp.$$" ]; then
  mv -f "$SWAYNC.tmp.$$" "$SWAYNC"
  timeout 3 swaync-client -rs >/dev/null 2>&1 || true
else
  rm -f "$SWAYNC.tmp.$$"
fi
