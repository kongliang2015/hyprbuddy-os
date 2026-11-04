# 本发行版唯一的对外接口：所有机器差异都在这里声明。
# 约定：host 文件只写 distro.*，不直接写 NixOS 选项。
{ lib, ... }:
let inherit (lib) mkOption types;
in
{
  options.distro = {
    version = mkOption {
      type = types.str;
      default = "0.1.0-dev";
      description = "发行版版本号，用于 boot 标签与 os-release 变体名";
    };

    boot = {
      loader = mkOption {
        type = types.enum [ "systemd-boot" "grub" ];
        default = "systemd-boot";
        description = "引导器类型；由安装器探测后写入 host 文件";
      };
      windowsEntry = mkOption {
        type = types.bool;
        default = false;
        description = "是否在 systemd-boot 菜单加入 Windows 链式启动项";
      };
      plymouth = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            启用 Plymouth 开机动画。NVIDIA 专有驱动下 simpledrm → nvidia_drm 的 KMS
            交接可能闪一下或短暂黑屏，出问题就把这项关掉。
          '';
        };
        theme = mkOption {
          type = types.str;
          default = "catppuccin-mocha";
          description = ''
            Plymouth 主题名。catppuccin-<variant>（latte/frappe/macchiato/mocha）
            会自动带上对应变体的包；其余取值需自行提供 themePackages。
          '';
        };
        themePackages = mkOption {
          type = types.listOf types.package;
          default = [ ];
          example = lib.literalExpression ''
            [ (pkgs.adi1090x-plymouth-themes.override { selected_themes = [ "colorful" ]; }) ]
          '';
          description = ''
            额外提供 Plymouth 主题的包，每个包需有
            $out/share/plymouth/themes/<主题名>/<主题名>.plymouth。
            theme 取 <主题名> 即可选中；catppuccin-<variant> 会自动带包，无需在此重复。
          '';
        };
        debug = mkOption {
          type = types.bool;
          default = false;
          description = ''
            打开 plymouthd 调试日志（内核参数 plymouth.debug，输出到
            /var/log/plymouth-debug.log）。排查"有 splash 服务但看不到画面"时临时开。
          '';
        };
      };
    };

    user = {
      name = mkOption { type = types.str; description = "主用户登录名"; };
      description = mkOption {
        type = types.str;
        default = "";
        defaultText = "distro.user.name";
        description = "GECOS 描述";
      };
      extraGroups = mkOption {
        type = types.listOf types.str;
        default = [ "networkmanager" "wheel" ];
      };
    };

    gpu = {
      vendor = mkOption {
        type = types.enum [ "nvidia" "amd" "intel" "virtio" "none" ];
        default = "virtio";
        description = ''
          显卡厂商。none 表示不启用任何图形驱动（headless）。
          由 installer/detect.sh 读 lspci 后写入 host 文件。
        '';
      };
      nvidia = {
        pciIds = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "10de:1c82" ];
          description = "vendor:device 列表，branch=auto 时用于推断驱动分支";
        };
        branch = mkOption {
          type = types.enum [ "auto" "legacy_580" "production" "beta" ];
          default = "auto";
          description = ''
            auto：按 pciIds 判断 Turing 分界（device id >= 0x1E00 用 production，
            其余用 legacy_580）；无法判断时回退 legacy_580 并给出 warning。
          '';
        };
        open = mkOption {
          type = types.bool;
          default = false;
          description = "是否使用 open 内核模块（Pascal 及更早不支持）";
        };
      };
    };

    desktop = {
      enable = mkOption { type = types.bool; default = true; };
      # 同时安装的 Wayland 桌面会话。两个提供方实现同一组能力契约
      # （见 docs/desktop-abstraction.md），可并存、可逐步退役。
      sessions = mkOption {
        type = types.listOf (types.enum [ "niri" ]);
        default = [ "niri" ];
        description = "启用的桌面提供方；SDDM 会为每一项生成登录会话";
      };

      # 默认登录的会话，必须在 sessions 里。
      default = mkOption {
        type = types.enum [ "niri" ];
        default = "niri";
        description = "SDDM 默认选中的桌面（hyprland 映射到 hyprland-uwsm 会话）";
      };
      theme = mkOption { type = types.str; default = "elarun"; };

      # SDDM 主题包：null = 默认 catppuccin-sddm（catppuccin-mocha-mauve）；
      # 设置后 theme 字段即该包 share/sddm/themes/ 下的目录名。
      sddmThemePackage = mkOption {
        type = types.nullOr types.package;
        default = null;
        description = "SDDM greeter 主题包，null 用默认 catppuccin-sddm";
      };

      # Noctalia 夜间模式（wlr-gamma-control）。色温日程来自 [location]：
      # 没有坐标时不会生效（日志：gamma no schedule）。
      nightlight = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "启用夜间模式（Noctalia nightlight，随日出日落渐变）";
        };
        autoLocate = mkOption {
          type = types.bool;
          default = true;
          description = "按公网 IP 定位（最省事，精确到城市；无网时回落失败）";
        };
        address = mkOption {
          type = types.str;
          default = "";
          description = "autoLocate 关闭时用地址geocode，例如 \"Shanghai\"";
        };
        latitude = mkOption {
          type = types.nullOr types.float;
          default = null;
          description = "手动纬度（autoLocate 与 address 都为空时生效）";
        };
        longitude = mkOption {
          type = types.nullOr types.float;
          default = null;
          description = "手动经度";
        };
        customSchedule = mkOption {
          type = types.bool;
          default = false;
          description = "用固定日落/日出时间代替天文计算";
        };
        sunset = mkOption { type = types.str; default = "19:00"; };
        sunrise = mkOption { type = types.str; default = "07:00"; };
        temperatureDay = mkOption { type = types.int; default = 6500; };
        temperatureNight = mkOption {
          type = types.int;
          default = 4000;
          description = "夜间色温（须比白天低至少 100K）";
        };
      };

    };

    polkitAgent = mkOption {
      type = types.enum [ "kde" "gnome" ];
      default = "kde";
      description = ''
        polkit 认证代理实现。kde = polkit-kde-agent-1（Qt，Wayland 可用）；
        gnome = polkit-gnome（GTK）。
        原 hyprpolkitagent 在 niri 会话下会 SIGABRT（实测），已弃用。
      '';
    };

    hypervisor = mkOption { type = types.enum [ "none" "vmware" "qemu" ]; default = "none"; description = "虚拟化平台：vmware 时启用软件 EGL 等兼容设置"; };
    hardware = {
      battery = mkOption { type = types.bool; default = false; };
      backlight = mkOption { type = types.bool; default = false; };
      bluetooth = mkOption { type = types.bool; default = true; };
    };

    agent = {
      # 默认关闭：agent 栈会引入较大的包（claude-code 等），由 host 显式开启。
      enable = mkOption { type = types.bool; default = false; };
      agents = mkOption {
        type = types.listOf (types.enum [ "claude-code" "codebuddy" "opencode" "codex" "aider-chat" ]);
        default = [ "claude-code" ];
      };
      diagnostics = mkOption { type = types.bool; default = true; };
      usage = mkOption { type = types.bool; default = true; };
      localModels = mkOption { type = types.bool; default = false; };
      model = mkOption {
        type = types.str;
        default = "qwen2.5-coder:1.5b";
        description = "本地模型名；需先 `ollama pull`。诊断与摘要都使用它";
      };
    };
  };
}
