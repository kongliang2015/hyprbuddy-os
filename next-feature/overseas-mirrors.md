# 海外用户镜像源适配评估（live ISO 安装）

> **状态：方案 C 已实施（2026-11-06；完整 ISO 构建已通过，实机安装待验证）** · 评估基准 `hyprbuddy-os` @ `10f5df3`
> `next-feature/` 存放**尚未落地**的新特性评估：不属于现行规范、不计入 `docs/SKILLS.md`
> 的技能数、不随 `install.sh` 部署。现状说明以 `docs/ROADMAP.md` 与 `docs/INDEX.md` 为准。
>
> 背景：ISO 安装要拉两类网络资源 —— flake 输入（nixpkgs）与二进制缓存。当前两者都面向
> 中国大陆（清华 nixexprs + 国内三镜像），海外用户安装可能极慢或直接失败。本文评估
> 「按区域切换源」的可行方案与成本。

## 1. 需求与结论

需求：海外用户用 live / installer ISO 安装时，不应因为中国镜像不可达而失败或卡住；
安装完成后日常 `nixos-rebuild` 也应能命中合适的缓存。

结论：**现状不是最优，且最严重的问题在安装阶段而不是日常使用** ——
`nixos-install --flake` 必须拉 `flake.lock` 里写死的清华 nixexprs，海外网络下可能直接失败。
推荐两步走：先补文档与 `--mirror official` 指引（止血）；中期做「ISO 预置 nixpkgs」
（方案 C），把安装对 flake 输入的依赖去掉，之后「中国 / 海外」只剩一个二进制缓存开关。

**2026-11-06 进展**：方案 C 的代码已落地（ISO 预置 + 安装时 override + 安装后恢复），
`--dry-run` 端到端验证通过；完整 ISO 构建与实机安装仍待验证。

## 2. 现状盘点

| 源 | 当前值 | 海外体验 | 安装时可选 |
|---|---|---|---|
| flake 输入（`nixpkgs` / `nixpkgs-unstable`） | 清华 nixexprs（`flake.nix:6`、`:11`），`flake.lock` 锁 narHash | ❌ 慢或失败 | **不能**：`nixos-install` 不支持 `--override-input` |
| 二进制缓存 | `distro.mirror = cn`（清华 / 上交 / 中科大，`modules/base.nix`） | ❌ 慢 | ✅ `--mirror official` 已支持 |
| `codebuddy` 的 npm 依赖 | `pkgs/codebuddy/package-lock.json`：31 处 resolved 指向 npmmirror，2 处 GitHub | ❌ 构建慢 | ❌ 锁在 lockfile 里，运行时不能切 |
| `codex` / `opencode` 源码 | GitHub（`openai/codex`、`anomalyco/opencode`） | ✅ 海外正常 | —（中国靠 nix 缓存命中） |
| `claude-code` 源码 | `downloads.claude.ai` | ✅ 海外正常 | — |

## 3. 三个卡点

### 3.1 安装阶段：flake 输入写死清华（最严重）

- `flake.nix` 的两个输入 URL 硬编码为清华；`flake.lock` 记录 `narHash`。
- **实测**：同一滚动 channel 在清华与中科大的 nixexprs `narHash` 不同（不同时间点的快照），
  所以「只换 URL、保留 lock」会校验失败；必须 `nix flake lock --update-input` 重新生成，
  等于**换一个 nixpkgs 版本**。
- `nixos-install --help` 实测不支持 `--override-input`，只能在安装脚本的 `$work/src` 副本里
  改 `flake.nix` 并重新 lock。

### 3.2 二进制缓存：已可配，但默认面向国内

- `distro.mirror` 已支持 `cn / tuna / sjtu / ustc / official`，安装器有 `--mirror`；
- 海外用户不知道要改，或 ISO 交互提示里没有「海外」这个语义（只有具体镜像名）。

### 3.3 `codebuddy` 的 npm 依赖锁在 npmmirror

- `pkgs/codebuddy/default.nix` 的 `src` 指向 `registry.npmmirror.com`；
- `package-lock.json` 里 31 处 `resolved` 也是 npmmirror（另 2 处 GitHub git 依赖）；
- `npmDepsHash` 是按这份 lock 算的，换源必须改 lock 并重算 hash，属于构建期改动，
  不能做成安装选项。

## 4. 方案对比

| 方案 | 做法 | 优点 | 代价 |
|---|---|---|---|
| **A. 文档 + `--mirror official`** | README 增加「海外安装」小节，明确 `--mirror official`；说明 flake 输入仍需手动改 | 零代码改动、立刻可用 | 不解决 3.1，安装仍可能卡死 |
| **B. 安装器 `--region cn\|global`** | 在 `$work/src` 改 flake URL + `nix flake lock`；substituters 跟随 | 海外安装可用 | 换 nixpkgs 版本（与仓库 lock 不一致）；安装要拉 nixexprs；双区域测试 |
| **C. ISO 预置 nixpkgs（推荐核心）** | 构建 ISO 时把 nixexprs 放进镜像；安装时 work 副本指向 `path:/iso/nixpkgs`，`nix flake lock` 本地完成 | 中海外都受益：安装不依赖 flake 输入网络；版本随 ISO 固定、可复现 | ISO +38.2 MiB（解压 256.6 MiB 需临时空间）；ISO 构建流程要改 |
| **D. 双 lock 预置** | ISO 里放 `flake.lock.cn` / `flake.lock.global`，`--region` 选一个 | 无需运行时 lock | 两套 nixpkgs 版本，测试面翻倍 |
| **E. codebuddy npm 双变体** | `codebuddy`（npmmirror）与 `codebuddy-npmjs`（官方 registry），按 `--region` 选 | 海外构建快 | 改构建脚本；重算 `npmDepsHash`；双版本维护 |

## 5. 方案 C 的落地细节

1. **ISO 构建**：在 `installer/iso-config.nix` / `live-iso-config.nix` 的 `srcPkg` 里额外放入
   `nixexprs.tar.xz`（38.2 MiB），或解压后的目录（256.6 MiB，体积更大）。
2. **安装时**：`installer/install.sh` 在 `$work/src` 里把 `flake.nix` 的输入改为
   `path:/iso/nixpkgs`（或 `file://` 指向解压目录），然后 `nix flake lock` 本地生成 lock。
3. **版本一致性**：ISO 内的 nixpkgs 与仓库 `flake.lock` 会不同（ISO 构建时的快照），
   需要在安装计划里显示 ISO 内的 nixpkgs 版本，避免「装完和仓库对不上」的困惑。
4. **体积**：ISO 约 +38 MiB；安装阶段临时解压需要约 257 MiB 空间（目标盘已挂载，通常够）。

**实施记录（2026-11-06）**

| 文件 | 改动 |
|---|---|
| `installer/iso-config.nix` / `live-iso-config.nix` | 新增 `nixpkgsPkg`：复制 `pkgs.path` 到 `share/hyprbuddy-nixpkgs` 并 `chmod -R u+w`；加入 `environment.systemPackages`。**首次用 `cp -al` 硬链接在构建沙箱里失败**（回退 `cp -r` 无法覆盖只读文件，Permission denied），已改为直接复制 |
| `installer/install.sh` | 自动检测 `/run/current-system/sw/share/hyprbuddy-nixpkgs`（或 `$here/nixpkgs`）；备份 `flake.lock` → `nix flake lock --override-input nixpkgs path:…` → 安装后用备份恢复 |

验证：

- `nix flake lock --override-input nixpkgs path:<nixpkgs source>` 后 `narHash` 与 `flake.lock` **完全一致**（`sha256-OtQ9…`），不换版本；
- `unshare -r` + `NIXPKGS_LOCAL=<source>` 跑 dry-run：计划显示「使用 ISO 内置 nixpkgs」，override 成功，`nix eval` 求值通过；
- 恢复后 `flake.lock` 与仓库版本 `diff` 一致；
- 两个 ISO 的 `drvPath` 求值通过，`nix flake check --no-build` 通过；
- **完整 `nix flake check` 通过**（含内核模块构建，31 分钟）；
- **完整 live ISO 构建通过**：`nix build .#packages.x86_64-linux.liveIso` → `EXIT=0`，产物 `hyprbuddy-live.iso` **3.6 GiB**。
  首次构建失败，根因是 `nixpkgsPkg` 用 `cp -al` 硬链接到只读 store 文件：部分成功后回退 `cp -r`
  无法覆盖只读文件（Permission denied）；已改为直接 `cp -r` + `chmod -R u+w`。
  **代价**：内置的是 nixpkgs 完整源码（约 485 MiB），ISO 达 3.6 GiB，比预期 +100 MiB 大得多；
  后续可优化为只放 nixexprs tarball（38 MiB）或软链到 store，见 §7 待确认。

## 6. 建议分阶段

| 阶段 | 内容 | 成本 |
|---|---|---|
| 现在 | README 增加「海外安装」小节：`--mirror official`、flake 输入手动替换方法、已知限制 | 文档 |
| 中期 | 方案 C（ISO 预置 nixpkgs）；之后海外只剩 binary cache 选择 | **代码已实施 + 完整 ISO 构建通过（2026-11-06，3.6G）**；实机安装待验证 |
| 可选 | 方案 E（codebuddy npm 双变体） | 构建脚本 + 双版本维护 |

## 7. 待确认技术点

- ~~`path:` 输入在无 `.git` 的 `$work/src` 里执行 `nix flake lock` 的行为~~（已实测：成功，narHash 一致）。
- ISO 预置后 `nixos-install` 的求值路径与 `flake.lock` 生成位置。
- 双区域切换后的回归范围（`nix flake check` / `desktop-check` / 三类 host 求值）。
- `codebuddy` 换 npm 源后 `npmDepsHash` 重算与构建验证（约 30 个依赖包）。

## 附录：实测数据（2026-11-06）

| 项 | 值 |
|---|---|
| 清华 nixexprs narHash（`flake.lock` 当前） | `sha256-OtQ9jaQ9aXZDm61TqykPLZdXJa2NMykYG3d0tbT683U=` |
| 中科大同一 channel narHash | `sha256-zaqzqkIxpoJA5s6mhAjAVbWba3Ao1u6SH93fixYbN6A=`（不同快照） |
| nixexprs.tar.xz 体积 | 38.2 MiB 压缩 / 256.6 MiB 解压 |
| `nixos-install --help` | 无 `--override-input`（只有 `--flake` / `--option` 等） |
| `codebuddy` package-lock 域名 | 31 处 `registry.npmmirror.com`，2 处 `github.com` |
| `codex` src | `https://github.com/openai/codex/archive/refs/tags/rust-v0.146.0.tar.gz` |
| `opencode` src | `https://github.com/anomalyco/opencode/archive/refs/tags/v1.15.10.tar.gz` |
| `claude-code` src | `https://downloads.claude.ai/claude-code-releases/2.1.223/linux-x64/claude` |
