# 懒加载 agent（codex / claude-code / aider-chat）评估

> **状态：未实施（2026-11-06 评估）** · 评估基准 `hyprbuddy-os` @ `d15df1a`
> `next-feature/` 存放**尚未落地**的新特性评估：不属于现行规范、不计入 `docs/SKILLS.md`
> 的技能数、不随 `install.sh` 部署。现状说明以 `docs/ROADMAP.md` 与 `docs/INDEX.md` 为准。
>
> 背景：Omarchy 预置约 10 个 AI 编程 CLI 的启动器，实体程序由 mise shim 在首次运行时下载
>（「懒加载」）。本项目的 agent 是声明式预装：`distro.agent.agents` 里列出的包在构建期
> 进入 `environment.systemPackages`。本文评估「把未启用的 codex / claude-code / aider-chat
> 改成按需拉取」是否值得、怎么做。

## 1. 需求与结论

目标：让 `codex` / `claude-code` / `aider-chat` 在需要时可用，但不进入系统包、
不阻塞 `nixos-rebuild`，同时保持版本可复现。

结论：**可行，推荐 Nix 式懒加载** —— 首次运行 `nix build`，版本由本仓库 `flake.lock`
固定的 nixpkgs 决定，产物进 store 并建 out-link 缓存；**不采用** Omarchy 的 mise/npm
shim（版本随上游漂移，与「可审计、可回滚」定位冲突）。

## 2. 现状盘点

| 项 | 现状 | 依据 |
|---|---|---|
| 支持的 agent | 枚举 5 个：`claude-code` / `codebuddy` / `opencode` / `codex` / `aider-chat` | `modules/options.nix:203` |
| 实际启用 | `leonard`、`vm-virtio` 均为 `[ "opencode" "codebuddy" ]`；`vmware` 关闭 agent 层 | `hosts/*/default.nix` |
| 安装方式 | `environment.systemPackages = map (name: pkgs.${name}) cfg.agents` | `modules/agent/core.nix` |
| nixpkgs 可用性（2026-11-06 求值） | `codex-0.146.0`、`claude-code-2.1.223`、`aider-chat-0.86.1` | `nix eval ... .name` |
| 菜单发现 | `agent-menu` 只列 PATH 中 `command -v` 命中的 agent | `scripts/agent-menu` |
| 用量统计 | `agent-usage` 按 `~/.claude/projects` 等日志路径统计，与安装方式无关 | `lib/agent-usage.nix` |
| 自检 | `desktop-check` 检查键位引用的命令是否存在 | `scripts/desktop-check` |

## 3. 三种形态

| 形态 | 内容 | 判断 |
|---|---|---|
| A 维持现状 | 需要时把包名加进 `distro.agent.agents`，重建并 switch | 不够：`claude-code` 构建期需访问 `downloads.claude.ai`（`hosts/leonard/default.nix` 注释），会把网络问题带进系统构建 |
| B Nix 式懒加载（推荐） | flake 暴露单包；`agent-shim` 首次运行 `nix build`，之后走 out-link 缓存 | 推荐：版本仍由 `flake.lock` 固定，失败被限制在首次运行 |
| C Omarchy 式 shim | mise / npm 从上游拉最新版 | 不推荐：版本漂移、与 lock 脱节、破坏可复现 |

## 4. 推荐方案

### 4.1 flake 暴露单包（示意，按 `flake.nix` 实际结构落地）

```nix
packages = lib.mapAttrs
  (system: names:
    lib.genAttrs names homePkg
    // { iso = mkIso system; liveIso = mkLiveIso system; }
    // lib.optionalAttrs (system == "x86_64-linux") {
         codex       = nixpkgs.legacyPackages.${system}.codex;
         claude-code = nixpkgs.legacyPackages.${system}.claude-code;
         aider-chat  = nixpkgs.legacyPackages.${system}.aider-chat;
       })
  hostsBySystem;
```

### 4.2 `scripts/agent-shim`

```bash
#!/usr/bin/env bash
# @command: agent-shim
# @summary: 懒加载 agent 启动器（首次运行按 flake.lock 构建，之后走缓存）
# @category: runtime
# @usage: agent-shim（由 codex / claude 等 shim 链接调用，按 $0 判断名字）
# @effect: 首次运行写 ~/.local/state/agent-shims/<name>（out-link）
set -euo pipefail
name=$(basename "$0")
repo="${HYPRBUDDY_OS_REPO:-$HOME/hyprbuddy-os}"
cache="${XDG_STATE_HOME:-$HOME/.local/state}/agent-shims/$name"
if [ ! -x "$cache/bin/$name" ]; then
  notify-send -a agent-shim "首次运行 $name" "正在按 flake.lock 拉取，稍等…" 2>/dev/null || true
  nix build --out-link "$cache" "$repo#$name"
fi
exec "$cache/bin/$name" "$@"
```

> `--refresh`（可选）：删除 `$cache` 后重跑，用于 `flake.lock` 更新后刷新版本。

### 4.3 选项与断言

```nix
lazyAgents = mkOption {
  type = types.listOf (types.enum [ "codex" "claude-code" "aider-chat" ]);
  default = [ ];
};
```

断言：`lazyAgents` 与 `agents` 不得重叠（同一 agent 不能既装包又放 shim）。

### 4.4 部署

`home/default.nix` 按 `distro.agent.lazyAgents` 生成 `bin/<name>` 条目（`agent-shim` 的副本或软链），
随 `install.sh` 部署到 `~/.local/bin`。

### 4.5 缓存与版本

- 缓存目录 `~/.local/state/agent-shims/<name>` 是 out-link（GC root），不会被 `nix-collect-garbage` 回收。
- `flake.lock` 更新后缓存不会自动刷新：需要 `agent-shim --refresh` 或删缓存。
- 首次构建后启动零求值开销。

## 5. 与现有体系集成

| 机制 | 影响 |
|---|---|
| `agent-menu` | 无需改：shim 是 PATH 中的真实命令，会被列出；未下载时选中会触发首次拉取 |
| `agent-usage` | 无需改：按日志路径统计，与是否懒加载无关 |
| `desktop-check` | 无需改：命令存在性检查看到的是 shim |
| `commands.json` | `agent-shim` 自身作为一条 runtime 命令进入清单；shim 副本不带 `@command`，不计入 26 条 |
| `install.sh` | shim 属用户级，随 linkFarm 部署；不涉及系统包 |
| `nix flake check` | 新增的 `packages.<system>.<agent>` 会被 check 覆盖（求值层面） |

## 6. 风险与边界

1. **`claude-code` 的构建期依赖不会消失**：懒加载只把「switch 失败」推迟到「首次运行失败」。落地前必须先在那台机器验证 `nix build nixpkgs#claude-code --no-link` 能成功。
2. **首次运行需网络 + 时间**：求值约 1–2s，下载取决于包体；离线且未缓存时不可用。
3. **缓存刷新是手动的**：与 lock 更新解耦，需要在文档里写清。
4. **交互式 TUI**：`exec` 后 `$0` 是真实二进制，通常无影响；若某 agent 依赖 argv 判断自身路径，需实测。
5. **冲突**：同一 agent 同时出现在 `agents` 与 `lazyAgents` 会 PATH 打架，用断言拦截。
6. **不建议把 `nix profile` 当方案**：命令式安装脱离声明式，与系统包更新节奏不一致。

## 7. 验收清单（落地后）

- [ ] `nix build .#codex` 成功，`nix eval` 版本与 lock 一致
- [ ] 首次 `codex --version` 触发构建并成功；第二次启动无额外求值延迟
- [ ] `agent-menu` 列出并能启动 codex
- [ ] `agent-usage` 能统计 claude 的日志（若同时启用 claude-code）
- [ ] `desktop-check` 与 `nix flake check` 通过
- [ ] 移除 `lazyAgents` 后 shim 消失、`~/.local/bin` 干净
- [ ] `claude-code` 的可构建性有实测结论（通过 / 记录失败原因）

## 8. 决策与后续

| 路线 | 内容 | 建议 |
|---|---|---|
| A 试点 | 只做 `codex`：flake 加一项 + shim + 选项 + 文档 | 先做，风险最低（无构建期网络依赖记录） |
| B 扩到 claude-code | 验证 `nix build nixpkgs#claude-code` 通过后再加 | 视 A 的结果 |
| C 维持现状 | 只用 `distro.agent.agents` 预装 | 若懒加载的复杂度不值得 |

**当前决定：尚未实施，仅存档评估。** 未写入 `docs/ROADMAP.md` 的待办清单；
若决定推进，先在 ROADMAP 登记，再按「先 commit 再 install」的流程落地。

## 附：Omarchy 对照（事实核对）

- Omarchy 预置约 10 个 AI CLI 的**启动器**（claude / codex / opencode / copilot / crush / grok / pi / omp / agy / ori），
  实体由 mise shim 首次运行时下载；stable 4.0.6 已去掉 `agy` / `ori`。
- 别名 `cx` / `cy` / `c` 为**自动批准模式**（不逐条确认命令），与「懒加载」是两件事，不要混在一起评估。
- 本项目若采用 Nix 式懒加载，差异在于版本由 `flake.lock` 固定，而不是跟随上游最新。
