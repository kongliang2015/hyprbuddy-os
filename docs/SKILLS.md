# 技能总览（HyprBuddy OS / SKILLS）

> 更新：2026-11-05 · 5 个技能 · 28 条命令
> 相关：`docs/INDEX.md`（全仓库文档总入口）、`docs/agent-coverage-review.md`（命令的来龙去脉）、
> `docs/AGENT-LAYER.md`（设计稿，已标注历史）

agent 层分两半：**命令**回答"能做什么"（`agent-commands --json` 可查），
**技能**回答"什么时候用、按什么顺序用、输出怎么判读"。本文是技能的路由表。

## 1. 一览

| 技能 | 定位 | 典型触发 | 参考文件 |
|---|---|---|---|
| `nixos-desktop-settings` | 桌面配置入口：改仓库 → 求值构建 → 部署 → 自检 | 改键位/bar/主题/通知、桌面报错 | 6 篇（niri / bar-notify / theming / troubleshooting / agent / workflow） |
| `nixos-system-ops` | 系统运维：先用只读命令拿事实 | 机器卡、服务挂了、磁盘满、断网、更新回滚 | 2 篇（diagnose / lifecycle） |
| `theme-create` | 照品牌配色造一套新主题 | "照 X 官网做套主题" | — |
| `scifi-ui` | 科幻风视觉规范 | "做成 HUD 风格"、改 SDDM/kitty/fuzzel 观感 | — |
| `diagnose-crash` | 崩溃 / core dump 分析 | 进程段错误、系统崩了 | — |

> 注：`~/.codebuddy/skills/` 下还可能看到宿主 / CodeBuddy 内置的 `cosmic-ux` 技能
> （COSMIC 时代残留，COSMIC 已退役）。它**不在本仓库**、不随 `install.sh` 部署，
> 不属于上表 5 个技能，不要按本表路由使用。

## 2. 怎么选

```
要改东西？  → nixos-desktop-settings（外观/键位/配置）
                └ 造新主题 → theme-create
                └ 定视觉规范 → scifi-ui
要看状态/排障？ → nixos-system-ops
进程崩了？     → diagnose-crash
```

| 用户说 | 用哪个 | 第一动作 |
|---|---|---|
| "机器很卡 / 不知道哪不对" | `nixos-system-ops` | `sys-health` |
| "服务挂了 / 某某没起来" | `nixos-system-ops` | `svc-status` |
| "连不上网 / 网很慢" | `nixos-system-ops` | `net-status` |
| "发烫 / 想换性能档" | `nixos-system-ops` | `power-status` |
| "磁盘满了 / store 太大" | `nixos-system-ops` | `sys-gc` |
| "升级 / 回滚" | `nixos-system-ops` | `sys-update --check` / `sys-rollback` |
| "面板没了 / 输入法不能用" | `nixos-desktop-settings` | `desktop-check`，再 `sys-log` |
| "改快捷键 / 换壁纸 / 切主题" | `nixos-desktop-settings` | 直接调对应脚本 |
| "照某网站做套主题" | `theme-create` | 取色 → 壁纸 → tokens.json |
| "要赛博朋克/HUD 风格" | `scifi-ui` | 先定 tokens，再改 SDDM/kitty/fuzzel |
| "程序崩了 / core dump" | `diagnose-crash` | 读 `~/.local/state/agent/coredump-report.md` |

**三个常见误判**：

1. "机器卡" 不要走 `nixos-desktop-settings` 的改仓库流程——那是改配置，不是查状态
2. "做套主题" 是 `theme-create`（产出数据），"改成科幻风" 是 `scifi-ui`（改视觉规范）
3. 桌面报错先 `desktop-check`，不要直接 `sudo nixos-rebuild`——多数时候是用户配置没部署（缺 `install.sh`）

## 3. 技能 × 命令

| 命令 | desktop-settings | system-ops | theme-create | scifi-ui | crash |
|---|:---:|:---:|:---:|:---:|:---:|
| `sys-health` / `svc-status` / `sys-log` | | ● | | | |
| `net-status` / `power-status` | | ● | | | |
| `sys-rollback` / `sys-gc` / `sys-update` | | ● | | | |
| `agent-apply` + `install.sh` | ● | ○（引用） | ● | ○ | ○ |
| `desktop-check` | ● | ○ | | | |
| `theme-next` / `theme-picker` / `de-theme-apply` | ● | | ● | ○ | |
| `wallpaper-next` / `screenshot-*` / `record-toggle` / `notif-dnd` / `night-mode` | ● | | | | |
| `sddm-theme` | ● | | | ● | |
| `agent-commands` | ● | ○ | | | |

（● 主用 · ○ 辅助引用）

## 4. 逐个说明

### 4.1 nixos-desktop-settings

- **入口**：`SKILL.md` 的决策树 → 对应参考文件
- **流程**：改 `home/` → `agent-apply` → `install.sh` → `niri msg action load-config-file`
- **铁律**：改仓库不改 store 软链；不执行 sudo；`/etc/nixos/configuration.nix` 是防误用桩
- **常见误用**：改完不跑 `install.sh`（只 rebuild），导致运行态与代码不一致

### 4.2 nixos-system-ops

- **入口**：症状 → 命令（`SKILL.md` 决策树）
- **流程**：`sys-health` → `svc-status` → `sys-log`，拿到事实再决定动不动手
- **铁律**：只读优先；sudo 命令只打印不执行
- **参考**：`diagnose.md`（7 类症状判读）、`lifecycle.md`（更新/回滚/GC 与提交顺序）

### 4.3 theme-create

- **产出**：`wallpapers/NN-<slug>.png` + `themes/<slug>/tokens.json`
- **流程**：取官网色值 → ImageGen 壁纸（2560×1440 RGB）→ 写 tokens（`order` 递增）→ `install.sh` → `de-theme-apply <slug>` 验证
- **注意**：ImageGen 花 credits，动手前告知用户；v5 面板配色来自壁纸取色，tokens 只直接影响 kitty/fuzzel

### 4.4 scifi-ui

- **适用面**：SDDM QML、kitty、fuzzel（Noctalia 受限）
- **硬规则**：颜色只能来自 tokens，禁止硬编码 hex
- **已退役不要引用**：waybar / swaync / mako / eww / hyprshell / swayosd / hyprlock / COSMIC

### 4.5 diagnose-crash

- **流程**：读 coredump 报告（若启用自动分析）→ 符号化栈 → 排除 OOM/磁盘 → 输出结论
- **注意**：报告是模型生成的，需与 `coredumpctl info` 原文交叉验证

## 5. 维护约定

| 事项 | 要求 |
|---|---|
| 目录结构 | `skills/<name>/SKILL.md`（必需）+ 可选参考资料 |
| frontmatter | 必须有 `name` / `description`，description 写清"什么时候用" |
| 部署 | 先 `git commit`，再 `./install.sh --host <host> --yes`（flake 只认 git 跟踪文件） |
| 死引用检查 | 组件退役后，`grep -rn "已删组件名" skills/` 必须为 0（或在"已退役"清单里） |
| 命令一致性 | 技能里提到的命令必须存在于 `agent-commands list` |
| 新增技能 | 同步更新本文第 1、2、3 节与 `nixos-desktop-settings` 的分工表 |

## 6. 命令全景（28 条）

下表是**仓库能力**，不代表本机都可用：`commands.json` 的 `available` 字段反映
本机构建状态。例如 `distro.agent.enable = false` 的机器上，
`agent-apply` / `agent-menu` / `agent-theme-sync` 未部署、`available=false`。
以 `agent-commands --json` 为准。

| 分类 | 命令 |
|---|---|
| check（11） | `agent-commands` `desktop-check` `sys-health` `svc-status` `sys-log` `sys-rollback` `sys-gc` `net-status` `power-status` `model-status` `model-bench` |
| workflow（2） | `agent-apply` `sys-update` |
| agent（1） | `agent-theme-sync` |
| runtime（14） | `agent-menu` `clipboard-menu` `de-theme-apply` `night-mode` `notif-dnd` `record-toggle` `screenshot-annotate` `screenshot-output` `sddm-theme` `show-sysinfo` `sysinfo-os` `theme-next` `theme-picker` `wallpaper-next` |

详细参数：`agent-commands show <name>`；结构：`agent-commands --json`；
分类筛选：`agent-commands --category check`；路径落点：`agent-commands paths`
（XDG 目录在运行时展开，构建期清单里是 `<XDG_*_DIR>` 占位符）。
