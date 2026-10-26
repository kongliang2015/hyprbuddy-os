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
| P1 | 能力层 `scripts/lib/de.sh`，21 处 hyprctl 收敛到 8 个能力；`hypr-check` → `desktop-check` | 待做 |
| P2 | `themes/*/tokens.json` + exporters 拆分，新增 cosmic exporter | 待做 |
| P3 | COSMIC 功能对齐（配置部署、壁纸/截图/锁屏/OSD/夜间/键位） | 待做 |
| P4 | `default = "cosmic"`，Hyprland 降为可选 | 待做 |
| P5 | 删 `hyprland.nix` + `exporters/hyprland/` + 相关包，打 tag 留回退 | 待做 |

## 退役判据（parity checklist）

进 P4/P5 前，下列各条必须在 COSMIC 下实测通过：

1. 通知（发送 / 历史 / 勿扰）
2. 8 套主题生效
3. 壁纸切换 + 主题绑定
4. 截图（区域/全屏）+ 标注
5. 锁屏 / 空闲 / 挂起
6. 中文输入法（text-input-v3）
7. 多显示器 + 缩放
8. 常用 15 个键位
9. 启动器（应用/计算/网页）
10. 音量/亮度 OSD
11. 剪贴板历史（COSMIC 无内置，需自建）
12. 夜间模式（无内置，需 gammastep）
13. 窗口总览（hyprshell 依赖 Hyprland IPC，**大概率放弃**）
14. agent 层（coredump 通知 / agent-menu / 诊断）
15. `desktop-check --de cosmic` 通过

第 11、12、13 是硬缺口，其中 13 需明确接受"总览功能消失"。

## 风险

| 风险 | 缓解 |
|---|---|
| NVIDIA + COSMIC（smithay） | 先 P0 实测，不切默认 |
| portal 互相抢（截图/共享） | `xdg.portal.config.cosmic.default` 分会话声明（已做） |
| 主题能力降级（无 CSS/模糊） | 接受降级，或用 cosmic-ext-tweaks 做有限调色 |
| 输入法 | P3 实测 fcitx5 text-input-v3 |
| ISO 回归 | 变更只在 v1-dev，出 ISO 前整体回归 |

## 当前状态（2026-10-26）

- `modules/desktop/cosmic.nix` 已落地，由 `sessions` 控制，**默认不启用**
- 带 cosmic 的配置已通过 `nix eval`（未下载/未安装）
- 启用方式：host 里加
  ```nix
  distro.desktop.sessions = [ "hyprland" "cosmic" ];
  distro.desktop.default = "hyprland";   # 先用 Hyprland 登录，验证 COSMIC 后再改
  ```
  然后 `sudo nixos-rebuild switch`，SDDM 会出现 COSMIC 会话。
