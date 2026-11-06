# 与机型无关的基础系统：时区、语言、字体、打印、音频、网络、nix 设置。
{ config, lib, pkgs, ... }:
{
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Shanghai";
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

  # 中文字体：窗口管理器字体回退、应用程序、fcitx5 界面
  fonts.packages = [
    pkgs.wqy_zenhei
    pkgs."noto-fonts-cjk-sans"
    pkgs.nerd-fonts.jetbrains-mono   # Waybar / fuzzel / kitty 图标字体
  ];

  # 中文统一走文泉驿（cosmic-text 静态链接了 fontconfig，同样吃这份配置）：
  # - 对 lang=zh 的查询把文泉驿 prepend 到最前，避免 Noto Sans CJK 被优先选中
  # - monospace 链里显式排到 Noto CJK 之前（否则终端中文会落成 Noto Sans CJK JP）
  fonts.fontconfig = {
    defaultFonts = {
      sansSerif = [ "DejaVu Sans" "WenQuanYi Zen Hei" "Noto Sans CJK SC" ];
      monospace = [ "JetBrainsMono Nerd Font" "DejaVu Sans Mono" "WenQuanYi Zen Hei" ];
      emoji = [ "Noto Color Emoji" ];
    };
    localConf = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig>
        <!-- 中文（zh-*）优先文泉驿：cosmic-text / GTK / Qt 一致 -->
        <match target="pattern">
          <test name="lang" compare="contains"><string>zh</string></test>
          <edit name="family" mode="prepend" binding="strong"><string>WenQuanYi Zen Hei</string></edit>
        </match>
        <match target="pattern">
          <test name="lang" compare="contains"><string>zh</string></test>
          <edit name="family" mode="append" binding="weak"><string>Noto Sans CJK SC</string></edit>
        </match>
      </fontconfig>
    '';
  };

  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "cn";
    variant = "";
  };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  nixpkgs.config.allowUnfree = true;

  # 二进制缓存源由 distro.mirror 决定（默认 cn = 清华 + 上交 + 中科大）。
  # 用 mkForce 覆盖默认列表（含官方 cache.nixos.org）；official 时只保留官方。
  nix.settings.substituters = lib.mkForce (
    let
      m = config.distro.mirror;
      tuna = "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store";
      sjtu = "https://mirror.sjtu.edu.cn/nix-channels/store";
      ustc = "https://mirrors.ustc.edu.cn/nix-channels/store";
    in
    if m == "official" then [ "https://cache.nixos.org/" ]
    else if m == "tuna" then [ tuna ]
    else if m == "sjtu" then [ sjtu ]
    else if m == "ustc" then [ ustc ]
    else [ tuna sjtu ustc ]
  );

  # ~/.local/bin 进 PATH：agent-commands / theme-next / hypr-check 等技能入口可裸命令调用
  environment.localBinInPath = true;

  environment.systemPackages = with pkgs; [
    git        # 仓库/安装脚本依赖；本机未启用 Home Manager，故落在系统级
    nodejs_22  # 运行时保留系统级，供所有用户/服务使用
    fzf        # theme-picker 主题预览选择（终端内）
  ];
}
