# agent 用量脚本的唯一来源：系统级 Waybar 模块与生成的用户配置共用。
{ pkgs }:
pkgs.writeShellScript "agent-usage" ''
  set -uo pipefail
  dir="''${HOME}/.claude/projects"
  # 还没用过 Claude Code 时输出 0，避免 Waybar 出现空白模块
  if [ ! -d "$dir" ]; then echo 0; exit 0; fi
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
''
