# agent 用量脚本的唯一来源：系统级 Waybar 模块与生成的用户配置共用。
# 聚合多个 agent 的当日 token 用量，数据源缺失时静默跳过。
# 已知限制：CodeBuddy 本地无结构化 token 数据（traces 里 usage 转义嵌在
# toolInput 字符串中且会被截断），不做统计；opencode 的 message schema
# 未在线确认，SQL 做防御式解析（time_created 单位自适应）。
{ pkgs }:
pkgs.writeShellScript "agent-usage" ''
  set -uo pipefail
  # 60s 结果缓存：waybar interval=60 下避免每分钟全量扫描日志
  cache="''${XDG_RUNTIME_DIR:-/tmp}/agent-usage.cache"
  if [ -f "$cache" ] && [ "$(( $(date +%s) - $(stat -c %Y "$cache") ))" -lt 60 ]; then
    cat "$cache"
    exit 0
  fi
  ${pkgs.python3}/bin/python3 <<'PY' | tee "$cache"
import datetime, glob, json, os, sqlite3

today = datetime.date.today()
total = 0

def claude():
    root = os.path.expanduser("~/.claude/projects")
    if not os.path.isdir(root):
        return 0
    s = 0
    for p in glob.glob(root + "/**/*.jsonl", recursive=True):
        try:
            if datetime.date.fromtimestamp(os.path.getmtime(p)) != today:
                continue
            with open(p, errors="ignore") as fh:
                for line in fh:
                    try:
                        o = json.loads(line)
                    except Exception:
                        continue
                    u = (o.get("message") or {}).get("usage") or o.get("usage") or {}
                    s += int(u.get("input_tokens", 0)) + int(u.get("output_tokens", 0))
        except OSError:
            pass
    return s

def opencode():
    db = os.path.expanduser("~/.local/share/opencode/opencode-stable.db")
    if not os.path.exists(db):
        return 0
    try:
        c = sqlite3.connect(db)
        s = 0
        for (t, data) in c.execute("select time_created, data from message"):
            ts = t / 1000 if t > 1e12 else t  # >1e12 视为毫秒
            if datetime.date.fromtimestamp(ts) != today:
                continue
            try:
                d = json.loads(data)
            except Exception:
                continue
            tok = d.get("tokens") or {}
            s += int(tok.get("input", 0)) + int(tok.get("output", 0))
        return s
    except Exception:
        return 0

total = claude() + opencode()
print(f"{total/1000:.1f}k" if total >= 1000 else str(total))
PY
''
