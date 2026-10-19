{ pkgs, ... }:
{
  # 用户名/主目录占位符由 install.sh 按实际用户替换。
  # module 模式下 Home Manager 用系统用户信息覆盖这两项，显式写出无副作用。
  home.username = "__TARGET_USER__";
  home.homeDirectory = "/home/__TARGET_USER__";

  # install.sh 会把这里对齐到系统的 system.stateVersion
  home.stateVersion = "26.05";

  home.packages = [ pkgs.git ];
}
