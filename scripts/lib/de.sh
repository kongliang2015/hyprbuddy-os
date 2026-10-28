#!/usr/bin/env bash
# 桌面能力层（P1）：脚本只调 de_*，不直接写 hyprctl / cosmic-*。
# P2 新增：de_theme_apply <slug>（tokens 见 themes/*/tokens.json）。
# 由 scripts/* 通过 source 引入，本身不是可执行命令。
#
# 约定：每个能力返回 0 表示已处理，1 表示当前桌面未实现（调用方应给出提示）。

de_name() {
  case "${XDG_CURRENT_DESKTOP:-}" in
    *COSMIC*)      echo cosmic ;;
    *Hyprland*)    echo hyprland ;;
    *niri*|*Niri*) echo niri ;;
    *)
      if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
        echo hyprland
      elif pgrep -x cosmic-session >/dev/null 2>&1; then
        echo cosmic
      elif pgrep -x niri >/dev/null 2>&1; then
        echo niri
      else
        echo unknown
      fi
      ;;
  esac
}

# 壁纸：$1 = 图片绝对路径
de_wallpaper_set() {
  local img="$1"
  case "$(de_name)" in
    hyprland|niri)
      # nixpkgs 26.05 起 swww 更名 awww，两者都兼容
      local wp wpd
      if command -v awww >/dev/null 2>&1; then wp=awww; wpd=awww-daemon
      elif command -v swww >/dev/null 2>&1; then wp=swww; wpd=swww-daemon
      else return 1; fi
      pgrep -f "$wpd" >/dev/null 2>&1 || { setsid "$wpd" >/dev/null 2>&1 </dev/null & sleep 1; }
      "$wp" img "$img" >/dev/null 2>&1 || return 1
      ;;
    cosmic)
      # COSMIC 由 cosmic-bg 监听 RON 配置，原子写入即可热生效
      local cfg="$HOME/.config/cosmic/com.system76.CosmicBackground/v1/all"
      mkdir -p "$(dirname "$cfg")" || return 1
      cat > "$cfg.tmp.$$" <<EOF || return 1
(
    output: "all",
    source: Path("$img"),
    filter_by_theme: true,
    rotation_frequency: 300,
    filter_method: Lanczos,
    scaling_mode: Zoom,
    sampling_method: Alphanumeric,
)
EOF
      mv -f "$cfg.tmp.$$" "$cfg" || return 1
      ;;
    *) return 1 ;;
  esac
}

# 区域截图 + 标注（swappy）
de_screenshot_annotate() {
  case "$(de_name)" in
    hyprland|niri)
      command -v grim >/dev/null 2>&1 && command -v slurp >/dev/null 2>&1 || return 1
      grim -g "$(slurp)" - | swappy -f -
      ;;
    cosmic)
      # COSMIC 走 portal 交互截图。注意它保存名是 Screenshot_YYYY-MM-DD_HH-MM-SS.png，
      # 不是 lowercase cosmic-screenshot-*，所以用独立临时目录 + 取最新文件来定位。
      command -v cosmic-screenshot >/dev/null 2>&1 || return 1
      local d f
      d=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/shot.XXXXXX") || return 1
      cosmic-screenshot --interactive=true --notify=false --save-dir "$d" >/dev/null 2>&1
      f=$(find "$d" -maxdepth 1 -type f -name '*.png' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)
      if [ -z "$f" ]; then
        rm -rf "$d"
        return 1
      fi
      if command -v swappy >/dev/null 2>&1; then
        swappy -f "$f"
      else
        de_notify "截图已保存" "$f"
      fi
      ;;
    *) return 1 ;;
  esac
}

# 锁屏
de_lock() {
  case "$(de_name)" in
    hyprland) hyprlock ;;
    cosmic|niri) loginctl lock-session ;;
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
    hyprland)
      hyprctl monitors -j 2>/dev/null | python3 -c 'import json,sys; [print(f"{m['name']} {m['width']}x{m['height']}") for m in json.load(sys.stdin)]'
      ;;
    cosmic)
      # cosmic-randr 输出为人类可读格式，这里只做透传
      cosmic-randr list 2>/dev/null
      ;;
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
# Hyprland → theme-next <idx>；COSMIC → exporters/cosmic/theme.sh。
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
    cosmic)
      theme_env_load "$slug" || return 1
      . "$THEME_LIB_DIR/cosmic/theme.sh"
      cosmic_theme_apply
      ;;
    niri)
      theme_env_load "$slug" || return 1
      . "$THEME_LIB_DIR/niri/theme.sh"
      noctalia_theme_apply
      ;;
    hyprland)
      local i=0 found="" s
      for s in $(theme_list); do
        [ "$s" = "$slug" ] && found=$i
        i=$((i + 1))
      done
      [ -n "$found" ] || { echo "de_theme_apply: 未知主题 $slug" >&2; return 1; }
      theme-next "$found"
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
    hyprland)
      if command -v hyprshot >/dev/null 2>&1; then
        hyprshot -m output >/dev/null 2>&1 || return 1
      else
        grim "$HOME/Pictures/Screenshot_$(date +%Y%m%d_%H%M%S).png" || return 1
      fi
      ;;
    cosmic)
      command -v cosmic-screenshot >/dev/null 2>&1 || return 1
      mkdir -p "$HOME/Pictures" || return 1
      cosmic-screenshot --interactive=false --notify=true --save-dir "$HOME/Pictures" >/dev/null 2>&1 || return 1
      ;;
    *) return 1 ;;
  esac
}
