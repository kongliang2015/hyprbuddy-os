# Agent 驱动的 COSMIC UX 定制方案

> 前置调研见 `docs/cosmic-customization.md`。本文补充实测细节，并给出一套
> 「自然语言 → 受控变更 → 验证 → 可回滚」的 agent 工作流设计。

## 一、调研补充（本机 COSMIC 1.2.0 实测）

### 1.1 非显然的 RON 结构（最容易写错的地方）

```ron
# plugins_center：单列表
Some([ "com.system76.CosmicAppletTime", ])

# plugins_wings：**元组**，左翼 + 右翼两个列表
Some(([
    "com.system76.CosmicPanelWorkspacesButton",
    "com.system76.CosmicPanelAppButton",
], [
    "com.system76.CosmicAppletAudio",
    "com.system76.CosmicAppletNetwork",
]))

# autohide：None 或 元组
None
Some((
    wait_time: 500,
    transition_time: 200,
    handle_size: 2,
    unhide_...
))
```

→ **不能用字符串拼接生成**，必须用结构化模板（我们的 cosmic exporter 已按此做）。

### 1.2 当前面板基线

```
Panel: anchor=Top  autohide=None  border_radius=0   opacity=1.0  size=XS  layer=Top
       expand_to_edges=true  exclusive_zone=true
Dock : anchor=Bottom  autohide=Some(...)  border_radius=8  opacity=1.0  size=L
entries = [ "Panel", "Dock" ]
```

### 1.3 可用 applet（13 个，决定布局上限）

```
A11y  Audio  Battery  Bluetooth  InputSources  Minimize  Network
Notifications  Power  StatusArea  Tiling  Time  Workspaces
```

另有面板专用按钮：`CosmicPanelWorkspacesButton`、`CosmicPanelAppButton`、`CosmicPanelLauncherButton`。

### 1.4 可用的官方 CLI（agent 可直接调）

| 命令 | 用途 |
|---|---|
| `cosmic-settings <page>` | 打开指定设置页（30+ 子命令：panel/dock/keyboard/wallpaper/…） |
| `cosmic-randr` | 显示器查询/设置 |
| `cosmic-screenshot` | 截图（验证用） |
| `cosmic-osd` | OSD（音量/亮度由 settings-daemon DBus 触发） |

**没有** `cosmic-config` CLI —— 配置只能写文件。

## 二、设计目标

| 目标 | 说明 |
|---|---|
| 自然语言驱动 | 用户说"顶栏自动隐藏、圆角 12"，agent 完成余下全部 |
| 受控写入 | agent **不得**直接编辑 `~/.config/cosmic/**`，只能经 `uxctl` |
| 可预览 | 变更先出 diff（人可读表格），确认后才落盘 |
| 可回滚 | 每次 apply 前快照，一条命令恢复 |
| 可验证 | 写后读回 + 可选截图比对，失败自动回滚 |

**非目标**：主题配色（走 P2 的 exporter）、Applet 开发、Settings 页开发。

## 三、架构

```
┌─────────────────────────────────────────────────┐
│ L4 agent 层   skill: cosmic-ux                   │  自然语言 → intent
│               codebuddy/opencode 读 SKILL.md      │
├─────────────────────────────────────────────────┤
│ L3 uxctl      dump / diff / apply / verify /      │  唯一写入口 + 白名单
│               snapshot / restore / layout         │
├─────────────────────────────────────────────────┤
│ L2 cosmic-config  ~/.config/cosmic/<ns>/v1/<key>  │  原子写 + 热加载
├─────────────────────────────────────────────────┤
│ L1 COSMIC     panel / dock / applets / shortcuts  │
└─────────────────────────────────────────────────┘
```

**边界原则**：
- 配色 = `theme-next` / `exporters/cosmic`
- 布局/行为/键位 = `uxctl`
- 两者不交叉，避免"改主题把面板布局冲掉"

## 四、数据模型：UXProfile

JSON，**只写与默认/当前不同的项**（partial），apply 时做深合并：

```json
{
  "version": 1,
  "panel": {
    "anchor": "Top",
    "autohide": { "wait_time": 500, "transition_time": 200, "handle_size": 2 },
    "border_radius": 12,
    "opacity": 0.92,
    "size": "M",
    "wings": {
      "left":  ["com.system76.CosmicPanelWorkspacesButton", "com.system76.CosmicPanelAppButton"],
      "right": ["com.system76.CosmicAppletAudio", "com.system76.CosmicAppletNetwork",
                "com.system76.CosmicAppletBattery", "com.system76.CosmicAppletTime"]
    },
    "center": []
  },
  "dock": { "autohide": null, "size": "M" },
  "comp": { "autotile": true, "autotile_behavior": "PerWorkspace" },
  "shortcuts": { "custom": "<profile-name or inline list>" }
}
```

**schema 表**（内置在 uxctl 里）：

| 键 | 类型 | 约束 |
|---|---|---|
| `anchor` | enum | Top/Bottom/Left/Right |
| `autohide` | object/null | wait_time 0–2000ms |
| `border_radius` | number | 0–32 |
| `opacity` | number | 0.3–1.0 |
| `size` | enum | XS/S/M/L/XL |
| `wings.left/right`, `center` | applet id 列表 | 必须是已知 applet |
| `comp.autotile` | bool | |

值不合法 → 拒绝并给出可用取值，**不写文件**。

## 五、uxctl 命令面

```bash
uxctl dump [--ns panel|dock|comp|shortcuts] [--json]   # 当前值
uxctl profile show                                     # 合成 profile（JSON）
uxctl diff <profile.json>                              # 人类可读变更表
uxctl apply <profile.json> [--dry-run] [--yes]         # 原子写 + 快照
uxctl verify                                           # 读回校验（+ 可选截图）
uxctl snapshot list | restore <id>                     # 回滚
uxctl layout <preset>                                  # minimal|top|top+bottom|dock-only
uxctl shortcuts import <keybinds.json>                 # 生成 Shortcuts/custom
```

`diff` 输出示例：

```
panel.autohide        None → Some(wait_time: 500, …)
panel.border_radius   0    → 12
panel.opacity         1.0  → 0.92
(3 处变更，2 个文件)
```

## 六、安全模型

| 机制 | 说明 |
|---|---|
| **白名单** | 只允许 schema 表里的 ns/key；路径必须落在 `~/.config/cosmic/` 下且匹配 `<ns>/v1/<key>` |
| **类型校验** | 按 schema 校验后再生成 RON（模板化，不拼字符串） |
| **原子写** | `tmp + mv`，写入前把原文件复制到快照目录 |
| **快照** | `~/.local/state/uxctl/snapshots/<UTC时间戳>/`，含 manifest |
| **默认 dry-run** | 无 `--yes` 时只打印 diff，不写盘 |
| **变更预算** | 单次 apply ≤ 12 个键（防止 agent 大范围乱改） |
| **写后校验** | `verify` 读回对比；不一致自动 restore 并报错 |
| **恢复通道** | 面板改坏导致无 UI 时，从 TTY/SSH 执行 `uxctl restore <id>` |

## 七、Agent 协议（写进 SKILL.md 的 SOP）

```
1. 读现状      uxctl dump --json
2. 生成 plan   只包含必要键的 partial profile（写 /tmp/ux-<ts>.json）
3. 展示 diff   uxctl diff /tmp/ux-<ts>.json
4. 等确认      用户明确同意（或策略已授权 --yes）
5. 应用        uxctl apply /tmp/ux-<ts>.json --yes
6. 验证        uxctl verify && desktop-check cosmic
7. 报告        变更表 + 快照 id + 验证结果（失败自动回滚）
```

**硬性约束（skill 里加粗写出）**：
- 禁止直接写 `~/.config/cosmic/**`（只能经 uxctl）
- 禁止一次改动超过 12 个键
- 每次改动必须留快照，并在回复中给出快照 id
- 涉及 `comp`（平铺/工作区）的改动要额外提示"可能影响窗口布局"

## 八、与现有仓库的衔接

| 现有资产 | 关系 |
|---|---|
| `exporters/cosmic/theme.sh`（P2） | 只管 palette；uxctl 不碰主题文件 |
| `scripts/lib/de.sh` | uxctl 复用其 `de_name` 判断；非 COSMIC 时直接退出 |
| `desktop-check --de cosmic` | 增加一条：profile 与当前配置是否一致 |
| `themes/*/tokens.json` | 不涉及（配色独立） |
| skills 体系 | 新增 `skills/cosmic-ux/SKILL.md` |
| Nix 部署 | `home/` 只部署一份 **只读基线 profile**（`share/hyprland-nixos/ux/baseline.json`），其余运行期由 uxctl 管 |

## 九、实施阶段

| 阶段 | 内容 | 预估 |
|---|---|---|
| U1 | `uxctl dump/diff/apply/snapshot/restore` + schema + RON 模板 | 1 天 |
| U2 | `layout` 预设 + `shortcuts import` | 0.5 天 |
| U3 | `skills/cosmic-ux/SKILL.md` + 文档 | 0.5 天 |
| U4 | `verify` 接截图比对 + `desktop-check` 集成 | 0.5 天 |
| 合计 | | **2.5 天** |

## 十、示例会话

**例 1：顶栏自动隐藏 + 圆角**

> 用户：顶栏改成自动隐藏，圆角 12，稍微透一点
> agent：dump → 生成 `{panel:{autohide:{...},border_radius:12,opacity:0.92}}` → diff 3 行 → 用户确认 → apply → verify 通过 → "已应用，快照 20261027T0130Z"

**例 2：换 Dock 内容**

> 用户：Dock 只要启动器和文件管理器
> agent：改 `dock.plugins_center = Some([LauncherButton, CosmicFiles])` + `autohide` → diff → apply → verify

**例 3：键位对齐 Hyprland**

> 用户：把常用键位改成和我 Hyprland 一样，除了 Super+Space
> agent：读 `docs/KEYBINDS.md` 的对照表 → 生成 `shortcuts` profile（含排除项）→ diff（显示冲突项与跳过项）→ apply → verify 读回 Shortcuts/custom

## 十一、风险

| 风险 | 缓解 |
|---|---|
| RON 结构写错（元组/Some） | 全部走模板，禁止字符串拼接；schema 单测 |
| 热加载失败 | verify 读回兜底；失败自动 restore |
| 面板改坏导致无 UI | 快照 + TTY 恢复；apply 前提示"面板变更风险" |
| agent 越权改其他配置 | 唯一写入口 + 路径白名单 + 变更预算 |
| 与主题 exporter 互相覆盖 | 明确分工：theme 只管 cosmic-themes，uxctl 只管 CosmicPanel/Comp/Shortcuts |
| COSMIC 版本升级改 schema | `uxctl dump` 探测未知键并告警，不静默丢弃 |

## 十二、结论

COSMIC 的自定义能力全部落在**声明式 RON 文件 + 热加载**上，天然适合 agent 操作；
真正缺的不是能力，而是**受控的写入层**。uxctl 就是这个层：
它把"agent 的自由度"限制在 schema 白名单内，同时提供 diff/快照/回滚/验证，
使 agent 驱动 UX 定制从"危险的文本编辑"变成"可审计的配置事务"。
## 十三、实现进度

| 阶段 | 内容 | 状态 |
|---|---|---|
| U1-a | `uxctl dump`（只读） | **已完成（2026-10-27）** |
| U1-b | `diff / apply / snapshot / restore` | 待做 |
| U2 | `layout` 预设、`shortcuts import` | 待做 |
| U3 | skill `cosmic-ux` | 待做 |
| U4 | `verify` + desktop-check 集成 | 待做 |

`uxctl dump` 实测行为：

```bash
uxctl dump                      # 全部命名空间，人类可读
uxctl dump --ns panel           # 单个命名空间
uxctl dump --ns panel --json    # 机器可读（含 type/raw/count）
uxctl dump --ns panel --raw     # 不截断
```

输出含类型推断（bool/int/float/enum/none/some/list/record/string），
实测 panel 与 dock 各 22 键，空命名空间显示「无配置键」而非报错。

### U1-b：`uxctl diff`（已完成 2026-10-27）

```bash
uxctl diff profile.json          # 人类可读变更表
uxctl diff profile.json --json   # 机器可读 {changes, same, errors}
```

- **schema 白名单**：内置 panel/dock/comp 共 33 个可写键，未知键直接报错
- **类型校验**：enum 取值、数值范围（opacity 0.3–1.0、border_radius 0–32）、
  bool、applet 白名单（从 `/run/current-system/sw/share/applications` 读取 13 个内置 applet）
- **RON 模板化渲染**：`Some([...])` / `Some(([左],[右]))` / `Some((wait_time: …))` 各自独立函数，
  禁止字符串拼接
- **比较方式**：渲染结果与现文件做「去空白规范化」比较——实测对当前面板
  `plugins_wings` / `plugins_center` 判为「无变化」，说明模板与 COSMIC 自身写出的格式一致
- **退出码**：0 = 可应用（含 0 变更），1 = 有校验错误，2 = profile 读不了

### U1-c：`uxctl apply` + `snapshot`（已完成 2026-10-27）

```bash
uxctl apply profile.json                 # 默认 dry-run：只打印变更，不写盘
uxctl apply profile.json --yes --reason "改圆角"
uxctl snapshot list
uxctl snapshot restore <id>
```

流程：校验 → 变更预算（≤12 键）→ 快照 → 原子写（tmp+fsync+rename）→ 读回校验 →
不一致自动回滚。

实测：
| 场景 | 结果 |
|---|---|
| dry-run | 打印 `0 → 12`，文件未变 |
| `--yes` | 快照 `20261027T133822Z`，写入 12，校验通过 |
| `snapshot list` | 显示 id / 键数 / 键名 / reason |
| `snapshot restore` | 值回到 0 |
| 多键 apply（7 键） | 快照 + 写入 + 校验通过，随后 restore 完整还原 |

快照存于 `~/.local/state/uxctl/snapshots/<UTC id>/`：
`manifest.json`（id/created/reason/files[]）+ `files/<ns>/<key>`（原文件副本）。
未提供 `--yes` 时不会产生任何写入，这是 agent 工作流的安全默认值。

