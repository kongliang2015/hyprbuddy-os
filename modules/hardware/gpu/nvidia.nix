# NVIDIA 闭源驱动。
{ config, lib, pkgs, ... }:
let
  cfg = config.distro.gpu;
  nv = cfg.nvidia;

  # GPU 代际判断：Turing（RTX 20xx / GTX 16xx）及更新的 device id >= 0x1E00 (=7680)。
  # Maxwell / Pascal / Volta 低于该值，只能用 580 LTSB 分支。
  # lib.toInt 只接受十进制，这里自带一个十六进制解析。
  hexDigits = lib.listToAttrs (lib.imap0 (i: c: { name = c; value = i; })
    (lib.stringToCharacters "0123456789abcdef"));
  hexToInt = s:
    lib.foldl' (acc: c: acc * 16 + hexDigits.${lib.toLower c}) 0 (lib.stringToCharacters s);

  isTuringOrNewer = id: hexToInt (lib.last (lib.splitString ":" id)) >= 7680;

  resolvedBranch =
    if nv.branch != "auto" then nv.branch
    else if nv.pciIds == [ ] then "legacy_580"       # 580 覆盖 Maxwell→Blackwell，安全兜底
    else if lib.any isTuringOrNewer nv.pciIds then "production"
    else "legacy_580";
in
lib.mkIf (cfg.vendor == "nvidia") {
  warnings = lib.optional (nv.branch == "auto" && nv.pciIds == [ ])
    "distro.gpu.nvidia.branch=auto 但未提供 pciIds，已回退 legacy_580；请补 distro.gpu.nvidia.pciIds。";

  assertions = [
    {
      assertion = !(nv.open && resolvedBranch != "production");
      message = "Pascal 及更早架构不支持 open 内核模块，请保持 distro.gpu.nvidia.open = false。";
    }
  ];

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    branch = resolvedBranch;
    open = nv.open;
    modesetting.enable = true;      # Wayland / X11 混合必需
    powerManagement.enable = true;
  };

  # Wayland（Hyprland）+ NVIDIA 必需的 DRM modeset 参数
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];
}
