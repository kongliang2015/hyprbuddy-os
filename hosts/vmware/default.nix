# VMware Workstation 虚机适配：x86_64 + BIOS/MBR + VMware SVGA。
# 复用当前机器的 hardware-configuration.nix；引导器为 GRUB(BIOS)。
{ config, lib, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nixos";
  system.stateVersion = "26.05";

  # v0 使用 flake 部署
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # VMware 客户机集成（open-vm-tools：分辨率自适应/剪贴板/时间同步）
  virtualisation.vmware.guest.enable = true;

  # 如意玲珑：容器化应用包管理（NixOS 25.11+ 原生模块，ll-cli / 网页商店）
  services.linyaps.enable = true;

  # BIOS + MBR：GRUB 必须装到磁盘，modules/boot.nix 默认 nodev 不适用
  boot.loader.grub.device = lib.mkForce "/dev/sda";
  # 显示 GRUB 菜单，等待 3 秒
  boot.loader.grub.timeoutStyle = "menu";
  boot.loader.grub.timeout = 3;
  # 压掉内核/用户态的 console 输出（plymouth 链路已设 loglevel=0，这里再补 quiet）
  boot.kernelParams = [ "quiet" ];
  # VMware SVGA 的 KMS 驱动必须提前到 initrd，plymouthd 才有 DRM 设备可画；
  # virtio.nix 只处理 virtio_gpu（QEMU），不覆盖 vmwgfx。
  boot.initrd.kernelModules = lib.mkIf config.distro.boot.plymouth.enable [ "vmwgfx" ];

  distro = {
    user.name = "leonard";
    # 注意：COSMIC 需在宿主机关闭「加速 3D 图形」——vmwgfx 的 dmabuf 导入
    # 残缺，开启 3D 加速时 Workspaces 缩略图等客户端会因协议错误 7 崩溃；
    # 关闭后 mesa 探测失败自动全栈回落 swrast，dmabuf 两端一致。
    hypervisor = "vmware";

    boot.loader = "grub";
    boot.windowsEntry = false;
    boot.plymouth.enable = true;
    # HyprBuddy 主题：仓库自带 splash 图 + 彩色进度条（pkgs/plymouth-theme-hyprbuddy）
    boot.plymouth.theme = "hyprbuddy";
    boot.plymouth.themePackages =
      lib.mkIf config.distro.boot.plymouth.enable
        [ (pkgs.callPackage ../../pkgs/plymouth-theme-hyprbuddy { }) ];

    gpu = {
      vendor = "virtio";   # 虚机通用 modesetting + Mesa 软件渲染
    };

    desktop = {
      # v1 抽象层：Hyprland + COSMIC 并存；本机日常使用 COSMIC
      sessions = [ "hyprland" "niri" ];
      default = "niri";   # COSMIC 已于 2026-10-28 退役（v1-nn 分支）
      # HyprBuddy 配套 SDDM 登录界面（pkgs/sddm-theme-hyprbuddy）
      sddmThemePackage = pkgs.callPackage ../../pkgs/sddm-theme-hyprbuddy { };
      theme = "hyprbuddy";   # sddmThemePackage 内 share/sddm/themes/ 下的目录名
    };

    hardware.battery = false;
    hardware.backlight = false;

    agent = {
      enable = false;
    };
  };
}
