# 引导器。类型由安装器探测后写入 host 的 distro.boot.*。
{ config, lib, ... }:
let cfg = config.distro.boot;
in
{
  boot.loader.systemd-boot.enable = lib.mkIf (cfg.loader == "systemd-boot") true;
  boot.loader.efi.canTouchEfiVariables = lib.mkIf (cfg.loader == "systemd-boot") true;
  boot.loader.grub.enable = lib.mkIf (cfg.loader == "grub") true;
  boot.loader.grub.device = lib.mkIf (cfg.loader == "grub") "nodev";

  # Windows 链式启动项：Windows 引导器副本放在本 ESP 的 /EFI/Microsoft/Boot/
  boot.loader.systemd-boot.extraEntries."windows.conf" = lib.mkIf cfg.windowsEntry ''
    title Windows
    efi /EFI/Microsoft/Boot/bootmgfw.efi
  '';
}
