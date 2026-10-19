# 虚拟机（QEMU virtio / VMware 等）：通用 modesetting + Mesa 软件渲染。
{ config, lib, ... }:
lib.mkIf (config.distro.gpu.vendor == "virtio") {
  services.xserver.videoDrivers = [ "modesetting" ];
  hardware.graphics.enable = true;
}
