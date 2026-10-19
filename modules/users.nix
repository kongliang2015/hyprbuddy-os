# 主用户。用户名由 host 的 distro.user.name 提供。
{ config, lib, ... }:
let cfg = config.distro.user;
in
{
  users.users.${cfg.name} = {
    isNormalUser = true;
    description = if cfg.description == "" then cfg.name else cfg.description;
    extraGroups = cfg.extraGroups;
  };
}
