#!/usr/bin/env bash
# 主题系统公共库（P2）：tokens 加载 + 颜色工具。
# 被 theme-next / exporters/* / de.sh source，不独立执行。
# 定位：lib.sh 被部署在 share/hyprland-nixos/exporters/，themes 在其上级目录；
# 仓库内直接跑时同一相对结构也成立（exporters/ 与 themes/ 同级）。

# 注意不能用 readlink -f / cd 解析物理路径：部署时 lib.sh 是指向 store 的软链，
# 解析进 store 会丢掉 share/hyprland-nixos/ 的 themes/ 布局。保留逻辑路径。
THEME_LIB_DIR="$(dirname "${BASH_SOURCE[0]}")"
case "$THEME_LIB_DIR" in
  /*) : ;;
  *) THEME_LIB_DIR="$PWD/$THEME_LIB_DIR" ;;
esac
THEMES_DIR="${THEMES_DIR:-$THEME_LIB_DIR/../themes}"

command -v jq >/dev/null 2>&1 || { echo "theme lib: 需要 jq（home 包应已提供）" >&2; return 1 2>/dev/null || exit 1; }

# mixhex <A> <B> <pct> → #RRGGBB，pct% 偏向 B（用于派生中间色，与原 theme-next 一致）
mixhex() {
  local a=${1#\#} b=${2#\#} p=$3 i x y v out=""
  for i in 0 2 4; do
    x=$((16#${a:i:2})); y=$((16#${b:i:2}))
    v=$(( (x * (100 - p) + y * p + 50) / 100 ))
    printf -v out '%s%02X' "$out" "$v"
  done
  printf '#%s' "$out"
}

# theme_list：按 tokens.json 的 order 字段排序输出 slug 列表（保持 v0 索引顺序，
# 已存的 state idx 在迁移后指向同一主题）
theme_list() {
  local f d
  for f in "$THEMES_DIR"/*/tokens.json; do
    [ -e "$f" ] || continue
    d=$(basename "$(dirname "$f")")
    printf '%s\t%s\n' "$(jq -r '.order // 99' "$f")" "$d"
  done | sort -n | cut -f2
}

# theme_slug_at <idx>：第 idx 个主题的 slug（0 起）
theme_slug_at() {
  theme_list | sed -n "$(( $1 + 1 ))p"
}

# theme_env_load <slug>：把 tokens.json 展开为 T_* 环境变量。
# 终端色板为 16 项标准排布（[0]=黑/底色，[8..15]=bright）。
theme_env_load() {
  local slug=$1
  local f="$THEMES_DIR/$slug/tokens.json" j i
  [ -r "$f" ] || { echo "theme_env_load: 找不到 $f" >&2; return 1; }
  j=$(cat "$f")
  T_SLUG=$slug
  T_NAME=$(jq -r '.name' <<<"$j")
  T_WALLPAPER=$(jq -r '.wallpaper' <<<"$j")
  T_DARK=$(jq -r '.dark' <<<"$j")
  T_BG=$(jq -r '.bg' <<<"$j")
  T_FG=$(jq -r '.fg' <<<"$j")
  T_ACCENT=$(jq -r '.accent' <<<"$j")
  T_ACCENT2=$(jq -r '.accent2' <<<"$j")
  T_INACTIVE=$(jq -r '.inactive' <<<"$j")
  T_SURFACE=$(jq -r '.surface' <<<"$j")
  T_MUTED=$(jq -r '.muted' <<<"$j")
  T_URGENT=$(jq -r '.urgent' <<<"$j")
  T_BAR_CLOCK=$(jq -r '.bar.clock' <<<"$j")
  T_BAR_CPU=$(jq -r '.bar.cpu' <<<"$j")
  T_BAR_MEM=$(jq -r '.bar.mem' <<<"$j")
  T_BAR_BAT=$(jq -r '.bar.battery' <<<"$j")
  T_BAR_PULSE=$(jq -r '.bar.pulse' <<<"$j")
  T_BAR_AGENT=$(jq -r '.bar.agent' <<<"$j")
  T_TERM_BG=$(jq -r '.terminal.bg' <<<"$j")
  T_TERM_FG=$(jq -r '.terminal.fg' <<<"$j")
  T_TERM_CURSOR=$(jq -r '.terminal.cursor' <<<"$j")
  # 终端色板 v0 只有 15 项（K15 缺失是历史 bug），缺省位回落终端前景色
  for i in $(seq 0 15); do
    local v
    v=$(jq -r ".terminal.colors[$i] // .terminal.fg" <<<"$j")
    printf -v "T_TERM_C$i" '%s' "$v"
  done
}

