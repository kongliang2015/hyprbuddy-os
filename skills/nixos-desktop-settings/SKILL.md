---
name: nixos-desktop-settings
description: hyprland-nixos 桌面配置入口：改仓库 → 求值构建 → 部署 → 自检。桌面外观/键位/状态栏/通知/主题/agent 层请求从这里开始；即时动作（切主题/壁纸/录屏等）直接调用对应脚本。
---

# nixos-desktop-settings

hyprland-nixos 发行版的桌面配置入口。**当前桌面提供方只有 niri + Noctalia**
（Hyprland / COSMIC 均已退役，见 `docs/desktop-retire-hyprland.md`）；
共享底座（SDDM / fcitx5 / Qt / polkit / 通用 CLI）在 `modules/desktop/hyprbuddy.nix`。
仓库：`~/hyprland-nixos`（`HYPRLAND_NIXOS_REPO` 可覆盖）；host 名默认 `$(hostname)`。

## 铁律

1. **改仓库源文件，绝不改 `~/.config` 下的 store 软链**
   （例外：`~/.config/noctalia/settings.json` 是 Noctalia 自己的运行时状态，可直接改，重装会回默认）
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
| 不确定入口/报错 | `agent-commands --json`（或 `list` / `show <name>`）→ `desktop-check` → `troubleshooting.md` → `git log --oneline -10` |
| 崩溃/段错误/core dump | 调用 diagnose-crash 技能（启用自动分析时先读 ~/.local/state/agent/coredump-report.md） |

## 专题指南

| 文件 | 内容 |
|---|---|
| `workflow.md` | 四步流程、生效方式、备份与回滚、agent-apply 输出判读 |
| `agent.md` | `distro.agent.*` 开关、agent-usage 口径、诊断、本地模型 |
| `troubleshooting.md` | 常见故障（待重写为 niri/Noctalia 版） |
| `hyprland.md` / `bar-notify.md` / `theming.md` | ⚠️ **已过时**（Hyprland 时代内容）。键位看 `home/niri/config.kdl`；bar/通知/OSD 走 Noctalia；壁纸走 `wallpaper set` IPC |

## 示例表

| 用户请求 | 操作 |
|---|---|
| "Mod+E 打开文件管理器" | `home/niri/config.kdl` 的 binds 段加 `Mod+E { spawn "thunar"; }` |
| "Mod+G 打开 btop" | 同文件加 `Mod+G { spawn "kitty" "-e" "btop"; }` |
| "外接 2K 显示器放右边" | `wlr-randr --output DP-1 --mode 2560x1440 --pos 1920,0`（或写进 config.kdl 的 `output` 段） |
| "圆角大一点、间隙小一点" | `home/niri/config.kdl` 的 `layout { gaps …; }` |
| "让 GIMP 默认浮动" | `window-rule { match app-id="gimp"; open-floating true; }` |
| "状态栏加 CPU 温度" | Noctalia 设置（`Mod+Shift+S` → Bar → Widgets），或改 `settings.json` 的 `showCpuTemp` |
| "通知超时/勿扰" | Noctalia 通知面板，或 `settings.json` 的 `notifications` |
| "10 分钟无操作锁屏" | `~/.config/noctalia/settings.json` 的 `idle`（当前 600s 熄屏 / 660s 锁屏 / 不挂起） |
| "终端字号改 13" | `home/kitty/kitty.conf` |
| "换个主题" | 运行 `theme-next`（循环切换；`restore` 仅供登录） |
| "照 X 官网风格做套新主题" | 技能 `theme-create`（取色 → 生成壁纸 → 追加主题表 → 部署） |
| "想先看看各主题效果再选" | 运行 `theme-picker`（须在 kitty 内；菜单：外观 → 主题预览） |
| "换壁纸" | 运行 `wallpaper-next` |
| "夜间模式/勿扰/录屏/区域截图标注" | `night-mode` / `notif-dnd` / `record-toggle` / `screenshot-annotate` |
| "现在有哪些快捷键" | `show-keybinds`（浮动 kitty）或 `docs/KEYBINDS.md` |
| "系统崩了 / 段错误 / 分析 core dump" | `diagnose-crash` 技能（先读 `~/.local/state/agent/coredump-report.md`） |
| "这台机器能做什么 / 有哪些命令" | `agent-commands list`（机器可读用 `--json`） |
| "这台新机器是 N 卡" | `hosts/<name>/default.nix` 设 `distro.gpu.vendor = "nvidia"` |
| "waybar 显示 agent 用量" | `hosts/<host>` 设 `distro.agent.enable/usage = true` |
| "桌面报错/状态栏没了/中文变方块" | `desktop-check` → `journalctl --user -b` → `troubleshooting.md` |
| "回到上一个系统版本" | 交用户 `sudo nixos-rebuild --rollback` |
| "用户级配置改了没生效" | `./install.sh --host <host> --yes`（备份到 `~/.config.bak-*`） |

## 相关技能

- `diagnose-crash`：崩溃 / 段错误 / core dump 分析（本机启用自动诊断时先读
  `~/.local/state/agent/coredump-report.md`）
- `agent-commands`：机器可读命令清单（`--json` / `list` / `show <name>` / `--category`）
- `theme-create`：照某网站/品牌风格做一套新主题（取色 → 壁纸 → 主题表 → 接入主题预览）
