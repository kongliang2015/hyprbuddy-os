# NixOS Hyprland 桌面配置（Kanagawa · aarch64 / vm-virtio）

flake 化的 Hyprland 桌面骨架：SDDM → Hyprland（可选 uwsm 托管）→ Waybar / fuzzel / mako / hyprlock / hyprpaper / SwayOSD，统一 Kanagawa 配色。按 host 选择架构与 GPU；本分支在 aarch64 KVM 虚机（QEMU virtio）上完成构建、启动与桌面验证。

## 环境

### leonard（x86_64 真机）
- NVIDIA GTX 1050 Ti，闭源驱动 legacy_580（580.178.04）+ nvidia-drm.modeset=1
- 额外保留 XFCE / Window Maker 会话

### vm-virtio（aarch64，本分支实测目标）
- 宿主：aarch64 Kylin；KVM/libvirt 域 nixos，4 vCPU / 3.8 GiB RAM
- 磁盘：/data/usershare/vm-install/nixos-vm.qcow2（qcow2，已扩容至 60 GiB）
- 网络：libvirt passt；宿主 ssh -p 2222 nixos@127.0.0.1 登录
- 显卡：QEMU virtio-gpu（modesetting + Mesa），分辨率 1280x800（DRM preferred）
- 登录器：SDDM（catppuccin-mocha-mauve），默认会话 hyprland-uwsm
- 输入法：fcitx5 + 拼音

宿主机要求：可访问 mirrors.tuna.tsinghua.edu.cn（nixpkgs 走清华 nixexprs，不依赖 GitHub）。

## 目录结构

```
hyprland-nixos/
├── flake.nix            # nixosConfigurations / packages(per-host home + iso) / checks
├── flake.lock           # nixpkgs 指向清华 nixos-26.05 nixexprs
├── install.sh           # 构建 home 配置树并软链到 ~/.config / ~/.local/bin（带 GC root）
├── modules/             # options / base / boot / users / desktop / hardware-gpu / agent
├── hosts/
│   ├── leonard/         # x86_64 + NVIDIA
│   ├── vm-virtio/       # aarch64 + virtio（本分支实测）
│   └── _template/       # 模板（不参与构建）
├── home/                # hypr / waybar / fuzzel / kitty / mako / swayosd + default.nix
├── lib/                 # waybar.nix / agent-usage.nix
├── scripts/             # hypr-menu / night-mode / record-toggle / ...
├── installer/           # ISO 与安装脚本
├── wallpapers/
└── docs/                # KEYBINDS / TROUBLESHOOTING / ROADMAP / ARCHITECTURE-REVIEW / IMPLEMENTATION-PLAN / AGENT-LAYER
```

## 设计文档

- docs/ARCHITECTURE-REVIEW.md：评估结论与结构性硬伤
- docs/IMPLEMENTATION-PLAN.md：flake + options + host 的目标结构与实施步骤

## 已实现的功能

### 系统层（modules/）
- programs.hyprland（withUWSM = true，自动启用 programs.uwsm，安装其 systemd user units）
- SDDM：默认会话 hyprland-uwsm，主题 catppuccin-mocha-mauve；greeter 分辨率跟随 DRM preferred
- hyprlock 的 PAM 校验；NetworkManager；firewall 放行 22；openssh
- 按 distro.gpu.vendor 选择 nvidia / amd / intel / virtio 驱动模块

### 用户层（home/ + scripts/）
- Hyprland：渐变边框、模糊、阴影、动画、完整键位
- Waybar：Kanagawa 风格（工作区/窗口/音量/网络/CPU/内存/时钟）
- fuzzel：应用启动器 + Super+Space 系统菜单 + 快捷键参考
- mako / SwayOSD / hypridle / 夜间模式 / 录屏 / 截图标注 / 壁纸轮换

## host 与 distro 选项

每个 hosts/<host>/default.nix 只写 distro.*：

```nix
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "vm-virtio";
  system.stateVersion = "25.11";

  distro = {
    gpu.vendor = "virtio";
    desktop.extraSessions = [ ];
    user.name = "nixos";
    hardware.battery = false;
  };
}
```

| 选项 | 取值 | 作用 |
|---|---|---|
| distro.gpu.vendor | nvidia / amd / intel / virtio / none | 选择 GPU 模块 |
| distro.gpu.nvidia.branch | auto / legacy_580 / production / beta | auto 按 pciIds 判断 |
| distro.desktop.extraSessions | xfce / windowmaker | 额外 X11 会话 |
| distro.hardware.battery / backlight | bool | 影响 Waybar 与键位 |
| distro.agent.* | enable / agents / usage / diagnostics / localModels | agent 层 |

> NVIDIA 必须留在 580 LTSB：26.05 的 nvidiaPackages.stable 已指向 595.x，该分支不支持 Pascal，误用会黑屏。

## 部署

```bash
# 用户级：构建 home 配置树并软链（会自动创建 GC root）
./install.sh --host vm-virtio

# 系统级（只装新世代，重启生效）
sudo nixos-rebuild boot --flake .#vm-virtio

# 或立即切换
sudo nixos-rebuild switch --flake .#vm-virtio
```

然后注销重登（或重启）让 exec-once 的守护进程启动。

home 配置由 home/default.nix 生成（nix build .#vm-virtio 可看产物），~/.config 与 ~/.local/bin 都是指向 store 的软链；install.sh 通过 --out-link 建立 GC root，nix-collect-garbage 不会让软链悬空。

## aarch64 / vm-virtio 实机验证

本分支在下列环境中完成端到端验证：

- 构建：nix build .#nixosConfigurations.vm-virtio.config.system.build.toplevel（约 369 个 derivation 本地构建，其余从 TUNA/SJTU substitute）
- 部署：sudo nixos-rebuild boot --flake .#vm-virtio 后重启，进入新世代
- 登录：SDDM 默认选中 Hyprland (uwsm-managed)，输入密码进入桌面
- 验证点：
  - hostname = vm-virtio，内核 6.18.x aarch64，systemctl is-system-running = running
  - SDDM 日志无 Using fallback theme；主题为 catppuccin-mocha-mauve
  - greeter X 分辨率 1280x800（与 Hyprland 的 monitor=,preferred,auto,1 一致）
  - uwsm 会话正常：pgrep Hyprland 与 uwsm 均存在，systemctl --user 可用
  - kitty 平铺：remember_window_size no，两窗口左右平分

### 注意事项
- flake.lock 的 nixpkgs narHash 已更新到清华镜像当前内容；频道刷新后若校验失败，执行 nix flake update nixpkgs。
- SDDM 0.21 (Qt6) 在本快照上仍需要给 sddm-wrapped 补 bin/sddm-greeter 符号链接，否则主题回退到 fallback（本分支已在 modules/desktop/hyprland.nix 处理）。
- hosts/vm-virtio/default.nix 里的 SSH 公钥为测试用途，正式使用前请替换。
- ISO 产物按架构：nix build .#packages.aarch64-linux.iso（x86_64 用 .#packages.x86_64-linux.iso）。

## 修改配置

- 改外观/键位 → 改 home/ 或 home/default.nix，再 ./install.sh --host <host>
- 改系统能力 → 改 modules/，再 sudo nixos-rebuild switch --flake .#<host>
- 改机器参数 → 改 hosts/<host>/default.nix（只写 distro.*）

## 安装到新机器

```bash
nix build .#packages.aarch64-linux.iso   # 或 x86_64-linux
sudo dd if=result/iso/hyprland-nixos-installer.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

镜像启动后以 root 登录，分区并挂载到 /mnt，然后执行 installer/install.sh（详见 installer/）。安装器不分区、不格式化。

## 快捷键

完整列表见 docs/KEYBINDS.md。常用：Super+Return（kitty）、Super+D（fuzzel）、Super+Space（系统菜单）、Super+L（锁屏）、Super+Q（关闭）、Super+V（剪贴板）、Print（截图）。

## 主题

Kanagawa：背景 #1F1F28 / #16161D，前景 #DCD7BA，强调 #7E9CD8 / #957FB8，绿 #76946A，黄 #DCA561，红 #FF5D62，青 #7AA89F，粉 #D27E99，橙 #FFA066。

## 为什么用 SDDM 而不是 LightDM

LightDM 启动 Wayland 会话时破坏 seat/输入设备交接（Hyprland 起来但键鼠全死）；TTY 直接启动正常。换 SDDM 后问题消失。详见 docs/TROUBLESHOOTING.md。

## 后续路线

见 docs/ROADMAP.md。
