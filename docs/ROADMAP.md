# HyprBuddy OS 路线图

> 更新：2026-11-05 · 分支 `distro/v1-nn`
> 本版按项目定位 **「对外可复现的 agent 桌面底座」** 重写。2026-11-04 及以前的版本以桌面外壳功能清单为主体，其已完成项已并入第 2 节，被替换的优先级见文末变更表。
> 状态口径：**已实现 / 已实现未启用 / 计划 / 暂缓** 分开写，不把计划写成能力；现状永远以代码为准，索引见 `docs/INDEX.md`。

## 0. 当前形态

| 层 | 现状 |
|---|---|
| 底座 | NixOS 26.05 + flake（nixpkgs 走清华 nixexprs 镜像，不依赖 GitHub） |
| 合成器 | niri 26.04（唯一提供方，滚动平铺） |
| 外壳 | Noctalia v5（`pkgs.noctalia` 5.0.1，原生 C++，无 quickshell） |
| 会话 | SDDM → niri；fcitx5；polkit KDE 代理；xwayland-satellite；Noctalia 自有 PAM 锁屏 |
| 主题 | `themes/<slug>/tokens.json` 单一真相 → kitty/fuzzel 精确 16 色 + 外壳壁纸取色；10 套 |
| 键位 | `home/niri/config.kdl` 60 条，速查见 `docs/KEYBINDS.md` |
| 自检 | `desktop-check` 18 项（图形会话全量、非图形降级） |
| agent 层 | **26 条命令 + 5 个技能**，`commands.json`（schema 1）构建期生成；索引见 `docs/SKILLS.md` |
| 实测 | `vmware`（x86_64 软渲染）日用中；`leonard` / `vm-virtio` 仅求值；ISO 切换 v5 后未重建 |

## 1. 优先级原则

1. **主体是三件事**：配置即制品（声明式 / 可复现 / 可回滚）、能力机器可读（`@command` 元数据 + 构建期校验）、agent 权限有边界（只读优先、sudo 只打印）。桌面外壳是载体，不是差异化所在。
2. **不追平其它发行版的 UI 差距项**（多终端 / 编辑器切换、开发栈、游戏套件）。这类差异不产生护城河；若为个人日用体验需要，放个人分支，不进对外叙事。
3. **不落地系统级 AI 功能**（持续截屏索引、Recall 式数字记忆、「AI-native / Copilot+ 对标」措辞）。opt-in 与保守默认值不足以化解社区抵触，措辞与治理姿态本身就是决定因素。
4. **任何新能力的准入条件**：进 `commands.json` 且 `@summary` / `@category` / `@effect` 齐全；可 `nixos-rebuild --rollback` 回退；不引入必须联网的推理依赖；默认关闭的开关要有明确文档。

## 2. 已完成

### 2.1 Agent 底座（对外主体）

- **声明式 / 可回滚**：`flake.nix` + `flake.lock` + git；`hosts/<host>/default.nix` 只写 `distro.*`；`/etc/nixos/configuration.nix` 为防误用桩；用户级 `install.sh` 与系统级「构建验证 → 交人执行 sudo」严格分离；三级回滚（`--rollback` / `git revert` / 重跑 `install.sh`）。
- **能力机器可读**：`lib/gen-commands.py` 构建期生成 `commands.json`（schema 1）；`@command` / `@summary` / `@category` 必填且 `@command` 须等于文件名，`@doc` 指向的指南不存在即构建失败；`generated` 构建指纹、每条命令的 `available`、`paths.artifacts` 统一产物落点。
- **权限边界**：`scripts/agent-apply` 固定四步（`git diff --stat` → `nix eval` → `nixos-rebuild build` → 打印 sudo 命令）；`sys-*` 只读或只打印；错误配置在 build 阶段暴露。
- **技能体系**：5 个技能 / 13 篇指南的路由表与技能×命令矩阵；技能提到的命令必须在 `agent-commands list` 中存在。
- **agent 层命令**：`sys-*` 6 条、`svc-status` / `net-status` / `power-status`、技能 `nixos-system-ops`、过时技能重写（`theme-create` / `scifi-ui`）、`diagnose-crash`。

### 2.2 桌面外壳（载体）

- 桌面抽象 P0–P3：`distro.desktop.sessions`、能力层 `scripts/lib/de.sh`、tokens + exporters、Hyprland / COSMIC 退役（v1-nn）。
- Noctalia v4 → v5：包装、PAM 锁屏、upower / bluetooth 前置、exporter 重写、13+ 处键位与脚本换 `msg`。
- 键位补齐（B 套）：窗口切换器、通知 / 勿扰、夜间模式、壁纸、btop、上下工作区、截图 overlay、`allow-when-locked`。
- 夜间模式 `distro.desktop.nightlight`（6500 / 4000K，日志确认下发）；录屏 `Mod+Alt+R` → `record-toggle`。
- 剪贴板维持 cliphist + fuzzel（不绑 v5 面板）；截图落盘按 XDG 目录解析；产物落点统一进 `commands.json` 的 `paths.artifacts` + `agent-commands paths`。
- `desktop-check` 增补：键位引用命令存在性、壁纸目录、夜间模式日程、Noctalia unknown setting 告警；bar 布局确认**不做声明式基线**。
- 清理 `~/.config/noctalia/` 的 v4 残留。

### 2.3 对外叙事（2026-11-05）

- `README.md` 按新定位重构，agent 层与三条设计原则前移，主题 / 键位降为「桌面外壳」小节，原有部署与选项参考全部保留（提交 `4835b56`）。
- 新增 `README.en.md` 英文 1 页入口。
- 本文件按新定位重写。
- `next-feature/local-memory-timeline.md` 改名重写为 **`next-feature/agent-execution-audit.md`**：数据源从持续截屏改为 agent 执行事件，叙事从「记录用户」翻转为「审计 agent」；探针附录与技术栈复用清单保留，状态仍为**未实施**、不进本文件待办。

## 3. 待做（按优先级）

### P0 对外可发现性（收尾）

| 动作 | 落点 | 验收标准 | 状态 |
|---|---|---|---|
| README 首句改为「可复现、可审计、可回滚的 agent 桌面底座」，agent 层提到首位 | `README.md` | 首屏 200 字内出现声明式、agent 权限边界、机器可读能力清单 | [x] `4835b56` |
| 补英文 1 页 README | `README.en.md` | `NixOS agent desktop / auditable / reproducible` 可检索 | [x] `4835b56` |
| 停用「AI-native / Recall / Copilot+ 对标」措辞 | `README*`、`docs/ROADMAP.md`、`next-feature/` | 全仓库检索仅出现在否定 / 历史 / 非目标语境 | [x] 本轮 |
| 砍掉 P3 的 Omarchy UI 差距项 | `docs/ROADMAP.md` | 待办中不含「多终端 / 编辑器 / 开发栈 / 游戏套件」 | [x] 本版 |
| 时间轴方案改名重写为「agent 执行审计日志」 | `next-feature/agent-execution-audit.md` | 状态横幅为未实施、探针附录保留、不进待办 | [x] 本轮 |
| 仓库 `description` / `homepage` 补齐 | Gitee 仓库设置 | 一句话定位与英文关键词可被检索 | [ ] |
| GitHub 镜像 | 新仓库 | 与 Gitee 同步；**等 P1 跑通再公开**，避免过早放大未验证项 | [ ] |

### P1 点亮已有模块（对应外部最强需求：本地模型 7×24 常驻）

> 前提认知：本地模型当前是「core dump 诊断的隐私兜底」，外部需求把它当「常驻基础设施」。**先改定位，再改代码**；`modules/agent/local-llm.nix` 已有按 GPU 选包变体的抽象，改造面很小。

| 动作 | 落点 | 验收标准 | 状态 |
|---|---|---|---|
| 在 `leonard` 或新 host 打开 `localModels` + `diagnostics` | `hosts/*/default.nix`、`modules/agent/diagnostics.nix` | systemd 单元活跃；coredump 报告落 `~/.local/state/agent/` 且与 `coredumpctl info` 原文可交叉验证 | [ ] |
| 跑通 ollama OpenAI 兼容端点 `/v1/chat/completions` 与多客户端并发 | 新增回归脚本 | 2–3 个并发请求不互相挤占、无 OOM | [ ] |
| 新增 `model-status` / `model-bench` | `scripts/`、`lib/commands.nix` | `agent-commands --json` 条目 +2，`@summary` / `@effect` 齐全；输出 tok/s、内存 / 显存、整机功耗 | [ ] |
| `power-status` 补 idle / 单请求 / 并发三档功耗 | `scripts/power-status` | 输出可机器解析（JSON），形成 7×24 常驻的可量化证据 | [ ] |
| 新增 `distro.agent.localEndpoint`：`bind` / LAN 开关 / token / 并发上限 | `modules/options.nix`、`modules/agent/local-llm.nix` | 默认仍只绑 `127.0.0.1`；LAN 暴露需显式开关 + 断言 | [ ] |

### P2 新增 NPU host（承接 MACO470 选型）

| 动作 | 落点 | 验收标准 | 状态 |
|---|---|---|---|
| 新增 `hosts/maco470/`：`amdxdna` 内核模块、`render` / `video` 组、内核 ≥ 7.0 | `hosts/maco470/`、`modules/hardware/` | `lsmod \| grep amdxdna` 有输出；`/dev/accel/accel0` 属组 `render`；`flm validate` exit 0 | [ ] |
| systemd `LimitMEMLOCK = "infinity"` | service 单元 | 不出现 `mmap(MAP_LOCKED) failed err=-11`；**不能用 `limits.conf`，NixOS 的 systemd 会话不生效** | [ ] |
| XRT / FastFlowLM 先用 `buildFHSEnv` 或容器打通，再固化为 derivation | `pkgs/` | `flm bench llama3.2:1b` 接近公开基线（约 61 tok/s @1K） | [ ] |
| `local-llm.nix` 增 `amd-igpu-vulkan` 分支（Radeon 890M 上 ROCm 未必可用）与 NPU 低功耗路径 | `modules/agent/local-llm.nix` | 新 host 求值通过，不回退到 `ollama-cpu` | [ ] |
| 三条 M.2 物理隔离：系统盘 / 模型盘 / 数据盘 | `lib/commands.nix`、`agent-commands paths` | `paths.artifacts.models` 可查；skill 沙箱重建后模型文件校验和不变 | [ ] |
| 验证目标改为**常驻功耗 + 并发隔离 + 沙箱重建不扰动模型盘** | 回归清单 | 三条 M.2 逐条测速确认 PCIe 4.0 ×4 | [ ] |

> 连锁效应：现有文档中「无 NPU、软件渲染 VM，所以不做语义检索」这条约束，在 NPU 主机到位后失效。语义层可用 NPU 低功耗跑，但仍应按**「省电、不抢 GPU」**叙事，而非「更快」——TOPS 不预测 tok/s，瓶颈是内存带宽。

### P3 护城河（把优势变成可复用规范）

| 动作 | 落点 | 验收标准 | 状态 |
|---|---|---|---|
| 将 `skills/` + `commands.json` 抽成**可移植规范**：任意 NixOS 可导入，不绑定本仓库 flake | `lib/commands.nix`、`skills/` | 干净 NixOS 上用一份 flake 导入即可获得命令与技能；直接回答「更新通道锁定」的批评 | [ ] |
| CI：`nix flake check` + `commands.json` schema 校验 + ISO 构建 | `flake.nix`、CI 配置 | PR 自动跑，`desktop-check` 降级路径不报错 | [ ] |
| append-only **agent 执行审计日志**（方向，未登记为待办） | 评估见 `next-feature/agent-execution-audit.md` | 推进前须先定采集边界与隐私策略；若推进，验收为每次 `agent-apply` 与写操作留痕、可导出 JSONL | [ ] |

> P3 第三项按 `docs/INDEX.md` 第 5 节约定：决定推进时才从 `next-feature/` 转入本表待办。

## 4. 桌面外壳维护（低优先级 / 暂缓）

| 项 | 状态 |
|---|---|
| 重建 live / install ISO（niri 提供方换 v5 后未验证） | [ ] 质量项，P2 的历史遗留 |
| `sys-doctor`：聚合 `sys-health` + `net/power-status` + `desktop-check` | [ ] 低优先级 |
| 自定义调色板：5.0.1 的 `source="custom"` 试 6 种写法均 invalid，外壳暂只能壁纸取色 | [ ] 暂缓，等上游文档 / 新版本 |
| 多 host 实机验证 v5（`leonard` NVIDIA、`vm-virtio` aarch64 仅求值） | [ ] 暂缓，需要那两台机器 |

## 5. 明确不做

- 包管理命令封装（声明式已覆盖）、需要 sudo 的写操作（只打印命令交给人）。
- Hyprland / COSMIC 相关特性（已退役，勿回写）。
- **系统级 AI 功能**：持续截屏索引、Recall 式数字记忆、主动替用户思考的桌面助手；「AI-native OS」「Copilot+ 对标」措辞与以 TOPS 为卖点的算力宣传。
- **追平其它发行版的 UI 差距项**（多终端 / 编辑器切换、开发栈、游戏套件）：差异化不在这层，个人需要可留分支处理。
- agent 自动执行 sudo、直接改 `/etc`、绕过构建验证的即时生效写操作；私有更新通道。

## 6. 状态口径（防止文档写成「已支持」）

| 项 | 真实状态 |
|---|---|
| 本地模型 | `modules/agent/local-llm.nix` 代码就绪（按 GPU 选包变体、`127.0.0.1`），但**三台 host 全部 `localModels = false`**；无 OpenAI 兼容端点、并发控制、功耗观测。属 P1，不是已交付能力 |
| `diagnostics` | `modules/options.nix` 默认 `true`；`leonard` / `vm-virtio` 显式 `false`，`vmware` 因 `agent.enable = false` 整个模块不生效 |
| 实测覆盖 | 只有 `vmware` 日用；`leonard` / `vm-virtio` 仅求值；ISO 未重建 |
| 数字 | 26 命令 / 5 技能 / 60 键位 / 10 主题 / 18 项 `desktop-check`，按 `docs/INDEX.md` 第 4 节约定实测核对 |

## 附：本版相对 2026-11-04 版的变更

| 变更 | 原因 |
|---|---|
| 删除 P3 的「omarchy 差距表中难度项（多终端 / 编辑器切换、开发栈、游戏套件）」 | 追平的是无护城河的一层；见第 1 节原则 2 |
| 新增 P1「点亮本地模型」与 P2「NPU host」并附验收标准 | 原路线图没有「本地模型作为常驻基础设施」的位置，这是当前最大缺口 |
| 原「已完成 / 待做」的桌面功能清单并入第 2.2 与第 4 节 | 保留历史事实，但不再占据主线 |
| 时间轴方案改名重写为 agent 执行审计日志 | 技术栈复用、叙事从「监控用户」翻转为「审计 agent」；状态仍为未实施 |
| 措辞停用「AI-native / Recall / Copilot+ 对标」（除否定与历史语境） | 见第 1 节原则 3 |
