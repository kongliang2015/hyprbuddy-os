# 参考 Cinnamon 设计 COSMIC 布局：可行性评估

结论：**三者之中最容易实现的**。Cinnamon 是"单条底部面板 + 一群 applet"的传统布局，
和 COSMIC 的 panel 模型几乎一一对应，而且它**不依赖模糊**，我们唯一拿不到的能力正好用不上。

## 一、Cinnamon 的构成要素

| # | 要素 | 具体表现 |
|---|---|---|
| 1 | 单条底部面板 | 占满宽度、贴底、默认高度约 40px |
| 2 | 面板三段 | 左：菜单按钮 + 窗口列表；中：工作区切换器；右：系统托盘 + 时钟 |
| 3 | 窗口列表 | 显示运行窗口（图标 + 可选标题），支持分组 |
| 4 | Mint 菜单 | 分类导航 + 收藏 + 搜索的组合菜单 |
| 5 | 平面视觉 | 无模糊、无重阴影，靠色块与描边分层 |
| 6 | 圆角 | 面板默认直角；6.x 起可给窗口/面板加圆角 |
| 7 | 配色 | Mint-Y：绿色强调 `#87B158` / `#3EB34F`，浅灰底 |
| 8 | 字体 | Ubuntu / Noto Sans |

## 二、COSMIC 对应能力（本机 1.2.0 实测）

| Cinnamon 要素 | COSMIC 对应 | 可行性 |
|---|---|---|
| 单条底部面板 | Panel `anchor=Bottom` + `expand_to_edges=true` | ✅ |
| 面板高度 40px | Panel `size=M`（XS/S/M/L 四档） | ✅ |
| 菜单按钮（左） | `com.system76.CosmicPanelLauncherButton` | ✅ |
| **窗口列表（左）** | **`com.system76.CosmicAppList`**（官方 bottom-panel 布局就这么用） | ✅ 结构一致 |
| 工作区切换（中） | `com.system76.CosmicPanelWorkspacesButton` | ✅ |
| 系统托盘（右） | `com.system76.CosmicAppletStatusArea` | ✅ |
| 时钟（右） | `com.system76.CosmicAppletTime` | ✅ |
| 通知/电源 | `CosmicAppletNotifications` / `CosmicAppletPower` | ✅ |
| 平面无模糊 | —— | ✅ **不需要**，天然匹配 |
| 面板直角/圆角 | `border_radius`（0 或 8） | ✅ |
| 绿色强调 | `accent` 改 `#87B158` | ✅ |
| 窗口列表文字标签 | AppList 只显示图标 | △ 无标题文字/分组 |
| 窗口缩略图预览 | —— | ✗ |
| Mint 分类菜单 | cosmic-launcher（搜索优先 + 网格） | △ 结构不同 |
| 面板 applet 悬浮预览 | —— | ✗ |

## 三、三个方案横向对比

| 维度 | Windows 11 | Deepin | **Cinnamon** |
|---|---|---|---|
| 布局可达度 | 70% | 75% | **90%** |
| 是否依赖模糊 | 强依赖（Mica） | 强依赖 | **不依赖** |
| 面板结构匹配 | 居中任务栏（部分） | 底部 Dock（部分） | **单底栏（完全）** |
| 窗口列表 | 无对应 | 无对应 | **AppList 直接对应** |
| 字体成本 | 需 Inter | Noto 已有 | Noto 已有 |
| 主要缺口 | Mica / Snap / 钉板 | 模糊 / 图标放大 | 窗口标题 / 缩略图 / 分类菜单 |

→ **Cinnamon 是三者中性价比最高的**：结构几乎 1:1，且短板恰好是我们拿不到的能力。

## 四、方案：`COSMIC Cinnamon`

### 4.1 面板布局（uxctl profile）

```json
{
  "version": 1,
  "panels": { "entries": ["Panel"] },
  "panel": {
    "anchor": "Bottom",
    "expand_to_edges": true,
    "exclusive_zone": true,
    "border_radius": 0,
    "size": "M",
    "opacity": 1.0,
    "autohide": null,
    "margin": 0,
    "padding": 0,
    "plugins_center": ["com.system76.CosmicPanelWorkspacesButton"],
    "plugins_wings": {
      "left":  ["com.system76.CosmicPanelLauncherButton", "com.system76.CosmicAppList"],
      "right": ["com.system76.CosmicAppletInputSources", "com.system76.CosmicAppletStatusArea",
                "com.system76.CosmicAppletNotifications", "com.system76.CosmicAppletTime",
                "com.system76.CosmicAppletPower"]
    }
  }
}
```

- `expand_to_edges=true` + `exclusive_zone=true` = 占满宽度、挤压窗口（Cinnamon 的行为）
- 不留 Dock，`entries` 只有 `Panel`

### 4.2 配色（Mint-Y 风格）

```json
{ "name": "Mint-Y", "dark": false, "order": 9,
  "bg": "F2F2F2", "surface": "FFFFFF", "fg": "2E3436", "muted": "888A85",
  "accent": "3EB34F", "accent2": "87B158", "urgent": "CC0000" }
```

浅色底 + 绿色强调。若偏好深色 Mint-Y-Dark：`bg=2E3436 / surface=3A3F41 / fg=DEDEDE`。

### 4.3 字体

Noto Sans CJK SC（已有）+ JetBrainsMono（等宽）。Cinnamon 用 Ubuntu 字体，
`fonts.packages` 里没有，若想要可加 `pkgs.ubuntu_font_family`（开放授权）。

## 五、预期效果与差距

**能做到（约 90%）**：底部一条通栏面板、左菜单+窗口图标列表、中工作区、右托盘+时钟、
浅色/绿色 Mint 配色、直角面板、窗口挤压行为。

**做不到（10%）**：
- 窗口列表不显示文字标题，也无法分组折叠
- 没有窗口缩略图悬浮预览
- Mint 菜单的"分类导航栏 + 收藏区"没有等价物（cosmic-launcher 是搜索优先）

## 六、工作量

| 产物 | 工时 |
|---|---|
| `ux/profiles/cinnamon-panel.json` | 0.5 h |
| `themes/mint-y/tokens.json` | 0.5 h |
| 应用 + 截图验证 + 回滚确认 | 0.5 h |
| **合计** | **约 1.5 h** |

## 七、风险

| 风险 | 说明 |
|---|---|
| AppList 语义差异 | 它更接近"固定/运行应用图标"，不是传统窗口任务栏 |
| 浅色主题适配 | 我们的 8 套主题都是深色，浅色 Mint-Y 需要单独验证对比度 |
| 面板高度不可像素级调 | 只有 XS/S/M/L 四档 |
| 与现有布局冲突 | 应用前会快照，可随时 `uxctl snapshot restore` |

## 八、结论

**推荐优先做这一套**：它是三个参考里唯一"结构完全对得上、且不吃我们短板"的方案。
如果要验证，建议顺序：

1. 先只改面板布局（不动主题），看 AppList 在面板里的实际表现
2. 确认窗口列表可用后，再加 Mint-Y 配色
3. 若 AppList 表现不理想，退回"顶栏 + 胶囊 Dock"组合
