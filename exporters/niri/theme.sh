# Noctalia v5 主题 exporter（tokens → 外壳配色）。
#
# 事实（2026-10-29 实测 pkgs.noctalia 5.0.1）：
#   - 手写配置 ~/.config/noctalia/*.toml（按名排序合并）；GUI/运行态改动写
#     ~/.local/state/noctalia/settings.toml，且 state 优先级更高；
#   - 外壳配色由 [theme] source 决定：builtin | wallpaper | community | custom；
#   - 这里用 source = "wallpaper"：Noctalia 从当前壁纸派生 Material 调色板
#     （wallpaper_scheme = m3-tonal-spot），主题壁纸一换配色就跟着换；
#   - custom（~/.config/noctalia/palettes/<name>.json）配色更精确，但文件格式
#     在 5.0.1 上尚未跑通（16 色 m* / 完整 token 表 / 社区数组格式均被判 invalid），
#     待上游文档明确后再切，不要凭猜写死；
#   - IPC 是 `noctalia msg <cmd>`（wallpaper-set / color-scheme-set / theme-mode-set）。

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
  local mode="dark"
  [ "$T_DARK" = true ] && mode="dark" || mode="light"
  mkdir -p "$dir" || return 1

  # 主题壁纸：优先与 Hyprland 栈共用的 ~/Pictures/wallpapers，其次仓库 themes/<slug>/
  local wp=""
  local cand
  for cand in "$HOME/Pictures/wallpapers/$T_WALLPAPER" "$THEMES_DIR/$T_SLUG/$T_WALLPAPER"; do
    if [ -f "$cand" ]; then wp="$cand"; break; fi
  done

  # 手写基线（整份重写，与 fuzzel 同样的策略）：壁纸取色 + 明暗模式。
  # 注意 state/settings.toml 优先级更高，所以运行中的实例还要走 IPC 落一次。
  local f="$dir/theme.toml"
  cat > "$f.tmp.$$" <<NOCTALIA_THEME && mv -f "$f.tmp.$$" "$f" || { rm -f "$f.tmp.$$"; return 1; }
# 由 exporters/niri/theme.sh 生成，勿手改
[theme]
mode = "$mode"
source = "wallpaper"
wallpaper_scheme = "m3-tonal-spot"

[wallpaper]
enabled = true
# wallpaper-next/previous/random 需要目录（wallpaper-set 传绝对路径不依赖它）。
# 注意：5.0.1 不认 recursive 键（会 warn unknown setting），别加。
directory = "$HOME/Pictures/wallpapers"
NOCTALIA_THEME

  # 运行中的实例：壁纸会重新触发取色，mode/source 通过 IPC 同步进 state。
  if command -v noctalia >/dev/null 2>&1; then
    if [ -n "$wp" ]; then
      # 刚启动时 IPC socket 可能还没就绪，重试几轮
      for _ in $(seq 1 20); do
        noctalia msg wallpaper-set "$wp" >/dev/null 2>&1 && break
        sleep 0.5
      done
    fi
    noctalia msg color-scheme-set wallpaper m3-tonal-spot >/dev/null 2>&1 || true
    noctalia msg theme-mode-set "$mode" >/dev/null 2>&1 || true
  fi

  kitty_theme_apply && echo "kitty: theme.inc.conf <- $T_NAME" || echo "kitty: 写入失败（终端配色未更新）"
  fuzzel_theme_apply && echo "fuzzel: fuzzel.ini <- $T_NAME" || echo "fuzzel: 写入失败（启动器配色未更新）"
  echo "noctalia: $T_NAME ($slug) -> wallpaper scheme ($mode) ${wp:+[$wp]}"
}
