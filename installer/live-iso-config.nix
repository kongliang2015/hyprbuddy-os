# live + install 一体盘：启动直接进入 Hyprland 桌面（SDDM 自动登录 live 用户），
# 同时保留 install-hyprbuddy 安装器。基于 installation-cd-minimal 的
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
  distro.agent.enable = false;
  # live 盘也走 Plymouth：开机即有 splash，与安装后的系统观感一致
  distro.boot.plymouth.enable = true;
  distro.user.name = "live";
  distro.user.extraGroups = [ "networkmanager" "wheel" ];

  # 发行版品牌：菜单前缀 + os-release（NAME/PRETTY_NAME）。
  # 菜单条目名 = distroName + system.nixos.label；GRUB 字体无 CJK，用 ASCII。
  system.nixos.distroName = lib.mkForce "HyprBuddy";
  system.nixos.label = lib.mkForce "Live-generic-kernel";

  # live + install：保留安装器
  environment.systemPackages = with pkgs; [
    git
    pciutils
    vim
    srcPkg
    (writeShellScriptBin "install-hyprbuddy" ''
      echo "repo: ${srcPkg}/share/hyprland-nixos" >&2
      exec ${srcPkg}/share/hyprland-nixos/installer/install.sh "$@"
    '')
  ];

  # 身份 / 主机名 / ISO 元信息
  networking.hostName = lib.mkForce "hyprbuddy-live";
  # 输出文件名 → hyprbuddy-live.iso；卷标（stage-1 by-label 挂载用）≤32 字符
  image.baseName = lib.mkForce "hyprbuddy-live";
  isoImage.volumeID = lib.mkForce "hyprbuddy-live-26.05-${if pkgs.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64"}";
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
  system.activationScripts.liveConfig = lib.stringAfter [ "users" ] ''
    cfg=${userConfig}
    mkdir -p /home/live/.config /home/live/.local
    for d in hypr waybar fuzzel kitty mako swayosd Thunar; do
      if [ -e "$cfg/$d" ]; then
        ln -sfn "$cfg/$d" /home/live/.config/$d
      fi
    done
    if [ -e "$cfg/bin" ]; then
      ln -sfn "$cfg/bin" /home/live/.local/bin
    fi
    # share/hyprland-nixos（commands.json + 主题预览图）——theme-picker 预览用
    if [ -e "$cfg/share/hyprland-nixos" ]; then
      mkdir -p /home/live/.local/share
      ln -sfn "$cfg/share/hyprland-nixos" /home/live/.local/share/hyprland-nixos
    fi
    chown -R live:users /home/live
  '';
  # 安装 CD 模块用 mkOverride 500 强制关掉了 fontconfig（导致 /etc/fonts 整个缺失，中文豆腐块）——这里恢复
  fonts.fontconfig.enable = lib.mkForce true;
}
