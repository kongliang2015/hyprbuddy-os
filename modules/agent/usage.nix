# agent 层：用量观测。汇总 Claude Code 会话日志的 token 用量，注入 Waybar。
{ config, lib, pkgs, ... }:
let
  cfg = config.distro.agent;

  agentUsage = pkgs.writeShellScript "agent-usage" ''
    set -uo pipefail
    dir="''${HOME}/.claude/projects"
    [ -d "$dir" ] || exit 0
    ${pkgs.python3}/bin/python3 - "$dir" <<'PY'
import datetime, json, os, sys

root = sys.argv[1]
today = datetime.date.today()
total = 0
for dirpath, _, names in os.walk(root):
    for name in names:
        if not name.endswith(".jsonl"):
            continue
        path = os.path.join(dirpath, name)
        try:
            if datetime.date.fromtimestamp(os.path.getmtime(path)) != today:
                continue
            with open(path, errors="ignore") as fh:
                for line in fh:
                    try:
                        obj = json.loads(line)
                    except Exception:
                        continue
                    usage = (obj.get("message") or {}).get("usage") or obj.get("usage") or {}
                    total += int(usage.get("input_tokens", 0)) + int(usage.get("output_tokens", 0))
        except OSError:
            continue
print(f"{total/1000:.1f}k" if total >= 1000 else str(total))
PY
  '';
in
lib.mkIf (cfg.enable && cfg.usage) {
  distro.desktop.waybarRightExtra = [ "custom/agent-usage" ];

  distro.desktop.waybarConfig."custom/agent-usage" = {
    exec = "${agentUsage}";
    interval = 60;
    format = "AGENT {}";
    tooltip = true;
  };

  distro.desktop.waybarCssExtra = ''
    #custom-agent-usage { color: #bb9af7; padding: 0 6px; }
  '';
}
