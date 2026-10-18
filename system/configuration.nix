# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Windows entry (separate disk nvme1n1), chainloaded via the copy of its
  # bootloader placed on this ESP at /EFI/Microsoft/Boot/bootmgfw.efi.
  boot.loader.systemd-boot.extraEntries."windows.conf" = ''
    title Windows
    efi /EFI/Microsoft/Boot/bootmgfw.efi
  '';


  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Select internationalisation properties.
  i18n.defaultLocale = "zh_CN.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };

  # 中文字体：让 Window Maker 字体回退、应用程序及 fcitx5 界面能渲染中文
  fonts.packages = [
    pkgs.wqy_zenhei
    pkgs."noto-fonts-cjk-sans"
    pkgs.nerd-fonts.jetbrains-mono   # Waybar / fuzzel / kitty 的图标字体
  ];
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

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the XFCE Desktop Environment.
  services.xserver.desktopManager.xfce.enable = true;

  # 图形登录管理器：SDDM。
  # LightDM 启动 Wayland 会话时会把 seat/输入设备交接搞坏（键鼠全死），
  # 而 TTY 直接 `Hyprland` 正常，故改用 SDDM。
  # 注意：greeter 保持默认 X11（不启用 wayland.enable），在 NVIDIA 上更稳；
  # SDDM 仍能正常启动 Hyprland 这个 Wayland 会话。
  services.displayManager.sddm.enable = true;

  # 登录界面主题：elarun（暗色风景背景，与 Kanagawa 风格协调）
  services.displayManager.sddm.theme = "elarun";

  # 默认会话设为 Hyprland —— 登录界面会预选它（仍可改选 XFCE/Window Maker）。
  # 会话名对应 wayland-sessions/hyprland.desktop 的文件名。
  services.displayManager.defaultSession = "hyprland";

  # Enable the Window Maker desktop environment (selectable session in LightDM).
  services.xserver.windowManager.windowmaker.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "cn";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.leonard = {
    isNormalUser = true;
    description = "leonard";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # 镜像：清华/上交/中科大 频道二进制缓存（均含 qtwebengine、linux-dev 等大包）
  # 官方 cache.nixos.org（Fastly）在本机大文件下载时易卡死，用 mkForce 强制移除
  nix.settings.substituters = pkgs.lib.mkForce [
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
    "https://mirror.sjtu.edu.cn/nix-channels/store"
    "https://mirrors.ustc.edu.cn/nix-channels/store"
  ];

  services.xserver.videoDrivers = [ "nvidia" ];

  # NVIDIA 驱动配置
  hardware.nvidia = {
    # 驱动版本：stable / beta / production / vulkan_beta
    # 不同系列显卡选不同分支，见下方说明
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # 使用内核模块模式（现代 GPU 推荐）
    open = false;  # 闭源内核模块；Turing+(RTX 20系及以上) 可设为 true 使用开源内核模块

    # Wayland / X11 混合相关
    modesetting.enable = true;

    # 电源管理（笔记本推荐开启，台式机可选）
    powerManagement.enable = true;
    # 细粒度电源管理（仅部分笔记本需要）
    # powerManagement.finegrained = true;
  };

  # 如果用 Wayland，确保内核支持
  # boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  # Install firefox.
  programs.firefox.enable = true;

  # Hyprland (Wayland) 桌面会话 —— 可在 LightDM 中与 XFCE 一并选择
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # hyprlock 锁屏需要 PAM 服务来校验密码
  security.pam.services.hyprlock = { };

  # NVIDIA DRM modeset：Wayland/Hyprland 在此显卡上必需的开关
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # 个人 CLI（git/vim/wget/curl/htop）已迁移到 Home Manager (~/.config/home-manager/home.nix)
    nodejs_22  # 运行时保留系统级，供所有用户/服务使用
    # ── Hyprland 桌面套件 ────────────────────────────────
    waybar        # 顶部状态栏
    kitty         # Wayland 终端（Super+Return）
    fuzzel        # 应用启动器（Super+D / Super+Space）
    hyprlock      # 锁屏（Super+L）
    hyprpaper     # 壁纸
    mako          # 通知守护进程
    hyprshot      # 截图（Print）
    grim          # 截图后端
    slurp         # 区域选择
    wl-clipboard  # Wayland 剪贴板
    brightnessctl # 屏幕亮度
    playerctl     # 媒体控制
    btop          # 系统监视器（Super+Space 菜单里调用）
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
  ];

  # 系统级 Waybar 配置（Tokyo Night 风格），放在 /etc/xdg/waybar。
  # 用户可在 ~/.config/waybar 覆盖。
  environment.etc = {
    "xdg/waybar/config".text = ''
      {
        "layer": "top",
        "position": "top",
        "height": 28,
        "spacing": 4,
        "margin-top": 6,
        "margin-left": 10,
        "margin-right": 10,
        "radius": 12,
        "modules-left": ["hyprland/workspaces", "hyprland/window"],
        "modules-center": ["hyprland/window"],
        "modules-right": ["tray", "pulseaudio", "network", "cpu", "memory", "battery", "clock"],
        "hyprland/workspaces": { "disable-scroll": true, "show-special": true },
        "pulseaudio": { "format": "{volume}%", "format-muted": "MUTE" },
        "network": { "format-wifi": "WIFI {essid}", "format-ethernet": "ETH" },
        "cpu": { "format": "CPU {usage}%" },
        "memory": { "format": "RAM {}%" },
        "battery": { "format": "BAT {capacity}%", "format-charging": "CHG {capacity}%" },
        "clock": { "format": "{:%H:%M %a %d}" }
      }
    '';
    "xdg/waybar/style.css".text = ''
      * {
        font-family: "Noto Sans CJK SC", sans-serif;
        font-size: 13px;
        color: #c0caf5;
        border: none;
        border-radius: 0;
      }
      window#waybar { background: transparent; }
      window#waybar > box {
        background: #16161e;
        border-radius: 12px;
        padding: 2px 8px;
        margin: 0 4px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.4);
      }
      #workspaces button { padding: 0 6px; color: #565f89; border-radius: 8px; }
      #workspaces button.active { color: #7aa2f7; background: #1f2335; }
      #workspaces button.urgent { color: #f7768e; }
      #clock { color: #7dcfff; }
      #cpu { color: #9ece6a; }
      #memory { color: #e0af68; }
      #battery { color: #bb9af7; }
      #pulseaudio { color: #2ac3de; }
    '';
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
  # 在 Window Maker 等纯窗口管理器会话中自动启动 fcitx5 输入法
  # 注意：必须用 config.i18n.inputMethod.package（带 addons 的包装）。
  # 不能用 pkgs.fcitx5 —— 裸包不含 libpinyin，fcitx5 会报
  # "Group Item pinyin in group 默认 is not valid" 并移除拼音，导致打不出中文。
  systemd.user.services.fcitx5 = {
    description = "Fcitx5 Input Method";
    serviceConfig = {
      ExecStart = "${config.i18n.inputMethod.package}/bin/fcitx5";
      Restart = "on-failure";
    };
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
  };


}
