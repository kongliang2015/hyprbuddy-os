# 实施计划：从配置仓库到发行版骨架

> 前置评估见 [ARCHITECTURE-REVIEW.md](./ARCHITECTURE-REVIEW.md)。
> 目标：用 5 个阶段把 `26.05-dev` 的"单机模板"改造成 `flake + options + host` 结构，过程中系统始终可回滚。

## 1. 设计原则

1. **选项优先于覆盖**：所有机器差异走 `distro.*` 选项，禁止在 profile 里 `mkForce` 主配置。
2. **探测只在安装期**：Nix 求值期不猜硬件，安装器读 `lspci` 后写 `hosts/<host>/default.nix`，求值期只读结果。
3. **文件即接口**：agent 只操作三处——`hosts/<host>/default.nix`（机器参数）、`modules/`（能力）、`home/`（外观资产），全部在 git 内、可 diff、可 `nix flake check`。
4. **双轨过渡**：channel 方式在 P2 之前保持可用，任一阶段失败可 `git revert` + 重启旧世代。

## 2. 目标结构

```
flake.nix                      # inputs: nixpkgs(nixos-26.05) + home-manager(release-26.05)
flake.lock
hosts/
  leonard/
    default.nix                # 本机：GPU=nvidia(Pascal)、无电池/背光、保留 XFCE/WM
    hardware-configuration.nix # nixos-generate-config 产物（磁盘/UUID）
  vm-virtio/
    default.nix
    hardware-configuration.nix
  _template/default.nix        # 安装器渲染用模板（6 个变量）
modules/
  default.nix                  # 汇总 imports
  options.nix                  # distro.* schema（本发行版唯一对外接口）
  assertions.nix               # 跨选项一致性检查
  base.nix                     # locale / 时区 / nix 设置 / 镜像 / 防火墙 / SSH
  boot.nix                     # systemd-boot（+ Windows 链式条目）/ grub 分支
  users.nix                    # 用户、组、initialPassword 策略
  desktop/
    hyprland.nix               # programs.hyprland + SDDM + fcitx5 + 字体 + 桌面包
    sessions.nix               # 按 extraSessions 启用 XFCE / Window Maker
  hardware/
    gpu.nix                    # 按 vendor 分发到下面四个
    gpu/nvidia.nix             # branch 解析 + nvidia 模块参数
    gpu/amd.nix                # amdgpu + Mesa + VA-API
    gpu/intel.nix              # i915/xe + intel-media-driver
    gpu/virtio.nix             # modesetting + Mesa
  agent/
    core.nix                   # 层1 入口：agent 包 + 快捷键 + agent-menu
    diagnostics.nix            # 层3 coredump 诊断
    usage.nix                  # 层4 用量面板（waybar custom）
    local-llm.nix              # 层6 ollama + 按 GPU 选加速
installer/
  detect.sh                    # 探测 GPU / 引导器 / 磁盘
  render-host.sh               # 用 _template 生成 hosts/<host>/default.nix
  install.sh                   # 串起：探测 → 渲染 → disko(可选) → nixos-install --flake
  iso.nix                      # nixos-generators ISO 定义
home/                          # 外观资产（保持不变）
home-modules/                  # HM 模块：把资产按 host 选项渲染进 ~/.config（P4）
scripts/                       # 用户级脚本（保持不变）
docs/
```

## 3. 核心文件骨架

### 3.1 `flake.nix`

```nix
{
  description = "AI-agent 原生的 NixOS + Hyprland 发行版";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      hosts = [ "leonard" "vm-virtio" ];
      mkHost = name: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/${name}
          ./modules
          home-manager.nixosModules.home-manager
          { networking.hostName = name; }
        ];
      };
    in
    {
      nixosConfigurations = nixpkgs.lib.genAttrs hosts mkHost;

      # 每个 host 强制求值 + instantiate，CI / 本地一次跑完
      checks.x86_64-linux = nixpkgs.lib.genAttrs hosts (name:
        self.nixosConfigurations.${name}.config.system.build.toplevel);

      packages.x86_64-linux.iso =
        (nixpkgs.legacyPackages.x86_64-linux.callPackage ./installer/iso.nix { }).config.system.build.isoImage;
    };
}
```

> 注意：`nixosConfigurations` 不会被 `nix flake check` 自动检查，必须像上面这样显式放进 `checks`。

### 3.2 `modules/options.nix`

```nix
{ lib, ... }:
let inherit (lib) mkOption types;
in
{
  options.distro = {
    version = mkOption { type = types.str; default = "0.1.0-dev"; };

    gpu = {
      vendor = mkOption {
        type = types.enum [ "nvidia" "amd" "intel" "virtio" "none" ];
        default = "virtio";
      };
      nvidia = {
        pciIds = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "10de:1c82" ];
          description = "vendor:device 列表，branch=auto 时用于推断驱动分支";
        };
        branch = mkOption {
          type = types.enum [ "auto" "legacy_580" "production" "beta" ];
          default = "auto";
        };
        open = mkOption { type = types.bool; default = false; };
      };
    };

    desktop = {
      enable = mkOption { type = types.bool; default = true; };
      extraSessions = mkOption {
        type = types.listOf (types.enum [ "xfce" "windowmaker" ]);
        default = [ ];
      };
    };

    hardware = {
      battery = mkOption { type = types.bool; default = false; };
      backlight = mkOption { type = types.bool; default = false; };
      bluetooth = mkOption { type = types.bool; default = true; };
    };

    homeManager.mode = mkOption {
      type = types.enum [ "module" "standalone" ];
      default = "module";
    };

    agent = {
      enable = mkOption { type = types.bool; default = true; };
      agents = mkOption {
        type = types.listOf (types.enum [ "claude-code" "opencode" "codex" "aider-chat" ]);
        default = [ "claude-code" ];
      };
      diagnostics = mkOption { type = types.bool; default = true; };
      usage = mkOption { type = types.bool; default = true; };
      localModels = mkOption { type = types.bool; default = false; };
    };
  };
}
```

### 3.3 `modules/hardware/gpu.nix` + `gpu/nvidia.nix`

```nix
# gpu.nix —— 只做分发，不含任何硬件细节
{ config, ... }:
{
  imports = [ ./gpu/${config.distro.gpu.vendor}.nix ];
}
```

```nix
# gpu/nvidia.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.distro.gpu.nvidia;

  # GTX 16xx / RTX 20xx 及更新的 device id 均 >= 0x1E00；
  # Maxwell / Pascal / Volta 小于该值，只能用 580 LTSB。
  isTuringOrNewer = id:
    let dev = lib.toInt ("0x" + lib.last (lib.splitString ":" id));
    in dev >= 0x1E00;

  resolved =
    if cfg.branch != "auto" then cfg.branch
    else if cfg.pciIds == [ ] then "legacy_580"    # 580 覆盖 Maxwell→Blackwell，是安全兜底
    else if lib.any isTuringOrNewer cfg.pciIds then "production"
    else "legacy_580";
in
{
  warnings = lib.optional (cfg.branch == "auto" && cfg.pciIds == [ ])
    "distro.gpu.nvidia.branch=auto 但未提供 pciIds，已回退 legacy_580；请运行 installer/detect.sh 补充。";

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    branch = resolved;
    open = cfg.open;          # Pascal 及更早必须 false
    modesetting.enable = true;
    powerManagement.enable = true;
  };

  boot.kernelParams = [ "nvidia-drm.modeset=1" ];
}
```

```nix
# gpu/amd.nix
{ pkgs, ... }:
{
  services.xserver.videoDrivers = [ "modesetting" ];
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ libva-vdpau-driver libva-utils vulkan-tools ];
  };
  boot.initrd.kernelModules = [ "amdgpu" ];
}
```

```nix
# gpu/intel.nix
{ pkgs, ... }:
{
  services.xserver.videoDrivers = [ "modesetting" ];
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver intel-vaapi-driver libva-utils ];
  };
  boot.initrd.kernelModules = [ "i915" ];
}
```

### 3.4 `hosts/leonard/default.nix`

```nix
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];

  distro = {
    gpu = {
      vendor = "nvidia";
      nvidia = {
        pciIds = [ "10de:1c82" ];   # GTX 1050 Ti (GP107)
        branch = "auto";            # 由 pciIds 推出 legacy_580
        open = false;
      };
    };
    desktop.extraSessions = [ "xfce" "windowmaker" ];
    hardware.battery = false;
    hardware.backlight = false;
    homeManager.mode = "standalone";   # 本机现状：channel + home-manager switch
    agent = { enable = true; localModels = false; };
  };
}
```

### 3.5 `modules/assertions.nix`

```nix
{ config, lib, ... }:
{
  assertions = [
    {
      assertion = config.distro.gpu.vendor != "nvidia" || !config.distro.gpu.nvidia.open
                  || lib.versionAtLeast config.distro.gpu.nvidia.pciIds ... ;
      message = "Pascal 及更早架构不支持 open 内核模块，请设 distro.gpu.nvidia.open = false";
    }
    {
      assertion = config.distro.desktop.enable || config.distro.desktop.extraSessions == [ ];
      message = "未启用桌面时不能指定 extraSessions";
    }
  ];
}
```

> 上例第二行的代际判断在实现时改为调用 `gpu/nvidia.nix` 暴露的 `resolvedBranch`，避免重复逻辑。

## 4. 分阶段实施

### P0 · flake 化（不改任何结构）

- 新增 `flake.nix`、`flake.lock`；把现有 `system/configuration.nix` 原样搬成 `hosts/leonard/default.nix` 的 imports 内容（暂不放 options）。
- 保留 `install.sh` 与 channel 路径不动。

**验收**

```bash
nix flake check                                   # checks 通过
nixos-rebuild build --flake .#leonard             # 能构建
nix eval .#nixosConfigurations.leonard.config.services.xserver.videoDrivers
```

**回滚**：`git revert`，系统未变。

#### P0 验收记录（2026-10-19，分支 `distro/v0`）

| 检查 | 结果 |
|---|---|
| `nix flake lock` | ✅ 锁定 26.05.12192 tarball（narHash） |
| `nix flake check` | ✅ `checks.x86_64-linux.leonard-toplevel` 通过 |
| `nix build …system.build.toplevel` | ✅ 构建成功 |
| 关键选项 | ✅ `videoDrivers=["nvidia"]`、`nvidia=580.178.04`、XFCE+WM、`stateVersion=25.11`，与 `/etc/nixos` 一致 |
| 闭包内容 | ⚠️ 18 个文件不同，全部来自 NIX_PATH / nix registry（见下） |

差异根因（非配置差异）：

- channel 构建：`NIX_PATH` 含 `nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos`；
- flake 构建：`NIX_PATH` 为 `nixpkgs=flake:nixpkgs`，并在 `/etc/nix/registry.json` 注册输入路径；
- 其余 16 个文件（`etc/profile`、`etc/set-environment`、`activate`、`sw/bin/*` 等）都是引用这两者的级联结果。

结论：**包集合与服务集合完全一致**，差异只存在于"nixpkgs 从哪里解析"这条元数据上，属 flake/channel 固有差别，不追求消除。

实现细节两个坑（已在 `flake.nix` 注释）：

1. npm 之外的第一坑：flake 模式下 `lib.trivial.versionSuffix` 被 `lib/flake-version-info.nix` 覆盖为 `.19800101.dirty`（tarball 输入没有 git 元数据），必须直接读 `nixpkgs + "/.version-suffix"` 才能让 `nixos-version` 与 channel 一致。
2. 本机访问 `github.com` 被阻断，`nixpkgs` 输入改用清华镜像的 `nixexprs.tar.xz`，由 `flake.lock` 的 narHash 锁定；后续接入 home-manager 输入时需要单独的镜像方案。

### P1 · options schema + GPU 四厂商

- 落地 `modules/options.nix`、`modules/hardware/gpu*`、`modules/assertions.nix`。
- `hosts/leonard` 改为只写 `distro.*`；新增 `hosts/vm-virtio` 验证第二条路径。
- 删除 `system/profiles/leonard-nvidia.nix` 与 `system/configuration.nix`（由 modules 取代）。

**验收**

```bash
nix eval .#nixosConfigurations.leonard.config.hardware.nvidia.package.version   # 580.178.04
nix eval .#nixosConfigurations.vm-virtio.config.services.xserver.videoDrivers   # ["modesetting"]
nix build .#checks.x86_64-linux.leonard --dry-run
```

**判定标准**：改 `distro.gpu.vendor` 一个值，闭包按预期变化；不需要动任何其它文件。

#### P1 验收记录（2026-10-19，分支 `distro/v0`）

| 检查 | 结果 |
|---|---|
| `nix flake check` | ✅ 两个 host 全部通过（含 vm-virtio 实际构建） |
| `hosts/leonard` 闭包 | ✅ **与 P0 的派生路径完全相同**（`bcd7kk9a…`），证明纯重构未改变行为 |
| `hosts/vm-virtio` | ✅ `videoDrivers=["modesetting"]`、无 XFCE/WM、用户 `nixos` |
| 代码量 | `hosts/leonard` 从 327 行降到 30 行；`system/` 目录删除 |

三个实现坑（都已写进代码注释）：

1. **`imports` 不能依赖 `config`**。原计划 `imports = [ ./gpu/${config.distro.gpu.vendor}.nix ]` 会形成递归，
   改为四个厂商模块全部导入、各自用 `lib.mkIf` 包住模块体。
2. **Nix 的十六进制字面量只认小写**：`0x1E00` 会被解析成 `0` + 未定义变量 `x1E00`；
   `lib.toInt` 又不接受 `"0x..."`。最终自带 `hexToInt`（foldl + 数字表）解决。
3. **列表选项的合并顺序与 import 顺序相反**（实测）：把 `base.nix` 放在 `desktop/hyprland.nix` **之后**，
   `environment.systemPackages` 才会是 `nodejs` 在前，从而与重构前的闭包哈希一致。
   这条很反直觉，任何"闭包哈希对不上"的排查都应先看列表顺序。

### P2 · 安装器（探测 → 渲染 host → 安装）

```bash
# installer/detect.sh 输出
gpu_vendor=nvidia
gpu_pci_ids="10de:1c82"
boot=systemd-boot
battery=false
backlight=true
```

- `detect.sh`：`lspci -nn` 匹配 `10de/1002/8086/1af4`；`/sys/class/power_supply/BAT*` 判电池；`/sys/class/backlight/*` 判背光；`/sys/firmware/efi` 判引导方式。
- `render-host.sh`：`envsubst` 只替换 `hosts/_template/default.nix` 的 6 个变量，渲染后 `nix-instantiate --parse` 校验。
- `install.sh`：渲染 host →（可选 `disko` 分区）→ `nixos-install --flake .#${hostname} --root /mnt`。
- `iso.nix`：`nixos-generators.nixosGenerate` 产出带 `git`、`lspci`、仓库克隆步骤的安装镜像。

**验收**：在 virtio 虚拟机里用 ISO 完整装一遍，装完 `nvidia-smi` 不存在、`Hyprland` 正常；在真机上重装一次验证 NVIDIA 路径。

#### P2 验收记录（2026-10-20，分支 `distro/v0`）

| 组件 | 文件 | 说明 |
|---|---|---|
| 探测 | `installer/detect.sh` | `lspci` → GPU 厂商 + NVIDIA PCI id；`/sys/class/power_supply|backlight` → 笔记本特征；`/sys/firmware/efi`+`/boot/grub` → 引导器；`/boot/EFI/Microsoft` → Windows 项 |
| 渲染 | `installer/render-host.sh` | `hosts/_template/default.nix` 的 `@VAR@` 替换；空格分隔值自动转成 Nix 列表；渲染后 `nix-instantiate --parse` 校验 |
| 安装 | `installer/install.sh` | 探测 → 工作副本 → `nixos-generate-config` → 渲染 → 求值 → `nixos-install --flake` → 把仓库放进 `/home/<user>` |
| 镜像 | `installer/iso-config.nix` + flake `packages.<sys>.iso` | 最小 ISO + 仓库 + `install-hyprland-nixos` 包装命令 |

验证：

| 检查 | 结果 |
|---|---|
| `detect.sh` 在本机 | ✅ `systemd-boot` / `nvidia 10de:1c82` / 无电池 / 无背光 |
| 渲染合成 host（gt2） | ✅ 生成文件通过 `nix-instantiate --parse` |
| 渲染结果求值 | ✅ `videoDrivers=["nvidia"]`、`branch=legacy_580`、hostname=gt2、user=leonard |
| `install.sh --dry-run` 全流程 | ✅ 探测 → 计划 → 渲染 → 求值通过（未写盘） |
| ISO 求值 / 构建 | ✅ `nix build .#packages.x86_64-linux.iso` |

四个实现要点：

1. **flake 自动发现 `hosts/*`**：安装器渲染出的 host 立刻可 `nixosConfigurations.<host>`，无需改 flake。
   求值必须用 `path:$work/src#…` 前缀——直接用 `$work/src#…` 时 git 过滤会隐藏未提交的 host。
2. **安装器不分区**：`install.sh` 只接受已挂载的 `--target`，并默认要求确认；分区/格式化留给 disko 或人工，
   避免"一条命令抹盘"。这是有意为之的保守设计。
3. **模板占位符**：`hosts/_template` 用 `@VAR@` 占位，`render-host.sh` 负责把 `xfce windowmaker` 这类空格分隔值转成
   `"xfce" "windowmaker"`，并在渲染后检查是否残留占位符。
4. **ISO 里仓库不能放 `/etc`**：`environment.etc."<name>".source` 指向目录会让 ISO 的 `sources` 构建失败，
   改为 `runCommand` 打包成普通包，再用包装脚本 `install-hyprland-nixos` 调用。另：26.05 把
   `isoImage.isoName` 重命名为 `image.fileName`。

### P3 · agent 层（映射 `docs/AGENT-LAYER.md` 六层）

| 层 | 落点 | 关键实现 |
|---|---|---|
| 1 入口 | `modules/agent/core.nix` | `environment.systemPackages` 装 `distro.agent.agents`；快捷键通过 HM `wayland.windowManager.hyprland.settings.bind` 注入；`agent-menu` 放 `scripts/` |
| 2 主题 | `scripts/agent/theme-sync` | 只改 `~/.claude/settings.json` 的 `theme` 字段（jq merge，不覆盖） |
| 3 诊断 | `modules/agent/diagnostics.nix` | `systemd.paths.coredump-watch` + `systemd.services.coredump-analyze`（`User = config.distro.user`）；只用本地模型 |
| 4 观测 | `modules/agent/usage.nix` | 汇总 `~/.claude/projects/**/*.jsonl` → Waybar `custom/agent-usage` |
| 5 变更 | `scripts/agent/apply` | `git diff` → `nix flake check` → `nixos-rebuild build --flake .#$(hostname)` → 打印 sudo 命令 |
| 6 本地模型 | `modules/agent/local-llm.nix` | `services.ollama.enable`；`nvidia` 时 `hardware.nvidia` 已就绪，`amd` 时启用 ROCm 支持 |

**验收**：`distro.agent.enable = false` 时闭包中不含任何 agent 包与服务；开启后 `systemctl list-unit-files | grep coredump-analyze` 可见。

#### P3 验收记录（2026-10-19，分支 `distro/v0`）

六层落点：

| 层 | 文件 | 实现 |
|---|---|---|
| 1 入口 | `modules/agent/core.nix` | 按 `distro.agent.agents` 装包；`Super+Shift+Ctrl+A` → `scripts/agent-menu`（fuzzel 选择） |
| 2 主题 | `scripts/agent-theme-sync` | jq merge `~/.claude/settings.json` 的 `theme` 字段，不覆盖其它设置 |
| 3 诊断 | `modules/agent/diagnostics.nix` | `systemd.paths.coredump-watch` + `coredump-analyze`（oneshot，User=主用户，SupplementaryGroups=systemd-coredump）→ 本地 ollama → mako/日志 |
| 4 观测 | `modules/agent/usage.nix` | 汇总 `~/.claude/projects/**/*.jsonl` 当日 token，注入 Waybar `custom/agent-usage` |
| 5 变更 | `scripts/agent-apply` | `git diff` → 求值 → `nixos-rebuild build --flake` → 打印 sudo 命令 |
| 6 本地模型 | `modules/agent/local-llm.nix` | `services.ollama`，按 `distro.gpu.vendor` 选 `ollama-cuda/rocm/vulkan/cpu` |

验证：

| 检查 | 结果 |
|---|---|
| `agent.enable = false` | ✅ 无 agent 包、无 `custom/agent-usage`、无 coredump 单元 |
| `agent.enable = true` | ✅ 注入 `custom/agent-usage`，模块列表顺序 `… battery, custom/agent-usage, clock` |
| Waybar 基础配置 | ✅ 与旧文本逐键语义一致（仅序列化方式变化） |
| `diagnostics + localModels` | ✅ 生成 `coredump-watch`/`coredump-analyze`，ollama 派生路径等于 `pkgs.ollama-cuda` |
| `nix flake check` | ✅ 两 host 通过 |

三个必须记住的点：

1. **`claude-code` 在本机不可构建**：它的二进制从 `downloads.claude.ai` 拉（fetchurl），本机网络不可达，
   因此 `hosts/leonard` 暂时用 `opencode`（可替换、可离线）。枚举保留 `claude-code`，换到能访问的网络改一行即可。
2. **26.05 移除了 `services.ollama.acceleration`**：改用包变体 `ollama-{cuda,rocm,vulkan,cpu}`，
   且 CUDA 变体需要 `nixpkgs.config.allowUnfree`（base.nix 已开）。
3. **Waybar 配置改为 `builtins.toJSON` 生成**：为了给 agent/usage 之类的模块提供注入点
   （`distro.desktop.waybar{RightExtra,Config,CssExtra}`）。基础配置与旧文本逐键一致，
   但序列化方式变了，闭包哈希因此与 P1 不同——这属于预期变化，不再用哈希做等价判据。

### P4 · 用户层声明化（把 `cp + sed` 换成 HM 模块）

现状 `install.sh` 把 `home/` 拷进 `~/.config` 再 `sed` 替换路径。改为 Home Manager 生成：

| 现状 | 目标 |
|---|---|
| `home/hypr/hyprland.conf` + sed | `wayland.windowManager.hyprland.settings`（HM 模块，已确认存在于 26.05） |
| `home/waybar/config`（写死 battery） | `programs.waybar.settings`，模块列表由 `distro.hardware.battery` 决定 |
| `hypridle/hyprpaper` 手写 conf | `services.hypridle` / `services.hyprpaper`（HM 模块） |
| `__TARGET_USER__` / `/home/nixos` 占位 | 直接使用 `config.home.homeDirectory`，无需替换 |

**注意**：HM 化后 `~/.config` 变成指向 nix store 的符号链接，现有 `sync.sh`（线上 → 仓库）会失效，需改为"仓库即唯一源"，删除 sync.sh 或仅保留 `scripts/` 的同步。

#### P4 验收记录（2026-10-20，分支 `distro/v0`）

**方案调整**：原计划用 Home Manager 模块，但 HM 作为 flake 输入需要 github（本机不可达），
因此改为 **Nix 直接生成配置树**——目标相同（声明式、按 host 生成、`~/.config` 只读指向 store），
依赖更少。将来若接入 HM，`home/default.nix` 的产物可作为 `home.file` 的来源平滑迁移。

| 组件 | 文件 | 说明 |
|---|---|---|
| 单一来源 | `lib/waybar.nix` | 系统级 `/etc/xdg/waybar` 与用户级 `~/.config/waybar` 共用一份配置生成器 |
| 单一来源 | `lib/agent-usage.nix` | Waybar 的 agent 用量脚本 |
| 生成器 | `home/default.nix` | 读 `home/`、`scripts/` 资产，替换 `@HOME@`，按 `distro.*` 追加条件片段，输出 store 树（含 `bin/`） |
| 部署 | `install.sh` | `nix build .#<host>` → 逐文件软链到 `~/.config` / `~/.local/bin`，真实文件先备份 |

条件化行为（构建期决定）：

| 选项 | 影响 |
|---|---|
| `distro.hardware.battery` | 决定 Waybar 是否生成 `battery` 模块 |
| `distro.hardware.backlight` | 决定 `extra.conf` 是否生成 `XF86MonBrightness*` 键位 |
| `distro.agent.enable` | 决定是否生成 `Super+Shift+Ctrl+A` 与 Waybar `custom/agent-usage` |

验证：

| 检查 | 结果 |
|---|---|
| `nix build .#leonard` | ✅ 生成 5 类配置 + 10 个脚本 |
| `@HOME@` 残留 | ✅ 无（全部替换为 `/home/leonard`） |
| `extra.conf` | ✅ 仅 agent 键位（本机 backlight=false，无亮度键） |
| Waybar 模块 | ✅ `… memory, custom/agent-usage, clock`（无 battery） |
| `install.sh` 演练（fake HOME） | ✅ 链接正确，旧文件备份到 `~/.config.bak-<时间戳>` |
| `nix flake check` | ✅ 通过 |

实现要点与变更：

1. **移除 `sync.sh`**：`~/.config` 已是 store 链接，没有可回写的实体文件；仓库成为唯一来源。
2. **P3 的三个 Waybar 注入选项被取代**：`distro.desktop.waybar{RightExtra,Config,CssExtra}`
   换成 `distro.desktop.waybarAgentCmd` + `lib/waybar.nix`，避免两份配置各自演化。
3. **`@HOME@` 占位符**：资产文件不再写死 `/home/nixos`，构建期替换；脚本、hyprpaper、hyprlock 同理。
4. **`with pkgs` 的遮蔽陷阱**：`hyprland.nix` 里把 Waybar 配置变量命名为 `waybar` 会遮蔽
   `pkgs.waybar`，导致 `environment.systemPackages` 收到一个 attrset 而报错——已改名 `waybarCfg`。

## 5. 兼容与迁移策略

- `26.05-dev` 保持现状不动；新结构在 `distro/v0` 分支演进，P0–P1 完成后再决定是否合并。
- 每个阶段结束打 tag（`v0.1-p0` …），出问题 `git revert` 单个提交即可。
- 系统侧始终保留旧世代：P1 之后第一次 `nixos-rebuild switch --flake` 前先 `--build` 验证，再 `boot` + 重启。

## 6. 风险

| 风险 | 影响 | 缓解 |
|---|---|---|
| Nix 求值期无法探测硬件 | 装错驱动 → 黑屏 | 探测只在安装期；`branch=auto` 未识别时回退 `legacy_580` 并 warning |
| NVIDIA 设备 ID 表维护成本 | 新卡误判 | 表只做"Turing 分界"粗判；不确定时允许显式 `branch` |
| channel → flake 双轨期 generation 混乱 | 回滚点不清 | 每阶段只用一个入口；flip 后删除旧 channel 配置 |
| HM 化导致 `sync.sh` 失效 | 用户改动丢失 | P4 前明确"仓库即源"；提供一次性迁移提交 |
| unfree（nvidia）在 flake 下需显式放开 | 求值失败 | `nixpkgs.config.allowUnfree` 保留在 `modules/base.nix` |
| CI 不存在 | 回归靠人肉 | `checks` + 本地 `nix flake check` 作为最低门槛 |

## 7. 完成定义（DoD）

1. `nix flake check` 覆盖全部 host，且对关键选项有断言（GPU 分支、会话集、agent 开关）。
2. 新增一个厂商（例如 AMD）只新增 `modules/hardware/gpu/amd.nix` + 一个 host 文件，不改任何已有模块。
3. 安装器在无网络交互的前提下完成探测并产出可构建的 host 文件。
4. `hosts/leonard` 的闭包与本机当前 `/etc/nixos` 产出的关键选项完全一致（已用 eval 逐项核对）。
5. agent 可通过 `scripts/agent/apply` 完成"改 host → 校验 → 构建"，不接触 `sed`。
