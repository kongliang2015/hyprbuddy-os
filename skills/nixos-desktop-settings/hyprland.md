# hyprland：键位、规则、显示器、装饰、输入法

源文件：`home/hypr/hyprland.conf`（构建时 `@HOME@` 替换为家目录）

## 当前键位（节选）

| 键 | 动作 |
|---|---|
| Super+Return / Super+D / Super+Space | kitty / fuzzel / hypr-menu |
| Super+B / Super+E / Super+L | firefox / thunar / hyprlock |
| Super+Shift+T | theme-next 切换主题 |
| Super+V | 剪贴板历史（cliphist + fuzzel） |
| Super+Q / Super+M / Super+F / Super+T | killactive / exit / fullscreen / togglefloating |
| Super+Shift+R | hyprctl reload |
| Super+方向 / Shift+方向 / Alt+方向 | 聚焦 / 移动 / 缩放窗口 |
| Super+1..4 | 持久工作区（`persistent-workspaces` 4） |

完整列表：`show-keybinds` 或 `docs/KEYBINDS.md`

## 规则语法（Hyprland 0.55）

- 必须带 `match:` 前缀，否则**静默失效**：

      windowrule = match:class (gimp), float
      layerrule = match:namespace (waybar), blur

- 改完必须 `scripts/hypr-check`（0.55 语法 lint）+ 会话内 `hyprctl reload`
- 若存在 `hyprland.lua`，0.55 会忽略 `.conf`；hypr-check 会检测并提示

## 显示器

    monitor = DP-1, 2560x1440@60, 1920x0, 1
    monitor = , preferred, auto, 1        # 兜底

## 装饰 / 布局

在 `hyprland.conf` 的 `decoration`、`general`、`animations` 段调整圆角、间隙、模糊、动画。
边框兜底色与主题脚本联动，主题切换时由 theme-next 覆盖。

## 生成的片段（勿手改）

`~/.config/hypr/extra.conf` 由 `home/default.nix` 生成：背光快捷键（`distro.hardware.backlight`）
与 agent-menu 绑定（`distro.agent.enable`）。要改行为请改 host 选项。

## 输入法

`modules/desktop/hyprland.nix` 的 `i18n.inputMethod`。fcitx5 必须使用带插件的
`config.i18n.inputMethod.package`；裸 `pkgs.fcitx5` 缺拼音引擎，会报
`Group Item pinyin ... is not valid` 并把拼音移除。
