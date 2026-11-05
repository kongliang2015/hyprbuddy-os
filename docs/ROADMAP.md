# HyprBuddy OS 路线图

> 更新：2026-11-05 · 分支 `distro/v1-nn` · 夜间补充：P1 实施顺序（leonard runbook）
> 本版按项目定位 **「对外可复现的 agent 桌面底座」** 重写。2026-11-04 及以前的版本以桌面外壳功能清单为主体，其已完成项已并入第 2 节，被替换的优先级见文末变更表。
> 状态口径：**已实现 / 已实现未启用 / 计划 / 暂缓** 分开写，不把计划写成能力；现状永远以代码为准，索引见 `docs/INDEX.md`。

## 0. 当前形态

| 层 | 现状 |
|---|---|
| 底座 | NixOS 26.05 + flake（nixpkgs 走清华 nixexprs 镜像，不依赖 GitHub） |
| 合成器 | niri 26.04（唯一提供方，滚动平铺） |
| 外壳 | Noctalia v5（`pkgs.noctalia` 5.0.1，原生 C++，无 quickshell） |
| 会话 | SDDM → niri；fcitx5；polkit KDE 代理；xwayland-satellite；Noctalia 自有 PAM 锁屏 |
| 主题 | `themes/<slug>/tokens.json` 单一真相 → kitty/fuzzel 精确 16 色 + 外壳壁纸取色；10 套 |
| 键位 | `home/niri/config.kdl` 61 条，速查见 `docs/KEYBINDS.md` |
| 自检 | `desktop-check` 19 项（图形会话全量、非图形降级） |
| agent 层 | **28 条命令 + 5 个技能**，`commands.json`（schema 1）构建期生成；索引见 `docs/SKILLS.md` |
| 实测 | `vmware`（x86_64 软渲染）日用中；`leonard` / `vm-virtio` 仅求值；ISO 切换 v5 后未重建 |

## 1. 优先级原则

1. **主体是三件事**：配置即制品（声明式 / 可复现 / 可回滚）、能力机器可读（`@command` 元数据 + 构建期校验）、agent 权限有边界（只读优先、sudo 只打印）。桌面外壳是载体，不是差异化所在。
2. **不追平其它发行版的 UI 差距项**（多终端 / 编辑器切换、开发栈、游戏套件）。这类差异不产生护城河；若为个人日用体验需要，放个人分支，不进对外叙事。
3. **不落地系统级 AI 功能**（持续截屏索引、Recall 式数字记忆、「AI-native / Copilot+ 对标」措辞）。opt-in 与保守默认值不足以化解社区抵触，措辞与治理姿态本身就是决定因素。
4. **任何新能力的准入条件**：进 `commands.json` 且 `@summary` / `@category` / `@effect` 齐全；可 `nixos-rebuild --rollback` 回退；**系统内置推理**不引入必须联网的依赖（不禁止 agent 编排调用外部 LLM API）；默认关闭的开关要有明确文档。

## 2. 已完成

### 2.1 Agent 底座（对外主体）

- **声明式 / 可回滚**：`flake.nix` + `flake.lock` + git；`hosts/<host>/default.nix` 只写 `distro.*`；`/etc/nixos/configuration.nix` 为防误用桩；用户级 `install.sh` 与系统级「构建验证 → 交人执行 sudo」严格分离；三级回滚（`--rollback` / `git revert` / 重跑 `install.sh`）。
- **能力机器可读**：`lib/gen-commands.py` 构建期生成 `commands.json`（schema 1）；`@command` / `@summary` / `@category` 必填且 `@command` 须等于文件名，`@doc` 指向的指南不存在即构建失败；`generated` 构建指纹、每条命令的 `available`、`paths.artifacts` 统一产物落点。
- **权限边界**：`scripts/agent-apply` 固定四步（`git diff --stat` → `nix eval` → `nixos-rebuild build` → 打印 sudo 命令）；`sys-*` 只读或只打印；错误配置在 build 阶段暴露。
- **技能体系**：5 个技能 / 13 篇指南的路由表与技能×命令矩阵；技能提到的命令必须在 `agent-commands list` 中存在。
- **agent 层命令**：`sys-*` 6 条、`svc-status` / `net-status` / `power-status`、技能 `nixos-system-ops`、过时技能重写（`theme-create` / `scifi-ui`）、`diagnose-crash`。

### 2.2 桌面外壳（载体）

- 桌面抽象 P0–P3：`distro.desktop.sessions`、能力层 `scripts/lib/de.sh`、tokens + exporters、Hyprland / COSMIC 退役（v1-nn）。
- Noctalia v4 → v5：包装、PAM 锁屏、upower / bluetooth 前置、exporter 重写、13+ 处键位与脚本换 `msg`。
- 键位补齐（B 套）：窗口切换器、通知 / 勿扰、夜间模式、壁纸、btop、上下工作区、截图 overlay、`allow-when-locked`。
- 夜间模式 `distro.desktop.nightlight`（6500 / 4000K，日志确认下发）；录屏 `Mod+Alt+R` → `record-toggle`。
- 剪贴板维持 cliphist + fuzzel（不绑 v5 面板）；截图落盘按 XDG 目录解析；产物落点统一进 `commands.json` 的 `paths.artifacts` + `agent-commands paths`。
- `desktop-check` 增补：键位引用命令存在性、壁纸目录、夜间模式日程、Noctalia unknown setting 告警；bar 布局确认**不做声明式基线**。
- 清理 `~/.config/noctalia/` 的 v4 残留。

### 2.3 对外叙事（2026-11-05）

- `README.md` 按新定位重构，agent 层与三条设计原则前移，主题 / 键位降为「桌面外壳」小节，原有部署与选项参考全部保留（提交 `4835b56`）。
- 新增 `README.en.md` 英文 1 页入口。
- 本文件按新定位重写。
- `next-feature/local-memory-timeline.md` 改名重写为 **`next-feature/agent-execution-audit.md`**：数据源从持续截屏改为 agent 执行事件，叙事从「记录用户」翻转为「审计 agent」；探针附录与技术栈复用清单保留，状态仍为**未实施**、不进本文件待办。

## 3. 待做（按优先级）

### P0 对外可发现性（收尾）

| 动作 | 落点 | 验收标准 | 状态 |
|---|---|---|---|
| README 首句改为「可复现、可审计、可回滚的 agent 桌面底座」，agent 层提到首位 | `README.md` | 首屏 200 字内出现声明式、agent 权限边界、机器可读能力清单 | [x] `4835b56` |
| 补英文 1 页 README | `README.en.md` | `NixOS agent desktop / auditable / reproducible` 可检索 | [x] `4835b56` |
| 停用「AI-native / Recall / Copilot+ 对标」措辞 | `README*`、`docs/ROADMAP.md`、`next-feature/` | 全仓库检索仅出现在否定 / 历史 / 非目标语境 | [x] 本轮 |
| 砍掉 P3 的 Omarchy UI 差距项 | `docs/ROADMAP.md` | 待办中不含「多终端 / 编辑器 / 开发栈 / 游戏套件」 | [x] 本版 |
| 时间轴方案改名重写为「agent 执行审计日志」 | `next-feature/agent-execution-audit.md` | 状态横幅为未实施、探针附录保留、不进待办 | [x] 本轮 |
| 仓库 `description` / `homepage` 补齐，并同步 `flake.nix` 的 `description` | Gitee 仓库设置、`flake.nix` | 一句话定位与英文关键词可被检索；`flake.nix` 现行描述「AI-agent 原生的 NixOS 发行版」仍带 AI-native 措辞，须改为 agent 底座口径 | [ ] |
| GitHub 镜像 | 新仓库 | 与 Gitee 同步；**等 P1 跑通再公开**，避免过早放大未验证项 | [ ] |

### P1 点亮已有模块（对应外部最强需求：本地模型 7×24 常驻）

> 前提认知：本地模型当前是「core dump 诊断的隐私兜底」，外部需求把它当「常驻基础设施」。**先改定位，再改代码**；`modules/agent/local-llm.nix` 默认走 CPU 变体（无 CUDA 依赖），GPU 加速为显式 opt-in，改造面很小。
> **实施地点：`leonard`，由本机用户执行。** 步骤 1 的开关改动已在仓库落地（`hosts/leonard/default.nix`），但**验收清单全部勾完之前不视为已启用**——避免「代码已开、运行态未验」被误读；下面的顺序即验收口径。

| 动作 | 落点 | 验收标准 | 状态 |
|---|---|---|---|
| 在 `leonard` 打开 `localModels` + `diagnostics` | `hosts/leonard/default.nix` | `ollama.service` 与 `coredump-watch.path` 活跃；coredump 报告落 `~/.local/state/agent/` 且与 `coredumpctl info` 原文可交叉验证 | [ ] |
| 跑通 ollama OpenAI 兼容端点 `/v1/chat/completions` 与多客户端并发 | 本机回归脚本 | 2–3 个并发请求不互相挤占、无 OOM | [ ] |
| 新增 `model-status` / `model-bench` | `scripts/`（`home/default.nix` 自动扫描，无需改 `lib/commands.nix`） | `agent-commands --json` 条目 +2，`@summary` / `@effect` 齐全；输出 tok/s、RAM / 显存；功耗按可读来源采样，读不到留空（CPU 版见步骤 4） | [ ] |
| `power-status` 补 idle / 单请求 / 并发三档功耗 | `scripts/power-status` | 输出可机器解析（JSON），**并用 `power_source` 标注数据来源** | [ ] |
| 新增 `distro.agent.localEndpoint`：`bind` / LAN 开关 / token / 并发上限 | `modules/options.nix`、`modules/agent/local-llm.nix` | 默认仍只绑 `127.0.0.1`；LAN 暴露需显式开关 + 断言 | [ ] |

#### P1 实施顺序（leonard runbook）

**步骤 0 · 前置检查**（任一不通过就先解决，别进步骤 1）

```bash
git status -sb                                                        # 仓库根目录：干净、分支 distro/v1-nn
nvidia-smi --query-gpu=name,driver_version --format=csv                # 可选：确认 NVIDIA 驱动（CPU 版 ollama 不依赖 GPU）
df -h ~/.ollama /nix/store                                            # 模型 + 运行时需数 GB 空闲（CPU 版无 CUDA 工具链）
systemctl status ollama --no-pager || true                             # 现在应未安装/未启用
```

> 本机已有「`downloads.claude.ai` 不可达、构建期拉 claude-code 失败」的记录（`hosts/leonard/default.nix` 注释）。**`ollama pull` 同样要外网**：若失败，可在有网机器 `ollama pull` 后拷贝 `~/.ollama/models`，或用本地 GGUF `ollama create` 导入；不要为此改动 `agents` 列表。

**步骤 1 · 打开开关**（只改 `hosts/leonard/default.nix` 的 `distro.agent` 段）

```nix
    agent = {
      enable = true;
      agents = [ "opencode" "codebuddy" ];
      usage = true;
      diagnostics = true;    # 必须与 localModels 同时为 true
      localModels = true;
      # model = "qwen2.5-coder:1.5b";   # 默认值，可不写
    };
```

> 两处断言是硬约束：`modules/assertions.nix` 要求 `localModels ⇒ agent.enable`；`modules/agent/diagnostics.nix` 要求 `diagnostics ⇒ localModels`。**只开 `diagnostics` 不开 `localModels` 会直接 build 失败**，不是运行期报错。
> 保持 `gpu.vendor = "nvidia"` / `pciIds = [ "10de:1c82" ]` 的 580 LTSB 分支不变；`system.stateVersion = "25.11"` 也不要顺手改成 26.05（会触发状态目录迁移）。

**步骤 2 · 构建验证 → 由人执行 sudo**

```bash
git add hosts/leonard/default.nix && git commit -m "leonard: enable localModels + diagnostics"
nix --extra-experimental-features 'nix-command flakes' eval .#nixosConfigurations.leonard.config.system.build.toplevel.drvPath
nixos-rebuild build --flake .#leonard
sudo nixos-rebuild switch --flake .#leonard      # 你自己执行；agent 只打印、不执行 sudo
./install.sh --host leonard --yes                # 用户级必须显式 --host
nix flake check
```

> flake 只认 git 跟踪的文件，**先 commit 再 build**。本机 `networking.hostName = "nixos"` 而 host 目录叫 `leonard`，所以 `install.sh` 不带 `--host leonard` 会找不到 `hosts/nixos/default.nix`。
> `switch` 只换 `/run/current-system`，用户级脚本 / 技能仍要单独跑 `install.sh`。`nix flake check` 若因 `vm-virtio` 是 aarch64 而无法在本机构建，退化为 `nix build .#packages.x86_64-linux.leonard` + 已通过的 `nixos-rebuild build` 即可。

**步骤 3 · 拉模型、验端点、验并发**

```bash
ollama pull qwen2.5-coder:1.5b
systemctl status ollama --no-pager
curl -sS http://127.0.0.1:11434/api/tags
curl -sS http://127.0.0.1:11434/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen2.5-coder:1.5b","messages":[{"role":"user","content":"ping"}],"stream":false}'
for i in 1 2 3; do curl -sS -o /tmp/p1-$i.json -w "%{http_code}\n" \
  http://127.0.0.1:11434/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"qwen2.5-coder:1.5b","messages":[{"role":"user","content":"ping"}],"stream":false}' & done; wait
journalctl -k --since '5 min ago' | grep -i oom || true
systemctl status coredump-watch.path --no-pager
```

> 诊断走 `/api/generate`（不是 OpenAI 兼容端点），报告落在 `~/.local/state/agent/coredump-report.md`；`coredump-analyze.service` 是 oneshot，触发后才运行，验收要与 `coredumpctl info` 原文交叉验证。CPU 版下显存不参与推理：先确认 1.5B 稳定，**不要直接上 7B**（RAM 占用与单次延迟都会明显上升）。

**步骤 4 · 补命令与功耗观测**

- 在 `scripts/` 新建 `model-status`、`model-bench`：`home/default.nix` 会自动扫描 `scripts/` 并部署，`lib/commands.nix` / `commands.json` **无需改动**。
- 头部必填 `@command`（须等于文件名）、`@summary`、`@category`（用 `check`），建议补 `@usage`、`@effect: 只读`。**`@doc` 若写，必须指向 `skills/<skill>/` 下真实存在的指南文件名，否则构建失败**；没有对应指南就省略。
- `model-bench` 输出 tok/s 与 RAM / 显存（`nvidia-smi --query-gpu=memory.used` 仅作参考，CPU 版下显存不参与推理）；`power-status --json` 增加 idle / 单请求 / 并发三档字段。
- ⚠️ **CPU 版下三档功耗的边界**：`nvidia-smi power.draw` 只反映 GPU，CPU 推理时三档会接近 idle；本机 GTX 1050 Ti 更直接返回 `[N/A]`。所以 `power-status` 的 `current_w` / `scenarios` 在 CPU 版下多为 `null`、`power_source` 标 `unavailable`——**这是如实留空，不是缺陷**。需要 CPU 侧功耗时用 `/sys/class/powercap/*/energy_uj` 两次采样求差，或主板 hwmon 的 `power*_input`（视机型）。这套字段仍保留为 P2 NPU 主机的对比格式，**不要伪造整机瓦数**。

**步骤 5 · 可选：LAN 端点**（最后做，默认不做）

`distro.agent.localEndpoint` 目前**尚不存在**，需在 `modules/options.nix` 新增选项、`local-llm.nix` 消费：`bind` 默认 `127.0.0.1`、LAN 开关、token、并发上限，并加断言「仅开关为 true 时允许非回环地址」。与 `README.md` §8 的「默认只绑本机、显式开关 + token + 并发上限 + 断言」一致；跳过这一步不影响 P1 其余验收。

**验收清单**

- [ ] `ollama.service` active，`/api/tags` 能列出 `qwen2.5-coder:1.5b`
- [ ] `/v1/chat/completions` 单次返回 200；3 路并发互不挤占、无 OOM
- [ ] `coredump-report.md` 可生成，且与 `coredumpctl info` 原文可交叉验证
- [ ] `agent-commands --json` 条目 +2、`available=true`，`@summary` / `@effect` 齐全
- [ ] `power-status --json` 含三档字段并标注 `power_source`
- [ ] `nix flake check`（或上述退化路径）通过
- [ ] **回写文档**：把运行态验收结论（`ollama.service` 活跃、tok/s、功耗）补进本文档 §6 状态口径表与 `README.md` §5.3；代码状态已同步，缺的是运行态结论

**回滚**

```bash
sudo nixos-rebuild --rollback          # 系统世代
git revert <本次 commit>               # 配置
./install.sh --host leonard --yes      # 用户级重新软链
```

或直接把 `diagnostics` / `localModels` 一起改回 `false` 后重新 build；注意两个开关必须同时回退，否则断言会拦下。

### P2 新增 NPU host（承接 MACO470 选型）

| 动作 | 落点 | 验收标准 | 状态 |
|---|---|---|---|
| 新增 `hosts/maco470/`：`amdxdna` 内核模块、`render` / `video` 组、内核 ≥ 7.0 | `hosts/maco470/`、`modules/hardware/` | `lsmod \| grep amdxdna` 有输出；`/dev/accel/accel0` 属组 `render`；`flm validate` exit 0 | [ ] |
| systemd `LimitMEMLOCK = "infinity"` | service 单元 | 不出现 `mmap(MAP_LOCKED) failed err=-11`；**不能用 `limits.conf`，NixOS 的 systemd 会话不生效** | [ ] |
| XRT / FastFlowLM 先用 `buildFHSEnv` 或容器打通，再固化为 derivation | `pkgs/` | `flm bench llama3.2:1b` 接近公开基线（约 61 tok/s @1K） | [ ] |
| `local-llm.nix` 增 `amd-igpu-vulkan` 分支（Radeon 890M 上 ROCm 未必可用）与 NPU 低功耗路径 | `modules/agent/local-llm.nix` | 新 host 求值通过，不回退到 `ollama-cpu` | [ ] |
| 三条 M.2 物理隔离：系统盘 / 模型盘 / 数据盘 | `lib/commands.nix`、`agent-commands paths` | `paths.artifacts.models` 可查；skill 沙箱重建后模型文件校验和不变 | [ ] |
| 验证目标改为**常驻功耗 + 并发隔离 + 沙箱重建不扰动模型盘** | 回归清单 | 三条 M.2 逐条测速确认 PCIe 4.0 ×4 | [ ] |

> 连锁效应：现有文档中「无 NPU、软件渲染 VM，所以不做语义检索」这条约束，在 NPU 主机到位后失效。语义层可用 NPU 低功耗跑，但仍应按**「省电、不抢 GPU」**叙事，而非「更快」——TOPS 不预测 tok/s，瓶颈是内存带宽。

### P3 护城河（把优势变成可复用规范）

| 动作 | 落点 | 验收标准 | 状态 |
|---|---|---|---|
| 将 `skills/` + `commands.json` 抽成**可移植规范**：任意 NixOS 可导入，不绑定本仓库 flake | `lib/commands.nix`、`skills/` | 干净 NixOS 上用一份 flake 导入即可获得命令与技能；直接回答「更新通道锁定」的批评 | [ ] |
| CI：`nix flake check` + `commands.json` schema 校验 + ISO 构建 | `flake.nix`、CI 配置 | PR 自动跑，`desktop-check` 降级路径不报错 | [ ] |
| append-only **agent 执行审计日志**（方向，未登记为待办） | 评估见 `next-feature/agent-execution-audit.md` | 推进前须先定采集边界与隐私策略；若推进，验收为每次 `agent-apply` 与写操作留痕、可导出 JSONL | [ ] |

> P3 第三项按 `docs/INDEX.md` 第 5 节约定：决定推进时才从 `next-feature/` 转入本表待办。

## 4. 桌面外壳维护（低优先级 / 暂缓）

| 项 | 状态 |
|---|---|
| 重建 live / install ISO（niri 提供方换 v5 后未验证） | [ ] 质量项，P2 的历史遗留 |
| `sys-doctor`：聚合 `sys-health` + `net/power-status` + `desktop-check` | [ ] 低优先级 |
| 自定义调色板：5.0.1 的 `source="custom"` 试 6 种写法均 invalid，外壳暂只能壁纸取色 | [ ] 暂缓，等上游文档 / 新版本 |
| 多 host 实机验证 v5（`leonard` NVIDIA、`vm-virtio` aarch64 仅求值） | [ ] 暂缓，需要那两台机器 |

## 5. 明确不做

**权威清单见 `README.md` §8「明确不做」**，本节不另立口径，避免两处漂移。路线图视角只补充一条优先级约束：

- **不追平其它发行版的 UI 差距项**（多终端 / 编辑器切换、开发栈、游戏套件）：差异化不在这层，个人需要可留分支处理；见第 1 节原则 2。

所有边界的变更仍按第 1 节原则 4 执行（进 `commands.json`、可 rollback、系统内置推理不引入必须联网的依赖、默认关闭的开关要有文档）。

## 6. 状态口径（防止文档写成「已支持」）

| 项 | 真实状态 |
|---|---|
| 本地模型 | `modules/agent/local-llm.nix` 代码就绪（默认 CPU 变体、GPU 加速需显式开启、`127.0.0.1`）；**`leonard` 已在仓库打开 `localModels` + `diagnostics`，但运行态未验收**（未 switch、未 `ollama pull`，服务未激活）；`vmware` / `vm-virtio` 仍为 `false`。无 OpenAI 兼容端点实测、并发控制、功耗观测。属 P1，不是已交付能力 |
| `diagnostics` | `modules/options.nix` 默认 `true`；`leonard` 已打开（与 `localModels` 同步，运行态待验收），`vm-virtio` 显式 `false`，`vmware` 因 `agent.enable = false` 整个模块不生效 |
| 实测覆盖 | 只有 `vmware` 日用；`leonard` / `vm-virtio` 仅求值；ISO 未重建 |
| 数字 | 28 命令 / 5 技能 / 61 键位 / 10 主题 / 19 项 `desktop-check`，按 `docs/INDEX.md` 第 4 节约定实测核对 |

> 本表记录的是**仓库代码状态**；`leonard` 的 P1 开关已打开，但**运行态验收（switch / `ollama pull` / 端点与并发）尚未完成**，所以「本地模型」一行仍标为未交付。P1 验收清单勾完后，把运行态结论（服务活跃、tok/s、功耗）补进本表与 `README.md` §5.3。

## 附：本版相对 2026-11-04 版的变更

| 变更 | 原因 |
|---|---|
| 删除 P3 的「omarchy 差距表中难度项（多终端 / 编辑器切换、开发栈、游戏套件）」 | 追平的是无护城河的一层；见第 1 节原则 2 |
| 新增 P1「点亮本地模型」与 P2「NPU host」并附验收标准 | 原路线图没有「本地模型作为常驻基础设施」的位置，这是当前最大缺口 |
| 原「已完成 / 待做」的桌面功能清单并入第 2.2 与第 4 节 | 保留历史事实，但不再占据主线 |
| 时间轴方案改名重写为 agent 执行审计日志 | 技术栈复用、叙事从「监控用户」翻转为「审计 agent」；状态仍为未实施 |
| 措辞停用「AI-native / Recall / Copilot+ 对标」（除否定与历史语境） | 见第 1 节原则 3 |
