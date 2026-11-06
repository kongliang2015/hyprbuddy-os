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

  # Noctalia 夜间模式：色温日程由 [location] 驱动，没有坐标就不生效
  nl = distro.desktop.nightlight;
  nightlightToml = ''
    # 由 flake 生成（distro.desktop.nightlight），勿手改
    [location]
    auto_locate = ${lib.boolToString nl.autoLocate}
  '' + lib.optionalString (nl.address != "") ''
    address = "${nl.address}"
  '' + lib.optionalString (nl.latitude != null && nl.longitude != null) ''
    latitude = ${toString nl.latitude}
    longitude = ${toString nl.longitude}
  '' + lib.optionalString nl.customSchedule ''
    custom_schedule = true
    sunset = "${nl.sunset}"
    sunrise = "${nl.sunrise}"
  '' + ''
    [nightlight]
    enabled = true
    force = false
    temperature_day = ${toString nl.temperatureDay}
    temperature_night = ${toString nl.temperatureNight}
  '';

  # 本地模型端点（客户端约定）：ollama 不校验 token，这里只是让各 agent 客户端
  # 共用同一份 base URL / 并发值，不构成访问控制。
  ep = distro.agent.localEndpoint;
  epKey = if ep.token != null then ep.token else "local";
  localEndpointEnv = ''
    # 由 flake 生成（distro.agent.localEndpoint），勿手改。
    # 用法: set -a; . ~/.config/hyprbuddy-os/local-endpoint.env; set +a
    # ollama 不校验 token：本文件只是客户端约定，不是访问控制。
    OLLAMA_BASE_URL=http://127.0.0.1:11434/v1
    OLLAMA_API_KEY=${lib.escapeShellArg epKey}
    OLLAMA_NUM_PARALLEL=${toString ep.maxConcurrent}
    OLLAMA_BIND=${ep.bind}
    OPENAI_BASE_URL=http://127.0.0.1:11434/v1
    OPENAI_API_KEY=${lib.escapeShellArg epKey}
  '';

  agentEnabled = distro.agent.enable;
  # 仅在 agent.enable 时部署的脚本（供 scriptNames 与 commands.json 的 available 共用，避免漂移）
  agentOnlyScripts = [ "agent-menu" "agent-apply" "agent-theme-sync" ];
  usageEnabled = agentEnabled && distro.agent.usage;
  # agent-usage 部署到 ~/.local/bin，供 fastfetch 的 command 模块调用
  agentUsage = if usageEnabled then import ../lib/agent-usage.nix { inherit pkgs; } else null;

  textFiles = {
    # fuzzel/fuzzel.ini 不在这里部署：由 exporters/niri/theme.sh 按主题整份生成
    # （[colors] 必须跟随 tokens；若在此链接 store 版本，install.sh 会把主题色刷回默认）
    "kitty/kitty.conf" = read ./kitty/kitty.conf;
    "Thunar/uca.xml" = read ./thunar/uca.xml;
    "niri/config.kdl" = read ./niri/config.kdl;
    "fastfetch/config.jsonc" = read ./fastfetch/config.jsonc;
    # 能力层库（scripts/lib/de.sh）：脚本被逐个装进 bin/，无法靠相对路径找兄弟文件，
    # 所以单独落到 ~/.local/share/hyprbuddy-os/lib/ 供脚本 source
    "share/hyprbuddy-os/lib/de.sh" = read ../scripts/lib/de.sh;
  } // lib.optionalAttrs nl.enable {
    "noctalia/nightlight.toml" = nightlightToml;
  } // lib.optionalAttrs (distro.agent.enable && distro.agent.localModels) {
    "hyprbuddy-os/local-endpoint.env" = localEndpointEnv;
  };

  # P2 主题系统：themes/<slug>/tokens.json（唯一真相）+ exporters
  # （theme-next / de_theme_apply 运行时 source；部署到 share/hyprbuddy-os/）
  themeEntries = lib.concatLists (
    lib.mapAttrsToList
      (slug: _:
        lib.optional (builtins.pathExists (../themes + "/${slug}/tokens.json")) {
          name = "share/hyprbuddy-os/themes/${slug}/tokens.json";
          path = pkgs.writeTextFile {
            name = "theme-${slug}-tokens";
            text = read (../themes + "/${slug}/tokens.json");
          };
        })
      (lib.filterAttrs (_: t: t == "directory") (builtins.readDir ../themes)));

  exporterFiles = {
    "lib.sh" = ../exporters/lib.sh;
  } // builtins.listToAttrs (map (n: {
        name = "niri/${n}";
        value = ../exporters/niri + "/${n}";
      }) (builtins.attrNames (lib.filterAttrs (_: t: t == "regular") (builtins.readDir ../exporters/niri))));

  exporterEntries = lib.mapAttrsToList (name: path: {
    name = "share/hyprbuddy-os/exporters/${name}";
    path = pkgs.writeTextFile {
      name = "exporter-${lib.replaceStrings [ "/" ] [ "-" ] name}";
      text = read path;
    };
  }) exporterFiles;

  # agent 层脚本随 distro.agent.enable 开关安装（agent-usage 由 lib/ 生成，下面单独挂到 bin/）
  scriptNames = let
    entries = builtins.readDir ../scripts;
    all = builtins.filter (n: entries.${n} == "regular") (builtins.attrNames entries);
    agentOnly = agentOnlyScripts;
  in
    if agentEnabled then all
    else builtins.filter (n: !(builtins.elem n agentOnly)) all;

  # 懒加载 agent：把同一份 shim 部署成 bin/<命令名>（claude-code 包的命令名是 claude）
  shimScript = read ./agent-shim.sh;
  shimBinName = name: if name == "claude-code" then "claude" else name;
  shimEntries = map (name: {
    name = "bin/${shimBinName name}";
    path = pkgs.writeTextFile {
      name = "agent-shim-${name}";
      text = shimScript;
      executable = true;
    };
  }) distro.agent.lazyAgents;

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
    ++ lib.optional (distro.hypervisor == "vmware") { name = "bin/kitty"; path = pkgs.writeShellScript "kitty-software-egl" (builtins.readFile ./kitty-egl.sh); }
    ++ themeEntries
    ++ exporterEntries
    ++ lib.singleton { name = "bin/jq"; path = "${pkgs.jq}/bin/jq"; }
    ++ lib.singleton { name = "bin/python3"; path = "${pkgs.python3}/bin/python3"; }
    ++ shimEntries;
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
    agentOnly = agentOnlyScripts;
    version = distro.version;
  };

  # 主题预览图（assets/theme-previews/，theme-picker 的 fzf 预览用；
  # 由 theme-preview-capture 在虚机捕获后入库，装机即带默认预览图）。
  # 经 install.sh 的 share/* 映射落到 ~/.local/share/hyprbuddy-os/。
  previewDir = ../assets/theme-previews;
  previewEntries = lib.mapAttrsToList
    (name: _: {
      name = "share/hyprbuddy-os/theme-previews/${name}";
      path = previewDir + "/${name}";
    })
    (builtins.readDir previewDir);
in
pkgs.linkFarm "user-config-${hostName}" (entries ++ skillEntries ++ previewEntries ++ [ { name = "share/hyprbuddy-os/commands.json"; path = commandsJson; } ])
