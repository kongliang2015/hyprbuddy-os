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
# 仅在 agent.enable 时部署的脚本清单（与 home/default.nix 的 agentOnlyScripts 同一份）
agent_only = set(filter(None, sys.argv[5].split(",")))
# skills/ 目录（store 副本），用于校验 @doc 指向的指南真实存在
skills_dir = sys.argv[6]

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
            line = line.rstrip("\r\n")
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
        # available = 该脚本会被 install.sh 部署到 PATH；
        # 不能只看 category（agent-apply/agent-menu 是 workflow/runtime 但同样 agent-only）
        "available": not (name in agent_only and not agent_enabled),
    }
    doc = meta.get("doc")
    if doc:
        # @doc 是 skills/<skill>/ 下的指南文件名；不存在即构建失败，防死引用
        found = any(
            os.path.isfile(os.path.join(skills_dir, skill, doc))
            for skill in os.listdir(skills_dir)
            if os.path.isdir(os.path.join(skills_dir, skill))
        ) if os.path.isdir(skills_dir) else False
        if not found:
            errors.append("%s: @doc=%r 在 skills/ 下找不到对应指南" % (name, doc))
        cmd["doc"] = doc
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
            "steps": ["sudo nixos-rebuild switch --flake ~/hyprbuddy-os#<host>"],
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
        "repo": "~/hyprbuddy-os",
        "user_config": [
            "~/.config/niri",
            "~/.config/kitty",
            "~/.config/fuzzel",
            "~/.config/noctalia",
            "~/.config/fastfetch",
            "~/.config/Thunar",
        ],
        "skills": ["~/.codebuddy/skills/", "~/.claude/skills/"],
        # 产物落点：<XDG_*_DIR> 是运行时展开标记（构建期无法知道用户的 XDG 目录），
        # 由 agent-commands paths 解析；其余为与主机无关的固定落点。
        "artifacts": {
            "screenshots": "<XDG_PICTURES_DIR>",
            "recordings": "<XDG_VIDEOS_DIR>",
            "wallpapers": "~/Pictures/wallpapers",
            "theme_tokens": "~/.local/share/hyprbuddy-os/themes",
            "state": "~/.local/state",
            "config_backups": "~/.config.bak-*",
        },
    },
}

sys.stdout.write(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
