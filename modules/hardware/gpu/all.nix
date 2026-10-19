# GPU 分发。四个厂商模块全部导入，各自用 mkIf 挂在 distro.gpu.vendor 上。
#
# 为什么不在 imports 里按 config 动态选择：imports 在模块收集阶段求值，
# 引用 config 会形成递归。用 mkIf 包住模块内容是最稳的写法。
{ ... }:
{
  imports = [
    ./nvidia.nix
    ./amd.nix
    ./intel.nix
    ./virtio.nix
  ];
}
