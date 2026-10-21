# 机器可读命令清单：解析 scripts/ 头部的 @command 元数据，生成 commands.json。
# 缺 @command / @summary / @category 时构建失败（防止文档与脚本漂移）。
{ pkgs, lib, hostName, version, agentEnabled }:
pkgs.runCommand "hyprland-nixos-commands.json" { } ''
  ${pkgs.python3}/bin/python3 ${./gen-commands.py} \
    ${../scripts} ${lib.escapeShellArg hostName} ${lib.escapeShellArg version} \
    ${lib.boolToString agentEnabled} > $out
''
