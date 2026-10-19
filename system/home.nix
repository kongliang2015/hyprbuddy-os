{ pkgs, ... }:
{
  home.stateVersion = "26.05";
  home.packages = [ pkgs.git ];
}
