# niri 桌面提供方（滚动平铺合成器 + Noctalia 外壳）。
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
    pkgs.noctalia-shell # 面板 / launcher / 通知 / 锁屏 / OSD / 夜间模式
    pkgs.xwayland-satellite # niri 无内置 Xwayland，niri 会自动拉起 PATH 中的它
  ];

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
