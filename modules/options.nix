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
      extraSessions = mkOption {
        type = types.listOf (types.enum [ "xfce" "windowmaker" ]);
        default = [ ];
        description = "除 Hyprland 外额外保留的 X11 会话";
      };
      theme = mkOption { type = types.str; default = "elarun"; };
    };

    hardware = {
      battery = mkOption { type = types.bool; default = false; };
      backlight = mkOption { type = types.bool; default = false; };
      bluetooth = mkOption { type = types.bool; default = true; };
    };

    agent = {
      enable = mkOption { type = types.bool; default = true; };
      agents = mkOption {
        type = types.listOf (types.enum [ "claude-code" "opencode" "codex" "aider-chat" ]);
        default = [ "claude-code" ];
      };
      diagnostics = mkOption { type = types.bool; default = true; };
      usage = mkOption { type = types.bool; default = true; };
      localModels = mkOption { type = types.bool; default = false; };
    };
  };
}
