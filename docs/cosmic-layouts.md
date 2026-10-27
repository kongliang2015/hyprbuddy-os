# COSMIC 布局模板（可参考的 UX 模板）

来源：`cosmic-initial-setup 1.2.0` 自带，安装到
`/run/current-system/sw/share/cosmic-layouts/`。
当前只有 **2 个**官方模板，但结构清晰、可直接复用。

## 一、模板格式

每个模板是一个目录：

```
<id>/
  layout.kdl                          # id + 多语言名称
  icon.png                            # 缩略图
  com.system76.CosmicPanel/v1/entries # ["Panel", "Dock"]
  com.system76.CosmicPanel.Panel/v1/<key>
  com.system76.CosmicPanel.Dock/v1/<key>
```

`layout.kdl` 示例：

```kdl
id 0
name en="Top Panel & Bottom Dock"
name cs="Horní panel a dolní dok"
```

也就是说：**模板 = 一棵可以整目录覆盖到 `~/.config/cosmic/` 的配置子树**，
和 `uxctl` 的目标结构完全一致。

## 二、模板 A：Bottom Panel（id 1）

单个底部面板，**无 Dock**。

```
entries            = [ "Panel" ]
anchor             = Bottom
autohide           = None
border_radius      = 0
exclusive_zone     = false        # ← 与 Dock 不同：不挤压窗口
expand_to_edges    = true
margin / padding   = 0 / 0
opacity            = 1.0
size               = M
plugins_center     = Some([])
plugins_wings      = Some((
    [ CosmicPanelLauncherButton, CosmicPanelWorkspacesButton,
      CosmicPanelAppButton, CosmicAppList, CosmicAppletMinimize ],
    [ CosmicAppletInputSources, CosmicAppletStatusArea, CosmicAppletA11y,
      CosmicAppletTiling, CosmicAppletAudio, CosmicAppletBluetooth,
      CosmicAppletNetwork, CosmicAppletBattery, CosmicAppletNotifications,
      CosmicAppletTime, CosmicAppletPower ]
))
```

**参考价值**：这是任务栏式布局——开始菜单 + 窗口列表 + 最小化都在左侧，
系统托盘挤在右侧，`exclusive_zone=false` 让面板浮在窗口上而不是挤压。

## 三、模板 B：Top Panel & Bottom Dock（id 0）

顶栏 + 底部 Dock，**当前系统的默认形态**。

### 顶栏

```
anchor          = Top
size            = XS
border_radius   = 0
exclusive_zone  = true
padding         = 0
plugins_center  = Some([ CosmicAppletTime ])      # 时钟居中
plugins_wings   = Some((
    [ CosmicPanelWorkspacesButton, CosmicPanelAppButton ],
    [ InputSources, StatusArea, A11y, Tiling, Audio, Bluetooth,
      Network, Battery, Notifications, Power ]
))
```

### Dock

```
anchor          = Bottom
size            = L
border_radius   = 160        # ← 胶囊形（半高）
expand_to_edges = false      # 不拉满宽度
margin          = 4
padding         = 4
exclusive_zone  = true
plugins_center  = Some([ LauncherButton, WorkspacesButton, AppButton,
                         CosmicAppList, CosmicAppletMinimize ])
plugins_wings   = Some(( [], [] ))
```

**参考价值**：
- 顶栏 `size=XS` + `border_radius=0` = 极简细条
- Dock `border_radius=160` + `expand_to_edges=false` = **胶囊 Dock**（视觉重点）
- Dock 的两个 wing 都是空列表，靠 `plugins_center` 居中排列

## 四、与当前系统的差异

| 键 | 模板 B | 本机当前 | 说明 |
|---|---|---|---|
| dock.border_radius | 160 | **8** | 当前是直角 Dock，模板是胶囊 |
| 其余 panel/dock 键 | — | 与模板一致 | 当前配置是模板 B 的微调 |

## 五、如何复用

### 已可用（本次新增）

```bash
uxctl layout                # 列出系统模板 + 各命名空间键数
uxctl layout --json         # 含完整键值，可直接转 profile
```

### 已实现（U2，2026-10-27）

```bash
uxctl layout apply bottom-panel                # 整树铺到 ~/.config/cosmic（默认 dry-run）
uxctl layout apply bottom-panel --yes          # 真正写入（带快照 + 写后校验 + 自动回滚）
uxctl layout save leonard-current              # 把当前配置存成用户模板
```

- `apply` 不套用 12 键预算（模板本身就是全量重置，属于显式操作），但**必须 `--yes`**
- 与 `apply` 共用快照/校验/回滚链路
- 用户模板写到 `~/.local/share/cosmic-layouts/<name>/`，`layout` 列表里标 `[用户]`
- `save` 目前不生成 `icon.png`（COSMIC 设置页会显示无缩略图）

实现要点：模板树的键名与 `uxctl` 的 schema 完全重叠（21 键 × 命名空间），
所以 `layout apply` 可以直接走 `apply` 的快照 + 校验 + 回滚链路，
只是把「profile JSON」换成「读模板树」。

## 六、还能从哪找模板

| 来源 | 内容 | 说明 |
|---|---|---|
| `/share/cosmic-layouts` | **只有 2 个**官方布局 | 本文档已完整记录 |
| `/share/cosmic-themes/` | 4 套主题（mocha/cream/comet/nebula） | 只管配色，不含布局 |
| cosmic-themes.org | 社区主题（配色） | 同上 |
| Pop!_OS 安装镜像 | 发行版默认布局 | 需解包 iso 才能拿到 |
| 自建 | `uxctl layout save` | U2 提供 |

**结论**：布局类模板官方只给了 2 个，且都是顶栏/底栏形态；
想要第三种（例如左侧竖栏、双 Dock）需要自己写模板——这正是 `uxctl layout save` 的价值。

## 七、关键洞察

1. **模板是完整键树**，不是补丁——应用模板等于重置面板配置（可预测，但会覆盖用户微调）
2. **`plugins_wings` 是元组**（左翼/右翼），`plugins_center` 是单列表；Wings 可以是 `Some(([], []))`
3. **`exclusive_zone`** 决定面板是挤压窗口还是浮在上面，这是两种布局观感的分水岭
4. **`border_radius=160`** 是胶囊 Dock 的关键（配合 `expand_to_edges=false` + `margin/padding`）
