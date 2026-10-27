# 参考 Windows 11 设计 COSMIC 主题：可行性评估与方案

结论先说：**视觉气质可复刻约 70%，交互结构基本不可复刻**。
能拿到的：配色体系、容器层级、圆角、间距、居中 Dock；
拿不到的：Mica 壁纸采样、Snap Layouts、开始菜单钉板、窗口描边/阴影、动画曲线、Segoe 字体。

## 一、Windows 11 (Fluent) 的构成要素

| # | 要素 | 具体表现 |
|---|---|---|
| 1 | 配色 | 深色底 #202020、表面 #2B2B2B、描边 #3A3A3A、强调色 #0078D4 / #60CDFF |
| 2 | 层级 | 靠"表面提亮"表达层级，而不是靠边框或阴影 |
| 3 | 圆角 | 控件 4px、卡片 8px、窗口 8px（四角统一） |
| 4 | Mica / Acrylic | 窗口背景采样壁纸并模糊 |
| 5 | 任务栏 | 底部居中、图标分组、hover 胶囊高亮 |
| 6 | 开始菜单 | 固定应用网格 + 推荐区 + 搜索 |
| 7 | Snap Layouts | 悬停最大化按钮弹出分屏方案 |
| 8 | 动效 | 弹性/缓出曲线，窗口最小化飞入任务栏 |

## 二、COSMIC 的实际能力（本机 1.2.0 实测）

主题覆盖目录 `~/.config/cosmic/com.system76.CosmicTheme.Dark/v1/` 下实际有：

```
background  primary  secondary  button  accent  icon_button  link_button
text_button  accent_button  warning  success  destructive  warning_button
palette  corner_radii  spacing  is_frosted
```

每个 surface（`background`/`primary`/`secondary`/`button`…）是**带状态的容器样式**：

```ron
(
    base:  (red: 0.086, green: 0.086, blue: 0.114, alpha: 1.0),
    component: (
        base:   (r, g, b, a),
        hover:  (r, g, b, a),
        pressed:(r, g, b, a),
    ),
)
```

`corner_radii` 当前值：`xs=2, s/m/l/xl=8`（已经是 8px 体系）；`spacing` 10 档。

## 三、可行性矩阵

| Win11 要素 | COSMIC 对应 | 可行性 | 说明 |
|---|---|---|---|
| 配色（底/表面/强调） | `background`/`primary`/`secondary`/`accent` | ✅ | 逐容器可调，含 hover/pressed |
| 表面提亮表达层级 | `primary`/`secondary`/`button` 的 alpha 与色值 | ✅ | 与 Fluent 同思路 |
| 圆角 4/8 | `corner_radii` 六档 | ✅ | 当前已是 8，调 xs=4 即对齐控件圆角 |
| 间距 4/8/12/16 | `spacing` 十档 | ✅ | 直接改 |
| 居中 Dock | Dock `anchor=Bottom` + `expand_to_edges=false` + `margin` | ✅ | 已有模板证明可行（胶囊 Dock） |
| Dock 图标 hover 胶囊 | Dock `button` hover 态 | △ | 可给组内按钮加圆角高亮，但不是任务栏级"胶囊指示器" |
| Mica 壁纸采样 | `is_frosted` | △/✗ | **实测未观察到可见变化**（RMSE 0.19%，等同噪声），需应用重启复测；大概率不是真 Mica |
| 开始菜单钉板 | cosmic-launcher | ✗ | 搜索优先列表，无固定网格/推荐区 |
| Snap Layouts | cosmic-comp tiling | ✗ | 有平铺与快捷键，无悬停弹出式方案选择 |
| 窗口描边/阴影/标题栏 | compositor + toolkit | ✗ | 不可主题化 |
| 动画曲线（弹性/飞入） | toolkit 固定 | ✗ | 无自定义缓动入口 |
| Segoe UI Variable | fontconfig 全局 | ✗（字体本身） | 专有字体，不可分发；可用 Inter 近似 |

## 四、设计方案：`COSMIC Fluent Dark`

### 4.1 色板

```
背景      #202020   (Win11 dark 基底)
表面      #2B2B2B   (卡片/输入框)
次级表面  #272727
描边      #3A3A3A
正文      #F3F3F3
次要文字  #A0A0A0
强调色    #60CDFF   (Win11 dark 强调，浅蓝)
强调 hover #7FD8FF
危险      #FF99A4
成功      #6CCB5F
警告      #FCE100
```

### 4.2 形状与间距

```
corner_radii: xs=4  s=8  m=8  l=8  xl=16
spacing:      4 / 8 / 12 / 16 / 24 / 32
```

### 4.3 Dock 与面板

```
Dock:  anchor=Bottom  expand_to_edges=false  margin=8  border_radius=16
       size=M  opacity=1.0  autohide=None
       plugins_center = [ LauncherButton, AppList, WorkspacesButton ]
Panel: 隐藏（Win11 只有一条任务栏）→ entries = [ "Dock" ]
```

面板隐藏意味着放弃顶栏的时钟/托盘；若要保留，改为顶栏 XS + 纯托盘（与 Win11 托盘区对应）。

### 4.4 字体

- 界面：`Inter`（开放授权，x-height 与 Segoe 接近）通过 fontconfig 设为 sans-serif 首选
- 等宽：保留 JetBrainsMono Nerd Font
- 不可用 Segoe UI Variable（专有，分发有法律风险）

### 4.5 图标

`cosmic-icons` 保留（线性风格与 Fluent 接近）；若换 Fluent 图标需注意微软图标集授权。

## 五、落地路径

| 产物 | 做法 | 工作量 |
|---|---|---|
| `themes/fluent-dark/tokens.json` | 按 4.1/4.2 填 token（含 `dark: true`） | 0.5 h |
| cosmic 侧 | `exporters/cosmic/theme.sh` 已支持从 token 生成，补 `corner_radii`/`spacing` 映射即可 | 1–2 h |
| Hyprland 侧 | 走现有 exporter，配色自然跟随 | 0（自动） |
| Dock/面板布局 | `uxctl` profile + `layout save fluent-dock` | 0.5 h |
| 字体 Inter | `fonts.packages` + fontconfig 规则 | 0.5 h |
| 验证 | 截图对比 + 对比度脚本 + `uxctl verify` | 0.5 h |

合计 **约 1 天**可出第一版（配色 + 圆角 + 居中 Dock + 字体）。

## 六、风险与注意

| 风险 | 说明 |
|---|---|
| 版权 | Segoe 字体、Fluent 图标集不可随意分发；配色本身无版权问题 |
| Mica 幻觉 | 不要承诺"和 Win11 一样的毛玻璃"，`is_frosted` 实测不可见 |
| 结构差异 | 用户预期"开始菜单"时，COSMIC launcher 是搜索列表，需提前说明 |
| 主题覆盖范围 | 改 `CosmicTheme.Dark/v1/*` 是**全局覆盖内置主题**，切回原样需备份 |
| 8 套主题共存 | 新主题作为第 9 套加入 `themes/`，`order` 排最后 |

## 七、结论

**可以做，但要重新定义"像 Win11"的含义**：

- 如果"像"指**配色/圆角/表面层级/居中任务栏** → 可以达到 80%，一天完工
- 如果"像"指**Mica 毛玻璃 + Snap Layouts + 开始菜单钉板** → 做不到，属于 toolkit 层能力

建议按"Fluent 配色 + 居中胶囊 Dock + Inter 字体"来做，
并在文档里明确标注"Mica/Snap/钉板"为不可得，避免后续返工。
