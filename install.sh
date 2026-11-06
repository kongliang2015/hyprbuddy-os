#!/usr/bin/env bash
# 部署用户级配置：由 flake 的 packages.<system>.<host>（`.#<host>`）生成配置树，
# 再软链进 ~/.config、~/.local/bin 与 ~/.codebuddy/skills。
#
# 不再拷贝 + sed：配置文件是 Nix store 里的产物，主机差异（电池/背光/agent）在构建期决定。
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
HOST="${HOST:-$(hostname)}"
ASSUME_YES=0

usage() {
  cat <<'EOF'
用法: ./install.sh [--host <name>] [--yes]

  --host <名字>   hosts/<名字> 对应的配置（默认取 hostname）
  --yes           覆盖已存在的真实文件时不再询问

说明:
  配置由 nix build .#<host>（即 packages.<system>.<host>）生成，链接到
  ~/.config / ~/.local/bin / ~/.codebuddy/skills。被替换的真实文件会备份到
  ~/.config.bak-<时间戳>/。
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --host) HOST="${2:?}"; shift 2 ;;
    --yes) ASSUME_YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done

[ -f "$here/hosts/$HOST/default.nix" ] || {
  echo "找不到 hosts/$HOST/default.nix；现有 host：" >&2
  ls "$here/hosts" | grep -v '^_' >&2
  exit 1
}

echo "==> 生成用户级配置（host: $HOST）"
mkdir -p "$HOME/.local/share"
out="$(nix --extra-experimental-features 'nix-command flakes' \
  build --out-link "$HOME/.local/share/hyprbuddy-os-home" --print-out-paths "path:$here#$HOST")"

if [ "$ASSUME_YES" -ne 1 ]; then
  printf '\n将把 %s 下的文件链接到 ~/.config、~/.local/bin 与 ~/.codebuddy/skills（已存在的真实文件会先备份）。继续？[y/N] ' "$out"
  read -r ans
  [ "$ans" = y ] || [ "$ans" = Y ] || { echo "已取消"; exit 0; }
fi

stamp="$(date +%Y%m%d-%H%M%S)"
backup="$HOME/.config.bak-$stamp"

# 清理上一代 linkFarm 遗留的软链：仅 ~/.local/bin 里指向「其它 user-config / agent-shim
# store」的链接。本次 $out 的路径保留（下面会重新 ln -sfn）；用户自己放的真实文件、
# 指向其它 store 的链接都不动。这样移除 lazyAgents / 命令后 shim 会真正消失。
echo "==> 清理陈旧部署软链"
cleaned=0
for l in "$HOME/.local/bin/"*; do
  [ -L "$l" ] || continue
  target="$(readlink "$l")"
  case "$target" in
    "$out"/*) continue ;;
    /nix/store/*-user-config-*|/nix/store/*-agent-shim-*)
      rm -f "$l"
      cleaned=$((cleaned + 1))
      echo "  清理 ${l#$HOME/} -> $target" ;;
  esac
done
[ "$cleaned" -gt 0 ] && echo "  共清理 $cleaned 个" || echo "  无陈旧软链"

echo "==> 链接配置"
while IFS= read -r rel; do
  case "$rel" in
    bin/*) dst="$HOME/.local/bin/${rel#bin/}" ;;
    share/*)
      dst="$HOME/.local/share/${rel#share/}"
      # 主题预览图属用户数据：本地已用 theme-preview-capture 捕获（真实文件）
      # 时不覆盖，仅在本机没有预览图时链接仓库内置的默认图。
      case "$rel" in
        *theme-previews/*)
          if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            echo "  保留本地预览图 ${dst#$HOME/}"
            continue 2
          fi
          ;;
      esac
      ;;
    skills/*)
      dst="$HOME/.codebuddy/skills/${rel#skills/}"
      if [ -d "$HOME/.claude" ]; then
        mkdir -p "$HOME/.claude/skills/$(dirname "${rel#skills/}")"
        ln -sfn "$out/$rel" "$HOME/.claude/skills/${rel#skills/}"
        echo "  .claude/skills/${rel#skills/} -> $out/$rel"
      fi
      ;;
    *)     dst="$HOME/.config/$rel" ;;
  esac
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mkdir -p "$backup/$(dirname "${dst#$HOME/}")"
    mv "$dst" "$backup/${dst#$HOME/}"
    echo "  备份 ${dst#$HOME/}"
  fi
  ln -sfn "$out/$rel" "$dst"
  echo "  ${dst#$HOME/} -> $out/$rel"
done < <(cd "$out" && find . \( -type f -o -type l \) | sed 's|^\./||' | sort)

echo "==> 壁纸"
mkdir -p "$HOME/Pictures/wallpapers"
cp -f "$here"/wallpapers/* "$HOME/Pictures/wallpapers/" 2>/dev/null || true

echo "==> 运行时样式"
# fuzzel.ini 由 theme-next 按主题生成（写 tmp → 非空才替换），不能是 store 软链。
# 若这里还是旧部署留下的链接，先摘掉，否则 theme-next 写不进去。
fz="$HOME/.config/fuzzel/fuzzel.ini"
if [ -L "$fz" ]; then
  case "$(readlink "$fz")" in
    /nix/store/*)
      rm -f "$fz"
      echo "  - 移除 fuzzel.ini 的 Nix 链接（改由 theme-next 生成）"
      ;;
  esac
fi
# 图形会话里立刻按当前主题重生成一次，避免装完还是旧样式。theme-next 自己也按
# XDG_CURRENT_DESKTOP 判断是否动运行态，TTY 下只更新索引。
if [ -x "$HOME/.local/bin/theme-next" ]; then
  case "${XDG_CURRENT_DESKTOP:-}" in
    *niri*|*Niri*)
      if "$HOME/.local/bin/theme-next" restore >/dev/null 2>&1; then
        echo "  - 已按当前主题重生成组件样式"
      else
        echo "  - 组件样式重生成失败（可手动运行 theme-next restore）"
      fi
      ;;
  esac
fi

echo "==> 桌面自检"
# desktop-check：当前只有 niri 提供方（Hyprland 于 v1-nn 退役）
if [ -x "$HOME/.local/bin/desktop-check" ]; then
  "$HOME/.local/bin/desktop-check" || true
else
  echo "  - 跳过（desktop-check 未安装）"
fi

echo
echo "完成。注销重登（或重启）让 niri 读取新配置。"
[ -d "$backup" ] && echo "旧文件备份在: $backup"
echo
echo "改了配置后的流程："
echo "  1. 编辑仓库下的 home/ 或 hosts/$HOST"
echo "  2. ./install.sh --host $HOST      # 重新生成并链接"
echo "  3. 系统级改动: sudo nixos-rebuild switch --flake .#$HOST"
