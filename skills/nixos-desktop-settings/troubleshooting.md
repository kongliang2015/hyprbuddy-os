# troubleshooting：常见故障

## 先跑自检

    scripts/hypr-check

三项检查：① 0.55 的 Lua 优先（存在 `hyprland.lua` 时 `.conf` 被忽略）
② `hyprctl configerrors`（需会话内）③ 规则语法 lint（缺 `match:` 前缀会静默失效）

## 状态栏不显示

1. CSS 非法：`:root` / `var()` 会让 waybar 解析失败拒绝启动 → 全部改具体色值
2. 进程检测：wrapper 的 comm 是 `.waybar-wrapped`，用 `pgrep waybar`，不要 `pgrep -x`
3. 并发 spawn：exec-once 与配置变更自动重载可能各起一个 → 用 flock 串行化

## 锁屏解锁后工作区数字消失

`lib/waybar.nix` 的 `hyprland/workspaces` 需要 `"persistent-workspaces" = { "*" = 4; }`。

## 锁屏出现两个输入框

hyprlock 的 `source` 是**追加**语义，不是覆盖：主题文件只放变量，默认值在前、`source` 在后。

## 中文变豆腐块 / kitty 字体难看

- 先查 `/etc/fonts` 是否存在：缺失时应用扫不到任何字体目录
- 已知成因：`installation-cd-minimal.nix` 用 `mkOverride 500` 关闭 `fonts.fontconfig.enable`；
  修法：`fonts.fontconfig.enable = lib.mkForce true;`
- 字体包（`modules/base.nix`）：`wqy_zenhei`、`noto-fonts-cjk-sans`、`nerd-fonts.jetbrains-mono`
- 验证：`fc-match "sans-serif:lang=zh-cn"`、`fc-list :lang=zh-cn | wc -l`

## Super+Space 菜单打不开

绑定是绝对路径 `@HOME@/.local/bin/hypr-menu`。若 `~/.local/bin` 被误建为真实目录，
脚本会落到 `~/.local/bin/bin/` 导致失效。正确形态：`~/.local/bin` 本身是指向 store `.../bin` 的软链。

## VNC 里鼠标指针重叠黑色 X

virtio-gpu 软件渲染无硬件光标平面，宿主 VNC 客户端自绘光标叠加——仅影响观看，截图不含，可忽略。

## fuzzel.ini 变成 0 字节

store 中间软链未就绪时直接写会得空文件；theme-next 已用「写 tmp → 非空才替换」规避。
