# 示例 host：QEMU virtio 虚拟机，用于验证非 NVIDIA 路径。
{ config, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "vm-virtio";
  system.stateVersion = "25.11";

  distro = {
    gpu.vendor = "virtio";
    desktop.extraSessions = [ ];
    user.name = "nixos";
    hardware.battery = false;
    # 验证 agent-usage：开启 agent 层（对齐 leonard，排除 claude-code 防构建期拉取失败）
    agent = {
      enable = true;
      agents = [ "opencode" "codebuddy" ];
      usage = true;
      diagnostics = false;
      localModels = false;
    };
  };

  # 测试用：注入宿主机 SSH 公钥，避免 boot/switch 后丢失免密登录。
  users.users.${config.distro.user.name}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHCfLhHIKYiYSR3zOc/YZBhdRNFrNsy1AFVahKGo91Hw phytium@host"
  ];
}
