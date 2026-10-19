# NixOS Hyprland 桌面配置（Kanagawa · omarchy 风格）

在 **NixOS 26.05 + NVIDIA** 上用 Hyprland 搭一套类似 omarchy 的平铺桌面：
SDDM 登录 → Hyprland → Waybar 状态栏 / fuzzel 启动器 / mako 通知 / hyprlock 锁屏 / hyprpaper 壁纸 / SwayOSD 屏显，统一 Kanagawa 配色。

## 环境

- NixOS 26.05（flake 方式，nixpkgs 走清华 nixexprs 输入）
- NVIDIA GTX 1050 Ti，闭源驱动 `legacy_580`（580.178.04）+ `nvidia-drm.modeset=1`
- 结构：`hosts/<host>` 只写 `distro.*` 选项，`modules/` 承载全部实现
- 登录管理器：**SDDM**，默认会话 Hyprland
- 中文输入：fcitx5 + 拼音

## 目录结构

```
hyprland-nixos/
├── README.md
├── flake.nix                   # nixosConfigurations.<host> + checks
├── flake.lock
├── install.sh                  # 部署用户级配置（系统层改用 nixos-rebuild --flake）
├── modules/
│   ├── default.nix             # 模块汇总入口
│   ├── options.nix             # distro.* 选项 schema（唯一对外接口）
│   ├── base.nix / boot.nix / users.nix / assertions.nix
│   ├── desktop/{hyprland,sessions}.nix
│   └── hardware/gpu/{all,nvidia,amd,intel,virtio}.nix
├── hosts/
│   ├── leonard/                # GTX 1050 Ti / 台式机 / 保留 XFCE+WM
│   └── vm-virtio/              # QEMU 虚拟机示例
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
    ├── ROADMAP.md              # 与 omarchy 的差距与后续
    ├── ARCHITECTURE-REVIEW.md  # 架构评估：现状 vs 发行版目标
    ├── IMPLEMENTATION-PLAN.md  # flake/options/host 改造的实施计划
    └── AGENT-LAYER.md          # AI agent 层落地设计
```

## 设计文档

本项目的目标是做成 **AI agent 原生**、可覆盖多种显卡（NVIDIA / AMD / Intel / virtio）的 NixOS 发行版骨架。当前结构与该目标之间的差距、以及分阶段改造方案：

- [docs/ARCHITECTURE-REVIEW.md](docs/ARCHITECTURE-REVIEW.md)：评估结论与四个结构性硬伤
- [docs/IMPLEMENTATION-PLAN.md](docs/IMPLEMENTATION-PLAN.md)：flake + options + host 的目标结构与 P0–P4 实施步骤

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

### host 与 distro 选项

每台机器是一个 `hosts/<host>/default.nix`，**只写 `distro.*`，不直接写 NixOS 选项**：

```nix
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nixos";
  system.stateVersion = "25.11";

  distro = {
    user.name = "leonard";
    boot.windowsEntry = true;
    gpu = {
      vendor = "nvidia";
      nvidia = { pciIds = [ "10de:1c82" ]; open = false; };  # auto → legacy_580
    };
    desktop.extraSessions = [ "xfce" "windowmaker" ];
    hardware.battery = false;
  };
}
```

| 选项 | 取值 | 作用 |
|---|---|---|
| `distro.gpu.vendor` | nvidia / amd / intel / virtio / none | 选择 GPU 模块 |
| `distro.gpu.nvidia.branch` | auto / legacy_580 / production / beta | auto 按 pciIds 的 Turing 分界（device id ≥ 0x1E00）判断 |
| `distro.gpu.nvidia.open` | bool | Pascal 及更早必须 false |
| `distro.desktop.extraSessions` | xfce / windowmaker 列表 | 额外保留的 X11 会话 |
| `distro.hardware.{battery,backlight}` | bool | 笔记本能力（P4 起影响 Waybar 与键位） |
| `distro.agent.*` | enable / agents / diagnostics / usage / localModels | agent 层（P3 落地） |

> NVIDIA 必须留在 580 LTSB：26.05 的 `nvidiaPackages.stable` 已指向 595.x，
> 该分支不再支持 Maxwell / Pascal / Volta，误用会导致开机黑屏、无图形会话。

### 部署

```bash
# 用户级（Hyprland / Waybar / 脚本 / 壁纸）
./install.sh

# 系统级（flake）
sudo nixos-rebuild switch --flake .#leonard
```

然后**注销重登**（或重启），让 `exec-once` 的守护进程启动。

新增机器：复制 `hosts/vm-virtio` 为新目录，改 `distro.*`，再跑 `nix flake check` 确认求值。

> 用户级包（git/vim/curl…）仍由外部 Home Manager 管理（`~/.config/home-manager`）。
> 本仓库暂未纳入 HM：本机访问 github.com 被阻断，HM 作为 flake 输入需要单独的镜像方案。

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
