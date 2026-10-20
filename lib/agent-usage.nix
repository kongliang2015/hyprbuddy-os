# agent 用量脚本的唯一来源：系统级 Waybar 模块与生成的用户配置共用。
# 口径（与 codebuddy /cost 对齐）：主指标为当日 output tokens（真实生成量，
# 不受缓存影响）；tooltip 给出各源 out/in/cache 明细。
# 数据源：
#   codebuddy  ~/.codebuddy/projects/**/*.jsonl（message.usage，与 Claude 同构）
#   claude     ~/.claude/projects/**/*.jsonl
#   opencode   ~/.local/share/opencode/opencode-stable.db（message.data.tokens）
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

def fmt(n):
    return f"{n/1000:.1f}k" if n >= 1000 else str(n)

def scan_jsonl(root):
    """返回 (output, non_cache_input, cache_read)。input_tokens 含缓存，需减去。"""
    if not os.path.isdir(root):
        return (0, 0, 0)
    out = inp = cache = 0
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
                    if not u:
                        continue
                    c = int(u.get("cache_read_input_tokens", 0) or 0)
                    cache += c
                    out += int(u.get("output_tokens", 0) or 0)
                    inp += max(0, int(u.get("input_tokens", 0) or 0) - c)
        except OSError:
            pass
    return (out, inp, cache)

def scan_opencode():
    db = os.path.expanduser("~/.local/share/opencode/opencode-stable.db")
    if not os.path.exists(db):
        return (0, 0, 0)
    try:
        c = sqlite3.connect(db)
        out = inp = cache = 0
        for (t, data) in c.execute("select time_created, data from message"):
            ts = t / 1000 if t > 1e12 else t
            if datetime.date.fromtimestamp(ts) != today:
                continue
            try:
                d = json.loads(data)
            except Exception:
                continue
            tok = d.get("tokens") or {}
            out += int(tok.get("output", 0) or 0)
            inp += int(tok.get("input", 0) or 0)
            cache += int(((tok.get("cache") or {}).get("read", 0)) or 0)
        return (out, inp, cache)
    except Exception:
        return (0, 0, 0)

cb = scan_jsonl(os.path.expanduser("~/.codebuddy/projects"))
cl = scan_jsonl(os.path.expanduser("~/.claude/projects"))
oc = scan_opencode()

total_out = cb[0] + cl[0] + oc[0]
lines = []
for name, s in (("codebuddy", cb), ("claude", cl), ("opencode", oc)):
    if s[0] == 0 and s[1] == 0:
        lines.append(f"{name}: 无数据")
    else:
        lines.append(f"{name}: out {fmt(s[0])} / in {fmt(s[1])} / cache {fmt(s[2])}")

print(json.dumps({
    "text": fmt(total_out),
    "tooltip": "今日 output 用量（/cost 口径）\n" + "\n".join(lines),
}, ensure_ascii=False))
PY
''
