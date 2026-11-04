# 本地时间轴 + 语义检索（Linux / niri 版 Recall）评估

> **状态：未实施（2026-11-04 评估）** · 基准仓库 `hyprbuddy-os` @ `6199353`
> `next-feature/` 存放**尚未落地**的新特性评估：不属于现行规范、不计入 `docs/SKILLS.md`
> 的技能数、不随 `install.sh` 部署。现状说明以 `docs/ROADMAP.md` 与 `docs/INDEX.md` 为准。
>
> 背景：Windows 11 Copilot+ PC 的 **Recall**（微软官方中文「回顾」，英文媒体称
> *AI-powered digital memory* / *photographic memory*，国内 AI PC 宣传常译「数字记忆」）。
> 它每隔几秒截取屏幕快照，本地 OCR + 语义索引，之后用自然语言找回「看过的那一刻」。

## 1. 需求与结论

目标：在本机（niri 26.04 + Noctalia v5 / NixOS 26.05）实现等价能力 ——
**持续记录屏幕内容 → 本地索引 → 时间轴浏览 + 语义检索 → 跳回当时上下文**。

结论：**Linux 上没有开箱即用的 Recall，但按三层拼完全可行**，且本机截图链路现成。
建议优先走「贴合仓库的自建方案」（第 4 节），而不是引入一个 Python 常驻服务；
理由是本机已具备 `agent-commands` / `commands.json` / skills / systemd 声明式体系，
新能力可以自然接进去，而现成项目在 Wayland + 软件渲染 VM 上都存在适配风险。

三层拆解：

| 层 | 回答的问题 | 本方案 |
|---|---|---|
| 事件时间轴 | 我这段时间在用什么 | ActivityWatch 或 niri IPC 记录窗口 app_id / 标题 |
| 内容采集 | 屏幕上出现过什么 | `grim` 定时截图 + `tesseract` OCR（eng + chi_sim） |
| 检索 | 怎么找回那一刻 | SQLite FTS5 关键词检索；可选本地 embedding 语义排序 |

## 2. 现成项目对比

| 项目 | 接近 Recall 的程度 | 技术栈 | 主要短板 |
|---|---|---|---|
| **OpenRecall** | 最接近：定时截屏 + 本地 OCR + 语义检索 + 时间轴 Web UI，AGPLv3，全本地不出机器 | Python 3.11 + pip，浏览器访问 `localhost:8082` | 官方安装是 `pip install git+…`，与 NixOS 声明式不对付；Wayland 截图支持需自行验证；本地 embedding 吃 CPU |
| **screenpipe** | 更重：24/7 录屏 + 麦克风转录 + 本地索引 + 可挂自动化 pipe | Rust，支持 Linux / macOS / Windows，偏「喂给 agent」 | 常驻采集开销大；语义检索依赖外接模型；更偏平台而非纯时间轴工具 |
| **ActivityWatch**（含 `awatcher`） | 只有事件时间轴：窗口 / 应用 / AFK，**不存屏幕内容** | 本地 server + Web UI，Go/Rust watcher | 无内容级检索，回答不了「上周那家餐厅叫什么」；但隐私风险最低 |

补充判断：

- Rewind / Limitless 是 macOS 或云方案，无 Linux 版；云方案与本地优先原则不符，排除。
- Zeitgeist / KDE KActivities 是老一代活动日志，只记录「打开过什么文件」，不记录屏幕内容。
- 想要「屏幕内容 + 语义搜索」只能选 OpenRecall 或 screenpipe；只想要「我这段时间在干嘛」用 ActivityWatch 即可。

## 3. 本机环境约束（决定选型）

| 约束 | 事实 | 影响 |
|---|---|---|
| Wayland / niri | `grim`、`wf-recorder` 已装且实测可用；gnome/gtk portal 已注册 | 截图链路现成，可用 `xdg-desktop-portal` Screenshot 或 `wlr-screencopy`；但 OpenRecall 若写死 X11 截图（mss / pyautogui）会直接失败，**这是首要验证点** |
| 无 NPU、软件渲染 VM | VMware SVGA + llvmpipe，无 40 TOPS NPU | CLIP / sentence-transformers 在 CPU 上很慢；先做 OCR + 关键词检索，语义检索作为可选第二层 |
| NixOS 声明式 | 系统 / 用户层都由 flake 生成，pip 与预编译二进制不好管 | 要么 `nix develop` / venv 隔离试跑，要么把采集端写进 `modules/` 的 `distro.*` 选项 |
| 隐私 | 持续截屏天然扩大攻击面（参考 Windows Recall 2024 年的明文存储争议） | 默认关闭、排除列表、锁屏暂停、保留期、目录权限 700、只存 OCR 文本与缩略图 |

## 4. 推荐方案：贴合仓库的自建最小闭环

```
systemd user timer（每 20–60s，且仅在「解锁 + 非排除应用」时触发）
   ↓ grim 截图（降采样到约 1280 宽，只保留缩略图）
   ↓ tesseract OCR（eng + chi_sim）→ 纯文本
   ↓ niri IPC 取当前窗口 app_id / title（具体子命令查 niri msg --help）
   ↓ SQLite：ts, app_id, title, ocr_text, thumb_path
        └─ FTS5 虚拟表做关键词 / 短语检索（中文可配 jieba 或 trigram）
   ↓ 检索脚本：memory-recall "上周看过的餐厅"
        └─ 命中后开缩略图 / 复制文本 / 跳回窗口
```

组件全部是 nixpkgs 现成包：`grim`、`tesseract`（含 chi_sim 语言数据）、`sqlite`、
`imagemagick`（缩略图）、`python3`、`jq`。无需新增外部服务或 Python 依赖。

**为什么先不做语义检索**：本机没有 NPU，本地 embedding 是纯 CPU 开销；
而「找回看过的东西」的大部分场景用 OCR 文本 + FTS5 关键词已经够用。
先把采集、排除、保留期、检索体验跑顺，再决定要不要付语义的成本。

## 5. 语义检索（可选第二层）

在 FTS5 之上叠加，随时可加可撤：

- OCR 文本 → 本地 embedding（轻量 multilingual MiniLM 系；走 ollama embeddings 或 onnxruntime，
  **不要**上图像 CLIP，CPU 上代价过高）
- 向量存 SQLite（`sqlite-vec` 或直接 numpy 余弦）
- 检索时 FTS5 关键词结果与向量结果混合排序；白天走关键词，模糊描述时才付语义成本

## 6. 与现有体系的集成点

| 现有机制 | 怎么接 |
|---|---|
| `scripts/` + `@command` 元数据 | 新增 `scripts/memory-recall`，头部写 `@command / @summary / @category / @doc`，自动进 `agent-commands --json`（当前 26 条命令） |
| `home/default.nix` 的 linkFarm | 采集端脚本随 `install.sh` 部署；配置类文本走 `share/hyprbuddy-os/` |
| `modules/` + `distro.*` 选项 | 采样间隔、排除列表、保留天数、开关做成声明式选项，避免手工改 `~/.config` |
| `systemd.user.timers` | 与现有 fcitx5 / polkit-agent 的用户单元同一套写法（含等待会话环境变量的竞态处理） |
| `skills/` | 新增指南或并入 `nixos-desktop-settings`；`docs/SKILLS.md` 第 1/2/3 节同步 |
| `desktop-check` | 增补检查：采集单元是否在跑、数据库大小、数据目录权限、保留期是否超限 |

## 7. 隐私与性能默认值（保守起步）

1. **默认关闭**，需显式 `distro.memoryTimeline.enable = true` 才启用。
2. 排除列表默认含密码管理器、银行 / 邮箱 / 医疗财务类应用与网站；无痕窗口不采集。
3. **锁屏时暂停**（可用 `loginctl` / session lock 信号判断），解锁后恢复。
4. 只存 OCR 文本 + 降采样缩略图，不长期保留全屏原图。
5. 数据目录权限 700，位于 `~/.local/state/`，保留期默认 7 天，超限自动清理。
6. 磁盘低于阈值（参考 Recall 的 25 GB 思路，按本机比例设）自动暂停采集。
7. 跑一周后看 CPU / 磁盘 / 命中率，再决定是否提高采样频率或启用语义层。

## 8. 决策与后续

| 路线 | 内容 | 改动面 | 建议 |
|---|---|---|---|
| A 探路 | 在 `nix develop` / venv 里装 OpenRecall，验证 niri/Wayland 下能否截图、OCR 与 UI 是否可用 | 几乎零仓库改动 | 先做，成本低，能确认现成方案的适配上限 |
| B 落地 | 按第 4 节在仓库实现最小原型，接进 `agent-commands` 与 `desktop-check`，vmware 上试跑一周 | 新增 module + 脚本 + 技能 + 选项，需 `nixos-rebuild switch` | A 结论不满意再走；贴合现有体系、可控 |

**当前决定：尚未实施，仅存档评估。** 未写入 `docs/ROADMAP.md` 的待办清单；
若决定推进，先在 ROADMAP 的 P2/P3 里登记，再按「先 commit 再 install」的流程落地。

## 附：Windows Recall 参考事实（评估背景）

- Copilot+ PC 独占：≥ 40 TOPS NPU、16 GB RAM、256 GB 存储、启用需 ≥ 50 GB 可用空间、BitLocker / 设备加密、Windows Hello ESS。
- 默认关闭、需 opt-in；`设置 → 隐私和安全性 → 回顾和快照`；`Win + J` 打开；每次访问要 Windows Hello 验证。
- 快照本地加密、不上传微软 / 第三方、不跨 Windows 用户共享；可过滤应用与网站、过滤隐私浏览、随时暂停 / 删除。
- 发布史：2024-05 公布 → 2024-07 因明文存储争议推迟 → 2024-10/11 再次撤回 → 2025-04 以 opt-in + 加密 + Hello 重新推出 → 2025 年扩到 AMD / Intel Copilot+ PC。
- 争议要点：持续截屏本身扩大攻击面，自动敏感信息过滤不保证 100% 可靠 —— 本方案第 7 节的保守默认值即针对这些风险。
