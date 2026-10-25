# NG 外壳方案（swaync + eww，hyprshell 待解锁）

分支：`distro/v0-ng`。目标：在不替换 waybar 的前提下，补齐 waybar 结构上做不到的
交互能力（通知中心、控制中心、就地弹窗、窗口总览）。

## 组件分工

| 组件 | 职责 | 状态 |
|---|---|---|
| **swaync** | 通知守护 + 通知中心 + 控制中心（MPRIS/音量/亮度/DND） | 已接入，替代 mako |
| **eww** | 自绘弹窗：日历、会话面板 | 已接入 |
| **hyprshell** | 窗口总览 / Alt-Tab 缩略图 | **暂缓**（见文末） |
| waybar | 状态栏 | 保留不动 |
| mako | — | **退役**（与 swaync 抢 DBus 通知名） |
| swayosd | 音量/亮度 OSD | 保留（避免与 swaync 控制中心双弹窗） |

## 主题联动

`theme-next` 沿用"推导色 + 原子写"模式，新增两个 writer：

| 主题字段 | swaync（GTK4 `@define-color`） | eww（SCSS `$var`） |
|---|---|---|
| WB_BG | `@noti-bg` / `@cc-bg` | `$bg` |
| WB_FG | `@text-color` | `$fg` |
| HA1 | `@accent` | `$accent` |
| HA2 | `@accent-2` | `$accent2` |
| HI | 描边 | `$border` |
| WB_URGENT | critical | `$urgent` |
| WB_PULSE | `@progress` | `$pulse` |

## 交互

| 触发 | 动作 |
|---|---|
| `Super+N` | `swaync-client -t` 切换通知中心 |
| `Super+C` | `eww open calendar`（贴 waybar 下方） |
| waybar clock 点击 | 同上 |
| hypr-menu | 新增「通知中心」「日历」；DND 改走 `swaync-client` |

## 文件

```
home/swaync/config.json     通知中心布局/超时/控件
home/swaync/style.css       基础样式（颜色段由 theme-next 重写）
home/eww/eww.yuck           日历 + 会话面板
home/eww/eww.scss           变量（theme-next 重写）
```

## hyprshell 暂缓原因

`hyprshell config check` 对手写 config.ron 稳定报 `10:19: Expected identifier`，
而 `hyprshell config generate` 需要打开 GUI 编辑器（无头环境下不写文件）。
上游文档的字段（`filter_by_same_class` 等）与 4.10.4 实际 schema（`filter_by` 列表）不一致。

解除阻塞的办法（需人工一步）：在有显示的会话里跑一次
```bash
hyprshell config generate     # 打开编辑器后保存，生成 ~/.config/hyprshell/config.ron
```
把生成的文件贴回 `home/hyprshell/config.ron`，再按本文件的口径接入（`exec-once = hyprshell run`，
键位由 hyprshell 自己在 config 里注册：`overview.key/modifier`、`switch.key/modifier`）。
