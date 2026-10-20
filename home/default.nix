# 生成用户级配置树（不依赖 Home Manager）。
#
# 输入: host 的 distro.* 选项 + 用户主目录
# 输出: 一个 store 目录，结构与 ~/.config 对齐（另有 bin/ 对应 ~/.local/bin）
#       install.sh 负责把它软链进用户目录。
{ lib, pkgs, distro, home, hostName }:
let
  inherit (lib) concatStringsSep optional optionals;

  sub = s: lib.replaceStrings [ "@HOME@" ] [ home ] s;
  read = path: sub (builtins.readFile path);

  agentEnabled = distro.agent.enable;
  usageEnabled = agentEnabled && distro.agent.usage;
  agentUsageCmd =
    if usageEnabled then "${import ../lib/agent-usage.nix { inherit pkgs; }}" else null;

  waybar = import ../lib/waybar.nix {
    inherit lib;
    home = home;
    battery = distro.hardware.battery;
    inherit agentUsageCmd;
  };

  # 按硬件/功能开关生成的 Hyprland 片段
  extraHypr = ''
    # 由发行版生成（home/default.nix），不要手改
  '' + concatStringsSep "
" (
    optionals distro.hardware.backlight [
      "bind = , XF86MonBrightnessUp, exec, swayosd-client --brightness raise"
      "bind = , XF86MonBrightnessDown, exec, swayosd-client --brightness lower"
    ]
    ++ optional agentEnabled
      "bind = $mainMod SHIFT CTRL, A, exec, ${home}/.local/bin/agent-menu"
  ) + "
";

  textFiles = {
    "hypr/hyprland.conf" = read ./hypr/hyprland.conf;
    "hypr/extra.conf" = extraHypr;
    "hypr/hypridle.conf" = read ./hypr/hypridle.conf;
    "hypr/hyprlock.conf" = read ./hypr/hyprlock.conf;
    "waybar/config" = builtins.toJSON waybar.config;
    "waybar/style.css" = waybar.css;
    "fuzzel/fuzzel.ini" = read ./fuzzel/fuzzel.ini;
    "kitty/kitty.conf" = read ./kitty/kitty.conf;
    "mako/config" = read ./mako/config;
    "swayosd/style.css" = read ./swayosd/style.css;
    "Thunar/uca.xml" = read ./thunar/uca.xml;
  };

  scriptNames = builtins.attrNames (builtins.readDir ../scripts);

  entries =
    lib.mapAttrsToList (name: text: {
      inherit name;
      path = pkgs.writeTextFile {
        name = "cfg-${lib.replaceStrings [ "/" ] [ "-" ] name}";
        inherit text;
      };
    }) textFiles
    ++ map (name: {
      name = "bin/${name}";
      path = pkgs.writeTextFile {
        name = "bin-${name}";
        text = read (../scripts + "/${name}");
        executable = true;
      };
    }) scriptNames;
in
pkgs.linkFarm "user-config-${hostName}" entries
