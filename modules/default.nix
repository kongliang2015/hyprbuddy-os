# 模块汇总入口。host 只需 import 本文件。
{ ... }:
{
  imports = [
    ./options.nix
    ./assertions.nix
    ./desktop/hyprbuddy.nix
    ./desktop/niri.nix
    ./base.nix
    ./boot.nix
    ./users.nix
    ./desktop/sessions.nix
    ./hardware/gpu/all.nix
    ./agent/default.nix
  ];
}
