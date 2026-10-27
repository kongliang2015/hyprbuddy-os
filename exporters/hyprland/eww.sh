#!/usr/bin/env bash
# eww scss 重写 + reload 热加载
# （P2 从 theme-next 拆分；由编排器 source，T_* 环境由 exporters/lib.sh 的 theme_env_load 提供）
# ── eww（日历/会话弹窗；整份 scss 重写，eww reload 热加载）───────────────
# 用带引号的 heredoc（不做 shell 展开）+ sed 占位替换：scss 的 $var 与
# theme 的 ${...} 混在一起时，无引号 heredoc 会在 set -u 下炸掉。
EW="$XDG_CONFIG_HOME/eww/eww.scss"
mkdir -p "$XDG_CONFIG_HOME/eww"
cat > "$EW.tmp.$$" <<'EWWSCSS'
// 由 theme-next 生成，勿手改
$bg: #@BG@;
$bg2: #@BG2@;
$fg: #@FG@;
$muted: #@MUTED@;
$accent: #@ACCENT@;
$accent2: #@ACCENT2@;
$border: rgba(#@ACCENT@, 0.28);

* { all: unset; font-family: "JetBrainsMono Nerd Font", "Noto Sans CJK SC"; }
.card { background: $bg; border: 1px solid $border; border-radius: 14px; padding: 12px; color: $fg; }
.card-title { color: $accent; font-weight: bold; font-size: 14px; padding-bottom: 6px; }
.cal { color: $fg; }
.cal:selected { background: $accent; color: $bg; }
.card-btn { background: $bg2; border: 1px solid $border; border-radius: 8px; padding: 6px 10px; color: $fg; }
.card-btn:hover { color: $accent; border-color: $accent; }
EWWSCSS
sed -i -e "s/@BG@/$T_BG/g" -e "s/@BG2@/$SN_BG2/g" -e "s/@FG@/$T_FG/g" \
       -e "s/@MUTED@/$T_MUTED/g" -e "s/@ACCENT@/$T_ACCENT/g" -e "s/@ACCENT2@/$T_ACCENT2/g" \
       "$EW.tmp.$$" 2>/dev/null || true
if [ -s "$EW.tmp.$$" ]; then
  mv -f "$EW.tmp.$$" "$EW"
  timeout 3 eww reload >/dev/null 2>&1 || true
else
  rm -f "$EW.tmp.$$"
fi
