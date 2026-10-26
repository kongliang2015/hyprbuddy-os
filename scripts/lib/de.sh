#!/usr/bin/env bash
# 桌面能力层（P1）：脚本只调 de_*，不直接写 hyprctl / cosmic-*。
# 由 scripts/* 通过 source 引入，本身不是可执行命令。
#
# 约定：每个能力返回 0 表示已处理，1 表示当前桌面未实现（调用方应给出提示）。

de_name() {
  case "${XDG_CURRENT_DESKTOP:-}" in
    *COSMIC*)      echo cosmic ;;
    *Hyprland*)    echo hyprland ;;
    *)
      if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
        echo hyprland
      elif pgrep -x cosmic-session >/dev/null 2>&1; then
        echo cosmic
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
    hyprland)
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
    hyprland)
      command -v grim >/dev/null 2>&1 && command -v slurp >/dev/null 2>&1 || return 1
      grim -g "$(slurp)" - | swappy -f -
      ;;
    cosmic)
      # COSMIC 走 portal 交互截图，落地到临时目录后再交 swappy
      local tmp="${XDG_RUNTIME_DIR:-/tmp}"
      local before after f
      before=$(ls -t "$tmp"/cosmic-screenshot-*.png 2>/dev/null | head -1)
      cosmic-screenshot --interactive=true --notify=false --save-dir "$tmp" >/dev/null 2>&1 || return 1
      after=$(ls -t "$tmp"/cosmic-screenshot-*.png 2>/dev/null | head -1)
      [ -n "$after" ] && [ "$after" != "$before" ] || return 1
      swappy -f "$after"
      ;;
    *) return 1 ;;
  esac
}

# 锁屏
de_lock() {
  case "$(de_name)" in
    hyprland) hyprlock ;;
    cosmic)   loginctl lock-session ;;
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
    *) return 1 ;;
  esac
}
