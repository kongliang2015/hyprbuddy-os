# 示例 host：QEMU virtio 虚拟机，用于验证非 NVIDIA 路径。
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "vm-virtio";
  system.stateVersion = "25.11";

  distro = {
    gpu.vendor = "virtio";
    desktop.extraSessions = [ ];
    user.name = "nixos";
    hardware.battery = false;
  };
}
