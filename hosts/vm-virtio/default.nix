# 示例 host：QEMU virtio 虚拟机，用于验证非 NVIDIA 路径。
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "vm-virtio";
  system.stateVersion = "25.11";

  # virtio-gpu 不响应内核 video=，用 SDDM Xsetup 的 xrandr 强制 greeter 分辨率。
  services.displayManager.sddm.setupScript = "${pkgs.xorg.xrandr}/bin/xrandr --output Virtual-1 --mode 1920x1080 || true";

  distro = {
    gpu.vendor = "virtio";
    desktop.extraSessions = [ ];
    user.name = "nixos";
    hardware.battery = false;
  };

  # 测试用：注入宿主机 SSH 公钥，避免 boot/switch 后丢失免密登录。
  users.users.${config.distro.user.name}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHCfLhHIKYiYSR3zOc/YZBhdRNFrNsy1AFVahKGo91Hw phytium@host"
  ];
}
