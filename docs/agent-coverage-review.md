# Agent 层覆盖度评审与补齐方案

> 评审日期：2026-10-29 · 対象：`distro/v1-nn` 的 agent 层（模块 + 脚本 + skill）
> 关联：`docs/AGENT-LAYER.md`（2026-10-21 设计稿，仍含 Hyprland 时代内容）、`docs/COMMANDS-JSON.md`
> **2026-11-05 更新**：本地模型默认改用 `pkgs.ollama-cpu`（GPU 加速为显式 opt-in），命令 26→28（新增 `model-status` / `model-bench`）；第 2 节的规模与命令数为此前评审时点快照，现状以 `agent-commands --json` 与 `docs/ROADMAP.md` 为准。

## 1. 结论

当前 agent 层是一个**「桌面配置机器人」，而不是「系统管理员」**：

- 强项：改配置 → 构建 → 部署 → 自检 的闭环；桌面外观即时动作（主题/壁纸/录屏/截图/通知）覆盖完整
- 弱项：**系统运维几乎空白**——日志、服务、存储、网络、电源、用户权限都没有专属入口，
  模型只能凭通用 Linux 知识现场拼命令，没有本发行版的"预期状态"安全网

一句话：**会把界面改对，不会判断机器出了什么毛病。**

## 2. 现状盘点

### 2.1 模块（`modules/agent/`）

| 文件 | 作用 | 规模 |
|---|---|---|
| `core.nix` | 按 `distro.agent.agents` 安装 CLI（opencode / codebuddy） | 8 行 |
| `diagnostics.nix` | coredump → 本地 ollama 分析 → 写 `~/.local/state/agent/` | 82 行 |
| `local-llm.nix` | 按 GPU 厂商选 ollama 变体（cuda/rocm/vulkan/cpu） | 19 行 |
| `../lib/agent-usage.nix` | token 用量统计，输出 `{text, tooltip}`，供 bar 的 CustomButton 消费 | 100 行 |

### 2.2 脚本（`scripts/`，19 个）

| 分类 | 数量 | 命令 |
|---|---|---|
| `workflow` | 1 | `agent-apply` |
| `check` | 2 | `agent-commands`、`desktop-check` |
| `agent` | 1 | `agent-theme-sync` |
| `runtime` | 14 | `theme-next`、`theme-picker`、`de-theme-apply`、`wallpaper-next`、`notif-dnd`、`night-mode`、`record-toggle`、`screenshot-output`、`screenshot-annotate`、`clipboard-menu`、`sddm-theme`、`show-sysinfo`、`sysinfo-os`、`agent-menu` |

**写操作 14 / 读操作 2** —— 读写比例 7:1，排障侧几乎没有抓手。

### 2.3 Skill（4 个）

| skill | 定位 | 状态 |
|---|---|---|
| `nixos-desktop-settings` | 桌面配置主入口，含 7 篇参考文档 | 已随 v1-nn 更新 |
| `diagnose-crash` | 崩溃/core dump 分析 | 可用 |
| `theme-create` | 按品牌配色生成主题 | ⚠️ 仍描述 waybar/mako/hyprlock 流水线 |
| `scifi-ui` | 科幻风 UI 组件规范 | ⚠️ 目标组件（waybar/eww/swaync/hyprlock/swayosd）已全删 |

## 3. 覆盖矩阵

图例：✅ 完整 · 🟡 部分/裸工具 · ❌ 空白

| 能力域 | 状态 | 依据 |
|---|---|---|
| 变更构建 | 🟡 | `agent-apply` 负责求值+构建+打印 sudo；无 switch/rollback/GC/flake update 封装 |
| 配置部署 | ✅ | `install.sh` + skill 全流程，幂等、有备份（`~/.config.bak-*`） |
| 自检 | ✅ | `desktop-check` 14 项 + `agent-commands --json` 自描述 |
| 崩溃诊断 | ✅ | coredump 自动分析 + 专用 skill |
| 日志/服务排障 | ❌ | 无 `journalctl`/`systemctl status`/`dmesg` 封装 |
| 包管理 | ❌ | 纯声明式（设计选择，不算缺陷） |
| 存储/磁盘 | ❌ | 无磁盘占用、日志膨胀、U 盘挂载入口（udisks2 已装但无封装） |
| 网络 | ❌ | Wi-Fi / VPN / DNS / 连通性全无 |
| 电源/温度/电池 | ❌ | `power-profiles-daemon` 已装，无任何命令入口 |
| 显示器/输入设备 | 🟡 | `wlr-randr` 已装但无封装；键盘布局、触摸板无入口 |
| 用户/权限 | ❌ | 密码、sudoers、polkit 调试均无 |
| 桌面即时操作 | ✅ | 主题、壁纸、通知、录屏、截图、剪贴板、夜间、SDDM、系统信息 |

## 4. 设计得失

### 4.1 做得好的

1. **单一入口**：`agent-apply` 是唯一改动通道，模型不必记多条构建命令
2. **自描述**：`agent-commands --json` 暴露 `@effect`、是否需 sudo、是否交互
3. **无 sudo 原则**：命令只在用户空间运行，需特权的操作"打印命令交给人"
4. **预期状态编码化**：`desktop-check` 把"什么样算好"写成可执行断言
5. **skill 与 script 分工**：skill 给流程与判断，script 给原子动作

### 4.2 短板

1. **只写不读**：19 条命令里 14 条是写操作，读操作只有 2 条 check
2. **缺聚合视图**：没有"系统现在怎么样"的单条命令
3. **sudo 动作无统一出口**：除 `agent-apply` 的一行提示外，重启服务/GC/改时间都没有对应封装
4. **2 个 skill 已过时**：`scifi-ui`、`theme-create` 仍是 Hyprland 时代内容
5. **输出非结构化**：除 `agent-commands --json` 外均为人类可读文本，模型解析靠正则

## 5. 补齐方案

设计约束（沿用现有哲学）：**只读优先、无 sudo、幂等、人类可读 + 可选 `--json`**。

### P0 只读诊断组（预计 4 小时，收益最大）

#### `sys-health`  — 系统健康总览

```
@category: check      @effect: 只读
输出：磁盘(/, /home) · 内存+swap · load · CPU 温度 · 失败 systemd 单元
      · 最近 1h error 计数 · 关键进程(niri/noctalia/fcitx5/polkit-agent)
参数：--json
退出码：严重问题(磁盘>90%/有 failed 单元) 返回 1，其余 0
```

#### `sys-log` — 日志查询封装

```
@category: check      @effect: 只读
sys-log [--user|--system] [--since <t>] [--grep <pat>] [--unit <u>] [-n N]
默认：--user -b -n 50 --no-pager
输出：原样 journal 行（不加工，保证可追溯）
```

#### `svc-status` — 关键服务状态

```
@category: check      @effect: 只读
svc-status [unit...]
默认集合：niri(user) noctalia(user) fcitx5(user) polkit-agent(user)
          sddm(system) udisks2(system) power-profiles-daemon(system)
输出：NAME  STATE  SINCE  LAST_LOG_LINE
```

**验收**：三条命令均 <2s 完成、不调用 sudo、出现在 `agent-commands --json` 里。

### P1 生命周期（预计 3 小时）

| 命令 | 作用 | 说明 |
|---|---|---|
| `sys-rollback` | 列系统世代（编号/时间/差异摘要）+ 打印回滚命令 | 不执行，只输出 |
| `sys-gc` | 统计 `/nix/store` 体积、世代数、估算可回收量 + 打印 GC 命令 | 不执行 |
| `sys-update` | `nix flake update`（`--check` 时仅 `--dry-run`）+ `agent-apply` + 打印 switch | 默认不更新，需显式 `--apply` |

### P2 网络与电源（预计 2 小时）

| 命令 | 内容 |
|---|---|
| `net-status` | 默认路由、IP、DNS 解析测试（3 个域名）、网关 ping、Wi-Fi SSID（有则显示） |
| `power-status` | `powerprofilesctl get`、CPU 温度、电池（有则显示）、当前亮度 |

### P3 skill 清理（预计 1 小时）

| skill | 动作 |
|---|---|
| `scifi-ui` | 收窄到现存组件（SDDM QML、kitty/fuzzel），开头标注 waybar/eww/swaync/hyprlock 已退役 |
| `theme-create` | 改为 v5 管线（壁纸取色 / custom palette + kitty/fuzzel 派生），删 waybar/mako/hyprlock 段落 |

## 6. 实施顺序

```
P0 sys-health  →  svc-status  →  sys-log       （先聚合，后细分）
P1 sys-rollback → sys-gc → sys-update
P2 net-status   → power-status
P3 skill 清理（可与 P2 并行）
```

每完成一条：`agent-commands --json` 校验 → 实测输出 → 提交。

## 7. 明确不做

| 不做 | 理由 |
|---|---|
| 包管理命令（install/remove） | 声明式系统，应由改仓库完成 |
| 需要 sudo 的写操作封装 | 保持"agent 不执行 sudo"，只打印命令 |
| 用本地模型做常规诊断 | 延迟高、不确定性大；ollama 仅用于 coredump 这类重任务 |

## 8. 附录：现有命令全表

| 命令 | 分类 | 摘要 |
|---|---|---|
| `agent-apply` | workflow | 改动唯一入口：求值 → 构建 → 打印 sudo |
| `agent-commands` | check | 机器可读命令清单（`--json`/`list`/`show`） |
| `desktop-check` | check | 桌面自检（niri + Noctalia v5） |
| `agent-menu` | runtime | agent 选择器（`Mod+Shift+Ctrl+A`） |
| `agent-theme-sync` | agent | 按 dark/light 同步 claude/opencode 主题 |
| `theme-next` / `theme-picker` / `de-theme-apply` | runtime | 主题循环 / 预览选择 / 按 slug 应用 |
| `wallpaper-next` | runtime | 循环切换壁纸 |
| `notif-dnd` / `night-mode` | runtime | 勿扰开关 / 夜间模式 |
| `record-toggle` | runtime | 录屏开始/停止（wf-recorder） |
| `screenshot-output` / `screenshot-annotate` | runtime | 整屏截图 / 区域截图标注 |
| `clipboard-menu` | runtime | 剪贴板历史选择器 |
| `sddm-theme` | runtime | 查看/切换 SDDM 主题（下次注销生效） |
| `show-sysinfo` / `sysinfo-os` | runtime | 系统信息弹窗 / OS 行 |

## 9. 实施进度

| 项 | 状态 | 说明 |
|---|---|---|
| P0 `sys-health` | ✅ 2026-11-03 | 7 组信息 + `--json`，150ms，已入 commands.json |
| P0 `svc-status` | OK 2026-11-03 | 7 个单元/进程 + --json, 205ms, inactive 视为按需启动 |
| P0 `sys-log` | OK 2026-11-03 | 薄封装 journalctl，支持 --system/--since/--unit/--grep/--json；自动去 ANSI |
| P1 `sys-rollback` | OK 2026-11-03 | 列 21 代 + 打印 switch/boot 命令，--json；只读 |
| P1 `sys-gc` | OK 2026-11-03 | df 分区 + dead 路径 3041 个 / 可回收上限 22.2G；--fast/--json |
| P1 `sys-update` | OK 2026-11-03 | 只读列输入 / --check 临时副本试更新(30s) / --apply 更新+构建+打印 switch |
| P2 `net-status` | OK 2026-11-04 | 接口/路由/Wi-Fi/网关 RTT/DNS，~5s |
| P2 `power-status` | OK 2026-11-04 | 档位/温度/电池/亮度/抑制，<0.1s |
| P3 skill 清理 | OK 2026-11-04 | scifi-ui 234→109 行（只剩 SDDM/kitty/fuzzel）、theme-create 125→104 行（改 tokens.json 管线） |

## 10. 实施小结（P0 + P1 已完成，2026-11-03）

### 10.1 新增命令

| 命令 | 分类 | 用途 | 退出码 1 的条件 | 耗时 |
|---|---|---|---|---|
| `sys-health` | check | 磁盘/内存/负载/温度/failed 单元/1h 错误数/关键进程 | 磁盘≥90%、有 failed 单元、关键进程缺失 | 0.15s |
| `svc-status` | check | 7 个关键单元/进程的状态 + 最后一条日志 | failed / not-found / 进程缺失 | 0.2s |
| `sys-log` | check | journalctl 薄封装（user/system/since/unit/grep/level/json） | 仅权限问题 | <0.1s |
| `sys-rollback` | check | 世代清单 + 打印 switch/boot 回滚命令 | 恒 0 | <0.1s |
| `sys-gc` | check | 分区占用 / dead 路径 / 可回收上限 + 清理命令 | 恒 0 | 9s |
| `sys-update` | workflow | 列输入 / `--check` 试更新 / `--apply` 更新+构建 | `--check` 发现更新 | 30s |

命令总数从 19 → **24**（check 2 → 7，workflow 1 → 2），读写比从 14:2 改善到 14:9。

### 10.2 实施中确认的事实（都已落到代码注释）

1. **`systemctl show -p A -p B --value` 的输出顺序与请求顺序无关** —— 按行号解析会错位，必须逐属性查询
2. **`nix path-info --stdin --json` 返回 `{path: {...}}` 字典且含 `null` 值** —— 不能当列表遍历
3. **`readlink /nix/var/nix/profiles/system` 是相对软链**（`system-49-link`），不是 store 路径
4. **`du -sh /nix/store` 要 35s**，`df` 只要毫秒；`nix-store --gc --print-dead` 固定 8s
5. **`nix flake update` 没有 `--dry-run`** —— 只能复制 flake.nix+lock 到临时目录真跑一次
6. **journal 消息体可能自带 ANSI**（polkit agent 等），`journalctl` 不清洗，管道里会变成 `:5:245m`
7. **进程探测要同时看 comm 与命令行** —— `noctalia` 的 comm 是 `.noctalia-wrapp`、args 是 `noctalia`

### 10.3 配套技能

新增 `skills/nixos-system-ops/`：

| 文件 | 内容 |
|---|---|
| `SKILL.md` | 铁律、症状→命令决策树、命令速查（含退出码与耗时）、三步排障法 |
| `diagnose.md` | 7 类症状的判读与处置（P3 初版 5 类，P2 补充网络/电源后为 7 类），含本机三次真实事故的判据 |
| `lifecycle.md` | 更新/回滚/GC 流程，以及「先 commit 再 install」的顺序铁律 |

`nixos-desktop-settings` 的决策树加了交叉引用：系统运维类请求转 `nixos-system-ops`。

### 10.4 覆盖现状

原计划中「日志/服务/存储/网络/电源」五块空白已在 P0–P2 补齐；
`scifi-ui` / `theme-create` 两份过时技能在 P3 重写。剩余空白只有：
包管理（设计上走声明式，不做命令）、需要 sudo 的写操作（只打印命令）。
### 10.5 P2 补充（2026-11-04）

| 命令 | 分类 | 用途 | 退出码 1 的条件 | 耗时 |
|---|---|---|---|---|
| `net-status` | check | 接口/路由/Wi-Fi SSID/网关 RTT/DNS 解析 | 网关不通或 DNS 全部失败 | ~5s |
| `power-status` | check | 性能档位/CPU 温度/电池/背光/空闲抑制 | 电池 <10% | <0.1s |

命令总数 24 → **26**；网络与电源不再是空白。

`net-status` 的一个坑值得记：**必须 `LC_ALL=C` 调 nmcli 与 ping**。中文 locale 下
nmcli 的 ACTIVE 字段是「是/否」、ping 输出是「时间=3.24 毫秒」，按英文正则解析会全部失败。

### 10.6 P3 技能重写（2026-11-04）

| 技能 | 行数 | 主要问题 | 处理 |
|---|---|---|---|
| `theme-create` | 125 → 104 | 围绕已删除的 36 字段 `THEMES` 数组 | 改围绕 `themes/<slug>/tokens.json`，补 order 规则与 v5 壁纸取色限制 |
| `scifi-ui` | 234 → 109 | 改造对象 waybar/swaync/eww/hyprshell/swayosd/hyprlock 全部删除，另有整节 COSMIC | 收窄到 SDDM QML / kitty / fuzzel（Noctalia 受限说明），保留设计资产 |

两份技能开头都显式列出「已退役，不要再引用」的组件名，防止被重新写回。

### 10.7 技能分工（当前 5 个）

| 技能 | 入口场景 |
|---|---|
| `nixos-desktop-settings` | 改桌面外观/键位/主题、构建部署流程 |
| `nixos-system-ops` | 系统排障（卡顿/服务/磁盘/网络/电源）、更新回滚 |
| `theme-create` | 照品牌配色做一套新主题 |
| `scifi-ui` | 科幻风视觉改造（SDDM/kitty/fuzzel） |
| `diagnose-crash` | 进程崩溃 / core dump |
