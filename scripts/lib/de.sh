#!/usr/bin/env bash
# 桌面能力层（P1）：脚本只调 de_*，不直接写 hyprctl / niri msg。
# P2 新增：de_theme_apply <slug>（tokens 见 themes/*/tokens.json）。
# 由 scripts/* 通过 source 引入，本身不是可执行命令。
#
# 约定：每个能力返回 0 表示已处理，1 表示当前桌面未实现（调用方应给出提示）。

de_name() {
  case "${XDG_CURRENT_DESKTOP:-}" in
    *niri*|*Niri*) echo niri ;;
    *)
      if pgrep -x niri >/dev/null 2>&1; then echo niri; else echo unknown; fi
      ;;
  esac
}

# 壁纸：$1 = 图片绝对路径
de_wallpaper_set() {
  local img="$1"
  case "$(de_name)" in
    niri)
      # 壁纸交给 Noctalia v5 自带服务（awww 已从包集移除）；
      # 必须传绝对路径：壁纸目录会被 Noctalia 启动时重置为默认值。
      command -v noctalia >/dev/null 2>&1 || return 1
      noctalia msg wallpaper-set "$img" >/dev/null 2>&1 || return 1
      ;;
    *) return 1 ;;
  esac
}

# 区域截图 + 标注（swappy）
de_screenshot_annotate() {
  case "$(de_name)" in
    niri)
      command -v grim >/dev/null 2>&1 && command -v slurp >/dev/null 2>&1 || return 1
      grim -g "$(slurp)" - | swappy -f -
      ;;
    *) return 1 ;;
  esac
}

# 锁屏
de_lock() {
  case "$(de_name)" in
    niri) loginctl lock-session ;; # Noctalia v5 锁屏接管 session lock 信号
    *) return 1 ;;
  esac
}

# 通知（两个桌面都走 org.freedesktop.Notifications）
de_notify() {
  local summary="$1"; shift || true
  local body="${1:-}"; shift || true
  notify-send -a "${DE_NOTIFY_APP:-desktop}" "$summary" "$body" "$@"
}

# 显示器信息（统一成 name/WxH 行，供脚本解析）
de_monitors() {
  case "$(de_name)" in
    niri)
      # niri IPC：{name: {modes: [{width, height}], current_mode: idx}}
      niri msg -j outputs 2>/dev/null | python3 -c 'import json,sys
d = json.load(sys.stdin)
for name, o in d.items():
    modes = o.get("modes") or []
    idx = o.get("current_mode")
    if idx is not None and idx < len(modes):
        w = modes[idx]["width"]
        h = modes[idx]["height"]
        print(f"{name} {w}x{h}")
    else:
        print(f"{name} ?")'
      ;;
    *) return 1 ;;
  esac
}

# de_theme_apply <slug>：应用指定主题（slug 为 themes/<slug>/ 目录名）。
# Hyprland → theme-next <idx>；niri → exporters/niri/theme.sh。
# 依赖 exporters/lib.sh（theme_list / theme_env_load），按部署布局定位。
de_theme_apply() {
  local slug=$1 lib=""
  [ -n "$slug" ] || { echo "usage: de_theme_apply <slug>" >&2; return 1; }
  # 注意不能用 readlink -f：解析到 store 会丢掉 share/hyprland-nixos/ 布局。
  # 按 source 时的原始路径回溯：
  #   部署   ~/.local/share/hyprland-nixos/lib/ → ../exporters/
  #   仓库   scripts/lib/ → ../../exporters/
  local d; d=$(dirname "${BASH_SOURCE[0]}")
  for d in "$d/../exporters/lib.sh" "$d/../../exporters/lib.sh"; do
    [ -r "$d" ] && lib=$d && break
  done
  [ -n "$lib" ] || { echo "de_theme_apply: 找不到 exporters/lib.sh" >&2; return 1; }
  . "$lib"
  case "$(de_name)" in
    niri)
      theme_env_load "$slug" || return 1
      . "$THEME_LIB_DIR/niri/theme.sh"
      noctalia_theme_apply "$slug"
      ;;
    *)
      echo "de_theme_apply: 未知桌面" >&2
      return 1
      ;;
  esac
}

# 整屏截图（区域截图见 de_screenshot_annotate）
de_screenshot_output() {
  case "$(de_name)" in
    niri) grim "$HOME/Pictures/Screenshot_$(date +%Y%m%d_%H%M%S).png" || return 1 ;;
    *) return 1 ;;
  esac
}
