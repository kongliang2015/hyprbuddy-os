# P2 主题 token 化方案

> 注：本文中的 `hyprland-nixos` 为更名前的仓库名（现为 `hyprbuddy-os`），按历史原样保留。

> **历史 / 设计稿（2026-11-04 标注）**：本文是 P2 主题 token 化设计稿，范围曾收缩为「只给 COSMIC 导出调色板」；当前实现是 `exporters/niri/theme.sh` → `theme.toml`（壁纸取色）。`tokens.json` 机制本身仍然有效。
> 当前实现为 **niri 26.04 + Noctalia v5**（唯一桌面提供方），现状以
> `docs/ROADMAP.md`、`docs/SKILLS.md`、`skills/nixos-desktop-settings/` 与代码为准。
> 本文保留为历史与决策依据，勿按现状引用。

> **修订（2026-10-26）**：COSMIC 已原生提供的桌面功能不再迁移，P2 范围收缩为
> 「token 化 + 只给 COSMIC 导出调色板」。详见文末《十、迁移边界》，第四节与工作量以修订版为准。

目标：把主题数据从 `scripts/theme-next` 的 shell 数组里抽出来，变成一份 **JSON token**，
再按桌面拆成多个 exporter。这样：
- 视觉输出零变化（有 golden 校验兜底）
- COSMIC 能复用同一份配色（新增 exporter）
- Hyprland 退役时只需删掉 `exporters/hyprland/`，主题资产不丢

## 一、现状盘点

### 1.1 数据结构

`scripts/theme-next` 里 `THEMES` 是 36 字段的管道分隔数组：

```
name | wallpaper | ha1 | ha2 | hi
| wb_bg | wb_fg | wb_ws | wb_wsafg | wb_wsabg | wb_urgent | wb_clock
| wb_cpu | wb_mem | wb_bat | wb_pulse | wb_agent
| k_bg | k_fg | k_cursor | k0..k15 (16 色)
```

派生色由 `mixhex A B pct` 现算（例如 swaync 卡片底 = `wb_bg` 向 `wb_fg` 提 8%）。

### 1.2 13 个 writer

| # | writer | 目标文件 |
|---|---|---|
| 1 | waybar | `waybar/style.css` |
| 2 | swaync | `swaync/style.css` |
| 3 | eww | `eww/eww.scss` |
| 4 | hyprshell | `hyprshell/styles.css` |
| 5 | swayosd | `swayosd/style.css` |
| 6 | fuzzel | `fuzzel/fuzzel.ini` |
| 7 | kitty | `kitty/theme.inc.conf` + `kitty @ set-colors` |
| 8 | hyprlock | `hypr/hyprlock.conf` 颜色段 |
| 9 | hyprtoolkit | `hypr/hyprtoolkit.conf` |
| 10 | fastfetch | `fastfetch/config.jsonc` |
| 11 | 边框（Lua） | `hypr/theme.lua` |
| 12 | 壁纸 | awww |
| 13 | 提交/预览 | `state` 文件 + 预览图 |

### 1.3 COSMIC 主题格式（本次新增依赖）

`/nix/store/*-cosmic-initial-setup-1.2.0/share/cosmic-themes/<name>.ron` + `<name>.png`：

```ron
(
    palette: Dark((
        name: "cosmic-dark",
        bright_red: (red: 1.0, green: 0.627451, blue: 0.5647059, alpha: 1.0),
        gray_1: (...), gray_2: (...),
        neutral_0: (...) … neutral_10: (...),   // 背景→前景的 11 级灰阶
        accent_blue / accent_indigo / accent_purple / accent_pink /
        accent_red / accent_orange / accent_yellow / accent_green / accent_warm_grey,
        ext_* 与 space_* / radius_* 也在 palette 里
    )),
    destructive: Some((...)),
    is_frosted: false,      // ← true 即 COSMIC 自带毛玻璃
    gaps: (0, 8),
    active_hint: 3,
    window_hint: None,
)
```

对我们的映射：

| 我们的 token | COSMIC 字段 |
|---|---|
| `bg` / `bg2` / `fg` | `neutral_0` / `neutral_2` / `neutral_10`（按亮度插值生成 11 级） |
| `accent` | `accent_blue`（或按色相就近选 accent_*） |
| `accent2` | `accent_purple` |
| `urgent` | `destructive` |
| 玻璃拟态 | `is_frosted: true` |

## 二、目标结构

```
themes/
  kanagawa/tokens.json
  tokyo-night/tokens.json
  …（8 套）
lib/
  tokens.py                  # 读取 + 派生，导出 shell 变量
scripts/
  theme-next                 # 调度器（next/prev/set/restore/preview）
  exporters/
    hyprland/{waybar,swaync,eww,hyprshell,swayosd,fuzzel,kitty,hyprlock,hyprtoolkit,fastfetch,border,wallpaper}.sh
    cosmic/cosmic.sh
```

部署路径（和 `de.sh` 同一机制）：

```
~/.local/share/hyprland-nixos/themes/<id>/tokens.json
~/.local/share/hyprland-nixos/lib/tokens.py
~/.local/share/hyprland-nixos/exporters/…
```

## 三、tokens.json 结构

```json
{
  "id": "kanagawa",
  "name": "Kanagawa",
  "wallpaper": "01-kanagawa.png",
  "colors": {
    "accent": "7E9CD8",
    "accent2": "957FB8",
    "borderInactive": "54546D",
    "urgent": "FF5D62"
  },
  "waybar": {
    "bg": "16161D", "fg": "DCD7BA",
    "workspace": "54546D", "workspaceActiveFg": "DCD7BA", "workspaceActiveBg": "2A2A37",
    "clock": "DCD7BA", "cpu": "7AA89F", "mem": "76946A", "battery": "DCA561",
    "pulse": "957FB8", "agent": "7E9CD8"
  },
  "kitty": {
    "background": "1F1F28", "foreground": "DCD7BA", "cursor": "DCD7BA",
    "palette": ["C34043", "76946A", "C0A36E", "7E9CD8", "957FB8", "6A9589", "C5C9C5",
                "717C7C", "C34043", "76946A", "C0A36E", "7E9CD8", "957FB8", "6A9589", "DCD7BA"]
  },
  "style": {
    "radiusCard": 12, "radiusWindow": 14,
    "alphaCard": 0.72, "alphaPanel": 0.94, "alphaBar": 0.86,
    "font": "JetBrainsMono Nerd Font", "fontCjk": "Noto Sans CJK SC",
    "fontSize": 13
  }
}
```

约定：
- **数值保持原样**（不带 `#`），与现有 `THEMES` 字段一一对应，便于用脚本机械迁移
- 派生色（`mixhex` 结果）**不进 JSON**，仍在 exporter 里算 → 输出可复现
- `style` 段是新增的收敛项：把现在散落在 writer 里的圆角/透明度/字体集中管理

## 四、读取方式（不引入 jq）

jq 不在 PATH 上，python3 已有依赖。`lib/tokens.py` 提供：

```bash
# exporter 开头统一这样用
eval "$(python3 "$LIB/tokens.py" export kanagawa)"   # 输出 TK_ACCENT=7E9CD8 等
eval "$(python3 "$LIB/tokens.py" style)"             # TK_RADIUS_CARD=12 等
```

并暴露 `derive` 子命令做与 `mixhex` 等价的运算，避免两套实现漂移：

```bash
python3 "$LIB/tokens.py" derive 16161D DCD7BA 8    # → #2A2A37
```

## 五、迁移步骤（每步都可单独回滚）

### Step 0：golden 快照（前置，最重要）

```bash
for i in 0..7; do theme-next <i>; cp -r ~/.config/{waybar,swaync,eww,hyprshell,swayosd,fuzzel,kitty,hypr,fastfetch} /tmp/golden/<i>/; done
```
之后每次改动都跑同一循环 `diff -r`，**必须零差异**。

### Step 1：数据外置

写一次性脚本 `tools/export-themes.py`（不进仓库，或放 `lib/`），把 `THEMES` 数组解析成 8 个 `tokens.json`，
并断言 36 字段全部落位（数量 + 每套主题 id 唯一）。

### Step 2：调度骨架

- `theme-next` 只保留：解析参数（next/prev/set/restore/preview）、读写 state、调用 exporter、切壁纸
- 新增 `theme-next --only waybar` 便于单独调试
- 此步不删旧 writer，用 `--legacy` 开关并存对比

### Step 3：逐个搬 writer（13 步，每步 diff）

建议顺序（影响面从小到大）：
`fuzzel → swayosd → hyprtoolkit → hyprlock → fastfetch → waybar → swaync → eww → hyprshell → kitty → border → wallpaper → 预览`

每搬一个：
1. 新文件 `exporters/hyprland/<name>.sh`，只读 token
2. `theme-next --only <name>` 生成
3. `diff` 对应 golden 文件
4. 通过后删除旧 writer 段

### Step 4：COSMIC exporter

`exporters/cosmic/cosmic.sh`：
1. 由 `bg/bg2/fg` 生成 `neutral_0..neutral_10`（线性插值，亮度递增）
2. 由色相把 `accent/accent2` 映射到 `accent_*(，`urgent` → `destructive`
3. `is_frosted: true`（对齐我们的玻璃拟态）、`gaps`、`radius_*` 取自 `style`
4. 写 `~/.local/share/cosmic-themes/<id>.ron` + 复制壁纸为 `<id>.png`
5. 通过 `cosmic-config` 或直接写 `com.system76.CosmicTheme.Mode/v1` 激活

### Step 5：收尾

- `desktop-check` 增加主题检查：当前主题名、生成文件是否最新、COSMIC 是否有对应 RON
- `theme-preview-capture` 兼容两桌面（COSMIC 用 cosmic-screenshot）
- 文档：`docs/themes/README.md` 写 token 字段表

## 六、验收矩阵

| 阶段 | 验收命令 | 期望 |
|---|---|---|
| Step 1 | `python3 lib/tokens.py list` | 8 个 id，字段数与 THEMES 一致 |
| Step 3（每步） | `diff -r /tmp/golden/<i> ~/.config/…` | 零差异 |
| Step 4 | `desktop-check cosmic` | 主题检查通过，COSMIC 应用后配色变化 |
| 全量 | 8 套主题 × 2 桌面切换 | 无报错，视觉一致 |

## 七、风险与回退

| 风险 | 缓解 |
|---|---|
| 搬迁时漏字段导致颜色错 | golden diff 是硬门槛，13 步每步比 |
| `mixhex` 与 python 派生结果差 1（四舍五入） | 只在 python 实现一份，bash 调它，删掉旧函数 |
| COSMIC 主题不生效 | 先用官方 `mocha-dark.ron` 复制改名验证加载路径，再换颜色 |
| 主题切换时 COSMIC 需重启会话 | 优先测试是否热加载；不行则文档标注"需注销" |
| 部署路径变化导致脚本找不到 tokens | 沿用 `de.sh` 的 `XDG_DATA_HOME` 模式 + 仓库内回退 |

## 八、工作量

| 阶段 | 预估 |
|---|---|
| Step 0–2（快照 + 迁移 + 骨架） | 2–3 h |
| Step 3（13 个 writer） | 4–5 h（可分 2 次） |
| Step 4（COSMIC exporter） | 2–3 h |
| Step 5（自检 + 文档） | 1 h |
| 合计 | **约 10 h**，建议拆 3 个会话 |

## 九、与 P3/P5 的关系

- P3 的"键位统一"可以复用同一套 `lib/` + `exporters/` 结构（token 之外再加 `keybinds.json`）
- P5 退役时删 `exporters/hyprland/` 即可，`themes/*/tokens.json` 与 cosmic exporter 保留
## 十、迁移边界（修订）：COSMIC 原生功能不搬

原则：**COSMIC 自己有的，不重复实现**。只迁「桌面不提供、属于我们资产」的部分。

| # | 现有 writer | COSMIC 原生对应 | 结论 |
|---|---|---|---|
| 1 | waybar（顶栏） | cosmic-panel + applets | **不迁移**（COSMIC 面板自带） |
| 2 | swaync（通知/控制中心） | cosmic-notifications | 不迁移 |
| 3 | eww（日历/会话弹窗） | 面板 applet + 系统动作 | 不迁移 |
| 4 | hyprshell（总览/切换） | WorkspaceOverview / WindowSwitcher | 不迁移 |
| 5 | swayosd（OSD） | cosmic-osd | 不迁移 |
| 6 | fuzzel（启动器） | cosmic-launcher（Super 单按） | 不迁移 |
| 7 | hyprlock（锁屏） | COSMIC 内置锁屏 | 不迁移 |
| 8 | hyprtoolkit（polkit 认证框） | 系统 polkit agent | 不迁移 |
| 9 | Hyprland 边框（theme.lua） | 无对应，且 Hyprland 将退役 | 保留为 Hyprland 专属 |
| 10 | 壁纸（awww） | cosmic-bg | **不迁移**，改用已有的 `de_wallpaper_set` |
| 11 | **kitty 配色** | 无（终端是应用级） | **迁移（共享）** |
| 12 | **fastfetch 配色** | 无（终端工具） | **迁移（共享）** |
| 13 | **主题调色板本身** | cosmic-themes RON 需要我们自己生成 | **迁移（唯一必须项）** |

### 修订后的结构

```
themes/<id>/tokens.json           8 套（唯一真相）
lib/tokens.py                     读取 + 派生
scripts/theme-next                调度器（切主题/切壁纸/调 exporter）
scripts/exporters/
  hyprland/*.sh                   1-9 项：只在 Hyprland 会话生效，P5 退役时整目录删除
  shared/kitty.sh                 11-12 项：两桌面共用（终端资产，不是桌面功能）
  shared/fastfetch.sh
  cosmic/palette.sh               13 项：生成 cosmic-themes RON（neutral 插值 + accent 映射
                                  + is_frosted + radius/gaps），并用 cosmic-config 激活
```

### 修订后的步骤

| Step | 内容 | 变化 |
|---|---|---|
| 0 | golden 快照 | 不变 |
| 1 | THEMES → tokens.json | 不变 |
| 2 | theme-next 退化为调度器 | 不变 |
| 3a | 桌面组件 writer（1–9）**只做 token 化，仍仅 Hyprland** | 不新增 COSMIC 实现 |
| 3b | 共享 writer（kitty、fastfetch）改为读 token | 跨桌面生效 |
| 4 | **唯一新增**：`cosmic/palette.sh`（约 100 行） | 原计划 13 个 cosmic exporter → 1 个 |
| 5 | 自检 + 文档 | 不变 |

### 修订后的工作量

| 阶段 | 预估 |
|---|---|
| Step 0–2 | 2–3 h |
| Step 3a/3b（token 化 11 个 writer，不加新功能） | 3–4 h |
| Step 4（cosmic palette） | 1.5–2 h |
| Step 5 | 1 h |
| **合计** | **约 8 h**（原 10 h） |

### 附带收益

- COSMIC 侧只需要维护 **1 个 exporter**，不存在"两套 UI 同步升级"的负担
- P5 退役 Hyprland 时，删 `exporters/hyprland/` 不影响 COSMIC 与终端资产
- 不再需要为 COSMIC 重写 CSS 类（原方案里最不确定、最容易反复的部分被整体去掉）

