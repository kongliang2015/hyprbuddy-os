# agent 层：用量观测。汇总 Claude Code 会话日志的 token 用量，注入 Waybar。
{ config, lib, pkgs, ... }:
let
  cfg = config.distro.agent;
in
lib.mkIf (cfg.enable && cfg.usage) {
  # 脚本实现在 lib/agent-usage.nix，用户级生成的 Waybar 复用同一份
  distro.desktop.waybarAgentCmd = "${import ../../lib/agent-usage.nix { inherit pkgs; }}";
}
