# 生成用户级配置树（不依赖 Home Manager）。
#
# 输入: host 的 distro.* 选项 + 用户主目录
# 输出: 一个 store 目录，结构与 ~/.config 对齐（另有 bin/ 对应 ~/.local/bin）
#       install.sh 负责把它软链进用户目录。
{ lib, pkgs, distro, home, hostName }:
let
  inherit (lib) concatStringsSep optional optionals;

  # @HOME@ -> 家目录；@JQ@ -> store 里的 jq（agent-commands 免依赖系统 PATH）
  sub = s: lib.replaceStrings [ "@HOME@" "@JQ@" ] [ home "${pkgs.jq}/bin/jq" ] s;
  read = path: sub (builtins.readFile path);

  agentEnabled = distro.agent.enable;
  usageEnabled = agentEnabled && distro.agent.usage;
  # agent-usage 既给 waybar 用（需要 store 路径字符串），也部署到 ~/.local/bin
  # 供 fastfetch 的 command 模块调用（需要 package 类型）
  agentUsage = if usageEnabled then import ../lib/agent-usage.nix { inherit pkgs; } else null;
  agentUsageCmd = if agentUsage != null then "${agentUsage}" else null;

  waybar = import ../lib/waybar.nix {
    inherit lib;
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
    ++ (if distro.hypervisor == "vmware" then [ "monitor=,1920x1080@60,auto,1" "bind = $mainMod, RETURN, exec, env LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe kitty" ] else [ "bind = $mainMod, RETURN, exec, kitty" ])
    ++ (if distro.hypervisor == "vmware" then [ ] else [ "bind = $mainMod, L, exec, hyprlock" ])
    ++ optional agentEnabled
      "bind = $mainMod SHIFT CTRL, A, exec, ${home}/.local/bin/agent-menu"
  ) + "
";

  textFiles = {
    "hypr/hyprland.conf" = read ./hypr/hyprland.conf;
    "hypr/extra.conf" = extraHypr;
    "hypr/hypridle.conf" = if distro.hypervisor == "vmware" then "" else read ./hypr/hypridle.conf;
    "hypr/hyprlock.conf" = read ./hypr/hyprlock.conf;
    "waybar/config" = builtins.toJSON waybar.config;
    "waybar/style.css" = waybar.css;
    "fuzzel/fuzzel.ini" = read ./fuzzel/fuzzel.ini;
    "kitty/kitty.conf" = read ./kitty/kitty.conf;
    "swaync/config.json" = read ./swaync/config.json;
    "swaync/style.css" = read ./swaync/style.css;
    "eww/eww.yuck" = read ./eww/eww.yuck;
    "eww/eww.scss" = read ./eww/eww.scss;
    "swayosd/style.css" = read ./swayosd/style.css;
    "Thunar/uca.xml" = read ./thunar/uca.xml;
    "fastfetch/config.jsonc" = read ./fastfetch/config.jsonc;
  };

  # agent 层脚本随 distro.agent.enable 开关安装（agent-usage 由 lib/ 生成，下面单独挂到 bin/）
  scriptNames = let
    all = builtins.attrNames (builtins.readDir ../scripts);
    agentOnly = [ "agent-menu" "agent-apply" "agent-theme-sync" ];
  in
    if agentEnabled then all
    else builtins.filter (n: !(builtins.elem n agentOnly)) all;

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
    }) scriptNames
    # agent-usage 由 lib/ 生成，部署到 PATH 供 fastfetch 的 command 模块调用
    ++ lib.optional (agentUsage != null) { name = "bin/agent-usage"; path = agentUsage; }
    ++ lib.optional (distro.hypervisor == "vmware") { name = "bin/kitty"; path = pkgs.writeShellScript "kitty-software-egl" (builtins.readFile ./kitty-egl.sh); };
  # agent skills（skills/<name>/…）：install.sh 链接到 ~/.codebuddy/skills/
  skillsDir = ../skills;
  skillEntries = lib.concatLists (
    lib.mapAttrsToList
      (skill: _:
        lib.mapAttrsToList
          (file: _:
            { name = "skills/${skill}/${file}";
              path = pkgs.writeTextFile {
                name = "skill-${skill}-${file}";
                text = read (skillsDir + "/${skill}/${file}");
              };
            })
          (builtins.readDir (skillsDir + "/${skill}")))
      (lib.filterAttrs (_: t: t == "directory") (builtins.readDir skillsDir)));
  # 机器可读命令清单（由 scripts/ 头部 @command 元数据生成）
  commandsJson = import ../lib/commands.nix {
    inherit pkgs lib hostName agentEnabled;
    version = distro.version;
  };

  # 主题预览图（assets/theme-previews/，theme-picker 的 fzf 预览用；
  # 由 theme-preview-capture 在虚机捕获后入库，装机即带默认预览图）。
  # 经 install.sh 的 share/* 映射落到 ~/.local/share/hyprland-nixos/。
  previewDir = ../assets/theme-previews;
  previewEntries = lib.mapAttrsToList
    (name: _: {
      name = "share/hyprland-nixos/theme-previews/${name}";
      path = previewDir + "/${name}";
    })
    (builtins.readDir previewDir);
in
pkgs.linkFarm "user-config-${hostName}" (entries ++ skillEntries ++ previewEntries ++ [ { name = "share/hyprland-nixos/commands.json"; path = commandsJson; } ])
