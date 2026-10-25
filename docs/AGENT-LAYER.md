# Agent 层（NixOS 版）：设计与实现

> **状态（2026-10-21）**：六层全部实现并通过实测验证。本文保留设计依据，内容已与代码同步；
> 实现细节以代码为准。关联：`docs/ROADMAP.md`、`docs/TROUBLESHOOTING.md`、skill `nixos-desktop-settings`。
>
> 目标：在 NixOS + Hyprland 上实现 agent 层，并在声明式系统的约束下给出可执行路径。

## 1. 背景

### 1.1 Omarchy 的 agent 层
AI agent（Claude Code、OpenCode、Codex 等）不是外挂应用，而是**系统基础设施**：

- 统一入口（全局快捷键 `Super+Shift+Ctrl+A` + fuzzel 选择器）
- 崩溃诊断（监听 `systemd-coredump`，把 core dump 交给本地模型分析）
- 用量面板（按天的 token 消耗，接入 Waybar）
- 主题同步（切主题时 agent 界面跟随）
- Skills（agent 读写 Hyprland/Waybar/主题配置）
- 本地模型（Ollama）

设计哲学是**深而慢**：agent 深入系统上下文（日志、core dump、配置树），承担需要多步读取与验证的任务。

### 1.2 NixOS 的关键差异（flake 流）

| 维度 | Omarchy (Arch) | 本项目（NixOS 26.05 + flake） |
|---|---|---|
| 配置模型 | 命令式，直接改 /etc | 声明式，全部由 `~/hyprland-nixos` flake 生成 |
| agent 改系统 | 即时生效 | 改仓库 → 构建验证 → 用户 `sudo --flake` |
| 用户级配置 | 即时 | 改仓库 → `install.sh` 链接 |
| 回滚 | pacman/手动 | `nixos-rebuild --rollback` / git revert |
| 包管理 | pacman/AUR | nix（锁定版本、可复现） |

**结论**：NixOS 上必须区分两种写：

1. **用户级**（`home/` `lib/` `scripts/` → `install.sh`）：无 sudo，可即时验证。
2. **系统级**（`hosts/` `modules/`）：agent 只改仓库并构建验证，sudo 命令交由用户执行；
   **绝不修改 `/etc/nixos/configuration.nix`**（防误用桩，不带 `--flake` 的 rebuild 会读它并报错）。

## 2. 依赖与基础设施（2026-10-21 实测）

| 组件 | 状态 |
|---|---|
| `codebuddy` 2.170.0 | 本仓库打包（`pkgs/codebuddy`），主力 agent |
| `opencode` | nixpkgs，已装 |
| `claude-code` | nixpkgs 存在，本机构建期无法访问 downloads.claude.ai，未启用 |
| `codex` / `aider-chat` | nixpkgs 存在，可选，未装 |
| `ollama` 0.40.3 | 包变体 `ollama-cuda/rocm/vulkan/cpu`，本机未启用 |

基础设施：`systemd-coredump` 活跃；kitty 16 色统一（agent ANSI 自动跟随）；swaync 通知；awww 壁纸守护。

## 3. 六层：设计与实现

### 层 1：入口层

**设计**：系统包 + 全局快捷键 + fuzzel 选择器。

**实现**：
- `modules/agent/core.nix`：`distro.agent.agents`（enum：claude-code / codebuddy / opencode / codex / aider-chat）→ `environment.systemPackages`
- `scripts/agent-menu`：PATH 探测已安装的 agent → fuzzel 选择 → kitty 启动（5 个内建分支）
- 绑定：`Super+Shift+Ctrl+A`（`home/default.nix` 生成，受 `agent.enable` 控制）

**状态**：已实现；本机 `agents = [ opencode codebuddy ]`。

**细节**：enum 值是包名，菜单 case 是命令名（claude-code→claude、aider-chat→aider，已实测 nixpkgs `mainProgram`）；
agent 层默认关闭，三个 agent 脚本随 `agent.enable` 安装（`home/default.nix` 的 `scriptNames` 过滤）。

### 层 2：主题同步层

**设计**：agent 的 dark/light 跟随系统主题。

**实现**：`scripts/agent-theme-sync [dark|light]`：
- claude：`~/.claude/settings.json` 的 `theme`（jq merge；无 jq 时 python3 兜底）
- opencode：`~/.config/opencode/tui.json` 的 `theme`（注意 `opencode.json` 的 theme 键已被官方废弃）
- 由 `scripts/theme-next` 每次切换/restore 调用（脚本不存在时静默跳过）

**状态**：已实现并实测（幂等、保留其他键）。

**已知限制**：CodeBuddy 的 settings.json 暂无 theme 字段，未覆盖。dark/light 由 `theme-next` 按主题表里 waybar 背景色亮度自动判定（浅色主题如 WorkBuddy 传 light）。

### 层 3：诊断层

**设计**：coredump → 本地模型分析 → 通知（不上传云端）。

**实现**：`modules/agent/diagnostics.nix`：
- `systemd.paths.coredump-watch`：`PathChanged = /var/lib/systemd/coredump` + **`pathConfig.Unit = coredump-analyze.service`**
- `systemd.services.coredump-analyze`：`User` 为当前用户、`SupplementaryGroups = systemd-coredump`、wants/after ollama
- 脚本：`coredumpctl info -1` → ollama `/api/generate` → `~/.local/state/agent/coredump-report.md` + swaync 通知
- 断言：`diagnostics` 需要 `localModels = true`（不上传 core dump）

**状态**：代码就绪，**本机未启用**（`diagnostics = false`；需 `localModels` + `ollama pull`）。

**关键修复**：`systemd.path` 默认触发**同名 service**，当 path 与 service 名字不同时必须显式 `Unit=`，
否则事件会去拉起不存在的单元、链路静默断裂（2026-10-21 修复）。

### 层 4：观测层

**设计**：agent token 用量 → Waybar 面板。

**实现**：`lib/agent-usage.nix`（三源聚合）：
- codebuddy：`~/.codebuddy/projects/**/*.jsonl` 的 `message.usage`（与 Claude Code 同构）
- claude：`~/.claude/projects/**/*.jsonl`
- opencode：`~/.local/share/opencode/opencode-stable.db` 的 `message.data.tokens`
- 口径与 codebuddy `/cost` 对齐：主指标为当日 **output**；`input_tokens` 含缓存，需减 `cache_read_input_tokens`；60s 缓存
- 输出 JSON：`text` = 当日 output，`tooltip` = 各源 out/in/cache 明细
- Waybar 侧：`custom/agent-usage`（`return-type = json`，`format = AGENT {}`）

**状态**：已实现；本机显示 `AGENT <今日 output>`，悬停看分源明细。

**注意**：jsonl 没有 cache write 字段，`/cost` 的 cache write 无法从日志复现。

### 层 5：变更层（flake 流）

**设计（原）**：agent 只改草稿 → 校验 → 用户 sudo。

**实现（现行）**：
- `scripts/agent-apply`：`git diff --stat` → `nix eval` 求值 → `nixos-rebuild build` → 打印
  `sudo nixos-rebuild switch --flake ~/hyprland-nixos#<host>`
- 用户级：`./install.sh --host <host> --yes`
- 自检：`scripts/hypr-check`（configerrors + 规则语法 lint + lua 优先检测），`install.sh` 末尾自动运行
- 工作流固化：skill `nixos-desktop-settings`（flake 流；skill 已收编进仓库 skills/，由 install.sh 链接到 ~/.codebuddy/skills/；channel 时代引用已全部清除）

**关键约束**：
- agent 不执行 sudo（需密码）；系统级改动一律构建验证后交用户执行
- `/etc/nixos/configuration.nix` 是防误用桩，绝不修改
- channel 时代的 `~/configuration.nix.new` 已归档到 `docs/configuration-25.11-archive.nix`

**状态**：已实现；本项目全部变更均走此流程。

### 层 6：本地模型

**实现**：`modules/agent/local-llm.nix` 按 `distro.gpu.vendor` 选择 ollama 变体
（nvidia→ollama-cuda、amd→ollama-rocm、intel→ollama-vulkan、其他→ollama-cpu），`host = 127.0.0.1`。

**状态**：代码就绪，本机未启用（`localModels = false`）。

**细节**：26.05 移除了 `services.ollama.acceleration` 选项，改用包变体。

## 4. 落地阶段（已完成）

| Phase | 内容 | 状态 |
|---|---|---|
| 1 | 入口 + 主题同步 | 已完成 |
| 2 | 诊断层 | 已实现，本机未启用 |
| 3 | 观测层 | 已完成（三源聚合） |
| 4 | 变更层 + 本地模型 | 变更层已完成；本地模型代码就绪未启用 |

## 5. 关键实现（文件索引）

| 能力 | 文件 |
|---|---|
| 选项定义 | `modules/options.nix`（`distro.agent.*`） |
| 入口 | `modules/agent/core.nix`、`scripts/agent-menu` |
| 主题 | `scripts/agent-theme-sync`（由 `theme-next` 调用） |
| 诊断 | `modules/agent/diagnostics.nix` |
| 观测 | `lib/agent-usage.nix` + `lib/waybar.nix` |
| 变更 | `scripts/agent-apply`、`install.sh`、`scripts/hypr-check` |
| 本地模型 | `modules/agent/local-llm.nix` |

## 6. 风险与安全

1. **core dump 隐私**：只走本地模型，分析结果落本地，不上传云端。
2. **API 费用**：output 用量可在 Waybar 的 AGENT 模块观测（tooltip 有分源明细）。
3. **系统配置改写**：agent 只改仓库 + 构建验证，sudo 由用户执行；错误配置在 build 阶段暴露。
4. **rebuild 副作用**：可能重启 display-manager 导致注销，先保存工作。
5. **本地模型资源**：NVIDIA 需 CUDA 变体包；注意显存占用，可限制并发与上下文。
6. **规则静默失效**：Hyprland 0.55 下旧 windowrule/layerrule 可能不报错但失效——改完必须 `hyprctl configerrors` + 实测行为（`hypr-check` 会做语法 lint）。

## 7. 回滚

- 系统：`sudo nixos-rebuild switch --rollback`，或切回旧 git 提交后 `--flake` 重建
- 项目：`git log --oneline` 后 `git revert`
- 用户级：重新 `install.sh`（旧文件备份在 `~/.config.bak-*`，`~/.local/bin` 软链指向 store）

## 8. 实施清单

- [x] Phase 1：包 + 快捷键 + agent-menu + theme-sync
- [x] Phase 2：coredump-watch + coredump-analyze（`Unit=` 已修；本机未启用）
- [x] Phase 3：agent-usage（三源）+ Waybar 模块
- [x] Phase 4：agent-apply + skill 集成（flake 流）；ollama 服务代码就绪（未启用）
- [x] 文档同步：本文件已与实现对齐

## 9. 参考

- Omarchy：<https://github.com/basecamp/omarchy>
- systemd-coredump：`man coredumpctl` / `man systemd.path`
- 本项目：`README.md`、`docs/ROADMAP.md`、`docs/TROUBLESHOOTING.md`
