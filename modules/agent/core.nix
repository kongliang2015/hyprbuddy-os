# agent 层：入口。安装 agent CLI，快捷键在 home/hypr/hyprland.conf 里。
{ config, lib, pkgs, ... }:
let cfg = config.distro.agent;
in
lib.mkIf cfg.enable {
  # distro.agent.agents 的取值与 nixpkgs 顶层属性名一致
  environment.systemPackages = map (name: pkgs.${name}) cfg.agents;
}
