# Agent 层落地方案（NixOS 版）

> **落地状态（P3，2026-10-19）**：六层已实现为 `modules/agent/*` 与 `scripts/agent-*`，
> 与本文件的映射关系记录在 `docs/IMPLEMENTATION-PLAN.md` 的 P3 验收记录中。
> 本文保留为设计依据；实现细节以代码为准。
>
> 目标：在 NixOS + Hyprland 上复刻 Omarchy 的 AI agent 层，并在声明式系统的约束下给出可执行路径。
> 关联：`docs/ROADMAP.md`、`docs/TROUBLESHOOTING.md`、skill `nixos-desktop-settings`。

## 1. 背景

### 1.1 Omarchy 的 agent 层
AI agent（Claude Code、OpenCode、Codex、Pi 等）不是外挂应用，而是**系统基础设施**：

- 统一入口（约 10 个启动器、全局快捷键 `Super+Shift+Ctrl+A`）
- 崩溃诊断（监听 `systemd-coredump`，把 core dump 交给 agent 分析）
- 用量面板（订阅状态、限额、按天/模型的 token 消耗）
- 主题同步（切主题时 agent 终端界面跟随）
- Skills：agent 可直接读写 Hyprland/Waybar/主题配置
- 本地模型（LM Studio / Ollama）

其设计哲学是**深而慢**：agent 要深入系统上下文（日志、core dump、配置树），承担需要多步读取与验证的任务，而非即时问答。

### 1.2 NixOS 的关键差异

| 维度 | Omarchy (Arch) | NixOS |
|---|---|---|
| 配置模型 | 命令式，直接改 `/etc` | 声明式，`/etc` 由 nix 生成 |
| agent 改系统 | 即时生效 | 必须改草稿并 rebuild |
| 用户级配置 | 即时 | 即时（同样） |
| 回滚 | pacman/手动 | `nixos-rebuild --rollback` / git |
| 包管理 | pacman/AUR | nix（锁定版本、可复现） |

**结论**：NixOS 上的 agent 层必须区分"两种写"：

1. **用户级**（`~/.config`、`~/.local/bin`、agent 自身配置）：agent 可即时读写，风险低。
2. **系统级**（`/etc`、systemd、软件包）：agent 只改 `~/configuration.nix.new`，验证后由用户 `sudo` 应用并 rebuild。

这正是"深而慢"在 NixOS 上的自然形态：系统级改动天然需要草稿 → 验证 → 重建。

## 2. 依赖核查

nixpkgs 25.11 中已存在的包（`nix eval` 核实）：

| 包 | 版本 | 用途 |
|---|---|---|
| `claude-code` | 2.1.140 | 云端 agent |
| `opencode` | 1.1.14 | 云端 agent |
| `codex` | 0.92.0 | 云端 agent |
| `aider-chat` | 0.86.1 | 云端 agent |
| `ollama` | 0.21.1 | 本地模型 |
| `mise` | 2025.11.7 | 工具/版本管理（可选） |

基础设施现状（本机核实）：
- `systemd-coredump` 已启用且活跃，`coredumpctl` 有历史记录（如 xdg-desktop-portal-hyprland 的 SIGSEGV）。
- 尚无任何 agent / ollama / mise 安装。
- 终端已由 kitty 的 16 色调色板统一（elarun），agent 的 ANSI 输出会自动跟随。

## 3. 逐层可行性评估

### 层 1：入口层
- **NixOS 做法**：`environment.systemPackages` 装包；Hyprland `bind` 快捷键；fuzzel 做 agent 选择器。
- **依赖**：`claude-code` / `opencode` / `codex`。
- **风险**：低。
- **工作量**：1 个 nix 块 + 1 条 bind + 1 个选择器脚本。
- **可行度**：★★★★★

### 层 2：主题同步层
- **NixOS 做法**：
  - 终端 agent 的 ANSI 颜色已由 kitty 16 色自动跟随，无需额外处理。
  - agent 自身的 dark/light 设置需同步：Claude Code `~/.claude/settings.json` 的 `theme`；OpenCode 的主题文件。
- **依赖**：无（纯用户级文件）。
- **风险**：低（需 merge 而非覆盖已有 settings）。
- **工作量**：1 个 `theme-sync` 脚本。
- **可行度**：★★★★★

### 层 3：诊断层
- **NixOS 做法**：利用已启用的 `systemd-coredump`：
  - `systemd.path` 监听 `/var/lib/systemd/coredump` 变化；
  - 触发脚本：`coredumpctl info` 提取栈 → 本地 `ollama`（或 agent CLI）分析 → `mako` 通知。
- **依赖**：`ollama`（本地，推荐）或 agent（云）。
- **风险**：中。
  - core dump 是进程内存快照，可能含密钥/密码 → 必须用本地模型或先脱敏。
  - 分析耗时、本地模型显存/内存占用。
  - `/var/lib/systemd/coredump` 需 `systemd-coredump` 组权限。
- **工作量**：1 个 nix 模块 + 1 个分析脚本。
- **可行度**：★★★★☆

### 层 4：观测层
- **NixOS 做法**：解析 agent 本地日志求 token 用量：
  - Claude Code：`~/.claude/projects/**/*.jsonl` 中的 usage 字段。
  - 汇总脚本 → Waybar 自定义模块 `custom/agent-usage`。
- **依赖**：无（只读日志）。
- **风险**：低（只读）。
- **工作量**：1 个汇总脚本 + Waybar 模块 + CSS。
- **可行度**：★★★★☆

### 层 5：变更层（NixOS 特有）
- **NixOS 做法**：agent 只改 `~/configuration.nix.new`：
  1. `nix-instantiate --parse` 语法校验；
  2. `nix-instantiate '<nixpkgs/nixos>' -A system` 完整求值（可选）；
  3. 生成 diff、通知用户 review；
  4. 用户 `sudo cp` + `nixos-rebuild switch`。
- **依赖**：nix、git。
- **风险**：中（错误配置会导致 rebuild 失败或重启 display-manager）。
- **工作量**：1 个 `apply-draft.sh`。
- **可行度**：★★★★☆
- **说明**：本项目 `sync.sh` + skill 已覆盖大半流程。

### 层 6：本地模型
- **NixOS 做法**：`services.ollama.enable = true`，模型按需拉取。
- **依赖**：`ollama`。
- **风险**：中（NVIDIA 需 CUDA 支持；显存/内存占用；首次拉模型需网络）。
- **可行度**：★★★★☆

## 4. 落地方案（分阶段）

### Phase 1：入口 + 主题同步（低风险，可当天完成）
1. `configuration.nix.new` 增加 agent 包。
2. `hyprland.conf` 增加快捷键。
3. 新增 `~/.local/bin/agent-menu`（fuzzel 选择 agent）。
4. 新增 `~/.local/bin/theme-sync`（同步 agent 的 dark 主题）。

### Phase 2：诊断层
1. nix 模块：`systemd.paths.coredump-watch` + `systemd.services.coredump-analyze`。
2. `~/.local/bin/coredump-analyze`：`coredumpctl` → 本地 ollama → mako。
3. 先用现有 core dump 验证。

### Phase 3：观测层
1. `~/.local/bin/agent-usage`：汇总 token。
2. Waybar `custom/agent-usage` 模块 + CSS。

### Phase 4：变更层 & 本地模型
1. `~/.local/bin/apply-draft`：验证草稿 + 打印 rebuild 命令。
2. 集成到 skill 工作流。
3. `services.ollama` 启用。

## 5. 关键实现片段

### 5.1 系统包
```nix
environment.systemPackages = with pkgs; [
  claude-code
  opencode
  codex
  aider-chat
  mise
  ollama
];
```

### 5.2 快捷键
```conf
# ~/.config/hypr/hyprland.conf
bind = $mainMod SHIFT, A, exec, /home/leonard/.local/bin/agent-menu
```

### 5.3 fuzzel 选择器
```bash
#!/usr/bin/env bash
# ~/.local/bin/agent-menu
choice=$(printf 'claude\nopencode\ncodex\naider' | fuzzel --dmenu --prompt 'agent> ')
[ -z "$choice" ] && exit 0
exec kitty -e "$choice"
```

### 5.4 主题同步
```bash
#!/usr/bin/env bash
# ~/.local/bin/theme-sync —— 让 agent 的 dark/light 跟随系统
mkdir -p ~/.claude
if command -v jq >/dev/null; then
  tmp=$(mktemp)
  jq '.theme = "dark"' ~/.claude/settings.json > "$tmp" 2>/dev/null \
    && mv "$tmp" ~/.claude/settings.json \
    || echo '{"theme":"dark"}' > ~/.claude/settings.json
else
  echo '{"theme":"dark"}' > ~/.claude/settings.json
fi
# OpenCode 等其他 agent 的主题文件按各自格式在此追加
```

### 5.5 coredump 诊断（nix 模块示意）
```nix
systemd.paths.coredump-watch = {
  wantedBy = [ "multi-user.target" ];
  pathConfig.PathChanged = "/var/lib/systemd/coredump";
};
systemd.services.coredump-analyze = {
  description = "Analyze newest core dump with local LLM";
  serviceConfig = {
    Type = "oneshot";
    User = "leonard";
    ExecStart = "/home/leonard/.local/bin/coredump-analyze";
  };
};
```

```bash
#!/usr/bin/env bash
# ~/.local/bin/coredump-analyze
set -euo pipefail
info=$(coredumpctl info --no-pager -1 2>/dev/null || true)
[ -z "$info" ] && exit 0
prompt="请分析下面这条 Linux core dump 的崩溃原因，并给出可执行的修复建议：\n$info"
out=$(ollama run llama3.2 "$prompt" 2>/dev/null || echo "本地模型不可用，跳过分析")
makoctl dismiss --all >/dev/null 2>&1 || true
notify-send -a "coredump-agent" "崩溃诊断" "$out"
```
> 注意：需把 `leonard` 加入 `systemd-coredump` 组，并确保 `ollama` 模型已拉取。

### 5.6 用量面板（Waybar）
```json
"custom/agent-usage": {
  "exec": "/home/leonard/.local/bin/agent-usage",
  "interval": 60,
  "format": " {}",
  "tooltip": true
}
```
`agent-usage` 解析 `~/.claude/projects/**/*.jsonl` 的 usage 字段并汇总。

### 5.7 变更层
```bash
#!/usr/bin/env bash
# ~/.local/bin/apply-draft
set -e
nix-instantiate --parse ~/configuration.nix.new >/dev/null
git -C ~/hyprland-nixos diff --stat
cat <<'EOF'
草稿语法通过。请手动执行：
  sudo cp ~/configuration.nix.new /etc/nixos/configuration.nix
  sudo nixos-rebuild switch
EOF
```

## 6. 风险与安全

1. **core dump 隐私**：core dump 含进程内存，可能有凭据。默认只用本地模型；分析后删除临时文件；不上传云端。
2. **API 费用**：云端 agent 会产生 token 费用，用量面板用于观测，必要时设限额。
3. **系统配置改写**：agent 只改草稿；必须过语法/求值校验 + diff review + 用户手动 rebuild。
4. **rebuild 副作用**：系统级改动可能重启 display-manager 导致注销，先保存工作。
5. **本地模型资源**：NVIDIA 需 CUDA；注意显存/内存占用，可限制并发与上下文长度。
6. **权限**：coredump 目录需 `systemd-coredump` 组；agent 进程不要以 root 运行。

## 7. 回滚

- 系统：`sudo nixos-rebuild switch --rollback`
- 项目：`git -C ~/hyprland-nixos log --oneline` 后 `git revert`
- 用户级：从项目 `git checkout` 恢复 `~/.config`

## 8. 实施清单

- [ ] Phase 1：装包 + 快捷键 + agent-menu + theme-sync
- [ ] Phase 2：coredump-watch 模块 + coredump-analyze
- [ ] Phase 3：agent-usage + Waybar 模块
- [ ] Phase 4：apply-draft + skill 集成 + ollama 服务
- [ ] 文档同步：更新 `docs/ROADMAP.md` 的"已完成"

## 9. 参考

- Omarchy：<https://github.com/basecamp/omarchy>
- systemd-coredump：`man coredumpctl`
- 本项目工作流：`README.md`、`docs/ROADMAP.md`
