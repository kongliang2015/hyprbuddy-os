# AMD：amdgpu 内核驱动 + Mesa（RADV） + VA-API 硬件解码。
{ config, lib, pkgs, ... }:
lib.mkIf (config.distro.gpu.vendor == "amd") {
  services.xserver.videoDrivers = [ "modesetting" ];
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      libva-vdpau-driver
      libva-utils
      vulkan-tools
    ];
  };
  boot.initrd.kernelModules = [ "amdgpu" ];
}
