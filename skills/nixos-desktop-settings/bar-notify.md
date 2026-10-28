# bar-notify：Noctalia 状态栏、通知与 OSD

## 现状：全部在 Noctalia 里

| 能力 | 组件 | 配置位置 |
|---|---|---|
| 状态栏 | Noctalia bar（三层：left / center / right） | `~/.config/noctalia/settings.json` → `bar.widgets` |
| 通知 | Noctalia 原生 + `NotificationHistory` 组件 | 同上 `notifications` |
| OSD | Noctalia（音量/亮度） | 由 IPC 触发，无需配置 |
| 启动器 | Noctalia `launcher` | `Mod+D` |
| 控制中心 / 会话菜单 / 设置 | Noctalia 面板 | `Mod+Shift+C` / `P` / `S` |

以下组件**已随 Hyprland 退役删除，不要再引用**：
`waybar`、`mako`、`swaync`/`swaync-client`、`swayosd`、`eww`、`hyprshell`、`lib/waybar.nix`。

## 改状态栏

两种入口，效果相同：

1. GUI：`Mod+Shift+S` → 侧栏 **Bar** → Widgets
2. 直接改 `~/.config/noctalia/settings.json`（**运行时状态，不进仓库，重装回默认**）

```json
"bar": { "widgets": { "left": [...], "center": [...], "right": [...] } }
```

每个元素是对象，`id` 决定类型。可用类型（4.7.6 实测）：

```
ActiveWindow AudioVisualizer Battery Bluetooth Brightness Clock ControlCenter
CustomButton DarkMode KeepAwake KeyboardLayout Launcher LockKeys MediaMini
Microphone Network NightLight NoctaliaPerformance NotificationHistory
PowerProfile SessionMenu Settings Spacer SystemMonitor Taskbar Tray Volume VPN
WallpaperSelector Workspace
```

## CustomButton：把任意脚本搬上栏

字段（`widgetSettings` 优先，缺省取 `widgetMetadata`）：

| 字段 | 作用 |
|---|---|
| `textCommand` | 定期执行的命令 |
| `parseJson` | `true` 时解析 stdout 为 JSON，取 `text` / `tooltip` |
| `textIntervalMs` | 轮询间隔（默认 3000） |
| `textStream` | 长驻流模式（配合 `parseJson` 用增量输出） |
| `showTextTooltip` | 是否把解析出的 `tooltip` 作为悬浮提示 |
| `generalTooltipText` | 静态提示文本（非空则总是显示） |
| `leftClickExec` / `rightClickExec` / `middleClickExec` | 点击动作 |
| `showIcon` / `icon` / `iconPosition` | 图标显示与位置 |

**tooltip 的坑**：只有 `parseJson: true` 时组件才会拿到 `tooltip` 字段。
用 `textCommand: "xxx --text"` + `parseJson: false` 的话，`_dynamicTooltip` 恒为空，
`showExecTooltip` 又因没有 `*ClickExec` 而无内容 → **鼠标移上去什么都不弹**。

现网示例（agent 用量）：

```json
{ "id": "CustomButton", "showIcon": false,
  "textCommand": "agent-usage", "parseJson": true,
  "textIntervalMs": 60000, "showTextTooltip": true }
```

`agent-usage` 输出 `{"text": "1278.4k", "tooltip": "今日 output 用量…"}`，正好对应。

## SystemMonitor：一个组件多个胶囊、共用一个 tooltip

`SystemMonitor` 在 `compactMode` 下把每个开启的指标画成一个胶囊：
`showCpuUsage` / `showCpuTemp` / `showMemoryUsage` / `showDiskUsage` …

**所有胶囊共用一个 `tooltipArea`**，`buildTooltipContent()` 一次性拼出全部指标
（CPU、温度、GPU、负载、内存、Swap、网络），与悬停哪一个胶囊无关，
且**会包含已被 `showXxx=false` 关掉的指标**。

所以「两个胶囊弹出一模一样的内容」是这个实现决定的，不是配置错。
要避免困惑就只保留一个指标：`showMemoryUsage: false` + `showCpuTemp: false`。

## 通知与勿扰

- 通知由 Noctalia 直接接管（不需要额外 daemon）；历史在 `NotificationHistory` 组件里
- 勿扰：`noctalia-shell ipc call notifications toggleDND`（另有 `enableDND` / `disableDND`）
- **`notif-dnd` 脚本已从 swaync-client 改为上面的 IPC**（swaync 已删除）
- 通知超时/紧急常驻在 `settings.json` 的 `notifications`（`low/normal/criticalUrgencyDuration`）

## OSD

OSD 是 Noctalia 的副作用，没有独立进程：

```bash
noctalia-shell ipc call volume increase      # 音量 +，同时弹 OSD
noctalia-shell ipc call brightness decrease  # 亮度 −，同时弹 OSD
```

直接调 `wpctl` / `brightnessctl` **不会**有 OSD —— 媒体键必须走 IPC（见 `niri.md`）。

## 排查

```bash
noctalia-shell ipc show          # 当前可用的 IPC target 与函数
niri msg layers | grep noctalia  # bar / 通知图层是否创建
tail -f ~/.cache/noctalia-shell.log
```
