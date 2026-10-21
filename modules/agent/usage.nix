# agent 层：用量观测。汇总 codebuddy / claude / opencode 三源会话日志的
# token 用量（/cost 口径），注入 Waybar。脚本实现在 lib/agent-usage.nix。
{ config, lib, pkgs, ... }:
let
  cfg = config.distro.agent;
in
lib.mkIf (cfg.enable && cfg.usage) {
  # 脚本实现在 lib/agent-usage.nix，用户级生成的 Waybar 复用同一份
  distro.desktop.waybarAgentCmd = "${import ../../lib/agent-usage.nix { inherit pkgs; }}";
}
