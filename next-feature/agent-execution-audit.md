# Agent 执行审计日志（可导出 / 可回放）评估

> **状态：未实施 · 未进 `docs/ROADMAP.md` 待办（2026-11-05 重写）**
> 前身：`next-feature/local-memory-timeline.md`（2026-11-04「Linux / niri 版 Recall」评估，本轮改名重写）。
> 评估基准：`hyprbuddy-os` @ `4835b56`；2026-11-05 一次性探针实测见附录 A（探针时 HEAD `09ec667`）。
> `next-feature/` 存放**尚未落地**的新特性评估：不属于现行规范、不计入 `docs/SKILLS.md` 的技能数、
> 不随 `install.sh` 部署。现状说明以 `docs/ROADMAP.md` 与 `docs/INDEX.md` 为准。

## 0. 为什么重构，而不是删掉

原方案的工程质量没有问题：2026-11-05 的一次性探针已实测截图、OCR、中文检索、锁屏状态四项关键假设，核心链路成立、开销可接受，并据此修正了四处假设（系统包、中文检索策略、产物与保留期、窗口字段验证）。**这些工作保留在附录 A，不浪费。**

问题在定位与措辞，不在工程：

1. **「Recall / AI-native」在海外 FOSS 社区是负资产。** KDE 的 Kadai 提案明确写了「你选择用多少 AI、用哪一个」并设计了审批门控，仍在 Akademy 遭冷遇、GitLab 删帖、两人被封、250 人签署 No-AI 请愿，两年目标里 AI 项归零。可见 **opt-in 与保守默认值不足以化解抵触，词本身就会触发防御反应**。
2. **持续截屏天然扩大攻击面。** 原方案第 7 节的默认关闭、排除列表、锁屏暂停、3 天保留、目录 700 都是对冲手段，但改变不了「系统在记录我」的观感。
3. **外部真正要求的是可问责性。** 对同类「agent-native 桌面」最具体的批评，正是「AI 生成脚本权限失控、不可审计」。而本项目已经具备 `@effect`、`requires_sudo`、构建期校验、sudo 只打印这些素材 —— 缺的只是把它们串成一条可导出的证据链。

**结论：技术栈近乎全额复用，把数据源与叙事同时翻转。**

| 维度 | 原方案（2026-11-04） | 本方案 |
|---|---|---|
| 定位 | Linux 版 Recall / 数字记忆 | **agent 执行审计日志**（可导出、可回放） |
| 数据源 | 持续截屏 → OCR | `agent-apply` / 写操作事件 + `@effect` + 变更前后 diff |
| 回答的问题 | 「我上周看过什么」 | 「**agent 对这台机器做了什么**」 |
| 用户感受 | 系统在记录我 | 系统在记录 agent |
| 社区对应 | 负资产 | 主动要求的 audit trail / 可问责性 |
| 状态 | 未实施 | 仍未实施、仍未进 ROADMAP 待办 |

## 1. 目标与非目标

**目标**

- 记录 agent 发起的每一次写操作与变更流，**包含失败与回滚**，而不只记录成功。
- 可导出 JSONL、可按时间 / host / 命令 / 风险等级检索、可回放「这次改动发生了什么」。
- 与 `commands.json` 的 `@effect` / `requires_sudo` / `available` 关联，让日志条目带有语义，而不是一堆裸 shell 历史。
- 为 skill 沙箱重建、回滚、多人交接提供证据链。

**非目标**

- 不采集屏幕内容、不做 OCR、不生成缩略图、不建用户行为时间轴。
- 不索引用户文档正文，不做语义画像 / embedding。
- 不默认开启、不联网上报、不改变现有权限边界（agent 仍不执行 sudo）。
- 不拦截 / 不阻断 agent 动作 —— 审计只记录，**不成为策略执行点**，避免审计组件变成新的权限中心。

## 2. 事件模型

| 事件源 | 触发条件 | 采集内容 |
|---|---|---|
| `agent-apply` | 每次调用 | `git diff --stat`、`nix eval` / `nixos-rebuild build` 结果、**打印出的 sudo 命令**、交人执行状态（只能标注 `handed_off`，无法确认是否真的执行） |
| 写操作命令 | `@effect` 非空或 `requires_sudo = true` | 命令名、参数（脱敏）、退出码、`effects[]` 原文 |
| 仓库变更 | commit / revert / rollback | `rev_before` / `rev_after`、改动文件列表、diff 摘要或 patch 路径 |
| 用户级部署 | `install.sh` / 技能重链 | 部署 host、软链变化、备份目录 `~/.config.bak-*` |
| 窗口上下文（可选） | 仅 `app_id` / 标题 | `niri msg` IPC；**不截屏**；锁屏期间不采集（`noctalia msg status` 的 `locked` 字段已实测存在） |
| 诊断报告（P1 启用后） | coredump → 本地模型 | 报告路径与模型名；沿用「模型生成，须与 `coredumpctl info` 交叉验证」的标注 |

一条 JSONL 的示意（`effects` 取自 `scripts/agent-apply` 的真实 `@effect`）：

```json
{"ts":"2026-11-05T14:18:03+08:00","host":"vmware","actor":"agent","command":"agent-apply","effects":["运行 nix eval 与 nixos-rebuild build（不改系统）"],"requires_sudo":false,"rev_before":"2d5cdb9","rev_after":"4835b56","diff_hash":"sha256:…","exit_code":0,"sudo_handed_off":true,"artifacts":["paths.artifacts.audit"]}
```

> 字段与落点为设计草案，未实现；真正落地时须与 `commands.json` 的 schema 一起评审。

## 3. 可复用清单（原方案技术栈）

| 原组件 / 结论 | 本方案怎么复用 | 变化 |
|---|---|---|
| SQLite FTS5 + **中文按字切分 + phrase query**（附录 A 实测「餐厅」可命中，无需 jieba） | 索引事件文本、命令摘要、diff 摘要 | ✅ 全额复用 |
| `systemd.user.timers` | 批量落盘、保留期清理 | ✅ 复用；不再是 60 s 定时采集 |
| `commands.json` / `@command` 元数据 | 事件语义来源：`effects`、`requires_sudo`、`available`、`category` | ✅ 从「集成点」升为核心输入 |
| `paths.artifacts` + `agent-commands paths` | 新增 `artifacts.audit`，脚本不硬编码目录 | ✅ 复用（原为 `artifacts.memory`） |
| `desktop-check` 增补 | 检查审计目录权限、落盘服务健康、保留期超限 | ✅ 复用 |
| `skills/` + `docs/SKILLS.md` | 新增 `audit-export` 命令与指南，同步第 1/2/3 节 | ✅ 复用 |
| `noctalia msg status` / `niri msg` IPC | 仅用于可选的窗口上下文与锁屏判断 | ✅ 降级使用 |
| ❌ `grim` / `tesseract` + eng、chi_sim / `imagemagick`、PIL / OCR 文本 / 缩略图 / 排除列表 / 语义 embedding / 22.6 GB 磁盘预算 | **不再使用** | 依赖随之消失：不再需要新增系统包（sqlite3 用 Python 标准库，FTS5 已实测可用） |

## 4. 保守默认值

1. **默认关闭**，需显式声明式开关（草案名 `distro.agent.audit.enable`），不因 P1/P2 的启用而自动打开。
2. **append-only**，目录权限 `0700`，落点走 `paths.artifacts.audit`。
3. **保留期默认 30 天**、上限 90 天，超限自动清理。与原方案 3 天不同：事件日志是 KB 级文本，没有 1.15 MB/张 × 30 s 采样的磁盘压力，无需为体积牺牲可追溯性。
4. 不采集屏幕内容与文档正文；命令参数做脱敏（token、密钥、含敏感信息的路径）。
5. 导出需显式命令 `audit-export`，输出到用户指定位置；不自动外发。
6. **审计者与被审计者分离**：agent 不应能删除或改写日志，否则「证据」不成立。
7. 回滚事件同样留痕（`nixos-rebuild --rollback` / `git revert`），保证回放链完整。
8. 沿用仓库既有约定：由模型生成的报告须标注「需交叉验证」。

## 5. 权限边界与采集边界（已决策）

审计**只记录、不拦截**，不改变 `agent-apply` 的四步流程，也不改变「sudo 只打印交人执行」。它是对既有权限边界的**观测**，不是新的权力。

**已决策（2026-11-06）：最小方案** —— 只覆盖 `agent-apply`、仓库内 `@effect` 非空的命令、`install.sh`；不覆盖宿主 agent 的全部写操作（全量方案留待跑通后再评估）。

| 范围 | 改动面 | 风险 |
|---|---|---|
| **最小方案（建议先做）**：只覆盖 `agent-apply`、仓库内 `@effect` 非空的命令、`install.sh` | 小，全部事件都已有仓库内锚点 | 覆盖不全，但对「验证审计链路是否成立」足够 |
| 全量方案：覆盖宿主 agent 的全部写操作 | 需要宿主侧 hook、日志格式适配、隐私策略 | 采集边界与脱敏规则复杂，容易反过来变成监控用户 |

按最小方案落地时仍须补齐隐私策略（审计文件权限 700、保留期、脱敏规则），但采集范围不再扩张到宿主 hook。

## 6. 落地前置与验收

**前置（按序）**

1. 先定第 5 节的采集边界与隐私策略（建议最小方案）。
2. 等 `docs/ROADMAP.md` 的 **P1** 完成（本地模型与端点稳定）后再引入，避免同时改两个变量。
3. 决定推进时，先在 ROADMAP 的 P3 登记，再按「先 commit 再 install」流程落地。

**验收标准**

| 项 | 标准 |
|---|---|
| 留痕完整 | 每次 `agent-apply` 与 `@effect` 非空的写操作都有记录，**含失败路径**与回滚事件 |
| 可导出 | `audit-export` 输出 JSONL，字段可被 `jq` 解析 |
| 隔离 | skill 沙箱重建后审计文件校验和不变（与 P2「模型盘物理隔离」的验证目标一致） |
| 自检 | `desktop-check` 能报出目录权限异常与保留期超限 |
| 无回摆 | 全仓库检索不出现 `grim` / `tesseract` / 截图相关依赖，不重新引入屏幕采集 |

## 7. 当前决定

**未实施，仅存档评估。** 不写入 `docs/ROADMAP.md` 的待办清单；本文由 `next-feature/local-memory-timeline.md` 改名重写而来，附录 A 的探针数据保留作技术栈可行性依据，但**不再作为「截图方案可落地」的证据**。

---

## 附录 A：2026-11-05 一次性可行性探针（实测数据，保留）

一次性、无副作用验证：临时目录跑完即删，未启动常驻采集，未输出任何截图 / OCR 内容；探针时仓库 HEAD 为 `09ec667`。

> 这些数字验证的是**原截图方案**的组件可用性。本方案只复用其中四项结论：SQLite FTS5 中文检索、systemd user timer 写法、`noctalia msg status` 的 `locked` 字段、以及「保守默认值 + 目录 700」的权限策略。

| 验证项 | 方法 | 实测结果 | 判定 |
|---|---|---|---|
| 截图 | `grim` 全屏 PNG | 502 ms / 1.15 MB | ✅ 可行（本方案不用） |
| OCR 组件 | store 内 `tesseract 5.5.2` + `eng` / `chi_sim` traineddata | 二进制可运行、语言包齐全，但**未进 PATH** | ✅ 需加系统包（本方案不用） |
| OCR 耗时 | eng / chi_sim 各跑一次 | eng 278 ms / 23 字符；chi_sim 549 ms / 0 字符（当时屏幕无可识别中文） | ✅ 中文效果待真实内容复测（本方案不用） |
| 单次开销 | 截图 + OCR 串行 | 约 0.8–1.05 s；30 s 采样 ≈ 3% 单核 | ✅ 可接受（本方案不用） |
| 锁屏状态 | `noctalia msg status` | 返回 `"locked": false` 字段 | ✅ **复用**：锁屏判断依据 |
| SQLite | `python3` 内置 `sqlite3` 3.51.2 | FTS5 可用，`trigram` tokenizer 可建表 | ✅ **复用** |
| 中文检索（原假设） | FTS5 trigram 查「餐厅」 | hits=0；「可持续餐厅」hits=1；unicode61 查「餐厅」也 hits=0 | ⚠️ 2 字词失效 |
| 中文检索（修正） | 按字切分 `餐 厅` + phrase query | 「餐厅」命中、「可持续餐厅」命中、英文数字正常 | ✅ **复用**：无需 jieba |
| 窗口元数据 | `niri msg focused-window` / `windows` | rc=0 但输出空（当时会话未开窗口） | ⚠️ 字段格式未验证 |
| 缩略图依赖 | `magick` / `convert` / `ffmpeg` / PIL | 全部缺失 | ❌ 需新增系统包（本方案不用） |
| 磁盘估算 | 1.15 MB/张、30 s 采样 | 全屏 7 天 ≈ 22.6 GB；1/10 ≈ 2.3 GB；1/20 ≈ 1.1 GB | ⚠️ 原「7 天保留」不可行（本方案不受此约束） |

原结论：核心链路可行，方案结论（自建优先、分两层、保守默认值）不变，但系统包、中文检索策略、产物与保留期、窗口字段验证四处假设已按上表修正。**本轮补充结论**：这些组件中，与「agent 执行审计」相关的四项可直接沿用，与屏幕采集相关的全部不再需要。

## 附录 B：与 2026-11-04 原方案的差异

| 章节 | 原方案 | 本文 |
|---|---|---|
| 需求 | 持续记录屏幕内容 → 索引 → 找回上下文 | 记录 agent 写操作 → 导出 → 回放变更 |
| 现成项目对比（OpenRecall / screenpipe / ActivityWatch） | 有 | 删除：与本方案无关 |
| 推荐实现 | `grim` → `tesseract` → SQLite → `memory-recall` | 事件采集 → append-only JSONL/SQLite → `audit-export` |
| 语义检索第二层 | OCR → embedding → sqlite-vec | 删除：不做语义画像 |
| 隐私默认值 | 排除列表、锁屏暂停、3 天保留、只存 OCR + 缩略图 | 默认关闭、0700、参数脱敏、30 天保留、审计者与 agent 分离 |
| 系统依赖 | 需新增 `tesseract` + 语言包 + 缩略图工具，`nixos-rebuild switch` | 无需新增系统包 |
| Windows Recall 参考事实 | 附录 | 删除：仅作为重构背景在第 0 节一句带过，不再作为设计依据 |
