# 懒加载 agent（codex / claude-code / opencode）评估

> **状态：安装器交互 + agent-shim + flake 单包已实施（2026-11-06）** · 评估基准 `hyprbuddy-os` @ `d15df1a`
> **2026-11-06 需求澄清**：lazy 列表定为 `codex` / `claude-code` / `opencode`（原 `kilo` 已替换为 `opencode`）；
> 预装不再默认 `codebuddy`，改由安装脚本交互选择；`live ISO` 维持 `codebuddy` + `opencode` 不变。
> `next-feature/` 存放**尚未落地**的新特性评估：不属于现行规范、不计入 `docs/SKILLS.md`
> 的技能数、不随 `install.sh` 部署。现状说明以 `docs/ROADMAP.md` 与 `docs/INDEX.md` 为准。
>
> 背景：Omarchy 预置约 10 个 AI 编程 CLI 的启动器，实体程序由 mise shim 在首次运行时下载
>（「懒加载」）。本项目的 agent 是声明式预装：`distro.agent.agents` 里列出的包在构建期
> 进入 `environment.systemPackages`。本文评估「预装 + 懒加载」的分层做法。

## 1. 需求与结论

目标：
- **预装**：安装脚本让用户多选（候选 `codebuddy` / `opencode` / `codex` / `claude-code` / `aider-chat`），
  写进目标 host 的 `distro.agent.agents`，构建时进系统包；
- **懒加载**：默认 `lazyAgents = [ "codex" "claude-code" "opencode" ]`，未预装的按首次运行拉取；
- 两者自动做**差集**，同一 agent 不允许同时出现在两个列表。

结论：**可行**。懒加载走 Nix 式（首次 `nix build` + out-link 缓存，版本由 `flake.lock` 固定），
不采用 Omarchy 的 mise/npm shim；安装器交互只改 `installer/install.sh` + `render-host.sh` +
`hosts/_template`，不动系统模块的求值路径。

## 2. 现状盘点

| 项 | 现状 | 依据 |
|---|---|---|
| 支持的 agent | 枚举 5 个：`claude-code` / `codebuddy` / `opencode` / `codex` / `aider-chat` | `modules/options.nix:203` |
| 实际启用 | `leonard`、`vm-virtio` 均为 `[ "opencode" "codebuddy" ]`；`vmware` 关闭 agent 层 | `hosts/*/default.nix` |
| 安装方式 | `environment.systemPackages = map (name: pkgs.${name}) cfg.agents` | `modules/agent/core.nix` |
| 安装器默认 | `AGENT_ENABLE=true`、`AGENT_LIST=opencode`（**不是 codebuddy**） | `installer/install.sh:15-16` |
| live ISO | 显式 `agents = [ "codebuddy" "opencode" ]`，不走安装器渲染 | `installer/live-iso-config.nix:36-39` |
| nixpkgs 可用性（2026-11-06 求值） | `codex-0.146.0`、`claude-code-2.1.223`、`aider-chat-0.86.1` | `nix eval ... .name` |
| 菜单发现 | `agent-menu` 只列 PATH 中 `command -v` 命中的 agent | `scripts/agent-menu` |
| 用量统计 | `agent-usage` 按 `~/.claude/projects` 等日志路径统计，与安装方式无关 | `lib/agent-usage.nix` |
| 自检 | `desktop-check` 检查键位引用的命令是否存在 | `scripts/desktop-check` |

## 3. 形态取舍

| 形态 | 内容 | 判断 |
|---|---|---|
| A 维持现状 | 需要时把包名加进 `distro.agent.agents`，重建并 switch | 不够：安装器默认值不可选；`claude-code` 构建期需访问 `downloads.claude.ai`（`hosts/leonard/default.nix` 注释），会把网络问题带进系统构建 |
| B Nix 式懒加载 | flake 暴露单包；`agent-shim` 首次运行 `nix build`，之后走 out-link 缓存 | 推荐：版本仍由 `flake.lock` 固定，失败被限制在首次运行 |
| C Omarchy 式 shim | mise / npm 从上游拉最新版 | 不推荐：版本漂移、与 lock 脱节、破坏可复现 |
| D 安装器交互选择（与 B 组合） | 安装时多选预装项；未选项进懒加载；两者差集 | 推荐：兼顾「装完即可用」与「不背全部包」 |

## 4. 推荐方案

### 4.1 flake 暴露单包（已实施）

```nix
packages = lib.mapAttrs
  (system: names:
    lib.genAttrs names homePkg
    // { iso = mkIso system; liveIso = mkLiveIso system; }
    // lib.optionalAttrs (system == "x86_64-linux") {
         codex       = nixpkgs.legacyPackages.${system}.codex;
         claude-code = nixpkgs.legacyPackages.${system}.claude-code;
         opencode    = nixpkgs.legacyPackages.${system}.opencode;
       })
  hostsBySystem;
```

### 4.2 `agent-shim`（已实施）

```bash
#!/usr/bin/env bash
# @command: agent-shim
# @summary: 懒加载 agent 启动器（首次运行按 flake.lock 构建，之后走缓存）
# @category: runtime
# @usage: agent-shim（由 codex / claude / opencode 等 shim 链接调用，按 $0 判断名字）
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

**实施记录（2026-11-06）**

| 文件 | 改动 |
|---|---|
| `home/agent-shim.sh` | shim 本体；按 `$0` 判断命令名，`claude → claude-code` 包名映射 |
| `home/default.nix` | 按 `distro.agent.lazyAgents` 部署 `bin/<命令名>`（`claude-code` 部署为 `claude`） |
| `flake.nix` | `packages.<x86_64-linux>.{codex,claude-code,opencode}`；用 `import nixpkgs.outPath` 单独实例化并白名单放行 unfree 的 `claude-code` |
| `hosts/vmware/default.nix` | 验证用：`lazyAgents = [ "codex" "claude-code" "opencode" ]`（与 `agent.enable = false` 并存，shim 部署不依赖 agent 层开关） |

验证：`bash -n` 通过；`nix build .#codex` 成功（142.8 MiB，经 SJTU nix 镜像缓存）；
首次 `codex --version` → `codex-cli 0.146.0`，out-link 落在 `~/.local/state/agent-shims/codex`；
`~/.local/bin/{codex,claude,opencode}` 均指向 shim；`agent-commands --json` 仍为 28 条；
`desktop-check` 通过。`claude` / `opencode` 的首次构建未触发（避免大下载），仅验证了 shim 逻辑。

### 4.3 选项与断言

```nix
lazyAgents = mkOption {
  type = types.listOf (types.enum [ "codex" "claude-code" "opencode" "aider-chat" ]);
  default = [ "codex" "claude-code" "opencode" ];
};
```

断言：`lazyAgents` 与 `agents` 不得有交集（同一 agent 不能既装包又放 shim）。

### 4.4 部署

`home/default.nix` 按 `distro.agent.lazyAgents` 生成 `bin/<name>` 条目（`agent-shim` 的副本或软链），
随 `install.sh` 部署到 `~/.local/bin`。

### 4.5 缓存与版本

- 缓存目录 `~/.local/state/agent-shims/<name>` 是 out-link（GC root），不会被 `nix-collect-garbage` 回收。
- `flake.lock` 更新后缓存不会自动刷新：需要 `agent-shim --refresh` 或删缓存。
- 首次构建后启动零求值开销。

### 4.6 安装器交互选择（已实施）

改动三处，均在安装路径上，不影响已装机器的求值：

| 文件 | 改动 |
|---|---|
| `installer/install.sh` | 新增 `--agents "codebuddy opencode"`（非交互）；`--yes` 未指定且 stdin 是 TTY 时，在「安装计划」后提示多选；默认空（全部懒加载） |
| `installer/render-host.sh` | 新增 `LAZY_AGENT_LIST` → `nix_list` → 替换 `@LAZY_AGENT_LIST@` |
| `hosts/_template/default.nix` | agent 段加 `lazyAgents = [ @LAZY_AGENT_LIST@ ];` |

核心逻辑示意：

```bash
AGENT_CANDIDATES="codebuddy opencode codex claude-code aider-chat"
LAZY_DEFAULT="codex claude-code opencode"
AGENT_LIST=""

prompt_agents() {
  printf "\n可选 agent：%s\n" "$AGENT_CANDIDATES"
  printf "要预装哪些？（空格分隔，回车=全部懒加载）: "
  read -r AGENT_LIST
}

# --yes 或非 TTY 时跳过提示；非交互请显式传 --agents
if [ "$ASSUME_YES" -ne 1 ] && [ -t 0 ]; then prompt_agents; fi

# 差集：懒加载默认里去掉已预装的
LAZY_AGENT_LIST=""
for a in $LAZY_DEFAULT; do
  case " $AGENT_LIST " in *" $a "*) ;; *) LAZY_AGENT_LIST="$LAZY_AGENT_LIST $a" ;; esac
done
LAZY_AGENT_LIST="${LAZY_AGENT_LIST# }"
```

> 纯 `read`，不依赖 whiptail/dialog（minimal ISO 不一定有）；`--yes` 与非 TTY 走 `--agents` 或默认空。
> 安装计划里打印两行：`预装 agent` / `懒加载 agent`，确认前可见。

**实施记录（2026-11-06）**

| 文件 | 改动 |
|---|---|
| `modules/options.nix` | 新增 `distro.agent.lazyAgents`（默认空，避免与现有 host 的 `agents` 冲突） |
| `modules/assertions.nix` | 交集断言（`lazyAgents` 与 `agents` 不得重叠） |
| `hosts/_template/default.nix` | `lazyAgents = [ @LAZY_AGENT_LIST@ ];` |
| `installer/render-host.sh` | `LAZY_AGENT_LIST` → `nix_list` → 替换 `@LAZY_AGENT_LIST@` |
| `installer/install.sh` | `--agents` 参数、TTY 交互多选、候选校验、差集、计划打印、`--no-agent` 清空 |

验证：`bash -n` 通过；渲染输出 `agents=[codebuddy]` + `lazyAgents=[codex claude-code opencode]`；
差集四组场景（含已选 `opencode`）结果正确；交集断言表达式 false/true 符合预期；
现有 `vmware` 求值通过（默认空不触发断言）。
端到端 `--dry-run` 已用 `unshare -r`（非特权 user namespace 模拟 root）跑通四组：
`--agents codebuddy --mirror tuna`、`--agents "opencode codex" --mirror official`、
无参数（全懒加载 + cn）、`--no-agent`（两列表清空）；四组均渲染正确且 `nix eval` 求值通过。

## 5. 与现有体系集成

| 机制 | 影响 |
|---|---|
| `agent-menu` | 无需改：shim 是 PATH 中的真实命令，会被列出；未下载时选中会触发首次拉取 |
| `agent-usage` | 无需改：按日志路径统计，与是否懒加载无关 |
| `desktop-check` | 无需改：命令存在性检查看到的是 shim |
| `commands.json` | `agent-shim` 自身作为一条 runtime 命令进入清单；shim 副本不带 `@command`，不计入命令数 |
| `install.sh` | shim 属用户级，随 linkFarm 部署；不涉及系统包 |
| `installer/` | 交互选择只影响新装机器生成的 host 配置；live ISO 与已装机不受影响 |
| `nix flake check` | 新增的 `packages.<system>.<agent>` 会被 check 覆盖（求值层面） |

## 6. 风险与边界

1. **`claude-code` 的构建期依赖不会消失**：懒加载只把「switch 失败」推迟到「首次运行失败」。落地前必须先验证 `nix build nixpkgs#claude-code --no-link` 能成功。
2. **首次运行需网络 + 时间**：求值约 1–2s，下载取决于包体；离线且未缓存时不可用。
3. **缓存刷新是手动的**：与 lock 更新解耦，需要在文档里写清。
4. **交互式 TUI**：`exec` 后 `$0` 是真实二进制，通常无影响；若某 agent 依赖 argv 判断自身路径，需实测。
5. **冲突**：同一 agent 同时出现在 `agents` 与 `lazyAgents` 会 PATH 打架，用断言 + 安装器差集双重拦截。
6. **非 TTY / 自动化安装**：`--yes` 或管道输入时必须用 `--agents`，否则默认全懒加载（不会卡在提示）。
7. **差集逻辑只有一处实现**：安装器算 `LAZY_AGENT_LIST`，运行期断言只做校验，避免两处规则漂移。
8. **live ISO 不走安装器渲染**：保持显式 `[ "codebuddy" "opencode" ]`，不要与 lazy 列表混用。

## 7. 验收清单（落地后）

- [x] `nix build .#codex` 成功，`nix eval` 版本与 lock 一致（codex-0.146.0）
- [x] 首次 `codex --version` 触发构建并成功（`codex-cli 0.146.0`）
- [x] `agent-menu` 能在 PATH 中列出 codex / claude / opencode
- [ ] `agent-usage` 能统计 claude 的日志（未触发 claude 首次构建，未测）
- [x] `desktop-check` 通过；`nix flake check` 待完整跑一次（此前只跑过 `--no-build`）
- [ ] 移除 `lazyAgents` 后 shim 消失、`~/.local/bin` 干净（未测）
- [x] 安装器 `--dry-run --agents "codebuddy" --mirror tuna`：`agents=[codebuddy]`、`lazyAgents=[codex claude-code opencode]`、`mirror="tuna"`
- [x] 安装器 `--dry-run --agents "opencode codex" --mirror official`：差集正确（`lazyAgents=[claude-code]`）、`mirror="official"`
- [x] `--yes` 且未传 `--agents` / `--mirror`：全部懒加载 + `cn`，不阻塞
- [x] `--no-agent`：`enable=false`、`agents` 与 `lazyAgents` 均为空
- [x] live ISO 配置未变（`codebuddy` + `opencode`）
- [ ] `claude-code` 的可构建性有实测结论（通过 / 记录失败原因）

## 8. 决策与后续

| 路线 | 内容 | 建议 |
|---|---|---|
| A 试点 | 安装器交互选择 + `codex` shim + `lazyAgents` 默认值 | **已完成（2026-11-06）**：安装器、shim、flake 单包、vmware 验证 |
| B 扩到 claude-code / opencode | 验证 `claude-code` 可构建后补齐；opencode 无构建风险 | 视 A 的结果 |
| C 维持现状 | 只用 `distro.agent.agents` 预装 | 若不接受安装器交互的复杂度 |

**当前决定：尚未实施，仅存档评估。** 未写入 `docs/ROADMAP.md` 的待办清单；
若决定推进，先在 ROADMAP 登记，再按「先 commit 再 install」的流程落地。

## 附：Omarchy 对照（事实核对）

- Omarchy 预置约 10 个 AI CLI 的**启动器**（claude / codex / opencode / copilot / crush / grok / pi / omp / agy / ori），
  实体由 mise shim 首次运行时下载；stable 4.0.6 已去掉 `agy` / `ori`。
- 别名 `cx` / `cy` / `c` 为**自动批准模式**（不逐条确认命令），与「懒加载」是两件事，不要混在一起评估。
- 本项目若采用 Nix 式懒加载，差异在于版本由 `flake.lock` 固定，而不是跟随上游最新。
