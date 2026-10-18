# 快捷键

主修饰键 `$mainMod = SUPER`（Windows 键）。

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
