# Hyprland 桌面栈：SDDM 登录、Hyprland 会话、fcitx5、Qt/GTK 主题、系统级 Waybar。
{ config, lib, pkgs, unstablePkgs, ... }:
let
  cfg = config.distro;
  # SDDM 主题：host 可用 distro.desktop.sddmThemePackage 覆盖（theme 字段填包内目录名）
  sddmTheme = if cfg.desktop.sddmThemePackage != null then cfg.desktop.sddmThemePackage else pkgs.catppuccin-sddm;
  sddmThemeName = if cfg.desktop.sddmThemePackage != null then cfg.desktop.theme else "catppuccin-mocha-mauve";
  # polkit 认证代理：hyprtoolkit 实现（0.2.0，来自 nixpkgs-unstable）的配色
  # 读 ~/.config/hypr/hyprtoolkit.conf，可由 theme-next 按主题重写；
  # qt 实现（0.1.3，stable）配色跟随 Adwaita，无法跟随主题。
  polkitAgent =
    if cfg.polkitAgent == "hyprtoolkit" then unstablePkgs.hyprpolkitagent else pkgs.hyprpolkitagent;

  # Waybar 配置由 lib/waybar.nix 统一生成，用户级配置（home/default.nix）复用同一份。
  # 注意变量名不能叫 waybar：会遮蔽下面 with pkgs 里的 pkgs.waybar。
  waybarCfg = import ../../lib/waybar.nix {
    inherit lib;
    battery = cfg.hardware.battery;
    agentUsageCmd = cfg.desktop.waybarAgentCmd;
  };
in
lib.mkIf cfg.desktop.enable {
  # 中文输入法：fcitx5 + 拼音
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5 = {
      addons = with pkgs; [
        kdePackages.fcitx5-chinese-addons  # 拼音等中文输入引擎
        fcitx5-gtk                         # GTK 应用支持
        kdePackages.fcitx5-qt              # Qt 应用支持
      ];
    };
  };

  # 图形登录管理器：SDDM
  # LightDM 启动 Wayland 会话时会把 seat/输入设备交接搞坏（键鼠全死），
  # 而 TTY 直接 `Hyprland` 正常，故用 SDDM。greeter 保持默认 X11，在 NVIDIA 上更稳。
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.enableHidpi = false;
  services.displayManager.sddm.theme = "${sddmTheme}/share/sddm/themes/${sddmThemeName}";
  services.displayManager.sddm.extraPackages = [ sddmTheme ];
  # 修复 SDDM 0.21 (Qt6) 主题回退：主题校验要求 $out/bin/sddm-greeter，
  # 但包只产出 sddm-greeter-qt6；给包装层补符号链接后 elarun 等主题才会生效。
  services.displayManager.sddm.package = pkgs.kdePackages.sddm.overrideAttrs (old: {
    buildCommand = (old.buildCommand or "") + ''
      ln -sf sddm-greeter-qt6 $out/bin/sddm-greeter
    '';
  });
  # 会话名对应 wayland-sessions/hyprland.desktop 的文件名
  # mkDefault：默认会话由 sessions.nix（L0 分发层）按 distro.desktop.default 裁决
  services.displayManager.defaultSession = lib.mkDefault "hyprland-uwsm";

  # GTK / Qt 统一暗色主题
  qt = {
    enable = true;
    platformTheme = "gnome";     # qgnomeplatform：Qt 跟随 GTK 的 Adwaita-dark
    style = "adwaita-dark";      # 兜底 Qt 风格
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

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
  };

  # XDG 桌面门户：跨应用的截图/录屏(screencast)/文件选择器等标准接口。
  # xdg-desktop-portal-hyprland(hyprwm 官方) 提供 ScreenCast/Screenshot/GlobalShortcuts；
  # gtk 门户兜底 FileChooser 等其余接口（Hyprland wiki 推荐组合）。
  # 不配置时 Firefox 窗口共享、系统文件选择等会静默失败。
  # NixOS 的 programs.hyprland 不会自动启用 portal，需显式声明。
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    # 会话内逐接口先试 hyprland 门户，未实现的接口（如 FileChooser）落到 gtk
    config.common.default = [ "hyprland" "gtk" ];
  };

  # hyprlock 锁屏需要 PAM 服务来校验密码
  security.pam.services.hyprlock = { };

  # polkit 认证代理（GUI 提权）
  # 注意：不挂 wantedBy=graphical-session.target——否则 niri/COSMIC 会话也会
  # 拉起它（niri 下会 SIGABRT 崩溃）。Hyprland 的 exec-once 里显式
  # systemctl --user start hyprpolkitagent 负责启动。
  systemd.user.services.hyprpolkitagent = {
    description = "Hyprland Polkit Authentication Agent";
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${polkitAgent}/libexec/hyprpolkitagent";
      Restart = "on-failure";
    };
  };

  environment.systemPackages = with pkgs; [
    # ── Hyprland 桌面套件 ────────────────────────────────
    waybar        # 顶部状态栏
    kitty         # Wayland 终端（Super+Return）
    fuzzel        # 应用启动器（Super+D / Super+Space）
    hyprlock      # 锁屏（Super+L）
    swww          # 壁纸守护（26.05 更名 awww，二进制 awww-daemon）
    swaynotificationcenter # 通知守护 + 通知中心 + 控制中心（替代 mako）
    eww           # 自绘弹窗（日历/会话面板）
    hyprshell     # 窗口总览 / Alt-Tab 缩略图（需 Lua 配置管理器）
    hyprshot      # 截图（Print）
    grim          # 截图后端
    slurp         # 区域选择
    wl-clipboard  # Wayland 剪贴板
    brightnessctl # 屏幕亮度
    playerctl     # 媒体控制
    btop          # 系统监视器（Super+Space 菜单里调用）
    fastfetch     # 系统信息展示
    # ── 低难度增强特性 ───────────────────────────────────
    swayosd       # 音量/亮度屏幕 OSD
    cliphist      # 剪贴板历史
    hypridle      # 空闲自动锁屏/熄屏
    hyprsunset    # 夜间色温
    networkmanagerapplet  # 托盘网络图标
    blueman       # 托盘蓝牙
    pavucontrol   # 图形音量控制
    wf-recorder   # 屏幕录制
    swappy        # 截图标注
    hyprpicker    # 屏幕取色
    libnotify     # notify-send
    thunar        # 文件管理器（Super+E）
    polkitAgent      # polkit 认证代理（实现由 distro.polkitAgent 选择）
  ];

  # 系统级 Waybar 配置（Tokyo Night / Kanagawa 风格），放在 /etc/xdg/waybar。
  # 用户可在 ~/.config/waybar 覆盖。
  environment.etc = {
    "xdg/waybar/config".text = builtins.toJSON waybarCfg.config;
    "xdg/waybar/style.css".text = waybarCfg.css;
    "xdg/hyprland-nixos/commands.json".source = import ../../lib/commands.nix {
      inherit pkgs lib;
      hostName = config.networking.hostName;
      version = config.distro.version;
      agentEnabled = config.distro.agent.enable;
    };
  };

  # 在纯窗口管理器会话中自动启动 fcitx5。
  # 必须用 config.i18n.inputMethod.package（带 addons 的包装）：
  # 裸 pkgs.fcitx5 不含 libpinyin，会报 "Group Item pinyin ... is not valid" 并移除拼音。
  systemd.user.services.fcitx5 = {
    description = "Fcitx5 Input Method";
    # 顺序：uwsm 会话里 WAYLAND_DISPLAY 由 wayland-session-waitenv.service 在
    # graphical-session.target 之前导入进 systemd user 环境。不排这个序，fcitx5 起在
    # 变量导入之前，进程环境里只有 DISPLAY，wayland 前端报
    # "Failed to open wayland connection"，走 zwp_input_method 的原生 wayland 客户端
    # （Chromium/Electron 等）就输不了中文。
    # 不写 wayland-wm@<实例>.service：实例名取决于桌面文件（实测 Exec 为
    # `uwsm start ... hyprland.desktop`，实例多半是 hyprland 而非 hyprland-uwsm），
    # 名字写错时 After 会静默失效；waitenv 是无实例的固定单元名，语义也正好是"等变量"。
    after = [ "wayland-session-waitenv.service" ];
    serviceConfig = {
      ExecStart = "${config.i18n.inputMethod.package}/bin/fcitx5";
      Restart = "on-failure";
    };
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
  };
}
