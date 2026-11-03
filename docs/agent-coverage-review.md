# Agent 层覆盖度评审与补齐方案

> 评审日期：2026-10-29 · 対象：`distro/v1-nn` 的 agent 层（模块 + 脚本 + skill）
> 关联：`docs/AGENT-LAYER.md`（2026-10-21 设计稿，仍含 Hyprland 时代内容）、`docs/COMMANDS-JSON.md`

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
| P1 `sys-rollback` | 待做 | |
| P1 `sys-gc` | 待做 | |
| P1 `sys-update` | 待做 | |
| P2 `net-status` | 待做 | |
| P2 `power-status` | 待做 | |
| P3 skill 清理 | 待做 | `scifi-ui`、`theme-create` |
