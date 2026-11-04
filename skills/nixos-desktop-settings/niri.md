# niri：键位、布局、规则、输出、输入法

源文件：`home/niri/config.kdl` → 部署到 `~/.config/niri/config.kdl`（store 软链，**install.sh 会覆盖**）。
改键位/规则请改仓库，不要直接编辑 `~/.config/niri/config.kdl`。

运行时重载：`niri msg action load-config-file`（niri 也会监视文件变化自动重载）。
校验：`niri validate -c home/niri/config.kdl`。

## 结构

```kdl
spawn-at-startup ...     // 自启（noctalia / wl-paste 等；v5 无需 sleep 2）
input { ... }            // 键盘布局、触摸板
layout { ... }           // gaps、列宽、居中策略
output "eDP-1" { ... }   // 每输出的 scale/mode
binds { ... }            // 键位
window-rule { ... }      // 窗口规则
```

## 键位（当前生效）

| 键 | 动作 |
|---|---|
| `Mod+Return` | kitty |
| `Mod+D` | Noctalia 启动器（`msg panel-toggle launcher`） |
| `Mod+Tab` | 窗口切换器（`msg window-switcher`） |
| `Mod+Q` / `Mod+F` / `Mod+Shift+F` | 关窗 / 全屏 / 浮动 |
| `Mod+Shift+E` | 会话面板（`panel-toggle session`，不再直接 quit） |
| `Mod+方向键` / `Mod+J/K` | 焦点移动 |
| `Mod+Shift+←/→` | 移动列 |
| `Mod+1..9` / `Mod+Shift+1..9` | 切工作区 / 移列到工作区 |
| `Mod+Ctrl+←/→` | 上/下一个工作区（`msg workspace-switch`） |
| `Mod+Ctrl+Shift+←/→` | 把列送到上/下工作区 |
| `Mod+Shift+C` / `P` / `S` | 控制中心 / 会话菜单 / 设置 |
| `Mod+N` | 弹最新通知（`notification-invoke-latest`） |
| `Mod+Shift+D` | 勿扰开关（`notification-dnd-toggle`） |
| `Mod+L` | 锁屏（`msg session lock` → Noctalia 锁屏，PAM 认证） |
| `Mod+V` | 剪贴板历史（`clipboard-menu`） |
| `Mod+Shift+T` | 主题选择器 |
| `Mod+Shift+N` | 夜间模式（`nightlight-toggle`） |
| `Mod+Shift+W` | 下一张壁纸（`wallpaper-next`，需 `[wallpaper] directory`） |
| `Mod+Shift+M` | btop |
| `Mod+Alt+R` | 录屏开始/停止（`record-toggle` → wf-recorder，存 `~/视频`） |
| `Print` / `Shift+Print` | v5 截图 overlay：区域 / 整屏 |
| `Mod+Shift+A` | 区域截图并标注（grim+slurp+swappy） |
| `XF86Audio*` / `XF86MonBrightness*` | 音量/静音/亮度（**必须显式绑定**，niri 不内置硬件键；`allow-when-locked=true`） |

媒体键绑定的写法（走 Noctalia `msg` 才有 OSD）：

```kdl
XF86AudioRaiseVolume allow-when-locked=true { spawn "noctalia" "msg" "volume-up"; }
XF86MonBrightnessUp  allow-when-locked=true { spawn "noctalia" "msg" "brightness-up"; }
```

## 截图落盘（实测 2026-11-04）

| 键 | 命令 | 落盘位置 |
|---|---|---|
| `Print` | `noctalia msg screenshot-region` | `~/图片/screenshot_<时间戳>.png`（XDG 图片目录）+ 剪贴板 `image/png` |
| `Shift+Print` | `noctalia msg screenshot-fullscreen` | 同上 |
| `Mod+Shift+A` | `screenshot-annotate`（grim+slurp+swappy） | 由 swappy 决定（默认 `~/Pictures`） |

要点：

- v5 的截图服务会**同时**保存文件并写入剪贴板，所以 `Print` 之后可以直接粘贴。
- 5.0.1 没有暴露「保存目录」的配置键（`settings.toml` 里没有 screenshot 段），
  目录固定跟随 XDG 图片目录（中文 locale 是 `~/图片`）。要换目录就改
  `~/.config/user-dirs.dirs` 或改用 `Mod+Shift+A` 那条链路。
- 因为截图落在 `~/图片`，**不要**把壁纸目录设成 `~/图片`，否则
  `wallpaper-next` 会把截图当壁纸轮播（我们显式设的是 `~/Pictures/wallpapers`）。
- 区域截图会起一层 overlay 等框选，未选中按 `Escape` 取消。

一次性动作加 `repeat=false`（窗口切换、截图），否则按住会连续弹面板。

## 窗口规则

```kdl
window-rule {
    match app-id=r#"pavucontrol"#;
    open-floating true
}
```

- `match` 支持 `app-id` / `title`，正则用 `r#"..."#`
- 其他常用字段：`open-floating`、`default-column-width`、`open-on-workspace`

## 输出（显示器）

持久化写进 `config.kdl`：

```kdl
output "HDMI-A-1" {
    mode "2560x1440@60"
    scale 1.0
    position x=0 y=0
}
```

临时调整（不重启）：`wlr-randr --output HDMI-A-1 --mode 2560x1440 --scale 1.25`。
Noctalia 4.7.6 没有显示器 GUI，`wlr-randr` 是唯一手段。

## 输入法（fcitx5）

- **不在** `config.kdl` 里 spawn：fcitx5 由 systemd 用户服务 `fcitx5.service` 拉起
- 该服务的 `ExecStart` 是包装脚本，会先等 `WAYLAND_DISPLAY` 进 systemd 环境**且** socket 文件存在，再 exec fcitx5
- 原因：niri 先跑 spawn、约 0.5s 后才建 wayland socket；抢跑会报 `Failed to open wayland connection`，整个会话都输不了中文

## 已知坑

1. **spawn 早于输出就绪**：niri 的 `spawn-at-startup` 在连接显示器之前执行，所以 noctalia 必须 `sleep 2` 再起（见 `spawn-at-startup` 行），否则 bar 永远不创建
2. **`Mod+Space` 已移除**：启动器统一 `Mod+D`；fuzzel 只保留 `--dmenu` 用途（剪贴板菜单）
3. **改 `~/.config/niri/config.kdl` 会被覆盖**：它是 store 软链，必须改仓库再 `install.sh`
