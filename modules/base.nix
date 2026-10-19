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

  # 镜像：清华 / 上交 / 中科大 频道二进制缓存（均含 qtwebengine、linux-dev 等大包）
  # 官方 cache.nixos.org（Fastly）在本机大文件下载时易卡死，用 mkForce 强制移除
  nix.settings.substituters = lib.mkForce [
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
    "https://mirror.sjtu.edu.cn/nix-channels/store"
    "https://mirrors.ustc.edu.cn/nix-channels/store"
  ];

  environment.systemPackages = with pkgs; [
    # 个人 CLI（git/vim/wget/curl/htop）在 Home Manager 里
    nodejs_22  # 运行时保留系统级，供所有用户/服务使用
  ];
}
