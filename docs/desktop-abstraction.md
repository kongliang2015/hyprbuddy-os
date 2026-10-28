> **v1-nn 分支状态（2026-10-28）**：COSMIC 已退役，第三提供方改为
> niri + Noctalia（见 `docs/niri-noctalia-plan.md`）。本文中 COSMIC 相关章节
> 为历史记录；当前 `distro.desktop.sessions = [ "hyprland" "niri" ]`。

# 桌面抽象层：COSMIC 接入与 Hyprland 渐进退役

目标：**不是迁移**，而是把 COSMIC 当作与 Hyprland 并列的桌面提供方接入现有
系统层 / agent 层 / skill 层，用同一份能力契约让两者共存，再逐步让 Hyprland 退役。

## 分层

```
L4 agent   codebuddy / opencode / ollama / 诊断 / usage      （与桌面无关）
L3 skill   diagnose-crash / desktop-settings / theme-create  （新增桌面矩阵说明）
L2 运行时  scripts/*   →  scripts/lib/de.sh 能力层
L1 提供方  modules/desktop/{hyprland,cosmic}.nix  实现同一契约
L0 系统层  distro.* 选项（distro.desktop.sessions / .default）
```

## 选项

```nix
distro.desktop.sessions = [ "hyprland" "cosmic" ];  # 装哪些（SDDM 各生成一项）
distro.desktop.default  = "hyprland";               # 默认登录哪个
```

约束：`default` 必须在 `sessions` 内（`modules/assertions.nix` 断言）。
映射：`hyprland` → SDDM 会话 `hyprland-uwsm`；`cosmic` → `cosmic`。

## 能力契约（L2）

脚本只调用能力，不直接碰 `hyprctl`。当前 7 个脚本共 21 处 `hyprctl` 调用，
收敛为 8 个能力：

| 能力 | Hyprland 实现 | COSMIC 实现 |
|---|---|---|
| `de_wallpaper set <path>` | awww | cosmic-bg |
| `de_theme apply <name>` | theme-next（13 writer） | cosmic-themes RON |
| `de_screenshot <region\|output>` | hyprshot | cosmic-screenshot |
| `de_lock` | hyprlock | 内置锁屏 |
| `de_osd <volume\|brightness> <±>` | swayosd-client | cosmic-osd |
| `de_notify <summary> <body>` | notify-send | notify-send（相同） |
| `de_keybinds_help` | show-keybinds（hyprctl） | cosmic-settings 提示 |
| `de_monitors` | hyprctl monitors | cosmic-randr |

## 主题资产：token 优先

COSMIC 只吃 RON 调色板，没有 CSS / 层模糊。为保住现有 8 套主题：

```
themes/<name>/tokens.json        ← 唯一真相（bg/bg2/fg/muted/accent/accent2/urgent/radius/font）
  ├── exporters/hyprland/*       现有 13 个 writer（waybar/swaync/eww/hyprshell/…）
  └── exporters/cosmic/*         cosmic-themes RON + 壁纸绑定
```

Hyprland 退役 = 删 `exporters/hyprland/`，主题资产不受影响。

## 阶段

| 阶段 | 内容 | 状态 |
|---|---|---|
| P0 | 并存骨架：`sessions`/`default` 选项、`modules/desktop/cosmic.nix`、portal 分会话 | **已完成（cosmic 默认关）** |
| P1 | 能力层 `scripts/lib/de.sh`，21 处 hyprctl 收敛到 8 个能力；`hypr-check` → `desktop-check` | **已完成（2026-10-26，见文末）** |
| P2 | `themes/*/tokens.json` + exporters 拆分，新增 cosmic exporter | **已完成（2026-10-27，见文末）** |
| P3 | 重定义为「实测 + 键位迁移 + de_osd 接线」（原"功能对齐"口径作废，见文末 P3 方案） | 待做（方案已定） |
| P4 | `default = "cosmic"`，Hyprland 降为可选 | 部分达成：vmware host 已 default = cosmic（2026-10-27） |
| P5 | 删 `hyprland.nix` + `exporters/hyprland/` + 相关包，打 tag 留回退 | 待做 |

## 退役判据（parity checklist，2026-10-27 重定义）

进 P4/P5 前，按 A/B/C/D 四类逐项确认（原 15 条扁平清单作废——
其中两条"硬缺口"经实测/内省证伪，见文末 P3 方案）。

### A. COSMIC 原生（零开发，实测确认即可）

| # | 能力 | COSMIC 实现 | 状态 |
|---|---|---|---|
| 1 | 通知（发送/历史/勿扰） | cosmic-notifications | 待实测 |
| 2 | 8 套主题生效 | cosmic exporter（P2 已落地） | ✅ 已实测 |
| 3 | 壁纸切换 + 主题绑定 | cosmic-bg（de_wallpaper_set） | ✅ 已实测 |
| 4 | 锁屏 / 空闲 / 挂起 | 内置锁屏 + com.system76.CosmicIdle | 待实测 |
| 5 | 启动器（应用/计算/网页） | cosmic-launcher | 待实测 |
| 6 | 工作区总览（侧边栏） | cosmic-workspaces | ✅ 已实测（vmwgfx 修复后） |
| 7 | 多显示器 + 缩放 | 设置 / cosmic-randr | 待实测 |
| 8 | agent 层 | 桌面无关，直接可用 | ✅ |

### B. 通用 Wayland 工具（装包即可，零开发）

| # | 能力 | 工具 | 依据 | 状态 |
|---|---|---|---|---|
| 9 | 剪贴板历史 | cliphist + wl-clipboard | 协议与合成器无关（原判"硬缺口"不成立） | 装包 + 实测 |
| 10 | 截图标注 | swappy（已在栈） | 通用 | 已接入 |
| 11 | 夜间模式 | gammastep | wlr-gamma-control，smithay 支持（原判"硬缺口"降级为实测项） | 装包 + 实测 |
| 12 | 中文输入法 | fcitx5 | text-input-v3，smithay 支持 | 装包 + 实测 |

### C. 少量开发（接口已确认）

| # | 能力 | 方案 | 状态 |
|---|---|---|---|
| 13 | 音量/亮度 OSD 触发（de_osd） | busctl 调 settings-daemon 现成方法（VolumeUp/Down、Increase/DecreaseDisplayBrightness） | 待开发（约半天） |
| 14 | 常用 15 个键位迁移 | com.system76.CosmicSettings.Shortcuts/v1/defaults 支持自定义命令绑定，写 RON 声明式部署进 home/ | 待开发（约半天） |
| 15 | desktop-check --de cosmic | 已有 12 项，随 A/B/C 各项实测补充 | 随测随补 |

### D. 明确放弃（接受降级）

| 能力 | 原因 | 替代 |
|---|---|---|
| 窗口总览 / Alt-Tab 缩略图 | hyprshell 依赖 Hyprland IPC | COSMIC 侧边栏（部分覆盖） |
| Waybar 形态 | COSMIC 用面板 applet 体系 | 能力等价、形态不同 |
| 玻璃拟态 CSS 级样式 | cosmic-themes 无 CSS/层模糊概念 | 接受降级 |

## 风险

| 风险 | 缓解 |
|---|---|
| NVIDIA + COSMIC（smithay） | 先 P0 实测，不切默认 |
| portal 互相抢（截图/共享） | `xdg.portal.config.cosmic.default` 分会话声明（已做） |
| 主题能力降级（无 CSS/模糊） | 接受降级，或用 cosmic-ext-tweaks 做有限调色 |
| 输入法 | P3 实测 fcitx5 text-input-v3 |
| ISO 回归 | 变更只在 v1-dev，出 ISO 前整体回归 |
| VMware vmwgfx dmabuf 导入残缺 | 宿主机关闭 3D 加速（已实测解决）；物理机/QEMU virtio 不受影响 |

## 当前状态（2026-10-27）

- `modules/desktop/cosmic.nix` 已落地，由 `sessions` 控制
- 已启用的 host：
  - **vmware**（x86_64 虚机）：`sessions = [ hyprland cosmic ]`，`default = cosmic`，
    **日用中**。2026-10-28 起 COSMIC 系列包经 `cosmicUnstable = true` 切到
    nixpkgs-unstable（epoch **1.11.0**，26.05 频道仍锁 1.2.0），vmwgfx 软渲染
    下桌面/主题/布局实测正常。前提：宿主机关闭「加速 3D 图形」——vmwgfx 的 dmabuf 导入残缺，
    开启 3D 加速时 Workspaces 缩略图等客户端因协议错误 7（create_immed failed，
    invalid wl_buffer，pop-os/cosmic-epoch#2978 同类）崩溃循环；关闭后 mesa
    全栈自动回落 swrast。排查过程见 hosts/vmware/default.nix 注释
  - **leonard**（x86_64 + NVIDIA）：`default = hyprland`，COSMIC 并存待实测
- `defaultSession` 优先级：hyprland.nix 用 `mkDefault`，由 sessions.nix 分发层
  裁决（多提供方并存的前提，commit 0702555）

## P1 落地（2026-10-26）

### 能力层文件位置

脚本被逐个装成独立的 store 文件（`bin-<name>`），无法靠相对路径找兄弟文件，所以
能力层库单独部署：

```
./scripts/lib/de.sh                     源码
~/.local/share/hyprland-nixos/lib/de.sh 部署位置（home/default.nix 里的 textFiles）
```

脚本统一这样引入（`@HOME@` 在构建期替换）：

```bash
DE_LIB="${XDG_DATA_HOME:-@HOME@/.local/share}/hyprland-nixos/lib/de.sh"
[ -r "$DE_LIB" ] || DE_LIB="$(dirname "$(readlink -f "$0")")/lib/de.sh"   # 仓库内直接跑时的回退
. "$DE_LIB"
```

### 已实现的能力

| 能力 | Hyprland | COSMIC | 说明 |
|---|---|---|---|
| `de_name` | `XDG_CURRENT_DESKTOP` 含 Hyprland / hyprctl 可用 | 含 COSMIC / cosmic-session 进程 | |
| `de_wallpaper_set` | awww（兼容 swww） | 写 `com.system76.CosmicBackground/v1/all` RON，cosmic-bg 热加载 | 两边都实测通过 |
| `de_screenshot_annotate` | grim + slurp → swappy | cosmic-screenshot（portal）→ swappy | COSMIC 分支未互动实测 |
| `de_lock` | hyprlock | `loginctl lock-session` | |
| `de_notify` | notify-send | notify-send | 同一套 DBus |
| `de_monitors` | hyprctl monitors -j | cosmic-randr list | |

### 已改造的脚本

- `wallpaper-next`：改调 `de_wallpaper_set`（COSMIC 下实测切换成功）
- `screenshot-annotate`：改调 `de_screenshot_annotate`
- `night-mode`：非 Hyprland 时明确提示"暂不支持"并退出 1（不再静默失败）

### 自检入口

新增 `desktop-check`，按当前桌面分派：

```
desktop-check            # 自动探测
desktop-check cosmic     # 显式指定
  → Hyprland: exec hypr-check（原 8 组检查不变）
  → COSMIC  : 进程 / portal / 壁纸配置 / 中文字体 / 常用命令 共 12 项
```

`install.sh` 末尾改为优先跑 `desktop-check`。

### P1 未完成（留到 P3）

- `de_osd`：COSMIC 的 cosmic-osd 需要自己的协议调用，暂未实现（swayosd 仅 Hyprland）
- `de_keybinds_help`：COSMIC 无等价物，需自建文本速查
- `de_theme_apply`：依赖 P2 的 token/exporters 拆分
- 夜间模式：COSMIC 需要引入 gammastep 或等 cosmic 上游支持

## P2 落地（2026-10-27）

### 文件结构

```
themes/<slug>/tokens.json          8 套主题的语义令牌（bg/fg/accent/accent2/inactive/
                                   surface/muted/urgent + bar.* + terminal.*，
                                   含 order 字段沿用 v0 索引顺序、dark 字段）
exporters/lib.sh                   公共库：theme_list / theme_env_load（jq 展开
                                   为 T_* 环境变量）/ mixhex
exporters/hyprland/*.sh            12 个 writer（自 theme-next 拆分，逻辑原样）：
                                   hyprland-border / wallpaper / waybar / fuzzel /
                                   swaync / eww / hyprshell / swayosd / kitty /
                                   fastfetch / hyprlock / hyprtoolkit
exporters/cosmic/theme.sh          cosmic_theme_apply：生成 cosmic-themes RON
```

部署：home/default.nix 把 themes/ 与 exporters/ 落到
`~/.local/share/hyprland-nixos/{themes,exporters}/`；jq 进 home 包。

### theme-next（编排器）

只做索引管理 + tokens 展开 + 按 序 source exporters。对 theme-picker 的
`--print-themes` 5 字段契约不变；`theme-next <idx>` 保留。已知行为修正：
kitty 色板 v0 只有 15 项（K15 缺失），缺省位回落终端前景色。

### cosmic exporter

- 写 Dark/Light 目录由 tokens.dark 决定，并同步 `Mode/v1/is_dark`
- accent 系（accent/accent_button）：base=T_ACCENT，hover=×0.88、
  pressed=×0.62（实测 libcosmic 派生幅度后取整）
- background/primary/secondary：base 与 component 各态 = bg↔fg 线性 mix
  （pct 从现有主题实测：0.13/0.23/0.33 等，浅色主题同样成立）
- button：mix(bg,fg,0.64) α0.25，各态只变 alpha；selected_text/focus=accent
- destructive/success/warning 系：语义色（亮红/绿/黄）不随主题变
- palette/spacing：保留现有文件（palette.name 换主题 slug）
- 壁纸绑定复用 de_wallpaper_set
- 测试：`COSMIC_THEME_DIR_OVERRIDE=<目录>` 重定向写入，不碰真实配置

### 已实测

- 沙箱全流程：theme-next 0 → 12 个 exporter 全部产物正确（waybar/kitty/
  fastfetch/hyprlock 等抽查）、state 写入、无旧变量残留
- cosmic exporter：HyprBuddy 注入测试目录，background/accent/button 等值与
  结构（括号配对）全部正确

### 限制（留 P3）

- 浅色主题（WorkBuddy）会翻转全局明暗模式，primary/secondary 的深色中性
  百分比常数为暗色实测值，浅色下未调优
- cosmic-themes 无 CSS/层模糊概念，主题的模糊/胶囊样式不迁移（能力降级）
- de_theme_apply 已入 de.sh 并提供 CLI 入口 de-theme-apply（scripts/），COSMIC 会话实测通过
- **大坑留档（2026-10-27 实测）**：生成的 RON 若缺嵌套结构闭合的尾逗号（`base: (...)` 后
  少 `,`），整份主题反序列化失败，libcosmic **静默回落默认主题**（日志
  `RonSpanned(ExpectedComma)`），表现为"切主题颜色不变"。RON 要求：嵌套字段闭合
  括号后必须有逗号；仅文件末尾最后一个字段可省略。修复后 COSMIC 实测配色跟随正常


## P3 方案（2026-10-27 重定义）

原 P3「配置部署、壁纸/截图/锁屏/OSD/夜间/键位」的"功能对齐"口径作废。
逐项核对后，真正需要开发的只有两项（OSD 触发接线、键位 RON 迁移），
其余为 COSMIC 原生已有或通用 Wayland 工具直接可用。

### 重定义依据（实测/内省证据）

- **音量/亮度 OSD 触发**：cosmic-settings-daemon 已有现成 DBus 方法
  （busctl --user introspect 实测：VolumeUp/Down、Increase/DecreaseDisplayBrightness、
  KeyboardBrightness 等）——原判"需自研协议调用"不成立
- **剪贴板历史**：cliphist + wl-clipboard 走标准 Wayland 剪贴板协议，与合成器
  无关，直接可用——原判"COSMIC 无内置、需自建"不成立
- **夜间模式**：COSMIC 1.2 无内置（settings-daemon 内省无 CCT/NightMode 方法），
  但 gammastep 走 wlr-gamma-control（smithay 支持）可平替——降级为实测项
- **自定义键位**：com.system76.CosmicSettings.Shortcuts/v1/defaults 支持
  自定义命令绑定（社区键位表有先例），可声明式部署进 home/
- **主题传播链路**：cosmic-settings-daemon WatchConfig → 各 libcosmic 应用经
  cosmic-config 订阅热更新（P2 的 RON 写入路径已实测打通，含尾逗号坑）

### 工作项

1. 键位迁移：整理 15 个常用键位 → Shortcuts RON 声明式部署进 home/
2. 实测三件套：fcitx5 / gammastep / cliphist 装包实测（cosmic.nix 补包）
3. de_osd：busctl 接线（音量 + 亮度）
4. desktop-check --de cosmic 检查项随 A/B/C 各项实测补充

### 明确放弃

窗口总览/Alt-Tab 缩略图（hyprshell 依赖 Hyprland IPC）、Waybar 形态、
玻璃拟态 CSS 级样式。接受降级，P4/P5 判据不含这些项。
