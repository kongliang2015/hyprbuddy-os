# 文件操作能力（文件落点与数据安全）评估

> **状态：P0 已实施（2026-11-04，提交 `499435e`）；P1–P3 未实施（2026-11-04 评估）**
> 评估基准 `hyprbuddy-os` @ `746b723`；2026-11-05 事实核对基准 `499435e`
> `next-feature/` 存放**尚未整体落地**的新特性评估：不属于现行规范、不计入 `docs/SKILLS.md`
> 的技能数、不随 `install.sh` 部署。现状说明以 `docs/ROADMAP.md` 与 `docs/INDEX.md` 为准。
> 注：P0 一致性修复已拆出实施（见 `docs/ROADMAP.md` P2「产物落点统一」、提交 `499435e`）；
> 第 2 节现状盘点为评估时点（`746b723`）的快照，带「已由 P0 改变」括注的条目此后已变化；
> P1–P3 仍未实施。本次仅修正事实错误与更新基准，**方案结论不变**。
>
> 背景：agent 层现有 26 条命令 / 5 个技能，主线是「配置闭环 + 系统排障 + 崩溃诊断」
> （`docs/agent-coverage-review.md`）。文件与数据这一层既没有技能也没有专用命令，
> 且该文档「明确不做」只排除了包管理与 sudo 写操作，并未把文件操作列为设计排除项 ——
> 属于**未评估的空白，而非有意决策**。

## 1. 需求与结论

目标：让 agent 在本机处理文件时有「这台机器什么样算对、改哪里、什么不能碰」的依据，
覆盖日常高频的文件相关请求，同时不破坏现有「只读优先 / 无 sudo / 幂等」的约束。

结论：**不做通用文件操作 skill，做一个窄的「文件落点 + 数据安全」能力层。**
通用复制 / 移动 / 删除 / 搜索是宿主 agent 的能力，与发行版无关；本仓库 skill 的价值在于
把「预期状态」编码成可执行断言（评审 §4.1），这类操作没有可编码的预期状态，
包一层反而扩大误删面。真正缺的是四处**发行版特有**的语义：产物落点没有统一事实源、
备份只写不读、可移动介质 / 回收站已装软件但无视图、以及把这些规则写成可路由的指南。

## 2. 现状盘点

下表为评估时点（`746b723`）快照；标「已由 P0 改变」的条目在 `499435e` 后已不成立。

| 能力 | 现状 | 依据 |
|---|---|---|
| 配置文件的修改与部署 | 已覆盖 | `nixos-desktop-settings`：改仓库 → `agent-apply` → `install.sh` → `desktop-check` |
| 桌面产物写入 | 散落在各脚本 | `theme-next` 写 `~/.local/state/`；`install.sh` 复制壁纸到 `~/Pictures/wallpapers`、把被替换的真实文件备份到 `~/.config.bak-<时间戳>/` |
| 截图 / 录屏落点 | **不一致 → 已由 P0 改变** | 评估时：`record-toggle` 读 `XDG_VIDEOS_DIR`、`de_screenshot_output` 硬编码 `~/Pictures`；现已统一走 `de_xdg_dir` 按 XDG 解析 |
| 能力自描述 | 部分 → 已由 P0 改变 | 评估时 `paths` 段只有 `repo` / `user_config` / `skills`；现已有 `paths.artifacts` 六项与 `agent-commands paths` |
| 备份 | 只写不读 | `install.sh` 创建 `~/.config.bak-<时间戳>/`，无 list / restore |
| 可移动介质 / 回收站 | 软件已装、无封装 | `services.udisks2.enable` 与 `gvfs`（`modules/desktop/hyprbuddy.nix`）；Thunar 由 `Super+E` 打开（`docs/KEYBINDS.md`） |
| 存储状态 | 部分 | `sys-health`（磁盘占用）、`sys-gc`（store 与 GC）已有；设备 / 挂载点 / 回收站无视图 |

补充：评估时曾记录「本机（host `leonard`）的 `user-dirs.dirs` 为英文 `Pictures` / `Videos`」，
该判断不适用于当前机器（`vmware`）：2026-11-05 实测 `XDG_PICTURES_DIR="$HOME/图片"`、
`XDG_VIDEOS_DIR="$HOME/视频"`，`agent-commands paths` 也输出这两个中文目录。
结论仍是「落点问题不是纯文档问题」——P0 已用 `de_xdg_dir` 按运行时解析解决；
agent 应查 `agent-commands paths`，不要按中英文目录名做假设。

## 3. 三种形态的取舍

| 形态 | 内容 | 判断 |
|---|---|---|
| A 完整通用 skill | 封装 cp / mv / rm / 重命名 / 搜索 / 批量，做成第 6 个技能 | 不推荐：与宿主能力重复；删除不可逆，与只读优先冲突；无预期状态可编码 |
| B 维持现状 | 靠宿主 agent + Thunar（`Super+E`） | 不够：三处真实缺口（落点漂移、备份不可恢复、介质无只读视图）不会自行消失 |
| C 窄能力层（推荐） | 只补发行版特有语义：落点事实源 + 备份查恢 + 介质只读视图 + 一份薄指南 | 推荐：贴合 `@command` / `commands.json` / skill 三层现有体系，改动面可控 |

## 4. 推荐方案（分层，命令名均为「拟新增」）

**P0 统一落点 —— 已于 2026-11-04 拆出实施，不再是本评估的待办**

> 见 `docs/ROADMAP.md` P2「产物落点统一」（提交 `499435e`）。原方案（扩 `paths.artifacts`、
> XDG 解析对齐、修文档写死路径、`agent-commands paths`）已作为一致性修复落地；
> 2026-11-05 核对：`paths.artifacts` 六项、`de_xdg_dir`、两条脚本落点均已生效。
> 保留标题以便对照 P1–P3 的编号，不要再按本节推进。

**P1 备份可查可恢复**

- `backup-list`（拟）：列 `~/.config.bak-*` 的时间戳、文件数、与当前软链的对应关系；只读。
- `backup-restore <stamp> [--dry-run]`（拟）：显式恢复，默认 dry-run 只打印将执行的 `mv`。
- 两条按 `@command` 头部进 `commands.json`，`@effect` 标明写 `~/.config`；**不提供删除备份**。

**P2 存储介质只读视图**

- `storage-status`（拟）：块设备 / 挂载点 / 占用 / 可移动介质 / 回收站体积，复用 udisks2 + gvfs。
- 挂载、卸载、清空回收站只打印命令，不执行。
- 与 `docs/ROADMAP.md` P3 的 `sys-doctor` 不冲突：本命令是数据源，`sys-doctor` 是聚合器。

**P3 一份薄指南（技能或参考文档）**

- 倾向并入 `skills/nixos-system-ops/` 的一篇参考文档；若独立成 `file-ops`，按
  `docs/SKILLS.md` 第 5 节同步第 1/2/3 节矩阵与 `docs/INDEX.md`。
- 内容不是教 `cp` / `mv`，而是：路径从 `agent-commands paths` 查、哪些是 store 软链绝不能改、
  哪些是运行态可改（`~/.local/state/noctalia/settings.toml`）、备份怎么查恢复、
  介质动作只打印命令、以及「改配置转 `nixos-desktop-settings`」的路由。

## 5. 与现有体系的集成点

| 现有机制 | 怎么接 |
|---|---|
| `scripts/` + `@command` 元数据 | 新命令头部写 `@command` / `@summary` / `@category` / `@effect`，自动进 `agent-commands --json`（当前 26 条） |
| `lib/commands.nix` 生成器 | `paths` 段扩 `artifacts`；构建期校验必填字段，避免手写 JSON 漂移 |
| `home/default.nix` linkFarm | 指南 / 技能随 `install.sh` 部署；配置类文本走 `share/hyprbuddy-os/` |
| `docs/SKILLS.md` / `docs/INDEX.md` | 新增技能同步第 1/2/3 节；新增文档先归到索引第 5 节 |
| `desktop-check` | 可增补：产物目录可写、XDG 目录可解析、备份目录权限 |
| `systemd.user.timers` | 本方案不引入常驻采集，无需新单元 |

## 6. 安全与隐私约束

1. 只读优先：P1 / P2 的默认形态只读；`backup-restore` 默认 `--dry-run`。
2. 不封装删除：不提供 `rm`、批量删除、删除备份目录；交给人 / 宿主判断。
3. agent 不执行 sudo：挂载、卸载、清空回收站、系统级改动只打印命令。
4. 落点只从 XDG 变量解析，避免中英文目录假设造成写错位置。
5. 不改 `/etc/nixos/configuration.nix` 防误用桩，不改 `~/.config` 下的 store 软链。
6. 备份目录沿用现有 `~/.config.bak-*` 约定，不新增跨用户可见的数据目录。

## 7. 明确不做

| 不做 | 理由 |
|---|---|
| 通用文件管理器 / 文件操作命令 | Thunar 已由 `Super+E` 绑定；宿主 agent 已具备，重复且无预期状态可编码 |
| `rm` / 批量删除 / 回收站清空封装 | 不可逆，与「只读优先」冲突 |
| 需要 sudo 的写操作 | 沿用评审 §7，只打印命令交给人 |
| 把文件内容索引 / 语义检索做进来 | 与 `next-feature/agent-execution-audit.md`（agent 执行审计）是两件事，不要合并；本评估也不做任何屏幕 / 内容采集 |
| 把本评估直接写进 `ROADMAP.md` 待办 | 决定推进时再登记（`docs/INDEX.md` 第 5 节约定） |

## 8. 决策与后续

| 路线 | 内容 | 改动面 | 建议 |
|---|---|---|---|
| A 先修一致性 | 只做 P0 | — | **已拆出实施**（提交 `499435e`，见 ROADMAP P2「产物落点统一」），不再属于本评估 |
| B 完整落地 | 按第 4 节 P1–P3 加 3 条命令 + 一份指南，同步技能矩阵与索引 | 新增脚本 + 技能 / 参考文档 + 文档同步，在已装机器上试跑 | A 之后按序推进 |

**当前决定：尚未实施，仅存档评估。** 未写入 `docs/ROADMAP.md` 的待办清单，
不计入 `docs/SKILLS.md` 的技能数、不随 `install.sh` 部署。
若决定推进，先在 ROADMAP 的 P2 / P3 里登记，再按「先 commit 再 install」的流程落地；
每条命令完成后用 `agent-commands --json` 校验条目数与 `@effect`。
