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
    gpu = {
      vendor = "nvidia";
      nvidia = {
        pciIds = [ "10de:1c82" ];   # GTX 1050 Ti (GP107)；auto → legacy_580
        open = false;
      };
    };
    desktop.extraSessions = [ "xfce" "windowmaker" ];
    hardware.battery = false;
    hardware.backlight = false;
  };
}
