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
  # amdgpu 绝大多数型号依赖 linux-firmware 里的 blob；关着会让驱动起不来、
  # 退回 llvmpipe 软件渲染（能进桌面但卡）。
  hardware.enableRedistributableFirmware = true;

  # 早期 KMS：amdgpu 在 initrd 阶段接管 DRM，Plymouth 直接画在 amdgpu 上，
  # 不像 NVIDIA 专有驱动那样有 simpledrm → 专有驱动的中途换主。
  boot.initrd.kernelModules = [ "amdgpu" ];
}
