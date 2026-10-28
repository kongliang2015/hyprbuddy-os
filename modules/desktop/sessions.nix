# 桌面会话选择：由 distro.desktop.default 推导 SDDM 默认会话。
# X11 会话（XFCE / Window Maker）已于 2026-10-27 退役，不再提供。
{ config, lib, ... }:
let cfg = config.distro.desktop;
in
lib.mkIf cfg.enable {
  # SDDM 默认会话：只有默认项本身被启用时才设置，否则交给 SDDM 自己挑
  services.displayManager.defaultSession =
    lib.mkIf (builtins.elem cfg.default cfg.sessions) cfg.default;
}
