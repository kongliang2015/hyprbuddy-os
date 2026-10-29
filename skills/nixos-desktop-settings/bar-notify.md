# bar-notify：Noctalia v5 状态栏、通知与 OSD

## 现状：全部在 Noctalia 里

| 能力 | 入口 | 配置位置 |
|---|---|---|
| 状态栏 | Noctalia bar | GUI `Mod+Shift+S` → Bar；或 `~/.config/noctalia/*.toml` 的 `[bar.*]` |
| 通知 | Noctalia 原生（接管 org.freedesktop.Notifications） | GUI → Notifications |
| OSD | Noctalia（音量/亮度） | 由 `msg` 触发，无需配置 |
| 启动器 | Noctalia panel `launcher` | `Mod+D` |
| 控制中心 / 会话 / 设置 | Noctalia panel | `Mod+Shift+C` / `P` / `S` |

以下组件**已随 Hyprland 退役删除，不要再引用**：
`waybar`、`mako`、`swaync`/`swaync-client`、`swayosd`、`eww`、`hyprshell`、`lib/waybar.nix`。

## v5 的配置分层（重要）

- 手写：`~/.config/noctalia/*.toml`（按文件名排序合并，支持 `[include]`）
- GUI 运行时：`~/.local/state/noctalia/settings.toml`，**优先级更高**

GUI 里改完发现手写配置「不生效」，先看 state 文件。仓库只维护手写基线，
GUI 改动属于本机运行态，不进仓库。

## IPC 命令（`noctalia msg <cmd>`）

| 场景 | 命令 |
|---|---|
| 启动器 | `panel-toggle launcher` |
| 控制中心 | `panel-toggle control-center` |
| 会话面板 | `panel-toggle session`；直接执行用 `session lock` / `session logout` 等 |
| 设置 | `settings-toggle` |
| 音量 | `volume-up` / `volume-down` / `volume-mute` / `volume-osd <v>` |
| 麦克风 | `mic-mute` / `mic-volume-up` / `mic-volume-down` |
| 亮度 | `brightness-up` / `brightness-down`（无背光设备会返回 error） |
| 夜间模式 | `nightlight-toggle` |
| 勿扰 | `notification-dnd-toggle`（查询 `notification-dnd-status`） |
| 壁纸 | `wallpaper-set <绝对路径>` / `wallpaper-next` / `wallpaper-get` |
| 配色 | `color-scheme-get` / `color-scheme-set <builtin|wallpaper|community|custom> <name>` |
| 明暗 | `theme-mode-toggle` / `theme-mode-set dark|light` |
| 状态 | `status`（JSON：barVisible / panelOpen / locked） |

全部命令：`noctalia msg --help`。

## 通知与勿扰

- 通知由 Noctalia 直接接管，不需要额外 daemon
- `notif-dnd` 脚本走 `noctalia msg notification-dnd-toggle`
- 通知历史在 GUI 的通知面板里

## OSD

OSD 是 Noctalia 的副作用，没有独立进程：

```bash
noctalia msg volume-up       # 音量 +，同时弹 OSD
noctalia msg brightness-down # 亮度 −，同时弹 OSD
```

直接调 `wpctl` / `brightnessctl` **不会**有 OSD —— 媒体键必须走 `msg`（见 `niri.md`）。

## v4 遗留（已失效，勿照抄）

v4 `settings.json` 里的 `bar.widgets.left/center/right`、`CustomButton.textCommand`、
`SystemMonitor.showCpuUsage` 等字段在 v5 中已不存在。v5 的 bar/widget 结构与
组件清单见 GUI 与 `https://docs.noctalia.dev/noctalia/bar/`。

## 排查

```bash
noctalia msg status              # bar 是否创建
noctalia msg --help              # 全部命令
tail -f ~/.cache/noctalia/noctalia.log
niri msg layers                  # 外壳图层是否在
```
