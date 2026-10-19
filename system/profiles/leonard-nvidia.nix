# 机型 profile：真实 NVIDIA 显卡（本机 leonard：GTX 1050 Ti / Pascal）
#
# 由 system/configuration.nix 的 hardwareProfile 选择加载，默认不启用。
# 与默认 virtio 模板的差异只有两类：
#   1. 显卡驱动栈：modesetting + Mesa  →  nvidia 闭源驱动（锁 580 LTSB）
#   2. 可选 X 会话：Hyprland-only  →  额外保留 XFCE / Window Maker
{ config, lib, pkgs, ... }:

{
  # ── 显卡 ────────────────────────────────────────────────
  # Pascal 必须留在 580 分支：26.05 的 nvidiaPackages.stable 指向 production 595.x，
  # 该分支已不支持 Maxwell / Pascal / Volta，直接升级会加载失败（黑屏、无会话）。
  services.xserver.videoDrivers = lib.mkForce [ "nvidia" ];

  hardware.nvidia = {
    branch = "legacy_580";      # 580.178.04，NVIDIA 标为 LTSB（支持到 2028-08）
    open = false;               # Pascal 无 open 内核模块
    modesetting.enable = true;  # Wayland / X11 混合必需
    powerManagement.enable = true;
  };

  # Wayland（Hyprland）+ NVIDIA 必需的 DRM modeset 参数
  boot.kernelParams = lib.mkAfter [ "nvidia-drm.modeset=1" ];

  # ── 可选 X 会话 ─────────────────────────────────────────
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.windowManager.windowmaker.enable = true;
}
