#!/usr/bin/env bash
# COSMIC 主题 exporter（P2）：把 tokens 配色写入 cosmic-themes RON。
#
# 用法：de_theme_apply（de.sh）调用；或 source exporters/lib.sh + theme_env_load
#      <slug> 后 source 本文件并调用 cosmic_theme_apply。
#
# 生成规则（基于对 libcosmic 写盘格式的逐文件实测）：
#   - accent 系：base=T_ACCENT；hover=×0.88、pressed=×0.62、selected=hover；
#     selected_text/focus/border/disabled=base；divider/on=黑；on_disabled=×0.5
#   - background/primary/secondary：base 与 component 各态 = bg 与 fg 的线性
#     mix（pct 从现有主题实测得到，常数化）；selected_text/focus=accent
#   - button：base=mix(bg,fg,0.64) α0.25，各态只变 alpha；text 点缀=accent
#   - destructive/success/warning 系：语义色（亮红/绿/黄），不随主题变
#   - link/text/icon_button：透明底 + accent 文字
#   - palette/spacing：保留现有文件（palette.name 换成主题 slug）
#   - Mode/v1/is_dark 按 tokens.dark 同步（浅色主题会翻转全局明暗模式）
#
# 测试：COSMIC_THEME_DIR_OVERRIDE=<目录> 把写入重定向到副本，不动真实配置。
#
# 限制：cosmic-themes 无 CSS/层模糊概念，主题的模糊/胶囊样式不迁移
# （能力降级，见 docs/desktop-abstraction.md 风险表）。

cosmic_theme_apply() {
  local mode_dir mode_flag base
  if [ "$T_DARK" = true ]; then mode_dir=Dark; mode_flag=true; else mode_dir=Light; mode_flag=false; fi
  base="${COSMIC_THEME_DIR_OVERRIDE:-$HOME/.config/cosmic/com.system76.CosmicTheme.$mode_dir/v1}"
  [ -d "$base" ] || { echo "cosmic_theme_apply: 主题目录不存在: $base" >&2; return 1; }

  # ── 颜色工具 ──
  h2f() { awk -v h="$1" "BEGIN { printf \"%.7g\", strtonum(\"0x\" h) / 255 }"; }
  mixf() { awk -v a="$1" -v b="$2" -v p="$3" "BEGIN { printf \"%.7g\", a + (b - a) * p }"; }
  dimf() { awk -v a="$1" -v f="$2" "BEGIN { printf \"%.7g\", a * f }"; }
  st() { # <缩进> <state名> <r> <g> <b> <alpha>
    local pad; pad=$(printf "%*s" "$1" "")
    printf "%s%s: (\n" "$pad" "$2"
    printf "%s  red: %s,\n%s  green: %s,\n%s  blue: %s,\n%s  alpha: %s,\n" "$pad" "$3" "$pad" "$4" "$pad" "$5" "$pad" "$6"
    printf "%s),\n" "$pad"
  }
  atomic() { local tmp; tmp=$(mktemp); cat > "$tmp" && mv -f "$tmp" "$1"; }

  # ── 新配色（RON 浮点） ──
  local aR aG aB a2R a2G a2B bR bG bB fR fG fB
  aR=$(h2f "${T_ACCENT:0:2}"); aG=$(h2f "${T_ACCENT:2:2}"); aB=$(h2f "${T_ACCENT:4:2}")
  a2R=$(h2f "${T_ACCENT2:0:2}"); a2G=$(h2f "${T_ACCENT2:2:2}"); a2B=$(h2f "${T_ACCENT2:4:2}")
  bR=$(h2f "${T_BG:0:2}"); bG=$(h2f "${T_BG:2:2}"); bB=$(h2f "${T_BG:4:2}")
  fR=$(h2f "${T_FG:0:2}"); fG=$(h2f "${T_FG:2:2}"); fB=$(h2f "${T_FG:4:2}")
  # accent 派生态（实测常数：hover≈×0.88、pressed≈×0.62）
  local hR hG hB pR pG pB
  hR=$(dimf "$aR" 0.88); hG=$(dimf "$aG" 0.88); hB=$(dimf "$aB" 0.88)
  pR=$(dimf "$aR" 0.62); pG=$(dimf "$aG" 0.62); pB=$(dimf "$aB" 0.62)
  # 背景派生中性（实测 pct：component base/hover/pressed = mix(bg,fg,0.13/0.23/0.33)）
  local sR sG sB sHr sHg sHb sPr sPg sPb
  sR=$(mixf "$bR" "$fR" 0.13); sG=$(mixf "$bG" "$fG" 0.13); sB=$(mixf "$bB" "$fB" 0.13)
  sHr=$(mixf "$bR" "$fR" 0.23); sHg=$(mixf "$bG" "$fG" 0.23); sHb=$(mixf "$bB" "$fB" 0.23)
  sPr=$(mixf "$bR" "$fR" 0.33); sPg=$(mixf "$bG" "$fG" 0.33); sPb=$(mixf "$bB" "$fB" 0.33)
  local dvR dvG dvB bdR bdG bdB swR swG swB
  dvR=$(mixf "$bR" "$fR" 0.20); dvG=$(mixf "$bG" "$fG" 0.20); dvB=$(mixf "$bB" "$fB" 0.20)
  bdR=$(mixf "$bR" "$fR" 0.79); bdG=$(mixf "$bG" "$fG" 0.79); bdB=$(mixf "$bB" "$fB" 0.79)
  swR=$(mixf "$bR" "$fR" 0.06); swG=$(mixf "$bG" "$fG" 0.06); swB=$(mixf "$bB" "$fB" 0.06)

  # ── 语义色（亮红/绿/黄，来自 COSMIC 标准调色板，不随主题变） ──
  local dR=0.99215686 dG=0.6313726 dB=0.627451
  local cR=0.57254905 cG=0.8117647 cB=0.6117647
  local wR=0.96862745 wG=0.8784314 wB=0.38431373
  local dHr dHg dHb dPr dPg dPb cHr cHg cHb cPr cPg cPb wHr wHg wHb wPr wPg wPb
  dHr=$(dimf "$dR" 0.88); dHg=$(dimf "$dG" 0.88); dHb=$(dimf "$dB" 0.88)
  dPr=$(dimf "$dR" 0.62); dPg=$(dimf "$dG" 0.62); dPb=$(dimf "$dB" 0.62)
  cHr=$(dimf "$cR" 0.88); cHg=$(dimf "$cG" 0.88); cHb=$(dimf "$cB" 0.88)
  cPr=$(dimf "$cR" 0.62); cPg=$(dimf "$cG" 0.62); cPb=$(dimf "$cB" 0.62)
  wHr=$(dimf "$wR" 0.88); wHg=$(dimf "$wG" 0.88); wHb=$(dimf "$wB" 0.88)
  wPr=$(dimf "$wR" 0.62); wPg=$(dimf "$wG" 0.62); wPb=$(dimf "$wB" 0.62)

  # ── accent 系（accent / accent_button 同形） ──
  emit_accent_like() { local f=$1; {
    echo "("
    st 4 base "$aR" "$aG" "$aB" 1.0
    st 4 hover "$hR" "$hG" "$hB" 1.0
    st 4 pressed "$pR" "$pG" "$pB" 1.0
    st 4 selected "$hR" "$hG" "$hB" 1.0
    st 4 selected_text "$aR" "$aG" "$aB" 1.0
    st 4 focus "$aR" "$aG" "$aB" 1.0
    st 4 divider 0.0 0.0 0.0 1.0
    st 4 on 0.0 0.0 0.0 1.0
    st 4 disabled "$aR" "$aG" "$aB" 1.0
    st 4 on_disabled 0.0 0.0 0.0 0.5
    st 4 border "$aR" "$aG" "$aB" 1.0
    st 4 disabled_border "$aR" "$aG" "$aB" 0.5
    echo ")"
  } | atomic "$f"; }

  # ── background / primary / secondary（嵌套 component 形） ──
  # $1=file $2=base偏移 $3=component base $4=hover $5=pressed
  emit_nested() {
    local f=$1 bo=$2 cb=$3 hv=$4 pr=$5
    local mR mG mB mHr mHg mHb mPr mPg mPb
    mR=$(mixf "$bR" "$fR" "$bo"); mG=$(mixf "$bG" "$fG" "$bo"); mB=$(mixf "$bB" "$fB" "$bo")
    mHr=$(mixf "$bR" "$fR" "$hv"); mHg=$(mixf "$bG" "$fG" "$hv"); mHb=$(mixf "$bB" "$fB" "$hv")
    mPr=$(mixf "$bR" "$fR" "$pr"); mPg=$(mixf "$bG" "$fG" "$pr"); mPb=$(mixf "$bB" "$fB" "$pr")
    {
      echo "("
      st 4 base "$mR" "$mG" "$mB" 1.0
      printf "    component: (\n"
      st 8 base "$sR" "$sG" "$sB" 1.0
      st 8 hover "$sHr" "$sHg" "$sHb" 1.0
      st 8 pressed "$sPr" "$sPg" "$sPb" 1.0
      st 8 selected "$sHr" "$sHg" "$sHb" 1.0
      st 8 selected_text "$aR" "$aG" "$aB" 1.0
      st 8 focus "$aR" "$aG" "$aB" 1.0
      st 8 divider "$bdR" "$bdG" "$bdB" 0.2
      st 8 on "$fR" "$fG" "$fB" 1.0
      st 8 disabled "$sR" "$sG" "$sB" 0.5
      st 8 on_disabled "$fR" "$fG" "$fB" 0.65
      st 8 border "$bdR" "$bdG" "$bdB" 1.0
      st 8 disabled_border "$bdR" "$bdG" "$bdB" 0.5
      printf "    ),\n"
      st 4 divider "$dvR" "$dvG" "$dvB" 1.0
      st 4 on "$fR" "$fG" "$fB" 1.0
      st 4 small_widget "$swR" "$swG" "$swB" 0.25
      echo ")"
    } | atomic "$f"
  }

  # ── 语义色组件（destructive/success/warning 系，同 accent 形但用语义色） ──
  emit_semantic() { # <file> <r> <g> <b> <on=黑|白>
    local f=$1 r=$2 g=$3 b=$4
    local Hr Hg Hb Pr Pg Pb
    Hr=$(dimf "$r" 0.88); Hg=$(dimf "$g" 0.88); Hb=$(dimf "$b" 0.88)
    Pr=$(dimf "$r" 0.62); Pg=$(dimf "$g" 0.62); Pb=$(dimf "$b" 0.62)
    {
      echo "("
      st 4 base "$r" "$g" "$b" 1.0
      st 4 hover "$Hr" "$Hg" "$Hb" 1.0
      st 4 pressed "$Pr" "$Pg" "$Pb" 1.0
      st 4 selected "$Hr" "$Hg" "$Hb" 1.0
      st 4 selected_text "$aR" "$aG" "$aB" 1.0
      st 4 focus "$aR" "$aG" "$aB" 1.0
      st 4 divider 0.0 0.0 0.0 1.0
      st 4 on 0.0 0.0 0.0 1.0
      st 4 disabled "$r" "$g" "$b" 1.0
      st 4 on_disabled 0.0 0.0 0.0 0.5
      st 4 border "$r" "$g" "$b" 1.0
      st 4 disabled_border "$r" "$g" "$b" 0.5
      echo ")"
    } | atomic "$f"
  }

  # ── 透明按钮（link/text/icon） ──
  emit_transparent() { # <file> <hover灰r g b> <divider/on 用 accent?>
    local f=$1 hR2=$2 hG2=$3 hB2=$4
    {
      echo "("
      st 4 base 0.0 0.0 0.0 0.0
      st 4 hover "$hR2" "$hG2" "$hB2" 0.2
      st 4 pressed "$sR" "$sG" "$sB" 0.5
      st 4 selected "$hR2" "$hG2" "$hB2" 0.2
      st 4 selected_text "$aR" "$aG" "$aB" 1.0
      st 4 focus "$aR" "$aG" "$aB" 1.0
      st 4 divider "$aR" "$aG" "$aB" 0.2
      st 4 on "$aR" "$aG" "$aB" 1.0
      st 4 disabled 0.0 0.0 0.0 0.0
      st 4 on_disabled "$aR" "$aG" "$aB" 0.65
      st 4 border "$bdR" "$bdG" "$bdB" 1.0
      st 4 disabled_border "$bdR" "$bdG" "$bdB" 0.5
      echo ")"
    } | atomic "$f"
  }

  # ── 写盘 ──
  emit_accent_like "$base/accent"
  emit_accent_like "$base/accent_button"
  emit_nested "$base/background" 0 0.13 0.23 0.33
  emit_nested "$base/primary" 0.06 0.16 0.26 0.36
  emit_nested "$base/secondary" 0.12 0.19 0.29 0.39
  emit_semantic "$base/destructive" "$dR" "$dG" "$dB"
  emit_semantic "$base/destructive_button" "$dR" "$dG" "$dB"
  emit_semantic "$base/success" "$cR" "$cG" "$cB"
  emit_semantic "$base/warning" "$wR" "$wG" "$wB"
  emit_semantic "$base/warning_button" "$wR" "$wG" "$wB"
  emit_transparent "$base/link_button" "$sHr" "$sHg" "$sHb"
  emit_transparent "$base/text_button" "$sHr" "$sHg" "$sHb"
  emit_transparent "$base/icon_button" "$sHr" "$sHg" "$sHb"

  # button：中性胶囊（base=mix(bg,fg,0.64) α0.25，各态只变 alpha）
  local btR btG btB
  btR=$(mixf "$bR" "$fR" 0.64); btG=$(mixf "$bG" "$fG" 0.64); btB=$(mixf "$bB" "$fB" 0.64)
  {
    echo "("
    st 4 base "$btR" "$btG" "$btB" 0.25
    st 4 hover "$btR" "$btG" "$btB" 0.4
    st 4 pressed "$btR" "$btG" "$btB" 0.625
    st 4 selected "$btR" "$btG" "$btB" 0.4
    st 4 selected_text "$aR" "$aG" "$aB" 1.0
    st 4 focus "$aR" "$aG" "$aB" 1.0
    st 4 divider "$fR" "$fG" "$fB" 0.2
    st 4 on "$fR" "$fG" "$fB" 1.0
    st 4 disabled "$btR" "$btG" "$btB" 0.125
    st 4 on_disabled "$fR" "$fG" "$fB" 0.65
    st 4 border "$bdR" "$bdG" "$bdB" 1.0
    st 4 disabled_border "$bdR" "$bdG" "$bdB" 0.5
    echo ")"
  } | atomic "$base/button"

  # palette：name 换成主题 slug（其余槽位保留官方值）
  if [ -f "$base/palette" ]; then
    sed -E "0,/name: \"[^\"]*\"/s//name: \"$T_SLUG\"/" "$base/palette" > "$base/palette.tmp" \
      && [ -s "$base/palette.tmp" ] && mv -f "$base/palette.tmp" "$base/palette" || rm -f "$base/palette.tmp"
  fi

# ── 形状与间距（可选：tokens.json 里给了才写，其余主题保持官方默认）──
  local tok="$THEMES_DIR/$T_SLUG/tokens.json"
  if [ -r "$tok" ] && jq -e '.corner_radii' "$tok" >/dev/null 2>&1; then
    {
      echo "("
      for k in 0 xs s m l xl; do
        v=$(jq -r --arg k "$k" '.corner_radii[$k] // empty' "$tok")
        [ -n "$v" ] && printf '    radius_%s: (%s, %s, %s, %s),\n' "$k" "$v" "$v" "$v" "$v"
      done
      echo ")"
    } | atomic "$base/corner_radii"
  fi
  if [ -r "$tok" ] && jq -e '.spacing' "$tok" >/dev/null 2>&1; then
    {
      echo "("
      for k in none xxxs xxs xs s m l xl xxl xxxl; do
        v=$(jq -r --arg k "$k" '.spacing[$k] // empty' "$tok")
        [ -n "$v" ] && printf '    space_%s: %s,\n' "$k" "$v"
      done
      echo ")"
    } | atomic "$base/spacing"
  else
    # 主题没定义形状时回到 COSMIC 官方默认，避免上一套主题的圆角/间距残留
    {
      echo "("
      printf '    radius_0: (0, 0, 0, 0),\n'
      printf '    radius_xs: (4, 4, 4, 4),\n'
      printf '    radius_s: (8, 8, 8, 8),\n'
      printf '    radius_m: (16, 16, 16, 16),\n'
      printf '    radius_l: (32, 32, 32, 32),\n'
      printf '    radius_xl: (160, 160, 160, 160),\n'
      echo ")"
    } | atomic "$base/corner_radii"
    {
      echo "("
      local i=0
      for v in 0 4 8 12 16 24 32 48 64 128; do
        printf '    space_%s: %s,\n' "$(echo none xxxs xxs xs s m l xl xxl xxxl | cut -d' ' -f$((i+1)))" "$v"
        i=$((i + 1))
      done
      echo ")"
    } | atomic "$base/spacing"
  fi

  # 明暗模式同步（浅色主题会翻转全局模式）
  local mode_file="$HOME/.config/cosmic/com.system76.CosmicTheme.Mode/v1/is_dark"
  if [ -f "$mode_file" ] && [ "${COSMIC_THEME_DIR_OVERRIDE:-}" = "" ]; then
    local cur; cur=$(cat "$mode_file" 2>/dev/null | tr -d "[:space:]")
    [ "$cur" = "$mode_flag" ] || printf "%s" "$mode_flag" > "$mode_file"
  fi

  # 壁纸绑定：复用能力层（cosmic-bg 热加载）
  local de_sh=""
  for cand in "$THEME_LIB_DIR/../lib/de.sh" \
              "$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")/scripts/lib/de.sh"; do
    [ -r "$cand" ] && de_sh=$cand && break
  done
  if [ -n "$de_sh" ]; then
    . "$de_sh"
    de_wallpaper_set "$HOME/Pictures/wallpapers/${T_WALLPAPER}" >/dev/null 2>&1 || true
  fi
  echo "cosmic: $T_NAME -> $mode_dir"
}
