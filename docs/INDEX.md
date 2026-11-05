# HyprBuddy OS 文档索引（唯一入口）

> 更新：2026-11-05 · 分支 `distro/v1-nn` · 桌面 **niri 26.04 + Noctalia v5**
> 项目定位：**对外可复现的 agent 桌面底座**（声明式 / 可审计 / 可回滚）；桌面外壳是载体，不是主体。
> 本索引是找文档的第一站。全仓库文档分三类：**现行规范 / 历史归档 / 设计稿**，
> 另有单独一类 `next-feature/`（待评估特性，见第 5 节）。
> 现状永远以代码为准：`modules/options.nix`、`hosts/`、`home/`、`scripts/`。
> 改配置从技能 `nixos-desktop-settings` 进入，不要直接改 `~/.config` 下的 store 软链。

## 1. 我想……（速查）

| 需求 | 去哪 |
|---|---|
| 项目定位 / 对外说明 | `README.md`（中文完整版）、`README.en.md`（英文 1 页入口） |
| 快速上手 / 复现 / 部署命令 | `README.md` 第 3、9 节 |
| 现在做到哪、下一步做什么 | `docs/ROADMAP.md`（唯一进度表，含验收标准） |
| 该用哪个技能 | `docs/SKILLS.md`（技能路由 + 技能×命令矩阵） |
| 有哪些命令、参数、副作用 | `agent-commands --json`（机器可读）；机制见 `docs/COMMANDS-JSON.md` |
| 快捷键 | `docs/KEYBINDS.md` **文末「niri 当前键位」表**（中间表格是历史对照） |
| 改键位 / 主题 / 壁纸 / 面板 | `skills/nixos-desktop-settings/SKILL.md` → 对应专题指南 |
| 桌面报错 / 面板消失 | `skills/nixos-desktop-settings/troubleshooting.md` → `desktop-check` → `sys-log` |
| 系统卡 / 服务挂 / 磁盘 / 网络 / 电源 / 更新回滚 | `skills/nixos-system-ops/SKILL.md` |
| 照品牌配色造一套主题 | `skills/theme-create/SKILL.md` |
| 科幻 HUD 风视觉改造 | `skills/scifi-ui/SKILL.md` |
| 进程崩溃 / core dump | `skills/diagnose-crash/SKILL.md` |
| 有哪些 `distro.*` 选项 | `modules/options.nix`（唯一权威）+ `README.md` 选项表 |
| agent 层为什么有这些命令 | `docs/agent-coverage-review.md` |
| Hyprland / COSMIC 时代发生了什么 | 见第 3 节历史文档（勿按现状引用） |

## 2. 现行规范

### 路线与全局
- `README.md` — 项目定位、三条设计原则、复现路径、agent 层、部署与选项参考
- `README.en.md` — 英文 1 页对外入口（定位 / 原则 / 复现 / 非目标 / 状态）
- `docs/ROADMAP.md` — 按 agent 底座定位重写的 P0–P3 进度、验收标准、暂缓项、明确不做（权威清单见 `README.md` §8）
- `docs/SKILLS.md` — 5 个技能 / 26 条命令的分工与路由
- `docs/KEYBINDS.md` — 文末 niri 键位表（60 条，源 `home/niri/config.kdl`）
- `docs/agent-coverage-review.md` — agent 层覆盖度评审与 P0–P3 补齐记录
- `docs/COMMANDS-JSON.md` — **生成机制现行**（`lib/commands.nix` + `scripts/agent-commands`），仅文中示例是历史数据

### 桌面配置技能 `skills/nixos-desktop-settings/`（7 篇）
- `SKILL.md` — 入口：铁律、决策树、示例表
- `workflow.md` — 改仓库 → 求值构建 → `install.sh` → switch / 回滚；「先 commit 再 install」
- `niri.md` — 键位、window-rule、截图落盘、输入法
- `bar-notify.md` — Noctalia v5 `msg` 命令表；bar 属运行态
- `theming.md` — tokens → theme.toml（壁纸取色）+ kitty/fuzzel；v5 已知坑
- `agent.md` — `distro.agent.*` 开关、用量口径、诊断
- `troubleshooting.md` — **现行排障**：bar 消失、unknown setting、夜间模式、custom palette、store 产物截断

### 系统运维技能 `skills/nixos-system-ops/`（3 篇）
- `SKILL.md` — 入口：先用只读命令拿事实，不执行 sudo 写操作
- `diagnose.md` — 五类症状判读
- `lifecycle.md` — 更新 / 回滚 / GC 流程

### 其它技能
- `skills/theme-create/SKILL.md`　`skills/scifi-ui/SKILL.md`　`skills/diagnose-crash/SKILL.md`

### 配置权威源（不是文档，但比文档准）
`modules/options.nix`（选项）、`modules/desktop/niri.nix`（桌面栈）、`home/niri/config.kdl`（键位）、
`exporters/niri/theme.sh`（主题链路）、`themes/<slug>/tokens.json`（10 套主题）、`scripts/`（27 个文件 / 26 条命令）。

## 3. 历史 / 设计稿（勿按现状引用）

这些文件**头部都有状态标注**（多数为 2026-11-04 统一横幅），保留作决策依据，不作为现状说明。

- **B 档统一横幅（10 份）**：`AGENT-LAYER.md`、`ARCHITECTURE-REVIEW.md`、`COMMANDS-JSON.md`（机制除外）、
  `IMPLEMENTATION-PLAN.md`、`ng-shell.md`、`ng-shell-benchmark.md`、`SKILL-REDESIGN.md`（已实施并演化）、
  `theme-tokens.md`、`TROUBLESHOOTING-hyprland-era.md`、`ux-capabilities.md`
- **原有状态标注**：`cosmic-*.md` ×7（COSMIC 退役历史调研）、`desktop-abstraction.md`（COSMIC 接入与 Hyprland 退役）、
  `niri-noctalia-plan.md`（v4 接入方案）、`desktop-retire-hyprland.md`（退役记录）、
  `eww-start-menu.md`（放弃记录）、`KEYBINDS.md` 中间的 Hyprland/COSMIC 对照表
- **同名冲突已处理**：原 `docs/TROUBLESHOOTING.md` 已改名 `docs/TROUBLESHOOTING-hyprland-era.md`；
  现行排障是 `skills/nixos-desktop-settings/troubleshooting.md`

## 4. 维护约定

1. **新增文档**：先在本索引里归到某一类，再写；不要让「无标注的新文档」直接描述现状。
2. **现状变更**：先更新 `ROADMAP.md` 与对应技能文档；旧文档转为历史时补统一横幅，不要删。
3. **横幅模板**：复制任一历史文件头部（`> **历史 / 设计稿（YYYY-MM-DD 标注）**：…`），
   写清当时对象、当前实现、现状以哪份为准。
4. **不要两份同名主题文档**：排障/指南类只允许一份现行版本，历史版加后缀或标横幅。
5. **数字要实测**：命令数用 `agent-commands --json`、主题数用 `ls themes`、
   键位数看 `home/niri/config.kdl`、技能数用 `ls skills`；统一写进 `ROADMAP.md`。
6. **文档不进 `install.sh`**：只有 `skills/` 会部署到 `~/.codebuddy/skills/`；
   `docs/` 与根 `README.md` 只在仓库里供人/agent 阅读。
7. **对外措辞**：不使用「AI-native OS」「Recall」「Copilot+ 对标」作为卖点；
   这些词只出现在否定、历史或非目标语境中（`README.md` 第 8 节、`ROADMAP.md` 第 5 节）。

## 5. 待评估特性（`next-feature/`）

第 4 类文档：**尚未落地**的新特性调研与方案评估，不算现行规范、不计入技能数、
不随 `install.sh` 部署，也不写进 `ROADMAP.md` 的待办清单（决定推进时再登记）。
每份文件头部必须标注「状态：未实施 + 评估日期 + 基准 commit」。

| 文件 | 主题 |
|---|---|
| `next-feature/agent-execution-audit.md` | **Agent 执行审计日志**（可导出 / 可回放）：记录 `agent-apply` 与写操作事件；由 2026-11-04 的 Recall 式屏幕时间轴方案于 2026-11-05 改名重写，**不采集屏幕内容**，状态未实施 |
| `next-feature/file-ops-skill.md` | 文件操作能力：落点统一 + 备份查恢 + 介质只读视图（2026-11-04 评估，P0 已拆出实施于 `499435e`） |

> 2026-11-05 变更：原 `next-feature/local-memory-timeline.md` 已改名重写为 `agent-execution-audit.md`。
> 原方案的一次性探针数据、FTS5 中文按字切分、systemd user timer、`paths.artifacts`、`desktop-check` 集成点
> 保留在附录并继续复用；`grim` / `tesseract` / 缩略图 / 语义 embedding 等屏幕采集组件不再使用。
