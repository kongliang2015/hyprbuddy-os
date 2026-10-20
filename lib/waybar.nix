# Waybar 配置的唯一来源：系统级 /etc/xdg/waybar 与用户级 ~/.config/waybar 共用。
# 按 distro.* 选项决定模块列表，避免两份配置漂移。
#
# 注意：GTK 的 CSS 不支持 :root 和 var() 自定义属性（报 "Invalid name of pseudo-class"
# 会让 Waybar 直接拒绝启动），所以配色全部写具体颜色值。换肤由 theme-next 把整份
# CSS（同样只有具体颜色值）重写到 ~/.config/waybar/style.css。
# 字体栈首位必须是 Nerd Font：模块图标用 Nerd Font 字形，中文由 fontconfig 回退到 Noto。
{ lib, battery ? false, agentUsageCmd ? null }:
let
  inherit (lib) optional optionalString;

  baseCss = ''
    * {
      font-family: "JetBrainsMono Nerd Font", "Noto Sans CJK SC", sans-serif;
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
    /* workspaces：胶囊 + hover */
    #workspaces button { padding: 0 8px; margin: 2px 1px; color: #565f89; border-radius: 8px; }
    #workspaces button:hover { color: #7aa2f7; background: #1f2335; }
    #workspaces button.active { color: #7aa2f7; background: #1f2335; }
    #workspaces button.urgent { color: #f7768e; }
    /* 中间窗口标题：独立胶囊 */
    #window { background: #16161e; border-radius: 10px; padding: 0 12px; color: #565f89; }
    /* 分组胶囊（与 Hyprland rounding=10 对齐） */
    #group-hardware, #group-media, #group-clock {
      background: #1f2335;
      border: 1px solid #7aa2f7;
      border-radius: 10px;
      padding: 0 8px;
      margin: 4px 3px;
    }
    #group-hardware:hover, #group-media:hover, #group-clock:hover { background: #565f89; }
    #network, #tray { border: 1px solid #7aa2f7; border-radius: 10px; padding: 0 8px; margin: 4px 3px; }
    #network:hover { background: #1f2335; }
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
    height = 30;
    spacing = 6;
    margin-top = 6;
    margin-left = 10;
    margin-right = 10;
    radius = 12;
    # 注意：窗口标题只放 center。曾经 left 里也写了一份 hyprland/window，
    # 导致 Waybar 出现两个完全相同的标题模块。
    modules-left = [ "hyprland/workspaces" ];
    modules-center = [ "hyprland/window" ];
    # 右侧按功能分组：托盘 / 音量 / 网络 / CPU+内存(+电池) / 时钟
    modules-right =
      [ "tray" "group/media" "network" "group/hardware" "group/clock" ]
      ++ optional (agentUsageCmd != null) "custom/agent-usage";

    "group/media" = { orientation = "horizontal"; modules = [ "pulseaudio" ]; };
    "group/hardware" = {
      orientation = "horizontal";
      modules = [ "cpu" "memory" ] ++ optional battery "battery";
    };
    "group/clock" = { orientation = "horizontal"; modules = [ "clock" ]; };

    # persistent-workspaces: 空桌面/锁屏解锁后 1-4 也常驻显示，不再消失
    "hyprland/workspaces" = {
      disable-scroll = true;
      show-special = true;
      persistent-workspaces = { "*" = 4; };
    };

    pulseaudio = {
      format = "{icon} {volume}%";
      format-muted = " MUTE";
      format-icons = [ "" "" "" ];
      on-click = "pavucontrol";
      tooltip-format = "音量 {volume}%";
    };
    network = { format-wifi = " {essid}"; format-ethernet = " ETH"; };
    cpu = { format = " {usage}%"; };
    memory = { format = " {}%"; };
    battery = {
      format = "{icon} {capacity}%";
      format-charging = " {capacity}%";
      format-icons = [ "" "" "" "" "" ];
    };
    clock = { format = " {:%H:%M}"; tooltip-format = "{:%A %d %B %Y}"; };
  }
  // lib.optionalAttrs (agentUsageCmd != null) {
    "custom/agent-usage" = {
      exec = agentUsageCmd;
      return-type = "json";
      interval = 60;
      format = "AGENT {}";
      tooltip = true;
    };
  };

  css = baseCss + optionalString (agentUsageCmd == null) "";
}
