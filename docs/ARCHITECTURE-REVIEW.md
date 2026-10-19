# 架构评估：现状 vs 发行版目标

> 评估对象：`26.05-dev` 分支（`9c7f320`）
> 设计目标：以本仓库的 Hyprland 桌面为壳，构建 **AI agent 原生**、**可覆盖多种显卡配置**（NVIDIA / AMD / Intel / virtio）的 NixOS 发行版。
> 本文件只做评估与结论，具体实施见 [IMPLEMENTATION-PLAN.md](./IMPLEMENTATION-PLAN.md)。

## 1. 结论

**方向正确，抽象层不足。** 当前仓库是"一份单机配置 + 一层薄模板"，能支撑"同一用户的两台机器"，但不满足"发行版"的三个硬性条件：可复现、可分发、可被 agent 安全改写。

| 目标 | 现状 | 判定 |
|---|---|---|
| 多显卡（NVIDIA / AMD / Intel / virtio） | 仅 `virtio` 与 `leonard-nvidia` 两个取值，靠 `mkForce` 互相覆盖 | ❌ 只覆盖 1 个真实厂商 |
| 可安装的发行版 | channel 方式，无 `flake.lock`，靠 `sed` 改模板 | ❌ 不可复现、不可分发 |
| agent 原生 | `docs/AGENT-LAYER.md` 设计完整，代码 0 实现 | ❌ 未落地 |
| 用户层可移植 | `home/` 为纯文本资产 + `__TARGET_USER__` 替换 | ✅ 方向正确 |
| 系统/用户分层 | `home/` 与 `system/` 分离，`system/profiles/` 扩展点已存在 | ✅ 可保留 |
| 文档与踩坑沉淀 | TROUBLESHOOTING / AGENT-LAYER / ROADMAP 质量高 | ✅ 核心资产 |

## 2. 四个结构性硬伤

### 2.1 硬件差异用 `mkForce` 覆盖，而非"选项 + 默认值"

`system/profiles/leonard-nvidia.nix` 中：

```nix
services.xserver.videoDrivers = lib.mkForce [ "nvidia" ];
```

问题：

1. **组合爆炸**：加 AMD 要再 Force 一次 `modesetting`，加 Intel 再来一次，加"无显卡/headless"还要处理冲突检测。
2. **同厂商多代际无法表达**：GTX 1050 Ti（Pascal）必须锁 `legacy_580`，RTX 40 系必须 `production`。当前只能靠人在注释里写死，机器换卡即失效。
3. **没有类型**：`hardwareProfile = "leonard-nvidia"` 是字符串，拼错不会报错，只会静默加载不到 profile（`lib.optional` 对字符串比较），进而得到一个"看起来正常但显卡驱动错"的系统。

### 2.2 `sed` 模板化：脆弱且对 agent 不友好

`install.sh` 中的关键逻辑全部依赖文本匹配：

```bash
sed -i "s|^  hardwareProfile = \"virtio\";|  hardwareProfile = \"$PROFILE\";|" "$SYS_TMP"
sed -i '/^  users.users.nixos = {$/,/^  };/d' "$SYS_TMP"
grep -q 'boot.loader.grub.enable = true' /etc/nixos/configuration.nix
```

后果：

- 改缩进、调顺序、换注释即静默失效；
- 引导器判断只看"配置里有没有 grub 字样"，实际系统是 systemd-boot 时会误判；
- **agent 没有可安全改写的接口**：只能"猜着 sed"，改完无法用编译器验证语义。

### 2.3 没有 flake，就没有"发行版"

- `nixpkgs` 来自机器上的 channel，两台机器同一时刻 rebuild 会得到不同 nixpkgs；
- 无 `flake.lock` → 无法回答"这个版本装出来是什么"；
- 无 `nixosConfigurations.<host>` 概念 → 只有"一个 configuration.nix 被 sed 成不同形态"，无法在同一仓库内表达多台机器；
- 无 `checks` → 新增厂商时只能人肉装机验证。

### 2.4 用户层只有"拷贝"，没有"按机器生成"

- `home/waybar/config` 写死 `battery` 模块与 `XF86MonBrightness*` 键位；
- `home/hypr/*.conf` 写死 `/home/nixos`，安装后靠 `sed` 批量替换；
- `sync.sh` 只对单一用户有效（硬编码 `$HOME` 路径），且是"线上 → 仓库"单向拷贝。

这正是"各种不同配置"的最小样例：台式机无电池、无背光，笔记本才有。发行版应由选项生成模块列表，而不是每种机器维护一份 config。

## 3. 现状中应当保留的部分

| 资产 | 原因 |
|---|---|
| `home/` 全部配置与脚本 | 纯文本、agent 可读；是"外观资产"而非"安装逻辑" |
| `system/profiles/` 目录 | 扩展点选择正确，只是实现方式要换成 option |
| `docs/TROUBLESHOOTING.md` | 记录了 0.55 语法、Pascal 驱动分支、SDDM/Qt6 等真实经验 |
| `docs/AGENT-LAYER.md` | 六层拆分与"NixOS 上两种写"的判断准确，可直接映射为模块 |
| 双 HM 模式（module / standalone） | 说明已意识到部署形态差异，需要保留为选项 |

## 4. 目标能力矩阵

发行版必须能对以下组合"同一套代码、不同 host 文件"：

| 维度 | 取值 | 承载方式 |
|---|---|---|
| GPU | nvidia（按代际选分支）/ amd / intel / virtio / none | `distro.gpu.vendor` + `gpu/nvidia.nix` 内部解析 branch |
| 形态 | 台式机 / 笔记本 / 虚拟机 | `distro.hardware.{battery,backlight}` |
| 会话 | Hyprland only / + XFCE / + Window Maker | `distro.desktop.extraSessions` |
| 用户环境 | HM 随系统构建 / 独立 channel | `distro.homeManager.mode` |
| agent | 关闭 / 入口+观测 / 全量（含本地模型） | `distro.agent.*` |
| 引导 | systemd-boot / grub | `hosts/<host>` 内声明，探测只发生在安装期 |

## 5. 与既有文档的关系

- `docs/AGENT-LAYER.md` 的六层能力继续有效，本评估只改变其**落地位置**：从"用户级脚本"提升为 `modules/agent/*`。
- `docs/ROADMAP.md` 的"难以直接移植"结论不变（Quickshell、omarchy 安装器）；本评估新增一条前置条件：先把 flake 与 options 补齐，否则 agent 层没有可靠的写入接口。
