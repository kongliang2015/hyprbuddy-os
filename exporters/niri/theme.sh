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

noctalia_theme_apply() {
  local dir="${NOCTALIA_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/noctalia}"
  dir="${dir%/}"
  mkdir -p "$dir" || return 1
  local colors="$dir/colors.json" settings="$dir/settings.json"

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
    jq --argjson dark "$mode" \
      '.colorSchemes.useWallpaperColors = false
       | .colorSchemes.predefinedScheme = null
       | .colorSchemes.darkMode = $dark' \
      "$settings" > "$settings.tmp.$$" 2>/dev/null && [ -s "$settings.tmp.$$" ] \
      && mv -f "$settings.tmp.$$" "$settings" || rm -f "$settings.tmp.$$"
  else
    jq -n --argjson dark "$mode" \
      '{colorSchemes: {useWallpaperColors: false, predefinedScheme: null, darkMode: $dark}}' \
      > "$settings.tmp.$$" 2>/dev/null && mv -f "$settings.tmp.$$" "$settings" || rm -f "$settings.tmp.$$"
  fi

  echo "noctalia: $T_NAME -> $dir"
}
