# 由 installer/render-host.sh 从本模板渲染生成；占位符形如 at-VAR-at，会被替换成实际值。
# 生成结果落在 hosts/<hostname>/default.nix。
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "@HOSTNAME@";
  system.stateVersion = "@STATE_VERSION@";

  distro = {
    user.name = "@USERNAME@";

    boot.loader = "@BOOTLOADER@";
    boot.windowsEntry = @WINDOWS_ENTRY@;
    # 开机动画默认开启（主题 catppuccin-mocha）；NVIDIA 会自动补早期 KMS。
    # 不想要就把它改成 false。
    boot.plymouth.enable = true;

    gpu = {
      vendor = "@GPU_VENDOR@";
      nvidia = {
        pciIds = [ @NVIDIA_PCI_IDS@ ];
        branch = "auto";
        open = false;
      };
    };

    hardware.battery = @BATTERY@;
    hardware.backlight = @BACKLIGHT@;

    agent = {
      enable = @AGENT_ENABLE@;
      agents = [ @AGENT_LIST@ ];
      lazyAgents = [ @LAZY_AGENT_LIST@ ];
      usage = @AGENT_ENABLE@;
      diagnostics = false;   # 需先 ollama pull 后手动开
      localModels = false;
    };
  };
}
