# 发行版共享底座（与合成器无关）：SDDM 登录、输入法、Qt/GTK 主题、polkit 认证代理、通用 CLI。
#
# 这些内容原本写在 desktop/hyprland.nix 里，退役 Hyprland 时必须独立成模块，
# 否则 niri 会话会一并失去登录界面、中文输入与提权弹窗。
{ config, lib, pkgs, ... }:
let
  cfg = config.distro;

  # SDDM 主题：host 可用 distro.desktop.sddmThemePackage 覆盖（theme 字段填包内目录名）
  sddmTheme =
    if cfg.desktop.sddmThemePackage != null then cfg.desktop.sddmThemePackage else pkgs.catppuccin-sddm;
  sddmThemeName = if cfg.desktop.sddmThemePackage != null then cfg.desktop.theme else "catppuccin-mocha-mauve";

  # polkit 认证代理：hyprpolkitagent 在 niri 下会 SIGABRT（实测），改用 KDE / GNOME 实现。
  polkitAgent = if cfg.polkitAgent == "gnome" then pkgs.polkit_gnome else pkgs.kdePackages.polkit-kde-agent-1;
  polkitAgentExe =
    if cfg.polkitAgent == "gnome" then "${polkitAgent}/libexec/polkit-gnome-authentication-agent-1"
    else "${polkitAgent}/libexec/polkit-kde-authentication-agent-1";
in
lib.mkIf cfg.desktop.enable {
  # ── 中文输入法：fcitx5 + 拼音 ────────────────────────────────
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5 = {
      addons = with pkgs; [
        kdePackages.fcitx5-chinese-addons # 拼音等中文输入引擎
        fcitx5-gtk # GTK 应用支持
        kdePackages.fcitx5-qt # Qt 应用支持
      ];
    };
  };

  # 登录后自动拉起 fcitx5。
  # 必须用 config.i18n.inputMethod.package（带 addons 的包装）：裸 pkgs.fcitx5 不含
  # libpinyin，会报 "Group Item pinyin ... is not valid" 并移除拼音。
  systemd.user.services.fcitx5 = {
    description = "Fcitx5 Input Method";
    # uwsm 会话由 wayland-session-waitenv.service 导入 WAYLAND_DISPLAY 后再放行；
    # niri 会话没有该单元，且 niri.service 的 READY 早于创建 wayland socket，
    # 因此光靠 After 会抢跑（实测 waylandmodule "Failed to open wayland connection"）。
    # ExecStart 用包装脚本主动等「环境变量 + socket 文件」双双就绪。
    after = [ "wayland-session-waitenv.service" ];
    serviceConfig = {
      ExecStart = pkgs.writeShellScript "fcitx5-start" ''
        export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.gnused ]}:$PATH
        wd=""
        for _ in $(seq 1 100); do   # 最多等 10 秒，通常 0.3–1 秒
          wd=$(${config.systemd.package}/bin/systemctl --user show-environment 2>/dev/null \
                | sed -n 's/^WAYLAND_DISPLAY=//p' | head -n1)
          [ -n "$wd" ] && [ -S "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/$wd" ] && break
          sleep 0.1
        done
        if [ -n "$wd" ]; then export WAYLAND_DISPLAY="$wd"; fi
        exec ${config.i18n.inputMethod.package}/bin/fcitx5
      '';
      Restart = "on-failure";
    };
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
  };

  # ── 登录管理器：SDDM ────────────────────────────────────────
  # LightDM 启动 Wayland 会话时会把 seat/输入设备交接搞坏（键鼠全死），故用 SDDM。
  # greeter 保持默认 X11，在 NVIDIA 上更稳。
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.enableHidpi = false;
  services.displayManager.sddm.theme = "${sddmTheme}/share/sddm/themes/${sddmThemeName}";
  services.displayManager.sddm.extraPackages = [ sddmTheme ];
  # 修复 SDDM 0.21 (Qt6) 主题回退：主题校验要求 $out/bin/sddm-greeter，
  # 但包只产出 sddm-greeter-qt6；补符号链接后 elarun 等主题才会生效。
  services.displayManager.sddm.package = pkgs.kdePackages.sddm.overrideAttrs (old: {
    buildCommand = (old.buildCommand or "") + ''
      ln -sf sddm-greeter-qt6 $out/bin/sddm-greeter
    '';
  });

  # ── GTK / Qt 统一暗色主题 ──────────────────────────────────
  qt = {
    enable = true;
    platformTheme = "gnome"; # qgnomeplatform：Qt 跟随 GTK 的 Adwaita-dark
    style = "adwaita-dark"; # 兜底 Qt 风格
  };
  programs.dconf.enable = true;
  programs.dconf.profiles.user.databases = [
    {
      settings."org/gnome/desktop/interface" = {
        gtk-theme = "Adwaita-dark";
        color-scheme = "prefer-dark";
      };
    }
  ];

  programs.firefox.enable = true;

  # 默认打开方式：图片 → imv，PDF → zathura，视频 → mpv
  xdg.mime.defaultApplications = {
    "image/png" = [ "imv.desktop" ];
    "image/jpeg" = [ "imv.desktop" ];
    "image/gif" = [ "imv.desktop" ];
    "image/webp" = [ "imv.desktop" ];
    "application/pdf" = [ "org.pwmt.zathura.desktop" ];
    "video/mp4" = [ "mpv.desktop" ];
    "video/x-matroska" = [ "mpv.desktop" ];
    "video/webm" = [ "mpv.desktop" ];
  };

  # 可移动介质：Thunar 侧栏挂载 U 盘/手机（udisks2 + gvfs）
  services.udisks2.enable = true;
  # 电源配置：笔记本/台式都受益（balanced/performance/power-saver）
  services.power-profiles-daemon.enable = true;

  # 桌面门户：niri 的具体后端在 desktop/niri.nix 里声明，这里只保证服务启用
  xdg.portal.enable = true;

  # ── polkit 认证代理（GUI 提权）──────────────────────────────
  systemd.user.services.polkit-agent = {
    description = "Polkit Authentication Agent";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      # 与 fcitx5 同理：graphical-session.target 触发时 systemd 用户环境里可能还没有
      # WAYLAND_DISPLAY，Qt 找不到平台插件会立刻崩（实测 NRestarts=2 才起来）。
      # 包装脚本先等「环境变量 + socket 文件」就绪再 exec。
      ExecStart = pkgs.writeShellScript "polkit-agent-start" ''
        export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.gnused ]}:$PATH
        wd=""
        for _ in $(seq 1 100); do
          wd=$(${config.systemd.package}/bin/systemctl --user show-environment 2>/dev/null \
                | sed -n 's/^WAYLAND_DISPLAY=//p' | head -n1)
          [ -n "$wd" ] && [ -S "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/$wd" ] && break
          sleep 0.1
        done
        if [ -n "$wd" ]; then export WAYLAND_DISPLAY="$wd"; fi
        # qt.style = adwaita-dark 会把 QT_STYLE_OVERRIDE 设成 adwaita-dark，而 KDE 代理的
        # QML 对话框按 QtQuick Controls 样式名加载 → 报 module "adwaita-dark" is not installed，
        # 认证框根本弹不出来（实测：只记 REQUEST 后 polkitd 报 FAILED）。
        unset QT_STYLE_OVERRIDE
        export QT_QUICK_CONTROLS_STYLE=Basic
        exec ${polkitAgentExe}
      '';
      Restart = "on-failure";
    };
  };

  # ── 通用 CLI / 桌面工具 ─────────────────────────────────────
  environment.systemPackages = with pkgs; [
    kitty # 终端
    fuzzel # 应用启动器
    grim # 截图后端
    slurp # 区域选择
    wl-clipboard # Wayland 剪贴板
    cliphist # 剪贴板历史
    brightnessctl # 屏幕亮度
    playerctl # 媒体控制
    btop # 系统监视器
    fastfetch # 系统信息
    wf-recorder # 屏幕录制
    swappy # 截图标注
    libnotify # notify-send
    xcb-util-cursor # libxcb-cursor：Qt xcb 平台插件的依赖（X11 回退时用）
    thunar # 文件管理器
    mpv # 视频播放
    imv # 图片查看
    zathura # PDF 阅读
    wlr-randr # 显示器配置（CLI，niri 无 GUI）
    gvfs # Thunar 的挂载/回收站支持
    polkitAgent # polkit 认证代理（实现由 distro.polkitAgent 选择）
  ];

  # 命令清单（agent / CLI 自检用）
  environment.etc."xdg/hyprbuddy-os/commands.json".source = import ../../lib/commands.nix {
    inherit pkgs lib;
    hostName = config.networking.hostName;
    version = config.distro.version;
    agentEnabled = config.distro.agent.enable;
  };
}