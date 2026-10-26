# 除 Hyprland 之外的可选 X11 会话，由 host 的 distro.desktop.extraSessions 决定。
{ config, lib, ... }:
let cfg = config.distro.desktop;
in
lib.mkIf cfg.enable {
  services.xserver.desktopManager.xfce.enable = lib.mkIf (builtins.elem "xfce" cfg.extraSessions) true;
  services.xserver.windowManager.windowmaker.enable = lib.mkIf (builtins.elem "windowmaker" cfg.extraSessions) true;

  # SDDM 默认会话：只有默认项本身被启用时才设置，否则交给 SDDM 自己挑
  services.displayManager.defaultSession =
    lib.mkIf (builtins.elem cfg.default cfg.sessions)
      (if cfg.default == "cosmic" then "cosmic" else "hyprland-uwsm");
}
