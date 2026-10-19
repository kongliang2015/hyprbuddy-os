# 除 Hyprland 之外的可选 X11 会话，由 host 的 distro.desktop.extraSessions 决定。
{ config, lib, ... }:
let cfg = config.distro.desktop;
in
lib.mkIf cfg.enable {
  services.xserver.desktopManager.xfce.enable = lib.mkIf (builtins.elem "xfce" cfg.extraSessions) true;
  services.xserver.windowManager.windowmaker.enable = lib.mkIf (builtins.elem "windowmaker" cfg.extraSessions) true;
}
