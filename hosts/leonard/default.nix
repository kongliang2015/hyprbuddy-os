# 本机：GTX 1050 Ti（Pascal）/ 台式机 / Hyprland + COSMIC 双会话（X11 会话已退役）。
# 只写 distro.*，不直接写 NixOS 选项。
{ pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nixos";
  system.stateVersion = "25.11";

  distro = {
    # 并存会话：Hyprland（默认）+ COSMIC。COSMIC 仅用于评估，
    # niri 与 Hyprland 并存；COSMIC 已于 2026-10-28 退役（见 docs/desktop-abstraction.md）。
    desktop.sessions = [ "niri" ];
    desktop.default = "niri";

    user.name = "leonard";
    boot.windowsEntry = true;   # ESP 上有 /EFI/Microsoft/Boot/bootmgfw.efi（nvme1n1 上的 Windows）
    # 开机动画：主题与 SDDM 的 catppuccin-mocha 对齐；NVIDIA 下若 KMS 交接黑屏就关掉
    boot.plymouth = {
      enable = true;
      theme = "hyprbuddy";                       # 自定义 script 主题（彩色进度条）
      themePackages = [ pkgs.plymouth-theme-hyprbuddy ];
    };
    gpu = {
      vendor = "nvidia";
      nvidia = {
        pciIds = [ "10de:1c82" ];   # GTX 1050 Ti (GP107)；auto → legacy_580
        open = false;
      };
    };
    desktop = {
      # HyprBuddy 配套 SDDM 登录界面：Plymouth 开屏 → 登录 → 桌面 同一套视觉
      sddmThemePackage = pkgs.callPackage ../../pkgs/sddm-theme-hyprbuddy { };
      theme = "hyprbuddy";   # sddmThemePackage 内 share/sddm/themes/ 下的目录名
    };
    # polkit 认证框跟随桌面主题：hyprtoolkit 实现（0.2.0，取 nixpkgs-unstable）
    polkitAgent = "kde";
    agent = {
      enable = true;
      # claude-code 的二进制从 downloads.claude.ai 拉取，本机网络不可达（构建期失败）；
      # 能访问该域名时改成 [ "claude-code" ] 即可，枚举已支持。
      agents = [ "opencode" "codebuddy" ];
      # codebuddy 的会话日志（~/.codebuddy/projects/*.jsonl）内含 usage，
      # agent-usage 按 /cost 口径统计当日 output
      usage = true;
      diagnostics = false;   # 需先开 localModels 并 ollama pull
      localModels = false;
    };
    hardware.battery = false;
    hardware.backlight = false;
  };
}
