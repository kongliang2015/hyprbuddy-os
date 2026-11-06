#!/usr/bin/env bash
# agent-shim：懒加载 agent 启动器（由 home/default.nix 部署为 ~/.local/bin/<命令名>）。
# 首次运行按本仓库 flake.lock 构建对应包；产物 out-link 到 ~/.local/state/agent-shims/<包名>，
# 之后直接 exec 缓存，不再求值。
set -euo pipefail
name=$(basename "$0")
# 命令名与 nixpkgs 包名不一致的映射（claude-code 包的 mainProgram 是 claude）
case "$name" in
  claude) pkg=claude-code ;;
  *) pkg=$name ;;
esac
repo="${HYPRBUDDY_OS_REPO:-$HOME/hyprbuddy-os}"
cache="${XDG_STATE_HOME:-$HOME/.local/state}/agent-shims/$pkg"

if [ ! -x "$cache/bin/$name" ]; then
  mkdir -p "$(dirname "$cache")"
  notify-send -a agent-shim "首次运行 $name" "正在按 flake.lock 拉取，稍等…" 2>/dev/null || true
  nix build --out-link "$cache" "$repo#$pkg"
fi

exec "$cache/bin/$name" "$@"
