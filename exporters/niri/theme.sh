#!/usr/bin/env bash
# Noctalia 主题 exporter（N3）：tokens 配色 → Noctalia colors.json + settings.json。
#
# 依据 N0 调研（docs/niri-noctalia-plan.md）：
#   - 配置目录 $XDG_CONFIG_HOME/noctalia/（NOCTALIA_CONFIG_DIR 可覆盖，用于测试）
#   - colors.json 结构 { "dark": {...}, "light": {...} }，Material 风格键；
#     目录级 watcher 会热加载本文件
#   - settings.json 的 colorSchemes.predefinedScheme 非空时启动会重新 apply
#     预设并覆盖 colors.json → 必须清空（jq 合并写，保留其余键）
#   - darkMode 跟随 tokens.dark（两段写同一色板，明暗由 darkMode 决定）


# fuzzel：整份重写（fuzzel 每次启动都重读配置，不需要热加载）。
# [main]/[border] 保持不变，[colors] 由 tokens 派生；fuzzel 的颜色是 rrggbb[aa]，不带 #。
fuzzel_theme_apply() {
  local dir="${XDG_CONFIG_HOME:-$HOME/.config}/fuzzel"
  local f="$dir/fuzzel.ini"
  mkdir -p "$dir" || return 1
  rm -f "$f"   # 可能是 install.sh 链接过来的 store 软链
  cat > "$f.tmp.$$" <<FUZZEL && mv -f "$f.tmp.$$" "$f" || { rm -f "$f.tmp.$$"; return 1; }
# fuzzel 启动器配置（由 exporters/niri/theme.sh 生成，勿手改）
[main]
font=JetBrainsMono Nerd Font:size=12
prompt="  "
icons-enabled=yes
terminal=kitty
lines=12
width=40
line-height=28

[colors]
background=@BG@ff
text=@FG@ff
match=@ACCENT@ff
selection=@SURFACE@ff
selection-text=@FG@ff
selection-match=@ACCENT2@ff
border=@ACCENT@ff

[border]
width=2
radius=10
FUZZEL
  sed -i -e "s/@BG@/$T_BG/" -e "s/@FG@/$T_FG/" -e "s/@ACCENT2@/$T_ACCENT2/" \
         -e "s/@ACCENT@/$T_ACCENT/" -e "s/@SURFACE@/$T_SURFACE/" "$f"
}

# kitty：把 tokens 的终端 16 色写成 include 文件并热加载已运行实例。
# 终端用 tokens 的色板而不是 Material 键：16 个 ANSI 色是专为终端调的，
# 从 Material 的 10 来个键反推只会更差。两者同源（同一份 tokens），不会漂移。
kitty_theme_apply() {
  local dir="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"
  local f="$dir/theme.inc.conf"
  mkdir -p "$dir" || return 1
  {
    printf 'foreground #%s\n' "$T_TERM_FG"
    printf 'background #%s\n' "$T_TERM_BG"
    printf 'cursor #%s\n' "$T_TERM_CURSOR"
    printf 'cursor_text_color #%s\n' "$T_TERM_BG"
    printf 'selection_background #%s\n' "$T_TERM_FG"
    printf 'selection_foreground #%s\n' "$T_TERM_BG"
    local i
    for i in $(seq 0 15); do
      local v; eval "v=\$T_TERM_C$i"
      printf 'color%-2s #%s\n' "$i" "${v:-$T_TERM_FG}"
    done
  } > "$f.tmp.$$" && mv -f "$f.tmp.$$" "$f" || { rm -f "$f.tmp.$$"; return 1; }
  # 只在 kitty 内部执行（KITTY_LISTEN_ON 存在才有可用 socket）；
  # 且必须 -k：客户端卡在失效 socket 上时 SIGTERM 不会返回，会把登录钩子一起拖死（实测 3 分钟）。
  if [ -n "${KITTY_LISTEN_ON:-}" ] && command -v kitty >/dev/null 2>&1; then
    timeout -k 2 3 kitty @ set-colors -a "$f" >/dev/null 2>&1 || true
  fi
}

noctalia_theme_apply() {
  local slug="${1:-theme}"
  local dir="${NOCTALIA_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/noctalia}"
  dir="${dir%/}"
  local sdir="$dir/colorschemes/$slug"
  mkdir -p "$sdir" || return 1
  local colors="$sdir/$slug.json" settings="$dir/settings.json"

  # 终端色板：tokens.terminal.colors 为 16 项标准排布
  # （[0]=黑/底色，[1..7]=red..white，[8..15]=bright black..bright white）
  local c=("$T_TERM_C0" "$T_TERM_C1" "$T_TERM_C2" "$T_TERM_C3" "$T_TERM_C4" \
           "$T_TERM_C5" "$T_TERM_C6" "$T_TERM_C7" "$T_TERM_C8" "$T_TERM_C9" \
           "$T_TERM_C10" "$T_TERM_C11" "$T_TERM_C12" "$T_TERM_C13" "$T_TERM_C14" "$T_TERM_C15")
  local white="${c[15]:-$T_TERM_FG}"

  emit_scheme() {
    printf '  "%s": {\n' "$1"
    printf '    "mPrimary": "#%s",\n' "$T_ACCENT"
    printf '    "mOnPrimary": "#%s",\n' "$T_BG"
    printf '    "mSecondary": "#%s",\n' "$T_ACCENT2"
    printf '    "mOnSecondary": "#%s",\n' "$T_BG"
    printf '    "mTertiary": "#%s",\n' "$T_BAR_PULSE"
    printf '    "mOnTertiary": "#%s",\n' "$T_BG"
    printf '    "mError": "#%s",\n' "$T_URGENT"
    printf '    "mOnError": "#%s",\n' "$T_BG"
    printf '    "mSurface": "#%s",\n' "$T_BG"
    printf '    "mOnSurface": "#%s",\n' "$T_FG"
    printf '    "mSurfaceVariant": "#%s",\n' "$T_SURFACE"
    printf '    "mOnSurfaceVariant": "#%s",\n' "$T_MUTED"
    printf '    "mOutline": "#%s",\n' "$T_INACTIVE"
    printf '    "mShadow": "#%s",\n' "$T_BG"
    printf '    "mHover": "#%s",\n' "$T_ACCENT"
    printf '    "mOnHover": "#%s",\n' "$T_BG"
    printf '    "terminal": {\n'
    printf '      "normal": {\n'
    printf '        "black": "#%s", "red": "#%s", "green": "#%s",\n' "${c[0]}" "${c[1]}" "${c[2]}"
    printf '        "yellow": "#%s", "blue": "#%s", "magenta": "#%s",\n' "${c[3]}" "${c[4]}" "${c[5]}"
    printf '        "cyan": "#%s", "white": "#%s"\n' "${c[6]}" "${c[7]}"
    printf '      },\n'
    printf '      "bright": {\n'
    printf '        "black": "#%s", "red": "#%s", "green": "#%s",\n' "${c[8]}" "${c[9]}" "${c[10]}"
    printf '        "yellow": "#%s", "blue": "#%s", "magenta": "#%s",\n' "${c[11]}" "${c[12]}" "${c[13]}"
    printf '        "cyan": "#%s", "white": "#%s"\n' "${c[14]}" "$white"
    printf '      }\n'
    printf '    }\n'
    printf '  }'
  }

  {
    printf '{\n'
    emit_scheme dark; printf ',\n'
    emit_scheme light; printf '\n}\n'
  } > "$colors.tmp.$$" && mv -f "$colors.tmp.$$" "$colors" || {
    rm -f "$colors.tmp.$$"
    return 1
  }

  # settings.json：清空预设方案 + 关闭壁纸取色 + 明暗跟随 tokens
  local mode=false
  [ "$T_DARK" = true ] && mode=true
  if [ -f "$settings" ]; then
    jq --arg s "$slug" --argjson dark "$mode" \
      '.colorSchemes.useWallpaperColors = false
       | .colorSchemes.predefinedScheme = $s
       | .colorSchemes.darkMode = $dark
' \
      "$settings" > "$settings.tmp.$$" 2>/dev/null && [ -s "$settings.tmp.$$" ] \
      && mv -f "$settings.tmp.$$" "$settings" || rm -f "$settings.tmp.$$"
  else
    jq -n --arg s "$slug" --argjson dark "$mode" \
      '{colorSchemes: {useWallpaperColors: false, predefinedScheme: $s, darkMode: $dark}}' \
      > "$settings.tmp.$$" 2>/dev/null && mv -f "$settings.tmp.$$" "$settings" || rm -f "$settings.tmp.$$"
  fi

  # 热应用：已在运行的 Noctalia 立即切换
  # 运行中的 shell 只认启动时扫描到的方案列表；新方案（首次使用）不在列表里，
  # IPC set 会失败。detect：colors.json 未在 1.5s 内更新则重启 shell
  # （重启后启动扫描会收录新方案，并按 settings.predefinedScheme 应用）。
  local marker="$dir/colors.json"
  local before=""
  [ -f "$marker" ] && before=$(stat -c %Y "$marker" 2>/dev/null)
  if command -v noctalia-shell >/dev/null 2>&1; then
    noctalia-shell ipc call colorScheme set "$slug" >/dev/null 2>&1 || true
  fi
  if pgrep -f 'bin/quickshell -p' >/dev/null 2>&1; then
    sleep 1.5
    local after=""
    [ -f "$marker" ] && after=$(stat -c %Y "$marker" 2>/dev/null)
    if [ "$before" = "$after" ]; then
      pkill -f 'bin/quickshell -p' 2>/dev/null
      sleep 0.5
      setsid noctalia-shell >/dev/null 2>&1 < /dev/null &
      echo "noctalia: scheme 未在运行实例中，已重启 shell（首次使用该方案）"
    fi
  fi

  # 壁纸：主题自带 PNG → Noctalia 壁纸服务
  # （awww 的壁纸层会被 Noctalia 壁纸层盖住，统一以 Noctalia 为准；
  #   重启后的 shell 需要约 20s 就绪，这里带重试）
  # 注意：settings.wallpaper.directory 会被 Noctalia 启动时强制重置为默认目录，
  # 不能靠它做扫描；直接传绝对路径。优先与 Hyprland 栈共用的 ~/Pictures/wallpapers。
  local wp=""
  for cand in "$HOME/Pictures/wallpapers/$T_WALLPAPER" "$THEMES_DIR/$T_SLUG/$T_WALLPAPER"; do
    if [ -f "$cand" ]; then wp="$cand"; break; fi
  done
  if [ -n "$wp" ] && command -v noctalia-shell >/dev/null 2>&1; then
    # 就绪探测：wallpaper get 返回非空说明服务已起来（裸 set 在未就绪时也会返回 0）
    for _ in $(seq 1 40); do
      cur=$(noctalia-shell ipc call wallpaper get all 2>/dev/null)
      if [ -n "$cur" ]; then
        noctalia-shell ipc call wallpaper set "$wp" all >/dev/null 2>&1 && break
      fi
      sleep 1
    done
  fi

  kitty_theme_apply && echo "kitty: theme.inc.conf <- $T_NAME" || echo "kitty: 写入失败（终端配色未更新）"
  fuzzel_theme_apply && echo "fuzzel: fuzzel.ini <- $T_NAME" || echo "fuzzel: 写入失败（启动器配色未更新）"
  echo "noctalia: $T_NAME ($slug) -> $colors"
}
