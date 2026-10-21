#!/usr/bin/env python3
"""解析 scripts/ 头部的 @command 元数据，生成机器可读命令清单 JSON。"""
import json
import os
import re
import sys

scripts_dir, host, version, agent_enabled = (
    sys.argv[1],
    sys.argv[2],
    sys.argv[3],
    sys.argv[4] == "true",
)

FIELD = re.compile(r"^#\s*@([\w-]+):\s*(.*)$")
ARG = re.compile(r"^#\s*@arg\s+([^:]+):\s*(.*)$")
REQUIRED = ("command", "summary", "category")
CATEGORIES = {"runtime", "workflow", "check", "agent", "system"}

commands, errors = [], []

for name in sorted(os.listdir(scripts_dir)):
    path = os.path.join(scripts_dir, name)
    if name.startswith(".") or not os.path.isfile(path):
        continue
    meta, args = {}, []
    with open(path, errors="ignore") as fh:
        for line in fh:
            if not line.startswith("#"):
                if line.strip():
                    break  # 头部块结束
                continue
            line = line.rstrip("\n")
            am = ARG.match(line)
            if am:
                args.append({"name": am.group(1).strip(), "desc": am.group(2).strip()})
                continue
            m = FIELD.match(line)
            if not m:
                continue
            meta[m.group(1)] = m.group(2).strip()

    missing = [k for k in REQUIRED if not meta.get(k)]
    if missing:
        errors.append("%s: 缺少 @%s" % (name, " / @".join(missing)))
        continue
    if meta["command"] != name:
        errors.append("%s: @command 为 %r，须与文件名一致" % (name, meta["command"]))
        continue
    if meta["category"] not in CATEGORIES:
        errors.append("%s: @category=%r 不在 %s 中" % (name, meta["category"], sorted(CATEGORIES)))
        continue

    effects = [e.strip() for e in re.split(r"[;；]", meta.get("effect", "")) if e.strip()]
    cmd = {
        "name": name,
        "path": "~/.local/bin/" + name,
        "summary": meta["summary"],
        "category": meta["category"],
        "usage": meta.get("usage", name),
        "args": args,
        "effects": effects,
        "interactive": meta.get("interactive", "false").lower() == "true",
        "requires_sudo": meta.get("requires-sudo", "false").lower() == "true",
        "available": not (meta["category"] == "agent" and not agent_enabled),
    }
    if meta.get("doc"):
        cmd["doc"] = meta["doc"]
    commands.append(cmd)

if errors:
    sys.stderr.write("命令清单生成失败（补齐脚本头部元数据后重试）:\n  " + "\n  ".join(errors) + "\n")
    sys.exit(1)

payload = {
    "schema": 1,
    "generated": {
        "host": host,
        "version": version,
        "agent_enabled": agent_enabled,
        # 构建指纹：scripts/ 在 store 中的名字（内容变化即变化），用于诊断部署偏斜
        "scripts_source": os.path.basename(os.path.normpath(scripts_dir)),
        "scripts_total": len(commands),
    },
    "commands": commands,
    "workflows": [
        {
            "name": "deploy-user",
            "summary": "用户级部署（无 sudo）：构建并软链 ~/.config、~/.local/bin、skills",
            "steps": ["scripts/agent-apply <host>", "./install.sh --host <host> --yes"],
            "requires_sudo": False,
        },
        {
            "name": "deploy-system",
            "summary": "系统级应用（由用户执行）",
            "steps": ["sudo nixos-rebuild switch --flake ~/hyprland-nixos#<host>"],
            "requires_sudo": True,
        },
        {
            "name": "rollback",
            "summary": "回滚系统代际（由用户执行）",
            "steps": ["sudo nixos-rebuild --rollback"],
            "requires_sudo": True,
        },
    ],
    "paths": {
        "repo": "~/hyprland-nixos",
        "user_config": [
            "~/.config/hypr",
            "~/.config/waybar",
            "~/.config/fuzzel",
            "~/.config/kitty",
            "~/.config/mako",
            "~/.config/swayosd",
            "~/.config/Thunar",
        ],
        "skills": ["~/.codebuddy/skills/", "~/.claude/skills/"],
    },
}

sys.stdout.write(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
