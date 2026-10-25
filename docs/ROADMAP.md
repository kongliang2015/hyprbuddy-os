# 后续路线（与 omarchy 的差距）

当前已具备 omarchy 的核心桌面骨架。下面按"可实现难度"列出剩余特性。

## 已完成

- Hyprland 平铺桌面、动画、渐变边框
- SDDM 登录 + 默认 Hyprland 会话
- Waybar 状态栏（Kanagawa）
- fuzzel 启动器 + `Super+Space` 系统菜单
- hyprlock 锁屏、hypridle 自动锁屏/熄屏
- hyprpaper 壁纸 + 壁纸轮换
- swaync 通知中心 + 控制中心（勿扰、历史、MPRIS；已替代 mako）
- SwayOSD 音量/亮度屏显
- 截图（hyprshot）+ 标注（swappy）+ 取色（hyprpicker）
- 录屏（wf-recorder）
- 剪贴板历史（cliphist）
- 夜间模式（hyprsunset）
- fcitx5 中文输入
- Nerd Font 图标

## 低难度（可直接继续做）

- **一键主题切换器**：需要按应用生成配置（kitty 16 色、hyprlock 十进制 rgba、Waybar CSS），建议用"模板 + 备份"方式实现，比 sed 更稳。
- SDDM 图形登录主题美化（sddm-astronaut-theme 等）。
- 通知操作按钮（mako `actions=1` 已开，可加"打开/复制"）。
- 通知居中大卡片样式。
- 电池/蓝牙/etc. 更多 Waybar 模块。

## 中难度

- 多编辑器（VSCode/Cursor/Zed/Helix）与多终端（Foot/Alacritty/Ghostty）切换菜单。
- mise 开发栈一键安装（Node/Rails/Laravel…）。
- 游戏套件（Steam / RetroArch+CRT / Lutris / Heroic / Moonlight）。
- Waybar 自定义插件（天气、系统更新提示、蓝牙电量等，近似 omarchy 插件）。
- `hypr-menu` 扩展为 `omarchy` 风格子命令（theme/update/install）。
- 电源/合盖策略（hypridle + logind）。

## 难以直接移植

- **Quickshell 顶栏 + 数千插件**：omarchy 专属 QML 组件，只能用 Waybar 做功能近似。
- **omarchy 安装器 / `omarchy update`**：绑定 Arch/pacman，NixOS 用 `nixos-rebuild`。
- **Windows 11 VM 自动化 + `omarchy windows key`**：可手动用 libvirt/QEMU 搭，无一键封装。
- **agentic 生态**（首次启动配 agent、崩溃派 agent、skills 市场）：可自行接 Claude Code 等近似。
- **`omarchy-theme-install`**：Arch 脚本，需自写取色/生成脚本代替。

## NixOS 相对优势

- 声明式配置、generation 回滚、可复现、系统/用户层分离。
