# 虚拟机（QEMU virtio / VMware 等）：通用 modesetting + Mesa 软件渲染。
{ config, lib, ... }:
lib.mkIf (config.distro.gpu.vendor == "virtio") {
  services.xserver.videoDrivers = [ "modesetting" ];
  hardware.graphics.enable = true;

  # Plymouth：把 virtio_gpu 提前到 initrd，让 KMS 在 plymouthd 启动前就绪，
  # 避免和 NVIDIA 一样的 simpledrm → 真驱动 交接（live 盘就是这么起的）。
  boot.initrd.kernelModules = lib.mkIf config.distro.boot.plymouth.enable [ "virtio_gpu" ];
}
