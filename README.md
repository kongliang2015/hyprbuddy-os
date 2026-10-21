# NixOS Hyprland 桌面配置（Kanagawa 默认 · aarch64 / vm-virtio）

flake 化的 Hyprland 桌面骨架：SDDM → Hyprland（uwsm 托管）→ Waybar / fuzzel / mako / hyprlock / awww / SwayOSD，默认 Kanagawa 配色，内置 5 套主题可热切换。按 host 选择架构与 GPU；本分支在 aarch64 KVM 虚机（QEMU virtio）上完成构建、启动、桌面验证与 live 镜像验证。

## 环境

### leonard（x86_64 真机）
- NVIDIA GTX 1050 Ti，闭源驱动 legacy_580（580.178.04）+ nvidia-drm.modeset=1
- 额外保留 XFCE / Window Maker 会话
- agent 层开启（opencode + codebuddy，含 usage 统计）

### vm-virtio（aarch64，本分支实测目标）
- 宿主：aarch64 Kylin；KVM/libvirt 域 nixos，6 vCPU / 8 GiB RAM（早期快照为 4 vCPU / 3.8 GiB）
- 磁盘：/data/usershare/vm-install/nixos-vm.qcow2（qcow2，已扩容至 60 GiB）
- 网络：libvirt passt；宿主 ssh -p 2222 nixos@127.0.0.1 登录
- 显卡：QEMU virtio-gpu（modesetting + Mesa），分辨率 1280x800（DRM preferred）
- 登录器：SDDM（catppuccin-mocha-mauve），默认会话 hyprland-uwsm
- 输入法：fcitx5 + 拼音
- agent 层：已开启（opencode + codebuddy），Waybar 显示当日 agent 用量

宿主机要求：可访问 mirrors.tuna.tsinghua.edu.cn（nixpkgs 走清华 nixexprs，不依赖 GitHub）。

## 目录结构

```
hyprland-nixos/
├── flake.nix            # nixosConfigurations / packages(per-host home + iso / liveIso) / checks
├── flake.lock           # nixpkgs 指向清华 nixos-26.05 nixexprs
├── install.sh           # 构建 home 配置树并软链到 ~/.config / ~/.local/bin / ~/.codebuddy/skills
├── modules/             # options / base / boot / users / desktop / hardware-gpu / agent
├── hosts/
│   ├── leonard/         # x86_64 + NVIDIA
│   ├── vm-virtio/       # aarch64 + virtio（本分支实测）
│   └── _template/       # 模板（不参与构建）
├── home/                # hypr / waybar / fuzzel / kitty / mako / swayosd / Thunar + default.nix
├── lib/                 # waybar.nix / agent-usage.nix
├── scripts/             # agent-apply / hypr-check / theme-next / hypr-menu / ...
├── skills/              # agent 技能：nixos-desktop-settings / diagnose-crash
├── installer/           # iso-config.nix（安装盘）/ live-iso-config.nix（live+install 一体盘）/ install.sh
├── wallpapers/
└── docs/                # KEYBINDS / TROUBLESHOOTING / ROADMAP / ARCHITECTURE-REVIEW / IMPLEMENTATION-PLAN / AGENT-LAYER / SKILL-REDESIGN
```

## 设计文档

- docs/ARCHITECTURE-REVIEW.md：评估结论与结构性硬伤
- docs/IMPLEMENTATION-PLAN.md：flake + options + host 的目标结构与实施步骤
- docs/AGENT-LAYER.md：agent 六层架构与实测状态
- docs/SKILL-REDESIGN.md：技能体系改造方案（路由器 + 专题指南 + 示例表）

## 已实现的功能

### 系统层（modules/）
- programs.hyprland（withUWSM = true，自动启用 programs.uwsm，安装其 systemd user units）
- SDDM：默认会话 hyprland-uwsm，主题 catppuccin-mocha-mauve；greeter 分辨率跟随 DRM preferred
- hyprlock 的 PAM 校验；NetworkManager；firewall 放行 22；openssh
- 按 distro.gpu.vendor 选择 nvidia / amd / intel / virtio 驱动模块
- 字体：wqy-zenhei + noto-fonts-cjk-sans + nerd-fonts.jetbrains-mono（fontconfig 必须启用，见「注意事项」）

### 用户层（home/ + scripts/）
- Hyprland：渐变边框、模糊、阴影、动画、完整键位；规则使用 0.55 语法（windowrule/layerrule 带 match: 前缀）
- Waybar：胶囊分组样式 + Nerd Font 图标 + 工作区 1-4 常驻；agent 用量模块（custom/agent-usage）
- fuzzel：应用启动器 + Super+Space 系统菜单（分组信息架构）+ 快捷键参考
- mako：毛玻璃样式 + urgency 分级（low 短超时 / critical 常驻）+ 勿扰模式；颜色随主题
- theme-next：5 套主题热切换，联动 waybar / fuzzel / mako / swayosd / 壁纸；登录时 restore
- hypr-check：配置自检（Lua 优先 / hyprctl configerrors / 0.55 规则语法 lint / 命令清单一致性），install.sh 末尾自动运行
- 其他：SwayOSD / hypridle / 夜间模式 / 录屏 / 截图标注 / 壁纸轮换（awww）

### Agent 层（modules/agent/ + lib/agent-usage.nix）
- 包与脚本：agent-menu（Super+Shift+Ctrl+A）/ agent-apply（求值→构建→交用户 switch）/ agent-theme-sync
- agent-usage：codebuddy / claude / opencode 三数据源，/cost 口径统计当日 output tokens
- diagnostics：coredump-watch + coredump-analyze（本地模型分析，需 localModels = true）

### 技能（skills/，随 install.sh 部署）
- `nixos-desktop-settings`：路由器（铁律 / 决策树 / 18 条示例表）+ 6 篇专题指南
  （workflow / hyprland / bar-notify / theming / agent / troubleshooting）
- `diagnose-crash`：崩溃 / 段错误 / core dump 分析，优先读 diagnostics 自动报告
- 分发：install.sh 链接到 `~/.codebuddy/skills/`；`~/.claude` 存在时同步到 `~/.claude/skills/`

### 镜像
- installer ISO（`.#packages.<system>.iso`）：root 文本界面 + `install-hyprland-nixos`
- live ISO（`.#packages.<system>.liveIso`）：live+install 一体盘，SDDM 自动登录 `live`（密码 live，wheel，免密 sudo，SSH 密码登录），保留安装器

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

    # 可选：agent 层（agents 排除 claude-code，其构建期需访问 downloads.claude.ai）
    agent = {
      enable = true;
      agents = [ "opencode" "codebuddy" ];
      usage = true;
      diagnostics = false;   # 开启需同时 localModels = true（断言强制）
      localModels = false;
    };
  };
}
```

| 选项 | 取值 | 作用 |
|---|---|---|
| distro.gpu.vendor | nvidia / amd / intel / virtio / none | 选择 GPU 模块 |
| distro.gpu.nvidia.branch | auto / legacy_580 / production / beta | auto 按 pciIds 判断 |
| distro.desktop.extraSessions | xfce / windowmaker | 额外 X11 会话 |
| distro.hardware.battery / backlight | bool | 影响 Waybar 与键位 |
| distro.agent.* | enable / agents / usage / diagnostics / localModels / model | agent 层 |

> NVIDIA 必须留在 580 LTSB：26.05 的 nvidiaPackages.stable 已指向 595.x，该分支不支持 Pascal，误用会黑屏。

## 部署

```bash
# 用户级：构建 home 配置树并软链（~/.config、~/.local/bin、~/.codebuddy/skills；自动创建 GC root）
./install.sh --host vm-virtio --yes

# 系统级（只装新世代，重启生效）
sudo nixos-rebuild boot --flake .#vm-virtio

# 或立即切换
sudo nixos-rebuild switch --flake .#vm-virtio
```

然后注销重登（或重启）让 exec-once 的守护进程启动。

home 配置由 home/default.nix 生成（nix build .#vm-virtio 可看产物），~/.config、~/.local/bin 与 skills 都是指向 store 的软链；install.sh 通过 --out-link 建立 GC root，nix-collect-garbage 不会让软链悬空。被替换的真实文件备份在 `~/.config.bak-<时间戳>/`。

agent 或自动化改动走统一入口 `scripts/agent-apply <host>`：`git diff --stat` → `nix eval` 求值 → `nixos-rebuild build` → 打印需要用户执行的 sudo 命令（agent 不执行 sudo）。

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

### 近期验证（2026-10）
- 12 项 v0 变更 cherry-pick 后实测：Hyprland 0.55 规则语法、mako 毛玻璃样式、超级菜单分组信息架构、Waybar 胶囊样式、theme-next 联动（Nord 主题下 waybar/mako/fuzzel 全部跟随）
- agent-usage：Waybar 显示 `AGENT 1237.2k`（codebuddy 当日 output，/cost 口径）
- live ISO（3.2 GiB）：以无安全启动固件（AAVMF_CODE.no-secboot.fd）启动，SDDM 自动登录、中文渲染正常、Super+Space 菜单可用
- 字体问题根因：installation-cd-minimal.nix 用 `mkOverride 500` 关闭 `fonts.fontconfig.enable`，导致 live 环境 `/etc/fonts` 缺失（中文豆腐块、kitty 字体回退）。修法：live 配置加 `fonts.fontconfig.enable = lib.mkForce true;`

### 注意事项
- flake.lock 的 nixpkgs narHash 已更新到清华镜像当前内容；频道刷新后若校验失败，执行 nix flake update nixpkgs。
- SDDM 0.21 (Qt6) 在本快照上仍需要给 sddm-wrapped 补 bin/sddm-greeter 符号链接，否则主题回退到 fallback（本分支已在 modules/desktop/hyprland.nix 处理）。
- hosts/vm-virtio/default.nix 里的 SSH 公钥为测试用途，正式使用前请替换。
- ISO 产物按架构：installer 用 `nix build .#packages.aarch64-linux.iso`，live 用 `nix build .#packages.aarch64-linux.liveIso`（x86_64 换成对应 system）。
- live 盘激活脚本只建 `~/.local`，`~/.local/bin` 必须是指向 store 的软链；误建成真实目录会让 `~/.local/bin/hypr-menu` 等绝对路径绑定失效。

## 修改配置

- 改外观/键位 → 改 home/ 或 home/default.nix，再 ./install.sh --host <host>
- 改系统能力 → 改 modules/，再 sudo nixos-rebuild switch --flake .#<host>
- 改机器参数 → 改 hosts/<host>/default.nix（只写 distro.*）
- 改技能 → 改 skills/，install.sh 会自动重新链接（新增技能目录零代码改动）
- 完整工作流与示例见技能 `nixos-desktop-settings`（docs/SKILL-REDESIGN.md 为设计说明）

## 安装到新机器

```bash
# 通用安装盘（root 文本界面）
nix build .#packages.aarch64-linux.iso
# live+install 一体盘（直接进桌面试用，仍可安装）
nix build .#packages.aarch64-linux.liveIso

sudo dd if=result/iso/hyprland-nixos-live.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

installer 镜像启动后以 root 登录，分区并挂载到 /mnt，然后执行 installer/install.sh（安装器不分区、不格式化）。live 镜像启动后直接进入 Hyprland（用户 live / 密码 live），并保留 `install-hyprland-nixos` 命令。

## 快捷键

完整列表见 docs/KEYBINDS.md。常用：Super+Return（kitty）、Super+D（fuzzel）、Super+Space（系统菜单）、Super+Shift+T（切换主题）、Super+L（锁屏）、Super+Q（关闭）、Super+V（剪贴板）、Print（截图）。

## 主题

内置 5 套主题，`theme-next` 循环切换（Super+Shift+T），`theme-next restore` 在登录时应用已保存主题，联动 waybar / fuzzel / mako / swayosd / 壁纸。默认 Kanagawa：背景 #1F1F28 / #16161D，前景 #DCD7BA，强调 #7E9CD8 / #957FB8，绿 #76946A，黄 #DCA561，红 #FF5D62，青 #7AA89F，粉 #D27E99，橙 #FFA066。

## 为什么用 SDDM 而不是 LightDM

LightDM 启动 Wayland 会话时破坏 seat/输入设备交接（Hyprland 起来但键鼠全死）；TTY 直接启动正常。换 SDDM 后问题消失。详见 docs/TROUBLESHOOTING.md。

## 后续路线

见 docs/ROADMAP.md。技能体系下一步可考虑：机器可读的命令清单（`agent-commands --json` 式）与更多专题指南。
