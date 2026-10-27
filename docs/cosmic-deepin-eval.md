# 参考 Deepin 设计 COSMIC 主题：可行性评估与方案

结论：**比参考 Windows 11 更容易**——同为 Linux、同样重"大圆角 + 蓝色强调 + 居中 Dock"，
而且 Deepin 用的中文字体我们已经有。唯一的硬伤还是**实时模糊**。

## 一、Deepin (DDE) 的构成要素

| # | 要素 | 具体表现 |
|---|---|---|
| 1 | 大圆角 | 卡片 12–16px、窗口 12px，柔和阴影 |
| 2 | 实时毛玻璃 | Dock / 启动器 / 控制中心背后做实时模糊 |
| 3 | 深海蓝强调 | `#0081FF` 主色，hover `#2C9BFF` |
| 4 | 底部居中胶囊 Dock | 半透明、圆角、图标 hover 放大 |
| 5 | 全屏启动器 | 网格 + 分类侧栏 + 搜索，背景模糊 |
| 6 | 右侧控制中心 | 快捷开关 + 亮度/音量滑块 + 通知合并 |
| 7 | 字体 | Source Han Sans / Noto Sans CJK |
| 8 | 图标 | deepin-icon-theme（圆润、彩色、辨识度高） |

## 二、COSMIC 对应能力（本机 1.2.0 实测）

| Deepin 要素 | COSMIC 对应 | 可行性 |
|---|---|---|
| 深海蓝强调 | `accent` / `accent_button`（含 hover/pressed） | ✅ |
| 大圆角 | `corner_radii`：xs=6 s=12 m=12 l=16 xl=32 | ✅ |
| 半透明表面 | `background`/`primary`/`secondary` 的 alpha | ✅ |
| 底部居中胶囊 Dock | Dock `anchor=Bottom` + `expand_to_edges=false` + `border_radius=16` | ✅ |
| 全屏启动器网格 | `cosmic-app-library`（Super+A，确认为独立二进制） | ✅ 结构上接近 |
| 控制中心 | 面板状态区 applet（快捷开关 + 滑块 + 通知） | ✅ 结构上接近 |
| 中文字体 | Noto Sans CJK SC（系统已有） | ✅ 零成本 |
| **实时模糊** | `is_frosted` | ❌ 实测前后截图 RMSE 0.19%，无可观察变化 |
| Dock 图标放大 | — | ❌ 无此动效 |
| 窗口圆角/阴影 | compositor 绘制 | ❌ 不可主题化 |
| 启动器玻璃背景 | — | ❌ 无背景模糊层 |
| 动画曲线 | toolkit 固定 | ❌ |

## 三、和 Windows 11 方案的对比

| 维度 | Windows 11 方案 | Deepin 方案 |
|---|---|---|
| 配色贴合度 | 中性灰 + 浅蓝 | **更接近**（Linux 审美一致） |
| 字体 | Segoe 专有，只能 Inter 近似 | **Noto Sans CJK 已具备** |
| 圆角体系 | 4/8 | **12/16 更符合 Deepin** |
| 启动器形态 | 开始菜单钉板（✗） | **应用库网格（✅ 接近）** |
| 控制中心 | 无对应 | **状态区 applet（✅ 接近）** |
| 核心短板 | Mica | **同样是模糊** |

→ **Deepin 方案的整体可达度约 75–80%，高于 Win11 的 ~70%。**

## 四、设计方案：`COSMIC Deepin Blue`

### 4.1 色板（深色）

```
背景      #1C1E26   (深蓝灰底)
表面      #262A36
次级表面  #2E3342
描边      #3A4152
正文      #E8EAF0
次要文字  #9AA3B5
强调      #0081FF
强调 hover #2C9BFF
危险      #FF5C5C
成功      #2ECC71
警告      #F5A623
```

### 4.2 形状与间距

```
corner_radii: xs=6  s=12  m=12  l=16  xl=32
spacing:      4 / 8 / 12 / 16 / 24 / 32
```

### 4.3 Dock 与面板

```
Dock:  anchor=Bottom  expand_to_edges=false  margin=8  padding=6
       border_radius=16  size=L  opacity=0.96
       plugins_center = [ LauncherButton, AppList, WorkspacesButton, Minimize ]
Panel: entries = [ "Dock" ]   # 只留一条任务栏，最接近 Deepin 默认
       （想保留托盘就加一条 XS 顶栏，Deepin 也有可选顶栏）
```

### 4.4 字体与图标

- 界面：**Noto Sans CJK SC**（已通过 fontconfig 设为中文首选）
- 等宽：JetBrainsMono Nerd Font
- 图标：先用 `cosmic-icons`；若要 Deepin 图标需评估 `deepin-icon-theme` 的许可证与体积

### 4.5 与我们的主题体系衔接

```json
{
  "name": "Deepin Blue", "dark": true, "order": 8,
  "bg": "1C1E26", "surface": "262A36", "fg": "E8EAF0", "muted": "9AA3B5",
  "accent": "0081FF", "accent2": "2C9BFF", "urgent": "FF5C5C"
}
```

作为第 9 套主题加入 `themes/deepin-blue/tokens.json`，Hyprland 与 COSMIC 两侧自动跟随。

## 五、落地路径与工作量

| 产物 | 做法 | 工时 |
|---|---|---|
| `themes/deepin-blue/tokens.json` | 按 4.1/4.2 填 | 0.5 h |
| cosmic exporter 补 `corner_radii`/`spacing` | 目前 exporter 只写颜色，需加形状映射 | 1–2 h |
| Dock-only 布局 | `uxctl layout save deepin-dock` + `apply` | 0.5 h |
| 字体 | 无改动（Noto 已在用） | 0 |
| 验证 | 截图 + 对比度 + `uxctl verify` | 0.5 h |

合计 **约 0.5–1 天**，比 Win11 方案快（省了字体接入）。

## 六、风险

| 风险 | 说明 |
|---|---|
| 模糊预期 | Deepin 的"高级感"一半来自实时模糊，COSMIC 拿不到；需提前说明 |
| Dock 动效 | Deepin 图标 hover 放大/跳动，COSMIC 无此动效 |
| 图标授权 | deepin-icon-theme 为 GPL，混入需注意；默认先用 cosmic-icons |
| 控制中心形态 | DDE 是右侧滑出面板，COSMIC 是状态区弹出菜单，仅结构近似 |
| 主题覆盖面 | 覆盖 `CosmicTheme.Dark/v1/*` 是全局的，需保留备份与切回路径 |

## 七、结论

**可做，且比 Win11 更划算。**

- 能做到：深蓝灰底 + `#0081FF` 强调 + 12/16 大圆角 + 居中胶囊 Dock + 应用库网格 + Noto 字体
- 做不到：实时模糊、图标放大动效、窗口圆角/阴影、启动器玻璃背景
- 观感预计：**75–80% 接近 Deepin**，差距集中在"玻璃质感"和"Dock 动效"

建议把它作为第 9 套主题（`deepin-blue`）与现有 8 套并列，
不替换默认主题；先用 `theme-next` 切过去看实际效果，再决定是否设为默认。
## 八、实现状态（2026-10-27）

| 项 | 状态 |
|---|---|
| `themes/deepin-blue/tokens.json` | ✅ 已加入（第 9 套，order=8） |
| cosmic exporter 形状支持 | ✅ 读 `corner_radii` / `spacing`，缺省时回落官方默认 |
| 深蓝配色 | ✅ 实测 `accent=#0081FF`、`background=#1C1E26` |
| 12/16 圆角 | ✅ 实测 `radius_s/m=12, l=16, xl=32` |
| Dock-only 布局 | ⏳ 待做（`uxctl layout save deepin-dock`） |
| 整体观感验证 | ⏳ 待用户在 COSMIC 会话实际切换体验 |

切换：`theme-next 8`（Deepin Blue）；回退：`theme-next 0`（Kanagawa）。


## 九、Dock-only 布局（已实现）

配置文件：`ux/profiles/deepin-dock.json`

```json
{ "panels": { "entries": ["Dock"] },
  "dock": { "anchor": "Bottom", "expand_to_edges": false, "margin": 8,
            "padding": 6, "border_radius": 16, "size": "L",
            "opacity": 0.96, "autohide": null,
            "plugins_center": ["LauncherButton", "AppList", "WorkspacesButton", "Minimize"],
            "plugins_wings": { "left": [], "right": ["StatusArea", "Notifications", "Power"] } } }
```

```bash
uxctl apply ux/profiles/deepin-dock.json --yes --reason "deepin-dock 布局"
uxctl snapshot restore <apply 输出的快照 id>     # 回滚
```

uxctl 为此新增了 `panels.entries` 写入支持（值必须是 `Panel` / `Dock` 的子集）。

**注意**：`entries` 只留 `Dock` 意味着顶栏消失，时钟与部分托盘项随之不见；
已把 `StatusArea` / `Notifications` / `Power` 移到 Dock 右翼作为补偿。
若发现托盘项不显示，把 `entries` 改回 `["Panel", "Dock"]` 即可恢复。
