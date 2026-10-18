# NixOS Hyprland 桌面配置（Kanagawa · omarchy 风格）

在 **NixOS 25.11 + NVIDIA** 上用 Hyprland 搭一套类似 omarchy 的平铺桌面：
SDDM 登录 → Hyprland → Waybar 状态栏 / fuzzel 启动器 / mako 通知 / hyprlock 锁屏 / hyprpaper 壁纸 / SwayOSD 屏显，统一 Kanagawa 配色。

## 环境

- NixOS 25.11（channel 方式，非 flake）
- NVIDIA GTX 1050 Ti，闭源驱动（`nvidia-drm.modeset=1`）
- 登录管理器：**SDDM**，默认会话 Hyprland
- 中文输入：fcitx5 + 拼音
- 保留 XFCE / Window Maker 作为可选会话

## 目录结构

```
hyprland-nixos/
├── README.md
├── install.sh                  # 部署用户级配置
├── system/
│   └── configuration.nix       # 系统层配置（需 sudo 应用）
├── home/
│   ├── hypr/                   # hyprland.conf / hypridle.conf / hyprlock.conf / hyprpaper.conf
│   ├── waybar/                 # config + style.css
│   ├── fuzzel/                 # fuzzel.ini
│   ├── kitty/                  # kitty.conf
│   ├── mako/                   # config（通知）
│   └── swayosd/                # style.css（音量/亮度 OSD）
├── scripts/                    # hypr-menu / night-mode / record-toggle / ...
├── wallpapers/                 # 5 张配色壁纸
└── docs/
    ├── KEYBINDS.md             # 完整快捷键
    ├── TROUBLESHOOTING.md      # 踩坑与修复记录
    └── ROADMAP.md              # 与 omarchy 的差距与后续
```

## 已实现的功能

### 系统层（`system/configuration.nix`）

- `programs.hyprland` + `xwayland`
- `services.displayManager.sddm`，`defaultSession = "hyprland"`
- `security.pam.services.hyprlock`（锁屏密码校验）
- `boot.kernelParams = [ "nvidia-drm.modeset=1" ]`
- 安装包：
  - 桌面：`waybar` `kitty` `fuzzel` `hyprlock` `hyprpaper` `mako` `hyprshot`
  - 工具：`grim` `slurp` `wl-clipboard` `brightnessctl` `playerctl` `btop`
  - 增强：`swayosd` `cliphist` `hypridle` `hyprsunset` `networkmanagerapplet` `blueman` `pavucontrol` `wf-recorder` `swappy` `hyprpicker` `libnotify`
- 字体：`nerd-fonts.jetbrains-mono` + `noto-fonts-cjk-sans` + `wqy_zenhei`

### 用户层（`home/` 与 `scripts/`）

- **Hyprland**：渐变边框、模糊、阴影、动画、完整键位
- **Waybar**：Kanagawa 风格，工作区/窗口/音量/网络/CPU/内存/电量/时钟
- **fuzzel**：应用启动器（`Super+D`）+ `Super+Space` 分组菜单（应用 / 系统工具 / 外观 / 会话，多层返回）+「快捷键参考」（动态读取 `hyprctl binds`，带中文说明）
- **mako**：统一通知样式（圆角/边框/进度条/分级/分组/图标/勿扰）
- **SwayOSD**：与通知同风格的音量/亮度屏显
- **hypridle**：5 分钟锁屏、10 分钟熄屏（不自动挂起）
- **附加脚本**：夜间模式、录屏、截图标注、取色、壁纸轮换

## 应用配置

### 方式一：一键脚本

```bash
cd ~/hyprland-nixos
./install.sh
# 系统层
sudo cp system/configuration.nix /etc/nixos/configuration.nix
sudo nixos-rebuild switch
```

然后**注销重登**（或重启），让 `exec-once` 的守护进程启动。

### 方式二：手动

```bash
# 用户级
cp -r home/hypr home/waybar home/fuzzel home/kitty home/mako home/swayosd ~/.config/
cp scripts/* ~/.local/bin/ && chmod +x ~/.local/bin/*

# 系统级
sudo cp system/configuration.nix /etc/nixos/configuration.nix
sudo nixos-rebuild switch
```

## 快捷键

完整列表见 [docs/KEYBINDS.md](docs/KEYBINDS.md)。常用：

| 按键 | 功能 |
|---|---|
| `Super+Return` | 终端 kitty |
| `Super+D` | 应用启动器 fuzzel |
| `Super+Space` | 系统菜单（含剪贴板/夜间/录屏/换壁纸/勿扰…） |
| `Super+L` | 锁屏 |
| `Super+M` | 注销（退出 Hyprland 回 SDDM） |
| `Super+Q` | 关闭窗口 |
| `Super+V` | 剪贴板历史 |
| `Print` | 区域截图 |

## 主题

Kanagawa 调色板（单色源）：

| 角色 | 色值 |
|---|---|
| 背景 | `#1F1F28` / 栏底 `#16161D` |
| 前景 | `#DCD7BA` |
| 强调 | `#7E9CD8`（winterBlue） / `#957FB8`（oniViolet） |
| 绿/黄/红 | `#76946A` / `#DCA561` / `#FF5D62` |
| 青/粉/橙 | `#7AA89F` / `#D27E99` / `#FFA066` |

## 为什么用 SDDM 而不是 LightDM

LightDM 启动 Wayland 会话时会破坏 seat/输入设备交接：Hyprland 起来了但**键鼠全死**；从 TTY 直接 `Hyprland` 则正常。换 SDDM 后 seat 正确交接，问题消失。详见 [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)。

## 后续路线

与 omarchy 的差距、可继续实现的功能见 [docs/ROADMAP.md](docs/ROADMAP.md)。
