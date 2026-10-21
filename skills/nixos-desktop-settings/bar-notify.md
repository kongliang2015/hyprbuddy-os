# bar-notify：waybar、mako、swayosd

## waybar：唯一来源 `lib/waybar.nix`

同一份配置同时用于：
- 系统级 `/etc/xdg/waybar/config|style.css`（`modules/desktop/hyprland.nix` 生成）
- 用户级 `~/.config/waybar/*`（`home/default.nix` 生成，install.sh 软链）

因此**只改 `lib/waybar.nix`**，不要分别改两处。

### 硬约束

- CSS 只能是**具体颜色值**：GTK 不支持 `:root` / `var()`，解析报
  `Invalid name of pseudo-class` 会让 waybar 拒绝启动
- 模块图标依赖 `JetBrainsMono Nerd Font`；字体栈首位保持 Nerd Font，中文由 fontconfig 回退 Noto
- 工作区常驻：`"persistent-workspaces" = { "*" = 4; }`（锁屏解锁后数字不消失）
- 排查进程用 `pgrep waybar`（wrapper 的 comm 是 `.waybar-wrapped`，`pgrep -x waybar` 永远匹配不到）

## mako

配置：`home/mako/config`。字体 `JetBrainsMono Nerd Font 10`（无中文字形，靠 fontconfig 回退；
若中文变豆腐块先查 `/etc/fonts` 是否存在）。

- 分段：`[urgency=low]` 短超时灰边、`[urgency=critical]` 红边常驻、`[mode=dnd]` 不可见
- 颜色键：`background-color` / `text-color` / `border-color` / `progress-color` 及 urgency 的 `border-color`
- **新增颜色键时必须同步 `scripts/theme-next` 的替换列表**，否则主题切换后该键不再跟随
- 改完：`makoctl reload`

## swayosd

`home/swayosd/style.css`，5 个颜色键由 theme-next 替换；主题脚本会重启 `swayosd-server`
（进程 comm 为 `.swayosd-server`，检测用 `pgrep swayosd-server`）。
