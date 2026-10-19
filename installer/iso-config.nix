# 安装镜像：nixos 最小 ISO + 本仓库源码 + 一键安装命令。
{ pkgs, lib, ... }:
let
  # 只带 git 跟踪之外也要排除的：.git / result
  src = builtins.path {
    path = ../.;   # installer/ 的上一级即仓库根
    name = "hyprland-nixos-src";
    filter = path: _type: !(builtins.elem (baseNameOf path) [ ".git" "result" ]);
  };

  # 仓库作为普通 store 包（/etc 的目录软链在 ISO 构建时会失败）
  srcPkg = pkgs.runCommand "hyprland-nixos" { } ''
    mkdir -p $out/share/hyprland-nixos
    cp -r ${src}/. $out/share/hyprland-nixos
  '';
in
{
  environment.systemPackages = with pkgs; [
    git
    pciutils
    vim
    srcPkg
    (writeShellScriptBin "install-hyprland-nixos" ''
      echo "仓库位置: ${srcPkg}/share/hyprland-nixos" >&2
      exec ${srcPkg}/share/hyprland-nixos/installer/install.sh "$@"
    '')
  ];

  # 安装器需要直接拿到 root shell，不希望被 getty 登录拦住
  services.getty.autologinUser = lib.mkForce "root";
  networking.hostName = lib.mkForce "hyprland-installer";

  # 26.05 起 isoImage.isoName 改名为 image.fileName；文件名由 baseName + extension 组成
  image.baseName = lib.mkForce "hyprland-nixos-installer";
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";

  # 安装镜像不需要强制导入 ZFS pool
  boot.zfs.forceImportRoot = lib.mkForce false;
}
