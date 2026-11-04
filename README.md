# NixOS 桌面配置（niri + Noctalia v5 · distro/v1-nn）

flake 化的桌面配置：SDDM → **唯一的 niri 会话**（滚动平铺合成器 26.04）+
**Noctalia v5**（`pkgs.noctalia` 5.0.1，原生 C++ 运行时，非 v4 的 quickshell）。
Hyprland / COSMIC 于 2026-10-28 在 `distro/v1-nn` 退役，历史版本见 `distro/v1-cosmic`。
按 host 选择架构 / GPU / 虚拟化适配；桌面能力通过 `scripts/lib/de.sh` 抽象层收敛。

- 共享底座（SDDM / fcitx5 / Qt / polkit / 通用 CLI）在 `modules/desktop/hyprbuddy.nix`
- 主题：`themes/<slug>/tokens.json` → `exporters/niri/theme.sh` → `theme.toml`（外壳壁纸取色）+ kitty/fuzzel 精确 16 色
- 分支：`distro/v1-cosmic`（Hyprland + COSMIC，历史）/ `distro/v1-nn`（当前）
- 文档总入口：`docs/INDEX.md`（现行规范 / 历史归档 / 设计稿 三类索引）；
  常用：`docs/ROADMAP.md`（路线与进度）、`docs/SKILLS.md`（技能路由）、`docs/KEYBINDS.md`（键位速查）

## 环境

### vmware（x86_64 虚机，当前实测机）
- VMware Workstation：BIOS/MBR + GRUB + plymouth（HyprBuddy 主题）+ open-vm-tools
- 显卡 VMware SVGA（modesetting）；宿主机关闭「加速 3D 图形」后 mesa 回落 swrast/llvmpipe，
  niri + Noctalia v5 在软渲染下实测可用（首帧约 200ms）。历史上 COSMIC Workspaces 的
  dmabuf 崩溃问题随 COSMIC 退役已不存在
- 会话：niri（唯一）；登录器 SDDM（HyprBuddy 主题）；输入法 fcitx5 + 拼音
- agent 层关闭（`distro.agent.enable = false`）；夜间模式启用（IP 定位，6500/4000K）

### leonard（x86_64 真机，NVIDIA）
- GTX 1050 Ti + 闭源驱动 legacy_580（580.178.04）+ `nvidia-drm.modeset=1`
- `desktop.sessions = [ "niri" ]`、`default = "niri"`；agent 层开启（opencode + codebuddy，含 usage）
- 尚未在真机上验证 Noctalia v5（见 `docs/ROADMAP.md` 的「P1 暂缓」）

### vm-virtio（aarch64 虚机）
- QEMU virtio-gpu（modesetting + Mesa），分辨率 1280x800；`stateVersion = "25.11"`，用户 `nixos`
- 未显式设 sessions，取默认值 `[ "niri" ]`；agent 层开启（验证 agent-usage）
- 尚未在真机上验证 Noctalia v5

宿主机要求：可访问 mirrors.tuna.tsinghua.edu.cn（nixpkgs 走清华 nixexprs，不依赖 GitHub）。

## 目录结构

```
hyprland-nixos/
├── flake.nix            # nixosConfigurations / packages(per-host home + iso / liveIso) / checks
├── flake.lock           # nixpkgs 指向清华 nixos-26.05 nixexprs
├── install.sh           # 构建 home 配置树并软链到 ~/.config / ~/.local/bin / ~/.codebuddy/skills
├── modules/             # options / assertions / desktop(hyprbuddy+niri+sessions) / base / boot / users / hardware/gpu / agent
├── hosts/               # leonard / vmware / vm-virtio / _template（模板不参与构建）
├── home/                # default.nix（linkFarm）/ niri / kitty / fuzzel / fastfetch / thunar / kitty-egl.sh
├── lib/                 # commands.nix / gen-commands.py / agent-usage.nix
├── exporters/           # lib.sh + niri/theme.sh（tokens → 主题产物）
├── scripts/             # 27 个文件，26 条命令（agent-commands --json 可查）
├── skills/              # 5 个技能 / 13 篇：nixos-desktop-settings / nixos-system-ops / theme-create / scifi-ui / diagnose-crash
├── installer/           # iso-config.nix / live-iso-config.nix / install.sh / detect.sh / render-host.sh
├── themes/              # 10 套 <slug>/tokens.json
├── wallpapers/
└── docs/                # 现行规范 + 已标注的历史/设计稿（见下节）
```

## 文档导航

**现行规范（以代码为准）**

- `docs/ROADMAP.md`：当前形态、P0–P3 进度与暂缓项
- `docs/SKILLS.md`：5 个技能的分工、路由、技能×命令矩阵
- `docs/KEYBINDS.md`：文末「niri 当前键位」表（中间表格是 Hyprland 历史对照）
- `docs/agent-coverage-review.md`：agent 层 26 条命令的覆盖度与 P0–P3 记录
- `skills/nixos-desktop-settings/`：桌面配置入口（决策树、流程、v5 排障）
- `skills/nixos-system-ops/`：系统运维只读命令与更新回滚

**历史 / 设计稿（勿按现状引用）**：`docs/desktop-abstraction.md`、`niri-noctalia-plan.md`、
`desktop-retire-hyprland.md`、`cosmic-*.md` ×7、`ng-shell*.md`、`eww-start-menu.md`、
`ARCHITECTURE-REVIEW.md`、`IMPLEMENTATION-PLAN.md`、`AGENT-LAYER.md`、
`TROUBLESHOOTING-hyprland-era.md`（原根目录同名文件，已改名）、`theme-tokens.md`、
`ux-capabilities.md`、`SKILL-REDESIGN.md`、`COMMANDS-JSON.md`。
这些文件头部均已加统一状态横幅；排障请以 `skills/nixos-desktop-settings/troubleshooting.md` 为准。

## 已实现的功能

### 系统层（modules/）
- 桌面提供方抽象：`distro.desktop.sessions`（enum 当前只允许 `"niri"`）+ `default`，
  断言 default 必须在 sessions 内；`sessions.nix` 分发默认会话
- niri 提供方（`modules/desktop/niri.nix`）：`programs.niri` + `pkgs.noctalia` +
  `xwayland-satellite` + gnome/gtk 门户；并启用 `services.upower`、`hardware.bluetooth`、
  `security.pam.services.noctalia`（锁屏认证）
- 共享底座（`hyprbuddy.nix`）：SDDM 主题、fcitx5 输入法及自启、polkit KDE 代理
  （包装脚本解决启动竞态与认证框样式问题）、字体、通用 CLI
- `distro.desktop.nightlight`：夜间模式声明式配置（autoLocate / address / 经纬度 / 固定日程 / 色温），
  生成 `~/.config/noctalia/nightlight.toml`
- 按 `distro.gpu.vendor` 选择 nvidia / amd / intel / virtio 驱动；vmware 适配见对应 host
- 字体：文泉驿 + noto-fonts-cjk-sans + nerd-fonts.jetbrains-mono

### 用户层（home/ + scripts/）
- niri：`home/niri/config.kdl` 声明 60 条键位（窗口/列/工作区/面板/媒体键/锁屏/截图/录屏），
  媒体键 `allow-when-locked=true`；部署后 `niri msg action load-config-file` 生效
- Noctalia v5：面板 / launcher / 通知 / 锁屏 / OSD / 夜间模式 / 壁纸 / 截图 overlay，
  IPC 为 `noctalia msg <cmd>`（脚本与键位都走它）
- 主题系统（P2）：`themes/<slug>/tokens.json` 唯一真相；`exporters/niri/theme.sh` 写
  `~/.config/noctalia/theme.toml`（`source="wallpaper"` 取色）+ kitty 16 色 + fuzzel 配色；
  `theme-next` 编排，`theme-picker` 预览，`de-theme-apply <slug>` 直接应用
- 能力层 `scripts/lib/de.sh`：壁纸 / 截图 / 锁屏 / 通知 / 显示器 / 主题应用（当前只有 niri 分支）
- `desktop-check`：18 项自检（进程、portal、壁纸、bar、字体、命令、键位命令存在性、
  壁纸目录、夜间模式日程、配置告警），非图形会话自动降级
- 其他：cliphist + fuzzel 剪贴板历史、grim/slurp/swappy 截图标注、wf-recorder 录屏

### Agent 层（modules/agent/ + lib/agent-usage.nix）
- agent 脚本随 `distro.agent.enable` 部署（vmware 为 false，leonard / vm-virtio 为 true）
- `agent-commands`：机器可读命令清单（`--json` / `list` / `show <name>` / `--category`），
  由脚本头部 `@command` 元数据在构建期生成，缺 `@summary` 直接构建失败
- 系统运维命令：`sys-health` / `svc-status` / `sys-log` / `sys-rollback` / `sys-gc` /
  `sys-update` / `net-status` / `power-status`（全部只读或只打印 sudo 命令）

### 技能与镜像
- 5 个技能随 `install.sh` 软链到 `~/.codebuddy/skills/`（`~/.claude` 存在时同步）
- installer ISO（`.#packages.<system>.iso`）：root 文本界面 + `install-hyprland-nixos`
- live ISO（`.#packages.<system>.liveIso`）：live+install 一体盘，保留安装器

## host 与 distro 选项

每个 `hosts/<host>/default.nix` 只写 `distro.*`：

```nix
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "vmware";
  system.stateVersion = "26.05";

  distro = {
    hypervisor = "vmware";       # none / vmware / qemu
    gpu.vendor = "virtio";
    desktop = {
      sessions = [ "niri" ];     # 当前只允许 niri（类型 listOf (enum [ "niri" ])）
      default = "niri";
      nightlight = { enable = true; autoLocate = true; };
    };
    user.name = "leonard";
    hardware.battery = false;
    hardware.backlight = false;
    agent = { enable = false; };
  };
}
```

| 选项 | 取值 | 作用 |
|---|---|---|
| `distro.desktop.sessions` | `[ "niri" ]` | 装哪些桌面提供方 |
| `distro.desktop.default` | `"niri"` | SDDM 默认登录会话 |
| `distro.desktop.nightlight` | 见 `modules/options.nix` | 夜间模式（定位、日程、色温） |
| `distro.hypervisor` | none / vmware / qemu | 虚拟化兼容设置 |
| `distro.gpu.vendor` | nvidia / amd / intel / virtio / none | 选择 GPU 模块 |
| `distro.gpu.nvidia.branch` | auto / legacy_580 / production / beta | auto 按 pciIds 判断 |
| `distro.hardware.battery / backlight` | bool | 影响 bar 组件与键位 |
| `distro.agent.*` | enable / agents / usage / diagnostics / localModels / model | agent 层 |

> NVIDIA 必须留在 580 LTSB：26.05 的 `nvidiaPackages.stable` 已指向 595.x，该分支不支持 Pascal，误用会黑屏。

## 部署

```bash
# 用户级：构建 home 配置树并软链（~/.config、~/.local/bin、~/.codebuddy/skills；自动创建 GC root）
./install.sh --host vmware --yes

# 系统级（只装新世代，重启生效）
sudo nixos-rebuild boot --flake .#vmware

# 或立即切换
sudo nixos-rebuild switch --flake .#vmware
```

`nixos-rebuild switch` 只换 `/run/current-system`，**用户级配置必须单独跑 `install.sh`**；
涉及 `home/` `scripts/` `skills/` 的改动，部署后再 `niri msg action load-config-file`（或重登）。
`install.sh` 末尾自动跑 `desktop-check`；被替换的真实文件备份在 `~/.config.bak-<时间戳>/`。

agent / 自动化改动走 `scripts/agent-apply <host>`：`git diff --stat` → `nix eval` →
`nixos-rebuild build` → 打印需要用户执行的 sudo 命令（agent 不执行 sudo）。
注意 **flake 只认 git 跟踪的文件**：先 commit 再 install，未提交改动不会进 store。

## 实测状态（2026-11-04）

- vmware（x86_64）：niri + Noctalia v5 日用中；桌面自检通过、夜间模式色温已下发
- leonard / vm-virtio：仅做过求值，尚未实机登录验证 v5（`docs/ROADMAP.md` 暂缓项）
- 安装镜像：v5 切换后尚未重建验证（`docs/ROADMAP.md` P2）

### 注意事项
- flake.lock 的 nixpkgs narHash 对应清华镜像内容；频道刷新后校验失败时执行 `nix flake update nixpkgs`
- SDDM 0.21 (Qt6) 的 `sddm-greeter` 符号链接处理在 `modules/desktop/hyprbuddy.nix`
- `hosts/vm-virtio/default.nix` 里的 SSH 公钥为测试用途，正式使用前请替换
- ISO 产物按架构：installer 用 `nix build .#packages.<system>.iso`，live 用 `.#packages.<system>.liveIso`
- `~/.local/bin` 必须是指向 store 的软链；误建成真实目录会让绝对路径绑定失效

## 修改配置

- 改外观/键位 → `home/niri/config.kdl`，再 `./install.sh --host <host> --yes`
- 改系统能力 → `modules/`，再交用户 `sudo nixos-rebuild switch --flake .#<host>`
- 改机器参数 → `hosts/<host>/default.nix`（只写 `distro.*`）
- 改桌面能力 → `scripts/lib/de.sh`（当前只有 niri 分支）
- 改技能 → `skills/`，`install.sh` 自动重新链接
- 不确定入口 → `agent-commands list`（或 `--json`）

## 安装到新机器

```bash
nix build .#packages.<system>.iso       # 通用安装盘（root 文本界面）
nix build .#packages.<system>.liveIso   # live+install 一体盘
sudo dd if=result/iso/hyprland-nixos-live.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

installer 镜像启动后以 root 登录，分区并挂载到 /mnt，然后执行 `installer/install.sh`
（安装器不分区、不格式化）。live 镜像直接进入桌面，保留 `install-hyprbuddy` 命令。

## 快捷键

完整列表见 `docs/KEYBINDS.md`（源文件 `home/niri/config.kdl`）。常用：
`Mod+Return`（kitty）、`Mod+D`（Noctalia 启动器）、`Mod+Tab`（窗口切换器）、
`Mod+Shift+C/P/S`（控制中心 / 会话 / 设置）、`Mod+Shift+T`（主题选择器）、
`Mod+L`（锁屏）、`Mod+V`（剪贴板历史）、`Mod+Alt+R`（录屏）、`Print`（区域截图）。

## 主题

内置 **10 套**主题（`themes/<slug>/tokens.json`）：`theme-next` 循环切换、`theme-next restore`
登录时应用已保存主题、`theme-picker` 预览。切换时 kitty / fuzzel 用 tokens 的精确 16 色，
外壳配色由主题壁纸取色（`source="wallpaper"`）。两者同源于同一次切换，但外壳配色不等于 tokens。
新增主题见技能 `theme-create` 与 `skills/nixos-desktop-settings/theming.md`。

## 后续路线

见 `docs/ROADMAP.md`：P2 剩 ISO 重建，P3 为长期项；自定义调色板与多 host 实机验证暂缓。
