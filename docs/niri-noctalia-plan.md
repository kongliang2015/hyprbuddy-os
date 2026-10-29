# niri + Noctalia 接入实施方案（v1 架构第三提供方）

> **状态（2026-10-29）**：本文记录的是 **Noctalia v4（noctalia-shell 4.7.6）** 的接入过程。
> 仓库现已切到 **Noctalia v5（pkgs.noctalia 5.0.1，原生 C++ 运行时）**：
> 配置为 `~/.config/noctalia/*.toml`、IPC 为 `noctalia msg ...`、配色走壁纸取色。
> 现状说明以 `skills/nixos-desktop-settings/{theming,bar-notify,niri}.md` 为准，
> 本文仅作历史与决策依据保留。

> 前置评估见本文件第一节；架构分层与阶段方法论沿用
> `docs/desktop-abstraction.md`（P0–P2 已落地的能力契约 + tokens/exporters 体系）。
> 目标：在 `distro.desktop.sessions` 中新增 `niri` 提供方，与 Hyprland / COSMIC
> 并存、可切换、可回退，复用同一套主题资产与能力层。

## 一、已核实的事实（2026-10-28，26.05 锁定频道）

| 组件 | 版本/位置 | 说明 |
|---|---|---|
| niri | `26.04`（日期版本制） | 滚动平铺合成器；NixOS 模块 `nixos/modules/programs/wayland/niri.nix`（`programs.niri.enable` 注册会话） |
| noctalia-shell | `4.7.6` | 面板 / launcher / 通知 / 锁屏 / OSD / 设置全套（quickshell QML） |
| noctalia-qs / quickshell | ✅ 均在 26.05 | Noctalia 运行时框架 |
| noctalia-greeter | ✅ | 可选登录器（本项目仍用 SDDM，不启用） |
| 依赖 | `noctalia-shell` 打包已带运行时依赖 | cliphist、wl-clipboard、brightnessctl、wlsunset（夜间模式）、ddcutil、wlr-randr、imagemagick |

**关键结论**：

- 打包零成本——不需要自建 derivation，不引入 github 输入（本机 github 被阻断）
- Noctalia 自带剪贴板历史、夜间模式（wlsunset）、亮度控制——COSMIC 路线的
  P3 "硬缺口"在 Noctalia 路线里是**内置能力**，无需 cliphist/gammastep 拼装
- niri 为 smithay 系，渲染路径与 COSMIC 同源，vmwgfx 软渲染预期一致（需 N5 实测）
- niri 无内置 Xwayland，X11 应用依赖 `xwayland-satellite`（N1 需确认模块是否自动拉起）

## 二、分层改动总览

```
L4 agent   codebuddy/opencode/诊断/usage              （不动）
L3 skill   nixos-desktop-settings / cosmic-ux           （N5 补桌面矩阵说明）
L2 运行时  scripts/lib/de.sh + desktop-check            （N2 加 niri 分支）
           exporters/niri/  ← 新增（N3，唯一真开发项）
L1 提供方  modules/desktop/niri.nix ← 新增（N1）
L0 选项层  distro.desktop.sessions += "niri"            （N1）
```

## 三、阶段与步骤

### N0 调研与可行性（0.5 天）

目标：把三个未知数变成确定值，结论写回本文档。

1. **Noctalia 配置机制**：`noctalia-shell` 首次运行生成的配置路径与格式
   （预期 `~/.config/noctalia/` JSON）；确认配色/主题是否可从外部注入
   （决定 N3 exporter 的写入目标）。在临时 HOME 下启动观察生成物，不动真实配置
2. **主题注入点**：Noctalia 是否有 "colors.json / theme" 类外部配置文件；
   若只能改 GUI 内部状态，记录其持久化位置与格式（仍可写文件）
3. **portal 组合**：niri 推荐 `xdg-desktop-portal-gnome`（录屏）+ `gtk`（文件选择）。
   与现有 cosmic/hyprland 门户做分会话声明（`xdg.portal.config.niri`）
4. **Xwayland**：确认 `programs.niri` 是否带 `xwayland-satellite`；不带则手动接
5. **版本行为**：niri 26.04 的 KDL 键位语法与滚动平铺默认行为（对照官方 wiki）

验收：本节补「调研结果」小节，三项都给出确定结论；结论推翻假设时同步调整 N1–N3。

#### N0 调研结果（2026-10-28，noctalia-shell 4.7.6 产物静态分析）

**配置位置（全部支持环境变量覆盖，便于无副作用测试）**

| 项 | 路径 | 覆盖变量 |
|---|---|---|
| 配置目录 | `$XDG_CONFIG_HOME/noctalia/` | `NOCTALIA_CONFIG_DIR` |
| 设置 | `~/.config/noctalia/settings.json` | `NOCTALIA_SETTINGS_FILE` |
| 当前配色（运行时缓存） | `~/.config/noctalia/colors.json` | 跟随配置目录 |

**配色注入协议（N3 exporter 直接采用）**

1. 写 `colors.json`：`{ "dark": { ... }, "light": { ... } }`，键为 Material 风格：
   `mPrimary/mOnPrimary/mSecondary/mOnSecondary/mTertiary/mOnTertiary/mError/
   mOnError/mSurface/mOnSurface/mSurfaceVariant/mOnSurfaceVariant/mOutline/
   mShadow/mHover/mOnHover` + `terminal.normal/bright`（8+8 色）
2. 映射关系（tokens → noctalia）：`mSurface ← bg`、`mOnSurface ← fg`、
   `mSurfaceVariant ← surface`、`mOnSurfaceVariant ← muted`、`mPrimary ← accent`、
   `mSecondary ← accent2`、`mTertiary ← accent`、`mError ← urgent`、
   `terminal ← terminal.*`（15 色板 → normal 8 + bright 7/8）
3. **必须先关闭预设方案**：settings.json 的 `colorSchemes.predefinedScheme`
   非空时，启动会重新 apply 预设并覆盖 colors.json。exporter 用 jq 合并写：
   `useWallpaperColors=false, predefinedScheme=null`（保留其余键）
4. 热更新：配置目录有目录级 watcher，colors.json 写入即生效（N3 实测确认）
5. 附带收益：Noctalia 会把配色分发给 kitty/gtk-3.0/foot/ghostty 等
   （TemplateRegistry），与我们的 kitty 主题写盘形成双写——N3 需实测冲突

**Noctalia 内置能力（settings.json 键，直接进能力层判定）**

`nightLight`（夜间模式）、`idle`、`notifications`、`sessionMenu`（注销/锁屏）、
`osd`、`bar`、`dock`、`controlCenter`、`dock`、`appLauncher`——即 N2 的
de_lock / de_osd / 夜间模式全部为原生，无需额外包。

**内置配色方案**：Ayu / Catppuccin / Dracula / Eldritch / Gruvbox / Kanagawa /
Noctalia-default / Nord / Rosepine / Tokyo-Night（与我们的 10 套主题 6 套同名，
可作为 N3 的对照基准）。

**niri 模块事实（26.05）**

- `programs.niri` 注册 SDDM 会话；默认 `useNautilus = true`（装 nautilus 供
  portal 文件选择，本项目可关掉改用 Thunar + gtk 门户）
- 默认启用 gnome-keyring；**不装 Xwayland**——需在 systemPackages 加
  `xwayland-satellite`（niri 会自动拉起 PATH 中的它，N1 实测确认）
- 上游推荐门户：`xdg-desktop-portal-gnome`（录屏/文件选择）+
  `xdg-desktop-portal-gtk`

### N1 选项与提供方骨架（0.5 天）

1. `modules/options.nix`：`desktop.sessions` 的类型 enum 加 `"niri"`；
   断言（default ∈ sessions）无需改动
2. 新建 `modules/desktop/niri.nix`（仿 cosmic.nix 结构）：
   - `programs.niri.enable = true`（注册 SDDM 会话 `niri`）
   - `xdg.portal.extraPortals` + `xdg.portal.config.niri.default`（按 N0 结论）
   - `environment.systemPackages` 加 `noctalia-shell`（及其运行时依赖，包装已带）
   - 按需 `xwayland-satellite`
3. `hosts/vmware/default.nix`：`sessions += "niri"`（保持 `default = "cosmic"`，
   验证通过后再评估默认值）

验收：`agent-apply` 构建通过；SDDM 出现 Niri 会话；登录后 niri 起位、
`noctalia-shell` 起壳（面板可见）；`Ctrl+Alt+F2` 可切 TTY 兜底。

### N2 能力层接线（0.5 天）

`scripts/lib/de.sh` 按能力逐项加分支（沿用 P1/P3 的"原生/通用/接线"判定）：

| 能力 | niri 实现 | 说明 |
|---|---|---|
| `de_name` | `XDG_CURRENT_DESKTOP` 含 niri / niri 进程 | 新增探测分支 |
| `de_wallpaper_set` | awww（layer-shell 协议通用）/ Noctalia 壁纸 | 优先 awww（与 hyprland 分支同实现） |
| `de_screenshot_annotate` | grim + slurp → swappy | niri 支持 wlr-screencopy |
| `de_lock` | `loginctl lock-session`（Noctalia 锁屏接管） | 同 cosmic 分支 |
| `de_notify` | notify-send | 同一 DBus |
| `de_monitors` | `niri msg -j outputs` | niri IPC 输出 JSON |
| `de_osd` | Noctalia OSD（音量/亮度事件原生监听） | 无需接线，能力直接可用 |
| `de_theme_apply` | N3 exporter | — |

`scripts/desktop-check`：新增 `niri` 分支（进程 / portal / 壁纸 / 字体 /
Noctalia 组件 / 常用命令 共约 10 项），`install.sh` 末尾自检自动适配。

验收：沙箱 + 实机逐项验证；`desktop-check --de niri` 全绿；
在 niri 会话下 `wallpaper-next` / `screenshot-annotate` / `night-mode` 不报错。

### N3 主题 exporter（1 天，唯一真开发项）

1. 新建 `exporters/niri/theme.sh`：`tokens → Noctalia 配置`（目标文件与字段
   按 N0 结论；沿用 cosmic exporter 的确定性生成 + 原子写 + 测试 override 模式）
2. `de.sh de_theme_apply`：case 加 `niri`；`scripts/de-theme-apply` 自动覆盖
3. `home/default.nix`：exporter 部署路径沿用 `share/hyprland-nixos/exporters/`
   的现有机制（`exporterFiles` 的 readDir 需加 niri 子目录——一行改动）

验收：`de-theme-apply kanagawa` / `hyprbuddy` 切换后 Noctalia 面板、launcher、
通知配色跟随；10 套主题逐一回归（对照 themes/*/tokens.json 的 accent）。

### N4 home 基线（0.5 天）

1. `home/niri/config.kdl`：15 个常用键位 + 布局/输入基线（声明式，随 install.sh
   部署；沿用 P3 键位迁移思路，与 `docs/KEYBINDS.md` 对齐）
2. Noctalia 配置基线：只放**只读基线**（默认布局/壁纸绑定），运行期用户改动
   留在用户配置目录，不被 install.sh 覆盖（与 uxctl 的"受控写"不同：niri 侧
   **不复制 uxctl 模式**，cosmic-config 键值体系是 COSMIC 专有）
3. `home/default.nix`：textFiles 挂载 niri/ 目录

验收：新会话开箱即用（面板布局、键位、壁纸齐全）；键位表与 KEYBINDS.md 一致。

### N5 实测、回归与文档（0.5–1 天）

1. vmware（vmwgfx + 软渲染）实测：滚动平铺、Noctalia 面板/launcher/通知/锁屏、
   输入法（fcitx5 text-input-v3）、多显示器（如有）
2. 三桌面并存回归：Hyprland / COSMIC 会话不受影响；`desktop-check` 三套全绿
3. 文档：`docs/desktop-abstraction.md` 阶段表加 N 阶段记录；README 桌面矩阵；
   `docs/KEYBINDS.md` 加 niri 段；能力层表格补 niri 列

验收：三桌面可自由切换；各自 `desktop-check` 通过；文档合并。

## 四、风险与缓解

| 风险 | 缓解 |
|---|---|
| Noctalia 配色不可外部注入 | N0 第一步验证；不可注入则降级为"仅壁纸+亮暗跟随"，或退回轻量路线 |
| vmwgfx 软渲染兼容性（未知） | N5 实测；异常则 `sessions` 去掉 niri，一小时内可回退 |
| niri 26.04 与 Noctalia 4.7.6 版本匹配 | 以 26.05 频道锁定组合为准；不追 unstable（磁盘/编译教训） |
| Xwayland 缺失导致 X11 应用不可用 | N1 接入 `xwayland-satellite` 并实测（Thunar 等） |
| 与既有能力层冲突 | de.sh 分支隔离 + `de_name` 严格探测；三桌面回归为 N5 卡点 |

## 五、决策点（开工前拍板）

1. **Noctalia 全家桶 vs 轻量复用**：waybar/fuzzel/swaync/awww 均为合成器无关
   组件，niri 下直接可用（轻量路线零 exporter 改动）。默认走 Noctalia（整体
   观感 + 内置剪贴板/夜间/亮度），轻量路线作为 fallback
2. **版本口径**：先用 26.05 锁定的 niri 26.04 + Noctalia 4.7.6，不引入 unstable
3. **默认会话**：接入期间 `default` 保持 COSMIC，N5 全绿后再评估

## 六、工作量汇总

| 阶段 | 内容 | 估计 |
|---|---|---|
| N0 | 调研（Noctalia 配置/主题注入、portal、Xwayland、版本行为） | 0.5 天 |
| N1 | 选项 + `modules/desktop/niri.nix` + host 挂载 | 0.5 天 |
| N2 | de.sh 分支 + desktop-check niri | 0.5 天 |
| N3 | `exporters/niri/`（tokens → Noctalia 配置） | 1 天 |
| N4 | home 基线（config.kdl 键位 + Noctalia 只读基线） | 0.5 天 |
| N5 | 实测、三桌面回归、文档 | 0.5–1 天 |
| 合计 | | **3–4 天** |

## 七、与既有路线的关系

- **不阻塞 P3/P4/P5**：niri 是并行第三提供方，COSMIC 的退役判据不变
- `uxctl` 仅服务 cosmic-config 键值体系，niri 不复制该模式（config.kdl 声明式 +
  home/ 基线）
- 主题资产（themes/*/tokens.json）跨三桌面复用，新增 exporter 不触碰既有资产
- agent 层、skills、镜像构建全部不受影响


## N5 实测结论（2026-10-28，vmware 虚机）

### 环境级阻塞：niri 在 vmwgfx 软渲染下无法出图

日志（niri 26.04，宿主关闭 3D 加速）：

```
failed to initialize renderer, falling back to primary gpu: software EGL renderers are skipped
error adding primary node device ... no allocator available for device
```

niri **主动跳过软件 EGL 渲染器**（二进制中无相关环境变量开关），vmwgfx 在
3D 关闭时只有 llvmpipe → 渲染器初始化失败 → 会话黑屏（合成器进程存活、
Web 无输出）。COSMIC 在此环境下能跑是因为它接受软件渲染。

**可选路径**：
1. VMware 宿主开启「加速 3D 图形」（SVGA3D → mesa svga 硬件 GL）→ niri 可用；
   但已知代价：COSMIC Workspaces 缩略图恢复崩溃（vmwgfx dmabuf 上游缺陷，
   pop-os/cosmic-epoch#2978 同类）
2. 真机验证（leonard host，NVIDIA）
3. niri 提供方保留但不在本 VM 的 sessions 中启用

### 已修复的两个真实 bug（与黑屏叠加）

1. **config.kdl 缺 `spawn-at-startup`**：niri 不会自动起 shell——已补
   `noctalia-shell` 与 `awww-daemon`（否则即使渲染正常也只有黑底）
2. **hyprpolkitagent 全局自启**：systemd 用户单元挂在
   `graphical-session.target`，导致 niri 会话也拉起并 SIGABRT 崩溃循环——
   已改为仅由 Hyprland 的 exec-once 启动

### 待办

- 渲染阻塞解除后重跑 N5 清单（desktop-check / 主题跟随 / 键位 / portal）

### N5 补充：Noctalia 配色热更新的真实机制（实测修正 N0 结论）

N0 的判断「写 colors.json 即热加载」**不成立**——colors.json 是服务写的运行时
输出（扁平结构，无 dark/light 包裹），直接写不会触发重读。真实机制：

1. **方案文件**：`~/.config/noctalia/colorschemes/<slug>/<slug>.json`
   （结构 `{"dark": {...}, "light": {...}}`，与内置 Assets/ColorScheme 相同）
2. **启动扫描**：shell 启动时 `find -mindepth 2 -name '*.json'` 扫描内置 +
   `colorschemes/`，方案列表只在此刻建立
3. **应用**：`settings.json colorSchemes.predefinedScheme = <slug>` →
   启动时自动 applyScheme；运行中经
   `noctalia-shell ipc call colorScheme set <slug>` 切换（仅限已扫描到的方案）
4. **首次使用新方案的兜底**：运行中新建的方案不在列表 → IPC 报 Scheme not
   found。exporter 检测 colors.json 未在 1.5s 内更新 → 重启 shell，重启后的
   扫描收录新方案并自动应用

### N5 已知遗留

- **壁纸**：Noctalia 报 `Wallpaper Scan failed for Virtual-1`（settings.wallpaper
  目录未配置）；de-theme-apply 的 niri 分支目前只做配色，主题→壁纸绑定未接
  （可走 awww 或 Noctalia 壁纸服务，待定）
- Noctalia 首启有隐私对话框，需手动确认一次

### N5 壁纸机制（实测）

- Noctalia 每次启动会把 `settings.wallpaper.directory` **强制重置**为默认
  `~/Pictures/Wallpapers`（大写 W）——写这个键无效，不能靠它换扫描目录
- 正确做法：`noctalia-shell ipc call wallpaper set <绝对路径> all`，exporter
  路径解析优先 `~/Pictures/wallpapers/<主题壁纸>`（与 Hyprland 栈共用），
  回退主题库
- 就绪探测：裸 `set` 在 shell 未就绪时也返回 0，必须先 `wallpaper get all`
  探测到非空再 set（重启兜底后约 20s 就绪）

### N5 验收（2026-10-28，全部通过）

| 项 | 结果 |
|---|---|
| niri 会话 + Noctalia 自启 | ✅（spawn-at-startup，重启后可自动起） |
| desktop-check niri | ✅ 13 项全绿 |
| 主题切换（配色） | ✅ 冷启动应用 + 热切换（新方案走重启兜底） |
| 主题切换（壁纸） | ✅ 与配色同步（rose-pine/nord 实测） |
| 方案出现在 Noctalia 设置页 | ✅ 自定义方案与内置方案并列可选 |
