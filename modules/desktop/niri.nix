# niri 桌面提供方（滚动平铺合成器 + Noctalia v5 外壳）。
# 由 distro.desktop.sessions 决定是否安装；架构见 docs/niri-noctalia-plan.md。
{ config, lib, pkgs, ... }:
let
  cfg = config.distro.desktop;
in
lib.mkIf (cfg.enable && builtins.elem "niri" cfg.sessions) {
  programs.niri.enable = true;

  # 文件选择走 gtk 门户（本项目用 Thunar），不额外装 nautilus
  programs.niri.useNautilus = false;

  environment.systemPackages = [
    # Noctalia v5（原生 C++ 运行时，非 v4 的 quickshell 实现）：
    # 面板 / launcher / 通知 / 锁屏 / OSD / 夜间模式。
    # 配置在 ~/.config/noctalia/*.toml，IPC 为 `noctalia msg ...`。
    pkgs.noctalia
    pkgs.xwayland-satellite # niri 无内置 Xwayland，niri 会自动拉起 PATH 中的它
  ];

  # v5 的电池 / 蓝牙 / 功耗组件依赖这些系统服务（官方 NixOS 前置要求）
  services.upower.enable = true;
  hardware.bluetooth.enable = lib.mkIf config.distro.hardware.bluetooth true;

  # 锁屏走 PAM 认证（noctalia 链接 libpam 并调用 pam_authenticate）。
  # NixOS 侧必须有同名 PAM 服务，否则锁屏无法验证密码。
  security.pam.services.noctalia = { };

  # 门户分会话：niri 走 gnome（录屏/文件选择）+ gtk，避免与
  # hyprland 的门户互相抢占
  xdg.portal.extraPortals = [
    pkgs.xdg-desktop-portal-gnome
    pkgs.xdg-desktop-portal-gtk
  ];
  xdg.portal.config.niri.default = [ "gnome" "gtk" ];
  # 文件选择器走 gtk 门户：gnome 门户 47+ 默认用 nautilus，我们没装 nautilus，
  # 不显式指定会让 Flatpak 应用的「打开文件」对话框失败。
  xdg.portal.config.niri."org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
}
