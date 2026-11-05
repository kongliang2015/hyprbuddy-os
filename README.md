# HyprBuddy OS

> **可复现、可审计、可回滚的 agent 桌面底座。**
> 基于 NixOS 26.05 + flake + niri 26.04 + Noctalia v5，把「agent 能对这台机器做什么」变成一份**可构建、可检索、可撤销**的制品。

这不是一套主题与键位配置，也不是一个「AI-native 桌面」。桌面外壳只是载体；**声明式配置、机器可读的能力清单、明确的 agent 权限边界**才是本项目的主体。

| 项 | 当前状态 |
|---|---|
| 底座 | NixOS 26.05（flake）· niri 26.04（唯一会话）· Noctalia v5（`pkgs.noctalia` 5.0.1，原生 C++） |
| Agent 能力 | **28 条命令 + 5 个技能**，`commands.json`（schema 1）构建期生成 |
| 分支 | `distro/v1-nn`（当前）；`distro/v1-cosmic`（Hyprland + COSMIC，2026-10-28 退役） |
| 实测 | `vmware`（x86_64 软渲染）日用中；`leonard` / `vm-virtio` 仅求值；install/live ISO 切换 v5 后未重建 |
| 镜像依赖 | nixpkgs 走清华 nixexprs 镜像，**不依赖 GitHub** |
| 许可 | Apache-2.0 |
| 文档 | 2026-11-05 按「对外可复现的 agent 底座」定位重排；文档总入口 `docs/INDEX.md` |

---

## 1. 为什么做这个项目

把 agent 放进桌面系统，常见的三种失败方式，以及本项目给出的答案：

| 常见问题 | 常见做法 | HyprBuddy OS 的答案（均已实现） |
|---|---|---|
| 配置是一堆 dotfiles，换台机器要靠手抄，无法证明「同一套系统」 | 脚本 + README 教程 | `flake.nix` / `flake.lock` + git 跟踪；`hosts/<host>/default.nix` 只写 `distro.*`；任何一台 NixOS 用同一份 flake 求值即可得到同一套系统 |
| 更新通道被锁定，配置绑死在某个发行版的私有仓库，出问题难回退 | 跟随上游发行版升级 | 无私有更新通道；系统 `nixos-rebuild --rollback`、项目 `git revert`、用户级重跑 `install.sh` 三级回滚 |
| agent 能做什么不透明，AI 生成的脚本直接改系统、甚至自动提权 | 把 agent CLI 做成快捷键 | `@effect` / `@requires-sudo` 元数据 + **只读优先** + **sudo 命令只打印交人执行** + `/etc/nixos/configuration.nix` 防误用桩；能力清单在构建期生成并做必填校验 |

**与「系统级 AI 功能」划清界限**：本项目不做持续截屏索引、不做 Recall 式数字记忆、不把「AI-native / Copilot+ 对标」当卖点，**系统内置推理不引入必须联网的依赖**（不禁止 agent 编排调用外部 LLM API）。本地模型（ollama）**默认关闭**、启用后默认只绑 `127.0.0.1`，定位是隐私诊断与离线兜底。

---

## 2. 三条设计原则（已实现，不是路线图）

### 2.1 配置即制品：声明式、可复现、可回滚

- 所有系统能力集中在 `modules/`，所有机器差异集中在 `hosts/<host>/default.nix` 的 `distro.*` 选项里；`modules/options.nix` 定义类型与断言（例如 `default` 必须在 `sessions` 内）。
- `/etc/nixos/configuration.nix` 是**防误用桩**：不带 `--flake` 的 rebuild 会读到它并报错，避免 agent 或用户把系统改成命令式配置。
- **两种写操作严格区分**：
  - 用户级（`home/` `lib/` `scripts/` `skills/`）→ `./install.sh --host <host> --yes`，无需 sudo，可即时验证；
  - 系统级（`hosts/` `modules/`）→ agent 只改仓库并构建验证，sudo 命令交给用户执行。
- 回滚三档：系统 `sudo nixos-rebuild --rollback` / 项目 `git revert` / 用户级重跑 `install.sh`（被替换的真实文件备份在 `~/.config.bak-<时间戳>/`）。

### 2.2 能力机器可读、构建期可校验

`lib/gen-commands.py` 在构建期扫描 `scripts/` 头部注释，生成 `commands.json`（schema 1），`lib/commands.nix` 把它做成 derivation。校验规则是**硬失败**，不是文档约定：

| 元数据 | 作用 |
|---|---|
| `@command` / `@summary` / `@category` | 三者必填，缺任一 → **构建失败**；`@command` 必须与脚本文件名一致；`@category` 限定 `runtime / workflow / check / agent / system` |
| `@effect` | 拆成 `effects[]`，声明该命令会产生哪些副作用 |
| `@requires-sudo` | 生成 `requires_sudo` 布尔值，供审计与路由 |
| `@arg` / `@usage` / `@interactive` | 参数、用法、是否交互 |
| `@doc` | 指向 `skills/<skill>/` 下的指南；**文件不存在即构建失败**，防死引用 |

`commands.json` 还带 `generated`（host / version / `agent_enabled` / `scripts_source` 构建指纹）、每条命令的 `available`（反映本机构建状态，而非仓库能力）、统一的 `paths`（`repo` / `user_config` / `skills` / `paths.artifacts`）与运维 recipes。

查询入口：`agent-commands --json`、`list`、`show <name>`、`--category <cat>`、`paths`。**以 `agent-commands --json` 为准，不要按本文档列举推断本机可用性。**

### 2.3 agent 权限有边界

| 动作 | agent 可以做 | 谁最终执行 |
|---|---|---|
| 读状态 / 排障 | `sys-health` `svc-status` `sys-log` `net-status` `power-status` | agent（只读） |
| 改用户级配置 | 改仓库 → `agent-apply` 求值构建 → `install.sh` 软链 | agent（无 sudo） |
| 改系统级配置 | 改仓库 → `nix eval` → `nixos-rebuild build` | **只打印** `sudo nixos-rebuild switch ...`，由用户执行 |
| 回滚 / GC | `sys-rollback` / `sys-gc` 输出命令与事实 | 用户 |
| core dump 诊断 | 报告由本地模型生成 | 需与 `coredumpctl info` 原文交叉验证 |

`scripts/agent-apply` 的四步是固定流程：`git diff --stat` → `nix eval`（求值 toplevel drvPath）→ `nixos-rebuild build` → 打印需用户执行的 sudo 命令。错误配置在 **build 阶段**暴露，不进入运行态。

---

## 3. 快速开始（复现路径）

前置：一台 NixOS 26.05 机器（或由本仓库 ISO 安装）、启用 `nix-command` 与 `flakes`、`git`；可访问 `mirrors.tuna.tsinghua.edu.cn`。

```bash
git clone https://gitee.com/lele2015/hyprbuddy-os.git
cd hyprbuddy-os
git checkout distro/v1-nn

# 1. 复制 host 模板，按机器改 distro.*（GPU / hypervisor / desktop / agent）
cp -r hosts/_template hosts/<your-host>

# 2. 用户级：构建 home 配置树并软链（~/.config、~/.local/bin、~/.codebuddy/skills）
./install.sh --host <your-host> --yes

# 3. 系统级：先构建验证，再由你自己执行应用
sudo nixos-rebuild boot --flake .#<your-host>     # 或 switch 立即生效

# 4. 验证
desktop-check                 # 18 项自检，非图形会话自动降级
agent-commands --json         # 本机实际可用的命令清单（含 available 字段）
```

两条必须记住的约束：

- **flake 只认 git 跟踪的文件**：先 `git commit` 再 install / build，未提交的改动不会进 store。
- `nixos-rebuild switch` 只换 `/run/current-system`；**用户级配置必须单独跑 `install.sh`**。涉及 `home/` `scripts/` `skills/` 的改动，部署后再 `niri msg action load-config-file`（或重登）。

`install.sh` 末尾会自动运行 `desktop-check`；仓库定义的一组 checks 可用 `nix flake check` 运行（见 `flake.nix`）。能力清单与脚本的一致性由 `lib/gen-commands.py` 在生成 `commands.json` 时强制校验。

---

## 4. 架构分层

| 层 | 目录 | 职责 / 关键产物 |
|---|---|---|
| 系统层 | `modules/` | `options.nix` / `assertions` / `desktop`（hyprbuddy + niri + sessions）/ `base` / `boot` / `users` / `hardware/gpu` / `agent` |
| 机器层 | `hosts/` | `vmware` / `leonard` / `vm-virtio` / `_template`（模板不参与构建），只写 `distro.*` |
| 用户层 | `home/` | `default.nix`（linkFarm）、niri / kitty / fuzzel / fastfetch / thunar |
| 能力层 | `scripts/`、`lib/` | 28 条命令；`lib/de.sh` 桌面能力抽象；`lib/commands.nix` + `gen-commands.py` 生成 `commands.json` |
| 技能层 | `skills/` | 5 个技能 / 13 篇指南，软链到 agent 的 skills 目录 |
| 主题层 | `themes/`、`exporters/`、`wallpapers/` | 10 套 `tokens.json` → `exporters/niri/theme.sh` → `theme.toml` + kitty/fuzzel 16 色 |
| 交付层 | `installer/`、`install.sh` | install ISO / live ISO / 用户级软链部署 |
| 文档层 | `docs/`、`next-feature/` | 现行规范 / 历史归档 / 设计稿 / 待评估特性 |

---

## 5. Agent 层：现在具备什么

### 5.1 命令（28 条，`agent-commands --json` 可查）

`@category` 枚举允许 `runtime / workflow / check / agent / system` 五类，当前实际分布为 **check 11 · runtime 14 · workflow 2 · agent 1**（`system` 暂未使用）：

| 类别 | 命令 |
|---|---|
| `check`（11） | `sys-health` `svc-status` `sys-log` `net-status` `power-status` `model-status` `model-bench` `sys-gc` `sys-rollback` `desktop-check`（18 项自检）`agent-commands` —— 除 `model-bench` 会发起本地推理并写状态文件外，其余只读或只打印 sudo 命令 |
| `runtime`（14） | `theme-next` `theme-picker` `de-theme-apply` `wallpaper-next` `night-mode` `notif-dnd` `sddm-theme` `clipboard-menu` `record-toggle` `screenshot-output` `screenshot-annotate` `agent-menu` `sysinfo-os` `show-sysinfo` |
| `workflow`（2） | `agent-apply`（改动唯一入口）、`sys-update` |
| `agent`（1） | `agent-theme-sync` |

> 上表是**仓库能力**，不代表任一台机器都可用。例如 `distro.agent.enable = false` 的机器上，`agent-apply` / `agent-menu` / `agent-theme-sync` 未部署，`available=false`。`install.sh` 是部署脚本，不属于这 28 条命令。完整清单见 `docs/agent-coverage-review.md` 与 `docs/SKILLS.md`。

### 5.2 技能（5 个，路由见 `docs/SKILLS.md`）

| 技能 | 定位 | 第一动作 |
|---|---|---|
| `nixos-desktop-settings` | 桌面配置入口：改仓库 → 求值构建 → 部署 → 自检 | 按决策树选参考文件；桌面报错先 `desktop-check` |
| `nixos-system-ops` | 系统运维：先用只读命令拿事实 | `sys-health` → `svc-status` → `sys-log` |
| `theme-create` | 照品牌配色造一套新主题 | 取色 → 壁纸 → `tokens.json` |
| `scifi-ui` | 科幻 / HUD 视觉规范（颜色只能来自 tokens） | 先定 tokens |
| `diagnose-crash` | 崩溃 / core dump 分析 | 读 `~/.local/state/agent/coredump-report.md` |

技能的 `SKILL.md` frontmatter 必须写清「什么时候用」；技能里提到的命令必须存在于 `agent-commands list`；组件退役后要过死引用检查。

### 5.3 本地模型：代码就绪，默认关闭（如实说明）

`modules/agent/local-llm.nix` 默认使用 `pkgs.ollama-cpu`（不引入 CUDA/ROCm 工具链），并固定 `host = "127.0.0.1"`；只有把 `distro.agent.ollamaAcceleration` 显式设为 `"gpu"` 时，才按 `distro.gpu.vendor` 选 `ollama-cuda` / `ollama-rocm` / `ollama-vulkan`。启用条件是 `cfg.enable && cfg.localModels`。

| host | `agent.enable` | `diagnostics` | `localModels` |
|---|:---:|:---:|:---:|
| `vmware` | `false` | — | `false` |
| `leonard` | `true` | `false` | `false` |
| `vm-virtio` | `true` | `false` | `false` |

`diagnostics` 在 `modules/options.nix` 中默认为 `true`，但 `vmware` 的 `agent.enable = false` 让整个 agent 模块不生效，另外两台则显式设为 `false`。

也就是说：**目前三台机器都没有本地模型服务，core dump → 本地模型报告同样未启用**；仓库里也没有 OpenAI 兼容端点、并发控制与功耗观测。这属于已明确记录的下一步，不是已交付能力——请勿按「本机自带本地推理」来理解。

---

## 6. 桌面外壳（载体，非主体）

- **会话**：SDDM → 唯一的 niri 26.04 会话；fcitx5 + 拼音、polkit KDE 代理、xwayland-satellite、upower / bluetooth、Noctalia 自有 PAM 锁屏。
- **外壳**：Noctalia v5 提供面板 / launcher / 通知 / 锁屏 / OSD / 夜间模式 / 壁纸 / 截图 overlay；IPC 为 `noctalia msg <cmd>`，脚本与键位都走它。
- **键位**：`home/niri/config.kdl` 声明 61 条，媒体键 `allow-when-locked=true`；完整列表见 `docs/KEYBINDS.md`。
- **主题**：`themes/<slug>/tokens.json` 是唯一真相；`theme-next` 循环、`theme-next restore` 登录恢复、`theme-picker` 预览、`de-theme-apply <slug>` 直接应用。外壳配色来自壁纸取色（`source="wallpaper"`），与 tokens 同源但**不等于** tokens。
- **自检**：`desktop-check` 18 项（进程、portal、壁纸、bar、字体、键位引用命令存在性、夜间模式日程、配置告警等），非图形会话自动降级。
- **其他**：`scripts/lib/de.sh` 能力层、`distro.desktop.nightlight` 声明式夜间模式、cliphist + fuzzel 剪贴板历史、grim/slurp/swappy 截图、wf-recorder 录屏。

---

## 7. 演进方向（计划，非已完成）

| 优先级 | 方向 | 主要落点 |
|---|---|---|
| **P0（基本完成）** | 对外可发现性：README 重构 + 英文入口 + ROADMAP 按新定位重写 + 时间轴方案改名重写为 agent 执行审计日志；**剩余**：仓库 description / homepage、GitHub 镜像（等 P1 跑通再公开） | `README.md`、`README.en.md`、`docs/ROADMAP.md`、`next-feature/` |
| **P1** | **点亮已有模块**：在真机打开 `localModels` + `diagnostics`，跑通 OpenAI 兼容端点与多客户端并发；新增 `model-status` / `model-bench`，输出 tok/s、内存 / 显存、整机功耗；`power-status` 补 idle / 单请求 / 并发三档 | `modules/options.nix`、`modules/agent/local-llm.nix`、`scripts/` |
| **P2** | 承接 NPU 主机：新增 `hosts/maco470`（`amdxdna`、`render` 组、systemd `LimitMEMLOCK=infinity`、内核 ≥ 7.0）；`local-llm.nix` 增 AMD iGPU Vulkan 与 NPU 低功耗分支；模型盘独立挂载点写入 `paths.artifacts` | `hosts/`、`modules/agent/`、`lib/` |
| **P3** | 把优势变成可移植规范：`skills/` + `commands.json` 抽成任意 NixOS 可导入的规范；append-only **agent 执行审计日志**（可导出 / 可回放）；CI 加 `nix flake check` + schema 校验 + ISO 构建 | `lib/commands.nix`、`skills/`、CI |

> 逐项进度与验收标准以 `docs/ROADMAP.md` 为准（2026-11-05 已按本定位重写）。P3 的审计日志数据源是「agent 执行事件 + `@effect` + 变更前后 diff」，**不是**持续截屏或屏幕时间轴；评估见 `next-feature/agent-execution-audit.md`（未实施、未登记待办）。

---

## 8. 明确不做（Non-goals）

> 本节是**对外边界的权威清单**；`docs/ROADMAP.md` 第 5 节引用本节，不另立口径。
> 条目分三种语气：价值观 / 安全红线、默认状态（可显式开启）、历史与范围清理；变更一律按 `docs/ROADMAP.md` 第 1 节原则 4 的准入条件执行。

- **系统级 AI 功能**：持续截屏索引、Recall 式数字记忆、主动替用户思考的桌面助手。审计方向只记录 agent 执行事件，见 `next-feature/agent-execution-audit.md`（未实施）。
- **「AI-native OS」「Copilot+ 对标」这类品牌措辞**，以及以 TOPS 为卖点的算力宣传。使用 NPU 不等于宣传 TOPS：验证指标是常驻功耗与并发隔离，不是 TOPS / tok/s 对照。
- **系统内置推理不引入必须联网的依赖**（不禁止 agent 编排调用外部 LLM API）；本地模型**默认关闭**、启用后**默认只绑 `127.0.0.1`**。P1 的 `distro.agent.localEndpoint` 若要开放 LAN，须显式开关 + token + 并发上限 + 断言。
- **agent 自动执行 sudo、直接改 `/etc`、绕过构建验证的即时生效写操作**。
- **私有更新通道或绑定单一发行版仓库的配置格式**。
- **不追平其它发行版的 UI 差距项**（多终端 / 编辑器切换、开发栈、游戏套件）：差异化不在这层，个人日用需要可放个人分支。
- **包管理命令封装（声明式已覆盖）、Hyprland / COSMIC 相关特性（已退役，勿回写）**。

---

## 9. 参考

### 9.1 host 与 `distro.*` 选项

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
      sessions = [ "niri" ];     # 当前只允许 niri（listOf (enum [ "niri" ])）
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
| `distro.desktop.sessions` / `default` | `[ "niri" ]` / `"niri"` | 装哪些桌面提供方、SDDM 默认会话 |
| `distro.desktop.nightlight` | 见 `modules/options.nix` | 夜间模式（定位、日程、色温） |
| `distro.hypervisor` | none / vmware / qemu | 虚拟化兼容设置 |
| `distro.gpu.vendor` | nvidia / amd / intel / virtio / none | 选择 GPU 模块 |
| `distro.gpu.nvidia.branch` | auto / legacy_580 / production / beta | auto 按 pciIds 判断 |
| `distro.hardware.battery` / `backlight` | bool | 影响 bar 组件与键位 |
| `distro.agent.*` | `enable` / `agents` / `usage` / `diagnostics` / `localModels` / `ollamaAcceleration` / `model` | agent 层；默认值见 `modules/options.nix`（`enable` / `localModels` 默认 `false`，`ollamaAcceleration` 默认 `cpu`） |

> NVIDIA 必须留在 580 LTSB：26.05 的 `nvidiaPackages.stable` 已指向 595.x，该分支不支持 Pascal，误用会黑屏。
> `distro.agent.model` 默认 `qwen2.5-coder:1.5b`，启用 `localModels` 前需先 `ollama pull`。

### 9.2 部署

```bash
./install.sh --host vmware --yes                    # 用户级
sudo nixos-rebuild boot --flake .#vmware           # 系统级（只装新世代，重启生效）
sudo nixos-rebuild switch --flake .#vmware         # 或立即切换
```

`install.sh` 会自动创建 GC root、备份被替换的真实文件到 `~/.config.bak-<时间戳>/`。注意 `~/.local/bin` **必须是指向 store 的软链**，误建成真实目录会让脚本里的绝对路径绑定失效。

### 9.3 改什么、动哪里

| 要改的 | 入口 | 之后 |
|---|---|---|
| 外观 / 键位 | `home/niri/config.kdl` | `./install.sh --host <host> --yes` |
| 系统能力 | `modules/` | 交用户 `sudo nixos-rebuild switch --flake .#<host>` |
| 机器参数 | `hosts/<host>/default.nix`（只写 `distro.*`） | 先 commit 再构建 |
| 桌面能力 | `scripts/lib/de.sh`（当前只有 niri 分支） | 重新部署 |
| 技能 | `skills/` | `install.sh` 自动重新软链 |
| 不确定入口 | `agent-commands list`（或 `--json`） | — |

### 9.4 安装到新机器

```bash
nix build .#packages.<system>.iso       # 通用安装盘（root 文本界面）
nix build .#packages.<system>.liveIso   # live + install 一体盘
sudo dd if=result/iso/hyprbuddy-live.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

installer 启动后以 root 登录，分区并挂载到 `/mnt`，再执行 `installer/install.sh`（安装器不分区、不格式化）；live 镜像直接进入桌面并保留 `install-hyprbuddy` 命令。**v5 切换后 ISO 尚未重建验证。**

### 9.5 常用快捷键

完整列表见 `docs/KEYBINDS.md`（源文件 `home/niri/config.kdl`）：`Mod+Return`（kitty）、`Mod+D`（启动器）、`Mod+Tab`（窗口切换器）、`Mod+Shift+C/P/S`（控制中心 / 会话 / 设置）、`Mod+Shift+T`（主题选择器）、`Mod+L`（锁屏）、`Mod+V`（剪贴板历史）、`Mod+Alt+R`（录屏）、`Print`（区域截图）。

### 9.6 实测状态与注意事项

| 项 | 状态（2026-11-04） |
|---|---|
| `vmware`（x86_64，软渲染） | niri + Noctalia v5 日用中；桌面自检通过、夜间模式色温已下发；`agent.enable = false` |
| `leonard`（GTX 1050 Ti / legacy_580） | 仅求值，未实机登录验证 v5；agent 层开启（opencode + codebuddy） |
| `vm-virtio`（aarch64 / virtio-gpu） | 仅求值，未实机登录验证 v5；agent 层开启 |
| install / live ISO | v5 切换后未重建 |

- `flake.lock` 的 nixpkgs narHash 对应清华镜像内容；频道刷新后校验失败时执行 `nix flake update nixpkgs`。
- SDDM 0.21 (Qt6) 的 `sddm-greeter` 符号链接处理在 `modules/desktop/hyprbuddy.nix`。
- `hosts/vm-virtio/default.nix` 里的 SSH 公钥为测试用途，正式使用前请替换。
- 自定义调色板（`source="custom"`）与多 host 实机验证目前暂缓，见 `docs/ROADMAP.md`。

### 9.7 文档导航

**现行规范（以代码为准）**：`docs/ROADMAP.md`（进度）、`docs/SKILLS.md`（技能路由与技能×命令矩阵）、`docs/KEYBINDS.md`、`docs/agent-coverage-review.md`、`skills/nixos-desktop-settings/`、`skills/nixos-system-ops/`。总入口 `docs/INDEX.md` 把全部文档分为「现行规范 / 历史归档 / 设计稿」三类。

**历史 / 设计稿（勿按现状引用）**：`docs/AGENT-LAYER.md`、`ARCHITECTURE-REVIEW.md`、`IMPLEMENTATION-PLAN.md`、`desktop-abstraction.md`、`niri-noctalia-plan.md`、`desktop-retire-hyprland.md`、`cosmic-*.md`、`theme-tokens.md`、`ux-capabilities.md` 等，文件头均已加统一状态横幅。排障请以 `skills/nixos-desktop-settings/troubleshooting.md` 为准。

**待评估特性**：`next-feature/`（未实施、未进路线图）。

---

## 许可

Apache-2.0。欢迎在其它 NixOS 机器上复现并反馈；`commands.json` 与脚本头部的 `@command` 元数据是本项目对外的能力接口。
