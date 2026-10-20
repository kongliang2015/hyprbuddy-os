# Waybar 配置的唯一来源：系统级 /etc/xdg/waybar 与用户级 ~/.config/waybar 共用。
# 按 distro.* 选项决定模块列表，避免两份配置漂移。
#
# 配色用 CSS 变量（--wb-*）表达，默认值即 Tokyo Night。运行时由 theme-next 写入
# ~/.config/waybar/theme.css（@import 本文件后再覆盖 :root 变量）实现整栏换肤。
{ lib, home ? "/home/nixos", battery ? false, agentUsageCmd ? null }:
let
  inherit (lib) optional optionalString;

  baseCss = ''
    :root {
      --wb-fg: #c0caf5;
      --wb-bg: #16161e;
      --wb-ws: #565f89;
      --wb-wsafg: #7aa2f7;
      --wb-wsabg: #1f2335;
      --wb-urgent: #f7768e;
      --wb-clock: #7dcfff;
      --wb-cpu: #9ece6a;
      --wb-mem: #e0af68;
      --wb-bat: #bb9af7;
      --wb-pulse: #2ac3de;
      --wb-agent: #bb9af7;
    }
    * {
      font-family: "Noto Sans CJK SC", sans-serif;
      font-size: 13px;
      color: var(--wb-fg);
      border: none;
      border-radius: 0;
    }
    window#waybar { background: transparent; }
    window#waybar > box {
      background: var(--wb-bg);
      border-radius: 12px;
      padding: 2px 8px;
      margin: 0 4px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.4);
    }
    #workspaces button { padding: 0 6px; color: var(--wb-ws); border-radius: 8px; }
    #workspaces button.active { color: var(--wb-wsafg); background: var(--wb-wsabg); }
    #workspaces button.urgent { color: var(--wb-urgent); }
    #clock { color: var(--wb-clock); }
    #cpu { color: var(--wb-cpu); }
    #memory { color: var(--wb-mem); }
    #battery { color: var(--wb-bat); }
    #pulseaudio { color: var(--wb-pulse); }
    #custom-agent-usage { color: var(--wb-agent); padding: 0 6px; }
  '';
in
{
  config = {
    layer = "top";
    position = "top";
    height = 28;
    spacing = 4;
    margin-top = 6;
    margin-left = 10;
    margin-right = 10;
    radius = 12;
    # theme-next 写入的用户级覆盖样式（含 @import 本文件 + 覆盖 :root 变量）。
    # 文件不存在时 Waybar 仅使用上面的默认 Tokyo Night 配色。
    "stylesheet" = "${home}/.config/waybar/theme.css";

    # 注意：窗口标题只放 center。曾经 left 里也写了一份 hyprland/window，
    # 导致 Waybar 出现两个完全相同的标题模块。
    modules-left = [ "hyprland/workspaces" ];
    modules-center = [ "hyprland/window" ];
    modules-right =
      [ "tray" "pulseaudio" "network" "cpu" "memory" ]
      ++ optional battery "battery"
      ++ optional (agentUsageCmd != null) "custom/agent-usage"
      ++ [ "clock" ];

    "hyprland/workspaces" = { disable-scroll = true; show-special = true; };
    pulseaudio = { format = "{volume}%"; format-muted = "MUTE"; };
    network = { format-wifi = "WIFI {essid}"; format-ethernet = "ETH"; };
    cpu = { format = "CPU {usage}%"; };
    memory = { format = "RAM {}%"; };
    battery = { format = "BAT {capacity}%"; format-charging = "CHG {capacity}%"; };
    clock = { format = "{:%H:%M %a %d}"; };
  }
  // lib.optionalAttrs (agentUsageCmd != null) {
    "custom/agent-usage" = {
      exec = agentUsageCmd;
      interval = 60;
      format = "AGENT {}";
      tooltip = true;
    };
  };

  css = baseCss + optionalString (agentUsageCmd == null) "";
}
