# 快捷键

主修饰键 `SUPER`（Windows 键）。

> **v1-nn 起只有 niri 提供方**（Hyprland / COSMIC 已退役）。
> 当前生效的键位在 `home/niri/config.kdl`，速查见文末「niri 当前键位」；
> 中间的表格是 Hyprland 时代的历史对照。

## 启动 / 窗口

| 快捷键 | 动作 |
|---|---|
| `Super+Return` | 终端 kitty |
| `Super+D` | 应用启动器 fuzzel |
| `Super+Space` | 系统菜单（hypr-menu） |
| `Super+B` | 浏览器 firefox |
| `Super+E` | 文件管理器 thunar |
| `Super+Q` | 关闭当前窗口 |
| `Super+M` | 注销（退出 Hyprland → SDDM） |
| `Super+L` | 锁屏（hyprlock） |
| `Super+F` | 全屏 |
| `Super+T` | 切换浮动 |
| `Super+P` | 伪平铺（pseudo） |
| `Super+J` | 切换分屏方向 |
| `Super+Shift+R` | 重载 Hyprland 配置 |

## 焦点 / 移动 / 缩放

| 快捷键 | 动作 |
|---|---|
| `Super+方向键` | 移动焦点 |
| `Super+Shift+方向键` | 移动窗口 |
| `Super+Alt+方向键` | 调整窗口大小 |
| `Super+鼠标左键拖拽` | 移动窗口 |
| `Super+鼠标右键拖拽` | 调整窗口大小 |

## 工作区

| 快捷键 | 动作 |
|---|---|
| `Super+1..0` | 切换到工作区 1–10 |
| `Super+Shift+1..0` | 把窗口移动到工作区 1–10 |
| `Super+S` | 切换 scratchpad 临时工作区 |
| `Super+Shift+S` | 把窗口移入 scratchpad |

## 截图 / 工具

| 快捷键 | 动作 |
|---|---|
| `Print` | 区域截图（hyprshot，存 `~/Pictures/Screenshots` + 剪贴板） |
| `Shift+Print` | 整屏截图 |
| `Super+Shift+A` | 区域截图并标注（swappy） |
| `Super+Shift+C` | 屏幕取色（hyprpicker，自动复制） |
| `Super+V` | 剪贴板历史（cliphist + fuzzel） |
| `Super+Shift+N` | 夜间模式开关（4000K） |
| `Super+Shift+P` | 开始/停止录屏（保存到 `~/Videos`） |
| `Super+Shift+W` | 下一张壁纸 |

## 音量 / 亮度 / 媒体

| 快捷键 | 动作 |
|---|---|
| `XF86AudioRaiseVolume` / `Lower` | 音量 ±（SwayOSD 屏显） |
| `XF86AudioMute` | 静音切换 |
| `XF86MonBrightnessUp` / `Down` | 亮度 ±（SwayOSD 屏显） |
| `XF86AudioPlay` | 播放/暂停（playerctl） |
| `XF86AudioNext` / `Prev` | 上一曲/下一曲 |

## 系统菜单（`Super+Space`）

分组菜单，支持多级返回：每个非根菜单都有「← 返回上级菜单」，`Esc` 返回上一级；根菜单有「✕ 退出菜单」。

```
主菜单
├── 应用        → 应用启动器 / 终端 / 文件管理器 / 浏览器 / btop
├── 系统工具
│   └── 截图    → 区域截图 / 整屏截图 / 截图标注
│   取色器 / 剪贴板历史 / 开始停止录屏
├── 外观        → 夜间模式 / 下一张壁纸 / 重载壁纸 / 重载 Hyprland
├── 会话        → 锁屏 / 勿扰开关 / 注销 / 重启 / 关机
└── 快捷键参考  → 动态读取 hyprctl binds，浮动窗口显示全部快捷键及中文说明
```

---

## COSMIC 桌面（默认键位）

> **已退役（v1-nn 分支）**：COSMIC 已移除，本节保留为历史对照。niri 键位见
> `home/niri/config.kdl`（Mod+D launcher / Mod+L 锁屏 / Print 截图等）。

COSMIC 的键位不写在仓库里，来源是 cosmic-comp 自带的默认表：

```
# 默认值（随包分发，只读）
/nix/store/*-cosmic-comp-1.2.0/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1/defaults
# 用户覆盖（当前不存在 → 用默认）
~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/
```

格式是 RON，形如 `(modifiers: [Super], key: "q"): Close`，可用声明式部署（见 P3）。

### 系统

| 快捷键 | 动作 |
|---|---|
| `Super`（单按） | 打开启动器 |
| `Super+/` | 打开启动器 |
| `Super+Esc` | 锁屏 |
| `Super+Shift+Esc` | 注销 |
| `Super+Alt+Esc` | 终止当前会话 |
| `Super+Ctrl+Esc` | 调试信息 |
| `Super+Space` | **输入法切换**（不是启动器） |
| `Print` | 截图 |

### 窗口管理

| 快捷键 | 动作 |
|---|---|
| `Super+Q` / `Alt+F4` | 关闭窗口 |
| `Super+M` | 最大化 |
| `Super+F11` | 全屏 |
| `Super+G` | 切换浮动 |
| `Super+X` | 交换窗口 |
| `Super+Y` | 切换平铺 |
| `Super+S` | 切换堆叠 |
| `Super+O` | 切换排列方向 |
| `Super+R` / `Super+Shift+R` | 调整大小（外扩 / 内收） |
| `Super+方向` 或 `Super+hjkl` | 焦点移动 |
| `Super+Shift+方向` 或 `Super+Shift+hjkl` | 移动窗口 |
| `Super+U` / `Super+I` | 焦点出 / 入（层级） |

### 工作区

| 快捷键 | 动作 |
|---|---|
| `Super+1…9` | 切换工作区 |
| `Super+0` | 上一个工作区 |
| `Super+Shift+1…9` | 窗口移到工作区 |
| `Super+Shift+0` | 窗口移到上一个工作区 |
| `Super+Ctrl+方向/hjkl` | 上 / 下一个工作区 |
| `Super+Shift+Ctrl+方向/hjkl` | 窗口移到上 / 下一个工作区 |

### 显示器

| 快捷键 | 动作 |
|---|---|
| `Super+Alt+方向/hjkl` | 焦点切到另一显示器 |
| `Super+Shift+Alt+方向/hjkl` | 窗口移到另一显示器 |

### 应用与切换

| 快捷键 | 动作 |
|---|---|
| `Super+W` | 工作区总览（WorkspaceOverview） |
| `Super+A` | 应用库 |
| `Super+T` | 终端 cosmic-term |
| `Super+F` | 文件管理器 |
| `Super+B` | 浏览器 |
| `Super+Tab` / `Alt+Tab` | 窗口切换 |
| `Super+Shift+Tab` / `Shift+Alt+Tab` | 反向切换 |
| `Super+=` / `Super+-`、`Super+.` / `Super+,` | 缩放放大 / 缩小 |
| XF86 多媒体键 | 音量 / 亮度 / 播放 / 电源 / 触摸板 |

### 与 Hyprland 的差异（切桌面注意）

| 快捷键 | Hyprland（本仓库） | COSMIC 默认 | 处理建议 |
|---|---|---|---|
| `Super+T` | 切换浮动 | **打开终端** | 冲突：COSMIC 下浮动改用 `Super+G` |
| `Super+F` | 全屏 | **打开文件管理器** | 冲突：COSMIC 下全屏改用 `Super+F11` |
| `Super+Space` | 系统菜单 | **输入法切换** | 不要覆盖，否则中文输入法无法切换 |
| `Super+S` | 特殊工作区 | 切换堆叠 | 语义不同 |
| `Super+Q` | 关闭窗口 | 关闭窗口 | 一致 |
| `Super+1…4` / `Super+Shift+1…4` | 工作区 / 移窗 | 相同 | 一致 |
| `Super+grave` | hyprshell 总览 | 无 | COSMIC 用 `Super+W` |
| `Super+N` | swaync 通知中心 | 无 | 需自建（P3） |
| `Super+C` | eww 日历 | 无 | 需自建（P3） |
| `Super+V` | 剪贴板历史 | 无内置 | 需自建（P3） |

### 结论

1. COSMIC 默认偏「应用启动器」：`T/B/F/A` 全是开应用，与我们的窗口操作冲突最大的是 `Super+T`、`Super+F`。
2. `Super+Space` 已被输入法占用，hypr-menu 在 COSMIC 下应换键（如 `Super+Shift+Space`）。
3. 键位可用 RON 声明式部署，P3 计划用同一份定义生成 Hyprland 绑定与 COSMIC 快捷键，避免两套肌肉记忆。

## niri 当前键位（v1-nn 生效）

| 快捷键 | 动作 |
|---|---|
| `Mod+Return` | kitty |
| `Mod+D` | Noctalia 启动器 |
| `Mod+Space` | fuzzel（dmenu 管道/备用） |
| `Mod+Q` / `Mod+F` | 关窗口 / 全屏 |
| `Mod+Shift+C` | 控制中心 |
| `Mod+Shift+P` | 会话菜单 |
| `Mod+Shift+S` | Noctalia 设置 |
| `Mod+L` | 锁屏（loginctl lock-session → Noctalia 锁屏） |
| `Mod+Shift+T` | 主题选择器 |
| `Mod+V` | 剪贴板历史（cliphist + fuzzel） |
| `Print` / `Mod+Shift+A` | 截图（整屏 / 窗口） |
| `XF86Audio{Raise,Lower}Volume` | 音量 ±5%（wpctl） |
| `XF86AudioMute` / `XF86AudioMicMute` | 静音 / 麦克风静音 |
| `XF86MonBrightness{Up,Down}` | 亮度 ±5%（brightnessctl） |
| `XF86Audio{Play,Next,Prev}` | 播放控制（playerctl） |

> 空闲行为（Noctalia idle）：10 分钟熄屏、11 分钟锁屏、**不自动挂起**。
