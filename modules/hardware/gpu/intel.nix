# Intel：i915/xe + intel-media-driver（VA-API）。
{ config, lib, pkgs, ... }:
lib.mkIf (config.distro.gpu.vendor == "intel") {
  services.xserver.videoDrivers = [ "modesetting" ];
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      libva-utils
    ];
  };
  boot.initrd.kernelModules = [ "i915" ];
}
