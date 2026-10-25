# 机器可读命令清单（agent-commands）方案

> 目标：给 agent 一份**不会漂移**的入口目录，把「有哪些能力、参数、副作用、权限」
> 从散文文档变成可查询的事实。对标 Omarchy 的 `omarchy commands --json`，
> 但数据源自本仓库真实脚本，并额外覆盖非脚本工作流。

## 1. 总体设计

```
scripts/<cmd>  ──(头部 @command 元数据)──►  lib/commands.nix 生成器  ──►  commands.json (store)
                                                                    ├─► ~/.local/share/hyprland-nixos/commands.json
                                                                    └─► /etc/xdg/hyprland-nixos/commands.json（可选回退）
                                                                        ▲
                                          scripts/agent-commands ───────┘（--json / list / show / --category）
```

**为什么不手写 JSON**：手写清单必然与脚本漂移。让每个脚本头部声明元数据，
构建期解析——单一事实源就是脚本本身。

## 2. 脚本头部元数据

```bash
#!/usr/bin/env bash
# @command: theme-next
# @summary: 在 8 套内置主题间循环切换
# @category: runtime
# @usage: theme-next [restore]
# @arg restore: 应用已保存主题（登录时调用，不前进索引）
# @effect: 重写 waybar/swaync/eww 样式；替换 fuzzel/swayosd 颜色；重启 waybar/swayosd，热重载 swaync/eww
# @doc: theming.md
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `@command` | 是 | 命令名（须等于文件名） |
| `@summary` | 是 | 一句话说明（缺失则**构建失败**，防漂移） |
| `@category` | 是 | `runtime` / `workflow` / `check` / `agent` / `system` |
| `@usage` | 否 | 用法字符串 |
| `@arg` | 否 | 可多条，`name: 说明` |
| `@effect` | 否 | 副作用，`;` 分隔（agent 判断安全性的依据） |
| `@doc` | 否 | 对应指南文件（相对 `skills/nixos-desktop-settings/`） |
| `@interactive` | 否 | `true` = 会阻塞等输入，agent 不得直接调用 |
| `@requires-sudo` | 否 | `true` = 必须交用户执行 |

## 3. 产物 schema

```json
{
  "schema": 1,
  "generated": { "host": "vm-virtio", "version": "0.1.0-dev", "agent_enabled": true },
  "commands": [
    {
      "name": "theme-next",
      "path": "~/.local/bin/theme-next",
      "summary": "在 8 套内置主题间循环切换",
      "category": "runtime",
      "usage": "theme-next [restore]",
      "args": [ { "name": "restore", "desc": "应用已保存主题" } ],
      "effects": [ "重写 waybar/swaync/eww 样式", "重启 waybar/swayosd，热重载 swaync/eww" ],
      "interactive": false,
      "requires_sudo": false,
      "available": true,
      "doc": "theming.md"
    }
  ],
  "workflows": [
    {
      "name": "deploy-user",
      "summary": "用户级部署（无 sudo）",
      "steps": [ "scripts/agent-apply <host>", "./install.sh --host <host> --yes" ]
    },
    {
      "name": "deploy-system",
      "summary": "系统级应用（用户执行）",
      "steps": [ "sudo nixos-rebuild switch --flake ~/hyprland-nixos#<host>" ],
      "requires_sudo": true
    }
  ],
  "paths": {
    "repo": "~/hyprland-nixos",
    "user_config": [ "~/.config/hypr", "~/.config/waybar", "~/.config/fuzzel", "~/.config/kitty", "~/.config/swaync", "~/.config/eww", "~/.config/swayosd", "~/.config/Thunar" ],
    "skills": [ "~/.codebuddy/skills/", "~/.claude/skills/" ]
  }
}
```

`available: false` 用于 agent 关闭时的 agent 专用脚本（category=agent）。

## 4. 生成器

`lib/commands.nix`：

```nix
{ pkgs, lib, hostName, version, agentEnabled }:
pkgs.runCommand "hyprland-nixos-commands" { } ''
  ${pkgs.python3}/bin/python3 ${./gen-commands.py} \
      ${../scripts} ${hostName} ${version} ${lib.boolToString agentEnabled} > $out
''
```

`lib/gen-commands.py` 职责：解析头部 → 校验必填 → 输出规范化 JSON（`ensure_ascii=False, indent=2`）；
缺 `@command` / `@summary` / `@category` 时退出码 1，构建失败并指明文件。

## 5. 分发与消费

| 环节 | 改动 |
|---|---|
| `home/default.nix` | linkFarm 增加 `share/hyprland-nixos/commands.json` |
| `install.sh` | 新增 `share/*)` → `~/.local/share/${rel#share/}` 分支 |
| `modules/desktop/hyprland.nix` | `environment.etc."xdg/hyprland-nixos/commands.json"`（未部署用户配置时兜底） |
| `scripts/agent-commands` | `--json` 原样输出；`list` 分组；`show <name>` 详情；`--category <c>` 过滤 |

`agent-commands` 读取顺序：`~/.local/share/…` → `/etc/xdg/…`。

## 6. 技能接入

- `SKILL.md` 决策树「不确定入口/报错」：`agent-commands --json` → `hypr-check` → `git log`
- `SKILL.md` 相关技能段与示例表补 `agent-commands`
- `workflow.md` 第一步：`agent-commands list` 自查入口

## 7. 防漂移与验证

| 机制 | 说明 |
|---|---|
| 构建期强校验 | 缺 `@summary` 直接构建失败 |
| `hypr-check` 第 4 项（阶段 B） | 条目数 == `scripts/` 文件数，且每个 path 存在 |
| 自注册 | `agent-commands` 自己也带头部，出现在清单里 |
| 快照 | `jq '.commands | length'` 期望 13（12 现有 + agent-commands） |

## 8. 阶段

| 阶段 | 内容 |
|---|---|
| A | 12 脚本加头部 + 生成器 + 分发 + `agent-commands` 包装 + 技能三处引用 |
| B（可选） | `hypr-check` 第 4 项校验、`--category` 之外的过滤、`paths` 段补全 |

## 9. 明确不做

- 不解析 `--help` 输出（各脚本格式不一，脆弱）
- 不做 shell 补全生成
- 不把 agent 禁用时的脚本从清单剔除——用 `category: agent` + `available: false` 标注

> 状态：阶段 A/B 均已实施（脚本头部 + 生成器 + 分发 + 包装 + hypr-check 第 4 项一致性校验）。
