# UX 可自定义能力清单

> **历史 / 设计稿（2026-11-04 标注）**：本文是 COSMIC / Hyprland 时代的 UX 能力清单（自称「唯一清单」），其中 `uxctl`、COSMIC 34 键等均已不存在。现行能力见 `docs/SKILLS.md` 与 `agent-commands --json`。
> 当前实现为 **niri 26.04 + Noctalia v5**（唯一桌面提供方），现状以
> `docs/ROADMAP.md`、`docs/SKILLS.md`、`skills/nixos-desktop-settings/` 与代码为准。
> 本文保留为历史与决策依据，勿按现状引用。

本文是"我能改什么、改哪里、改不了什么"的唯一清单。新增能力时同步更新本文件。

## 结论（先看这四条）

1. **COSMIC 侧**能控制「结构 + 配色 + 形状」，共 **34 个可写键** + 主题字段
2. **Hyprland 侧**能控制「一切视觉细节」（CSS/层模糊/切角/发光）
3. **工具层**统一走 `uxctl`（受控写入）与 `theme-next`（配色）
4. 做不到的集中在四个：实时模糊、窗口装饰、动画曲线、分类菜单

## 一、COSMIC：面板与 Dock（22 键 × 2）

`com.system76.CosmicPanel.Panel/v1/` 与 `com.system76.CosmicPanel.Dock/v1/` 键完全相同：

| 能力 | 键 | 取值 / 说明 |
|---|---|---|
| 位置 | `anchor` | Top / Bottom / Left / Right |
| 自动隐藏 | `autohide` | `None` 或 `Some((wait_time, transition_time, handle_size, unhide_delay_ms))` |
| 尺寸档位 | `size` | XS / S / M / L |
| 中区/翼区尺寸 | `size_center` / `size_wings` | 同上或 None |
| 圆角 | `border_radius` | 0–32（160 = 胶囊） |
| 透明度 | `opacity` | 0.3–1.0（必须是浮点，`1.0` 不是 `1`） |
| 背景 | `background` | ThemeDefault / Dark / Light / Custom |
| 边距/内距/间距 | `margin` / `padding` / `spacing` | 0–64 |
| 通栏 | `expand_to_edges` | true = 拉满宽度 |
| 挤压窗口 | `exclusive_zone` | true = 占位；false = 浮在窗口上 |
| 层级 | `layer` | Background / Bottom / Top / Overlay |
| 键盘交互 | `keyboard_interactivity` | OnDemand / Exclusive / None |
| 悬停延迟 | `autohover_delay_ms` | 毫秒 |
| 输出 | `output` | All 或指定显示器 |
| **组件布局** | `plugins_center` | `Some([id, ...])` |
| **翼区布局** | `plugins_wings` | `Some(([左翼...], [右翼...]))` |

## 二、COSMIC：可放进面板的组件（17 个）

```
Applet（13）:
  com.system76.CosmicAppletA11y     InputSources   Network
  CosmicAppletAudio                Minimize       Notifications
  CosmicAppletBattery              Power          StatusArea
  CosmicAppletBluetooth            Tiling         Time
  CosmicAppletWorkspaces

面板按钮（3）:
  com.system76.CosmicPanelLauncherButton   启动器
  com.system76.CosmicPanelAppButton        当前应用按钮
  com.system76.CosmicPanelWorkspacesButton 工作区切换

列表组件（1）:
  com.system76.CosmicAppList   收藏应用 + 当前工作区运行窗口（图标任务栏）
```

**不能做**：自定义 applet（要 Rust + libcosmic 编译）；给按钮换图标。

## 三、COSMIC：其他命名空间

| 能力 | 命名空间 / 键 | 入口 |
|---|---|---|
| 面板启停 | `CosmicPanel/v1/entries` | ✅ `uxctl` |
| 收藏应用 | `CosmicAppList/v1/favorites` | 手改 RON / 拖拽 |
| 平铺开关 | `CosmicComp/v1/autotile` | ✅ `uxctl` |
| 平铺策略 | `CosmicComp/v1/autotile_behavior` | ✅ `uxctl` |
| 固定工作区 | `CosmicComp/v1/pinned_workspaces` | 手改 |
| 键盘布局 | `CosmicComp/v1/xkb_config` | 手改 |
| 壁纸 | `CosmicBackground/v1/all` | ✅ 能力层 `de_wallpaper_set` |
| 壁纸按主题切换 | `CosmicBackground/v1/filter_by_theme` | 手改 |
| 快捷键 | `CosmicSettings.Shortcuts/v1/custom` | ⚠️ 可手写 RON，uxctl 未接 |
| 通知 | `CosmicNotifications/v1/*` | 按需生成 |
| 空闲/锁屏 | `CosmicIdle/v1/*` | 按需生成 |
| 字体 | **只能全局 fontconfig** | 已统一文泉驿 |

## 四、COSMIC：主题（配色 + 形状）

可写的容器样式（每个都有 base/hover/pressed/selected 等状态）：

```
background  primary  secondary  button  accent  icon_button  link_button
text_button  accent_button  success  warning  destructive  warning_button
palette  corner_radii  spacing  is_frosted
```

| 能力 | 字段 | 说明 |
|---|---|---|
| 主色 | `accent` | 单一强调色 |
| 容器层级 | `background` / `primary` / `secondary` | 靠表面提亮表达层级 |
| 语义色 | `success` / `warning` / `destructive` | |
| 圆角阶梯 | `corner_radii` | 0/4/8/16/32/160 六档，可自定义 |
| 间距阶梯 | `spacing` | 10 档 |
| 冷调 | `neutral_tint` / `bg_color` / `text_tint` | 可整体染色 |
| 毛玻璃 | `is_frosted` | **实测无可见效果**（RMSE 0.19%），不要依赖 |

写入方式：`themes/<slug>/tokens.json` → `exporters/cosmic/theme.sh` → `theme-next`。

## 五、Hyprland 侧（视觉细节全开）

| 能力 | 入口 | 粒度 |
|---|---|---|
| 配色 | `themes/*/tokens.json`（**10 套**） | 全组件 |
| 组件样式 | `exporters/hyprland/*.sh`（**12 个**） | CSS 完全可控 |
| 键位 | `home/hypr/hyprland.lua` | 任意 Lua 绑定 |
| 窗口/图层规则 | 同上（含 blur / ignore_alpha） | 按 class / namespace |
| 登录界面 | `pkgs/sddm-theme-hyprbuddy/Main.qml` | 自绘 |
| 锁屏 | `home/hypr/hyprlock.conf` | 完全可控 |

只有这一层能做：切角、发光、扫描线、等宽数字、层模糊。

## 六、工具层

| 工具 | 能力 |
|---|---|
| `uxctl dump/diff/apply/snapshot/restore` | 34 键白名单写入，默认 dry-run，写后校验，失败自动回滚 |
| `uxctl layout list/apply/save` | 系统模板（2 个）+ 用户模板（45 键整树） |
| `theme-next <idx>` | 10 套主题热切换，按桌面自动分派 exporter |
| `de-theme-apply <slug>` | 按 slug 应用主题 |
| `desktop-check` | 按桌面自检（COSMIC 12 项 / Hyprland 8 组） |
| skills | `cosmic-ux`（布局/行为）、`scifi-ui`（视觉规范）、`nixos-desktop-settings` |

## 七、明确做不到的

| 想要 | 原因 |
|---|---|
| 分类网格菜单（Mint Menu / 开始菜单） | 无此组件；applet 需 Rust 开发 |
| 启动器贴底弹出 | `cosmic-launcher` 用 layer-shell，锚点在程序内写死（实测 top 居中，y=16） |
| 实时模糊 / Mica | `is_frosted` 实测无可观察效果 |
| 窗口圆角 / 阴影 / 标题栏 | compositor 绘制，不可主题化 |
| 动画曲线 / 转场 | toolkit 固定 |
| 逐应用样式 | COSMIC 无 per-app 主题 |
| 面板按钮换图标 | 无接口 |
| App Library 作面板组件 | 它是独立应用，不是 applet（实测以窗口启动） |

## 八、操作速查

```bash
# 看现状
uxctl dump --ns panel --json

# 改面板（默认 dry-run，确认后加 --yes）
uxctl diff my-profile.json
uxctl apply my-profile.json --yes --reason "xxx"

# 布局模板
uxctl layout list
uxctl layout apply cosmic-center-taskbar --yes
uxctl layout save my-layout

# 主题
theme-next 8            # Deepin Blue
theme-next 9            # Mint-Y（浅色）
theme-next 0            # Kanagawa

# 回滚
uxctl snapshot list
uxctl snapshot restore <id>
```

## 九、维护约定

- 新增可写键：先加 `scripts/uxctl` 的 `SCHEMA`，再更新本文第二节
- 新增主题：`themes/<slug>/tokens.json`（order 递增），本文第四节无需改
- 发现"做不到"的项被上游解决（如 `is_frosted` 生效），从第七节移到对应能力表
- 本文与代码冲突时，**以 `scripts/uxctl` 的 SCHEMA 为准**
