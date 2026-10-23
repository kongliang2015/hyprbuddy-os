# 引导器。类型由安装器探测后写入 host 的 distro.boot.*。
{ config, lib, pkgs, ... }:
let
  cfg = config.distro.boot;
  ply = cfg.plymouth;
  # catppuccin-<variant> 由 catppuccin-plymouth 包提供，主题名直接决定变体
  plyCatppuccinVariant = lib.removePrefix "catppuccin-" ply.theme;
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

  # Plymouth 开机动画：开关与主题都由 host 的 distro.boot.plymouth 决定。
  # 模块会自动追加 splash 内核参数；这里只补主题包与日志级别。
  boot.plymouth = lib.mkIf ply.enable {
    enable = true;
    theme = ply.theme;
    themePackages = lib.optional (lib.hasPrefix "catppuccin-" ply.theme)
      (pkgs.catppuccin-plymouth.override { variant = plyCatppuccinVariant; });
  };
  # 开动画时把 console 输出彻底压掉：内核 console 0 级（连 ACPI 报错都不打），
  # systemd 也不往 console 写任务状态行；initrd 脚本不啰嗦。否则这些文字会在
  # splash 起来之前、plymouth 退出之后闪出来。
  boot.consoleLogLevel = lib.mkIf ply.enable 0;
  boot.initrd.verbose = lib.mkIf ply.enable false;
  boot.kernelParams = lib.optionals ply.enable [ "systemd.show_status=0" ]
    ++ lib.optionals ply.debug [ "plymouth.debug" ];
}
