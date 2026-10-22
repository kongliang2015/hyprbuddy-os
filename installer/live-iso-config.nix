# live + install 一体盘：启动直接进入 Hyprland 桌面（SDDM 自动登录 live 用户），
# 同时保留 install-hyprland-nixos 安装器。基于 installation-cd-minimal 的
# squashfs + tmpfs overlay 机制，根可写。
{ pkgs, lib, config, ... }:

let
  # 把仓库源码打进 ISO（安装器需要它）
  src = builtins.path {
    path = ../.;
    name = "hyprland-nixos-src";
    filter = path: _type: !(builtins.elem (baseNameOf path) [ ".git" "result" ]);
  };

  srcPkg = pkgs.runCommand "hyprland-nixos" { } ''
    mkdir -p $out/share/hyprland-nixos
    cp -r ${src}/. $out/share/hyprland-nixos
  '';

  # 复用发行版的用户级 dotfiles（linkFarm，结构对齐 ~/.config + ~/.local/bin）
  userConfig = import ../home/default.nix {
    inherit (pkgs) lib;
    pkgs = pkgs;
    inherit (config) distro;
    home = config.users.users.live.home;
    hostName = "live";
  };
in
{
  imports = [ ../modules/default.nix ];

  # 发行版开关：开启桌面 + 虚机显卡（验证虚机写死 virtio）
  distro.desktop.enable = true;
  distro.gpu.vendor = "virtio";
  # agent 层：live 环境只装 codebuddy + opencode（诊断关：无本地 ollama；
  # usage 开：waybar 显示 agent 用量）。ISO 体积 +~300M。
  distro.agent.enable = true;
  distro.agent.agents = [ "codebuddy" "opencode" ];
  distro.agent.diagnostics = false;
  distro.agent.usage = true;
  distro.user.name = "live";
  distro.user.extraGroups = [ "networkmanager" "wheel" ];

  # live + install：保留安装器
  environment.systemPackages = with pkgs; [
    git
    pciutils
    vim
    srcPkg
    (writeShellScriptBin "install-hyprland-nixos" ''
      echo "repo: ${srcPkg}/share/hyprland-nixos" >&2
      exec ${srcPkg}/share/hyprland-nixos/installer/install.sh "$@"
    '')
  ];

  # 身份 / 主机名 / ISO 元信息
  networking.hostName = lib.mkForce "hyprland-live";
  image.baseName = lib.mkForce "hyprland-nixos-live";
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";
  boot.zfs.forceImportRoot = lib.mkForce false;

  # 关闭 root 文本自动登录，让 SDDM 独占 seat
  services.getty.autologinUser = lib.mkForce "";

  # SSH：默认开启，允许密码登录（live / live）
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  # SDDM 自动登录 live 用户 -> hyprland-uwsm 会话
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "live";
  # live 用户密码 "live"（SHA-512 哈希写入 /etc/shadow，tmpfs 每次开机重建）
  users.users.live.hashedPassword = "$6$nd4EldxMwUY8PWXf$l1S7Jxh8Z6YIwBGHDMnqpz/bgV968.dznS63kUvG1feQ5wjvlLKY2ePYLXlq4kuINd/UmuFhPJrpvgCVysvLM.";
  # 免密 sudo（live 在 wheel 组），方便验证时执行命令
  security.sudo.wheelNeedsPassword = lib.mkForce false;

  # 把发行版 dotfiles 软链进 live 用户目录（等价 install.sh 的部署步骤）
  # 把发行版 dotfiles 软链进 live 用户目录（等价 install.sh 的部署步骤）。
  # 必须逐文件链接、目录保持真实可写——theme-next/wallpaper-next 会改写
  # waybar/fuzzel/mako/kitty/hypr 下的配置，整目录链到只读 store 会导致
  # 主题/壁纸切换全部失败（"只读文件系统"）。
  # share/（commands.json + 主题预览图）与 bin/ 同理逐文件链接。
  system.activationScripts.liveConfig = lib.stringAfter [ "users" ] ''
    cfg=${userConfig}
    mkdir -p /home/live/.config /home/live/.local/bin /home/live/.local/share
    cd $cfg
    find . \( -type f -o -type l \) | while read -r rel; do
      rel=''${rel#./}
      case "$rel" in
        bin/*)   dst=/home/live/.local/bin/''${rel#bin/} ;;
        share/*) dst=/home/live/.local/share/''${rel#share/} ;;
        *)       dst=/home/live/.config/$rel ;;
      esac
      mkdir -p "$(dirname "$dst")"
      ln -sfn "$cfg/$rel" "$dst"
    done
    cd /home/live
    # 壁纸：theme-next/wallpaper-next 依赖 ~/Pictures/wallpapers（安装器
    # 会拷贝，live 环境此前漏了，导致切壁纸/主题壁纸一直黑屏）
    mkdir -p /home/live/Pictures/wallpapers
    cp -f ${srcPkg}/share/hyprland-nixos/wallpapers/*.png /home/live/Pictures/wallpapers/ 2>/dev/null || true
    chown -R live:users /home/live
  '';
  # 安装 CD 模块用 mkOverride 500 强制关掉了 fontconfig（导致 /etc/fonts 整个缺失，中文豆腐块）——这里恢复
  fonts.fontconfig.enable = lib.mkForce true;
}
