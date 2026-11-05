# 本地时间轴 + 语义检索（Linux / niri 版 Recall）评估

> **状态：未实施（2026-11-04 评估）** · 评估基准 `hyprbuddy-os` @ `6199353`
> 2026-11-05 事实核对基准 `499435e`；同日完成**一次性可行性探针**（见附录 A），
> 核心链路实测可用，并据此修正第 3/4/6/7/8 节的四处假设。**方案结论不变**：
> 自建优先、检索分两层、保守默认值、默认关闭。
> `next-feature/` 存放**尚未落地**的新特性评估：不属于现行规范、不计入 `docs/SKILLS.md`
> 的技能数、不随 `install.sh` 部署。现状说明以 `docs/ROADMAP.md` 与 `docs/INDEX.md` 为准。
>
> 背景：Windows 11 Copilot+ PC 的 **Recall**（微软官方中文「回顾」，英文媒体称
> *AI-powered digital memory* / *photographic memory*，国内 AI PC 宣传常译「数字记忆」）。
> 它每隔几秒截取屏幕快照，本地 OCR + 语义索引，之后用自然语言找回「看过的那一刻」。

## 1. 需求与结论

目标：在本机（niri 26.04 + Noctalia v5 / NixOS 26.05）实现等价能力 ——
**持续记录屏幕内容 → 本地索引 → 时间轴浏览 + 语义检索 → 找回当时上下文**。

结论：**Linux 上没有开箱即用的 Recall，但按三层拼完全可行**，且本机截图链路现成。
建议优先走「贴合仓库的自建方案」（第 4 节），而不是引入一个 Python 常驻服务；
理由是本机已具备 `agent-commands` / `commands.json` / skills / systemd 声明式体系，
新能力可以自然接进去，而现成项目在 Wayland + 软件渲染 VM 上都存在适配风险。
2026-11-05 的一次性探针（附录 A）实测了截图、OCR、中文检索、锁屏状态四项关键假设，
链路成立且开销可接受；落地前需先补齐系统包、改写中文检索策略、收紧产物策略。

三层拆解：

| 层 | 回答的问题 | 本方案 |
|---|---|---|
| 事件时间轴 | 我这段时间在用什么 | ActivityWatch 或 niri IPC 记录窗口 app_id / 标题 |
| 内容采集 | 屏幕上出现过什么 | `grim` 定时截图 + `tesseract` OCR（eng + chi_sim） |
| 检索 | 怎么找回那一刻 | SQLite FTS5（中文按字切分 + phrase）；可选本地 embedding 语义排序 |

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

2026-11-05 实测补充（详见附录 A）：

- `grim` 全屏截图 502 ms / 1.15 MB；`tesseract` 5.5.2 二进制与 `eng` / `chi_sim`
  语言数据已在 store 中，只是**未进 PATH**；eng OCR 278 ms、chi_sim 549 ms。
- 单次「截图 + OCR」约 0.8–1.05 s，按 30 s 采样约占 3% 单核 —— 软件渲染 VM 的
  CPU 不是瓶颈，原先对持续负载的担忧不成立。
- 但 `magick` / `convert` / `ffmpeg` / Python PIL 全部缺失，缩略图生成需要新增系统包。

## 4. 推荐方案：贴合仓库的自建最小闭环

```
systemd user timer（默认 60s，仅在「解锁 + 有聚焦窗口 + 非排除应用」时触发）
   ↓ grim 截图（全屏 PNG；落盘前降为约 1/20 的缩略图，或只保留 OCR 文本）
   ↓ tesseract OCR（eng + chi_sim）→ 纯文本
   ↓ niri msg focused-window 取 app_id / title（无窗口时跳过本次采集）
   ↓ SQLite：ts, app_id, title, ocr_text, thumb_path
        └─ FTS5：中文按字切分后建索引，查询用 phrase（见附录 A）
   ↓ 检索脚本：memory-recall "上周看过的餐厅"
        └─ 命中后复制 OCR 文本 / 打开命中的 URL 或文档路径 / 查看缩略图
```

组件与依赖（2026-11-05 修正）：

- 已在 PATH：`grim`、`wf-recorder`、`niri`、`noctalia`、`python3`（含 `sqlite3` 3.51.2）、`jq`。
- **需新增系统包**：`tesseract` + `eng` / `chi_sim` 语言数据、缩略图工具
  （`imagemagick` 或 `python3Packages.pillow`）；sqlite 用 Python 标准库即可，无需 CLI。
- 因此落地不只是用户级脚本：需要 `environment.systemPackages` + `nixos-rebuild switch`。
- 产物落点统一从 `agent-commands paths` 查询（现有 `paths.artifacts`），
  新增 `artifacts.memory`，不另写死路径。
- 「跳回窗口」在 niri 平铺 WM 下不现实（窗口关闭后即不存在），
  改为复制文本 / 打开命中的 URL 或文档路径。

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
| `commands.json` 的 `paths.artifacts` | 新增 `artifacts.memory`；采集端从 `agent-commands paths` 查落点，不硬编码目录 |
| 系统包（`modules/desktop/`） | `tesseract` + 语言数据 + 缩略图工具进 `environment.systemPackages`，需 `nixos-rebuild switch`，`install.sh` 管不到 |
| `systemd.user.timers` | 与现有 fcitx5 / polkit-agent 的用户单元同一套写法（含等待会话环境变量的竞态处理） |
| `skills/` | 新增指南或并入 `nixos-desktop-settings`；`docs/SKILLS.md` 第 1/2/3 节同步 |
| `desktop-check` | 增补检查：采集单元是否在跑、数据库大小、数据目录权限、保留期是否超限 |

## 7. 隐私与性能默认值（保守起步）

1. **默认关闭**，需显式 `distro.memoryTimeline.enable = true` 才启用。
2. 排除列表默认含密码管理器、银行 / 邮箱 / 医疗财务类应用与网站；无痕窗口不采集。
   排除依据 `app_id` / 标题正则，需在有窗口时先验证 `niri msg focused-window` 的字段格式
   （探针时会话无窗口，该字段格式尚未验证）。
3. **锁屏时暂停**：读 `noctalia msg status` 的 `locked` 字段（已实测存在），
   不用 `loginctl` —— Noctalia 是自有 PAM 锁屏，logind 未必感知；
   解锁后恢复。无聚焦窗口时同样跳过本次采集。
4. 只存 OCR 文本 + 约 1/20 的缩略图，不保留全屏原图；命中时可临时重截。
5. 数据目录权限 700，落点查 `agent-commands paths` 的 `artifacts.memory`；
   **保留期默认 3 天**（非 7 天），超限自动清理。
6. 磁盘预算（实测 1.15 MB/张、30 s 采样）：全屏原图 7 天 ≈ 22.6 GB、
   缩略图 1/10 ≈ 2.3 GB、1/20 ≈ 1.1 GB。因此采样间隔 ≥ 60 s、
   保留 ≤ 3 天；磁盘低于阈值自动暂停采集。
7. CPU 预算：单次「截图 + OCR」约 0.8–1.05 s，30 s 采样约占 3% 单核；
   采集与 OCR 解耦（先存文本 / 缩略图，OCR 用 idle timer 批处理）可进一步压低。
8. 中文检索按字切分 + FTS5 phrase query（附录 A 已验证「餐厅」可命中），
   不引入 jieba，也不用 trigram 单独承担 2 字词。
9. 跑一周后看 CPU / 磁盘 / 命中率，再决定是否提高采样频率或启用语义层。

## 8. 决策与后续

| 路线 | 内容 | 改动面 | 建议 |
|---|---|---|---|
| A 探路 | 装 OpenRecall 验证 Wayland 截图与 OCR | 几乎零仓库改动 | **已由 2026-11-05 一次性探针完成**（附录 A）：关键假设用 10 行脚本即可验证，不必再引整个 Python 服务 |
| B 落地 | 按第 4 节在仓库实现最小原型，接进 `agent-commands` 与 `desktop-check`，vmware 上试跑一周 | 新增 module + 脚本 + 系统包 + 技能 + 选项，需 `nixos-rebuild switch` | 探针确认可行后按序推进；先补系统包与中文检索策略，再上采集 |

**当前决定：尚未实施，仅存档评估。** 未写入 `docs/ROADMAP.md` 的待办清单；
若决定推进，先在 ROADMAP 的 P2/P3 里登记，再按「先 commit 再 install」的流程落地。
探针结论：核心链路（截图 → OCR → 本地检索 → 锁屏暂停）**技术可行且开销可接受**；
落地前必须满足四个前提 —— 新增系统包、中文检索改写、产物与保留期收紧、有窗口时验证 IPC 字段。

## 附录 A：2026-11-05 可行性探针（实测数据）

一次性、无副作用验证：临时目录跑完即删，未启动常驻采集，
未输出任何截图 / OCR 内容；探针时仓库 HEAD 为 `09ec667`。

| 验证项 | 方法 | 实测结果 | 判定 |
|---|---|---|---|
| 截图 | `grim` 全屏 PNG | 502 ms / 1.15 MB | ✅ 可行 |
| OCR 组件 | store 内 `tesseract 5.5.2` + `eng` / `chi_sim` traineddata | 二进制可运行、语言包齐全，但**未进 PATH** | ✅ 需加系统包 |
| OCR 耗时 | eng / chi_sim 各跑一次 | eng 278 ms / 23 字符；chi_sim 549 ms / 0 字符（当时屏幕无可识别中文） | ✅ 中文效果待真实内容复测 |
| 单次开销 | 截图 + OCR 串行 | 约 0.8–1.05 s；30 s 采样 ≈ 3% 单核 | ✅ 可接受 |
| 锁屏状态 | `noctalia msg status` | 返回 `"locked": false` 字段 | ✅ 可作暂停依据 |
| SQLite | `python3` 内置 `sqlite3` 3.51.2 | FTS5 可用，`trigram` tokenizer 可建表 | ✅ |
| 中文检索（原假设） | FTS5 trigram 查「餐厅」 | hits=0；「可持续餐厅」hits=1；unicode61 查「餐厅」也 hits=0 | ⚠️ 2 字词失效 |
| 中文检索（修正） | 按字切分 `餐 厅` + phrase query | 「餐厅」命中、「可持续餐厅」命中、英文数字正常 | ✅ 无需 jieba |
| 窗口元数据 | `niri msg focused-window` / `windows` | rc=0 但输出空（当时会话未开窗口） | ⚠️ 字段格式未验证 |
| 缩略图依赖 | `magick` / `convert` / `ffmpeg` / PIL | 全部缺失 | ❌ 需新增系统包 |
| 磁盘估算 | 1.15 MB/张、30 s 采样 | 全屏 7 天 ≈ 22.6 GB；1/10 ≈ 2.3 GB；1/20 ≈ 1.1 GB | ⚠️ 原「7 天保留」不可行 |

结论：核心链路可行；方案结论（自建优先、分两层、保守默认值）不变，
但第 3/4/6/7/8 节的四处假设已按上表修正 —— 系统包、中文检索策略、产物与保留期、窗口字段验证。

## 附：Windows Recall 参考事实（评估背景）

- Copilot+ PC 独占：≥ 40 TOPS NPU、16 GB RAM、256 GB 存储、启用需 ≥ 50 GB 可用空间、BitLocker / 设备加密、Windows Hello ESS。
- 默认关闭、需 opt-in；`设置 → 隐私和安全性 → 回顾和快照`；`Win + J` 打开；每次访问要 Windows Hello 验证。
- 快照本地加密、不上传微软 / 第三方、不跨 Windows 用户共享；可过滤应用与网站、过滤隐私浏览、随时暂停 / 删除。
- 发布史：2024-05 公布 → 2024-07 因明文存储争议推迟 → 2024-10/11 再次撤回 → 2025-04 以 opt-in + 加密 + Hello 重新推出 → 2025 年扩到 AMD / Intel Copilot+ PC。
- 争议要点：持续截屏本身扩大攻击面，自动敏感信息过滤不保证 100% 可靠 —— 本方案第 7 节的保守默认值即针对这些风险。
