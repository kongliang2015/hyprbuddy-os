# NixOS Hyprland 桌面配置（Kanagawa · omarchy 风格）

在 **NixOS 25.11 + NVIDIA** 上用 Hyprland 搭一套类似 omarchy 的平铺桌面：
SDDM 登录 → Hyprland → Waybar 状态栏 / fuzzel 启动器 / mako 通知 / hyprlock 锁屏 / hyprpaper 壁纸 / SwayOSD 屏显，统一 Kanagawa 配色。

## 环境

- NixOS 25.11（channel 方式，非 flake）
- NVIDIA GTX 1050 Ti，闭源驱动（`nvidia-drm.modeset=1`）
- 登录管理器：**SDDM**，默认会话 Hyprland
- 中文输入：fcitx5 + 拼音

## 目录结构

```
hyprland-nixos/
├── README.md
├── install.sh                  # 部署用户级配置
├── system/
│   ├── configuration.nix       # 系统层配置（需 sudo 应用）
│   ├── home.nix                # Home Manager 配置片段（由 NixOS module 导入）
│   └── profiles/
│       └── leonard-nvidia.nix  # 机型 profile：真实 NVIDIA 显卡 + 保留 XFCE/WM
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

### 机型 profile

`system/configuration.nix` 顶部的 `hardwareProfile` 决定加载哪个机型 profile：

| 值 | 适用 | 显卡栈 | 会话 |
|---|---|---|---|
| `"virtio"`（默认） | QEMU / virtio GPU 虚拟机 | `modesetting` + Mesa | Hyprland only |
| `"leonard-nvidia"` | 真实 NVIDIA 显卡（GTX 1050 Ti / Pascal） | 闭源驱动 `legacy_580`（580.178.04） | Hyprland + XFCE + Window Maker |

设置方式：

```bash
./install.sh --profile leonard-nvidia   # 由脚本写入 configuration.nix
# 或手动改 system/configuration.nix 里的 hardwareProfile
```

> NVIDIA 必须留在 580 LTSB 分支：26.05 的 `nvidiaPackages.stable` 已指向 595.x，
> 该分支不再支持 Maxwell / Pascal / Volta，误用会导致开机黑屏、无图形会话。

### Home Manager 接入方式

`system/configuration.nix` 顶部的 `homeManagerMode` 决定 Home Manager 怎么接入：

| 值 | 行为 | 配置文件位置 | 生效命令 |
|---|---|---|---|
| `"module"`（默认） | 作为 NixOS module 集成，用户环境随系统一起构建 | `/etc/nixos/home.nix` | `nixos-rebuild switch` |
| `"standalone"` | 独立 channel，用户环境单独构建 | `~/.config/home-manager/home.nix` | `nixos-rebuild switch` + `home-manager switch` |

```bash
./install.sh --hm standalone --profile leonard-nvidia
./install.sh --hm module      # 默认，等价于不传
```

`system/home.nix` 里的 `home.username` / `home.homeDirectory` 用占位符书写，由 install.sh 按实际用户替换；`home.stateVersion` 会一并 align 到系统的 `system.stateVersion`。

> 两种模式互斥：`standalone` 模式不会导入 `<home-manager/nixos>`，因此系统重建不需要 `home-manager` 在 NIX_PATH 里。

### 方式一：一键脚本

```bash
cd ~/hyprland-nixos
./install.sh
# 系统层
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

### 同步线上改动回项目

改完线上配置后，运行：

```bash
./sync.sh                  # 自动提交，提交信息带时间戳
./sync.sh "调整通知样式"    # 自定义提交信息
```

`sync.sh` 会把 `~/.config`、`~/.local/bin`、`~/configuration.nix.new` 和壁纸同步回项目目录，然后 `git add -A` 并在有改动时提交。

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


## 用户名与主目录自适应

仓库不绑定固定用户名，可部署到安装时创建了任意用户名的 NixOS：

- `system/configuration.nix` 中的用户写作占位符 `__TARGET_USER__`；
- `home/`、`scripts/` 中的路径统一写作 `/home/nixos`（占位）。

以目标用户身份运行 `./install.sh` 时会自动：

1. 用实际用户（`$SUDO_USER`，否则 `id -un`）替换 `__TARGET_USER__`；
2. 用该用户的 `$HOME` 替换配置/脚本中的 `/home/nixos`；
3. 把 `wallpapers/*` 复制到 `~/Pictures/wallpapers/`；
4. 把 `system/home.nix` 部署到 `/etc/nixos/home.nix`，并检查/添加 `home-manager` channel。

因此无需手工修改用户名或路径。

手动部署（方式二）时，需先在复制系统配置前替换占位符：

```bash
sed -i "s/__TARGET_USER__/$USER/g" system/configuration.nix
sudo cp system/configuration.nix /etc/nixos/configuration.nix
sudo cp system/home.nix /etc/nixos/home.nix
```

> `home-manager` 需预先添加 channel：
> `sudo nix-channel --add https://github.com/nix-community/home-manager/archive/release-26.05.tar.gz home-manager && sudo nix-channel --update`
