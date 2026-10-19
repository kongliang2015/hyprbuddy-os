#!/usr/bin/env bash
# 部署用户级配置：由 flake 的 homeConfigs.<host> 生成配置树，再软链进 ~/.config 与 ~/.local/bin。
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
  配置由 nix build .#homeConfigs.<host> 生成，链接到 ~/.config / ~/.local/bin。
  被替换的真实文件会备份到 ~/.config.bak-<时间戳>/。
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
out="$(nix --extra-experimental-features 'nix-command flakes' \
  build --no-link --print-out-paths "path:$here#$HOST")"

if [ "$ASSUME_YES" -ne 1 ]; then
  printf '\n将把 %s 下的文件链接到 ~/.config 与 ~/.local/bin（已存在的真实文件会先备份）。继续？[y/N] ' "$out"
  read -r ans
  [ "$ans" = y ] || [ "$ans" = Y ] || { echo "已取消"; exit 0; }
fi

stamp="$(date +%Y%m%d-%H%M%S)"
backup="$HOME/.config.bak-$stamp"

echo "==> 链接配置"
while IFS= read -r rel; do
  case "$rel" in
    bin/*) dst="$HOME/.local/bin/${rel#bin/}" ;;
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

echo
echo "完成。注销重登（或重启）让 Hyprland 读取新配置。"
[ -d "$backup" ] && echo "旧文件备份在: $backup"
echo
echo "改了配置后的流程："
echo "  1. 编辑仓库下的 home/ 或 hosts/$HOST"
echo "  2. ./install.sh --host $HOST      # 重新生成并链接"
echo "  3. 系统级改动: sudo nixos-rebuild switch --flake .#$HOST"
