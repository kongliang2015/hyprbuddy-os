---
name: nixos-desktop-settings
description: hyprland-nixos 桌面配置入口：改仓库 → 求值构建 → 部署 → 自检。桌面外观/键位/状态栏/通知/主题/agent 层请求从这里开始；即时动作（切主题/壁纸/录屏等）直接调用对应脚本。
---

# nixos-desktop-settings

hyprland-nixos 发行版（NixOS + Hyprland）的桌面配置入口。
仓库：`~/hyprland-nixos`（`HYPRLAND_NIXOS_REPO` 可覆盖）；host 名默认 `$(hostname)`。

## 铁律

1. **改仓库源文件，绝不改 `~/.config` 下的 store 软链**
   （例外：`~/.config/waybar/style.css` 由 theme-next 整份重写，本就该被脚本覆盖）
2. **agent 不执行 sudo**；系统级改动构建验证后把命令交给用户
3. `/etc/nixos/configuration.nix` 是防误用桩，**绝不修改**

## 决策树

| 请求类型 | 入口 |
|---|---|
| 即时动作：主题/壁纸/勿扰/录屏/夜间/截图标注 | 直接跑 `theme-next` / `wallpaper-next` / `notif-dnd` / `record-toggle` / `night-mode` / `screenshot-annotate` |
| 桌面外观行为：键位/规则/bar/通知/终端 | 改 `home/` → `scripts/agent-apply <host>` → `./install.sh --host <host> --yes` |
| 系统组件/服务/驱动 | 改 `modules/` 或 `hosts/<host>/` → agent-apply → 交用户 `sudo nixos-rebuild switch --flake ~/hyprland-nixos#<host>` |
| agent 能力 | `modules/agent/` + `lib/agent-usage.nix` + `scripts/agent-*`（受 `distro.agent.*`） |
| 硬件差异 / 新 host | `hosts/<name>/default.nix` 只写 `distro.*`（选项见 `modules/options.nix`） |
| 不确定入口/报错 | `scripts/hypr-check` → `troubleshooting.md` → `git log --oneline -10` |
| 崩溃/段错误/core dump | 调用 diagnose-crash 技能（启用自动分析时先读 ~/.local/state/agent/coredump-report.md） |

## 专题指南

| 文件 | 内容 |
|---|---|
| `workflow.md` | 四步流程、生效方式、备份与回滚、agent-apply 输出判读 |
| `hyprland.md` | 键位、windowrule/layerrule（0.55 语法）、monitor、装饰、输入法 |
| `bar-notify.md` | waybar（`lib/waybar.nix` 唯一来源）、mako、swayosd |
| `theming.md` | theme-next 全链路、壁纸（awww）、fuzzel 联动 |
| `agent.md` | `distro.agent.*` 开关、agent-usage 口径、诊断、本地模型 |
| `troubleshooting.md` | hypr-check 判读、常见故障 |

## 示例表

| 用户请求 | 操作 |
|---|---|
| "Super+E 改成打开 Nautilus" | `home/hypr/hyprland.conf` 改 `bind = $mainMod, E, exec, nautilus` |
| "加个 Super+G 打开 btop" | 同文件加 `bind = $mainMod, G, exec, btop` |
| "外接 2K 显示器放右边" | `monitor = DP-1, 2560x1440@60, 1920x0, 1` |
| "圆角大一点、间隙小一点" | `home/hypr/hyprland.conf` 的 decoration/general 段 |
| "让 GIMP 默认浮动" | `windowrule = match:class (gimp), float`（0.55 必须 `match:` 前缀） |
| "waybar 加 CPU 温度" | 改 `lib/waybar.nix`（唯一来源，系统级与用户级共用） |
| "通知 3 秒消失、紧急常驻" | `home/mako/config`（新增颜色键须同步 `scripts/theme-next`） |
| "10 分钟无操作锁屏" | `home/hypr/hypridle.conf` |
| "终端字号改 13" | `home/kitty/kitty.conf` |
| "换个主题" | 运行 `theme-next`（5 套循环；`restore` 仅供登录） |
| "换壁纸" | 运行 `wallpaper-next` |
| "夜间模式/勿扰/录屏/区域截图标注" | `night-mode` / `notif-dnd` / `record-toggle` / `screenshot-annotate` |
| "现在有哪些快捷键" | `show-keybinds`（浮动 kitty）或 `docs/KEYBINDS.md` |
| "这台新机器是 N 卡" | `hosts/<name>/default.nix` 设 `distro.gpu.vendor = "nvidia"` |
| "waybar 显示 agent 用量" | `hosts/<host>` 设 `distro.agent.enable/usage = true` |
| "桌面报错/状态栏没了/中文变方块" | `scripts/hypr-check` → `troubleshooting.md` |
| "回到上一个系统版本" | 交用户 `sudo nixos-rebuild --rollback` |
| "用户级配置改了没生效" | `./install.sh --host <host> --yes`（备份到 `~/.config.bak-*`） |

## 相关技能

- `diagnose-crash`：崩溃 / 段错误 / core dump 分析（本机启用自动诊断时先读
  `~/.local/state/agent/coredump-report.md`）
