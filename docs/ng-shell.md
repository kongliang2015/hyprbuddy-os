# NG 外壳方案（swaync + eww + hyprshell）

> 同类项目与可借鉴功能见 [ng-shell-benchmark.md](ng-shell-benchmark.md)。

分支：`distro/v0-ng`。目标：在不替换 waybar 的前提下，补齐 waybar 结构上做不到的
交互能力（通知中心、控制中心、就地弹窗、窗口总览）。

## 组件分工

| 组件 | 职责 | 状态 |
|---|---|---|
| **swaync** | 通知守护 + 通知中心 + 控制中心（MPRIS/音量/亮度/DND） | 已接入，替代 mako |
| **eww** | 自绘弹窗：日历、会话面板 | 已接入 |
| **hyprshell** | 窗口总览（Super + 反引号 grave） / Alt-Tab 缩略图切换 | 已接入，依赖 Lua 配置管理器 |
| waybar | 状态栏 | 保留不动 |
| mako | — | **退役**（与 swaync 抢 DBus 通知名） |
| swayosd | 音量/亮度 OSD | 保留（避免与 swaync 控制中心双弹窗） |

## 使用与验证（当前状态）

| 键位 | 功能 |
|---|---|
| `Super+N` | swaync 通知中心 |
| `Super+C` | eww 日历（跟随焦点显示器） |
| `Super+Shift+E` | eww 会话面板 |
| `Super` + `` ` `` (grave) | hyprshell 窗口总览 |
| `Alt+Tab` | hyprshell 窗口切换 |

环境要求：`home/uwsm/env` 里把 `HYPRLAND_CONFIG` 指向 `hyprland.lua`；
`hyprctl systeminfo` 应显示 `configProvider: lua`（hyprshell 的 `eval` 键位注册只在
Lua 管理器下可用）。

```bash
hypr-check                        # 8 组自检（含外壳组件、Lua 配置、规则计数）
hyprctl binds -j | jq length      # 期望 64 = 56 基础键位 + hyprshell 注册
```

回退：删掉 `~/.config/uwsm/env` 后重新登录，即回到经典 `hyprland.conf`
（hyprshell 热键随之失效，其余组件不受影响）。

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

## 历史：hyprshell 曾因配置模式无法注册键位

> 本节是排查记录。结论已被后文《方案 A 实施：Hyprland 迁移到 Lua 配置管理器》解决，
> 现在键位能正常注册，留档供以后排查同类问题。

当时的实测结论（4.10.4 + Hyprland 0.55.4，经典 `hyprland.conf`）：

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

## 历史：socat 方案排查结论（2026-10-25）

> 结论：socat 不是可用的控制面。后来改用方案 A（Lua 配置管理器）后，热键由
> hyprshell 自己注册，不再需要 socat。本节留作协议记录。

进一步调试后确认：**socat 不是可用的控制面，这条路走不通**。

1. **daemon 处于降级状态**：启动日志末尾是
   ```
   WARN Failed to configure wm: Failed to apply binds
   ... eval is only supported with the lua config manager
   Failed to register: 已到超时限制
   ```
   也就是说键位注册失败后它一直在重试并超时，overview/switch 的"打开"路径
   从未被完整初始化——这解释了为什么下面即使命令被接收也没有窗口。

2. **协议细节**（从报错反推，无文档）：
   - `OpenOverview`：unit 变体，`hyprshell socat '"OpenOverview"'` 可被接收
   - `OpenSwitch`：newtype 变体，需要结构体，至少 `{"reverse": bool}`
   - `CloseSwitch`、`Reload`：unit 变体
   - **传错字段会让 daemon 直接退出**（实测 `{"direction":"next"}` 触发
     `missing field reverse` 后进程消失），对绑定脚本非常不友好

3. **即便收到命令也没有窗口**：`hyprctl clients` / `layers` 都没有新表面，
   说明渲染路径依赖前面失败的注册流程。

4. 附带坑：包里的 wrapper 把进程名改成了 `.hyprshell-wrap`（和 mako 的
   `.mako-wrapped` 同一套路），`pkill -x hyprshell` 杀不掉，得按包装名杀。

**结论与选项**

| 选项 | 说明 | 代价 |
|---|---|---|
| A 迁到 Hyprland **Lua 配置管理器** | hyprshell 才能用它要的 `eval` dispatcher 注册键位 | 需要重写 `hyprland.conf`（55 条 bind + 全部配置项），影响面大 |
| B 放弃 hyprshell | 窗口切换继续用 `hypr-menu` / waybar 工作区模块；总览需求改用 Hyprland 自带方案 | 没有缩略图总览 |
| C 等上游 | 关注 hyprshell 是否支持经典 conf 注册 | 不确定 |

当前建议 **B**：`home/hyprshell/` 的配置保留为备料，等真的决定迁 Lua 时直接可用。

## 踩坑记录：GTK CSS 语法错误会丢整份样式

现象：通知卡片变成 Adwaita 默认样式（#1C1E1F 底、方角、无强调色），
尺寸 366×105（单条通知卡在 swaync 380×1402 的通知窗口内，尺寸本身正常）。

原因：`theme-next` 最初把主题色直接拼进 `rgba()`，而主题表里的颜色是**不带 # 的**
十六进制串：

```css
@define-color border rgba(02F0FA, 0.28);   /* ✗ 'F0FA' is not a valid unit */
```

GTK4 CSS 解析失败时会**丢弃整份用户样式表**（不是跳过那一行），于是 swaync 退回
自带默认样式，看起来"完全没跟主题走"。

修复：GTK 用 `alpha(#02F0FA, 0.28)`，SCSS（eww）用 `rgba(#02f0fa, 0.28)`。

排查时要看 swaync 启动日志里的 `Theme parser error`，这是唯一的提示。
另外 `swaync` 的进程名是 `.swaync-wrapped`，重启脚本要用这个名字或 `pkill -f` 小心自杀。

## 多显示器与关闭方式

- **多显示器**：`defwindow` 的 `:monitor` 只能在定义时写死，会固定弹在主屏。
  改为调用 `scripts/eww-popup <calendar|session>`：它从 `hyprctl monitors` 取当前
  聚焦显示器，再用 `eww open --toggle --screen <连接器名>` 打开。键位与 hypr-menu 都走它。
- **关闭方式**：eww 0.6 的窗口没有键盘事件支持（二进制里没有 `onkey` 相关符号），
  Esc / 点击外部都关不掉，所以两个弹窗都放了按钮：日历「关闭」、会话「取消」。
- **音量控件**：swaync 的 `volume` widget 加载正常（日志有 `Loading widget: volume`），
  它走闭包内的 libpulse 直连 PipeWire-pulse，不依赖 `pactl`/`pamixer`（系统里都没装）。

## 方案 A 实施：Hyprland 迁移到 Lua 配置管理器

**为什么需要**：hyprshell 用 `eval` dispatcher 自注册热键，而 eval 只在 Lua 配置
管理器下存在（经典 hyprlang 会报 `Could not bind key: eval is only supported with the
lua config manager`）。

**怎么切换**（关键点，实测得出）：光放一个 `hyprland.lua` **不够** —— Hyprland 默认
仍走 hyprlang（`hyprctl systeminfo` 显示 `configProvider: hyprlang`）。必须用
`HYPRLAND_CONFIG` 指向 .lua，才会加载 Lua 管理器：

```bash
export HYPRLAND_CONFIG="$HOME/.config/hypr/hyprland.lua"   # 见 home/uwsm/env
```

所以仓库里：`home/hypr/hyprland.lua`（完整移植）+ `home/hypr/extra.lua`（原
extra.conf 的 Lua 版，由 hyprland.lua `dofile`）+ `home/uwsm/env`（设置环境变量）。
当前会话仍是 hyprlang（环境变量只在会话启动时生效），**需要注销重登**才切过去。

**移植时的 API 差异（踩过的）**
| 经典写法 | Lua 写法 |
|---|---|
| `bezier = name, x1,y1,x2,y2` | `hl.curve("name", { type="bezier", points={{x1,y1},{x2,y2}} })`（位置参数，不是表） |
| `bind = MOD, K, exec, CMD` | `hl.bind(MOD .. " + K", hl.dsp.exec_cmd("CMD"))` |
| `bind = MOD, K, fullscreen` | `hl.dsp.exec_cmd("hyprctl dispatch fullscreen 0")`（Lua 侧暂无对应 dsp） |
| `windowrule = match:class ^x$, float true` | `hl.window_rule({ name="x", match={class="^x$"}, float=true })` |
| `source = extra.conf` | `pcall(dofile, "$HOME/.config/hypr/extra.lua")` |

**验证方式（不用注销）**：用嵌套 Hyprland 跑一遍：
```bash
WLR_BACKENDS=wayland WLR_WL_OUTPUTS=1 Hyprland -c ~/.config/hypr/hyprland.lua
```
日志里 `[cfg] Config is lua, loading lua mgr` 表示加载成功，任何 `Lua error` 都会
逐行指出位置——迁移就是靠这个循环修完的。

**风险与回退**：注销重登后若 Lua 配置有问题，会表现为键位/外观缺失。回退只需删掉
`~/.config/uwsm/env`（或注释掉 `HYPRLAND_CONFIG`）再登录，即回到 hyprland.conf。

## 重登后实测：三个报错与修复

重登后 configProvider 变成 lua，hyprshell 的 Super+grave（Open Overview）与 Alt+Tab 成功注册。
但暴露了三处问题：

### 1. 顶部红条：keyword can't work with non-legacy parsers. Use eval.

来源：theme-next 用 `hyprctl keyword general:col.active_border` 改边框色。
Lua 配置管理器下 keyword 整体不可用，Hyprland 把失败写进 seterror，于是屏幕顶部出现
红条（截图 862x56）。

修复：provider 为 lua 时改为写 `~/.config/hypr/theme.lua` 再 `hyprctl reload`；
`hyprland.lua` 里用 `pcall(dofile, ...theme.lua)` 加载。经典 hyprlang 仍走 keyword。

### 2. hyprctl reload 会清空所有 bind

hyprshell 只在启动时注册热键（eval dispatcher），reload 后不会自动重注册，表现为
切主题后 Super+grave / Alt+Tab 失效（binds 从 64 掉回 56）。

修复：theme-next 在 lua 分支 reload 之后重启 hyprshell daemon：

```bash
pkill -x .hyprshell-wrap; sleep 0.3; setsid hyprshell run &
```

### 3. Lua 配置的两个字段陷阱

| 现象 | 正确写法 |
|---|---|
| unknown config key 'input.touchpad.tap-to-click' | `tap_to_click = true`（Lua 里用下划线） |
| Scale factor must be less than 15 and greater than 0 | scale 取 (0,15) 开区间，最后定 10.0 |

### 当前状态

```
configProvider: lua
binds: 64（含 Super+grave overview、Alt+Tab switch）
overview 窗口: 568x378（1 个工作区，尺寸由内容驱动）
configerrors: 空
```
