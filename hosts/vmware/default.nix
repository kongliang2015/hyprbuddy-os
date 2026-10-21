# VMware Workstation 虚机适配：x86_64 + BIOS/MBR + VMware SVGA。
# 复用当前机器的 hardware-configuration.nix；引导器为 GRUB(BIOS)。
{ config, lib, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nixos";
  system.stateVersion = "26.05";

  # v0 使用 flake 部署
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # VMware 客户机集成（open-vm-tools：分辨率自适应/剪贴板/时间同步）
  virtualisation.vmware.guest.enable = true;

  # BIOS + MBR：GRUB 必须装到磁盘，modules/boot.nix 默认 nodev 不适用
  boot.loader.grub.device = lib.mkForce "/dev/sda";

  distro = {
    user.name = "leonard";

    boot.loader = "grub";
    boot.windowsEntry = false;

    gpu = {
      vendor = "virtio";   # 虚机通用 modesetting + Mesa 软件渲染
    };

    desktop.extraSessions = [ ];

    hardware.battery = false;
    hardware.backlight = false;

    agent = {
      enable = false;
    };
  };
}
