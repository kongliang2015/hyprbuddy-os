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

## hyprshell：已备好配置，但键位注册被 Hyprland 配置模式卡住

实测结论（4.10.4 + Hyprland 0.55.4，经典 `hyprland.conf`）：

1. `hyprshell config generate` 需要图形界面，我已跑过一次，产出
   `home/hyprshell/config.ron`（已精修：overview = Super+`，switch = Alt+Tab），
   `hyprshell config check` 校验通过。
2. daemon 能起来，但**键位注册失败**：
   ```
   WARN Failed to configure wm: Failed to apply binds
   Could not bind key: eval is only supported with the lua config manager, could not load config
   ```
   → hyprshell 用 `eval` dispatcher 注册 overview/switch 热键，只在 Hyprland 的
   **Lua 配置管理器**下可用；本仓库用的是经典 conf，绑不上。
3. 手动触发协议已摸清（`hyprshell socat <JSON>`，变体为
   `OpenOverview` / `OpenSwitch` / `CloseSwitch` / `Reload`）：
   ```bash
   hyprshell socat '"OpenOverview"'
   ```
   但当前测试下发送后没有出现窗口（`hyprctl clients/layers` 均无新表面），
   推测与 GTK4 窗口创建或 config 里的 `top_offset/scale` 有关，需进一步调试。

**解锁路径（二选一）**

- A：把 Hyprland 迁到 Lua 配置管理器，hyprshell 自动注册键位（改动大，影响全仓 conf）
- B：继续排查 `socat '"OpenOverview"'` 无窗口的原因，搞通后手写绑定：
  `bind = $mainMod, grave, exec, hyprshell socat '"OpenOverview"'`

在此之前 `home/hyprshell/` 里的两份配置只是**备料**，没有接进 `home/default.nix`，
也不会有 `exec-once`。
