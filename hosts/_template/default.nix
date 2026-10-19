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

    gpu = {
      vendor = "@GPU_VENDOR@";
      nvidia = {
        pciIds = [ @NVIDIA_PCI_IDS@ ];
        branch = "auto";
        open = false;
      };
    };

    desktop.extraSessions = [ @EXTRA_SESSIONS@ ];

    hardware.battery = @BATTERY@;
    hardware.backlight = @BACKLIGHT@;

    agent = {
      enable = @AGENT_ENABLE@;
      agents = [ @AGENT_LIST@ ];
      usage = @AGENT_ENABLE@;
      diagnostics = false;   # 需先 ollama pull 后手动开
      localModels = false;
    };
  };
}
