# COSMIC 桌面提供方（Phase 0：并存，不改变 Hyprland 行为）
# 由 distro.desktop.sessions 决定是否安装；COSMIC 自带 panel/launcher/
# notifications/settings/bg/screenshot/osd/lock，不需要我们的外壳组件。
{ config, lib, pkgs, unstablePkgs, ... }:
let
  cfg = config.distro.desktop;

  # COSMIC 全家桶清单：cosmicUnstable = true 时整体指向 nixpkgs-unstable。
  # 逐个取值并 or 回退 stable，防止 unstable 侧改名导致求值失败。
  # 注意 xdg-desktop-portal-cosmic 必须与 epoch 同版本，一并切换。
  cosmicPackageNames = [
    "cosmic-bg"
    "cosmic-comp"
    "cosmic-session"
    "cosmic-panel"
    "cosmic-launcher"
    "cosmic-applets"
    "cosmic-app-library"
    "cosmic-notifications"
    "cosmic-osd"
    "cosmic-idle"
    "cosmic-settings"
    "cosmic-settings-daemon"
    "cosmic-greeter"
    "cosmic-workspaces-epoch"
    "cosmic-randr"
    "cosmic-screenshot"
    "cosmic-edit"
    "cosmic-files"
    "cosmic-term"
    "cosmic-player"
    "cosmic-store"
    "cosmic-wallpapers"
    "cosmic-icons"
    "cosmic-initial-setup"
    "xdg-desktop-portal-cosmic"
  ];

  # UX 布局模板（scripts/uxctl 的 layout 子命令使用）：
  # 把仓库 ux/layouts/<模板>/ 整树装进系统 share/cosmic-layouts/<模板>/。
  # linkFarm 的 name 允许嵌套路径，递归 walk 即可。
  uxLayouts = pkgs.linkFarm "cosmic-layouts" (
    lib.concatLists (
      lib.mapAttrsToList
        (layout: _:
          let
            walk = path: prefix:
              lib.concatLists (
                lib.mapAttrsToList
                  (n: t:
                    if t == "directory"
                    then walk (path + "/${n}") "${prefix}${n}/"
                    else [ { name = "share/cosmic-layouts/${prefix}${n}"; path = path + "/${n}"; } ])
                  (builtins.readDir path)
              );
          in
          walk (../.. + "/ux/layouts/${layout}") "${layout}/")
        (lib.filterAttrs (_: t: t == "directory") (builtins.readDir (../.. + "/ux/layouts"))))
  );
in
lib.mkIf (cfg.enable && builtins.elem "cosmic" cfg.sessions) {
  services.desktopManager.cosmic.enable = true;

  # 与 Hyprland 的 portal 分开声明：COSMIC 会话走 cosmic 门户，
  # 否则截图/屏幕共享会先撞上 hyprland 门户而静默失败。
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-cosmic ];
  xdg.portal.config.cosmic.default = [ "cosmic" "gtk" ];

  # COSMIC 的会话由 NixOS 模块注册（cosmic.desktop），无需手写 desktop 文件。
  # 输入法沿用系统级 fcitx5 配置，但 COSMIC 走 text-input-v3，需实测。

  # UX 布局模板：uxctl（scripts/uxctl）的 LAYOUT_DIR 指向这里
  environment.systemPackages = [ uxLayouts ];
  environment.pathsToLink = [ "/share/cosmic-layouts" ];

  # COSMIC 系列包整体指向 nixpkgs-unstable（epoch 1.2.0 → 官方最新）
  nixpkgs.overlays = lib.optionals cfg.cosmicUnstable [
    (final: prev: lib.listToAttrs (map (name: {
      inherit name;
      value = unstablePkgs.${name} or prev.${name};
    }) cosmicPackageNames))
  ];
}
