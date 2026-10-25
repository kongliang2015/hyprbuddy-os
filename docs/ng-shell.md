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

## socat 方案排查结论（2026-10-25）

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
