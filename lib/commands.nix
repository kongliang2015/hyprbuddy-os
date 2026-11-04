# 机器可读命令清单：解析 scripts/ 头部的 @command 元数据，生成 commands.json。
# 缺 @command / @summary / @category 时构建失败（防止文档与脚本漂移）。
# agentOnly 有兜底默认值：系统级（modules/desktop/hyprbuddy.nix）与用户级
# （home/default.nix）都会显式传同一份列表，漏传时不至于求值失败。
{ pkgs, lib, hostName, version, agentEnabled,
  agentOnly ? [ "agent-menu" "agent-apply" "agent-theme-sync" ] }:
pkgs.runCommand "hyprbuddy-os-commands.json" { } ''
  ${pkgs.python3}/bin/python3 ${./gen-commands.py} \
    ${../scripts} ${lib.escapeShellArg hostName} ${lib.escapeShellArg version} \
    ${lib.boolToString agentEnabled} ${lib.escapeShellArg (lib.concatStringsSep "," agentOnly)} \
    ${../skills} > $out
''
