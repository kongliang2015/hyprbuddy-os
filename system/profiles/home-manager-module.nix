# Home Manager 接入方式 profile：module 模式
#
# 由 system/configuration.nix 的 homeManagerMode 选择加载，默认启用。
# 用户环境随系统一起构建（nixos-rebuild 即生效），无需单独跑 home-manager switch。
# 另一种取值 "standalone" 不加载本文件，改用 channel + `home-manager switch`。
{ ... }:

{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.__TARGET_USER__ = import ../home.nix;
}
