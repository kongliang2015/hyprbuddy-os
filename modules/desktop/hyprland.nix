# Hyprland 桌面提供方（过渡期保留，niri 为默认会话）。
# 共享底座（SDDM / 输入法 / Qt / polkit / 通用 CLI）已移到 desktop/hyprbuddy.nix；
# 这里只剩 Hyprland 专属内容，退役时整个文件删除即可。
{ config, lib, pkgs, ... }:
let
  cfg = config.distro;
  # 系统级 Waybar 配置（/etc/xdg/waybar），用户级在 home/default.nix 复用同一份
  waybarCfg = import ../../lib/waybar.nix {
    inherit lib;
    battery = cfg.hardware.battery;
    agentUsageCmd = cfg.desktop.waybarAgentCmd;
  };
in
lib.mkIf (cfg.desktop.enable && builtins.elem "hyprland" cfg.desktop.sessions) {
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
  };

  # XDG 门户：hyprland 官方实现负责 ScreenCast/Screenshot/GlobalShortcuts，gtk 兜底其余接口。
  xdg.portal.extraPortals = with pkgs; [
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
  ];
  xdg.portal.config.common.default = [ "hyprland" "gtk" ];

  # hyprlock 锁屏需要 PAM 服务来校验密码
  security.pam.services.hyprlock = { };

  environment.systemPackages = with pkgs; [
    waybar # 顶部状态栏
    hyprlock # 锁屏（Super+L）
    swaynotificationcenter # 通知守护 + 控制中心
    eww # 自绘弹窗（日历/会话面板）
    hyprshell # 窗口总览 / Alt-Tab 缩略图
    hyprshot # 截图（Print）
    swayosd # 音量/亮度屏幕 OSD
    hypridle # 空闲自动锁屏/熄屏
    hyprsunset # 夜间色温
    hyprpicker # 屏幕取色
  ];

  # 系统级 Waybar 配置，放在 /etc/xdg/waybar（用户可在 ~/.config/waybar 覆盖）
  environment.etc = {
    "xdg/waybar/config".text = builtins.toJSON waybarCfg.config;
    "xdg/waybar/style.css".text = waybarCfg.css;
  };
}
