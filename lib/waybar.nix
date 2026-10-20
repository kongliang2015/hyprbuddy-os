# Waybar 配置的唯一来源：系统级 /etc/xdg/waybar 与用户级 ~/.config/waybar 共用。
# 按 distro.* 选项决定模块列表，避免两份配置漂移。
#
# 注意：GTK 的 CSS 不支持 :root 和 var() 自定义属性（报 "Invalid name of pseudo-class"
# 会让 Waybar 直接拒绝启动），所以配色全部写具体颜色值。换肤由 theme-next 把整份
# CSS（同样只有具体颜色值）重写到 ~/.config/waybar/style.css。
{ lib, home ? "/home/nixos", battery ? false, agentUsageCmd ? null }:
let
  inherit (lib) optional optionalString;

  baseCss = ''
    * {
      font-family: "Noto Sans CJK SC", sans-serif;
      font-size: 13px;
      color: #c0caf5;
      border: none;
      border-radius: 0;
    }
    window#waybar { background: transparent; }
    window#waybar > box {
      background: #16161e;
      border-radius: 12px;
      padding: 2px 8px;
      margin: 0 4px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.4);
    }
    #workspaces button { padding: 0 6px; color: #565f89; border-radius: 8px; }
    #workspaces button.active { color: #7aa2f7; background: #1f2335; }
    #workspaces button.urgent { color: #f7768e; }
    #clock { color: #7dcfff; }
    #cpu { color: #9ece6a; }
    #memory { color: #e0af68; }
    #battery { color: #bb9af7; }
    #pulseaudio { color: #2ac3de; }
    #custom-agent-usage { color: #bb9af7; padding: 0 6px; }
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
