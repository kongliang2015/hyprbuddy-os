# COSMIC 自定义 UX 调研（2026-10-27）

来源：
- <https://system76.com/cosmic>（产品页）
- <https://system76.com/cosmic/ux>（UX 自定义，官方口径）
- <https://system76.com/cosmic/theming>（主题，官方口径）
- 本机 COSMIC 1.2.0 实测（`~/.config/cosmic/**`、`/nix/store/*-cosmic-*`）

## 一、官方说法（原文要点）

**UX 页**列出五种"发行版可定制"的维度：

| 维度 | 官方描述 |
|---|---|
| Panels | 单/双面板、任意屏幕边缘、applet 放 beginning/center/end、可调尺寸与不透明度、方角/圆角 |
| Applets | 可自带 applet，用 Applet Template + libcosmic 开发；社区 applet 可上架 COSMIC Store |
| Shortcuts | 可定义发行版默认快捷键 |
| Settings | 可加自定义 Settings 页（cargo feature，如 Pop!_OS 的 "Upgrades and Restore"） |
| Theming | 一套主题贯穿 app / applet / 面板 / dock，甚至 Firefox |

**Theming 页**强调：颜色、面板、快捷键都可预设；字体与图标可换默认；"改一个 .config 就能换字体"；
社区主题站 <https://cosmic-themes.org/>。

**关键判断**：官方的"custom UX"面向**发行版打包者**（改默认值、加 Settings 页），
不是面向终端用户的插件生态——COSMIC **没有** GNOME Shell 扩展那样的运行时插件机制。

## 二、本机实测：配置到底存在哪

cosmic-config 把配置写成**每键一个文件**（不是单个 JSON），路径：

```
~/.config/cosmic/<命名空间>/v1/<键名>        # 值 = RON 片段
~/.local/share/cosmic-themes/<name>.ron      # 主题（可选，系统级在 /run/current-system/sw/share/cosmic-themes）
```

实测已存在的命名空间与键（本机）：

| 命名空间 | 可配置内容 | 实测键数 |
|---|---|---|
| `com.system76.CosmicPanel.Panel` | 主面板 | **22** |
| `com.system76.CosmicPanel.Dock` | 程序坞 | **22** |
| `com.system76.CosmicComp` | 平铺/工作区/xkb | 4 |
| `com.system76.CosmicAppList` | 收藏应用、拖拽 | 3 |
| `com.system76.CosmicBackground` | 壁纸 | 2 |
| `com.system76.CosmicSettings.Shortcuts` | 快捷键 | 默认表 + 自定义 |
| `com.system76.CosmicNotifications` | 通知 | 按需生成 |
| `com.system76.CosmicIdle` | 空闲/锁屏 | 按需生成 |

### 面板的 22 个键（实测枚举）

```
anchor  anchor_gap  autohide  autohover_delay_ms  background  border_radius
exclusive_zone  expand_to_edges  keyboard_interactivity  layer  margin  name
opacity  output  padding  padding_overlap  plugins_center  plugins_wings
size  size_center  size_wings  spacing
```

示例（本机实际值）：

```ron
# plugins_center
Some([
    "com.system76.CosmicAppletTime",
])
```

```ron
# CosmicAppList/favorites
[
    "firefox",
    "com.system76.CosmicFiles",
    ...
]
```

```ron
# CosmicComp/xkb_config
(
    rules: "",
    model: "pc104",
    layout: "cn",
    ...
)
```

### 主题文件（cosmic-themes）

```ron
(
    palette: Dark((
        name: "cosmic-dark",
        neutral_0 … neutral_10,       // 背景→前景 11 级灰阶
        accent_blue / accent_indigo / accent_purple / accent_pink /
        accent_red / accent_orange / accent_yellow / accent_green / accent_warm_grey,
        ext_*, space_*, radius_*,
    )),
    destructive: Some((r,g,b)),
    is_frosted: false,                // ← true = COSMIC 自带毛玻璃
    gaps: (0, 8),
    active_hint: 3,
)
```

## 三、六类自定义的具体做法

### 1. 配色（最有价值）

写 `~/.local/share/cosmic-themes/<name>.ron`，由我们 P2 的
`exporters/cosmic/theme.sh` 从 `themes/<slug>/tokens.json` 生成。
**已落地**：`theme-next` 在 COSMIC 会话下直接调 `cosmic_theme_apply`。

### 2. 面板形态

直接写 `com.system76.CosmicPanel.Panel/v1/` 下的键即可（热加载）：

```ron
# anchor          Top | Bottom | Left | Right
Top
# autohide
true
# border_radius
12.0
# opacity
0.92
# size
M            # S | M | L
# plugins_wings
Some([ "com.system76.CosmicAppletWorkspaces", "com.system76.CosmicAppletWindowTitle" ])
```

支持**双面板**：`com.system76.CosmicPanel/v1/entries` 里列两个面板名，各自有独立命名空间。

### 3. Applet 布局

`plugins_center` / `plugins_wings` 三个槽位，值是 `Some([...])` 的 RON 列表。
可用的内置 applet 从 store 里的 `cosmic-applets` 包可见（audio/battery/time/network/
workspaces/window title/input source 等）。

### 4. 快捷键

`com.system76.CosmicSettings.Shortcuts/v1/`：
- `defaults`：随包分发的默认表（只读）
- `custom`（我们写）：完整替换表，键位见 `docs/KEYBINDS.md` 的 COSMIC 章节

### 5. 字体 / 图标

- 字体：1.2 **没有字体设置项**（`CosmicTk/v1/` 只有 `header_size`、`interface_density`），
  实际走 **fontconfig**——我们已把中文统一到文泉驿（`modules/base.nix`）
- 图标：`cosmic-icons` + `hicolor` 主题；换成自定义图标集需要打包一个新图标主题

### 6. 启动器 / 收藏 / 工作区

- 收藏应用：`CosmicAppList/v1/favorites`
- 工作区：`CosmicComp/v1/{autotile, autotile_behavior, pinned_workspaces}`
- 键盘布局：`CosmicComp/v1/xkb_config`

## 四、对项目的可落地清单

| 目标 | 做法 | 成本 |
|---|---|---|
| 双面板（顶栏 + 底坞） | 部署 `CosmicPanel/v1/entries` + 两个面板命名空间 | 小（纯文件） |
| 面板自动隐藏 + 圆角 + 半透明 | 写 `autohide/border_radius/opacity` | 极小 |
| 自定义键位 | 写 `Shortcuts/v1/custom` | 中（需整理 15 个） |
| 品牌主题 | 已有 cosmic exporter | 已完成 |
| 自带 applet | 需 Rust + libcosmic 开发，打包成 `.desktop` + 二进制 | 大（不建议） |
| 自定义 Settings 页 | cargo feature，需重编 cosmic-settings | 很大（不建议） |

## 五、坑与限制

1. **没有 `cosmic-config` CLI**（本机无该命令）：只能直接写文件。写的时候要
   **原子替换**（临时文件 + mv），且 RON **最后一个元素允许尾逗号**——P2 的
   exporter 已经踩过这个坑。
2. **改完不需重启**：cosmic-settings-daemon WatchConfig → 各应用经 cosmic-config
   订阅热更新（P2 已实测）。
3. **没有运行时插件机制**：Applet 是 Rust 程序（`com.system76.CosmicApplet*` 的
   .desktop + 二进制），不是 shell 脚本；社区 applet 走 Flatpak + COSMIC Store。
4. **文档口径 vs 实现**：官网说"可加自定义 Settings 页/字体"，但那是**打包期**
   能力（cargo feature），用户侧做不到。

## 六、结论

COSMIC 的可定制性集中在**声明式配置文件**上，这恰好和本仓库"用 Nix 部署用户级配置"的
思路一致——不需要写插件、不需要重编译，只要把 RON 文件铺到 `~/.config/cosmic/`。

优先级建议：
1. **面板形态**（双面板/自动隐藏/圆角）——纯文件，收益最直观
2. **快捷键**（P3 第 1 项，已有方案）
3. **主题**（已完成）
4. Applet 开发——除非确有需求，否则放弃
