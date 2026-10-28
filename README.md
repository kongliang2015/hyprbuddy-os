# NixOS 桌面配置（Hyprland + niri 双桌面 · distro/v1）

flake 化的桌面配置：SDDM → 桌面会话（Hyprland / niri 可并存、可指定默认；
COSMIC 已在本分支退役，COSMIC 版见 `distro/v1-cosmic`），
按 host 选择架构 / GPU / 桌面提供方。桌面能力通过 \`scripts/lib/de.sh\` 抽象层
收敛（壁纸 / 截图 / 锁屏 / 通知 / 显示器…），脚本不直接依赖具体桌面。

- Hyprland 栈：uwsm 托管，Lua 配置管理器（hyprland.lua），Waybar / fuzzel /
  swaync / eww / hyprshell / SwayOSD，9 套主题热切换（新增 Deepin Blue）
- niri 栈：niri 26.04 + Noctalia 外壳（面板 / launcher / 通知 / 锁屏 / OSD），
  由 \`distro.desktop.sessions\` 控制安装，与 Hyprland 共用 agent 层与技能层
- 分支：`distro/v1-cosmic`（Hyprland + COSMIC）/ `distro/v1-nn`（Hyprland + niri，当前）。
  桌面提供方抽象 P0/P1 在两个分支均已完成（见
  docs/desktop-abstraction.md），后续按 P2–P5 渐进推进

## 环境

### leonard（x86_64 真机）
- NVIDIA GTX 1050 Ti，闭源驱动 legacy_580（580.178.04）+ nvidia-drm.modeset=1
- 双会话并存：Hyprland + niri（vmware 虚机默认 niri）；COSMIC / X11 会话已退役
- agent 层开启（opencode + codebuddy，含 usage 统计）

### vmware（x86_64 虚机，niri 实测机）
- VMware Workstation：BIOS/MBR + GRUB + plymouth（HyprBuddy 主题）+ open-vm-tools
- 显卡：VMware SVGA（modesetting）。**必须在宿主机关闭「加速 3D 图形」**：
  **必须开启 3D 加速**（niri 跳过软件 EGL 渲染器）；vmwgfx 的 dmabuf 导入残缺，开启 3D 加速时 COSMIC Workspaces 缩略图等客户端
  会因协议错误 7 崩溃循环；关闭后 mesa 全栈自动回落 swrast（详见
  hosts/vmware/default.nix 注释）
- 会话：Hyprland + niri，默认登录 niri
- 登录器：SDDM（HyprBuddy 主题）；输入法 fcitx5 + 拼音

### vm-virtio（aarch64，v0 实测目标）
- 宿主：aarch64 Kylin；KVM/libvirt 域 nixos，6 vCPU / 8 GiB RAM
- 显卡：QEMU virtio-gpu（modesetting + Mesa），分辨率 1280x800（DRM preferred）
- 登录器：SDDM（catppuccin-mocha-mauve），默认会话 hyprland-uwsm
- agent 层：已开启，Waybar 显示当日 agent 用量

宿主机要求：可访问 mirrors.tuna.tsinghua.edu.cn（nixpkgs 走清华 nixexprs，不依赖 GitHub）。

## 目录结构

\`\`\`
hyprland-nixos/
├── flake.nix            # nixosConfigurations / packages(per-host home + iso / liveIso) / checks
├── flake.lock           # nixpkgs 指向清华 nixos-26.05 nixexprs
├── install.sh           # 构建 home 配置树并软链到 ~/.config / ~/.local/bin / ~/.codebuddy/skills
├── modules/             # options / base / boot / users / desktop(hyprland+niri+sessions) / hardware-gpu / agent
├── hosts/
│   ├── leonard/         # x86_64 + NVIDIA（双会话并存）
│   ├── vmware/          # x86_64 + VMware SVGA（niri 默认）
│   ├── vm-virtio/       # aarch64 + virtio（v0 实测）
│   └── _template/       # 模板（不参与构建）
├── home/                # hypr(hyprland.lua) / waybar / fuzzel / swaync / eww / hyprshell / fastfetch / kitty / swayosd
├── lib/                 # waybar.nix / agent-usage.nix
├── scripts/             # agent-apply / desktop-check / hypr-check / lib/de.sh（能力层）/ theme-next / hypr-menu / ...
├── skills/              # agent 技能：nixos-desktop-settings / diagnose-crash
├── installer/           # iso-config.nix（安装盘）/ live-iso-config.nix（live+install 一体盘）/ install.sh
├── wallpapers/
└── docs/                # desktop-abstraction / KEYBINDS / TROUBLESHOOTING / ROADMAP / ng-shell / AGENT-LAYER / themes/
\`\`\`

## 设计文档

- docs/desktop-abstraction.md：桌面提供方抽象（选项 / 能力契约 / P0–P5 阶段与实测记录）
- docs/ARCHITECTURE-REVIEW.md：评估结论与结构性硬伤
- docs/IMPLEMENTATION-PLAN.md：flake + options + host 的目标结构与实施步骤
- docs/AGENT-LAYER.md：agent 六层架构与实测状态
- docs/ng-shell.md：hyprshell / 外壳组件设计与实测状态
- docs/KEYBINDS.md：Hyprland 键位全表（niri 键位见 home/niri/config.kdl）
- docs/niri-noctalia-plan.md：niri + Noctalia 第三提供方接入实施方案（N0–N5）

## 已实现的功能

### 系统层（modules/）
- 桌面提供方抽象：\`distro.desktop.sessions\`（装哪些）+ \`distro.desktop.default\`
  （默认登录哪个，断言必须在 sessions 内）；SDDM 为每项生成会话
  （hyprland → hyprland-uwsm，niri → niri），\`sessions.nix\` 分发默认会话
- Hyprland 提供方：programs.hyprland（withUWSM）、Lua 配置管理器（hyprland.lua，
  为 hyprshell 的 eval 键位铺路）、0.55 规则语法（match: 前缀）
- niri 提供方：programs.niri + noctalia-shell + gnome/gtk 门户（与 Hyprland
  门户分会话声明，避免截图/共享抢占）；Noctalia 自带 panel/launcher/通知/
  settings/bg/screenshot/osd/lock，无需外壳组件
- SDDM：主题 HyprBuddy（自绘上拉菜单会话选择）/ catppuccin-mocha-mauve；
  greeter 分辨率跟随 DRM preferred
- vmware 客户机适配：open-vm-tools、vmwgfx 进 initrd（plymouth）、关闭 3D 加速
  下的软件渲染路径（见 hosts/vmware/default.nix 注释）
- 按 distro.gpu.vendor 选择 nvidia / amd / intel / virtio 驱动模块
- 字体：文泉驿（wqy-zenhei）统一中文（COSMIC/GTK/Qt 共用 fontconfig）+
  noto-fonts-cjk-sans + nerd-fonts.jetbrains-mono

### 用户层（home/ + scripts/）
- Hyprland：渐变边框、模糊、阴影、动画、完整键位；配置由 Lua 管理器托管
- Waybar：胶囊分组样式 + Nerd Font 图标 + 工作区 1-4 常驻；agent 用量模块
- fuzzel：应用启动器 + Super+Space 系统菜单（分组信息架构）+ 快捷键参考
- 通知：swaync 通知中心 + 控制中心（勿扰 / 历史 / MPRIS，已替代 mako）
- 窗口总览 / Alt-Tab 缩略图：hyprshell（依赖 Lua 配置管理器；样式随主题）
- eww 弹窗：日历 / 会话面板 / 系统信息（跟随焦点显示器）
- fastfetch：配置随主题联动（OS / 主题 / Agent 三项定制）
- 能力层 de.sh：壁纸 / 截图标注 / 锁屏 / 通知 / 显示器 / 主题应用等能力分派
  （Hyprland / niri 双实现），wallpaper-next / screenshot-annotate /
  night-mode 已接入
- 主题系统（P2）：`themes/<slug>/tokens.json` 唯一真相 + `exporters/{hyprland,
  niri}/*` 输出端拆分；theme-next 只做编排；niri 经 `de_theme_apply`
  生成 Noctalia 配色方案 + 壁纸（详见 docs/niri-noctalia-plan.md）
- desktop-check：按桌面分派的自检（Hyprland → hypr-check 原有 8 组；
  niri → 13 项：进程 / portal / 壁纸守护 / 字体 / 命令 / 配色配置）
- theme-next：8 套主题热切换（编排器），联动 waybar / fuzzel / swaync / eww /
  hyprshell / swayosd / fastfetch / 壁纸；登录时 restore；theme-picker 预览选择器
- 其他：SwayOSD / hypridle / 夜间模式 / 录屏 / 截图标注 / 壁纸轮换（awww）

### Agent 层（modules/agent/ + lib/agent-usage.nix）
- 包与脚本：agent-menu（Super+Shift+Ctrl+A）/ agent-apply（求值→构建→交用户 switch）/ agent-theme-sync
- agent-usage：codebuddy / claude / opencode 三数据源，/cost 口径统计当日 output tokens
- diagnostics：coredump-watch + coredump-analyze（本地模型分析，需 localModels = true）
- agent-commands：机器可读命令清单（\`--json\` / \`list\` / \`show <name>\` / \`--category\`）；
  由 scripts/ 头部元数据在构建期生成，缺 @summary 直接构建失败，desktop-check 含一致性校验

### 技能（skills/，随 install.sh 部署）
- \`nixos-desktop-settings\`：路由器（铁律 / 决策树 / 示例表）+ 专题指南
  （workflow / hyprland / bar-notify / theming / agent / troubleshooting）
- \`diagnose-crash\`：崩溃 / 段错误 / core dump 分析，优先读 diagnostics 自动报告
- 分发：install.sh 链接到 \`~/.codebuddy/skills/\`；\`~/.claude\` 存在时同步到 \`~/.claude/skills/\`

### 镜像
- installer ISO（\`.#packages.<system>.iso\`）：root 文本界面 + \`install-hyprland-nixos\`
- live ISO（\`.#packages.<system>.liveIso\`）：live+install 一体盘，SDDM 自动登录
  \`live\`（密码 live，wheel，免密 sudo，SSH 密码登录），保留安装器；agent 层已开启

## host 与 distro 选项

每个 hosts/<host>/default.nix 只写 distro.*：

\`\`\`nix
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "vmware";
  system.stateVersion = "26.05";

  distro = {
    hypervisor = "vmware";            # none / vmware / qemu
    gpu.vendor = "virtio";
    desktop = {
      sessions = [ "hyprland" "niri" ];     # 装哪些桌面（断言 default 必须在其中）
      default = "niri";                      # SDDM 默认登录哪个
    };
    user.name = "leonard";
    hardware.battery = false;

    agent = {
      enable = true;
      agents = [ "opencode" "codebuddy" ];
      usage = true;
    };
  };
}
\`\`\`

| 选项 | 取值 | 作用 |
|---|---|---|
| distro.desktop.sessions | hyprland / niri 列表 | 装哪些桌面提供方（可并存） |
| distro.desktop.default | hyprland / niri | SDDM 默认登录会话 |
| distro.hypervisor | none / vmware / qemu | 虚拟化平台（兼容设置） |
| distro.gpu.vendor | nvidia / amd / intel / virtio / none | 选择 GPU 模块 |
| distro.gpu.nvidia.branch | auto / legacy_580 / production / beta | auto 按 pciIds 判断 |
| distro.hardware.battery / backlight | bool | 影响 Waybar 与键位 |
| distro.agent.* | enable / agents / usage / diagnostics / localModels / model | agent 层 |

> NVIDIA 必须留在 580 LTSB：26.05 的 nvidiaPackages.stable 已指向 595.x，该分支不支持 Pascal，误用会黑屏。
> niri 会话在 VMware 上需要宿主**开启** 3D 加速（niri 跳过软件 EGL，见「环境 · vmware」）。

## 部署

\`\`\`bash
# 用户级：构建 home 配置树并软链（~/.config、~/.local/bin、~/.codebuddy/skills；自动创建 GC root）
./install.sh --host vmware --yes

# 系统级（只装新世代，重启生效）
sudo nixos-rebuild boot --flake .#vmware

# 或立即切换
sudo nixos-rebuild switch --flake .#vmware
\`\`\`

然后注销重登（或重启）让会话与守护进程生效。install.sh 末尾自动跑
\`desktop-check\`（按当前桌面分派检查项）。

home 配置由 home/default.nix 生成（nix build .#<host> 可看产物），~/.config、
~/.local/bin 与 skills 都是指向 store 的软链；install.sh 通过 --out-link 建立
GC root，nix-collect-garbage 不会让软链悬空。被替换的真实文件备份在
\`~/.config.bak-<时间戳>/\`。

agent 或自动化改动走统一入口 \`scripts/agent-apply <host>\`：\`git diff --stat\` →
\`nix eval\` 求值 → \`nixos-rebuild build\` → 打印需要用户执行的 sudo 命令（agent
不执行 sudo）。

## 实测状态

- vm-virtio（aarch64）：v0 端到端验证完成（构建 / 部署 / 登录 / live ISO，
  详见 git 历史与 docs/KEYBINDS.md）
- vmware（x86_64）：niri 桌面日用中（Noctalia 外壳，主题/壁纸跟随）；历史 COSMIC 的 Workspaces 缩略图问题已通过宿主机
  关闭 3D 加速解决（vmwgfx dmabuf 上游缺陷，排查记录见 hosts/vmware/default.nix）
- leonard（x86_64 + NVIDIA）：Hyprland 默认；niri 会话已构建（待实测）
  （NVIDIA + smithay 组合待实测，见 desktop-abstraction.md 风险表）

### 注意事项
- flake.lock 的 nixpkgs narHash 已更新到清华镜像当前内容；频道刷新后若校验失败，执行 nix flake update nixpkgs。
- SDDM 0.21 (Qt6) 需要给 sddm-wrapped 补 bin/sddm-greeter 符号链接，否则主题回退到 fallback（已在 modules/desktop/hyprland.nix 处理）。
- hosts/vm-virtio/default.nix 里的 SSH 公钥为测试用途，正式使用前请替换。
- ISO 产物按架构：installer 用 \`nix build .#packages.<system>.iso\`，live 用 \`nix build .#packages.<system>.liveIso\`。
- live 盘激活脚本只建 \`~/.local\`，\`~/.local/bin\` 必须是指向 store 的软链；误建成真实目录会让绝对路径绑定失效。

## 修改配置

- 改外观/键位 → 改 home/ 或 home/default.nix，再 ./install.sh --host <host>
- 改系统能力 → 改 modules/，再 sudo nixos-rebuild switch --flake .#<host>
- 改机器参数 → 改 hosts/<host>/default.nix（只写 distro.*）
- 改桌面能力 → 改 scripts/lib/de.sh（Hyprland / niri 双实现同步维护）
- 改技能 → 改 skills/，install.sh 会自动重新链接
- 不确定入口 → agent-commands list（或 --json）查询命令、参数、副作用、是否需 sudo
- 完整工作流与示例见技能 \`nixos-desktop-settings\`（docs/SKILL-REDESIGN.md 为设计说明）

## 安装到新机器

\`\`\`bash
# 通用安装盘（root 文本界面）
nix build .#packages.<system>.iso
# live+install 一体盘（直接进桌面试用，仍可安装）
nix build .#packages.<system>.liveIso

sudo dd if=result/iso/hyprland-nixos-live.iso of=/dev/sdX bs=4M status=progress oflag=sync
\`\`\`

installer 镜像启动后以 root 登录，分区并挂载到 /mnt，然后执行 installer/install.sh
（安装器不分区、不格式化）。live 镜像启动后直接进入桌面（用户 live / 密码 live），
并保留 \`install-hyprland-nixos\` 命令。

## 快捷键

完整列表见 docs/KEYBINDS.md（niri 键位见 home/niri/config.kdl）。常用：Super+Return（kitty）、
Super+D（fuzzel）、Super+Space（系统菜单）、Super+Shift+T（切换主题）、Super+L（锁屏）、
Super+Q（关闭）、Super+V（剪贴板）、Print（截图）。

## 主题

内置 8 套主题，\`theme-next\` 循环切换（Super+Shift+T），\`theme-next restore\` 在
登录时应用已保存主题，联动 waybar / fuzzel / swaync / eww / hyprshell / swayosd /
fastfetch / 壁纸。默认 Kanagawa：背景 #1F1F28 / #16161D，前景 #DCD7BA，
强调 #7E9CD8 / #957FB8，绿 #76946A，黄 #DCA561，红 #FF5D62，青 #7AA89F，
粉 #D27E99，橙 #FFA066。

## 为什么用 SDDM 而不是 LightDM

LightDM 启动 Wayland 会话时破坏 seat/输入设备交接（Hyprland 起来但键鼠全死）；
TTY 直接启动正常。换 SDDM 后问题消失。详见 docs/TROUBLESHOOTING.md。

## 后续路线

- 桌面抽象 P2–P5（主题 token 拆分 → COSMIC 功能对齐 → 默认切换 → Hyprland 退役），
  见 docs/desktop-abstraction.md
- 桌面功能差距（对照 omarchy），见 docs/ROADMAP.md
