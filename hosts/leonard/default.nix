# 本机：GTX 1050 Ti（Pascal）/ 台式机 / 保留 XFCE + Window Maker。
# 只写 distro.*，不直接写 NixOS 选项。
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nixos";
  system.stateVersion = "25.11";

  distro = {
    user.name = "leonard";
    boot.windowsEntry = true;   # ESP 上有 /EFI/Microsoft/Boot/bootmgfw.efi（nvme1n1 上的 Windows）
    # 开机动画：主题与 SDDM 的 catppuccin-mocha 对齐；NVIDIA 下若 KMS 交接黑屏就关掉
    boot.plymouth.enable = true;
    gpu = {
      vendor = "nvidia";
      nvidia = {
        pciIds = [ "10de:1c82" ];   # GTX 1050 Ti (GP107)；auto → legacy_580
        open = false;
      };
    };
    desktop.extraSessions = [ "xfce" "windowmaker" ];
    # polkit 认证框跟随桌面主题：hyprtoolkit 实现（0.2.0，取 nixpkgs-unstable）
    polkitAgent = "hyprtoolkit";
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
